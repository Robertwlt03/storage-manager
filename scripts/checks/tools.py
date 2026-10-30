"""The steps that hand the work to a tool: formatting, SwiftLint, compiler, tests, plutil, scripts.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (swift, swift format, plutil) and SwiftLint (brew install swiftlint)
"""

import json
import re
import shutil
from collections import Counter
from pathlib import Path

from checks.project import BUILD_OPTIONS, LINE_LENGTH, PROJECT, Codebase, app, lines_of, place, run

# MARK: Settings

# What every script states in its head, so each one opens the same way (see CODE_STYLE.md).
SCRIPT_HEAD = "Start:"

# A rule name in the Makefile, such as "build:" at the start of a line.
MAKE_RULE = re.compile(r"^([a-z]+):", re.MULTILINE)

# How many lines at the top of a script count as its head.
HEAD_LINES = 12

# The coverage report's columns, in characters.
FOLDER_COLUMN_WIDTH = 14
PERCENT_WIDTH = 6

SOURCE_FOLDER = PROJECT / "Sources"  # the coverage report sorts by the folders below it

# A failed expectation in the output of Swift Testing:
# ✘ Test "Sizes …" recorded an issue at FormatTests.swift:18:9: Expectation failed: …
TEST_ISSUE = re.compile(r"""
    Test \s "(?P<test> [^"]+ )" \s recorded \s an \s issue \s at \s   # the test
    (?P<file> [^:\s]+ ) : (?P<line> \d+ ) : \d+ : \s                # its file, line and column
    (?P<message> .+ )                                               # what failed
""", re.VERBOSE)


# MARK: Steps


def formatting_findings() -> list[str]:
    folders = ["Sources", "Tests", "scripts"]
    return run(["swift", "format", "lint", "--strict", "--recursive", *folders]).diagnostics()


def lint_findings() -> list[str]:
    """Length, nesting and complexity limits from .swiftlint.yml."""
    if not shutil.which("swiftlint"):
        return ["SwiftLint is missing: brew install swiftlint"]
    return run(["swiftlint", "lint", "--quiet", "--strict"]).diagnostics()


def compiler_findings() -> list[str]:
    result = run(["swift", "build", *BUILD_OPTIONS])
    return result.findings(result.diagnostics())


def test_findings() -> list[str]:
    result = run(["swift", "test", *BUILD_OPTIONS])
    failures = [
        readable_failure(line.strip()) for line in result.output.splitlines()
        if TEST_ISSUE.search(line) or ": error:" in line
    ]
    return result.findings(failures)


def readable_failure(line: str) -> str:
    """A failed expectation as "Tests/…/File.swift:18: the test: what failed", so the report sorts
    it under its file."""
    issue = TEST_ISSUE.search(line)
    if not issue:
        return line
    test_files = {path.name: path for path in app().swift_tests}
    path = test_files.get(issue["file"])
    where = place(path, int(issue["line"])) if path else f"{issue['file']}:{issue['line']}"
    return f"{where}: {issue['test']}: {issue['message']}"


def property_list_findings() -> list[str]:
    files = [PROJECT / "Info.plist", *sorted((PROJECT / "Resources").glob("*.lproj/*.strings"))]
    result = run(["plutil", "-lint", *map(str, files)])
    return [line for line in result.output.splitlines() if not line.endswith(": OK")]


def script_findings() -> list[str]:
    """The scripts keep the app's line length, open with the shared head and have no typos."""
    findings = script_layout_problems(app())
    for command in syntax_checks(app()):
        findings += run(command).findings([])
    return findings


def script_layout_problems(codebase: Codebase) -> list[str]:
    problems = []
    for path in codebase.all_scripts():
        problems += long_lines(path)
        if not any(SCRIPT_HEAD in line for line in lines_of(path)[:HEAD_LINES]):
            problems.append(f"{place(path, 1)}: the head lacks '{SCRIPT_HEAD}' (see CODE_STYLE.md)")
    return problems


def long_lines(path: Path) -> list[str]:
    return [
        f"{place(path, number)}: line longer than {LINE_LENGTH} characters"
        for number, line in enumerate(lines_of(path), start=1)
        if len(line) > LINE_LENGTH
    ]


