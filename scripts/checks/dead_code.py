"""Finds declarations nothing uses and properties nothing reads, from the compiler's index.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the index reader libIndexStore, see index_store.py)
Only uses in the app's own code count, so code that only the tests use is dead as well.
"""

import re

from checks.index_store import Kind, Occurrence, Role
from checks.project import Codebase, app, compiler_index, lines_of, place

# MARK: Settings

# What macOS or SwiftUI uses although no line of ours does, marked by an attribute on the
# declaration or the line above it: the app's entry point and the app delegate.
USED_BY_THE_SYSTEM = ("@main", "@NSApplicationDelegateAdaptor")
ENTRY_POINT = "main()"  # the function macOS calls in the type marked @main

# The cases of an enum that conforms to CaseIterable are used through allCases ...
LISTS_ITS_CASES = "CaseIterable"
# ... except text keys: a key the app never shows is dead, whatever allCases says.
TEXT_KEYS = "TextKey"

# A property wrapper such as @Binding passes every write on, so writing alone is a use.
PROPERTY_WRAPPER = re.compile(r"^\s*@[A-Z]\w*")  # an attribute with a capital letter: @State

# The index holds where parameters are declared but not where they are used, so they are left out.
DECLARATION_KINDS = set(Kind) - {Kind.PARAMETER}
PROPERTY_KINDS = {
    Kind.VARIABLE, Kind.INSTANCE_PROPERTY, Kind.CLASS_PROPERTY, Kind.STATIC_PROPERTY,
}


# MARK: Step


def dead_code_findings() -> list[str]:
    return dead_code_problems(app())


def dead_code_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    app_code = set(codebase.swift_sources)
    return DeadCode([found for found in index.occurrences if found.path in app_code]).findings()


# MARK: Judging each declaration


class DeadCode:
    def __init__(self, occurrences: list[Occurrence]):
        definitions = [found for found in occurrences if found.roles & Role.DEFINITION]
        self.declarations = {
            definition.unique_name: definition for definition in definitions
            if is_written_declaration(definition)
        }
        # A property wrapper adds `$name` and `_name` in the same line; a use of either counts
        # for the property, so each definition belongs to the group of its line and name.
        self.groups = {definition.unique_name: group(definition) for definition in definitions}
        self.uses = self.uses_per_group(occurrences)
        self.enums_listing_their_cases = {
            enum
            for found in occurrences if found.name == LISTS_ITS_CASES
            for enum in found.related(Role.BASE_OF)
        }

    def uses_per_group(self, occurrences: list[Occurrence]) -> dict[tuple, Role]:
        """All the ways our own lines use each group; code that macros such as @Observable
        generate is marked implicit and does not count."""
        uses: dict[tuple, Role] = {}
        for found in occurrences:
            is_written_use = found.roles & Role.REFERENCE and not found.roles & Role.IMPLICIT
            if is_written_use and found.unique_name in self.groups:
                key = self.groups[found.unique_name]
                uses[key] = uses.get(key, Role(0)) | found.roles
        return uses

    def findings(self) -> list[str]:
        in_order = sorted(self.declarations.values(), key=lambda found: (found.path, found.line))
        judged = [(declaration, self.problem(declaration)) for declaration in in_order]
        return [
            f"{place(declaration.path, declaration.line)}: {problem}"
            for declaration, problem in judged if problem
        ]

    def problem(self, declaration: Occurrence) -> str | None:
        if self.is_used_by_the_system(declaration):
            return None
        uses = self.uses.get(self.groups[declaration.unique_name])
        if uses is None:
            return self.unused_problem(declaration)
        if declaration.kind in PROPERTY_KINDS and not uses & Role.READ:
            if not PROPERTY_WRAPPER.match(declaration_line(declaration)):
                return f"'{declaration.name}' is assigned but never read"
        return None

    def unused_problem(self, declaration: Occurrence) -> str | None:
        parent = self.parent(declaration)
        is_listed_case = (
            declaration.kind == Kind.ENUM_CASE
            and parent is not None
            and parent.unique_name in self.enums_listing_their_cases
        )
        if is_listed_case and parent.name != TEXT_KEYS:
            return None
        if is_listed_case:
            return f"text '{declaration.name}' is never shown"
        return f"'{declaration.name}' is declared but never used"

    def parent(self, declaration: Occurrence) -> Occurrence | None:
        parents = declaration.related(Role.CHILD_OF)
        return self.declarations.get(parents[0]) if parents else None

    def is_used_by_the_system(self, declaration: Occurrence) -> bool:
        line_above = lines_of(declaration.path)[max(declaration.line - 2, 0)]
        nearby = (line_above, declaration_line(declaration))
        if any(attribute in line for line in nearby for attribute in USED_BY_THE_SYSTEM):
            return True
        parent = self.parent(declaration)
        is_entry_point = declaration.name == ENTRY_POINT and parent is not None
        return is_entry_point and self.is_used_by_the_system(parent)


def is_written_declaration(definition: Occurrence) -> bool:
    """A declaration written in our code; accessors, generated code and the fulfillment of a
    protocol requirement (which the system calls) are left out."""
    return (
        definition.kind in DECLARATION_KINDS
        and not definition.is_accessor()
        and not definition.roles & Role.IMPLICIT
        and not definition.related(Role.OVERRIDE_OF)
    )


def group(definition: Occurrence) -> tuple:
    return definition.path, definition.line, definition.name.lstrip("$_")


def declaration_line(declaration: Occurrence) -> str:
    return lines_of(declaration.path)[declaration.line - 1]
