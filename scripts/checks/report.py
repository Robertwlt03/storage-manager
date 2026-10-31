"""Prints the results of the check pipeline so anyone can read them at a glance.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
Each step gets one line with a mark, its number of findings and how long it took; its findings
follow, grouped by file. A frame at the end sums up. The pieces and colors come from
console.py, the shared look of every command. On GitHub every finding also becomes an annotation
beside its line in the pull request, and the run's summary page gets a table of the steps with
every finding linked to its line.
"""

import os
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from checks import console
from checks.console import DIM, FAILURE, ON_GITHUB, RED, SUCCESS, paint
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
# GitHub's summary page of the job, and where the checked code can be read on GitHub.
SUMMARY_FILE = os.environ.get("GITHUB_STEP_SUMMARY")
CODE_ADDRESS = "{}/{}/blob/{}".format(
    *(os.environ.get(name, "") for name in ("GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_SHA"))
)
# How GitHub's workflow commands write characters that would end a message or a property.
MESSAGE_ESCAPES = {"%": "%25", "\r": "%0D", "\n": "%0A"}
PROPERTY_ESCAPES = MESSAGE_ESCAPES | {":": "%3A", ",": "%2C"}


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
    console.heading("Storage Manager · check pipeline", plural(step_count, "step"))
    write_summary("| | Step | Findings | Time |\n|:-:|---|---|--:|")


def step_finished(title: str, findings: list[str], seconds: float) -> None:
    count = paint(plural(len(findings), "finding").ljust(COUNT_WIDTH), RED if findings else DIM)
    result = console.failed if findings else console.passed
    result(f"{title.ljust(TITLE_WIDTH)} {count}", f"{seconds:.1f} s")
    for path, group in sorted(by_file(findings).items()):
        print_group(path, group, title)
    write_summary(summary_row(title, findings, seconds))


def print_group(path: str, group: list[Finding], title: str) -> None:
    console.group(path)
    for finding in sorted(group, key=lambda finding: finding.line):
        console.entry(str(finding.line) if finding.line else "", finding.message)
        if ON_GITHUB:
            console.data(github_annotation(finding, title))
    console.show("")


def github_annotation(finding: Finding, title: str) -> str:
    """A line GitHub turns into a note beside the finding's line in the pull request, and into a
    line of the run's summary; the message names the place too, as the summary shows only it."""
    if finding.path == GENERAL:
        return f"::error title={escaped(title, PROPERTY_ESCAPES)}::{escaped(finding.message)}"
    message = escaped(f"{finding.path}:{finding.line}: {finding.message}")
    properties = f"file={finding.path},line={finding.line},title={escaped(title, PROPERTY_ESCAPES)}"
    return f"::error {properties}::{message}"


def escaped(text: str, escapes: dict[str, str] = MESSAGE_ESCAPES) -> str:
    """GitHub reads % and line breaks in a message as escapes, and also : and , in a property."""
    return "".join(escapes.get(character, character) for character in text)


# MARK: GitHub's summary page


def write_summary(line: str) -> None:
    """Adds a line to the job's summary page on GitHub; elsewhere there is none."""
    if SUMMARY_FILE:
        with open(SUMMARY_FILE, "a", encoding="utf-8") as page:
            page.write(line + "\n")


def summary_row(title: str, findings: list[str], seconds: float) -> str:
    """One step as a table row: its mark, title, findings (each linked to its line) and time."""
    mark = "✘" if findings else "✔"
    cells = [plural(len(findings), "finding"), *map(linked, map(parsed, findings))]
    return f"| {mark} | {title} | {'<br>'.join(cells)} | {seconds:.1f} s |"


def linked(finding: Finding) -> str:
    # A bar would end the table cell, and an angle bracket would open an HTML tag.
    message = finding.message.replace("|", "\\|").replace("<", "&lt;").replace(">", "&gt;")
    if finding.path == GENERAL:
        return message
    place = f"{finding.path}:{finding.line}"
    return f"[{place}]({CODE_ADDRESS}/{finding.path}#L{finding.line}) {message}"


def summary(results: list[tuple[str, int]]) -> None:
    """A frame with the outcome: every step passed, or how many findings came from which steps."""
    failed = [(title, count) for title, count in results if count]
    if not failed:
        steps = f"All {len(results)} steps" if len(results) > 1 else "The step"
        console.frame(f"{steps} passed", ["no errors, no warnings"], SUCCESS)
        return
    total = sum(count for _, count in failed)
    console.frame(
        f"{plural(total, 'finding')} in {len(failed)} of {len(results)} steps",
        [f"{title}: {count}" for title, count in failed],
        FAILURE,
    )
