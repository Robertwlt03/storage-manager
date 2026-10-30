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
from collections.abc import Callable
from dataclasses import dataclass
from html import escape, unescape
from pathlib import Path

from checks.console import (
    FAILURE, SUCCESS, ask_choice, ask_text, ask_yes_no, can_ask, frame, heading, note,
)
from checks.project import PROJECT, relative_path

# MARK: Settings

ASSETS = PROJECT / "assets"
MAIN_BANNER = ASSETS / "banner.svg"  # holds the app icon; the single source of its shape
FONT = (
    "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', "
    "Helvetica, Arial, sans-serif"
)
DEFAULT_EYEBROW = "Speicher-Explorer · Documentation"
# Never replaced through make banner: the app's footer is drawn by hand like banner.svg, and the
# Claude footer is drawn again with every banner in the Claude theme.
HAND_DRAWN_BANNERS = {"footer", "claude-footer"}
CLAUDE_FOOTER = "claude-footer"
FOOTER_WIDTH, FOOTER_HEIGHT = 480, 120  # the size of the app's footer
FOOTER_TILE_LEFT, FOOTER_TILE_TOP, FOOTER_TILE_SIZE = 36, 24, 72
FOOTER_TEXT_LEFT = 130
# The footer's two lines, as on the app's: baseline, size, weight and color.
FOOTER_NAME_LINE = (58, 28, 700, "#141413")
FOOTER_CAPTION_LINE = (86, 16, 400, "#5E5D59")
BANNER_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")  # the <file name> in banner-<file name>.svg
TEXT_ELEMENT = re.compile(r"<text [^>]*>(.*?)</text>")  # a drawn banner's three lines of text
THEME_MARK = re.compile(r'data-theme="(?P<theme>[a-z]+)"')  # the design a banner was drawn in
FILE_NAME_LIMIT = 40
# How many characters of usual text fit between the text's start and the banner's right margin,
# measured in the system font at each line's size and weight.
# ponytail: counts characters, not their width; a line of only wide letters (W, M) may still run
# out, which a look at the drawn banner shows. Measure with the font itself if that happens often.
EYEBROW_LIMIT, TITLE_LIMIT, SUBTITLE_LIMIT = 60, 24, 50

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
    # Claude's colors (claude.com and its app icon), vivid like Claude's own: for CLAUDE.md.
    "clay": ("#D97757", "#D8653F"),
    "dusk": ("#6FA2DA", "#4A86CC"),
    "mineral": ("#5FA88F", "#3F8A70"),
    "plum": ("#8A84D1", "#6660BE"),
    "ink": ("#4D4C48", "#141413"),
    "kraft": ("#DDA174", "#C9844F"),
    "cactus": ("#E5B84F", "#C9952B"),
    "heather": ("#DD84A6", "#C45A84"),
    "peach": ("#EF9A72", "#E07A4C"),
    "olive": ("#86A05E", "#66843C"),
    "stone": ("#8F8D86", "#5E5D59"),
}

