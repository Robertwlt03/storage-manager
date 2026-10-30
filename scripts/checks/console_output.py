"""Keeps every command's output in one look: everything printed goes through the shared console.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
The console draws headings, lines with marks, hints and frames the same way in every language:
checks/console.py for Python and make (python -m checks.console), and Console.swift for
the app. Any other echo, printf or print is reported. Output that another program reads, not a
person, says so in the head of its script (Output:) and stays plain; the app's own Swift code
outside Diagnostics may not print at all, which the design rules check.
"""

import re
from pathlib import Path

from checks.house_rules import DIAGNOSTICS
from checks.project import Codebase, app, lines_of, numbered_lines, place, relative_path
from checks.tools import HEAD_LINES

# MARK: Settings

CONSOLE_NAME = "console"  # console.py and Console.swift draw the shared look
DATA_OUTPUT = "Output:"  # in a script's head: what it prints is data for another program
SHELL_OUTPUT = re.compile(r"""
    ^ (?! \s* \# )                      # not a comment
    .* (?: \b (?: echo | printf ) \b    # echo or printf ...
         | \b cat \b [^>]* << )          # ... or a text block handed to cat ...
    (?! .* > \s* [^&\s] )               # ... unless it goes into a file
""", re.VERBOSE)
PYTHON_OUTPUT = re.compile(r"""
    ^ (?! \s* \# )                      # not a comment
    .* (?: \b print \(                  # a call of print ...
         | \b sys \. std (?: out | err ) \. write \b )  # ... or a direct write
    (?! .* \b file \s* = )              # ... unless it goes into a file
""", re.VERBOSE)
SWIFT_OUTPUT = re.compile(r"""
    ^ (?! \s* // )                       # not a comment
    .* (?: \b (?: print | debugPrint | dump | fputs | NSLog ) \(   # a printing function
         | \b FileHandle \. standard (?: Output | Error ) \b )     # or the terminal itself
""", re.VERBOSE)
MESSAGE = (
    "prints past the shared console; use its pieces (checks/console.py, "
    "Console.swift), or name data for another program in the head (Output:)"
)


# MARK: Steps


def prints_data(path: Path) -> bool:
    return any(line.lstrip("#/ ").startswith(DATA_OUTPUT) for line in lines_of(path)[:HEAD_LINES])


def output_problems_in(paths: tuple[Path, ...], output: re.Pattern) -> list[str]:
    checked = [
        path for path in paths if path.stem.lower() != CONSOLE_NAME and not prints_data(path)
    ]
    return [
        f"{place(path, number)}: {MESSAGE}"
        for path, number, line in numbered_lines(checked) if output.search(line)
    ]


def swift_files_that_may_print(codebase: Codebase) -> tuple[Path, ...]:
    """The scripts and Diagnostics; the design rules keep the rest of the app silent."""
    diagnostics = [path for path in codebase.swift_sources
                   if relative_path(path).startswith(DIAGNOSTICS)]
    return (*codebase.swift_scripts, *diagnostics)


# MARK: Step


def console_output_findings() -> list[str]:
    return console_output_problems(app())


def console_output_problems(codebase: Codebase) -> list[str]:
    return (
        output_problems_in(codebase.shell_scripts + codebase.makefiles, SHELL_OUTPUT)
        + output_problems_in(codebase.python_scripts, PYTHON_OUTPUT)
        + output_problems_in(swift_files_that_may_print(codebase), SWIFT_OUTPUT)
    )
