#!/usr/bin/env python3
"""Draws the pictures of the guides from small descriptions, each in a light and a dark version.

Start:  make pictures, or scripts/pictures.py [<name> …] [--shots <folder>]
Needs:  macOS (sips makes screenshots small); for the README's tour the demo pages photographed
        light and dark, as make snapshots leaves them in snapshots/current
Every file docs/pictures/<name>.json describes one picture, and the script draws it as
assets/pictures/<name>-light.svg and -dark.svg; a guide shows them through <picture>, so GitHub
picks the one that fits. The "kind" of a description says what it draws:
  button     a large button, such as the download button (title, line, glyph, color)
  grid       items in columns without frames: a tile with a glyph, a title and a sentence;
             with "code": true the title is a command or path in a monospace chip instead
  chips      a flag (names from scripts/flags.py) or a short code in a chip, with a name and a
             smaller second name, such as the languages
  terminal   a terminal window that types its commands; lines are [kind, text] with the kinds
             command, output, result and note
  flow       steps from left to right with arrows between them
  layers     stacked bars, the top one first, for parts that build on each other
  slideshow  pictures that fade into each other with a caption; "file" may name {shots} for
             the screenshots and {theme} for light or dark
Glyphs are names from GLYPHS below or SVG shapes in a 24-point grid; colors are the names of
doc-assets.py, so the pictures match the section icons. Slideshows and terminals move with
SVG's own animation, which GitHub plays in a guide.
"""

import argparse
import base64
import json
import subprocess
import tempfile
from html import escape
from importlib import import_module
from pathlib import Path

from checks.console import FAILURE, SUCCESS, frame, heading
from checks.project import PROJECT, relative_path
from flags import FLAGS

doc_assets = import_module("doc-assets")  # the shared colors and the section icon's tile

# MARK: Settings

DESCRIPTIONS = PROJECT / "docs" / "pictures"
OUT = PROJECT / "assets" / "pictures"
SHOTS = PROJECT / "snapshots" / "current"
FONT = doc_assets.FONT
MONO = "ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas, monospace"
# Apple's text colors; the shadow is the app icon's blue in light and black in dark.
THEMES = {
    "light": dict(text="#1D1D1F", muted="#6E6E73", chip="#E8EEFB", chip_text="#1F52DB",
                  window="#FFFFFF", bar="#F5F5F7", edge="#D2D2D7", prompt="#1E9B45",
                  output="#3A3A3C", success="#1E9B45", quiet="#8E8E93", shadow="#1F52DB",
                  backdrop=("#F7FAFF", "#DCE7FF"), tint=".10"),
    "dark": dict(text="#F5F5F7", muted="#A1A1A6", chip="#1F2A44", chip_text="#8DB8FF",
                 window="#1C1C1E", bar="#2C2C2E", edge="#3A3A3C", prompt="#5BD27A",
                 output="#E5E5EA", success="#5BD27A", quiet="#8E8E93", shadow="#000000",
                 backdrop=("#1A2238", "#0B1020"), tint=".22"),
}
WIDTH = 900  # a guide's width on GitHub, roughly; the pictures scale with the page
CHIP_ROW, TERMINAL_LINE, LAYER_ROW, LINE, ROW_GAP = 52, 24, 64, 19, 26
LETTER, MONO_LETTER = 7.0, 8.4  # rough widths of a letter at 13.5 and 14 points, for wrapping
SECONDS_PER_PICTURE, FADE_SECONDS, SECONDS_PER_LETTER = 3.5, 0.6, 0.02
SCREENSHOT_PIXELS, SCREENSHOT_QUALITY = 1200, 70  # sharp at a guide's width, light to load

