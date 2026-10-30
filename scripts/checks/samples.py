"""Tests the checks themselves: each rule must find the mistake planted for it in checks/samples.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27, to build the samples' own small package
Every planted mistake carries a note on its line, `expect: <part of the finding>`, or on the line
above it, `expect below: …`. The step fails when a check no longer finds a planted mistake, or
when it finds something nobody planted. The samples never belong to the app: nothing builds or
ships them except this step.
"""

import re
from pathlib import Path

from checks.accessibility import accessibility_problems
from checks.architecture import architecture_problems
from checks.commits import CommitMessage, commit_problems
from checks.dead_code import dead_code_problems
from checks.disk_access import disk_access_problems
from checks.duplicates import duplicate_problems
from checks.guides import guide_problems
from checks.house_rules import design_problems, house_rule_problems
from checks.language import language_problems
from checks.nesting import nesting_problems
from checks.promises import promise_problems
from checks.secrets import secret_problems
from checks.translations import translation_problems
from checks.unused_files import unused_file_problems
from checks.project import PROJECT, SAMPLES, Codebase, lines_of, numbered_lines, place
from checks.tools import script_layout_problems

# MARK: Settings

BUILD_FOLDER = PROJECT / ".build" / "check-samples"
COMMIT_SAMPLES = SAMPLES / "commits.txt"  # messages kept apart by lines of three dashes
MESSAGE_SEPARATOR = "---"

# The note on a planted mistake: "expect: is short for", or "expect below: …" for the next line.
EXPECTATION = re.compile(r"""
    expect (?P<below> \s below )? :     # expect: or expect below:
    \s* (?P<part> .+? )                 # the part of the finding that must appear
    \s* (?: --> | \*/ )? \s* $          # the end of the note, or of a comment around it
""", re.VERBOSE)

# The checks that read code; the tool steps (formatting, tests) have samples of their own.
CHECKS = [
    house_rule_problems, design_problems, dead_code_problems, language_problems,
    nesting_problems, script_layout_problems, duplicate_problems, architecture_problems,
    promise_problems, guide_problems, accessibility_problems, translation_problems,
    secret_problems, disk_access_problems, unused_file_problems,
]


# MARK: Steps


def samples() -> Codebase:
    return Codebase(
        package=SAMPLES,
        build_folder=BUILD_FOLDER,
        build_options=("--scratch-path", str(BUILD_FOLDER), "--enable-index-store"),
        swift_sources=tuple(sorted((SAMPLES / "Sources").rglob("*.swift"))),
        python_scripts=(SAMPLES / "sample.py",),
        shell_scripts=(SAMPLES / "sample.sh",),
        source_root=SAMPLES / "Sources" / "Samples",
        guides=tuple(sorted((SAMPLES / "guides").glob("*.md"))),
        translations=SAMPLES / "Resources",
        text_files=(SAMPLES / "settings.txt", SAMPLES / "assets" / "orphan.svg", COMMIT_SAMPLES),
    )


def expectations(codebase: Codebase) -> list[tuple[str, str]]:
    """Each planted mistake: where it is and the part of the finding it must produce."""
    expected = []
    strings = tuple(sorted(codebase.translations.glob("*.lproj/*.strings")))
    paths = (
        codebase.swift_sources + codebase.python_scripts + codebase.shell_scripts
        + codebase.guides + strings + codebase.text_files
    )
    for path, number, line in numbered_lines(paths):
        note = EXPECTATION.search(line)
        if note:
            line_of_mistake = number + 1 if note["below"] else number
            expected.append((place(path, line_of_mistake), note["part"]))
    return expected


def commit_samples(codebase: Codebase) -> list[str]:
    """The commit check, run on the sample messages; lines starting with # are notes, as git
    leaves them out of a message too."""
    messages, kept, first_line = [], [], 0
    for number, line in enumerate(lines_of(COMMIT_SAMPLES) + [MESSAGE_SEPARATOR], start=1):
        if line == MESSAGE_SEPARATOR:
            messages.append(CommitMessage(place(COMMIT_SAMPLES, first_line), "\n".join(kept)))
            kept = []
        elif not line.startswith("#"):
            first_line = first_line if kept else number
            kept.append(line)
    return commit_problems(messages)


def matches(finding: str, where: str, part: str) -> bool:
    return finding.startswith(f"{where}:") and part in finding


# MARK: Step


def sample_findings() -> list[str]:
    codebase = samples()
    found = [finding for check in CHECKS + [commit_samples] for finding in check(codebase)]
    expected = expectations(codebase)
    problems = [
        f"{where}: no check finds '{part}' any more"
        for where, part in expected
        if not any(matches(finding, where, part) for finding in found)
    ]
    problems += [
        f"not planted, but found in the samples: {finding}"
        for finding in found
        if not any(matches(finding, where, part) for where, part in expected)
    ]
    return problems