# The banner, in pixels: the icon on the left, the three lines of text to its right.
BANNER_WIDTH, BANNER_HEIGHT = 1280, 300
ICON_SIZE_ON_BANNER = 168
ICON_SIZE_ON_MAIN_BANNER = 240
ICON_LEFT, ICON_TOP = 96, 66
ICON_ORIGIN_ON_MAIN_BANNER = "-96 -100"  # moves the copied icon back to the top left corner
TEXT_LEFT = 320
# Each line of text: where it stands (its baseline), its size and its weight; the theme colors it.
EYEBROW_LINE = (112, 22, 600)
TITLE_LINE = (176, 60, 700)
SUBTITLE_LINE = (224, 28, 400)
# Claude's mark for the Claude theme, the path of the logo on claude.com in a square of
# CLAUDE_MARK_UNITS; it stands light on a clay tile, as in Claude's app icon. The mark belongs to
# Anthropic and names the tool only; the project's MIT license does not cover it.
CLAUDE_MARK = (
    "M54.375 118.75L56.125 111L58.125 101L59.75 93L61.25 83.125L62.125 79.875L62 "
    "79.625L61.375 79.75L53.875 90L42.5 105.375L33.5 114.875L31.375 115.75L27.625 113.875L28 "
    "110.375L30.125 107.375L42.5 91.5L50 81.625L54.875 76L54.75 75.25H54.5L21.5 96.75L15.625 "
    "97.5L13 95.125L13.375 91.25L14.625 90L24.5 83.125L49.125 69.375L49.5 68.125L49.125 "
    "67.5H47.875L43.75 67.25L29.75 66.875L17.625 66.375L5.75 65.75L2.75 65.125L0 61.375L0.25 "
    "59.5L2.75 57.875L6.375 58.125L14.25 58.75L26.125 59.5L34.75 60L47.5 61.375H49.5L49.75 "
    "60.5L49.125 60L48.625 59.5L36.25 51.25L23 42.5L16 37.375L12.25 34.75L10.375 32.375L9.625 "
    "27.125L13 23.375L17.625 23.75L18.75 24L23.375 27.625L33.25 35.25L46.25 44.875L48.125 "
    "46.375L49 45.875V45.5L48.125 44.125L41.125 31.375L33.625 18.375L30.25 13L29.375 "
    "9.75C29.0417 8.625 28.875 7.375 28.875 6L32.75 0.750006L34.875 0L40.125 0.750006L42.25 "
    "2.625L45.5 10L50.625 21.625L58.75 37.375L61.125 42.125L62.375 46.375L62.875 "
    "47.75H63.75V47L64.375 38L65.625 27.125L66.875 13.125L67.25 9.125L69.25 4.375L73.125 "
    "1.87501L76.125 3.25L78.625 6.875L78.25 9.125L76.875 18.75L73.875 33.875L72 "
    "44.125H73.125L74.375 42.75L79.5 36L88.125 25.25L91.875 21L96.375 16.25L99.25 "
    "14H104.625L108.5 19.875L106.75 26L101.25 33L96.625 38.875L90 47.75L86 54.875L86.375 "
    "55.375H87.25L102.125 52.125L110.25 50.75L119.75 49.125L124.125 51.125L124.625 "
    "53.125L122.875 57.375L112.625 59.875L100.625 62.25L82.75 66.5L82.5 66.625L82.75 67L90.75 "
    "67.75L94.25 68H102.75L118.5 69.125L122.625 71.875L125 75.125L124.625 77.75L118.25 "
    "80.875L109.75 78.875L89.75 74.125L83 72.5H82V73L87.75 78.625L98.125 88L111.25 "
    "100.125L111.875 103.125L110.25 105.625L108.5 105.375L97 96.625L92.5 92.75L82.5 "
    "84.375H81.875V85.25L84.125 88.625L96.375 107L97 112.625L96.125 114.375L92.875 115.5L89.5 "
    "114.875L82.25 104.875L74.875 93.5L68.875 83.375L68.25 83.875L64.625 121.625L63 "
    "123.5L59.25 125L56.125 122.625L54.375 118.75Z"
)
CLAUDE_MARK_UNITS = 125
CLAUDE_MARK_SHARE = 0.64  # how much of the tile the mark fills
TILE_CORNER = 0.225  # the corner radius of the app icon's tile, as a share of its size

# The group in the main banner that draws the app icon, the part with the shadow filter "sh".
APP_ICON_GROUP = re.compile(r"""
    <g \s filter="url\(\#sh\)">     # the opening tag of the icon's group
    (.*?)                           # the icon's shapes
    </g> \n                         # the group's end, on a line of its own
""", re.VERBOSE)

# The banner's background and decoration, in the shape of the main banner.
BANNER_BACKGROUND = """<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{deep}"/></linearGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="150%">
  <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="{shadow}" flood-opacity=".28"/>
</filter></defs>
<rect {size} rx="32" fill="url(#bg)"/>
<circle cx="1180" cy="30" r="200" fill="{large_circle}" fill-opacity=".10"/>
<circle cx="80" cy="300" r="160" fill="{shadow}" fill-opacity=".06"/>"""

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


@dataclass(frozen=True)
class Theme:
    """How a banner looks; the shape stays the same in every theme."""
    light: str  # the background, from the top left
    deep: str  # to the bottom right
    large_circle: str  # the decoration top right
    shadow: str  # the shadow under the mark, and the decoration bottom left
    text_colors: tuple[str, str, str]  # the small line, the title, the subtitle
    mark: Callable[[], str]  # what stands on the left