GLYPHS = {
    "overview": '<path d="M5 20v-7M10 20V6M15 20v-9M20 20V9"/>',
    "folders": '<path d="M3 7.5A1.5 1.5 0 0 1 4.5 6H9l2 2h8.5A1.5 1.5 0 0 1 21 9.5v8a1.5 1.5 0 0 '
               '1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z"/>',
    "search": '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5.5 5.5"/>',
    "clean": '<path d="M11 3l1.9 5.1L18 10l-5.1 1.9L11 17l-1.9-5.1L4 10l5.1-1.9z"/>'
             '<path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
    "duplicates": '<rect x="8" y="3" width="11" height="14" rx="2"/>'
                  '<path d="M5 7v11a2 2 0 0 0 2 2h9"/>',
    "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "menu bar": '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 9h18M16 7h2"/>',
    "widget": '<rect x="4" y="4" width="7" height="7" rx="2"/>'
              '<rect x="13" y="4" width="7" height="7" rx="2"/>'
              '<rect x="4" y="13" width="16" height="7" rx="2"/>',
    "document": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
    "shield": '<path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z"/>'
              '<path d="M9 12l2 2 4-4"/>',
    "bolt": '<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z"/>',
    "code": '<path d="M8.5 8L4.5 12l4 4M15.5 8l4 4-4 4M13.5 5.5l-3 13"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 3.8 5.5 3.8 9s-1.3 '
             '6.5-3.8 9c-2.5-2.5-3.8-5.5-3.8-9S9.5 5.5 12 3z"/>',
    "download": '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
    "hammer": '<path d="M14 4l6 6-2.5 2.5-6-6zM11.5 6.5L4 14l3 3 7.5-7.5"/>',
    "terminal": '<rect x="3" y="4" width="18" height="16" rx="2.5"/>'
                '<path d="M7 9l3 3-3 3M12 15h5"/>',
    "tree": '<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="12" r="2.5"/>'
            '<circle cx="6" cy="18" r="2.5"/><path d="M8.5 6H12v12H8.5M12 12h3.5"/>',
    "box": '<path d="M4 7.5L12 3l8 4.5v9L12 21l-8-4.5z"/><path d="M4 7.5L12 12l8-4.5M12 12v9"/>',
    "window": '<rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M3 8.5h18M9 8.5V20"/>',
    "heart": '<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.6 4.3 4.3 0 0 1 19.5 10'
             'c0 5.4-7.5 10-7.5 10z"/>',
    "people": '<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/>'
              '<path d="M3.5 19c.5-3.2 2.7-5 5.5-5s5 1.8 5.5 5M15 14.2c2.7-.4 5 1.2 5.5 4.3"/>',
    "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/>'
            '<path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    "sprout": '<path d="M12 21v-9M12 12c0-4-3-6.5-7-6.5 0 4 3 6.5 7 6.5zM12 14c0-3.5 2.6-6 '
              '6.5-6 0 3.5-2.6 6-6.5 6z"/>',
}


# MARK: Pieces


def text(left: float, baseline: float, content: str, size: float, color: str, weight: int = 400,
         anchor: str = "start", font: str = FONT) -> str:
    return (f'<text x="{left:g}" y="{baseline:g}" font-family="{font}" font-size="{size}" '
            f'font-weight="{weight}" fill="{color}" text-anchor="{anchor}" '
            f'xml:space="preserve">{ascii_only(escape(content))}</text>')


def ascii_only(markup: str) -> str:
    """Letters beyond ASCII as character references: they render the same, and an own name
    such as Turkish's keeps its letters without reading as German to the repository's checks."""
    return markup.encode("ascii", "xmlcharrefreplace").decode()


def glyph_shapes(glyph: str) -> str:
    return GLYPHS.get(glyph, glyph)


def tile(left: float, top: float, color: str, glyph: str, number: int, size: float = 44) -> str:
    """The section icon of the guides, scaled so its tile is size pixels wide."""
    top_color, bottom_color = doc_assets.COLORS[color]
    icon = doc_assets.ICON_TEMPLATE.format(
        top=top_color, bottom=bottom_color, glyph=glyph_shapes(glyph))
    unique = icon.replace('id="t"', f'id="t{number}"').replace("url(#t)", f"url(#t{number})")
    scale = size / 45
    placed = f'x="{left:g}" y="{top:g}" width="{60 * scale:.1f}" height="{56 * scale:.1f}"'
    return unique.replace('width="60" height="56"', placed)


def svg(width: float, height: float, label: str, body: list[str]) -> str:
    named = ascii_only(escape(label))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:g}" height="{height:g}" '
            f'viewBox="0 0 {width:g} {height:g}" role="img" aria-label="{named}">\n'
            + "\n".join(body) + "\n</svg>\n")


