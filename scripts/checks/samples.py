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

from checks.dead_code import dead_code_problems
from checks.house_rules import design_problems, house_rule_problems
from checks.language import language_problems
from checks.project import PROJECT, SAMPLES, Codebase, lines_of, place
from checks.tools import script_layout_problems

# MARK: Settings

BUILD_FOLDER = PROJECT / ".build" / "check-samples"

# The note on a planted mistake: "expect: is short for", or "expect below: …" for the next line.
EXPECTATION = re.compile(r"""
    expect (?P<below> \s below )? :     # expect: or expect below:
    \s* (?P<part> .+? ) \s* $           # the part of the finding that must appear
""", re.VERBOSE)

# The checks that read code; the tool steps (formatting, tests) have samples of their own.
CHECKS = [
    house_rule_problems, design_problems, dead_code_problems, language_problems,
    script_layout_problems,
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
    )


def expectations(codebase: Codebase) -> list[tuple[str, str]]:
    """Each planted mistake: where it is and the part of the finding it must produce."""
    expected = []
    for path in codebase.swift_sources + codebase.python_scripts + codebase.shell_scripts:
        for number, line in enumerate(lines_of(path), start=1):
            note = EXPECTATION.search(line)
            if note:
                line_of_mistake = number + 1 if note["below"] else number
                expected.append((place(path, line_of_mistake), note["part"]))
    return expected


def matches(finding: str, where: str, part: str) -> bool:
    return finding.startswith(f"{where}:") and part in finding


# MARK: Step


def sample_findings() -> list[str]:
    codebase = samples()
    found = [finding for check in CHECKS for finding in check(codebase)]
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
