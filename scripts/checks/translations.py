"""Finds texts that were copied from English instead of translated.

Start:  imported by scripts/check.py, not started on its own
Needs:  macOS (plutil reads the translation files, the spell checker knows 40 languages)
A text that reads exactly like the English one is fine when the language uses the same words,
such as "Downloads" in German, or when it is shared by most languages, such as "iCloud Drive" or
"1–10 MB". Otherwise one of its words is unknown to that language's dictionary, and the text is
reported. For a language macOS has no dictionary for, every word counts as unknown, so a text
copied into Japanese or Chinese never slips through. Which dictionaries a Mac has differs, though
(GitHub's Mac lacks the Danish one), so a text that is the same as English on purpose says so on
its line, with the comment SAME_ON_PURPOSE.
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
DICTIONARY_NAMES = {"pt-BR": "pt_BR", "pt-PT": "pt_PT"}
SAME_ON_PURPOSE = "/* same as English on purpose */"
TABLES = ("Localizable", "Widget")  # the app's texts and the widget's
# The languages by their folder names, so a finding says "Danish" and not only "da".
LANGUAGE_NAMES = {
    "cs": "Czech", "da": "Danish", "de": "German", "es": "Spanish", "fi": "Finnish",
    "fr": "French", "it": "Italian", "ja": "Japanese", "ko": "Korean", "nb": "Norwegian",
    "nl": "Dutch", "pl": "Polish", "pt-BR": "Brazilian Portuguese", "ru": "Russian",
    "sv": "Swedish", "tr": "Turkish", "uk": "Ukrainian", "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese", "pt-PT": "European Portuguese", "hu": "Hungarian",
    "ro": "Romanian", "el": "Greek", "id": "Indonesian", "vi": "Vietnamese", "th": "Thai",
    "hi": "Hindi",
}


# MARK: Reading the translations


def translations(folder: Path, table: str) -> dict[str, dict[str, str]]:
    """Each language's texts by key, read with plutil, which understands the .strings format."""
    texts = {}
    for strings in sorted(folder.glob(f"*.lproj/{table}.strings")):
        result = run(["plutil", "-convert", "json", "-o", "-", str(strings)])
        texts[strings.parent.stem] = json.loads(result.output)
    return texts


def key_line(strings: Path, key: str) -> int:
    marker = f'"{key}"'
    numbered = enumerate(lines_of(strings), start=1)
    return next((number for number, line in numbered if line.startswith(marker)), 1)


def is_same_on_purpose(strings: Path, key: str) -> bool:
    marker = f'"{key}"'
    return any(line.startswith(marker) and SAME_ON_PURPOSE in line for line in lines_of(strings))


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
    return [finding for table in TABLES for finding in table_problems(codebase.translations, table)]


def table_problems(folder: Path, table: str) -> list[str]:
    texts = translations(folder, table)
    if SOURCE_LANGUAGE not in texts:  # a project without this table, such as the samples
        return []
    findings = []
    for language, keys in copied_texts(texts).items():
        strings = folder / f"{language}.lproj" / f"{table}.strings"
        words = {key: set(WORD.findall(texts[language][key])) for key in keys}
        unknown = unknown_in(language, set().union(*words.values())) if words else set()
        findings += [
            f"{place(strings, key_line(strings, key))}: '{texts[language][key]}' ({key}) is still "
            f"English in {LANGUAGE_NAMES.get(language, language)} ({language}); translate it, or "
            f"mark the line {SAME_ON_PURPOSE} if {language} uses these very words"
            for key in keys if words[key] & unknown and not is_same_on_purpose(strings, key)
        ]
    return findings
