"""Checks the commit messages: a subject in the shared form, lines of the usual length, a blank
line before the body, and American English.

Start:  imported by scripts/check.py, not started on its own
Needs:  git, and macOS for the spell checker (see unknown_words.swift)
A subject reads like `fix(scan): canceled scans stop at once`: a kind from Conventional Commits
(conventionalcommits.org), maybe a part in brackets, then what changed. The rule holds from the
commit that brought it in, so earlier history stays as it is; on GitHub the commits of a pull
request are checked, on this Mac the commits not yet on the remote's main.
"""

import os
import re
from dataclasses import dataclass

from checks.language import BRITISH_VARIANTS, PLAIN_WORD, unknown_words
from checks.project import LINE_LENGTH, run

# MARK: Settings

KINDS = "feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"  # Conventional Commits
SUBJECT = re.compile(rf"""
    ^ (?: {KINDS} )             # the kind of change
    (?: \( [a-z0-9-]+ \) )?     # maybe the part it touches: (scan)
    !? : \s \S                  # maybe ! for a breaking change, then the summary
""", re.VERBOSE)
MERGE = re.compile(r"^Merge ")  # merge commits are written by git and GitHub
RULE_FILE = "scripts/checks/commits.py"
LINK = re.compile(r"\w+://\S+")
UNIT_SEPARATOR, RECORD_SEPARATOR = "\x1f", "\x1e"  # keep commits apart in git's output


# MARK: Messages


@dataclass(frozen=True)
class CommitMessage:
    place: str  # "commit 1a2b3c4", or a file and line for the samples
    text: str


def commits_to_check() -> list[CommitMessage]:
    """The commits since the rule came in that the remote's main does not hold yet."""
    introduced = run(["git", "log", "--diff-filter=A", "--format=%H", "-1", "--", RULE_FILE])
    first = introduced.output.strip()
    if not first:
        return []  # the rule is not committed yet, so it holds from its own commit on
    excluded = [f"^{first}^"] + [f"^{base}" for base in comparison_bases()]
    message_format = f"--format=%h{UNIT_SEPARATOR}%B{RECORD_SEPARATOR}"
    output = run(["git", "log", message_format, "HEAD", *excluded])
    records = [record.strip("\n") for record in output.output.split(RECORD_SEPARATOR)]
    pairs = [record.split(UNIT_SEPARATOR, 1) for record in records if UNIT_SEPARATOR in record]
    return [CommitMessage(f"commit {short_id}", text.strip()) for short_id, text in pairs]


def comparison_bases() -> list[str]:
    """What the commits are compared with: a pull request's base, or the remote's main."""
    base_branch = os.environ.get("GITHUB_BASE_REF") or "main"
    remote_branch = f"origin/{base_branch}"
    exists = run(["git", "rev-parse", "--verify", "--quiet", remote_branch]).succeeded
    return [remote_branch] if exists else []


# MARK: Judging


def message_problems(message: CommitMessage) -> list[str]:
    lines = message.text.splitlines()
    subject = lines[0] if lines else ""
    if MERGE.match(subject):
        return []
    problems = []
    if not SUBJECT.match(subject):
        problems.append(f"'{subject}' is not a commit subject like 'fix(scan): what changed'")
    if len(lines) > 1 and lines[1].strip():
        problems.append("a blank line belongs between the subject and the body")
    problems += [
        f"line {number} is longer than {LINE_LENGTH} characters"
        for number, line in enumerate(lines, start=1)
        if len(line) > LINE_LENGTH and not LINK.search(line)
    ]
    return [f"{message.place}: {problem}" for problem in problems]


def spelling_problems(messages: list[CommitMessage]) -> list[str]:
    words = {
        (message.place, word) for message in messages
        for word in PLAIN_WORD.findall(LINK.sub(" ", message.text))
    }
    verdicts = unknown_words({word.lower() for _, word in words}, set())
    return sorted(
        f"{where}: '{word}' is British; American English writes '{american}'"
        for where, word in words
        if (american := BRITISH_VARIANTS.get(word.lower()) or british_guess(word, verdicts))
    )


def british_guess(word: str, verdicts: dict) -> str | None:
    kind, guess = verdicts.get(word.lower(), ("", ""))
    return guess if kind == "british" else None


# MARK: Step


def commit_findings() -> list[str]:
    return commit_problems(commits_to_check())


def commit_problems(messages: list[CommitMessage]) -> list[str]:
    findings = [problem for message in messages for problem in message_problems(message)]
    return findings + spelling_problems(messages)
