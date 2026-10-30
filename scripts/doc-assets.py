#!/usr/bin/env python3
"""Draws the graphics of the guides in the shared style, so new ones match the old ones.

  scripts/doc-assets.py banner <file name> <title> <subtitle> [--eyebrow <small line above>]
      writes assets/banner-<file name>.svg: the app icon, a small line, the title and a subtitle.
  scripts/doc-assets.py icon <name> <colour> '<svg shapes in a 24-point grid>'
      writes assets/icons/<name>.svg: a rounded tile in one of the colours below with a white glyph.

Within one guide every section icon gets its own colour and its own shape (see CLAUDE.md).
"""

import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ASSETS = PROJECT / "assets"
FONT = (
    "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', "
    "Helvetica, Arial, sans-serif"
)
DEFAULT_EYEBROW = "Speicher-Explorer · Dokumentation"

# Top and bottom of each tile gradient, in the spirit of System Settings.
COLOURS = {
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

BANNER_WIDTH, BANNER_HEIGHT = 1280, 300
ICON_SIZE_ON_BANNER = 168
HERO_SIZE_ON_MAIN_BANNER = 240


def app_icon() -> str:
    """The app icon as drawn on the main banner, which stays the single source of its shape."""
    banner = (ASSETS / "banner.svg").read_text()
    return re.search(r'<g filter="url\(#sh\)">(.*?)</g>\n', banner).group(1)


def banner(file_name: str, title: str, subtitle: str, eyebrow: str = DEFAULT_EYEBROW) -> Path:
    scale = ICON_SIZE_ON_BANNER / HERO_SIZE_ON_MAIN_BANNER
    size = f'width="{BANNER_WIDTH}" height="{BANNER_HEIGHT}"'
    text = f'font-family="{FONT}" text-anchor="start"'
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" {size}
  viewBox="0 0 {BANNER_WIDTH} {BANNER_HEIGHT}" role="img"
  aria-label="Speicher-Explorer – {title}. {subtitle}">
<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#F7FAFF"/><stop offset="1" stop-color="#DCE7FF"/></linearGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="150%">
  <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#1F52DB" flood-opacity=".28"/>
</filter></defs>
<rect {size} rx="32" fill="url(#bg)"/>
<circle cx="1180" cy="30" r="200" fill="#5C9EFF" fill-opacity=".10"/>
<circle cx="80" cy="300" r="160" fill="#1F52DB" fill-opacity=".06"/>
<g filter="url(#sh)" transform="translate(96 66) scale({scale:.4f}) translate(-96 -100)">\
{app_icon()}</g>
<text x="320" y="112" {text} font-size="22" font-weight="600" fill="#1F52DB">{eyebrow}</text>
<text x="320" y="176" {text} font-size="60" font-weight="700" fill="#1D1D1F">{title}</text>
<text x="320" y="224" {text} font-size="28" font-weight="400" fill="#3A3A3C">{subtitle}</text>
</svg>
'''
    path = ASSETS / f"banner-{file_name}.svg"
    path.write_text(svg)
    return path


def icon(name: str, colour: str, glyph: str) -> Path:
    top, bottom = COLOURS[colour]
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="60" height="56" viewBox="0 0 60 56"
  aria-hidden="true">
<defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>
</linearGradient></defs>
<rect x="1.5" y="1.5" width="45" height="45" rx="11" fill="url(#t)"/>
<rect x="2" y="2" width="44" height="44" rx="10.5" fill="none" stroke="#fff" stroke-opacity=".25"/>
<g transform="translate(12 12)" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"
  stroke-linejoin="round">{glyph}</g>
</svg>
'''
    path = ASSETS / "icons" / f"{name}.svg"
    path.write_text(svg)
    return path


def main() -> int:
    arguments = sys.argv[1:]
    if arguments[:1] == ["banner"] and len(arguments) in (4, 6):
        has_eyebrow = len(arguments) == 6 and arguments[4] == "--eyebrow"
        eyebrow = arguments[5] if has_eyebrow else DEFAULT_EYEBROW
        print(banner(arguments[1], arguments[2], arguments[3], eyebrow))
        return 0
    if arguments[:1] == ["icon"] and len(arguments) == 4 and arguments[2] in COLOURS:
        print(icon(arguments[1], arguments[2], arguments[3]))
        return 0
    print(__doc__)
    print("Colours: " + ", ".join(COLOURS))
    return 2


if __name__ == "__main__":
    sys.exit(main())
