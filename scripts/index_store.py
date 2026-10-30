"""Reads the index the Swift compiler writes while building (`swift build --enable-index-store`).

The index knows every declaration and every place that uses it, with the exact symbol, so a
property called `bytes` is never confused with another one of the same name. Xcode ships the
reader as libIndexStore; this module calls its C functions directly, so nothing is installed.
"""

import ctypes
import subprocess
from dataclasses import dataclass
from enum import IntEnum, IntFlag
from pathlib import Path


class Role(IntFlag):
    """How an occurrence touches its symbol (indexstore_symbol_role_t)."""

    DEFINITION = 1 << 1
    REFERENCE = 1 << 2
    READ = 1 << 3
    IMPLICIT = 1 << 8
    CHILD_OF = 1 << 9
    BASE_OF = 1 << 10
    OVERRIDE_OF = 1 << 11  # also a protocol requirement that a declaration fulfils


ALL_ROLES = sum(Role)  # roles this module does not name are dropped


class Kind(IntEnum):
    """What a symbol is (indexstore_symbol_kind_t); only the kinds this project asks about."""

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


ACCESSOR_SUBKINDS = {3, 4, *range(1000, 1004), *range(1014, 1019)}  # get, set, didSet, …
RECORD_DEPENDENCY = 2


@dataclass(frozen=True)
class Relation:
    roles: Role
    usr: str


@dataclass(frozen=True)
class Occurrence:
    """One place in a file where a symbol is declared or used."""

    usr: str  # the symbol's unique name across the whole program
    name: str
    kind: int
    subkind: int
    roles: Role
    path: Path
    line: int
    relations: tuple[Relation, ...]

    def related(self, role: Role) -> list[str]:
        return [relation.usr for relation in self.relations if relation.roles & role]


class StringReference(ctypes.Structure):
    _fields_ = [("data", ctypes.c_char_p), ("length", ctypes.c_size_t)]

    def text(self) -> str:
        return ctypes.string_at(self.data, self.length).decode() if self.length else ""


NAME_VISITOR = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, StringReference)
VISITOR = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
POINTER = ctypes.c_void_p
TEXT = ctypes.c_char_p
LINE_NUMBER = ctypes.POINTER(ctypes.c_uint)

# The C functions used here, with their argument and result types (see indexstore.h).
FUNCTIONS = {
    "store_create": ([TEXT, POINTER], POINTER),
    "store_units_apply_f": ([POINTER, ctypes.c_uint, POINTER, NAME_VISITOR], ctypes.c_bool),
    "unit_reader_create": ([POINTER, TEXT, POINTER], POINTER),
    "unit_reader_dispose": ([POINTER], None),
    "unit_reader_dependencies_apply_f": ([POINTER, POINTER, VISITOR], ctypes.c_bool),
    "unit_dependency_get_kind": ([POINTER], ctypes.c_int),
    "unit_dependency_get_name": ([POINTER], StringReference),
    "unit_dependency_get_filepath": ([POINTER], StringReference),
    "record_reader_create": ([POINTER, TEXT, POINTER], POINTER),
    "record_reader_dispose": ([POINTER], None),
    "record_reader_occurrences_apply_f": ([POINTER, POINTER, VISITOR], ctypes.c_bool),
    "occurrence_get_symbol": ([POINTER], POINTER),
    "occurrence_get_roles": ([POINTER], ctypes.c_uint64),
    "occurrence_get_line_col": ([POINTER, LINE_NUMBER, LINE_NUMBER], None),
    "occurrence_relations_apply_f": ([POINTER, POINTER, VISITOR], ctypes.c_bool),
    "symbol_relation_get_roles": ([POINTER], ctypes.c_uint64),
    "symbol_relation_get_symbol": ([POINTER], POINTER),
    "symbol_get_usr": ([POINTER], StringReference),
    "symbol_get_name": ([POINTER], StringReference),
    "symbol_get_kind": ([POINTER], ctypes.c_int),
    "symbol_get_subkind": ([POINTER], ctypes.c_int),
}


def load_library() -> ctypes.CDLL:
    """libIndexStore from the toolchain that also builds the app."""
    swift = subprocess.run(["xcrun", "--find", "swift"], capture_output=True, text=True)
    library = ctypes.CDLL(str(Path(swift.stdout.strip()).parents[1] / "lib/libIndexStore.dylib"))
    for name, (arguments, result) in FUNCTIONS.items():
        function = getattr(library, f"indexstore_{name}")
        function.argtypes = arguments
        function.restype = result
    return library


class IndexStore:
    def __init__(self, path: Path):
        self.library = load_library()
        self.store = self.library.indexstore_store_create(str(path).encode(), None)
        if not self.store:
            raise RuntimeError(f"no index store in {path}")

    def occurrences(self, inside: Path) -> list[Occurrence]:
        """Every occurrence in the files below `inside`; the system's own files are skipped."""
        found = []
        for record, path in self.records().items():
            if path.is_relative_to(inside):
                found += self.record_occurrences(record, path)
        return found

    def records(self) -> dict[str, Path]:
        """Each record (the symbols of one source file) and the file it describes."""
        units = []
        self.library.indexstore_store_units_apply_f(
            self.store, 0, None, NAME_VISITOR(lambda _, name: units.append(name.text()) or True))
        records = {}

        def note_record(_, dependency) -> bool:
            if self.library.indexstore_unit_dependency_get_kind(dependency) == RECORD_DEPENDENCY:
                name = self.library.indexstore_unit_dependency_get_name(dependency).text()
                path = self.library.indexstore_unit_dependency_get_filepath(dependency).text()
                records[name] = Path(path)
            return True

        for unit in units:
            reader = self.library.indexstore_unit_reader_create(self.store, unit.encode(), None)
            self.library.indexstore_unit_reader_dependencies_apply_f(
                reader, None, VISITOR(note_record))
            self.library.indexstore_unit_reader_dispose(reader)
        return records

    def record_occurrences(self, record: str, path: Path) -> list[Occurrence]:
        found = []

        def note_occurrence(_, occurrence) -> bool:
            found.append(self.occurrence(occurrence, path))
            return True

        reader = self.library.indexstore_record_reader_create(self.store, record.encode(), None)
        self.library.indexstore_record_reader_occurrences_apply_f(
            reader, None, VISITOR(note_occurrence))
        self.library.indexstore_record_reader_dispose(reader)
        return found

    def occurrence(self, occurrence, path: Path) -> Occurrence:
        library = self.library
        symbol = library.indexstore_occurrence_get_symbol(occurrence)
        line, column = ctypes.c_uint(), ctypes.c_uint()
        library.indexstore_occurrence_get_line_col(
            occurrence, ctypes.byref(line), ctypes.byref(column))
        relations = []

        def note_relation(_, relation) -> bool:
            related_symbol = library.indexstore_symbol_relation_get_symbol(relation)
            relations.append(Relation(
                Role(library.indexstore_symbol_relation_get_roles(relation) & ALL_ROLES),
                library.indexstore_symbol_get_usr(related_symbol).text()))
            return True

        library.indexstore_occurrence_relations_apply_f(occurrence, None, VISITOR(note_relation))
        return Occurrence(
            usr=library.indexstore_symbol_get_usr(symbol).text(),
            name=library.indexstore_symbol_get_name(symbol).text(),
            kind=library.indexstore_symbol_get_kind(symbol),
            subkind=library.indexstore_symbol_get_subkind(symbol),
            roles=Role(library.indexstore_occurrence_get_roles(occurrence) & ALL_ROLES),
            path=path,
            line=line.value,
            relations=tuple(relations),
        )

