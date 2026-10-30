"""Checks that methods stay flat: few blocks inside blocks, no function in a function in a function.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
A block is anything that opens on one line and closes on a later one: if, else, switch, a loop,
a closure or an inner function. Inside a method at most MAXIMUM_BLOCK_DEPTH blocks may be open at
once; a deeper part belongs in a method of its own, named for what it does. One-line blocks such
as `.map { entry in entry.name }` do not count. Swift, Python and shell are measured alike.
"""

import ast
import re
from dataclasses import dataclass
from pathlib import Path

from checks.project import Codebase, app, lines_of, place

# MARK: Settings

MAXIMUM_BLOCK_DEPTH = 2
# A function may hold a helper function, but that helper may not hold another one.
MAXIMUM_FUNCTION_NESTING = 1

# The text before a Swift brace that opens the body of a function-like declaration: a function,
# an initializer, a subscript, an accessor or a computed property such as `var body: some View`.
SWIFT_BODY = re.compile(r"""
    \b (?: func | init | deinit | subscript | get | set | willSet | didSet ) \b
    | \b var \s+ \w+ \s* : [^=]* $          # a computed property: a type, but no value
""", re.VERBOSE)
SWIFT_FUNCTION_NAME = re.compile(r"\b(?:func|var)\s+(\w+)|\b(init|subscript)\b")

# Comments and texts, longest forms first: """…""", "…", /* … */ and // to the end of the line.
SWIFT_NOISE = re.compile(r'''
    """ .*? """                 # a text over several lines
    | " (?: \\. | [^"\\\n] )* " # a text on one line
    | /\* .*? \*/               # a block comment
    | // [^\n]*                 # a line comment
''', re.VERBOSE | re.DOTALL)

# Python statements that open a block.
PYTHON_BLOCKS = (
    ast.If, ast.For, ast.AsyncFor, ast.While, ast.With, ast.AsyncWith, ast.Try, ast.Match,
    ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef,
)
PYTHON_FUNCTIONS = (ast.FunctionDef, ast.AsyncFunctionDef)

# Shell: a function starts with `name() {`; blocks open with these words and close with the
# matching ones, unless both stand on the same line.
SHELL_FUNCTION = re.compile(r"^(\w+)\(\)\s*\{")
SHELL_OPENING = re.compile(r"^\s*(?:if|for|while|until|case)\b")
SHELL_CLOSING = re.compile(r"(?:^|[\s;])(?:fi|done|esac)\b")


# MARK: What a check reports


@dataclass(frozen=True)
class DeepPlace:
    """The first line in a method that goes too deep."""

    path: Path
    line: int
    function: str
    problem: str

    def finding(self) -> str:
        return f"{place(self.path, self.line)}: {self.problem} in {self.function}"


def too_deep(blocks: int) -> str:
    return f"{blocks} blocks inside each other, move the inner part into a method of its own"


def too_nested(functions: int) -> str:
    return f"a function inside a function inside a function ({functions} levels)"


# MARK: Step


def nesting_findings() -> list[str]:
    return nesting_problems(app())


def nesting_problems(codebase: Codebase) -> list[str]:
    places = []
    for path in codebase.swift_files():
        places += swift_deep_places(path)
    for path in codebase.python_scripts:
        places += python_deep_places(path)
    for path in codebase.shell_scripts:
        places += shell_deep_places(path)
    return [deep_place.finding() for deep_place in places]


# MARK: Swift


@dataclass
class Brace:
    """An opened brace: its line, and whether it opens the body of a function-like declaration."""

    line: int
    is_body: bool
    name: str


def swift_deep_places(path: Path) -> list[DeepPlace]:
    places = {}
    for brace, enclosing in swift_blocks(path):
        bodies = [index for index, outer in enumerate(enclosing) if outer.is_body]
        if not bodies:
            continue  # not inside a method, such as a type's own braces
        method = enclosing[bodies[0]]
        depth = len(enclosing) - bodies[0]  # this block and the blocks around it in the method
        functions = len(bodies) + brace.is_body - 1
        problem = None
        if functions > MAXIMUM_FUNCTION_NESTING:
            problem = too_nested(functions + 1)
        elif depth > MAXIMUM_BLOCK_DEPTH:
            problem = too_deep(depth)
        if problem and (path, method.line) not in places:
            places[(path, method.line)] = DeepPlace(path, brace.line, method.name, problem)
    return list(places.values())


