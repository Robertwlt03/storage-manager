"""The shared look of everything the project prints, so every command reads alike.

Start:  imported by the Python scripts; or one piece at a time, as make and the Swift scripts do:
        python3 -m checks.console passed "Built" "build/…" (with scripts/ on PYTHONPATH)
Needs:  nothing beyond Python
A heading names the command; each result gets a line with a mark (✔ done, ✘ failed, › under way)
and dimmed details; hints follow dimmed and a frame sums up at the end.
Sources/Diagnostics/Console.swift draws the same pieces for the app.
Colors appear in a terminal and on GitHub; NO_COLOR=1 turns them off and FORCE_COLOR=1 turns them
on (see no-color.org). Spacing follows one rule, so two blank lines never meet: only the heading
starts with a blank line, and every block (heading, question, group, frame) ends with one; only
the frame at the end leaves it out where no prompt follows, such as in GitHub's log.
A command that asks something uses the questions at the end: yes or no,
a line of text, or a list to walk with the arrow keys.
"""

import os
import re
import subprocess
import sys
import termios
import threading
import tty
from collections.abc import Callable, Iterator
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
STEP_MARK = "›"
FRAME_COLORS = {"success": SUCCESS, "failure": FAILURE}  # the kinds of frame make can ask for
# A wheel turns in front of a step while it runs, so a long step does not look stuck.
SPINNER_FRAMES = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
SPINNER_SECONDS = 0.08
GROUP_MARK = "▸"
NOTE_INDENT = "   "  # hints start below the text of a result line
TABLE_WIDTH = 16  # the names of a table fill this many characters, so the texts line up
ENTRY_INDENT = "       "
ENTRY_LABEL_WIDTH = 5  # wide enough for a line number such as 12345
HEADED = "CONSOLE_HEADED"  # set once a heading shows; what the command starts leaves out its own
CLEAR_LINE = "\r\x1b[K"  # back to the start of the line and erase it
COLOR_CODE = re.compile(r"\x1b\[[0-9;]*m")

# Questions: a mark in front, the line the answer is typed on, the entries of a list, and the keys
# the list understands.
QUESTION_MARK = "?"
ANSWER_MARK = "❯"
MARKED_ENTRY, OTHER_ENTRY = "●", "○"
YES_ANSWERS, NO_ANSWERS = {"y", "yes"}, {"n", "no"}
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
    """Every piece ends here; in a terminal it first stops the wheel and erases its line."""
    relay(f"{text}\n")


# MARK: What a command prints


def heading(title: str, detail: str = "") -> None:
    """Opens a command; once only, so a script another command started adds no second one."""
    if os.environ.get(HEADED):
        return
    os.environ[HEADED] = "1"
    show(f"\n{paint(title, BOLD)}  {paint(detail, DIM)}\n")


class Spinner(threading.Thread):
    """Draws the wheel and the text again and again, in a thread of its own, until it is stopped."""

    def __init__(self, text: str) -> None:
        super().__init__(daemon=True)  # Ctrl-C ends the command without waiting for the wheel
        self.text = text
        self.stopped = threading.Event()

    def run(self) -> None:
        frame = 0
        while True:
            wheel = paint(SPINNER_FRAMES[frame % len(SPINNER_FRAMES)], CYAN, BOLD)
            print(f"{CLEAR_LINE} {wheel} {paint(self.text, DIM)}", end="", flush=True)
            if self.stopped.wait(SPINNER_SECONDS):
                return
            frame += 1


turning: list[Spinner] = []  # the wheel that turns right now, if any


def running(text: str) -> None:
    """A turning wheel and the text while something runs; the next piece replaces it. Only in a
    terminal: a log on GitHub gets the result lines alone."""
    stop_running()
    if IN_TERMINAL:
        turning.append(Spinner(text))
        turning[-1].start()


def stop_running() -> None:
    while turning:
        spinner = turning.pop()
        spinner.stopped.set()
        spinner.join()


def passed(text: str, detail: str = "") -> None:
    result_line(paint(PASSED_MARK, GREEN, BOLD), text, detail)


def failed(text: str, detail: str = "") -> None:
    result_line(paint(FAILED_MARK, RED, BOLD), text, detail)


def step(text: str, detail: str = "") -> None:
    result_line(paint(STEP_MARK, CYAN, BOLD), text, detail)


def wait(text: str, command: list[str], folder: str | os.PathLike | None = None) -> int:
    """Runs a command (in a folder, if given) with the wheel turning in front of the text, then
    shows what it printed and returns its status. In a log, on GitHub for instance, a step line
    and the output as it comes."""
    if not IN_TERMINAL:
        step(text)
        sys.stdout.flush()  # the step line before what the command prints itself
        return subprocess.run(command, cwd=folder).returncode
    running(text)
    result = subprocess.run(
        command, cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        errors="replace",  # a byte outside UTF-8 shows as a placeholder instead of stopping
    )
    relay(result.stdout)
    return result.returncode


