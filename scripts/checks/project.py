"""What every check needs: the files to read, the compiler's index and a way to run a tool.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 for the index
A Codebase names the files one run of the checks reads. The app is one codebase; the samples in
checks/samples, which hold a mistake for every rule, are another, so the checks can test
themselves (see checks/samples.py).
"""

import json
import os
import re
import subprocess
from dataclasses import dataclass
from functools import cache
from pathlib import Path

from checks import console
from checks.index_store import IndexStore, Occurrence

# MARK: Settings

PROJECT = Path(__file__).resolve().parents[2]
SCRIPTS = PROJECT / "scripts"
SAMPLES = SCRIPTS / "checks" / "samples"
MAKEFILE = PROJECT / "Makefile"
SHELL_LINE = re.compile(r"#!.*\b(?:sh|bash|zsh|dash|ksh)\b")  # the first line of a shell script
BUILD_FOLDER = PROJECT / ".build" / "check"

# Building and testing share one configuration, so neither step rebuilds what the other built.
BUILD_OPTIONS = (
    "--scratch-path", str(BUILD_FOLDER),  # a build folder of its own, apart from make build
    "--enable-index-store",  # the compiler's index, which several steps read
    "-Xswiftc", "-warnings-as-errors",  # a single warning already fails the build
    "--enable-code-coverage",  # the tests measure what they reach, for the coverage step
)

# The longest line allowed, in Swift code and in every script; swift format reads the same value.
LINE_LENGTH = json.loads((PROJECT / ".swift-format").read_text())["lineLength"]

# A line a tool prints for a problem, such as "File.swift:12:5: warning: …".
TOOL_DIAGNOSTIC = re.compile(r": (?:warning|error):")

# Colors and links that tools write into their output for a terminal; they hide the words above.
TERMINAL_FORMATTING = re.compile(r"""
    \x1b \[ [0-9;]* m              # a color: ESC [ 1;31 m
    | \x1b \] 8 ;; [^\x1b]* \x1b \\  # a link: ESC ] 8 ;; address ESC \
""", re.VERBOSE)


# MARK: Codebases


@dataclass(frozen=True)
class Codebase:
    """The files one run of the checks reads, and how to build its Swift code."""

    package: Path  # the folder with Package.swift
    build_folder: Path
    build_options: tuple[str, ...]
    swift_sources: tuple[Path, ...]  # the app's code: every rule applies
    swift_tests: tuple[Path, ...] = ()
    swift_scripts: tuple[Path, ...] = ()
    python_scripts: tuple[Path, ...] = ()
    shell_scripts: tuple[Path, ...] = ()
    makefiles: tuple[Path, ...] = ()
    source_root: Path | None = None  # its folders are the layers of the architecture
    guides: tuple[Path, ...] = ()  # the Markdown files
    translations: Path | None = None  # the folder with one <language>.lproj per language
    text_files: tuple[Path, ...] = ()  # every file that could carry a secret
    workflows: tuple[Path, ...] = ()  # the GitHub workflows and the actions they share

    def swift_files(self) -> tuple[Path, ...]:
        return self.swift_sources + self.swift_tests + self.swift_scripts

    def all_scripts(self) -> tuple[Path, ...]:
        return self.shell_scripts + self.python_scripts + self.swift_scripts + self.makefiles


def files(folder: Path, pattern: str) -> tuple[Path, ...]:
    """The files below a folder, without the samples, which are not part of the project."""
    return tuple(sorted(path for path in folder.rglob(pattern) if not path.is_relative_to(SAMPLES)))


@cache
def app() -> Codebase:
    return Codebase(
        package=PROJECT,
        build_folder=BUILD_FOLDER,
        build_options=("--build-tests", *BUILD_OPTIONS),
        swift_sources=files(PROJECT / "Sources", "*.swift"),
        swift_tests=files(PROJECT / "Tests", "*.swift"),
        swift_scripts=files(SCRIPTS, "*.swift"),
        # The hooks are Python too; only what git knows, never a cache Python leaves beside them.
        python_scripts=(*files(SCRIPTS, "*.py"), *tracked_files("scripts/hooks/*")),
        # None: the tools are Python (CLAUDE.md); check.py reports any that appears.
        shell_scripts=tuple(filter(is_shell_script, tracked_files("*"))),
        makefiles=(MAKEFILE,),
        source_root=PROJECT / "Sources",
        guides=tracked_files("*.md"),
        translations=PROJECT / "Resources",
        text_files=tracked_files("*"),
        workflows=(*tracked_files(".github/workflows/*.yml"),
                   *tracked_files(".github/actions/*/action.yml")),
    )


def tracked_files(pattern: str) -> tuple[Path, ...]:
    """The files git knows, so build folders and local notes stay out; never the samples."""
    names = run(["git", "ls-files", pattern]).output.splitlines()
    paths = (PROJECT / name for name in names)
    return tuple(sorted(path for path in paths if not path.is_relative_to(SAMPLES)))


# MARK: Reading files


def is_text(path: Path) -> bool:
    """A file that reads as text; images, icons and other binary files do not. The lines stay
    cached, so the checks that read the file next do not read it again."""
    try:
        lines_of(path)
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return False
    return True


def is_shell_script(path: Path) -> bool:
    """A .sh file, or a text file whose first line starts a shell, such as #!/usr/bin/env bash."""
    if path.suffix == ".sh":
        return True
    first_line = lines_of(path)[:1] if is_text(path) else []
    return any(SHELL_LINE.match(line) for line in first_line)


@cache
def lines_of(path: Path) -> list[str]:
    return path.read_text().splitlines()


def numbered_lines(paths):
    """Each line of the files with its file and its number, counted from 1."""
    for path in paths:
        for number, line in enumerate(lines_of(path), start=1):
            yield path, number, line


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
            return [self.last_line() or "the tool failed without saying why"]
        return readable_findings

    def last_line(self) -> str:
        return self.output.strip().rpartition("\n")[2]


def run(command: list[str], given_input: str | None = None) -> ToolResult:
    result = subprocess.run(command, cwd=PROJECT, input=given_input, capture_output=True, text=True)
    output = TERMINAL_FORMATTING.sub("", result.stdout + result.stderr)
    return ToolResult(result.returncode == 0, output)


def has_xcode() -> bool:
    """SwiftUI's macros for macOS 27 ship only with Xcode; without it, says how to switch."""
    # DEVELOPER_DIR is Apple's name for a chosen Xcode; without it, xcode-select knows.
    developer_folder = os.environ.get("DEVELOPER_DIR") or run(["xcode-select", "-p"]).output
    if "Xcode" in developer_folder:
        return True
    console.stopped("Xcode 27 is needed", "the developer tools point elsewhere", (
        "Install it, then switch once:", "sudo xcode-select --switch /Applications/Xcode.app"))
    return False


# MARK: The compiler's index


@dataclass(frozen=True)
class CompilerIndex:
    """Every declaration and use in a codebase's files, or why its build failed."""

    occurrences: tuple[Occurrence, ...]
    build_problems: tuple[str, ...]


@cache
def compiler_index(codebase: Codebase) -> CompilerIndex:
    """Builds the codebase (nothing happens when it is current) and reads the index once."""
    command = ["swift", "build", "--package-path", str(codebase.package), *codebase.build_options]
    result = run(command)
    if not result.succeeded:
        return CompilerIndex((), tuple(result.findings(result.diagnostics())))
    store = IndexStore(next(codebase.build_folder.glob("**/index/store")))
    return CompilerIndex(tuple(store.occurrences(inside=codebase.package)), ())
