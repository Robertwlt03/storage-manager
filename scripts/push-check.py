#!/usr/bin/env python3
"""Checks the commits of a git push before they leave the Mac (the pre-push hook starts it).

Start:  git push, through scripts/hooks/pre-push
Needs:  what make check needs (Xcode 27, SwiftLint, Python 3.13 or newer)
The checks read the files in the folder, so they only speak for the pushed commits when the
folder holds exactly those: no change waits uncommitted, and the pushed branch is checked out.
"""

import subprocess
import sys

from checks import console, project
from checks.project import PROJECT, SCRIPTS

# MARK: Settings

NO_COMMIT = "0" * 40  # what git hands over for a deleted branch
# git writes one line per pushed branch or tag: local name, local commit, remote name, remote
# commit.
PUSHED_LINE_FIELDS = 4


# MARK: Steps


def git(*arguments: str) -> str:
    result = project.run(["git", *arguments])
    if not result.succeeded:
        refuse(f"git could not read the push: {result.output.strip()}")
    return result.output.strip()


def has_uncommitted_changes() -> bool:
    return bool(git("status", "--porcelain"))


def pushes_other_commit(pushed: list[str]) -> bool:
    head = git("rev-parse", "HEAD")
    local_commits = [line.split()[1] for line in pushed if len(line.split()) == PUSHED_LINE_FIELDS]
    return any(
        commit != NO_COMMIT and git("rev-parse", f"{commit}^{{commit}}") != head
        for commit in local_commits
    )


def refuse(reason: str) -> None:
    console.frame("Not pushed", [
        reason,
        "The checks read the folder, not the commits.",
        "git push --no-verify pushes without the checks.",
    ], console.FAILURE)
    sys.exit(1)


# MARK: Run


def main() -> None:
    console.heading("Speicher-Explorer · pre-push", "checks the commits before they leave the Mac")
    if has_uncommitted_changes():
        refuse("commit your changes or set them aside first")
    if pushes_other_commit(sys.stdin.read().splitlines()):
        refuse("check out the branch you push first")
    sys.exit(subprocess.run([sys.executable, SCRIPTS / "check.py"], cwd=PROJECT).returncode)


if __name__ == "__main__":
    main()