def wrapped(sentence: str, width: float, letter: float = LETTER) -> list[str]:
    limit = max(int(width / letter), 1)
    lines = [""]
    for word in sentence.split():
        fits = len(lines[-1]) + 1 + len(word) <= limit or not lines[-1]
        lines[-1:] = [f"{lines[-1]} {word}".strip()] if fits else [lines[-1], word]
    return lines


def rows_of(items: list, columns: int) -> int:
    return -(-len(items) // columns)


def label_of(items: list[dict]) -> str:
    return "; ".join(f"{item['title']}: {item['text']}" for item in items)


# MARK: Kinds


def button(spec: dict, colors: dict) -> str:
    top, bottom = doc_assets.COLORS[spec.get("color", "blue")]
    body = [
        f'<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>'
        f'</linearGradient><filter id="s" x="-20%" y="-40%" width="140%" height="200%">'
        f'<feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="{colors["shadow"]}" '
        f'flood-opacity=".30"/></filter></defs>',
        '<g filter="url(#s)">'
        '<rect x="20" y="12" width="340" height="72" rx="20" fill="url(#b)"/></g>',
        '<rect x="20.5" y="12.5" width="339" height="71" rx="19.5" fill="none" stroke="#fff" '
        'stroke-opacity=".28"/>',
        '<g transform="translate(44 30) scale(1.5)" fill="none" stroke="#fff" stroke-width="2" '
        f'stroke-linecap="round" stroke-linejoin="round">{glyph_shapes(spec["glyph"])}</g>',
        text(100, 46, spec["title"], 24, "#FFFFFF", 600),
        text(100, 70, spec["line"], 14, "#E8F0FF"),
    ]
    return svg(380, 104, spec["label"], body)


def grid(spec: dict, colors: dict) -> str:
    items, columns, code = spec["items"], spec.get("columns", 3), spec.get("code", False)
    column_width = WIDTH / columns
    text_width = column_width - (24 if code else 76)
    most_lines = max(len(wrapped(item["text"], text_width)) for item in items)
    row = max(44 if code else 58, 44 + most_lines * LINE) + ROW_GAP
    body = []
    for number, item in enumerate(items):
        left, top = number % columns * column_width, number // columns * row
        place = (left, top, column_width, colors)
        body += code_item(item, *place) if code else tile_item(item, number, *place)
    height = rows_of(items, columns) * row - ROW_GAP
    return svg(WIDTH, height, spec.get("label", label_of(items)), body)


def tile_item(item: dict, number: int, left: float, top: float, width: float,
              colors: dict) -> list[str]:
    lines = wrapped(item["text"], width - 76)
    return [tile(left - 2, top + 3, item["color"], item["glyph"], number),
            text(left + 58, top + 22, item["title"], 16, colors["text"], 600)] + [
        text(left + 58, top + 44 + row * LINE, line, 13.5, colors["muted"])
        for row, line in enumerate(lines)]


def code_item(item: dict, left: float, top: float, width: float, colors: dict) -> list[str]:
    chip = len(item["title"]) * MONO_LETTER + 18
    lines = wrapped(item["text"], width - 24)
    return [f'<rect x="{left:g}" y="{top:g}" width="{chip:.1f}" height="26" rx="7" '
            f'fill="{colors["chip"]}"/>',
            text(left + 9, top + 18, item["title"], 14, colors["chip_text"], 600, font=MONO)] + [
        text(left, top + 46 + row * LINE, line, 13.5, colors["muted"])
        for row, line in enumerate(lines)]


def chips(spec: dict, colors: dict) -> str:
    items, columns = spec["items"], spec.get("columns", 4)
    column_width = WIDTH / columns
    body = []
    for number, item in enumerate(items):
        left, top = number % columns * column_width, number // columns * CHIP_ROW
        body += [
            flag(item["flag"], left, top + 9, number, colors) if "flag" in item else
            f'<rect x="{left:g}" y="{top + 6:g}" width="34" height="34" rx="9" '
            f'fill="{colors["chip"]}"/>'
            + text(left + 17, top + 28, item["code"], 12, colors["chip_text"], 700, "middle"),
            text(left + 50, top + 21, item["title"], 14.5, colors["text"], 600),
            text(left + 50, top + 38, item["text"], 12, colors["muted"]),
        ]
    label = spec.get("label", ", ".join(item["text"] for item in items))
    return svg(WIDTH, rows_of(items, columns) * CHIP_ROW, label, body)


def flag(country: str, left: float, top: float, number: int, colors: dict) -> str:
    """A flag of scripts/flags.py, 39 × 26 with rounded corners and a faint edge like a tile."""
    return (f'<svg x="{left:g}" y="{top:g}" width="39" height="26" viewBox="0 0 30 20">'
            f'<defs><clipPath id="f{number}"><rect width="30" height="20" rx="3.5"/></clipPath>'
            f'</defs>'
            f'<g clip-path="url(#f{number})">{FLAGS[country]}</g>'
            f'<rect x=".25" y=".25" width="29.5" height="19.5" rx="3.3" fill="none" '
            f'stroke="{colors["edge"]}" stroke-width=".5"/></svg>')


def flow(spec: dict, colors: dict) -> str:
    steps = spec["items"]
    column_width = WIDTH / len(steps)
    body, height = [], 0
    for number, step in enumerate(steps):
        middle = number * column_width + column_width / 2
        lines = wrapped(step["text"], column_width - 36)
        body += [tile(middle - 26.4, 0, step["color"], step["glyph"], number, 48),
                 text(middle, 80, f"{number + 1} · {step['title']}", 15, colors["text"], 600,
                      "middle")]
        body += [text(middle, 102 + row * 19, line, 13.5, colors["muted"], 400, "middle")
                 for row, line in enumerate(lines)]
        height = max(height, 102 + len(lines) * 19)
        body += [arrow(number * column_width, colors)] if number else []
    return svg(WIDTH, height, spec.get("label", label_of(steps)), body)


def arrow(left: float, colors: dict) -> str:
    return (f'<path d="M{left - 4:g} 18l8 8-8 8" fill="none" stroke="{colors["quiet"]}" '
            f'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')


def layers(spec: dict, colors: dict) -> str:
    rows = spec["items"]
    body = []
    for number, row in enumerate(rows):
        top = number * LAYER_ROW
        tint = doc_assets.COLORS[row["color"]][1]
        body += [f'<rect x="0" y="{top:g}" width="{WIDTH}" height="{LAYER_ROW - 10}" rx="14" '
                 f'fill="{tint}" fill-opacity="{colors["tint"]}"/>',
                 tile(14, top + 9, row["color"], row["glyph"], number, 36),
                 text(66, top + 24, row["title"], 15, colors["text"], 600),
                 text(66, top + 43, row["text"], 13, colors["muted"])]
    return svg(WIDTH, len(rows) * LAYER_ROW - 10, spec.get("label", label_of(rows)), body)


# MARK: Terminal


def typed_command(baseline: float, command: str, colors: dict,
                  begin: float) -> tuple[list[str], float]:
    """A prompt and a command that appears letter by letter: a cover slides off to the right."""
    seconds = len(command) * SECONDS_PER_LETTER
    left, width = 45, len(command) * 9.1 + 4  # 9.1 pixels per letter of the 15-pixel monospace
    timing = f'begin="{begin:.2f}s" dur="{seconds:.2f}s" fill="freeze"'
    cover = (f'<rect x="{left}" y="{baseline - 17:g}" width="{width:.1f}" height="23" '
             f'fill="{colors["window"]}">'
             f'<animate attributeName="x" from="{left}" to="{left + width:.1f}" {timing}/>'
             f'<animate attributeName="width" from="{width:.1f}" to="0" {timing}/></rect>')
    pieces = [text(28, baseline, "$", 15, colors["prompt"], 600, font=MONO),
              text(46, baseline, command, 15, colors["text"], 500, font=MONO), cover]
    return pieces, begin + seconds + 0.35


def terminal(spec: dict, colors: dict) -> str:
    lines = spec["lines"]
    height = 74 + len(lines) * TERMINAL_LINE + 10
    body = [
        f'<rect x="1" y="1" width="{WIDTH - 2}" height="{height - 2}" rx="12" '
        f'fill="{colors["window"]}" stroke="{colors["edge"]}"/>',
        f'<path d="M1 40V13a12 12 0 0 1 12-12h{WIDTH - 26}a12 12 0 0 1 12 12v27z" '
        f'fill="{colors["bar"]}"/>',
        f'<line x1="1" y1="40" x2="{WIDTH - 1}" y2="40" stroke="{colors["edge"]}"/>',
        '<circle cx="24" cy="20.5" r="6" fill="#FF5F57"/>'
        '<circle cx="44" cy="20.5" r="6" fill="#FEBC2E"/>'
        '<circle cx="64" cy="20.5" r="6" fill="#28C840"/>',
        text(WIDTH / 2, 25, spec["title"], 13, colors["muted"], 500, "middle", MONO),
    ]
    begin = 0.4
    for number, (kind, content) in enumerate(lines):
        baseline = 74 + number * TERMINAL_LINE
        if kind == "command":
            pieces, begin = typed_command(baseline, content, colors, begin)
            body += pieces
            continue
        color = colors[{"output": "output", "result": "success", "note": "quiet"}[kind]]
        body.append(f'<g opacity="0">{text(46, baseline, content, 15, color, font=MONO)}'
                    f'<set attributeName="opacity" to="1" begin="{begin:.2f}s" fill="freeze"/></g>')
        begin += 0.12
    return svg(WIDTH, height, spec["label"], body)


# MARK: Slideshow


def appearing(number: int, count: int) -> str:
    """Picture number fades in over the one before and stays until the next one covers it; the
    first lies at the bottom and shows again when the last fades out, so the show loops."""
    if number == 0:
        return ""
    total = count * SECONDS_PER_PICTURE
    start, end = number * SECONDS_PER_PICTURE, (number + 1) * SECONDS_PER_PICTURE
    last = number == count - 1
    values = "0;0;1;1;0" if last else "0;0;1;1;0;0"
    moments = [0, start - FADE_SECONDS, start, total - FADE_SECONDS if last else end]
    moments += [total] if last else [end + 0.01, total]
    key_times = ";".join(f"{moment / total:.4f}" for moment in moments)
    return (f'<animate attributeName="opacity" values="{values}" keyTimes="{key_times}" '
            f'dur="{total:g}s" repeatCount="indefinite"/>')


def dots(current: int, count: int, height: float, colors: dict) -> str:
    """One dot per picture, the current one wide and in the accent color."""
    first = WIDTH / 2 - count * 11
    return "".join(
        f'<rect x="{first + number * 22 - (6 if number == current else 0):g}" y="{height - 26:g}" '
        f'width="{20 if number == current else 8}" height="8" rx="4" '
        f'fill="{colors["chip_text"] if number == current else colors["muted"]}" '
        f'fill-opacity="{1 if number == current else 0.35}"/>'
        for number in range(count))


def slideshow(spec: dict, colors: dict, theme: str, shots: Path) -> str:
    width = spec.get("width", WIDTH - 90)
    files = [PROJECT / item["file"].format(shots=shots, theme=theme) for item in spec["pictures"]]
    area = max(picture_height(file, width) for file in files)
    height = 36 + area + 104
    light, deep = colors["backdrop"]
    body = [f'<defs><linearGradient id="bd" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{deep}"/>'
            f'</linearGradient><filter id="sh" x="-10%" y="-10%" width="120%" height="130%">'
            f'<feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="{colors["shadow"]}" '
            f'flood-opacity=".25"/></filter></defs>']
    for number, (item, file) in enumerate(zip(spec["pictures"], files)):
        left, top = (WIDTH - width) / 2, 36 + (area - picture_height(file, width)) / 2
        drawn = (drawing(file, left, top, width) if file.suffix == ".svg"
                 else photo(file, (left, top, width), spec.get("corner", 13), number))
        hidden = ' opacity="0"' if number else ""
        body.append(f'<g{hidden}>{appearing(number, len(files))}'
                    f'<rect width="{WIDTH}" height="{height:g}" rx="24" fill="url(#bd)"/>{drawn}'
                    + text(WIDTH / 2, height - 62, item["caption"], 20, colors["text"], 600,
                           "middle")
                    + text(WIDTH / 2, height - 38, item["line"], 14, colors["muted"], 400,
                           "middle")
                    + dots(number, len(files), height, colors) + "</g>")
    label = spec.get("label", "; ".join(item["caption"] for item in spec["pictures"]))
    return svg(WIDTH, height, label, body)


def drawing(path: Path, left: float, top: float, width: float) -> str:
    """Another SVG of the project, drawn inside the slideshow with a shadow."""
    source = path.read_text().strip()
    view = source.split('viewBox="', 1)[1].split('"', 1)[0]
    inner = source[source.index(">") + 1:source.rindex("</svg>")]
    return (f'<g filter="url(#sh)"><svg x="{left:g}" y="{top:g}" width="{width:g}" '
            f'height="{picture_height(path, width):.1f}" viewBox="{view}">{inner}</svg></g>')


def photo(path: Path, place: tuple[float, float, float], corner: float, number: int) -> str:
    """A screenshot as a small JPEG inside the SVG, its corners rounded like the window's."""
    left, top, width = place
    height = picture_height(path, width)
    with tempfile.TemporaryDirectory() as folder:
        jpeg = Path(folder) / "picture.jpg"
        subprocess.run(["sips", "-s", "format", "jpeg",
                        "-s", "formatOptions", str(SCREENSHOT_QUALITY),
                        "-Z", str(SCREENSHOT_PIXELS), str(path), "--out", str(jpeg)],
                       check=True, capture_output=True)
        data = base64.b64encode(jpeg.read_bytes()).decode()
    box = f'x="{left:g}" y="{top:g}" width="{width:g}" height="{height:.1f}"'
    return (f'<defs><clipPath id="c{number}"><rect {box} rx="{corner}"/></clipPath></defs>'
            f'<g filter="url(#sh)"><rect {box} rx="{corner}" fill="#fff"/></g>'
            f'<image {box} clip-path="url(#c{number})" href="data:image/jpeg;base64,{data}"/>')


def picture_height(path: Path, width: float) -> float:
    if path.suffix == ".svg":
        view = path.read_text().split('viewBox="', 1)[1].split('"', 1)[0]
        _, _, view_width, view_height = map(float, view.split())
        return width * view_height / view_width
    sizes = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                           check=True, capture_output=True, text=True).stdout.split()
    return width * int(sizes[-1]) / int(sizes[-3])


