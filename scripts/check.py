#!/usr/bin/env python3
"""The check pipeline: every rule from CODE_STYLE.md that a tool can check, one step after another.

Run it from anywhere: scripts/check.py
It exits with status 1 as soon as one finding is left, so it guards every pull request.
"""

import json
import re
import shutil
import subprocess
import sys
from collections import Counter
from functools import cache
from pathlib import Path

from index_store import ACCESSOR_SUBKINDS, IndexStore, Kind, Occurrence, Role

PROJECT = Path(__file__).resolve().parent.parent
SOURCES = PROJECT / "Sources"
TESTS = PROJECT / "Tests"
SCRIPTS = PROJECT / "scripts"
MAKEFILE = PROJECT / "Makefile"
BUILD_FOLDER = str(PROJECT / ".build" / "check")
# Building and testing share one configuration, so neither step rebuilds what the other built.
# The index store feeds the dead-code step.
BUILD_OPTIONS = [
    "--scratch-path", BUILD_FOLDER, "--enable-index-store", "-Xswiftc", "-warnings-as-errors",
]

THEME_FILE = "DesignSystem/Theme.swift"
# Made-up demo content may use plain example numbers, like the tests.
DEMO_FILE = "Diagnostics/DemoData.swift"
TOKENS_FILE = "DesignSystem/Tokens.swift"
MOTION_FILE = "DesignSystem/Motion.swift"
DESIGN_FOLDER = "DesignSystem/"
DIAGNOSTICS_FOLDER = "Diagnostics/"
# swift format wraps code but not comments, so this check covers the comments; the scripts keep
# the same limit.
LINE_LENGTH = json.loads((PROJECT / ".swift-format").read_text())["lineLength"]
ALLOWED_SHORT_NAMES = {"id", "x", "y"}
NUMBER = re.compile(r"(?<![\w.])\d[\d_]*(?:\.\d+)?(?![\w.])")
NAMED_CONSTANT = re.compile(
    r"^\s*(?:@\w+\s+)*(?:(?:private|fileprivate|static|nonisolated)\s+)*(?:let|var|case)\s+\w+"
)
# Swift only accepts a written-out version in an availability check.
AVAILABILITY = re.compile(r"[#@]available\s*\(")
COLOUR_OUTSIDE_THEME = re.compile(
    r"\b(?:Color|NSColor)\s*[.(]"
    r"|\.(?:red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|gray|black"
    r"|white)\b"
)
GERMAN_LETTER = re.compile(r"[äöüÄÖÜß]")
SHORT_CLOSURE_PARAMETERS = re.compile(r"\{\s*\(?\s*(\w{1,2}(?:\s*,\s*\w{1,2})*)\s*\)?\s+in\b")
SHORT_DECLARATION = re.compile(r"\b(?:let|var)\s+(\w{1,2})\b|\b_\s+(\w{1,2})\s*:")
ANONYMOUS_PARAMETER = re.compile(r"\$\d")
FONT = re.compile(r"\.font\(")
SYMBOL_NAME = re.compile(r'systemName:\s*"|\.symbol\("|"[a-z][a-z0-9]*(?:\.[a-z0-9]+)+"')
NOT_A_SYMBOL = re.compile(r'"(?:com|org|net|io)\.|"\w+\.(?:app|lproj|strings|png|plist)"')
ANIMATION = re.compile(
    r"(?:\bwithAnimation|\.animation)\(|\.(?:smooth|spring|bouncy|snappy|easeInOut)\b|\.linear\("
)
WRITTEN_UI_TEXT = re.compile(r'\b(?:Text|Button|Label|Toggle|Picker|Section)\("[^"]|\.help\("[^"]')
PRINT = re.compile(r"\bprint\(")
# Liquid Glass, materials and button styles come only from the design system (surface, appButton).
OWN_SURFACE = re.compile(
    r"\.glassEffect\(|\.buttonStyle\(|Material\b|\.background\((?!Backdrop\(\)\))"
)
DIAGNOSTIC = re.compile(r": (?:warning|error):")

# Dead code: what macOS or SwiftUI uses although no line of ours does, marked by these attributes
# on the declaration or the line above it: the app's entry point and the app delegate.
USED_BY_THE_SYSTEM = ("@main", "@NSApplicationDelegateAdaptor")
ENTRY_POINT = "main()"
CASE_ITERABLE = "s:s12CaseIterableP"  # cases of such an enum are used through allCases
TEXT_KEYS = "TextKey"  # except text keys: a key nobody shows is dead, whatever allCases says
# A property wrapper such as @Binding passes every write on, so writing alone is a use.
PROPERTY_WRAPPER = re.compile(r"^\s*@[A-Z]\w*")
CHECKED_KINDS = set(Kind)
PROPERTY_KINDS = {
    Kind.VARIABLE, Kind.INSTANCE_PROPERTY, Kind.CLASS_PROPERTY, Kind.STATIC_PROPERTY,
}


