"""Closes the ways in an attacker could use: in the app, in the scripts and on GitHub.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
The app holds Full Disk Access, so whoever runs code inside it can read every file on the Mac.
Each rule names one way in: a shell that reads words as commands, text run as code, a fixed place
in the shared temporary folder, a signature that lets other code load into the app, Swift's
safety switched off without a reason, and a GitHub workflow that strangers could steer.
"""

import re
from dataclasses import dataclass
from pathlib import Path

from checks.project import Codebase, app, lines_of, numbered_lines, place

# MARK: Settings


@dataclass(frozen=True)
class Risk:
    pattern: re.Pattern
    message: str


SHELL_INSTEAD_OF_PROGRAM = (
    "starts a shell, which reads its text as commands; start the program itself and hand it the "
    "arguments as a list"
)
CODE_FROM_TEXT = "runs text as code; read the text as data instead"
# A path in the shared temporary folder: another user can create the file or a link there first.
FIXED_TEMPORARY_PATH = Risk(
    re.compile(r"(?<! [\w/.$] ) / (?: private/ )? tmp /", re.VERBOSE),
    "a fixed path in the shared temporary folder, where another user can plant a file or a link "
    "first; let the system make a private one (FileManager.temporaryDirectory, tempfile, mktemp)",
)

SWIFT_RISKS = (
    Risk(re.compile(r'" / (?: usr/ )? bin / (?: ba | z | k | da | fi )? sh "', re.VERBOSE),
         SHELL_INSTEAD_OF_PROGRAM),
    Risk(re.compile(r'" /usr/bin/env "', re.VERBOSE),
         "lets the search path choose the program; name it with its full path"),
    FIXED_TEMPORARY_PATH,
)
PYTHON_RISKS = (
    Risk(re.compile(r"\b shell \s* = \s* True", re.VERBOSE), SHELL_INSTEAD_OF_PROGRAM),
    Risk(re.compile(r"""
        \b os \. (?: system | popen | exec\w* | spawn\w* ) \s* \(  # os.system and its family
        | \b subprocess \. (?: getoutput | getstatusoutput ) \b
    """, re.VERBOSE), SHELL_INSTEAD_OF_PROGRAM),
    Risk(re.compile(r"(?<! [\w.] ) (?: eval | exec ) \s* \(", re.VERBOSE), CODE_FROM_TEXT),
    Risk(re.compile(r"\b (?: pickle | marshal | shelve ) \. (?: loads? | open ) \b", re.VERBOSE),
         "builds objects from stored bytes, which can run code; store JSON instead"),
    Risk(re.compile(r"\b yaml \. (?: load | unsafe_load ) \s* \(", re.VERBOSE),
         "builds any object a YAML file asks for; use yaml.safe_load"),
    FIXED_TEMPORARY_PATH,
)
SHELL_RISKS = (
    Risk(re.compile(r"(?: ^ | [;&|] ) \s* eval \b", re.VERBOSE), CODE_FROM_TEXT),
    Risk(re.compile(r"\b (?: curl | wget ) \b .* \| \s* (?: sudo \s+ )? \w*sh \b", re.VERBOSE),
         "runs a script straight from the internet; download it, read it, then run it"),
    FIXED_TEMPORARY_PATH,
)

# The first command of every shell script: stop at the first failed command, at the first unset
# variable and at a failure inside a pipe, instead of going on with a half-done result.
STRICT_MODE = "set -euo pipefail"
COMMENT_OR_BLANK = re.compile(r"^\s*(?:#.*)?$")

# Signing: the hardened runtime keeps other code out of the app (no injected libraries, no
# debugger), so nobody borrows its Full Disk Access.
SIGNS = re.compile(r"--sign\b")
HARDENED_RUNTIME = re.compile(r"(?:--options|-o)[ =]\S*runtime")

# Places where Swift's safety is switched off. Each needs a comment that says why it holds, on its
# line or right above it (lines with the same kind of switch may stand in between).
SAFETY_SWITCHES = re.compile(r"""
    nonisolated \( unsafe \)            # a value any thread may change without a lock
    | @unchecked \s+ Sendable           # a type the compiler does not check for threads
    | \b unsafeBitCast \b               # reads the bits of one type as another
    | \b Unmanaged \b                   # memory the program frees by hand
""", re.VERBOSE)
SWIFT_COMMENT = re.compile(r"//")

# GitHub workflows: what a stranger's pull request or a changed tool could change or read.
WORKFLOW_PERMISSIONS = re.compile(r"^permissions:", re.MULTILINE)
EVERY_PERMISSION = re.compile(r"\bwrite-all\b")
ACTION = re.compile(r"""
    \b uses: \s* (?! \./ | docker:// )  # an action from another repository
    [^@\s]+ @ (?P<version> [^\s#]+ )    # owner/name@version
""", re.VERBOSE)
COMMIT_NAME = re.compile(r"^[0-9a-f]{40}$")  # a commit's full name, which nobody can move
STRANGERS_TRIGGER = re.compile(r"^\s*-?\s*pull_request_target\b")
RUN_BLOCK = re.compile(r"^(?P<indent>\s*)(?:-\s+)?run:")
STRANGERS_TEXT = re.compile(r"\$\{\{[^}]*\b(?:github\.event\.|github\.head_ref)")
# An install that takes whatever version is newest that day.
NEWEST_VERSION_INSTALL = re.compile(r"""
    \b brew \s+ install \b                  # Homebrew knows no fixed versions
    | \b pip3? \s+ install \b (?! .* == )   # pip without name==version
""", re.VERBOSE)