# MARK: Run

KINDS = {"button": button, "grid": grid, "chips": chips, "flow": flow, "layers": layers,
         "terminal": terminal}


def draw(description: Path, shots: Path) -> list[Path]:
    spec = json.loads(description.read_text())
    drawn = []
    for theme, colors in THEMES.items():
        kind = spec["kind"]
        content = (slideshow(spec, colors, theme, shots) if kind == "slideshow"
                   else KINDS[kind](spec, colors))
        path = OUT / f"{description.stem}-{theme}.svg"
        path.write_text(content)
        drawn.append(path)
    return drawn


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", help="only these pictures (docs/pictures/<name>.json)")
    parser.add_argument("--shots", type=Path, default=SHOTS,
                        help="the folder with <page>-<appearance>.png, as make snapshots leaves it")
    arguments = parser.parse_args()
    heading("Storage Manager · pictures", relative_path(OUT))
    names = arguments.names or sorted(path.stem for path in DESCRIPTIONS.glob("*.json"))
    missing = [name for name in names if not (DESCRIPTIONS / f"{name}.json").exists()]
    if missing:
        frame("Nothing drawn", [f"No description for {', '.join(missing)} in docs/pictures"],
              FAILURE)
        raise SystemExit(1)
    OUT.mkdir(exist_ok=True)
    descriptions = [DESCRIPTIONS / f"{name}.json" for name in names]
    drawn = [path for description in descriptions for path in draw(description, arguments.shots)]
    frame("Drawn", [f"{len(drawn)} pictures in {relative_path(OUT)}"], SUCCESS)


if __name__ == "__main__":
    main()