# MARK: Reading files and running tools


def strip_comments_and_strings(line: str) -> str:
    def keep_interpolations(literal: re.Match) -> str:
        return " ".join(re.findall(r"\\\((.*?)\)", literal.group(0)))

    without_strings = re.sub(r'"(?:\\.|[^"\\])*"', keep_interpolations, line)
    return without_strings.split("//", 1)[0]


def string_literals(line: str) -> list[str]:
    code = line.split("//", 1)[0] if '"' not in line.split("//", 1)[0] else line
    return re.findall(r'"((?:\\.|[^"\\])*)"', code)


def swift_files() -> list[Path]:
    return sorted(SOURCES.rglob("*.swift"))


def test_files() -> list[Path]:
    return sorted(TESTS.rglob("*.swift"))


def swift_scripts() -> list[Path]:
    return sorted(SCRIPTS.glob("*.swift"))


def script_files() -> list[Path]:
    """Scripts that swift format does not cover."""
    return [
        PROJECT / "build.sh", MAKEFILE,
        *sorted(SCRIPTS.glob("*.sh")), *sorted(SCRIPTS.glob("*.py")),
    ]


def place(path: Path, number: int) -> str:
    return f"{path.relative_to(PROJECT).as_posix()}:{number}"


@cache
def lines_of(path: Path) -> list[str]:
    return path.read_text().splitlines()


def numbered_lines(paths: list[Path]):
    """Each Swift line with its path below Sources or Tests, its place and its bare code."""
    for path in paths:
        relative = path.relative_to(PROJECT).as_posix().split("/", 1)[1]
        for number, line in enumerate(lines_of(path), start=1):
            yield relative, place(path, number), line, strip_comments_and_strings(line)


def run(command: list[str]) -> tuple[int, str]:
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def diagnostics(output: str) -> list[str]:
    """The warnings and errors a tool printed, each once."""
    return sorted({line for line in output.splitlines() if DIAGNOSTIC.search(line)})


def or_last_line(status: int, output: str, findings: list[str]) -> list[str]:
    """When a tool fails without a readable finding, its last line explains why."""
    if status != 0 and not findings:
        return [output.strip().splitlines()[-1]]
    return findings


def swift_test_command(*options: str) -> list[str]:
    return ["swift", "test", *BUILD_OPTIONS, *options]


# MARK: Tools


def formatting_findings() -> list[str]:
    _, output = run(
        ["swift", "format", "lint", "--strict", "--recursive", "Sources", "Tests", "scripts"]
    )
    return diagnostics(output)


def lint_findings() -> list[str]:
    """Length, nesting and complexity limits from .swiftlint.yml."""
    if not shutil.which("swiftlint"):
        return ["SwiftLint is missing: brew install swiftlint"]
    _, output = run(["swiftlint", "lint", "--quiet", "--strict"])
    return diagnostics(output)


def compiler_findings() -> list[str]:
    status, output = run(["swift", "build", *BUILD_OPTIONS])
    return or_last_line(status, output, diagnostics(output))


def test_findings() -> list[str]:
    status, output = run(swift_test_command())
    failures = [line.strip() for line in output.splitlines() if "✘" in line or ": error:" in line]
    return or_last_line(status, output, failures)


def coverage_report() -> list[str]:
    """Runs the tests with coverage and prints how much of each source folder they reach."""
    status, output = run(swift_test_command("--enable-code-coverage"))
    if status != 0:
        return or_last_line(status, output, [])
    _, report_path = run(swift_test_command("--show-codecov-path"))
    report = json.loads(Path(report_path.strip().splitlines()[-1]).read_text())
    covered = Counter()
    counted = Counter()
    for source in report["data"][0]["files"]:
        if f"{SOURCES}/" not in source["filename"]:
            continue
        folder = source["filename"].split(f"{SOURCES}/", 1)[1].split("/", 1)[0]
        covered[folder] += source["summary"]["lines"]["covered"]
        counted[folder] += source["summary"]["lines"]["count"]
    for folder in sorted(counted):
        share = covered[folder] / counted[folder]
        print(f"  {folder:<14} {share:6.1%}  ({covered[folder]} of {counted[folder]} lines)")
    print(f"  {'all':<14} {sum(covered.values()) / sum(counted.values()):6.1%}")
    return []


def property_list_findings() -> list[str]:
    files = [PROJECT / "Info.plist", *sorted((PROJECT / "Resources").glob("*.lproj/*.strings"))]
    _, output = run(["plutil", "-lint", *map(str, files)])
    return [line for line in output.splitlines() if not line.endswith(": OK")]


