"""Checks that names and comments are understandable American English.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index and the macOS spell checker, see unknown_words.swift)
Every name we declare is split into its words (fileCount: file, count). Each word must be an
American English word or a known technical term, and never an abbreviation. Comments are read the
same way, apart from code in backticks, paths and links.
"""

import ast
import io
import re
import tokenize
from dataclasses import dataclass
from pathlib import Path

from checks.index_store import IndexStore, Kind, Role
from checks.project import (
    BUILD_FOLDER, BUILD_OPTIONS, MAKEFILE, PROJECT, SCRIPTS, lines_of, place, python_scripts, run,
    shell_scripts, swift_scripts, swift_sources, swift_tests,
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

# Words the dictionary does not know but every reader of this code does: names of products,
# frameworks and tools, and the established short forms of the platform.
KNOWN_TERMS = {
    "app", "appkit", "apps", "async", "bool", "bundle", "cg", "codesign", "cpu", "css", "dmg",
    "docstring", "docstrings", "fts", "github", "gzip", "hdiutil", "html", "http", "https",
    "icns", "iconset", "id", "ids", "ios", "json", "lproj", "mac", "macos", "md",
    "nonisolated", "npm", "ns", "os", "pdf", "pid", "plist", "png", "py", "rgb", "rgba", "sdk",
    "sf", "sh", "sips", "speicher", "stdout", "svg", "swift", "swiftlint", "swiftpm",
    "swiftui", "symlink", "symlinks", "tcc", "ui", "uikit", "url", "urls", "usr", "utf",
    "uuid", "xcode", "xcrun", "yaml",
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


def declared_names(index_names: list[Name]) -> list[Name]:
    names = index_names + swift_local_names() + python_names() + shell_names()
    first = {}
    for name in names:
        first.setdefault(name.text, name)
    return list(first.values())


def swift_index_names() -> list[Name]:
    """Every declaration in Sources and Tests, with argument labels: scan(_:progress:)."""
    store = IndexStore(next(BUILD_FOLDER.glob("**/index/store")))
    names = []
    for found in store.occurrences(inside=PROJECT):
        is_ours = found.roles & Role.DEFINITION and not found.roles & Role.IMPLICIT
        if is_ours and not found.is_accessor() and found.kind in set(Kind):
            for part in re.split(r"[(:)]", found.name):
                names.append(Name(part, place(found.path, found.line)))
    return [name for name in names if name.text not in ("", "_")]


def swift_local_names() -> list[Name]:
    names = []
    for path in swift_sources() + swift_tests() + swift_scripts():
        for number, line in enumerate(lines_of(path), start=1):
            code = line.split("//", 1)[0]
            for pattern in (SWIFT_LOCAL_NAME, SWIFT_DECLARATION):
                for match in pattern.finditer(code):
                    for group in filter(None, match.groups()):
                        where = place(path, number)
                        names += [Name(text.strip(), where) for text in group.split(",")]
    return names


def python_names() -> list[Name]:
    names = []
    for path in python_scripts():
        for node in ast.walk(ast.parse(path.read_text())):
            text = declared_python_name(node)
            if text:
                names.append(Name(text, place(path, node.lineno)))
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


def shell_names() -> list[Name]:
    names = []
    for path in shell_scripts() + [MAKEFILE]:
        pattern = MAKE_VARIABLE if path == MAKEFILE else SHELL_NAME
        for number, line in enumerate(lines_of(path), start=1):
            for match in pattern.finditer(line):
                names += [Name(text, place(path, number)) for text in filter(None, match.groups())]
    return names


def comment_words() -> list[CommentWord]:
    """Every prose word of every comment, so each place with a problem is named."""
    words = []
    for path, number, comment in comments():
        for word in PLAIN_WORD.findall(NOT_PROSE.sub(" ", comment)):
            if not CODE_NAME.search(word):
                words.append(CommentWord(word, place(path, number)))
    return words


def comments():
    """Each comment with its file and line: Swift //, Python # and docstrings, shell #."""
    for path in swift_sources() + swift_tests() + swift_scripts():
        for number, line in enumerate(lines_of(path), start=1):
            if "//" in line:
                yield path, number, line.split("//", 1)[1]
    for path in python_scripts():
        yield from python_comments(path)
    for path in shell_scripts() + [MAKEFILE]:
        for number, line in enumerate(lines_of(path), start=1):
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


def name_words(name: Name) -> list[str]:
    return [part.lower() for part in NAME_PART.findall(name.text) if len(part) > 1]


def unknown_words(words: set[str]) -> dict[str, tuple[str, str]]:
    """Each word the American dictionary lacks: whether it is British, and the best guess."""
    to_check = sorted(word for word in words if word not in KNOWN_TERMS)
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
    result = run(["swift", "build", "--build-tests", *BUILD_OPTIONS])  # writes the index
    if not result.succeeded:
        return result.findings(result.diagnostics())
    names = declared_names(swift_index_names())
    words = comment_words()
    all_words = {part for name in names for part in name_words(name)}
    all_words |= {word.text.lower() for word in words}
    verdicts = unknown_words(all_words)
    findings = []
    for name in names:
        for part in name_words(name):
            found = problem(part, verdicts, check_abbreviations=True)
            if found:
                findings.append(f"{name.place}: '{part}' in {name.text} {found}")
    for word in words:
        found = problem(word.text.lower(), verdicts, check_abbreviations=False)
        if found:
            findings.append(f"{word.place}: comment word '{word.text}' {found}")
    return sorted(set(findings))
