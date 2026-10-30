"""Checks that every part of the app uses only the parts its layer may use (see ARCHITECTURE.md).

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index tells who uses whose types and functions)
A part is a folder below Sources, such as Services or Features. The design tokens are a part of
their own, because every layer may name a symbol or a color. A folder that is not in the table
is reported, so a new part needs a place in the architecture before it can be used.
"""

from pathlib import Path

from checks.index_store import Occurrence, Role
from checks.project import Codebase, app, compiler_index, place

# MARK: Settings

# Files that form a part of their own, by their path below the source folder.
OWN_PARTS = {"DesignSystem/Tokens.swift": "Tokens", "DesignSystem/Theme.swift": "Tokens"}

FOUNDATION = {"Core", "Localization", "Tokens"}
# Each part and the parts it may use, besides itself.
MAY_USE = {
    "Localization": {"Core"},
    "Core": {"Localization", "Tokens"},
    "Tokens": {"Core", "Localization"},
    "Models": FOUNDATION | {"Services"},
    "Services": FOUNDATION | {"Models"},
    "DesignSystem": FOUNDATION | {"Models", "Services"},
    "Diagnostics": FOUNDATION | {"Models", "Services", "State"},
    "State": FOUNDATION | {"Models", "Services", "DesignSystem", "Diagnostics"},
    "Features": FOUNDATION | {"Models", "Services", "State", "DesignSystem"},
    "App": FOUNDATION | {"Models", "Services", "State", "DesignSystem", "Diagnostics", "Features"},
}


# MARK: Parts


def part_of(path: Path, codebase: Codebase) -> str | None:
    """The part a file belongs to; files right in the source folder belong to none."""
    if codebase.source_root is None or not path.is_relative_to(codebase.source_root):
        return None
    below = path.relative_to(codebase.source_root)
    if own_part := OWN_PARTS.get(below.as_posix()):
        return own_part
    return below.parts[0] if len(below.parts) > 1 else None


# MARK: Step


def architecture_findings() -> list[str]:
    return architecture_problems(app())


def architecture_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    homes = {
        found.unique_name: part_of(found.path, codebase)
        for found in index.occurrences if found.roles & Role.DEFINITION
    }
    findings = {}  # one finding per file and used part
    for found in index.occurrences:
        problem = crossing_problem(found, homes, codebase)
        if problem:
            key = (found.path, homes.get(found.unique_name))
            findings.setdefault(key, f"{place(found.path, found.line)}: {problem}")
    return list(findings.values())


def crossing_problem(found: Occurrence, homes: dict[str, str | None], codebase: Codebase):
    """What is wrong when this use crosses into a part its own part may not use."""
    user = part_of(found.path, codebase)
    used = homes.get(found.unique_name)
    if not (found.roles & Role.REFERENCE) or user is None or used is None or user == used:
        return None
    if user not in MAY_USE:
        return f"the folder {user} has no place in the architecture yet; add it to architecture.py"
    if used in MAY_USE[user]:
        return None
    allowed = ", ".join(sorted(MAY_USE[user]))
    return f"{user} may not use {used} (it uses {found.name}); {user} may use {allowed}"
