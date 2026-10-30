"""Prints the results of the check pipeline so anyone can read them at a glance.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
Each step gets one line with a mark, its number of findings and how long it took; its findings
follow, grouped by file. A frame at the end sums up. The pieces and colors come from
console.py, the shared look of every command. On GitHub every finding also becomes an annotation
beside its line in the pull request.
"""

import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from checks import console
from checks.console import DIM, FAILED_MARK, FAILURE, ON_GITHUB, PASSED_MARK, RED, SUCCESS, paint
from checks.project import PROJECT

# MARK: Settings

TITLE_WIDTH = 50  # the step titles fill this many characters, so the counts line up
COUNT_WIDTH = 11  # wide enough for "99 findings"

# A finding that names its place: "Sources/File.swift:12: message"; tools may add a column
# ("…:12:5: error: …") and write the whole path.
PLACED_FINDING = re.compile(r"""
    ^ (?P<path> [^:\s]+ ) : (?P<line> \d+ )         # the file and the line
    (?: : \d+ )? : \s*                              # maybe the column
    (?P<message> .+ ) $                             # what is wrong
""", re.VERBOSE)
GENERAL = "general"  # the group of findings that name no file


# MARK: Pieces


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
    console.heading("Speicher-Explorer · check pipeline", plural(step_count, "step"))


def step_finished(title: str, findings: list[str], seconds: float) -> None:
    count = paint(plural(len(findings), "finding").ljust(COUNT_WIDTH), RED if findings else DIM)
    result = console.failed if findings else console.passed
    result(f"{title.ljust(TITLE_WIDTH)} {count}", f"{seconds:.1f} s")
    for path, group in sorted(by_file(findings).items()):
        print_group(path, group, title)


def print_group(path: str, group: list[Finding], title: str) -> None:
    console.group(path)
    for finding in sorted(group, key=lambda finding: finding.line):
        console.entry(str(finding.line) if finding.line else "", finding.message)
        if ON_GITHUB and finding.path != GENERAL:
            console.data(github_annotation(finding, title))
    console.show("")


def github_annotation(finding: Finding, title: str) -> str:
    """A line GitHub turns into a note beside the finding's line in the pull request."""
    return f"::error file={finding.path},line={finding.line},title={title}::{finding.message}"


def summary(results: list[tuple[str, int]]) -> None:
    """A frame with the outcome: every step passed, or how many findings came from which steps."""
    failed = [(title, count) for title, count in results if count]
    if not failed:
        steps = f"All {len(results)} steps" if len(results) > 1 else "The step"
        console.frame([f"{PASSED_MARK} {steps} passed: no errors, no warnings"], SUCCESS)
        return
    total = sum(count for _, count in failed)
    lines = [f"{FAILED_MARK} {plural(total, 'finding')} in {len(failed)} of {len(results)} steps"]
    lines += [f"  {title}: {count}" for title, count in failed]
    console.frame(lines, FAILURE)
