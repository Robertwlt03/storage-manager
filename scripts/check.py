#!/usr/bin/env python3
"""The check pipeline: every rule from CODE_STYLE.md that a tool can check, one step after another.

Start:  make check, or scripts/check.py tests rules for single steps, or a group such as
        scripts/check.py texts (GitHub runs the groups side by side)
Needs:  Xcode 27 and SwiftLint (`brew install swiftlint`)
It ends with status 1 as soon as one finding is left, so it guards every pull request. Each step
lives in scripts/checks/; samples.py tests the checks themselves on planted mistakes, and
report.py prints the results.
"""

import sys
import time
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from checks import (
    accessibility, architecture, commits, console, console_output, dead_code, disk_access,
    duplicates, english_only, guides, house_rules, language, nesting, project, promises, report,
    samples, secrets, security, tools, translations, unused_files, unused_python,
)

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
    Step("coverage", "Test coverage at least the minimum", tools.coverage_findings),
    Step("rules", "House rules", house_rules.rule_findings),
    Step("design", "Design rules", house_rules.design_findings),
    Step("accessibility", "Every image decided for VoiceOver",
         accessibility.accessibility_findings),
    Step("nesting", "Flat methods (two blocks deep at most)", nesting.nesting_findings),
    Step("duplicates", "No code written twice", duplicates.duplicate_findings),
    Step("architecture", "Layers of the architecture", architecture.architecture_findings),
    Step("promises", "Promises: offline, removing only after asking", promises.promise_findings),
    Step("disk", "The disk only off the main thread", disk_access.disk_access_findings),
    Step("deadcode", "Dead code (compiler index)", dead_code.dead_code_findings),
    Step("deadscripts", "Dead code in the Python scripts", unused_python.unused_python_findings),
    Step("files", "No unused images or media", unused_files.unused_file_findings),
    Step("language", "American English names and comments", language.language_findings),
    Step("plists", "Translation files and Info.plist (plutil)", tools.property_list_findings),
    Step("translations", "Every text translated", translations.translation_findings),
    Step("guides", "Guides: links whole, American spelling", guides.guide_findings),
    Step("english", "English everywhere but the translations", english_only.english_only_findings),
    Step("secrets", "No passwords or keys in the repository", secrets.secret_findings),
    Step("security", "No way in: shells, signing, workflows", security.security_findings),
    Step("scripts", "Scripts and Makefile", tools.script_findings),
    Step("output", "Every output in the shared look", console_output.console_output_findings),
    Step("commits", "Commit messages in the shared form", commits.commit_findings),
    Step("samples", "Every planted mistake found (checks/samples)", samples.sample_findings),
]
# The steps in groups that GitHub runs side by side, each as a job of its own in the workflow.
# Every step belongs to exactly one group, which the line after the table makes sure of.
GROUPS = {
    "tools": ["format", "lint", "compiler", "tests", "coverage"],
    "code": ["rules", "design", "accessibility", "nesting", "duplicates", "architecture",
             "promises", "disk", "deadcode", "language"],
    "texts": ["files", "plists", "translations", "guides", "english"],
    "safety": ["secrets", "security", "scripts", "deadscripts", "output", "commits", "samples"],
}
GROUPED_STEPS = sorted(name for names in GROUPS.values() for name in names)
assert GROUPED_STEPS == sorted(step.name for step in STEPS), "each step belongs to one group"
# Reports that only run when asked for by name, like `scripts/check.py coverage-report`.
EXTRA_STEPS = [
    Step("coverage-report", "Test coverage per folder", tools.coverage_report),
]

PASSED, FAILED, UNKNOWN_STEP = 0, 1, 2  # the exit status of the script


# MARK: Steps


def chosen_steps(names: list[str]) -> list[Step] | None:
    """The steps or groups named on the command line, every regular step without names, None for
    a typo."""
    known = {step.name: step for step in STEPS + EXTRA_STEPS}
    step_names = [step for name in names for step in GROUPS.get(name, [name])]
    unknown = [name for name in step_names if name not in known]
    if unknown:
        console.failed(f"Unknown step: {', '.join(unknown)}")
        console.note(f"Steps: {', '.join(known)}; groups: {', '.join(GROUPS)}")
        return None
    return [known[name] for name in step_names] if names else STEPS


def run_steps(steps: list[Step]) -> list[tuple[str, int]]:
    """Runs each step and prints its result; returns each step's title and number of findings."""
    results = []
    for step in steps:
        console.running(step.title)
        started = time.monotonic()
        findings = findings_of(step)
        report.step_finished(step.title, findings, time.monotonic() - started)
        results.append((step.title, len(findings)))
    return results


def findings_of(step: Step) -> list[str]:
    """The step's findings; a step that breaks down becomes one finding at the line where it
    stopped, so the steps after it still run and the summary still counts it."""
    try:
        return step.check()
    except Exception as error:
        # The last place inside the project, as the error may come from the standard library.
        ours = [
            frame for frame in traceback.extract_tb(error.__traceback__)
            if Path(frame.filename).is_relative_to(project.PROJECT)
        ]
        where = project.place(Path(ours[-1].filename), ours[-1].lineno or 0) if ours else "general"
        return [f"{where}: the step stopped with {type(error).__name__}: {error}"]


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