def syntax_checks(codebase: Codebase) -> list[list[str]]:
    """Each tool reads a script without running it."""
    checks = [
        *(["bash", "-n", str(path)] for path in codebase.shell_scripts),
        *(["python3", "-m", "py_compile", str(path)] for path in codebase.python_scripts),
        *(["swiftc", "-typecheck", str(path)] for path in codebase.swift_scripts),
    ]
    for makefile in codebase.makefiles:
        rules = MAKE_RULE.findall(makefile.read_text())
        checks.append(["make", "--dry-run", "--file", str(makefile), *rules])
    return checks


# MARK: Test coverage

# The least share of lines the tests must reach in each folder with logic. Each sits just below
# what the tests reach today, so coverage can only grow; raise a value when the tests grew.
MINIMUM_COVERAGE = {
    "Localization": 0.85,
    "Models": 0.65,
    "Core": 0.45,
    "Services": 0.35,
    "State": 0.30,
}
# Folders the unit tests do not measure, each for a reason. A folder in neither list is reported.
NOT_MEASURED = {
    "App": "it starts the app and its windows",
    "Features": "views, checked in the demo and with make snapshots",
    "DesignSystem": "views, checked in the demo and with make snapshots",
    "Diagnostics": "the self test and the stress test, which test the app themselves",
}


def coverage_findings() -> list[str]:
    report = coverage_data()
    if isinstance(report, list):
        return report
    covered_lines, all_lines = lines_per_folder(report)
    findings = []
    for folder in sorted(all_lines):
        share = covered_lines[folder] / all_lines[folder]
        findings += coverage_problems(folder, share)
    return findings


def coverage_problems(folder: str, share: float) -> list[str]:
    where = f"Sources/{folder}:1"
    if folder in NOT_MEASURED:
        return []
    if folder not in MINIMUM_COVERAGE:
        return [
            f"{where}: no coverage rule yet; add the folder to MINIMUM_COVERAGE or NOT_MEASURED"
        ]
    minimum = MINIMUM_COVERAGE[folder]
    if share >= minimum:
        return []
    return [f"{where}: the tests reach {share:.1%} of the lines, at least {minimum:.0%} are due"]


def coverage_data() -> dict | list[str]:
    """The report of the last test run, which measured coverage (see BUILD_OPTIONS); the tests
    run again only when they are not current."""
    result = run(["swift", "test", *BUILD_OPTIONS])
    if not result.succeeded:
        return result.findings([])
    report_path = run(["swift", "test", *BUILD_OPTIONS, "--show-codecov-path"]).output
    return json.loads(Path(report_path.strip().splitlines()[-1]).read_text())


def coverage_report() -> list[str]:
    """Prints how much of each source folder the tests reach."""
    report = coverage_data()
    if isinstance(report, list):
        return report
    covered_lines, all_lines = lines_per_folder(report)
    for folder in sorted(all_lines):
        print_coverage(folder, covered_lines[folder], all_lines[folder])
    print_coverage("all", sum(covered_lines.values()), sum(all_lines.values()))
    return []


def print_coverage(folder: str, covered: int, lines: int) -> None:
    """One line of the report, such as "  Services       84.2 %  (412 of 489 lines)"."""
    percent = f"{covered / lines:.1%}"  # a share as percent with one decimal
    print(f"  {folder.ljust(FOLDER_COLUMN_WIDTH)} {percent.rjust(PERCENT_WIDTH)}"
          f"  ({covered} of {lines} lines)")


def lines_per_folder(report: dict) -> tuple[Counter, Counter]:
    """Covered and all lines of each folder below Sources, from the coverage report's files."""
    covered_lines, all_lines = Counter(), Counter()
    for source in report["data"][0]["files"]:
        file_name = Path(source["filename"])
        if not file_name.is_relative_to(SOURCE_FOLDER):
            continue
        folder = file_name.relative_to(SOURCE_FOLDER).parts[0]
        covered_lines[folder] += source["summary"]["lines"]["covered"]
        all_lines[folder] += source["summary"]["lines"]["count"]
    return covered_lines, all_lines
