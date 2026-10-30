"""Prints the results of the check pipeline so anyone can read them at a glance.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
Each step gets one line with a mark, its number of findings and how long it took; its findings
follow, grouped by file. A frame at the end sums up. Colors appear in a terminal and on GitHub,
NO_COLOR=1 turns them off and FORCE_COLOR=1 turns them on (see no-color.org). On GitHub every
finding also becomes an annotation beside its line in the pull request.
"""

import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from checks.project import PROJECT

# MARK: Settings

ON_GITHUB = os.environ.get("GITHUB_ACTIONS") == "true"
IN_TERMINAL = sys.stdout.isatty()
USES_COLOR = "NO_COLOR" not in os.environ and (
    IN_TERMINAL or ON_GITHUB or "FORCE_COLOR" in os.environ
)

# Terminal codes for text styles (ECMA-48 "select graphic rendition").
BOLD, DIM, RED, GREEN, YELLOW, CYAN = "1", "2", "31", "32", "33", "36"

PASSED_MARK = "✔"
FAILED_MARK = "✘"
RUNNING_MARK = "…"
FILE_MARK = "▸"
TITLE_WIDTH = 50  # the step titles fill this many characters, so the counts line up
COUNT_WIDTH = 11  # wide enough for "99 findings"
LINE_NUMBER_WIDTH = 5
CLEAR_LINE = "\r\x1b[K"  # back to the start of the line and erase it

# A finding that names its place: "Sources/File.swift:12: message"; tools may add a column
# ("…:12:5: error: …") and write the whole path.
PLACED_FINDING = re.compile(r"""
    ^ (?P<path> [^:\s][^:]* ) : (?P<line> \d+ )     # the file and the line
    (?: : \d+ )? : \s*                              # maybe the column
    (?P<message> .+ ) $                             # what is wrong
""", re.VERBOSE)
GENERAL = "general"  # the group of findings that name no file


# MARK: Pieces


def paint(text: str, *styles: str) -> str:
    if not USES_COLOR or not styles:
        return text
    return f"\x1b[{';'.join(styles)}m{text}\x1b[0m"


def visible_length(text: str) -> int:
    return len(re.sub(r"\x1b\[[0-9;]*m", "", text))


def plural(count: int, word: str) -> str:
    return f"{count} {word}" if count == 1 else f"{count} {word}s"


@dataclass(frozen=True)
class Finding:
    path: str  # relative to the project, or GENERAL
    line: int
    message: str


def parsed(finding: str) -> Finding:
    match = PLACED_FINDING.match(finding)
    if not match:
        return Finding(GENERAL, 0, finding)
    path = Path(match["path"])
    if path.is_absolute() and path.is_relative_to(PROJECT):
        path = path.relative_to(PROJECT)
    return Finding(path.as_posix(), int(match["line"]), match["message"])


def by_file(findings: list[str]) -> dict[str, list[Finding]]:
    groups = defaultdict(list)
    for finding in map(parsed, findings):
        groups[finding.path].append(finding)
    return groups


# MARK: What check.py prints


def header(step_count: int) -> None:
    title = paint("Speicher-Explorer · check pipeline", BOLD)
    print(f"\n{title}  {paint(plural(step_count, 'step'), DIM)}\n")


def step_started(title: str) -> None:
    """A dim line while the step runs, replaced by its result in a terminal."""
    if IN_TERMINAL:
        print(paint(f" {RUNNING_MARK} {title}", DIM), end="", flush=True)


def step_finished(title: str, findings: list[str], seconds: float) -> None:
    if IN_TERMINAL:
        print(CLEAR_LINE, end="")
    mark = paint(FAILED_MARK, RED, BOLD) if findings else paint(PASSED_MARK, GREEN, BOLD)
    count = paint(plural(len(findings), "finding").ljust(COUNT_WIDTH), RED if findings else DIM)
    print(f" {mark} {title.ljust(TITLE_WIDTH)} {count}  {paint(f'{seconds:.1f} s', DIM)}")
    for path, group in sorted(by_file(findings).items()):
        print_group(path, group, title)


def print_group(path: str, group: list[Finding], title: str) -> None:
    print(f"     {paint(FILE_MARK, CYAN)} {paint(path, CYAN, BOLD)}")
    for finding in sorted(group, key=lambda finding: finding.line):
        line = str(finding.line) if finding.line else ""
        print(f"       {paint(line.rjust(LINE_NUMBER_WIDTH), DIM)}  {finding.message}")
        if ON_GITHUB and finding.path != GENERAL:
            print(github_annotation(finding, title))
    print()


def github_annotation(finding: Finding, title: str) -> str:
    """A line GitHub turns into a note beside the finding's line in the pull request."""
    return f"::error file={finding.path},line={finding.line},title={title}::{finding.message}"


def summary(results: list[tuple[str, int]]) -> None:
    """A frame with the outcome: every step passed, or how many findings came from which steps."""
    failed = [(title, count) for title, count in results if count]
    if not failed:
        steps = f"All {len(results)} steps" if len(results) > 1 else "The step"
        frame([f"{PASSED_MARK} {steps} passed: no errors, no warnings"], GREEN)
        return
    total = sum(count for _, count in failed)
    lines = [f"{FAILED_MARK} {plural(total, 'finding')} in {len(failed)} of {len(results)} steps"]
    lines += [f"  {title}: {count}" for title, count in failed]
    frame(lines, RED)


def frame(lines: list[str], color: str) -> None:
    width = max(visible_length(line) for line in lines) + 2
    print("\n " + paint("╭" + "─" * width + "╮", color))
    side = paint("│", color)
    for line in lines:
        padding = " " * (width - visible_length(line) - 1)
        print(f" {side} {paint(line, color, BOLD)}{padding}{side}")
    print(" " + paint("╰" + "─" * width + "╯", color) + "\n")
