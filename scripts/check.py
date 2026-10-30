#!/usr/bin/env python3
"""The check pipeline: every rule from CODE_STYLE.md that a tool can check, one step after another.

Start:  make check, or scripts/check.py tests rules for single steps
Needs:  Xcode 27 and SwiftLint (brew install swiftlint)
It ends with status 1 as soon as one finding is left, so it guards every pull request. The steps
live in scripts/checks/: project.py (folders, files, running tools), tools.py, house_rules.py,
dead_code.py and index_store.py.
"""

import sys
from dataclasses import dataclass
from typing import Callable

from checks import dead_code, house_rules, project, tools

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
    Step("deadcode", "Dead code (compiler index)", dead_code.dead_code_findings),
    Step("plists", "Translation files and Info.plist (plutil)", tools.property_list_findings),
    Step("scripts", "Scripts and Makefile", tools.script_findings),
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


def run_steps(steps: list[Step]) -> int:
    """Runs each step, prints its findings and returns how many there were."""
    total = 0
    for step in steps:
        findings = step.check()
        total += len(findings)
        print(f"{step.title}: {len(findings)}")
        for finding in findings:
            print(f"  {finding}")
    return total


# MARK: Run


def main() -> int:
    steps = chosen_steps(sys.argv[1:])
    if steps is None:
        return UNKNOWN_STEP
    if not project.has_xcode():
        return FAILED
    total = run_steps(steps)
    print(f"\n{total} findings" if total else "\nNo errors and no warnings.")
    return FAILED if total else PASSED


if __name__ == "__main__":
    sys.exit(main())
