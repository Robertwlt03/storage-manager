#!/usr/bin/env python3
"""Draws the graphics of the guides in the shared style, so new ones match the old ones.

Start:  make banner (asks for everything), or
        scripts/doc-assets.py banner <file name> <title> <subtitle> [--eyebrow <small line>]
        scripts/doc-assets.py icon <name> <color> '<svg shapes in a 24-point grid>'
        (--overwrite replaces a file that exists)
Needs:  nothing beyond Python
A banner (assets/banner-<file name>.svg) shows the app icon, a small line, the title and a
subtitle; an icon (assets/icons/<name>.svg) is a rounded tile in one color with a white glyph.
Within one guide every section icon gets its own color and its own shape (see CLAUDE.md).
Asked without texts, the script first offers to replace a banner (picked from a list), then
asks for the file name of a new one, the title and the subtitle.
"""

import argparse
import re
import sys
from html import escape, unescape
from pathlib import Path

from checks.console import (
    FAILURE, SUCCESS, ask_choice, ask_text, ask_yes_no, can_ask, frame, heading, note,
)

# MARK: Settings

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "assets"
MAIN_BANNER = ASSETS / "banner.svg"  # holds the app icon; the single source of its shape
FONT = (
    "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', "
    "Helvetica, Arial, sans-serif"
)
DEFAULT_EYEBROW = "Speicher-Explorer · Documentation"
HAND_DRAWN_BANNERS = {"footer"}  # drawn by hand like assets/banner.svg; never replaced
BANNER_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")  # the <file name> in banner-<file name>.svg
TEXT_ELEMENT = re.compile(r"<text [^>]*>(.*?)</text>")  # a drawn banner's three lines of text

# Top and bottom of each tile gradient, in the spirit of System Settings.
COLORS = {
    "blue": ("#5AA9FF", "#0A6CF0"),
    "sky": ("#62CBFA", "#1A86D9"),
    "indigo": ("#8389FF", "#4B4FD8"),
    "purple": ("#C58BFF", "#8B3FE0"),
    "pink": ("#FF7AA2", "#E0336B"),
    "red": ("#FF6B61", "#D92C20"),
    "orange": ("#FFB340", "#F07800"),
    "brown": ("#E7A764", "#A8641F"),
    "green": ("#5BD27A", "#1E9B45"),
    "teal": ("#56DBBE", "#12957B"),
    "gray": ("#76767F", "#2C2C31"),
    "slate": ("#A2A2AB", "#6A6A74"),
}

# The banner, in pixels: the icon on the left, the three lines of text to its right.
BANNER_WIDTH, BANNER_HEIGHT = 1280, 300
ICON_SIZE = 168  # the icon is 240 on the main banner and is scaled down to this
ICON_SIZE_ON_MAIN_BANNER = 240
ICON_LEFT, ICON_TOP = 96, 66
ICON_ORIGIN_ON_MAIN_BANNER = "-96 -100"  # moves the copied icon back to the top left corner
TEXT_LEFT = 320
# Each line of text: where it stands (its baseline), its size, its weight and its color.
EYEBROW_LINE = (112, 22, 600, "#1F52DB")
TITLE_LINE = (176, 60, 700, "#1D1D1F")
SUBTITLE_LINE = (224, 28, 400, "#3A3A3C")

# The group in the main banner that draws the app icon, the part with the shadow filter "sh".
APP_ICON_GROUP = re.compile(r"""
    <g \s filter="url\(\#sh\)">     # the opening tag of the icon's group
    (.*?)                           # the icon's shapes
    </g> \n                         # the group's end, on a line of its own
""", re.VERBOSE)

# The banner's background and decoration, the same as on the main banner.
BANNER_BACKGROUND = """<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#F7FAFF"/><stop offset="1" stop-color="#DCE7FF"/></linearGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="150%">
  <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#1F52DB" flood-opacity=".28"/>
</filter></defs>
<rect {size} rx="32" fill="url(#bg)"/>
<circle cx="1180" cy="30" r="200" fill="#5C9EFF" fill-opacity=".10"/>
<circle cx="80" cy="300" r="160" fill="#1F52DB" fill-opacity=".06"/>"""

