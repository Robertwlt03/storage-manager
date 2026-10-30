"""The shared look of everything the project prints, so every command reads alike.

Start:  imported by the Python scripts, not started on its own
Needs:  nothing beyond Python
A heading names the command; each result gets a line with a mark (✔ done, ✘ failed, › under way)
and dimmed details; hints follow dimmed and a frame sums up at the end. scripts/console.sh and
Sources/Diagnostics/Console.swift draw the same pieces for the shell scripts and for the app.
Colors appear in a terminal and on GitHub; NO_COLOR=1 turns them off and FORCE_COLOR=1 turns them
on (see no-color.org). A command that asks something uses the questions at the end: yes or no,
a line of text, or a list to walk with the arrow keys.
"""

import os
import re
import sys
import termios
import tty
from collections.abc import Iterator
from contextlib import contextmanager

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

# Questions: a mark in front, the entry the arrow keys point at, and the keys they understand.
QUESTION_MARK = "?"
POINTER_MARK = "›"
YES_ANSWERS = {"y", "yes"}
ENTER_KEYS = {"\r", "\n"}
# The arrow keys send these sequences (terminals send either form); j and k move as in vim.
MOVES = {"\x1b[A": -1, "\x1bOA": -1, "k": -1, "\x1b[B": 1, "\x1bOB": 1, "j": 1}
LONGEST_KEY = 3  # bytes of one arrow key, so one read takes it whole
HIDE_CURSOR, SHOW_CURSOR = "\x1b[?25l", "\x1b[?25h"


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


# MARK: Questions
# They need a person at a terminal; a command checks can_ask() before it asks.


def can_ask() -> bool:
    return sys.stdin.isatty() and IN_TERMINAL


def ask_yes_no(question: str) -> bool:
    """Enter alone answers no."""
    return answer(question, "y/N").lower() in YES_ANSWERS


def ask_text(label: str, meaning: str, current: str = "") -> str:
    """Enter alone keeps the current text; without one, the question comes again."""
    hint = f'{meaning} · Enter keeps "{current}"' if current else meaning
    while not (text := answer(label, hint) or current):
        note("This one needs an answer.")
    return text


def ask_choice(question: str, options: list[str]) -> int:
    """A list to walk with the arrow keys; Enter picks the marked entry and returns its index."""
    show(f"{question_start(question)}  {paint('↑↓ Enter', DIM)}")
    marked = 0
    show_options(options, marked)
    with keys_one_by_one() as read_key:
        while (key := read_key()) not in ENTER_KEYS:
            marked = (marked + MOVES.get(key, 0)) % len(options)
            print(f"\x1b[{len(options)}F", end="")  # up to the first entry, to draw the list again
            show_options(options, marked)
    return marked


def answer(question: str, hint: str) -> str:
    """One line: the question, dimmed what it means, and the answer typed behind it."""
    try:
        return input(f"{question_start(question)}  {paint(hint, DIM)}  ").strip()
    except (KeyboardInterrupt, EOFError):
        print()  # the cursor still stands behind the question
        raise


def question_start(question: str) -> str:
    return f" {paint(QUESTION_MARK, CYAN, BOLD)} {paint(question, BOLD)}"


def show_options(options: list[str], marked: int) -> None:
    for index, option in enumerate(options):
        if index == marked:
            show(f"   {paint(POINTER_MARK, CYAN, BOLD)} {paint(option, BOLD)}")
        else:
            show(f"     {paint(option, DIM)}")


@contextmanager
def keys_one_by_one() -> Iterator:
    """Hands out each key as it is pressed, without Enter, with the cursor hidden meanwhile."""
    keyboard = sys.stdin.fileno()
    saved = termios.tcgetattr(keyboard)
    tty.setcbreak(keyboard)  # unlike raw mode, Ctrl-C still stops the command
    print(HIDE_CURSOR, end="", flush=True)
    try:
        yield lambda: os.read(keyboard, LONGEST_KEY).decode(errors="ignore")
    finally:
        termios.tcsetattr(keyboard, termios.TCSADRAIN, saved)
        print(SHOW_CURSOR, end="", flush=True)
