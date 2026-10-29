#!/usr/bin/env python3
"""Code inspection: formatting, compiler warnings and the house rules from CODE_STYLE.md.

Run it from anywhere: scripts/inspect.py
It exits with status 1 as soon as one finding is left, so it can guard a commit.
"""

import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
SOURCES = PROJECT / "Sources"
BUILD_FOLDER = os.environ.get("INSPECT_BUILD_FOLDER", str(PROJECT / ".build" / "inspect"))

THEME_FILE = "DesignSystem/Theme.swift"
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


def run(command: list[str]) -> tuple[int, str]:
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def formatting_findings() -> list[str]:
    _, output = run(["swift", "format", "lint", "--strict", "--recursive", "Sources"])
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


def rule_findings() -> list[str]:
    findings = []
    for path in swift_files():
        relative = path.relative_to(SOURCES).as_posix()
        for number, line in enumerate(path.read_text().splitlines(), start=1):
            place = f"Sources/{relative}:{number}"
            code = strip_comments_and_strings(line)
            if not NAMED_CONSTANT.match(code) and not AVAILABILITY.search(code):
                for literal in NUMBER.findall(code):
                    if literal.replace("_", "") not in {"0", "1"}:
                        findings.append(f"{place}: number {literal} has no name")
            if relative != THEME_FILE and COLOUR_OUTSIDE_THEME.search(code):
                findings.append(f"{place}: colour defined outside Theme.swift")
            if any(GERMAN_LETTER.search(text) for text in string_literals(line)):
                findings.append(f"{place}: German text in code, it belongs in the translations")
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


def main() -> int:
    sections = [
        ("Formatting (swift format)", formatting_findings),
        ("Compiler warnings and errors", compiler_findings),
        ("House rules", rule_findings),
        ("Dead code", dead_code_findings),
    ]
    total = 0
    for title, check in sections:
        findings = check()
        total += len(findings)
        print(f"{title}: {len(findings)}")
        for finding in findings:
            print(f"  {finding}")
    print(f"\n{total} findings" if total else "\nNo errors and no warnings.")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
