"""Checks that names and comments are understandable American English.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index and the macOS spell checker, see unknown_words.swift)
Every name we declare is split into its words (fileCount: file, count). Each word must be an
American English word or a known technical term, and never an abbreviation. Comments are read the
same way, apart from code in backticks, paths and links.
"""

import ast
import io
import plistlib
import re
import shutil
import sys
import tokenize
from dataclasses import dataclass
from pathlib import Path

from checks.index_store import Kind, Role
from checks.project import (
    PROJECT, SCRIPTS, Codebase, CompilerIndex, app, compiler_index, numbered_lines, place, run,
)

# MARK: Settings

SPELL_CHECKER = SCRIPTS / "checks" / "unknown_words.swift"

# Short forms to spell out, with the word to write instead.
ABBREVIATIONS = {
    "arg": "argument", "args": "arguments", "arr": "array", "attr": "attribute", "bg": "background",
    "btn": "button", "calc": "calculate", "cb": "callback", "cfg": "configuration",
    "config": "configuration", "ctx": "context", "cur": "current", "curr": "current",
    "db": "database", "dest": "destination", "dict": "dictionary", "dir": "folder",
    "dirs": "folders", "dst": "destination", "elem": "element", "env": "environment",
    "err": "error", "evt": "event", "ext": "extension", "fn": "function", "func": "function",
    "idx": "index", "img": "image", "impl": "implementation", "len": "length", "lib": "library",
    "max": "maximum", "min": "minimum", "msg": "message", "num": "number", "obj": "object",
    "param": "parameter", "params": "parameters", "pkg": "package", "pos": "position",
    "prev": "previous", "proc": "process", "req": "request", "res": "result",
    "resp": "response", "sec": "seconds", "seq": "sequence", "src": "source",
    "stats": "statistics", "str": "string", "temp": "temporary", "tmp": "temporary",
    "util": "utility", "utils": "utilities", "val": "value", "vol": "volume",
}

# British spellings the American dictionary accepts as variants, with the American word.
BRITISH_VARIANTS = {
    "cancelled": "canceled", "cancelling": "canceling", "centre": "center", "grey": "gray",
    "labelled": "labeled", "modelling": "modeling", "travelled": "traveled",
    "favourite": "favorite", "catalogue": "catalog", "programme": "program", "metre": "meter",
    "whilst": "while", "amongst": "among",
}


# Name parts: an acronym in the plural (selectedIDs: IDs), an acronym before a capitalized word
# (NSWorkspace: NS), a capitalized or lower case word (fileCount: file, Count), or an acronym at
# the end (macOS: OS).
NAME_PART = re.compile(r"""
    [A-Z]{2,} s (?! [a-z] )     # an acronym in the plural: IDs
    | [A-Z]+ (?= [A-Z][a-z] )   # an acronym that a capitalized word follows
    | [A-Z]? [a-z]+             # a word, maybe capitalized
    | [A-Z]+                    # an acronym
""", re.VERBOSE)

# What a comment holds besides words: code in backticks, links, paths and file names.
NOT_PROSE = re.compile(r"""
    `[^`]*`                     # `code`
    | \w+://\S+                 # a link
    | \S* [/\\] \S*              # a path such as Sources/App or dist/
    | \S+ \. \w+                 # a file name such as check.py
""", re.VERBOSE)
PLAIN_WORD = re.compile(r"\b[A-Za-z]+(?:'[a-z]+)?\b")  # letters only, maybe with 's or 't
# A word with a second capital letter is a name or an acronym, not prose: fileCount, WCAG.
CODE_NAME = re.compile(r"^.+[A-Z]")

# Swift names the compiler's index does not hold: local values, loop and closure parameters.
SWIFT_LOCAL_NAME = re.compile(r"""
    \b (?: let | var ) \s+ (\w+)                # let total = …
    | \b for \s+ (\w+) \s+ in \b                # for entry in …
    | \{ \s* \(? ( \w+ (?: \s*,\s* \w+ )* ) \)? \s+ in \b   # { entry, index in
""", re.VERBOSE)
# Declarations in Swift scripts, which the index does not cover (enum cases come from the index:
# a `case` in a script's switch would only name something declared elsewhere).
SWIFT_DECLARATION = re.compile(r"""
    \b (?: func | struct | enum | class | protocol | typealias ) \s+ ( [A-Za-z_]\w* )
""", re.VERBOSE)
SHELL_NAME = re.compile(r"""
    ^ \s* (?: local \s+ )? ([A-Za-z_]\w*) =     # NAME=… or local name=…
    | ^ \s* ([A-Za-z_]\w*) \(\) \s* \{          # a function: name() {
    | \b for \s+ (\w+) \s+ in \b                # for size in …
""", re.VERBOSE)
MAKE_VARIABLE = re.compile(r"^([A-Z_]+) \s* [?:]?=", re.VERBOSE)
SHELL_COMMENT = re.compile(r"(?:^|\s)#(?!!)(.*)$")  # from # to the end, not the #! line


