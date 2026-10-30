"""Keeps the repository English: German belongs only in the app's translations.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
A line counts as German when it holds an umlaut or the sharp s, or at least two words that only
German uses, such as its words for "and" and "not". Every file git knows is read: guides,
templates, scripts, pictures drawn as SVG and settings. The translations in Resources are the one
place German belongs, and German text in Swift code is left to the house rules, which already
report it.
"""

import re
from pathlib import Path

from checks.house_rules import GERMAN_LETTER
from checks.project import Codebase, app, is_text, numbered_lines, place

# MARK: Settings

SWIFT = ".swift"
# Words German uses and English does not, one per line, so this list never reads as German.
GERMAN_ONLY_WORDS = {
    "und",
    "nicht",
    "ist",
    "der",
    "das",
    "mit",
    "auf",
    "wird",
    "sich",
    "oder",
    "auch",
    "eine",
    "einen",
    "zum",
    "zur",
    "wenn",
    "dann",
    "weil",
    "kein",
    "keine",
    "werden",
    "sind",
    "noch",
    "nur",
}
WORD = re.compile(r"\b[a-z]+\b")  # lowercase only, so the license name MIT never counts
WORDS_THAT_MAKE_GERMAN = 2  # one such word can be a name; two in a line are a sentence


# MARK: Steps


def is_german(line: str) -> bool:
    german_words = set(WORD.findall(line)) & GERMAN_ONLY_WORDS
    return bool(GERMAN_LETTER.search(line)) or len(german_words) >= WORDS_THAT_MAKE_GERMAN


def files_to_read(codebase: Codebase) -> list[Path]:
    """Every text file, without the translations and without Swift code."""
    paths = set(codebase.text_files) | set(codebase.guides)
    translations = codebase.translations
    return sorted(
        path for path in paths
        if is_text(path) and path.suffix != SWIFT
        and not (translations and path.is_relative_to(translations))
    )


# MARK: Step


def english_only_findings() -> list[str]:
    return english_only_problems(app())


def english_only_problems(codebase: Codebase) -> list[str]:
    return [
        f"{place(path, number)}: German text outside the app's translations; the repository is "
        "English, German belongs only in Resources"
        for path, number, line in numbered_lines(files_to_read(codebase)) if is_german(line)
    ]
