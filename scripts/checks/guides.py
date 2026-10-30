"""Checks the guides: every German guide and its English twin have the same layout, every link
leads to a file that exists, and the English texts use American spelling.

Start:  imported by scripts/check.py, not started on its own
Needs:  macOS (its spell checker tells British from American spelling, see unknown_words.swift)
The layout of a guide is the order of its parts: the headings with their section icons, the
images, the code blocks and the rows of its tables. A twin that lacks a part or shows another
icon is reported at the first place where the two differ.
"""

import re
from dataclasses import dataclass
from pathlib import Path

from checks.language import BRITISH_VARIANTS, NOT_PROSE, PLAIN_WORD, unknown_words
from checks.project import PROJECT, Codebase, app, lines_of, numbered_lines, place

# MARK: Settings

ENGLISH_SUFFIX = ".en.md"
# A link inside the project: Markdown's (target) or HTML's src= and href=.
LINK = re.compile(r"""
    \] \( (?P<markdown> [^)\s]+ ) \)            # [text](target)
    | (?: src | href ) = " (?P<html> [^"]+ ) "  # <img src="target"> or <a href="target">
""", re.VERBOSE)
# Targets that are no file of the project: web addresses, mail, a place on the same page, and
# GitHub's own pages such as ../../issues, which lie outside the repository.
OUTSIDE = re.compile(r"^(?:[a-z]+:|#|\.\./\.\./)")
HEADING = re.compile(r"^(?P<level>#{1,6})\s")
HTML_TAG = re.compile(r"<[^>]+>")
CODE_SPAN = re.compile(r"`[^`]*`")
IMAGE = re.compile(r'<img [^>]*src="(?P<source>[^"]+)"')
CODE_FENCE = re.compile(r"^\s*```")
TABLE_ROW = re.compile(r"^\s*\|")
# Words that tell English from German in a guide without a twin.
ENGLISH_WORDS = re.compile(r"\b(?:the|and|is|of|to)\b")
GERMAN_WORDS = re.compile(r"\b(?:der|die|das|und|ist|nicht)\b")


# MARK: Layout


@dataclass(frozen=True)
class Part:
    """One piece of a guide's layout, the same in both languages."""

    kind: str
    detail: str
    line: int


def layout(path: Path) -> list[Part]:
    parts = []
    for number, line in enumerate(lines_of(path), start=1):
        heading = HEADING.match(line)
        if heading:
            parts.append(Part("heading", f"{heading['level']} {first_image(line)}", number))
        elif IMAGE.search(line):
            # Banners and badges carry their language, so only the place of an image counts.
            parts.append(Part("image", "", number))
        elif CODE_FENCE.match(line):
            parts.append(Part("code block", "", number))
        elif TABLE_ROW.match(line):
            parts.append(Part("table row", "", number))
    return parts


def first_image(line: str) -> str:
    """A section icon's file, which both languages share."""
    image = IMAGE.search(line)
    return image["source"] if image else ""


def layout_problem(german: Path, english: Path) -> str | None:
    german_parts, english_parts = layout(german), layout(english)
    for german_part, english_part in zip(german_parts, english_parts):
        if (german_part.kind, german_part.detail) != (english_part.kind, english_part.detail):
            return (
                f"{place(english, english_part.line)}: the twin shows a {english_part.kind} "
                f"{english_part.detail} where {place(german, german_part.line)} has a "
                f"{german_part.kind} {german_part.detail}"
            )
    if len(german_parts) != len(english_parts):
        return (
            f"{place(english, 1)}: the twin has {len(english_parts)} parts, "
            f"{german.name} has {len(german_parts)}"
        )
    return None


# MARK: Twins and languages


def twin_problems(guides: tuple[Path, ...]) -> list[str]:
    problems = []
    for english in (guide for guide in guides if guide.name.endswith(ENGLISH_SUFFIX)):
        german = english.with_name(english.name.removesuffix(ENGLISH_SUFFIX) + ".md")
        if german not in guides:
            problems.append(f"{place(english, 1)}: an English twin without its German guide")
            continue
        problems += filter(None, [layout_problem(german, english)])
    return problems


def is_english(guide: Path, guides: tuple[Path, ...]) -> bool:
    """An English twin, or a guide without a twin whose text reads English."""
    if guide.name.endswith(ENGLISH_SUFFIX):
        return True
    if guide.with_name(guide.stem + ENGLISH_SUFFIX) in guides:
        return False
    text = guide.read_text().lower()
    return len(ENGLISH_WORDS.findall(text)) > len(GERMAN_WORDS.findall(text))


# MARK: Links and spelling


def link_problems(guides: tuple[Path, ...]) -> list[str]:
    problems = []
    for path, number, line in numbered_lines(guides):
        links = LINK.finditer(CODE_SPAN.sub("", line))  # a link in `code` is an example
        targets = [match["markdown"] or match["html"] for match in links]
        problems += [
            f"{place(path, number)}: the link to {target} leads nowhere"
            for target in targets if is_broken(path, target)
        ]
    return problems


def is_broken(guide: Path, target: str) -> bool:
    if OUTSIDE.match(target):
        return False
    file = (guide.parent / target.split("#", 1)[0]).resolve()
    return not file.exists() or not file.is_relative_to(PROJECT)


def spelling_problems(guides: tuple[Path, ...]) -> list[str]:
    english = [guide for guide in guides if is_english(guide, guides)]
    words = [
        (path, number, word)
        for path, number, line in numbered_lines(english)
        for word in PLAIN_WORD.findall(NOT_PROSE.sub(" ", HTML_TAG.sub(" ", line)))
    ]
    verdicts = unknown_words({word.lower() for _, _, word in words}, set())
    return [
        f"{place(path, number)}: '{word}' is British; American English writes '{american}'"
        for path, number, word in words
        if (american := american_spelling(word.lower(), verdicts))
    ]


def american_spelling(word: str, verdicts: dict) -> str | None:
    if word in BRITISH_VARIANTS:
        return BRITISH_VARIANTS[word]
    kind, guess = verdicts.get(word, ("", ""))
    return guess if kind == "british" else None


# MARK: Step


def guide_findings() -> list[str]:
    return guide_problems(app())


def guide_problems(codebase: Codebase) -> list[str]:
    guides = codebase.guides
    return twin_problems(guides) + link_problems(guides) + spelling_problems(guides)
