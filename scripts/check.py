#!/usr/bin/env python3
"""The check pipeline: every rule from CODE_STYLE.md that a tool can check, one step after another.

Start:  make check, or scripts/check.py tests rules for single steps
Needs:  Xcode 27 and SwiftLint (brew install swiftlint)
It ends with status 1 as soon as one finding is left, so it guards every pull request. The steps
live in scripts/checks/: project.py (folders, files, running tools), tools.py, house_rules.py,
nesting.py, dead_code.py with index_store.py, language.py with unknown_words.swift, and
samples.py, which tests the checks themselves on planted mistakes; report.py prints the results.
"""

import sys
import time
from dataclasses import dataclass
from typing import Callable

from checks import dead_code, house_rules, language, nesting, project, report, samples, tools

# MARK: Settings


@dataclass(frozen=True)
class Step:
    name: str  # to start the step alone: scripts/check.py tests
    title: str  # in the report
    check: Callable[[], list[str]]  # returns the findings


STEPS = [
    Step("format", "Formatting (swift format)", tools.formatting_findings),
    Step("lint", "Length, nesting and complexity (SwiftLint)", tools.lint_findings),
    Step("compiler", "Compiler warnings and errors", tools.compiler_findings),
    Step("tests", "Unit tests (Swift Testing)", tools.test_findings),
    Step("rules", "House rules", house_rules.rule_findings),
    Step("design", "Design rules", house_rules.design_findings),
    Step("nesting", "Flat methods (two blocks deep at most)", nesting.nesting_findings),
    Step("deadcode", "Dead code (compiler index)", dead_code.dead_code_findings),
    Step("language", "American English names and comments", language.language_findings),
    Step("plists", "Translation files and Info.plist (plutil)", tools.property_list_findings),
    Step("scripts", "Scripts and Makefile", tools.script_findings),
    Step("samples", "Every planted mistake found (checks/samples)", samples.sample_findings),
]
# Reports that only run when asked for by name, like `scripts/check.py coverage`.
EXTRA_STEPS = [
    Step("coverage", "Test coverage per folder", tools.coverage_report),
]

PASSED, FAILED, UNKNOWN_STEP = 0, 1, 2  # the exit status of the script


# MARK: Steps


def chosen_steps(names: list[str]) -> list[Step] | None:
    """The steps named on the command line, every regular step without names, None for a typo."""
    known = {step.name: step for step in STEPS + EXTRA_STEPS}
    unknown = [name for name in names if name not in known]
    if unknown:
        print(f"Unknown step: {', '.join(unknown)}. Steps: {', '.join(known)}")
        return None
    return [known[name] for name in names] if names else STEPS


def run_steps(steps: list[Step]) -> list[tuple[str, int]]:
    """Runs each step and prints its result; returns each step's title and number of findings."""
    results = []
    for step in steps:
        report.step_started(step.title)
        started = time.monotonic()
        findings = step.check()
        report.step_finished(step.title, findings, time.monotonic() - started)
        results.append((step.title, len(findings)))
    return results


# MARK: Run


def main() -> int:
    steps = chosen_steps(sys.argv[1:])
    if steps is None:
        return UNKNOWN_STEP
    if not project.has_xcode():
        return FAILED
    report.header(len(steps))
    results = run_steps(steps)
    report.summary(results)
    return FAILED if any(count for _, count in results) else PASSED


if __name__ == "__main__":
    sys.exit(main())
