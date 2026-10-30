"""Checks the commit messages: a subject in the shared form, lines of the usual length, a blank
line before the body, and English in American spelling.

Start:  imported by scripts/check.py, not started on its own
Needs:  git, and macOS for the spell checker (see unknown_words.swift)
A subject reads like `fix(scan): canceled scans stop at once`: a kind from Conventional Commits
(conventionalcommits.org), maybe a part in brackets, then what changed. The rule holds from the
commit that brought it in, so earlier history stays as it is; on GitHub the commits of a pull
request are checked, on this Mac the commits not yet on the remote's main. Every word must be
American English, a known technical term or a word the project's own code uses (`nonisolated`,
`fts`), so a message in German is reported as well.
"""

import os
import re
from dataclasses import dataclass

from checks.language import (
    BRITISH_VARIANTS, CODE_NAME, NOT_PROSE, is_known_term, known_terms, unknown_words, words_of,
)
from checks.project import LINE_LENGTH, app, compiler_index, lines_of, run

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
# A word of any language, umlauts included, so German words are read too; digits do not count.
WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)?")


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


def language_problems(messages: list[CommitMessage], terms: set[str]) -> list[str]:
    """British spellings, and words that are no English at all, such as a message in German."""
    words = {(message.place, word) for message in messages for word in message_words(message)}
    to_check = {word.lower() for _, word in words if not is_known_term(word.lower(), terms)}
    verdicts = unknown_words(to_check, set())
    return sorted(filter(None, (word_problem(where, word, verdicts) for where, word in words)))


def word_problem(where: str, word: str, verdicts: dict) -> str | None:
    kind, guess = verdicts.get(word.lower(), ("", ""))
    american = BRITISH_VARIANTS.get(word.lower()) or (guess if kind == "british" else None)
    if american:
        return f"{where}: '{word}' is British; American English writes '{american}'"
    if kind == "unknown":
        return f"{where}: '{word}' is not an English word; commit messages are written in English"
    return None


def message_words(message: CommitMessage) -> set[str]:
    """The prose words of a message; code in backticks, links, paths and names are left out."""
    prose = NOT_PROSE.sub(" ", LINK.sub(" ", message.text))
    return {word for word in WORD.findall(prose) if not CODE_NAME.search(word)}


def project_terms() -> set[str]:
    """The known technical terms, and every word the project's own code holds, whole and in its
    parts: `nonisolated`, `fts`, `fileCount` as file and count."""
    codebase = app()
    code = codebase.swift_files() + codebase.python_scripts
    words = {word for path in code for line in lines_of(path) for word in WORD.findall(line)}
    parts = {part for word in words for part in words_of(word)}
    terms = known_terms(codebase, compiler_index(codebase))
    return {word.lower() for word in words} | parts | terms


# MARK: Step


def commit_findings() -> list[str]:
    return commit_problems(commits_to_check())


def commit_problems(messages: list[CommitMessage]) -> list[str]:
    findings = [problem for message in messages for problem in message_problems(message)]
    return findings + language_problems(messages, project_terms())
