"""The shared look of everything the project prints, so every command reads alike.

Start:  imported by the Python scripts, not started on its own
Needs:  nothing beyond Python
A heading names the command; each result gets a line with a mark (✔ done, ✘ failed, › under way)
and dimmed details; hints follow dimmed and a frame sums up at the end. scripts/console.sh and
Sources/Diagnostics/Console.swift draw the same pieces for the shell scripts and for the app.
Colors appear in a terminal and on GitHub; NO_COLOR=1 turns them off and FORCE_COLOR=1 turns them
on (see no-color.org).
"""

import os
import re
import sys

# MARK: Settings

ON_GITHUB = os.environ.get("GITHUB_ACTIONS") == "true"
IN_TERMINAL = sys.stdout.isatty()
USES_COLOR = "NO_COLOR" not in os.environ and (
    IN_TERMINAL or ON_GITHUB or "FORCE_COLOR" in os.environ
)

# Terminal codes for text styles (ECMA-48 "select graphic rendition").
BOLD, DIM, RED, GREEN, CYAN = "1", "2", "31", "32", "36"
SUCCESS, FAILURE = GREEN, RED  # the colors of a frame

PASSED_MARK = "✔"
FAILED_MARK = "✘"
RUNNING_MARK = "…"
GROUP_MARK = "▸"
NOTE_INDENT = "   "  # hints start below the text of a result line
TABLE_WIDTH = 16  # the names of a table fill this many characters, so the texts line up
ENTRY_INDENT = "       "
ENTRY_LABEL_WIDTH = 5  # wide enough for a line number such as 12345
CLEAR_LINE = "\r\x1b[K"  # back to the start of the line and erase it
COLOR_CODE = re.compile(r"\x1b\[[0-9;]*m")


# MARK: Pieces


def paint(text: str, *styles: str) -> str:
    if not USES_COLOR or not styles:
        return text
    return f"\x1b[{';'.join(styles)}m{text}\x1b[0m"


def visible_length(text: str) -> int:
    return len(COLOR_CODE.sub("", text))


def show(text: str) -> None:
    """Every piece ends here; in a terminal it first erases a line that said what is running."""
    print(f"{CLEAR_LINE if IN_TERMINAL else ''}{text}")


# MARK: What a command prints


def heading(title: str, detail: str = "") -> None:
    show(f"\n{paint(title, BOLD)}  {paint(detail, DIM)}\n")


def running(text: str) -> None:
    """A dim line while something runs, which the next piece replaces; only in a terminal."""
    if IN_TERMINAL:
        print(paint(f" {RUNNING_MARK} {text}", DIM), end="", flush=True)


def passed(text: str, detail: str = "") -> None:
    result_line(paint(PASSED_MARK, GREEN, BOLD), text, detail)


def failed(text: str, detail: str = "") -> None:
    result_line(paint(FAILED_MARK, RED, BOLD), text, detail)


def result_line(mark: str, text: str, detail: str) -> None:
    show(f" {mark} {text}" + (f"  {paint(detail, DIM)}" if detail else ""))


def note(text: str) -> None:
    show(paint(f"{NOTE_INDENT}{text}", DIM))


def group(title: str) -> None:
    """The head of a group of entries, such as the findings in one file."""
    show(f"     {paint(GROUP_MARK, CYAN)} {paint(title, CYAN, BOLD)}")


def entry(label: str, text: str) -> None:
    """One entry of a group, after a dim label such as its line number."""
    show(f"{ENTRY_INDENT}{paint(label.rjust(ENTRY_LABEL_WIDTH), DIM)}  {text}")


def table(rows: list[tuple[str, str]]) -> None:
    for name, text in rows:
        show(f"  {paint(name.ljust(TABLE_WIDTH), CYAN, BOLD)} {text}")


def frame(lines: list[str], color: str) -> None:
    width = max(visible_length(line) for line in lines) + 2
    show("\n " + paint("╭" + "─" * width + "╮", color))
    side = paint("│", color)
    for line in lines:
        padding = " " * (width - visible_length(line) - 1)
        show(f" {side} {paint(line, color, BOLD)}{padding}{side}")
    show(" " + paint("╰" + "─" * width + "╯", color) + "\n")


def data(text: str) -> None:
    """Plain text another program reads, such as GitHub; never colored."""
    print(text)
