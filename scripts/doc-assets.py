#!/usr/bin/env python3
"""Draws the graphics of the guides in the shared style, so new ones match the old ones.

Start:  scripts/doc-assets.py banner <file name> <title> <subtitle> [--eyebrow <small line>]
        scripts/doc-assets.py icon <name> <color> '<svg shapes in a 24-point grid>'
Needs:  nothing beyond Python
A banner (assets/banner-<file name>.svg) shows the app icon, a small line, the title and a
subtitle; an icon (assets/icons/<name>.svg) is a rounded tile in one color with a white glyph.
Within one guide every section icon gets its own color and its own shape (see CLAUDE.md).
"""

import argparse
import re
from pathlib import Path

# MARK: Settings

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "assets"
MAIN_BANNER = ASSETS / "banner.svg"  # holds the app icon; the single source of its shape
FONT = (
    "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', "
    "Helvetica, Arial, sans-serif"
)
DEFAULT_EYEBROW = "Speicher-Explorer · Dokumentation"

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


def banner(file_name: str, title: str, subtitle: str, eyebrow: str) -> Path:
    size = f'width="{BANNER_WIDTH}" height="{BANNER_HEIGHT}"'
    svg = "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" {size}',
        f'  viewBox="0 0 {BANNER_WIDTH} {BANNER_HEIGHT}" role="img"',
        f'  aria-label="Speicher-Explorer – {title}. {subtitle}">',
        BANNER_BACKGROUND.format(size=size),
        banner_icon(),
        text_line(EYEBROW_LINE, eyebrow),
        text_line(TITLE_LINE, title),
        text_line(SUBTITLE_LINE, subtitle),
        "</svg>",
        "",
    ])
    return write(ASSETS / f"banner-{file_name}.svg", svg)


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
        f'font-size="{font_size}" font-weight="{font_weight}" fill="{color}">{text}</text>'
    )


def icon(name: str, color: str, glyph: str) -> Path:
    top, bottom = COLORS[color]
    return write(ASSETS / "icons" / f"{name}.svg", ICON_TEMPLATE.format(
        top=top, bottom=bottom, glyph=glyph))


def write(path: Path, svg: str) -> Path:
    path.write_text(svg)
    return path


# MARK: Run


def command_line() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Draws banners and section icons for the guides.")
    commands = parser.add_subparsers(dest="command", required=True)
    banner_command = commands.add_parser("banner", help="a banner for the top of a guide")
    banner_command.add_argument("file_name", help="written to assets/banner-<file name>.svg")
    banner_command.add_argument("title")
    banner_command.add_argument("subtitle")
    banner_command.add_argument("--eyebrow", default=DEFAULT_EYEBROW, help="the small line above")
    icon_command = commands.add_parser("icon", help="an icon in front of a section heading")
    icon_command.add_argument("name", help="written to assets/icons/<name>.svg")
    icon_command.add_argument("color", choices=COLORS)
    icon_command.add_argument("glyph", help="white SVG shapes in a 24-point grid")
    return parser


def main() -> None:
    chosen = command_line().parse_args()
    if chosen.command == "banner":
        print(banner(chosen.file_name, chosen.title, chosen.subtitle, chosen.eyebrow))
    else:
        print(icon(chosen.name, chosen.color, chosen.glyph))


if __name__ == "__main__":
    main()