def swift_blocks(path: Path):
    """Each block that spans lines, with the open blocks around it, outermost first."""
    open_braces: list[Brace] = []
    for number, line in enumerate(swift_code(path).splitlines(), start=1):
        yield from closed_blocks(line, number, open_braces)


def closed_blocks(line: str, number: int, open_braces: list[Brace]):
    """Follows the braces of one line: an opening one is noted with the text before it, a
    closing one ends the latest block, which counts when it began on an earlier line."""
    for segment_start, column, character in braces_of(line):
        if character == "{":
            open_braces.append(opened_brace(line[segment_start:column], number))
            continue
        closed = open_braces.pop() if open_braces else None
        if closed and closed.line != number:
            yield closed, list(open_braces)


def braces_of(line: str):
    """Each brace with its column and where the text before it starts (after the last brace)."""
    segment_start = 0
    for column, character in enumerate(line):
        if character in "{}":
            yield segment_start, column, character
            segment_start = column + 1


def opened_brace(text_before: str, number: int) -> Brace:
    name_match = SWIFT_FUNCTION_NAME.search(text_before)
    name = next(filter(None, name_match.groups()), "") if name_match else ""
    return Brace(number, SWIFT_BODY.search(text_before) is not None, name)


def swift_code(path: Path) -> str:
    """The file with every comment and text blanked out, so their braces do not count; line
    breaks stay where they are."""
    def blank(match: re.Match) -> str:
        return re.sub(r"[^\n]", " ", match.group(0))

    return SWIFT_NOISE.sub(blank, path.read_text())



# MARK: Python


def python_deep_places(path: Path) -> list[DeepPlace]:
    places = []
    tree = ast.parse(path.read_text())
    functions = [node for node in ast.walk(tree) if isinstance(node, PYTHON_FUNCTIONS)]
    for function in functions:
        deep = python_first_deep_place(function, depth=0, functions=1)
        if deep and is_outermost_function(functions, function):
            line, problem = deep
            places.append(DeepPlace(path, line, function.name, problem))
    return places


def is_outermost_function(functions: list[ast.AST], function: ast.AST) -> bool:
    """A function that no other function holds; methods of a class count as outermost."""
    return not any(
        outer is not function and any(inner is function for inner in ast.walk(outer))
        for outer in functions
    )


def python_first_deep_place(node: ast.AST, depth: int, functions: int) -> tuple[int, str] | None:
    for child, child_depth, child_functions in python_children(node, depth, functions):
        if child_functions > MAXIMUM_FUNCTION_NESTING + 1:
            return child.lineno, too_nested(child_functions)
        if child_depth > MAXIMUM_BLOCK_DEPTH:
            return child.lineno, too_deep(child_depth)
        deep = python_first_deep_place(child, child_depth, child_functions)
        if deep:
            return deep
    return None


def python_children(node: ast.AST, depth: int, functions: int):
    """Each child with its depth: a block that spans lines adds one, an `elif` does not."""
    for child in ast.iter_child_nodes(node):
        is_block = isinstance(child, PYTHON_BLOCKS) and child.end_lineno > child.lineno
        is_elif = isinstance(node, ast.If) and isinstance(child, ast.If) and child in node.orelse
        adds_level = is_block and not is_elif
        is_function = isinstance(child, PYTHON_FUNCTIONS)
        yield child, depth + adds_level, functions + is_function


# MARK: Shell


def shell_deep_places(path: Path) -> list[DeepPlace]:
    places = []
    function, depth, reported = "", 0, False
    for number, line in enumerate(lines_of(path), start=1):
        started = SHELL_FUNCTION.match(line)
        if started:
            function, depth, reported = started.group(1), 0, False
            continue
        opens = SHELL_OPENING.match(line) is not None
        closes = SHELL_CLOSING.search(line) is not None
        depth += opens - closes
        if function and opens and not closes and depth > MAXIMUM_BLOCK_DEPTH and not reported:
            places.append(DeepPlace(path, number, function, too_deep(depth)))
            reported = True
    return places
