"""Reads the index the Swift compiler writes while building (`swift build --enable-index-store`).

Start:  imported by checks/dead_code.py, not started on its own
Needs:  Xcode 27, which ships the index reader libIndexStore
The index knows every declaration and every place that uses it, with the exact symbol, so a
property called `bytes` is never confused with another one of the same name. This module calls
the reader's C functions directly (see indexstore.h in the Swift sources), so nothing is installed.
"""

import ctypes
import subprocess
from dataclasses import dataclass
from enum import IntEnum, IntFlag
from pathlib import Path

# MARK: Settings: the numbers the C library uses


class Role(IntFlag):
    """How an occurrence touches its symbol; one occurrence can have several roles."""

    DEFINITION = 1 << 1
    REFERENCE = 1 << 2
    READ = 1 << 3
    IMPLICIT = 1 << 8  # written by the compiler or a macro, not by us
    CHILD_OF = 1 << 9  # a member of a type
    BASE_OF = 1 << 10  # a protocol or class another type builds on
    OVERRIDE_OF = 1 << 11  # an override, or the fulfillment of a protocol requirement


ALL_NAMED_ROLES = sum(Role)  # roles this module does not name are dropped


class Kind(IntEnum):
    """What a symbol is; only the kinds this project asks about."""

    ENUM = 5
    STRUCT = 6
    CLASS = 7
    PROTOCOL = 8
    TYPE_ALIAS = 11
    FUNCTION = 12
    VARIABLE = 13
    ENUM_CASE = 15
    INSTANCE_METHOD = 16
    CLASS_METHOD = 17
    STATIC_METHOD = 18
    INSTANCE_PROPERTY = 19
    CLASS_PROPERTY = 20
    STATIC_PROPERTY = 21
    INITIALIZER = 22
    PARAMETER = 25


class Accessor(IntEnum):
    """The subkinds that mark the hidden functions behind a property."""

    GETTER = 3
    SETTER = 4
    WILL_SET = 1000
    DID_SET = 1001
    ADDRESSOR = 1002
    MUTABLE_ADDRESSOR = 1003
    READ = 1014
    MODIFY = 1015
    INIT = 1016
    BORROW = 1017
    MUTATE = 1018


RECORD = 2  # a unit (one compiled file) depends on records: the symbols of each source file


# MARK: What the index tells


@dataclass(frozen=True)
class Relation:
    roles: Role
    unique_name: str  # of the related symbol


@dataclass(frozen=True)
class Occurrence:
    """One place in a file where a symbol is declared or used."""

    unique_name: str  # the symbol's name across the whole program (the index calls it USR)
    name: str  # as written, with argument labels for functions: "toggle()"
    kind: int
    subkind: int
    roles: Role
    path: Path
    line: int
    relations: tuple[Relation, ...]

    def related(self, role: Role) -> list[str]:
        """The unique names of the symbols this occurrence relates to in the given way."""
        return [relation.unique_name for relation in self.relations if relation.roles & role]

    def is_accessor(self) -> bool:
        return self.subkind in set(Accessor)


# MARK: The C library


class CText(ctypes.Structure):
    """A text from the library: a pointer and a length, without a closing zero."""

    _fields_ = [("data", ctypes.c_char_p), ("length", ctypes.c_size_t)]

    def text(self) -> str:
        return ctypes.string_at(self.data, self.length).decode() if self.length else ""


POINTER = ctypes.c_void_p
TEXT = ctypes.c_char_p
YES_OR_NO = ctypes.c_bool
NUMBER = ctypes.c_uint64
LINE = ctypes.POINTER(ctypes.c_uint)
# The library hands each item to a function of ours; it returns True to go on.
NAME_VISITOR = ctypes.CFUNCTYPE(YES_OR_NO, POINTER, CText)
ITEM_VISITOR = ctypes.CFUNCTYPE(YES_OR_NO, POINTER, POINTER)

# Every C function used here (without the prefix indexstore_): its arguments and its result.
FUNCTIONS = {
    "store_create": ([TEXT, POINTER], POINTER),
    "store_units_apply_f": ([POINTER, ctypes.c_uint, POINTER, NAME_VISITOR], YES_OR_NO),
    "unit_reader_create": ([POINTER, TEXT, POINTER], POINTER),
    "unit_reader_dispose": ([POINTER], None),
    "unit_reader_dependencies_apply_f": ([POINTER, POINTER, ITEM_VISITOR], YES_OR_NO),
    "unit_dependency_get_kind": ([POINTER], ctypes.c_int),
    "unit_dependency_get_name": ([POINTER], CText),
    "unit_dependency_get_filepath": ([POINTER], CText),
    "record_reader_create": ([POINTER, TEXT, POINTER], POINTER),
    "record_reader_dispose": ([POINTER], None),
    "record_reader_occurrences_apply_f": ([POINTER, POINTER, ITEM_VISITOR], YES_OR_NO),
    "occurrence_get_symbol": ([POINTER], POINTER),
    "occurrence_get_roles": ([POINTER], NUMBER),
    "occurrence_get_line_col": ([POINTER, LINE, LINE], None),
    "occurrence_relations_apply_f": ([POINTER, POINTER, ITEM_VISITOR], YES_OR_NO),
    "symbol_relation_get_roles": ([POINTER], NUMBER),
    "symbol_relation_get_symbol": ([POINTER], POINTER),
    "symbol_get_usr": ([POINTER], CText),
    "symbol_get_name": ([POINTER], CText),
    "symbol_get_kind": ([POINTER], ctypes.c_int),
    "symbol_get_subkind": ([POINTER], ctypes.c_int),
}