# MARK: Code and scripts


def risk_problems(paths: tuple[Path, ...], risks: tuple[Risk, ...]) -> list[str]:
    return [
        f"{place(path, number)}: {risk.message}"
        for path, number, line in numbered_lines(paths)
        for risk in risks if risk.pattern.search(line)
    ]


def strict_mode_problems(shell_scripts: tuple[Path, ...]) -> list[str]:
    problems = []
    for path in shell_scripts:
        numbered = enumerate(lines_of(path), start=1)
        first = next(((number, line) for number, line in numbered
                      if not COMMENT_OR_BLANK.match(line)), None)
        if first and first[1].strip() != STRICT_MODE:
            problems.append(
                f"{place(path, first[0])}: the first command must be '{STRICT_MODE}', so the "
                "script stops at the first failure instead of going on"
            )
    return problems


def signing_problems(shell_scripts: tuple[Path, ...]) -> list[str]:
    return [
        f"{place(path, number)}: signs without the hardened runtime, so other code can load into "
        "the app and use its Full Disk Access; add --options runtime"
        for path, number, line in numbered_lines(shell_scripts)
        if SIGNS.search(line) and not HARDENED_RUNTIME.search(line)
    ]


def safety_switch_problems(swift_files: tuple[Path, ...]) -> list[str]:
    return [
        f"{place(path, number)}: switches off Swift's safety without a comment that says why it "
        "holds; write the reason on the line or right above it"
        for path, number, line in numbered_lines(swift_files)
        if SAFETY_SWITCHES.search(line) and not has_reason(lines_of(path), number)
    ]


def has_reason(lines: list[str], number: int) -> bool:
    """A comment on the line, or above it past the lines that switch off the same safety."""
    for line in reversed(lines[:number]):
        if SWIFT_COMMENT.search(line):
            return True
        if not SAFETY_SWITCHES.search(line):
            return False
    return False


# MARK: GitHub workflows


def workflow_problems(workflows: tuple[Path, ...]) -> list[str]:
    problems = []
    for workflow in workflows:
        if not WORKFLOW_PERMISSIONS.search(workflow.read_text()):
            problems.append(
                f"{place(workflow, 1)}: no permissions: block, so the job gets every right of "
                "GitHub's token; start with 'permissions: contents: read'"
            )
        problems += workflow_line_problems(workflow)
    return problems


def workflow_line_problems(workflow: Path) -> list[str]:
    problems = []
    run_indent = None  # the indentation of the run: block the line belongs to, if any
    for number, line in enumerate(lines_of(workflow), start=1):
        run_indent = run_block_indent(line, run_indent)
        problems += [
            f"{place(workflow, number)}: {problem}"
            for problem in line_problems(line, inside_run=run_indent is not None)
        ]
    return problems


def run_block_indent(line: str, current: int | None) -> int | None:
    """Where the run: block that holds this line starts; None outside of one."""
    run = RUN_BLOCK.match(line)
    if run:
        return len(run["indent"])
    indent = len(line) - len(line.lstrip())
    stays_inside = current is not None and (not line.strip() or indent > current)
    return current if stays_inside else None


def line_problems(line: str, inside_run: bool) -> list[str]:
    action = ACTION.search(line)
    checks = [
        (EVERY_PERMISSION.search(line),
         "write-all gives the job every right; name only the rights it needs"),
        (action and not COMMIT_NAME.match(action["version"]),
         "an action by a name its owner can move to other code; pin its commit (40 characters) "
         "and write the version in a comment"),
        (STRANGERS_TRIGGER.match(line),
         "pull_request_target runs with the repository's secrets for strangers' pull requests; "
         "use pull_request"),
        (inside_run and STRANGERS_TEXT.search(line),
         "puts text a stranger chooses, such as a title or branch name, into a command; hand it "
         "over in env: and read it as a variable"),
        (inside_run and NEWEST_VERSION_INSTALL.search(line),
         "installs a tool in whatever version is newest, so unchanged code can turn red or run "
         "changed tools; download a fixed version and compare its checksum"),
    ]
    return [message for found, message in checks if found]


# MARK: Step


def security_findings() -> list[str]:
    return security_problems(app())


def security_problems(codebase: Codebase) -> list[str]:
    swift_files = codebase.swift_files()
    return (
        risk_problems(swift_files, SWIFT_RISKS)
        + risk_problems(codebase.python_scripts, PYTHON_RISKS)
        + risk_problems(codebase.shell_scripts, SHELL_RISKS)
        + strict_mode_problems(codebase.shell_scripts)
        + signing_problems(codebase.shell_scripts)
        + safety_switch_problems(swift_files)
        + workflow_problems(codebase.workflows)
    )
