#!/usr/bin/env python3
"""The check pipeline: every rule from CODE_STYLE.md that a tool can check, one step after another.

Run it from anywhere: scripts/inspect.py
It exits with status 1 as soon as one finding is left, so it guards every pull request.
"""

import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
SOURCES = PROJECT / "Sources"
TESTS = PROJECT / "Tests"
BUILD_FOLDER = os.environ.get("INSPECT_BUILD_FOLDER", str(PROJECT / ".build" / "inspect"))

THEME_FILE = "DesignSystem/Theme.swift"
# Made-up demo content may use plain example numbers, like the tests.
DEMO_FILE = "Diagnostics/DemoData.swift"
TOKENS_FILE = "DesignSystem/Tokens.swift"
MOTION_FILE = "DesignSystem/Motion.swift"
DESIGN_FOLDER = "DesignSystem/"
DIAGNOSTICS_FOLDER = "Diagnostics/"
# swift format wraps code but not comments, so this check covers the comments.
LINE_LENGTH = json.loads((PROJECT / ".swift-format").read_text())["lineLength"]
ALLOWED_SHORT_NAMES = {"id", "x", "y"}
# Names the system calls by itself, so they are used although no source line calls them.
CALLED_BY_THE_SYSTEM = {
    "body", "main", "init", "id", "hash", "makeBody", "makeNSView", "updateNSView",
    "speechSynthesizer", "applicationShouldTerminateAfterLastWindowClosed",
    "applicationDidFinishLaunching", "previewValue", "defaultValue", "reduce",
    "description", "makeIterator", "next", "allCases", "rawValue", "path",
}
NUMBER = re.compile(r"(?<![\w.])\d[\d_]*(?:\.\d+)?(?![\w.])")
NAMED_CONSTANT = re.compile(
    r"^\s*(?:@\w+\s+)*(?:(?:private|fileprivate|static|nonisolated)\s+)*(?:let|var|case)\s+\w+"
)
# Swift only accepts a written-out version in an availability check.
AVAILABILITY = re.compile(r"[#@]available\s*\(")
COLOUR_OUTSIDE_THEME = re.compile(
    r"\b(?:Color|NSColor)\s*[.(]"
    r"|\.(?:red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|gray|black|white)\b"
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
DECLARATION = re.compile(
    r"\b(?:func|var|let|case|struct|enum|class|protocol|typealias)\s+([A-Za-z_]\w*)"
)


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


def numbered_lines(paths: list[Path]):
    for path in paths:
        relative = path.relative_to(PROJECT).as_posix()
        for number, line in enumerate(path.read_text().splitlines(), start=1):
            yield relative.split("/", 1)[1], f"{relative}:{number}", line, strip_comments_and_strings(line)


def run(command: list[str]) -> tuple[int, str]:
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def formatting_findings() -> list[str]:
    _, output = run(["swift", "format", "lint", "--strict", "--recursive", "Sources", "Tests"])
    return [line for line in output.splitlines() if ": warning:" in line or ": error:" in line]


def lint_findings() -> list[str]:
    """Length, nesting and complexity limits from .swiftlint.yml."""
    if not shutil.which("swiftlint"):
        return ["SwiftLint is missing: brew install swiftlint"]
    _, output = run(["swiftlint", "lint", "--quiet", "--strict"])
    return [line for line in output.splitlines() if ": warning:" in line or ": error:" in line]


def compiler_findings() -> list[str]:
    command = [
        "swift", "build", "--scratch-path", BUILD_FOLDER,
        "-Xswiftc", "-warnings-as-errors",
    ]
    status, output = run(command)
    findings = sorted({
        line for line in output.splitlines()
        if re.search(r"\.swift:\d+:\d+: (?:warning|error):", line)
    })
    if status != 0 and not findings:
        findings = [output.strip().splitlines()[-1]]
    return findings


XCODE_HINT = (
    "The tools point to the Command Line Tools, which lack SwiftUI's macros for macOS 27.\n"
    "Install Xcode 27 and switch once: sudo xcode-select --switch /Applications/Xcode.app"
)


def uses_xcode() -> bool:
    developer_folder = os.environ.get("DEVELOPER_DIR") or run(["xcode-select", "--print-path"])[1]
    return "Xcode" in developer_folder


def swift_test_command(*options: str) -> list[str]:
    return ["swift", "test", "--scratch-path", BUILD_FOLDER, *options]


def test_findings() -> list[str]:
    status, output = run(swift_test_command())
    failures = [line.strip() for line in output.splitlines() if "✘" in line or ": error:" in line]
    if status != 0 and not failures:
        failures = [output.strip().splitlines()[-1]]
    return failures


def coverage_report() -> list[str]:
    """Runs the tests with coverage and prints how much of each source folder they reach."""
    status, output = run(swift_test_command("--enable-code-coverage"))
    if status != 0:
        return [output.strip().splitlines()[-1]]
    _, report_path = run(["swift", "test", "--scratch-path", BUILD_FOLDER, "--show-codecov-path"])
    report = json.loads(Path(report_path.strip().splitlines()[-1]).read_text())
    covered_per_folder = Counter()
    lines_per_folder = Counter()
    for source in report["data"][0]["files"]:
        if f"{SOURCES}/" not in source["filename"]:
            continue
        folder = source["filename"].split(f"{SOURCES}/", 1)[1].split("/", 1)[0]
        covered_per_folder[folder] += source["summary"]["lines"]["covered"]
        lines_per_folder[folder] += source["summary"]["lines"]["count"]
    for folder in sorted(lines_per_folder):
        share = covered_per_folder[folder] / lines_per_folder[folder]
        print(f"  {folder:<14} {share:6.1%}  ({covered_per_folder[folder]} of {lines_per_folder[folder]} lines)")
    total_share = sum(covered_per_folder.values()) / sum(lines_per_folder.values())
    print(f"  {'all':<14} {total_share:6.1%}")
    return []


def design_findings() -> list[str]:
    findings = []
    for relative, place, line, code in numbered_lines(swift_files()):
        if FONT.search(code) and not relative.startswith(DESIGN_FOLDER):
            findings.append(f"{place}: font set directly, use .textRole(...)")
        if relative != TOKENS_FILE and SYMBOL_NAME.search(line) and not NOT_A_SYMBOL.search(line):
            findings.append(f"{place}: symbol name outside Symbols in Tokens.swift")
        if relative != MOTION_FILE and ANIMATION.search(code) and "Motion." not in code:
            findings.append(f"{place}: animation outside Motion.swift")
        if WRITTEN_UI_TEXT.search(line):
            findings.append(f"{place}: written-out text on screen, use TextKey")
        if OWN_SURFACE.search(code) and not relative.startswith(DESIGN_FOLDER):
            findings.append(f"{place}: own glass, material or background, use .surface()/.appButton()")
        if PRINT.search(code) and not relative.startswith(DIAGNOSTICS_FOLDER):
            findings.append(f"{place}: output outside Diagnostics could show private names")
    return findings


def property_list_findings() -> list[str]:
    files = [PROJECT / "Info.plist", *sorted((PROJECT / "Resources").glob("*.lproj/*.strings"))]
    _, output = run(["plutil", "-lint", *map(str, files)])
    return [line for line in output.splitlines() if not line.endswith(": OK")]


def shell_script_findings() -> list[str]:
    scripts = [PROJECT / "build.sh", *sorted((PROJECT / "scripts").glob("*.sh"))]
    findings = []
    for script in scripts:
        status, output = run(["bash", "-n", str(script)])
        if status != 0:
            findings.append(output.strip())
    # A dry run reads every short command in the Makefile without running one.
    targets = re.findall(r"^([a-z]+):", (PROJECT / "Makefile").read_text(), re.MULTILINE)
    status, output = run(["make", "--dry-run", *targets])
    if status != 0:
        findings.append(output.strip().splitlines()[-1])
    return findings


def rule_findings() -> list[str]:
    findings = []
    for relative, place, line, code in numbered_lines(swift_files() + test_files()):
        is_test = place.startswith("Tests/")
        if len(line) > LINE_LENGTH:
            findings.append(f"{place}: line longer than {LINE_LENGTH} characters")
        # Tests may use plain example values; the app's code may not.
        uses_example_numbers = is_test or relative == DEMO_FILE
        if not uses_example_numbers and not NAMED_CONSTANT.match(code) and not AVAILABILITY.search(code):
            for literal in NUMBER.findall(code):
                if literal.replace("_", "") not in {"0", "1"}:
                    findings.append(f"{place}: number {literal} has no name")
        if not is_test and relative != THEME_FILE and COLOUR_OUTSIDE_THEME.search(code):
            findings.append(f"{place}: colour defined outside Theme.swift")
        if any(GERMAN_LETTER.search(text) for text in string_literals(line)):
            findings.append(f"{place}: German text in code, it belongs in the translations")
        if line.rstrip().endswith("// DBG"):
            findings.append(f"{place}: temporary debug line left in the code")
        if ANONYMOUS_PARAMETER.search(code):
            findings.append(f"{place}: $0 instead of a named closure parameter")
        for match in SHORT_CLOSURE_PARAMETERS.finditer(code):
            names = [name.strip() for name in match.group(1).split(",")]
            for name in names:
                if name not in ALLOWED_SHORT_NAMES and name != "_":
                    findings.append(f"{place}: short name '{name}'")
        for match in SHORT_DECLARATION.finditer(code):
            name = match.group(1) or match.group(2)
            if name not in ALLOWED_SHORT_NAMES:
                findings.append(f"{place}: short name '{name}'")
    return findings


def dead_code_findings() -> list[str]:
    code_lines = {
        path: [strip_comments_and_strings(line) for line in path.read_text().splitlines()]
        for path in swift_files()
    }
    words = Counter(
        word for lines in code_lines.values() for line in lines
        for word in re.findall(r"[A-Za-z_]\w*", line)
    )
    findings = []
    for path, lines in code_lines.items():
        listed_enum_indent = None
        for number, line in enumerate(lines, start=1):
            indent = len(line) - len(line.lstrip())
            if listed_enum_indent is not None and line.strip() == "}" and indent == listed_enum_indent:
                listed_enum_indent = None
            if re.search(r"\benum\b.*\bCaseIterable\b", line):
                listed_enum_indent = indent
                continue
            if listed_enum_indent is not None and re.match(r"\s*case\b", line):
                continue  # every case of a CaseIterable enum is used through allCases
            if re.match(r"\s*case\b.*:\s*$", line) or "@main" in lines[number - 2]:
                continue  # a pattern in a switch, or the app's entry point that macOS starts
            if "@NSApplicationDelegateAdaptor" in line:
                continue  # SwiftUI creates and keeps the app delegate itself
            for match in DECLARATION.finditer(line):
                name = match.group(1)
                if words[name] == 1 and name not in CALLED_BY_THE_SYSTEM:
                    place = f"Sources/{path.relative_to(SOURCES).as_posix()}:{number}"
                    findings.append(f"{place}: '{name}' is declared but never used")
    return findings + unused_text_findings(words)


def unused_text_findings(words: Counter) -> list[str]:
    text_keys = SOURCES / "Localization" / "TextKey.swift"
    findings = []
    for number, line in enumerate(text_keys.read_text().splitlines(), start=1):
        listed = re.match(r"\s*case\s+(.+)", strip_comments_and_strings(line))
        for name in (listed.group(1).split(",") if listed else []):
            if words[name.strip()] == 1:
                place = f"Sources/Localization/TextKey.swift:{number}"
                findings.append(f"{place}: text '{name.strip()}' is never shown")
    return findings


STEPS = [
    ("format", "Formatting (swift format)", formatting_findings),
    ("lint", "Length, nesting and complexity (SwiftLint)", lint_findings),
    ("compiler", "Compiler warnings and errors", compiler_findings),
    ("tests", "Unit tests (Swift Testing)", test_findings),
    ("rules", "House rules", rule_findings),
    ("design", "Design rules", design_findings),
    ("deadcode", "Dead code", dead_code_findings),
    ("plists", "Translation files and Info.plist (plutil)", property_list_findings),
    ("scripts", "Shell scripts and Makefile (bash -n, make -n)", shell_script_findings),
]
# Reports that only run when asked for by name, like `scripts/inspect.py coverage`.
EXTRA_STEPS = [
    ("coverage", "Test coverage per folder", coverage_report),
]


def main() -> int:
    """Without arguments every step runs; `scripts/inspect.py tests rules` runs only those."""
    chosen = sys.argv[1:] or [key for key, _, _ in STEPS]
    known = [key for key, _, _ in STEPS + EXTRA_STEPS]
    unknown = [key for key in chosen if key not in known]
    if unknown:
        print(f"Unknown step: {', '.join(unknown)}. Steps: {', '.join(known)}")
        return 2
    if not uses_xcode():
        print(XCODE_HINT)
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
