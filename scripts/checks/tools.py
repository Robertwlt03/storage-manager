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

# A failed test in the output of Swift Testing.
FAILED_TEST = "✘"


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
        line.strip() for line in result.output.splitlines()
        if FAILED_TEST in line or ": error:" in line
    ]
    return result.findings(failures)


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


# MARK: Extra report


def coverage_report() -> list[str]:
    """Runs the tests with coverage and prints how much of each source folder they reach."""
    result = run(["swift", "test", *BUILD_OPTIONS, "--enable-code-coverage"])
    if not result.succeeded:
        return result.findings([])
    report_path = run(["swift", "test", *BUILD_OPTIONS, "--show-codecov-path"]).output
    report = json.loads(Path(report_path.strip().splitlines()[-1]).read_text())
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