# MARK: Words with their places


@dataclass(frozen=True)
class Name:
    """A name we declared, where it is declared first."""

    text: str
    place: str


@dataclass(frozen=True)
class CommentWord:
    text: str
    place: str


def declared_names(codebase: Codebase, index: CompilerIndex) -> list[Name]:
    names = (
        swift_index_names(index) + swift_local_names(codebase) + python_names(codebase)
        + shell_names(codebase)
    )
    first = {}
    for name in names:
        first.setdefault(name.text, name)
    return list(first.values())


def swift_index_names(index: CompilerIndex) -> list[Name]:
    """Every declaration in the Swift code, with argument labels: scan(_:progress:)."""
    definitions = [found for found in index.occurrences if is_written_definition(found)]
    names = [
        Name(part, place(found.path, found.line))
        for found in definitions
        for part in re.split(r"[(:)]", found.name)
    ]
    return [name for name in names if name.text not in ("", "_")]


def is_written_definition(found) -> bool:
    """A declaration written in our code, not one a macro or the compiler adds, nor an accessor."""
    is_ours = found.roles & Role.DEFINITION and not found.roles & Role.IMPLICIT
    return bool(is_ours) and not found.is_accessor() and found.kind in set(Kind)


def swift_local_names(codebase: Codebase) -> list[Name]:
    names = []
    for path, number, line in numbered_lines(codebase.swift_files()):
        code = line.split("//", 1)[0]
        names += names_in_line(code, place(path, number), (SWIFT_LOCAL_NAME, SWIFT_DECLARATION))
    return names


def names_in_line(code: str, where: str, patterns: tuple) -> list[Name]:
    """Every name the patterns find; a group can list several: `{ entry, index in`."""
    groups = [
        group for pattern in patterns for match in pattern.finditer(code)
        for group in match.groups() if group
    ]
    return [Name(text.strip(), where) for group in groups for text in group.split(",")]


def python_names(codebase: Codebase) -> list[Name]:
    names = []
    for path in codebase.python_scripts:
        nodes = ast.walk(ast.parse(path.read_text()))
        declared = [(node, text) for node in nodes if (text := declared_python_name(node))]
        names += [Name(text, place(path, node.lineno)) for node, text in declared]
    return names


def declared_python_name(node: ast.AST) -> str | None:
    if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and not is_python_special(node.name):
        return node.name
    if isinstance(node, ast.arg):
        return node.arg
    if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
        return node.id
    # Only our own attributes count: self.name = …, not a library's such as function.argtypes.
    is_own_attribute = isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name)
    if is_own_attribute and node.value.id == "self" and isinstance(node.ctx, ast.Store):
        return node.attr
    return None


def is_python_special(name: str) -> bool:
    """Methods such as __init__ that Python itself names."""
    return name.startswith("__") and name.endswith("__")


def shell_names(codebase: Codebase) -> list[Name]:
    names = []
    for path, number, line in numbered_lines(codebase.shell_scripts + codebase.makefiles):
        pattern = MAKE_VARIABLE if path in codebase.makefiles else SHELL_NAME
        names += names_in_line(line, place(path, number), (pattern,))
    return names


def comment_words(codebase: Codebase) -> list[CommentWord]:
    """Every prose word of every comment, so each place with a problem is named."""
    words = []
    for path, number, comment in comments(codebase):
        prose = PLAIN_WORD.findall(NOT_PROSE.sub(" ", comment))
        where = place(path, number)
        words += [CommentWord(word, where) for word in prose if not CODE_NAME.search(word)]
    return words


def comments(codebase: Codebase):
    """Each comment with its file and line: Swift //, Python # and docstrings, shell #."""
    for path, number, line in numbered_lines(codebase.swift_files()):
        if "//" in line:
            yield path, number, line.split("//", 1)[1]
    for path in codebase.python_scripts:
        yield from python_comments(path)
    for path, number, line in numbered_lines(codebase.shell_scripts + codebase.makefiles):
        match = SHELL_COMMENT.search(line)
        if match:
            yield path, number, match.group(1)


def python_comments(path: Path):
    source = path.read_text()
    for token in tokenize.generate_tokens(io.StringIO(source).readline):
        if token.type == tokenize.COMMENT:
            yield path, token.start[0], token.string
    for node in ast.walk(ast.parse(source)):
        documented = (ast.Module, ast.ClassDef, ast.FunctionDef)
        if isinstance(node, documented) and ast.get_docstring(node):
            line = node.body[0].lineno
            yield path, line, ast.get_docstring(node)