class Library:
    """libIndexStore from the toolchain that also builds the app. Each C function is called by
    its short name: `library.store_create(…)` calls indexstore_store_create."""

    def __init__(self):
        swift = subprocess.run(["xcrun", "--find", "swift"], capture_output=True, text=True)
        toolchain = Path(swift.stdout.strip()).parents[1]
        self.library = ctypes.CDLL(str(toolchain / "lib" / "libIndexStore.dylib"))
        for name, (arguments, result) in FUNCTIONS.items():
            function = getattr(self.library, f"indexstore_{name}")
            function.argtypes = arguments
            function.restype = result

    def __getattr__(self, name: str):
        return getattr(self.library, f"indexstore_{name}")


# MARK: Reading the store


class IndexStore:
    def __init__(self, folder: Path):
        self.library = Library()
        self.store = self.library.store_create(str(folder).encode(), None)
        if not self.store:
            raise RuntimeError(f"no index store in {folder}")

    def occurrences(self, inside: Path) -> list[Occurrence]:
        """Every occurrence in the files below `inside`; the system's own files are skipped, and so
        are files that were renamed or deleted since the index was written."""
        found = []
        for record, path in self.records().items():
            if path.is_relative_to(inside) and path.exists():
                found += self.occurrences_in_record(record, path)
        return found

    def records(self) -> dict[str, Path]:
        """Each record and the source file it describes."""
        records = {}

        def note_record(_, dependency) -> bool:
            if self.library.unit_dependency_get_kind(dependency) == RECORD:
                name = self.library.unit_dependency_get_name(dependency).text()
                records[name] = Path(self.library.unit_dependency_get_filepath(dependency).text())
            return True

        for unit in self.units():
            reader = self.library.unit_reader_create(self.store, unit.encode(), None)
            self.library.unit_reader_dependencies_apply_f(reader, None, ITEM_VISITOR(note_record))
            self.library.unit_reader_dispose(reader)
        return records

    def units(self) -> list[str]:
        units = []

        def note_unit(_, name: CText) -> bool:
            units.append(name.text())
            return True

        self.library.store_units_apply_f(self.store, False, None, NAME_VISITOR(note_unit))
        return units

    def occurrences_in_record(self, record: str, path: Path) -> list[Occurrence]:
        found = []

        def note_occurrence(_, occurrence) -> bool:
            found.append(self.occurrence(occurrence, path))
            return True

        reader = self.library.record_reader_create(self.store, record.encode(), None)
        self.library.record_reader_occurrences_apply_f(
            reader, None, ITEM_VISITOR(note_occurrence))
        self.library.record_reader_dispose(reader)
        return found

    def occurrence(self, occurrence, path: Path) -> Occurrence:
        symbol = self.library.occurrence_get_symbol(occurrence)
        line, column = ctypes.c_uint(), ctypes.c_uint()
        self.library.occurrence_get_line_col(occurrence, ctypes.byref(line), ctypes.byref(column))
        return Occurrence(
            unique_name=self.library.symbol_get_usr(symbol).text(),
            name=self.library.symbol_get_name(symbol).text(),
            kind=self.library.symbol_get_kind(symbol),
            subkind=self.library.symbol_get_subkind(symbol),
            roles=Role(self.library.occurrence_get_roles(occurrence) & ALL_NAMED_ROLES),
            path=path,
            line=line.value,
            relations=self.relations(occurrence),
        )

    def relations(self, occurrence) -> tuple[Relation, ...]:
        relations = []

        def note_relation(_, relation) -> bool:
            related_symbol = self.library.symbol_relation_get_symbol(relation)
            roles = self.library.symbol_relation_get_roles(relation) & ALL_NAMED_ROLES
            relations.append(Relation(
                Role(roles), self.library.symbol_get_usr(related_symbol).text()))
            return True

        self.library.occurrence_relations_apply_f(occurrence, None, ITEM_VISITOR(note_relation))
        return tuple(relations)