def script_findings() -> list[str]:
    findings = []
    for path in script_files():
        for number, line in enumerate(lines_of(path), start=1):
            if len(line) > LINE_LENGTH:
                findings.append(f"{place(path, number)}: line longer than {LINE_LENGTH} characters")
    checks = [
        *(["bash", "-n", str(path)] for path in script_files() if path.suffix == ".sh"),
        *(["python3", "-m", "py_compile", str(path)] for path in SCRIPTS.glob("*.py")),
        *(["swiftc", "-typecheck", str(path)] for path in swift_scripts()),
        # A dry run reads every short command in the Makefile without running one.
        ["make", "--dry-run", *re.findall(r"^([a-z]+):", "\n".join(lines_of(MAKEFILE)), re.M)],
    ]
    for command in checks:
        status, output = run(command)
        findings += or_last_line(status, output, [])
    return findings


# MARK: House rules


def design_findings() -> list[str]:
    findings = []
    for relative, where, line, code in numbered_lines(swift_files()):
        if FONT.search(code) and not relative.startswith(DESIGN_FOLDER):
            findings.append(f"{where}: font set directly, use .textRole(...)")
        if relative != TOKENS_FILE and SYMBOL_NAME.search(line) and not NOT_A_SYMBOL.search(line):
            findings.append(f"{where}: symbol name outside Symbols in Tokens.swift")
        if relative != MOTION_FILE and ANIMATION.search(code) and "Motion." not in code:
            findings.append(f"{where}: animation outside Motion.swift")
        if WRITTEN_UI_TEXT.search(line):
            findings.append(f"{where}: written-out text on screen, use TextKey")
        if OWN_SURFACE.search(code) and not relative.startswith(DESIGN_FOLDER):
            findings.append(f"{where}: own glass, material or background, use .surface()")
        if PRINT.search(code) and not relative.startswith(DIAGNOSTICS_FOLDER):
            findings.append(f"{where}: output outside Diagnostics could show private names")
    return findings


def rule_findings() -> list[str]:
    findings = []
    swift_code = swift_files() + test_files() + swift_scripts()
    for relative, where, line, code in numbered_lines(swift_code):
        is_test = where.startswith("Tests/")
        if len(line) > LINE_LENGTH:
            findings.append(f"{where}: line longer than {LINE_LENGTH} characters")
        # Tests may use plain example values; the app's code may not.
        if not (is_test or relative == DEMO_FILE):
            findings += [f"{where}: number {literal} has no name" for literal in bare_numbers(code)]
        if not is_test and relative != THEME_FILE and COLOUR_OUTSIDE_THEME.search(code):
            findings.append(f"{where}: colour defined outside Theme.swift")
        if any(GERMAN_LETTER.search(text) for text in string_literals(line)):
            findings.append(f"{where}: German text in code, it belongs in the translations")
        if line.rstrip().endswith("// DBG"):
            findings.append(f"{where}: temporary debug line left in the code")
        if ANONYMOUS_PARAMETER.search(code):
            findings.append(f"{where}: $0 instead of a named closure parameter")
        findings += [f"{where}: short name '{name}'" for name in short_names(code)]
    return findings


def bare_numbers(code: str) -> list[str]:
    if NAMED_CONSTANT.match(code) or AVAILABILITY.search(code):
        return []
    literals = NUMBER.findall(code)
    return [literal for literal in literals if literal.replace("_", "") not in {"0", "1"}]


def short_names(code: str) -> list[str]:
    names = [
        name.strip()
        for match in SHORT_CLOSURE_PARAMETERS.finditer(code)
        for name in match.group(1).split(",")
    ]
    names += [match.group(1) or match.group(2) for match in SHORT_DECLARATION.finditer(code)]
    return [name for name in names if name not in ALLOWED_SHORT_NAMES and name != "_"]


# MARK: Dead code


def dead_code_findings() -> list[str]:
    """Declarations nothing uses and properties nothing reads, from the compiler's index."""
    status, output = run(["swift", "build", *BUILD_OPTIONS])  # does nothing if already built
    if status != 0:
        return or_last_line(status, output, [])
    store = next(Path(BUILD_FOLDER).glob("**/index/store"))
    return DeadCode(IndexStore(store).occurrences(inside=SOURCES)).findings()


