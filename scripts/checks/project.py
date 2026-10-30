"""What every check needs: the project's folders, its files and a way to run a tool.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
"""

import json
import re
import subprocess
from dataclasses import dataclass
from functools import cache
from pathlib import Path

# MARK: Settings

PROJECT = Path(__file__).resolve().parents[2]
SOURCES = PROJECT / "Sources"
TESTS = PROJECT / "Tests"
SCRIPTS = PROJECT / "scripts"
MAKEFILE = PROJECT / "Makefile"
BUILD_FOLDER = PROJECT / ".build" / "check"

# Building and testing share one configuration, so neither step rebuilds what the other built.
BUILD_OPTIONS = [
    "--scratch-path", str(BUILD_FOLDER),  # a build folder of its own, apart from build.sh
    "--enable-index-store",  # the compiler's index, which the dead-code step reads
    "-Xswiftc", "-warnings-as-errors",  # a single warning already fails the build
]

# The longest line allowed, in Swift code and in every script; swift format reads the same value.
LINE_LENGTH = json.loads((PROJECT / ".swift-format").read_text())["lineLength"]

# A line a tool prints for a problem, such as "File.swift:12:5: warning: …".
TOOL_DIAGNOSTIC = re.compile(r": (?:warning|error):")


# MARK: Files


def swift_sources() -> list[Path]:
    return sorted(SOURCES.rglob("*.swift"))


def swift_tests() -> list[Path]:
    return sorted(TESTS.rglob("*.swift"))


def swift_scripts() -> list[Path]:
    return sorted(SCRIPTS.rglob("*.swift"))


def python_scripts() -> list[Path]:
    return sorted(SCRIPTS.rglob("*.py"))


def shell_scripts() -> list[Path]:
    return [PROJECT / "build.sh", *sorted(SCRIPTS.glob("*.sh"))]


def all_scripts() -> list[Path]:
    """Every script and the Makefile."""
    return [*shell_scripts(), *python_scripts(), *swift_scripts(), MAKEFILE]


@cache
def lines_of(path: Path) -> list[str]:
    return path.read_text().splitlines()


def relative_path(path: Path) -> str:
    return path.relative_to(PROJECT).as_posix()


def place(path: Path, line_number: int) -> str:
    """Where a finding is, in the form editors open with a click: Sources/File.swift:12."""
    return f"{relative_path(path)}:{line_number}"


# MARK: Running tools


@dataclass(frozen=True)
class ToolResult:
    succeeded: bool
    output: str

    def diagnostics(self) -> list[str]:
        """The warnings and errors the tool printed, each once."""
        return sorted({line for line in self.output.splitlines() if TOOL_DIAGNOSTIC.search(line)})

    def findings(self, readable_findings: list[str]) -> list[str]:
        """The findings; when the tool failed without one, its last line tells why."""
        if not self.succeeded and not readable_findings:
            return [self.output.strip().splitlines()[-1]]
        return readable_findings


def run(command: list[str]) -> ToolResult:
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    return ToolResult(result.returncode == 0, result.stdout + result.stderr)


def has_xcode() -> bool:
    """SwiftUI's macros for macOS 27 ship only with Xcode; the shared script explains how."""
    result = run([str(SCRIPTS / "require-xcode.sh")])
    if not result.succeeded:
        print(result.output.strip())
    return result.succeeded
