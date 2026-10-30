"""Makes sure no password, key or token reaches the repository.

Start:  imported by scripts/check.py, not started on its own
Needs:  git
Every file git knows is searched for private keys, the known shapes of access tokens and
settings that write a secret's value out. Every settings file the Makefile reads, such as local.mk
with the password of the signing keychain, must be ignored by git, so it can never be added.
"""

import re
from pathlib import Path

from checks.project import MAKEFILE, PROJECT, Codebase, app, numbered_lines, place, run

# MARK: Settings

SECRETS = {
    "a private key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "an AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "a GitHub token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    "a Slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    "a secret written into a setting": re.compile(r"""
        (?<! [a-z] )                    # the start of a word or a part such as _PASSWORD
        (?: password | passwd | secret | token | api [_-]? key ) \w* \s* [:=] \s*  # its name
        ["']? (?! [$<{(%] )             # not a variable, placeholder or format such as $PASSWORD
        [^\s"'$/(]{8,}                  # eight characters or more ...
        (?! [\w(.] | \S* / )             # ... that end there: no call, no path, no address
    """, re.VERBOSE | re.IGNORECASE),
}
INCLUDED_SETTINGS = re.compile(r"^-?include\s+(\S+)", re.MULTILINE)  # -include local.mk


# MARK: Steps


def secrets_in(paths: tuple[Path, ...]) -> list[str]:
    findings = []
    for path, number, line in numbered_lines(path for path in paths if is_text(path)):
        findings += [
            f"{place(path, number)}: {kind} must not be in the repository"
            for kind, pattern in SECRETS.items() if pattern.search(line)
        ]
    return findings


def is_text(path: Path) -> bool:
    try:
        path.read_text()
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return False
    return True


def unignored_settings() -> list[str]:
    """Settings the Makefile reads must stay out of git."""
    settings = INCLUDED_SETTINGS.findall(MAKEFILE.read_text())
    return [
        f"Makefile:1: {name} holds local settings such as passwords, but git does not ignore it"
        for name in settings
        if not run(["git", "check-ignore", "--quiet", str(PROJECT / name)]).succeeded
    ]


# MARK: Step


def secret_findings() -> list[str]:
    return secret_problems(app()) + unignored_settings()


def secret_problems(codebase: Codebase) -> list[str]:
    return secrets_in(codebase.text_files)