class DeadCode:
    """Only uses from the app's own code count; code that only the tests use is dead as well."""

    def __init__(self, occurrences: list[Occurrence]):
        definitions = [found for found in occurrences if found.roles & Role.DEFINITION]
        self.declarations = {
            definition.usr: definition for definition in definitions if is_checked(definition)
        }
        # A property wrapper adds `$name` and `_name` in the same line; a use of either counts.
        self.groups = {definition.usr: group(definition) for definition in definitions}
        # All the ways our own lines use each group; code that macros such as @Observable
        # generate is marked implicit and does not count.
        self.uses: dict[tuple, Role] = {}
        for occurrence in occurrences:
            is_written = not occurrence.roles & Role.IMPLICIT
            if occurrence.roles & Role.REFERENCE and is_written and occurrence.usr in self.groups:
                key = self.groups[occurrence.usr]
                self.uses[key] = self.uses.get(key, Role(0)) | occurrence.roles
        self.listed_enums = {
            usr
            for occurrence in occurrences if occurrence.usr == CASE_ITERABLE
            for usr in occurrence.related(Role.BASE_OF)
        }

    def findings(self) -> list[str]:
        declarations = sorted(self.declarations.values(), key=lambda item: (item.path, item.line))
        found = [(declaration, self.finding(declaration)) for declaration in declarations]
        return [f"{place(item.path, item.line)}: {finding}" for item, finding in found if finding]

    def finding(self, declaration: Occurrence) -> str | None:
        if self.is_used_by_the_system(declaration):
            return None
        uses = self.uses.get(self.groups[declaration.usr])
        if uses is None:
            return self.unused(declaration)
        if declaration.kind in PROPERTY_KINDS and not uses & Role.READ:
            line = lines_of(declaration.path)[declaration.line - 1]
            if not PROPERTY_WRAPPER.match(line):
                return f"'{declaration.name}' is assigned but never read"
        return None

    def unused(self, declaration: Occurrence) -> str | None:
        parent = self.parent(declaration)
        if declaration.kind == Kind.ENUM_CASE and parent and parent.usr in self.listed_enums:
            if parent.name != TEXT_KEYS:
                return None
            return f"text '{declaration.name}' is never shown"
        return f"'{declaration.name}' is declared but never used"

    def parent(self, declaration: Occurrence) -> Occurrence | None:
        parents = declaration.related(Role.CHILD_OF)
        return self.declarations.get(parents[0]) if parents else None

    def is_used_by_the_system(self, declaration: Occurrence) -> bool:
        lines = lines_of(declaration.path)[max(declaration.line - 2, 0):declaration.line]
        if any(attribute in line for line in lines for attribute in USED_BY_THE_SYSTEM):
            return True
        parent = self.parent(declaration)
        return declaration.name == ENTRY_POINT and parent is not None and (
            self.is_used_by_the_system(parent)
        )


def is_checked(definition: Occurrence) -> bool:
    """Written declarations; accessors, generated code and protocol requirements are skipped."""
    return (
        definition.kind in CHECKED_KINDS
        and definition.subkind not in ACCESSOR_SUBKINDS
        and not definition.roles & Role.IMPLICIT
        and not definition.related(Role.OVERRIDE_OF)
    )


def group(definition: Occurrence) -> tuple[Path, int, str]:
    return definition.path, definition.line, definition.name.lstrip("$_")


# MARK: Running the steps


STEPS = [
    ("format", "Formatting (swift format)", formatting_findings),
    ("lint", "Length, nesting and complexity (SwiftLint)", lint_findings),
    ("compiler", "Compiler warnings and errors", compiler_findings),
    ("tests", "Unit tests (Swift Testing)", test_findings),
    ("rules", "House rules", rule_findings),
    ("design", "Design rules", design_findings),
    ("deadcode", "Dead code (compiler index)", dead_code_findings),
    ("plists", "Translation files and Info.plist (plutil)", property_list_findings),
    ("scripts", "Scripts and Makefile", script_findings),
]
# Reports that only run when asked for by name, like `scripts/check.py coverage`.
EXTRA_STEPS = [
    ("coverage", "Test coverage per folder", coverage_report),
]


def main() -> int:
    """Without arguments every step runs; `scripts/check.py tests rules` runs only those."""
    chosen = sys.argv[1:] or [key for key, _, _ in STEPS]
    known = [key for key, _, _ in STEPS + EXTRA_STEPS]
    unknown = [key for key in chosen if key not in known]
    if unknown:
        print(f"Unknown step: {', '.join(unknown)}. Steps: {', '.join(known)}")
        return 2
    status, output = run([str(SCRIPTS / "require-xcode.sh")])
    if status != 0:
        print(output.strip())
        return 1
    total = 0
    for key, title, check in STEPS + EXTRA_STEPS:
        if key not in chosen:
            continue
        findings = check()
        total += len(findings)
        print(f"{title}: {len(findings)}")
        for finding in findings:
            print(f"  {finding}")
    print(f"\n{total} findings" if total else "\nNo errors and no warnings.")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
