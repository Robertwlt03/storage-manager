"""Finds texts that were copied from English instead of translated.

Start:  imported by scripts/check.py, not started on its own
Needs:  macOS (plutil reads the translation files, the spell checker knows 40 languages)
A text that reads exactly like the English one is fine when the language uses the same words,
such as "Downloads" in German, or when it is shared by most languages, such as "iCloud Drive" or
"1–10 MB". Otherwise one of its words is unknown to that language's dictionary, and the text is
reported. For a language macOS has no dictionary for, every word counts as unknown, so a text
copied into Japanese or Chinese never slips through.
"""

import json
import re
from pathlib import Path

from checks.language import spell_checker_answers
from checks.project import Codebase, app, lines_of, place, run

# MARK: Settings

SOURCE_LANGUAGE = "en"
# A text the same in more than this share of the other languages is a shared term.
SHARED_SHARE = 0.5
SHARED_MINIMUM = 3  # and in at least this many, so two languages alone never make a term shared
WORD = re.compile(r"[^\W\d_]+")  # letters only: placeholders such as %@ and numbers do not count
# The spell checker's names for languages whose folders are named differently.
DICTIONARY_NAMES = {"pt-BR": "pt_BR"}


# MARK: Reading the translations


def translations(folder: Path) -> dict[str, dict[str, str]]:
    """Each language's texts by key, read with plutil, which understands the .strings format."""
    texts = {}
    for strings in sorted(folder.glob("*.lproj/Localizable.strings")):
        result = run(["plutil", "-convert", "json", "-o", "-", str(strings)])
        texts[strings.parent.stem] = json.loads(result.output)
    return texts


def key_line(strings: Path, key: str) -> int:
    marker = f'"{key}"'
    numbered = enumerate(lines_of(strings), start=1)
    return next((number for number, line in numbered if line.startswith(marker)), 1)


# MARK: Judging


def copied_texts(texts: dict[str, dict[str, str]]) -> dict[str, list[str]]:
    """For each language, the keys whose text reads like English and is no shared term."""
    english = texts[SOURCE_LANGUAGE]
    others = [language for language in texts if language != SOURCE_LANGUAGE]
    copies = {
        language: [key for key, text in texts[language].items() if text == english.get(key)]
        for language in others
    }
    shared_count = {key: sum(key in keys for keys in copies.values()) for key in english}
    is_shared = {
        key: count >= SHARED_MINIMUM and count > len(others) * SHARED_SHARE
        for key, count in shared_count.items()
    }
    return {
        language: [key for key in keys if not is_shared[key]] for language, keys in copies.items()
    }


def unknown_in(language: str, words: set[str]) -> set[str]:
    dictionary = DICTIONARY_NAMES.get(language, language)
    return {line.split("\t")[0] for line in spell_checker_answers(words, dictionary)}


# MARK: Step


def translation_findings() -> list[str]:
    return translation_problems(app())


def translation_problems(codebase: Codebase) -> list[str]:
    if codebase.translations is None:
        return []
    texts = translations(codebase.translations)
    findings = []
    for language, keys in copied_texts(texts).items():
        strings = codebase.translations / f"{language}.lproj" / "Localizable.strings"
        words = {key: set(WORD.findall(texts[language][key])) for key in keys}
        unknown = unknown_in(language, set().union(*words.values())) if words else set()
        findings += [
            f"{place(strings, key_line(strings, key))}: '{texts[language][key]}' ({key}) is still "
            f"English; translate it, unless {language} uses these very words"
            for key in keys if words[key] & unknown
        ]
    return findings