def banner(file_name: str, title: str, subtitle: str, eyebrow: str, overwrite: bool,
           theme_name: str = "app") -> Path:
    if file_name in HAND_DRAWN_BANNERS:
        stop(f"banner-{file_name}.svg is drawn by hand", "Edit it in assets/ instead.")
    theme = THEMES[theme_name]
    size = f'width="{BANNER_WIDTH}" height="{BANNER_HEIGHT}"'
    theme_mark = "" if theme_name == "app" else f' data-theme="{theme_name}"'
    eyebrow_color, title_color, subtitle_color = theme.text_colors
    svg = "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" {size}',
        f'  viewBox="0 0 {BANNER_WIDTH} {BANNER_HEIGHT}" role="img"{theme_mark}',
        f'  aria-label="{escape(f"Speicher-Explorer – {title}. {subtitle}")}">',
        BANNER_BACKGROUND.format(size=size, light=theme.light, deep=theme.deep,
                                 large_circle=theme.large_circle, shadow=theme.shadow),
        theme.mark(),
        text_line(EYEBROW_LINE, eyebrow, eyebrow_color),
        text_line(TITLE_LINE, title, title_color),
        text_line(SUBTITLE_LINE, subtitle, subtitle_color),
        "</svg>",
        "",
    ])
    if theme_name == "claude":
        write(banner_path(CLAUDE_FOOTER), claude_footer(), overwrite=True)
    return write(banner_path(file_name), svg, overwrite)


def claude_footer() -> str:
    """The footer of CLAUDE.md, with the same mark as its banner."""
    size = f'width="{FOOTER_WIDTH}" height="{FOOTER_HEIGHT}"'
    return "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" {size} viewBox="0 0 {FOOTER_WIDTH} '
        f'{FOOTER_HEIGHT}" role="img" aria-label="Speicher-Explorer, built with Claude Code">',
        '<defs><linearGradient id="fbg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" '
        'stop-color="#FAF9F5"/><stop offset="1" stop-color="#F0EEE6"/></linearGradient></defs>',
        f'<rect {size} rx="24" fill="url(#fbg)"/>',
        claude_tile(FOOTER_TILE_LEFT, FOOTER_TILE_TOP, FOOTER_TILE_SIZE),
        footer_text(FOOTER_NAME_LINE, "Speicher-Explorer"),
        footer_text(FOOTER_CAPTION_LINE, "Built with Claude Code"),
        "</svg>",
        "",
    ])


def footer_text(style: tuple, text: str) -> str:
    baseline, font_size, font_weight, color = style
    return (
        f'<text x="{FOOTER_TEXT_LEFT}" y="{baseline}" font-family="{FONT}" font-size="{font_size}" '
        f'font-weight="{font_weight}" fill="{color}" text-anchor="start">{escape(text)}</text>'
    )


def banner_icon() -> str:
    scale = ICON_SIZE_ON_BANNER / ICON_SIZE_ON_MAIN_BANNER
    shapes = APP_ICON_GROUP.search(MAIN_BANNER.read_text()).group(1)
    placement = f"translate({ICON_LEFT} {ICON_TOP}) scale({scale:.4f})"
    return (
        f'<g filter="url(#sh)" transform="{placement} translate({ICON_ORIGIN_ON_MAIN_BANNER})">'
        f"{shapes}</g>"
    )


def claude_tile(left: float, top: float, size: float) -> str:
    """A clay tile with Claude's mark in ivory, drawn at any size (banner, footer)."""
    mark_size = size * CLAUDE_MARK_SHARE
    offset = (size - mark_size) / 2
    scale = mark_size / CLAUDE_MARK_UNITS
    top_color, bottom_color = COLORS["clay"]
    return (
        f'<defs><linearGradient id="clay" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top_color}"/><stop offset="1" stop-color="{bottom_color}"/>'
        f'</linearGradient></defs>'
        f'<rect x="{left}" y="{top}" width="{size}" height="{size}" rx="{size * TILE_CORNER:.1f}" '
        f'fill="url(#clay)"/>'
        f'<path transform="translate({left + offset:.1f} {top + offset:.1f}) scale({scale:.4f})" '
        f'fill="#FAF9F5" d="{CLAUDE_MARK}"/>'
    )


def claude_mark() -> str:
    return f'<g filter="url(#sh)">{claude_tile(ICON_LEFT, ICON_TOP, ICON_SIZE_ON_BANNER)}</g>'


THEMES = {
    "app": Theme("#F7FAFF", "#DCE7FF", "#5C9EFF", "#1F52DB",
                 ("#1F52DB", "#1D1D1F", "#3A3A3C"), banner_icon),
    # Claude's ivory, clay and slate (claude.com); the small line in a deeper clay for 4.5:1
    "claude": Theme("#FAF9F5", "#F0EEE6", "#D97757", "#C46849",
                    ("#A85536", "#141413", "#3D3D3A"), claude_mark),
}


def text_line(style: tuple, text: str, color: str) -> str:
    baseline, font_size, font_weight = style
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
        stop(f"{relative_path(path)} already exists",
             "Add --overwrite to replace it, or pick it from the list of make banner.")
    path.write_text(svg)
    return path


