"""Finds code written twice: the same run of lines in two places, which belongs in one method.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
Every file is read as a list of lines with substance; blank lines, comments, lone brackets and
lines with a single word do not count, and numbers and texts are treated as equal, so a copy that
only changed a value is still found. When the same REPEATED_LINES lines of substance stand in two
places, the second place is reported with a pointer to the first.
"""

import re
from dataclasses import dataclass
from pathlib import Path

from checks.project import Codebase, app, lines_of, place

# MARK: Settings

REPEATED_LINES = 6
# A line counts when it holds at least this many words and values: `self.items = items()` does,
# `} label: {` does not. Declarations alone in a list of constants never repeat with the same names.
WORDS_IN_A_LINE = 3

COMMENT = re.compile(r"//.*$|#.*$")
TEXT = re.compile(r'"(?:\\.|[^"\\])*"')
NUMBER = re.compile(r"\b\d[\d_.]*\b")
WORD = re.compile(r"\b[A-Za-z_]\w*\b")
NAME = re.compile(r"[A-Za-z_]")  # a line of values only, such as a row of a color table, is data


# MARK: Lines with substance


@dataclass(frozen=True)
class Line:
    path: Path
    number: int
    text: str  # with numbers and texts made equal


def lines_with_substance(path: Path) -> list[Line]:
    lines = []
    for number, written in enumerate(lines_of(path), start=1):
        code = COMMENT.sub("", TEXT.sub('"…"', written)).strip()
        code = NUMBER.sub("0", code)
        has_substance = len(WORD.findall(code)) >= WORDS_IN_A_LINE and NAME.search(code)
        if has_substance:
            lines.append(Line(path, number, code))
    return lines


# MARK: Step


def duplicate_findings() -> list[str]:
    return duplicate_problems(app())


def duplicate_problems(codebase: Codebase) -> list[str]:
    paths = codebase.swift_files() + codebase.python_scripts + codebase.shell_scripts
    first_places: dict[tuple, Line] = {}  # each run of lines and where it stood first
    findings = []
    for path in paths:
        findings += copies_in(lines_with_substance(path), first_places)
    return findings


def copies_in(lines: list[Line], first_places: dict[tuple, Line]) -> list[str]:
    """Each run of lines in a file that stood somewhere before; a long copy is reported once."""
    findings, covered = [], set()
    for start in range(len(lines) - REPEATED_LINES + 1):
        run_of_lines = lines[start:start + REPEATED_LINES]
        key = tuple(line.text for line in run_of_lines)
        earlier = first_places.setdefault(key, run_of_lines[0])
        is_new_copy = earlier is not run_of_lines[0] and run_of_lines[0].number not in covered
        if is_new_copy:
            findings.append(copy_finding(run_of_lines, earlier))
            covered.update(line.number for line in run_of_lines)
    return findings


def copy_finding(run_of_lines: list[Line], earlier: Line) -> str:
    first, last = run_of_lines[0], run_of_lines[-1]
    return (
        f"{place(first.path, first.number)}: lines {first.number}–{last.number} repeat "
        f"{place(earlier.path, earlier.number)}; move them into one method both places call"
    )