def relay(text: str) -> None:
    """What another program printed, as it printed it, after the wheel's line is gone."""
    stop_running()
    print(f"{CLEAR_LINE if IN_TERMINAL else ''}{text}", end="", flush=True)


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


def frame(outcome: str, details: list[str], color: str) -> None:
    """Ends a command, the same shape everywhere: the outcome after its mark, then below it what
    it concerns, such as the file or folder it made."""
    mark = PASSED_MARK if color == SUCCESS else FAILED_MARK
    lines = [paint(f"{mark} {outcome}", color, BOLD)] + [f"  {detail}" for detail in details]
    width = max(visible_length(line) for line in lines) + 2
    show(" " + paint("╭" + "─" * width + "╮", color))
    side = paint("│", color)
    for line in lines:
        padding = " " * (width - visible_length(line) - 1)
        show(f" {side} {line}{padding}{side}")
    show(" " + paint("╰" + "─" * width + "╯", color) + ("\n" if IN_TERMINAL else ""))


def data(text: str) -> None:
    """Plain text another program reads, such as GitHub; never colored."""
    stop_running()
    print(text)


# MARK: Questions
# They need a person at a terminal; a command checks can_ask() before it asks.


def can_ask() -> bool:
    return sys.stdin.isatty() and IN_TERMINAL


def ask_yes_no(question: str) -> bool:
    """Enter alone answers no; another answer than y or n is named and the question comes again."""
    def problem(reply: str) -> str:
        return "" if reply.lower() in YES_ANSWERS | NO_ANSWERS else f'"{reply}" is neither y nor n.'
    return ask_until(question, "y/n", problem, current="n").lower() in YES_ANSWERS


def ask_text(label: str, meaning: str, current: str = "",
             problem: Callable[[str], str] = lambda text: "") -> str:
    """Enter alone keeps the current text. problem names what is wrong with an answer, or says
    nothing when it fits; a wrong answer is named and the question comes again."""
    hint = f'{meaning} · Enter keeps "{current}"' if current else meaning
    return ask_until(label, hint, problem, current)


def ask_until(question: str, hint: str, problem: Callable[[str], str], current: str = "") -> str:
    while True:
        ask(question, hint)
        reply = answer() or current
        wrong = problem(reply) if reply else "This one needs an answer."
        if not wrong:
            show("")
            return reply
        show(f"   {paint(FAILED_MARK, RED, BOLD)} {wrong}")
        show("")


def ask_choice(question: str, options: list[str]) -> int:
    """A list to walk with the arrow keys; Enter picks the marked entry and returns its index."""
    ask(question, "↑↓ Enter")
    marked = 0
    show_options(options, marked)
    with keys_one_by_one() as read_key:
        while (key := read_key()) not in ENTER_KEYS:
            marked = (marked + MOVES.get(key, 0)) % len(options)
            print(f"\x1b[{len(options)}F", end="")  # up to the first entry, to draw the list again
            show_options(options, marked)
    show("")
    return marked


def ask(question: str, hint: str) -> None:
    """The question, and dimmed a few words on what it means or how to answer."""
    show(f" {paint(QUESTION_MARK, CYAN, BOLD)} {paint(question, BOLD)}  {paint(hint, DIM)}")


def answer() -> str:
    """The answer is typed on the line below its question."""
    try:
        return input(f"   {paint(ANSWER_MARK, CYAN, BOLD)} ").strip()
    except (KeyboardInterrupt, EOFError):
        print()  # the cursor still stands on the answer line
        raise


def show_options(options: list[str], marked: int) -> None:
    for index, option in enumerate(options):
        if index == marked:
            show(f"   {paint(MARKED_ENTRY, CYAN, BOLD)} {paint(option, BOLD)}")
        else:
            show(f"   {paint(OTHER_ENTRY, DIM)} {paint(option, DIM)}")


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


# MARK: Run
# make and the Swift scripts draw one piece at a time: python3 -m checks.console <piece> <text>…


def main(arguments: list[str]) -> int:
    # Each piece and how many texts it takes at most: a text and a detail, or a hint alone.
    pieces = {"heading": (heading, 2), "passed": (passed, 2), "failed": (failed, 2),
              "step": (step, 2), "note": (note, 1)}
    match arguments:
        case [piece, *texts] if piece in pieces and 1 <= len(texts) <= pieces[piece][1]:
            pieces[piece][0](*texts)
        case ["table"]:  # reads "name<tab>text" lines
            table([line.rstrip("\n").partition("\t")[::2] for line in sys.stdin])
        case ["frame", kind, outcome, *details] if kind in FRAME_COLORS:
            frame(outcome, details, FRAME_COLORS[kind])
        case ["wait", text, *command] if command:
            return wait(text, command)
        case _:
            failed("Unknown piece", " ".join(arguments))
            note("heading, passed, failed, step, note, table, frame <success|failure>, wait")
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