def banner_path(file_name: str) -> Path:
    return ASSETS / f"banner-{file_name}.svg"


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
        theme_name = banner_theme(file_name)
    else:
        file_name = new_banner_name()
        eyebrow, title, subtitle = DEFAULT_EYEBROW, "", ""
        theme_name = "app"
    title = ask_text("Title", f"large line, up to {TITLE_LIMIT} characters", title,
                     too_long(TITLE_LIMIT))
    subtitle = ask_text("Subtitle", f"one sentence below, up to {SUBTITLE_LIMIT} characters",
                        subtitle, too_long(SUBTITLE_LIMIT))
    return banner(file_name, title, subtitle, eyebrow, overwrite=True, theme_name=theme_name)


def banner_theme(file_name: str) -> str:
    """The theme a banner was drawn in, so replacing it keeps its look."""
    mark = THEME_MARK.search(banner_path(file_name).read_text())
    return mark["theme"] if mark else "app"


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
    return ask_text("File name", "assets/banner-<name>.svg, such as release-notes", "",
                    lambda file_name: name_problem(file_name) or exists_problem(file_name))


# MARK: Checking the texts
# Each returns what is wrong with a text, or nothing when it fits.


def too_long(limit: int) -> Callable[[str], str]:
    def problem(text: str) -> str:
        if len(text) > limit:
            return f"{len(text)} characters; at most {limit} fit on the banner."
        return ""
    return problem


def name_problem(file_name: str) -> str:
    if not BANNER_NAME.fullmatch(file_name):
        return "Small letters, digits and hyphens only, such as release-notes."
    if len(file_name) > FILE_NAME_LIMIT:
        return f"{len(file_name)} characters; at most {FILE_NAME_LIMIT} for a file name."
    return ""


def exists_problem(file_name: str) -> str:
    if file_name in HAND_DRAWN_BANNERS:
        return "That name belongs to a banner drawn by hand; choose another."
    if banner_path(file_name).exists():
        return "That banner exists; answer y to the first question to replace it."
    return ""


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
    banner_command.add_argument(
        "--theme", choices=THEMES,
        help="app: the app's blue; claude: Claude's ivory and clay (default: the banner's own)")
    icon_command = commands.add_parser("icon", help="an icon in front of a section heading")
    icon_command.add_argument("name", help="written to assets/icons/<name>.svg")
    icon_command.add_argument("color", choices=COLORS)
    icon_command.add_argument("glyph", help="white SVG shapes in a 24-point grid")
    for command in (banner_command, icon_command):
        command.add_argument("--overwrite", action="store_true", help="replace a file that exists")
    return parser


def drawn_file() -> Path:
    parser = command_line()
    arguments = parser.parse_args()
    if arguments.command == "icon":
        heading("Speicher-Explorer · icon", f"assets/icons/{arguments.name}.svg")
        return icon(arguments.name, arguments.color, arguments.glyph, arguments.overwrite)
    texts = [arguments.file_name, arguments.title, arguments.subtitle]
    if not any(texts):
        return banner_by_questions()
    if not all(texts):
        parser.error("name the file, the title and the subtitle, or none of them to be asked")
    problems = [
        name_problem(arguments.file_name),
        too_long(EYEBROW_LIMIT)(arguments.eyebrow),
        too_long(TITLE_LIMIT)(arguments.title),
        too_long(SUBTITLE_LIMIT)(arguments.subtitle),
    ]
    if problem := next((problem for problem in problems if problem), ""):
        parser.error(problem)
    heading("Speicher-Explorer · banner", relative_path(banner_path(arguments.file_name)))
    # Without --theme, a banner drawn again keeps the theme it has, and a new one gets the app's.
    exists = banner_path(arguments.file_name).exists()
    theme_name = arguments.theme or (banner_theme(arguments.file_name) if exists else "app")
    return banner(arguments.file_name, arguments.title, arguments.subtitle, arguments.eyebrow,
                  arguments.overwrite, theme_name)


def main() -> None:
    try:
        drawn = drawn_file()
    except (KeyboardInterrupt, EOFError):  # Ctrl-C or Ctrl-D while it asks; not a failure
        note("Cancelled, nothing written.")
        return
    details = [relative_path(drawn)]
    guides = PROJECT.glob("*.md")
    if drawn.parent == ASSETS and not any(drawn.name in guide.read_text() for guide in guides):
        details.append("No guide shows it yet; put it at the top of one.")
    frame("Drawn", details, SUCCESS)


if __name__ == "__main__":
    main()