# A section icon: a 45-pixel tile with a faint white edge, the glyph drawn in white on top.
ICON_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" width="60" height="56"
  viewBox="0 0 60 56" aria-hidden="true">
<defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>
</linearGradient></defs>
<rect x="1.5" y="1.5" width="45" height="45" rx="11" fill="url(#t)"/>
<rect x="2" y="2" width="44" height="44" rx="10.5" fill="none" stroke="#fff"
  stroke-opacity=".25"/>
<g transform="translate(12 12)" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"
  stroke-linejoin="round">{glyph}</g>
</svg>
"""


# MARK: Drawing


def banner(file_name: str, title: str, subtitle: str, eyebrow: str, overwrite: bool) -> Path:
    if file_name in HAND_DRAWN_BANNERS:
        stop(f"banner-{file_name}.svg is drawn by hand", "Edit it in assets/ instead.")
    size = f'width="{BANNER_WIDTH}" height="{BANNER_HEIGHT}"'
    svg = "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" {size}',
        f'  viewBox="0 0 {BANNER_WIDTH} {BANNER_HEIGHT}" role="img"',
        f'  aria-label="{escape(f"Speicher-Explorer – {title}. {subtitle}")}">',
        BANNER_BACKGROUND.format(size=size),
        banner_icon(),
        text_line(EYEBROW_LINE, eyebrow),
        text_line(TITLE_LINE, title),
        text_line(SUBTITLE_LINE, subtitle),
        "</svg>",
        "",
    ])
    return write(banner_path(file_name), svg, overwrite)


def banner_icon() -> str:
    scale = ICON_SIZE / ICON_SIZE_ON_MAIN_BANNER
    shapes = APP_ICON_GROUP.search(MAIN_BANNER.read_text()).group(1)
    placement = f"translate({ICON_LEFT} {ICON_TOP}) scale({scale:.4f})"
    return (
        f'<g filter="url(#sh)" transform="{placement} translate({ICON_ORIGIN_ON_MAIN_BANNER})">'
        f"{shapes}</g>"
    )


def text_line(style: tuple, text: str) -> str:
    baseline, font_size, font_weight, color = style
    return (
        f'<text x="{TEXT_LEFT}" y="{baseline}" font-family="{FONT}" text-anchor="start" '
        f'font-size="{font_size}" font-weight="{font_weight}" fill="{color}">{escape(text)}</text>'
    )


def icon(name: str, color: str, glyph: str, overwrite: bool) -> Path:
    top, bottom = COLORS[color]
    return write(ASSETS / "icons" / f"{name}.svg", ICON_TEMPLATE.format(
        top=top, bottom=bottom, glyph=glyph), overwrite)


def write(path: Path, svg: str, overwrite: bool) -> Path:
    if path.exists() and not overwrite:
        stop(f"{relative(path)} already exists",
             "Add --overwrite to replace it, or pick it from the list of make banner.")
    path.write_text(svg)
    return path


def banner_path(file_name: str) -> Path:
    return ASSETS / f"banner-{file_name}.svg"


def relative(path: Path) -> str:
    return str(path.relative_to(PROJECT))


def stop(problem: str, hint: str) -> None:
    frame("Nothing drawn", [problem, hint], FAILURE)
    sys.exit(1)


# MARK: Questions


def banner_by_questions() -> Path:
    """First whether to replace a banner and which one, then the texts of the banner."""
    heading("Speicher-Explorer · banner", "Ctrl-C cancels")
    if not can_ask():
        stop("no terminal to ask in",
             "Name the texts instead: scripts/doc-assets.py banner <file name> <title> <subtitle>")
    replaceable = sorted(
        path.stem.removeprefix("banner-") for path in ASSETS.glob("banner-*.svg")
        if path.stem.removeprefix("banner-") not in HAND_DRAWN_BANNERS
    )
    if replaceable and ask_yes_no("Replace an existing banner?"):
        file_name = replaceable[ask_choice("Which banner?", banner_list(replaceable))]
        eyebrow, title, subtitle = banner_texts(file_name)
    else:
        file_name = new_banner_name()
        eyebrow, title, subtitle = DEFAULT_EYEBROW, "", ""
    title = ask_text("Title", "large line", title)
    subtitle = ask_text("Subtitle", "one sentence below", subtitle)
    return banner(file_name, title, subtitle, eyebrow, overwrite=True)


def banner_list(file_names: list[str]) -> list[str]:
    """Each banner as its title and, after it, its file."""
    titles = [banner_texts(name)[1] for name in file_names]
    width = max(len(title) for title in titles)
    return [
        f"{title.ljust(width)}  {banner_path(name).name}"
        for title, name in zip(titles, file_names, strict=True)
    ]


def banner_texts(file_name: str) -> list[str]:
    """The small line, the title and the subtitle of a banner the script drew."""
    return [unescape(text) for text in TEXT_ELEMENT.findall(banner_path(file_name).read_text())]


def new_banner_name() -> str:
    while True:
        file_name = ask_text("File name", "assets/banner-<name>.svg, such as release-notes")
        if not BANNER_NAME.fullmatch(file_name):
            note("Small letters, digits and hyphens only, such as release-notes.")
        elif banner_path(file_name).exists():
            note("That banner exists; answer yes to the first question to replace it.")
        else:
            return file_name


# MARK: Run


def command_line() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Draws banners and section icons for the guides.")
    commands = parser.add_subparsers(dest="command", required=True)
    banner_command = commands.add_parser("banner", help="a banner for the top of a guide")
    banner_command.add_argument(
        "file_name", nargs="?", help="written to assets/banner-<file name>.svg; left out, it asks")
    banner_command.add_argument("title", nargs="?")
    banner_command.add_argument("subtitle", nargs="?")
    banner_command.add_argument("--eyebrow", default=DEFAULT_EYEBROW, help="the small line above")
    icon_command = commands.add_parser("icon", help="an icon in front of a section heading")
    icon_command.add_argument("name", help="written to assets/icons/<name>.svg")
    icon_command.add_argument("color", choices=COLORS)
    icon_command.add_argument("glyph", help="white SVG shapes in a 24-point grid")
    for command in (banner_command, icon_command):
        command.add_argument("--overwrite", action="store_true", help="replace a file that exists")
    return parser


def drawn_file() -> Path:
    parser = command_line()
    chosen = parser.parse_args()
    if chosen.command == "icon":
        heading("Speicher-Explorer · icon", f"assets/icons/{chosen.name}.svg")
        return icon(chosen.name, chosen.color, chosen.glyph, chosen.overwrite)
    texts = [chosen.file_name, chosen.title, chosen.subtitle]
    if not any(texts):
        return banner_by_questions()
    if not all(texts):
        parser.error("name the file, the title and the subtitle, or none of them to be asked")
    if not BANNER_NAME.fullmatch(chosen.file_name):
        parser.error("the file name takes small letters, digits and hyphens only")
    heading("Speicher-Explorer · banner", relative(banner_path(chosen.file_name)))
    return banner(chosen.file_name, chosen.title, chosen.subtitle, chosen.eyebrow,
                  chosen.overwrite)


def main() -> None:
    try:
        drawn = drawn_file()
    except (KeyboardInterrupt, EOFError):  # Ctrl-C or Ctrl-D while it asks; not a failure
        note("Cancelled, nothing written.")
        return
    details = [relative(drawn)]
    guides = PROJECT.glob("*.md")
    if drawn.parent == ASSETS and not any(drawn.name in guide.read_text() for guide in guides):
        details.append("No guide shows it yet; put it at the top of one.")
    frame("Drawn", details, SUCCESS)


if __name__ == "__main__":
    main()