# MARK: Judging words


def words_of(name: str) -> list[str]:
    return [part.lower() for part in NAME_PART.findall(name) if len(part) > 1]


def known_terms(codebase: Codebase, index: CompilerIndex) -> set[str]:
    """Words no dictionary has but every reader of this code knows, gathered from what the code
    uses instead of from a list:
    - the names of the platform's interfaces the Swift code calls (NSWorkspace gives "ns"),
    - the names the Python scripts use from Python itself (ast.get_docstring gives "docstring"),
    - the modules of Python's standard library, the app's name and the project's file endings.
    Commands installed on this Mac, such as codesign, count as well (see is_known_term)."""
    ours = {found.unique_name for found in index.occurrences if found.roles & Role.DEFINITION}
    platform_names = {
        found.name for found in index.occurrences
        if found.roles & Role.REFERENCE and found.unique_name not in ours
    }
    platform_names |= python_used_names(codebase)
    terms = {word for name in platform_names for word in words_of(name)}
    terms |= {name.lower() for name in platform_names if name.isalpha()}  # SwiftUI as one word
    terms |= set(sys.stdlib_module_names)
    app_name = plistlib.loads((PROJECT / "Info.plist").read_bytes())["CFBundleName"]
    terms |= set(words_of(app_name))
    tracked_files = run(["git", "ls-files"]).output.splitlines()
    return terms | {Path(file).suffix.lstrip(".").lower() for file in tracked_files}


def python_used_names(codebase: Codebase) -> set[str]:
    """Names the Python scripts use but do not declare, such as ctypes.c_char_p."""
    used = set()
    for path in codebase.python_scripts:
        nodes = ast.walk(ast.parse(path.read_text()))
        used |= {name for node in nodes if (name := loaded_python_name(node))}
    declared = {name.text for name in python_names(codebase)}
    return used - declared


def loaded_python_name(node: ast.AST) -> str | None:
    """The name a node reads: a variable, or an attribute such as c_char_p in ctypes.c_char_p."""
    if isinstance(node, ast.Attribute) and isinstance(node.ctx, ast.Load):
        return node.attr
    if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load):
        return node.id
    return None


def is_known_term(word: str, terms: set[str]) -> bool:
    """A known term, its plural (docstrings), or a command installed on this Mac."""
    singular = word.removesuffix("s")
    return word in terms or singular in terms or shutil.which(word) is not None


def unknown_words(words: set[str], terms: set[str]) -> dict[str, tuple[str, str]]:
    """Each word the American dictionary lacks: whether it is British, and the best guess."""
    to_check = sorted(word for word in words if not is_known_term(word, terms))
    result = run(["swift", str(SPELL_CHECKER)], given_input="\n".join(to_check))
    verdicts = {}
    for line in result.output.splitlines():
        word, kind, guess = (line.split("\t") + ["", ""])[:3]
        verdicts[word] = (kind, guess)
    return verdicts


def problem(word: str, verdicts: dict, check_abbreviations: bool) -> str | None:
    if check_abbreviations and word in ABBREVIATIONS:
        return f"is short for '{ABBREVIATIONS[word]}'"
    if word in BRITISH_VARIANTS:
        return f"is British; American English writes '{BRITISH_VARIANTS[word]}'"
    if word not in verdicts:
        return None
    kind, guess = verdicts[word]
    if kind == "british":
        return f"is British; American English writes '{guess}'"
    return "is not an English word" + (f"; maybe '{guess}'" if guess else "")


# MARK: Step


def language_findings() -> list[str]:
    return language_problems(app())


def language_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    names = declared_names(codebase, index)
    words = comment_words(codebase)
    all_words = {part for name in names for part in words_of(name.text)}
    all_words |= {word.text.lower() for word in words}
    verdicts = unknown_words(all_words, known_terms(codebase, index))
    return sorted(set(name_problems(names, verdicts) + comment_problems(words, verdicts)))


def name_problems(names: list[Name], verdicts: dict) -> list[str]:
    return [
        f"{name.place}: '{part}' in {name.text} {found}"
        for name in names
        for part in words_of(name.text)
        if (found := problem(part, verdicts, check_abbreviations=True))
    ]


def comment_problems(words: list[CommentWord], verdicts: dict) -> list[str]:
    return [
        f"{word.place}: comment word '{word.text}' {found}"
        for word in words
        if (found := problem(word.text.lower(), verdicts, check_abbreviations=False))
    ]
