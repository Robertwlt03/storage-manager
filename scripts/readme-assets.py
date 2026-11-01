#!/usr/bin/env python3
"""Draws the README's pictures in a light and a dark version, so GitHub shows the one that fits.

Start:  make readme, or scripts/readme-assets.py [--shots <folder>]
Needs:  macOS (sips makes the screenshots small) and the demo pages photographed light and dark,
        as make snapshots leaves them in snapshots/current (<page>-<appearance>.png)
Draws into assets/readme: the download button, the grids of features, promises and languages
(no frames, like a row of apps), two terminal windows that type their commands, the install
steps as a slideshow of the guide's pictures, and a tour through the app from the screenshots.
Slideshows and terminals move with SVG's own animation, which GitHub plays in a README.
"""

import argparse
import base64
import subprocess
import tempfile
from html import escape
from importlib import import_module
from pathlib import Path

from checks.console import FAILURE, SUCCESS, frame, heading
from checks.project import PROJECT, relative_path

doc_assets = import_module("doc-assets")  # the shared colors and the section icon's tile

# MARK: Settings

OUT = PROJECT / "assets" / "readme"
GUIDE_PICTURES = PROJECT / "docs" / "guide" / "images"
SHOTS = PROJECT / "snapshots" / "current"
FONT = doc_assets.FONT
MONO = "ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas, monospace"
# Apple's text colors; the shadow is the app icon's blue in light and black in dark.
THEMES = {
    "light": dict(text="#1D1D1F", muted="#6E6E73", chip="#E8EEFB", chip_text="#1F52DB",
                  window="#FFFFFF", bar="#F5F5F7", edge="#D2D2D7", prompt="#1E9B45",
                  output="#3A3A3C", success="#1E9B45", quiet="#8E8E93", shadow="#1F52DB",
                  backdrop=("#F7FAFF", "#DCE7FF")),
    "dark": dict(text="#F5F5F7", muted="#A1A1A6", chip="#1F2A44", chip_text="#8DB8FF",
                 window="#1C1C1E", bar="#2C2C2E", edge="#3A3A3C", prompt="#5BD27A",
                 output="#E5E5EA", success="#5BD27A", quiet="#8E8E93", shadow="#000000",
                 backdrop=("#1A2238", "#0B1020")),
}
WIDTH = 900  # the README's width on GitHub, roughly; everything scales with the page
GRID_ROW, LANGUAGE_ROW, TERMINAL_LINE = 118, 52, 24
SECONDS_PER_PICTURE, FADE_SECONDS, SECONDS_PER_LETTER = 3.5, 0.6, 0.02
SCREENSHOT_PIXELS, SCREENSHOT_QUALITY = 1200, 70  # sharp at README width, light to load

GLYPHS = {
    "overview": '<path d="M5 20v-7M10 20V6M15 20v-9M20 20V9"/>',
    "folders": '<path d="M3 7.5A1.5 1.5 0 0 1 4.5 6H9l2 2h8.5A1.5 1.5 0 0 1 21 9.5v8a1.5 1.5 0 0 '
               '1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z"/>',
    "search": '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5.5 5.5"/>',
    "clean": '<path d="M11 3l1.9 5.1L18 10l-5.1 1.9L11 17l-1.9-5.1L4 10l5.1-1.9z"/>'
             '<path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
    "duplicates": '<rect x="8" y="3" width="11" height="14" rx="2"/>'
                  '<path d="M5 7v11a2 2 0 0 0 2 2h9"/>',
    "apps": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "menu bar": '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 9h18M16 7h2"/>',
    "widget": '<rect x="4" y="4" width="7" height="7" rx="2"/>'
              '<rect x="13" y="4" width="7" height="7" rx="2"/>'
              '<rect x="4" y="13" width="16" height="7" rx="2"/>',
    "report": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
    "private": '<path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z"/>'
               '<path d="M9 12l2 2 4-4"/>',
    "energy": '<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z"/>',
    "open": '<path d="M8.5 8L4.5 12l4 4M15.5 8l4 4-4 4M13.5 5.5l-3 13"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 3.8 5.5 3.8 9s-1.3 '
             '6.5-3.8 9c-2.5-2.5-3.8-5.5-3.8-9S9.5 5.5 12 3z"/>',
    "download": '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
}

# Each item: glyph, color, title, one sentence.
FEATURES = [
    ("overview", "blue", "Overview",
     "Says how much space you can free and which step to take first."),
    ("folders", "sky", "Folders", "Every folder sorted by size, as a list, as tiles or as rings."),
    ("search", "indigo", "Large Files & Search",
     "Finds big files and any name in seconds, without a new scan."),
    ("clean", "purple", "Clean Up",
     "Removes caches, old logs and leftovers that macOS rebuilds anyway."),
    ("duplicates", "orange", "Duplicates",
     "Spots files that exist twice and moves the extra copies to the Trash."),
    ("apps", "pink", "Unused Apps",
     "Lists the apps you have not opened for months, with their size."),
    ("menu bar", "teal", "Menu bar",
     "Shows the free space at a glance and warns you when it runs low."),
    ("widget", "green", "Widget",
     "Keeps the free space on your desktop or in Notification Center."),
    ("report", "slate", "Report", "Saves every category and the largest files as a text file."),
]
PROMISES = [
    ("private", "green", "Private",
     "Reads only names and sizes and sends nothing to the internet."),
    ("energy", "orange", "Easy on energy", "Scans once on the efficient cores, then rests."),
    ("open", "indigo", "Free & open source", "No account, no ads, MIT license."),
    ("globe", "sky", "28 languages", "Follows the language of your Mac."),
]
# Code, own name, English name; in the order of the README's alt text.
LANGUAGES = [
    ("ZH", "简体中文", "Chinese (Simplified)"), ("ZH", "繁體中文", "Chinese (Traditional)"),
    ("CS", "Čeština", "Czech"), ("DA", "Dansk", "Danish"), ("NL", "Nederlands", "Dutch"),
    ("EN", "English", "English"), ("FI", "Suomi", "Finnish"), ("FR", "Français", "French"),
    ("DE", "Deutsch", "German"), ("EL", "Ελληνικά", "Greek"), ("HI", "हिन्दी", "Hindi"),
    ("HU", "Magyar", "Hungarian"), ("ID", "Bahasa Indonesia", "Indonesian"),
    ("IT", "Italiano", "Italian"), ("JA", "日本語", "Japanese"), ("KO", "한국어", "Korean"),
    ("NB", "Norsk", "Norwegian"), ("PL", "Polski", "Polish"),
    ("PT", "Português (Brasil)", "Portuguese (Brazil)"),
    ("PT", "Português (Portugal)", "Portuguese (Portugal)"), ("RO", "Română", "Romanian"),
    ("RU", "Русский", "Russian"), ("ES", "Español", "Spanish"), ("SV", "Svenska", "Swedish"),
    ("TH", "ไทย", "Thai"), ("TR", "T\u00fcrk\u00e7e", "Turkish"), ("UK", "Українська", "Ukrainian"),
    ("VI", "Tiếng Việt", "Vietnamese"),
]
# A terminal's lines: "command" is typed after the prompt, "note" stands in gray, "result" in green.
INSTALL_COMMANDS = [
    ("command", "hdiutil attach ~/Downloads/Storage-Manager.dmg"),
    ("command", 'cp -R "/Volumes/Storage Manager/Storage Manager.app" /Applications/'),
    ("command", 'hdiutil detach "/Volumes/Storage Manager"'),
    ("command", 'xattr -dr com.apple.quarantine "/Applications/Storage Manager.app"'),
    ("command", 'open "/Applications/Storage Manager.app"'),
    ("note", "# Storage Manager opens and asks for Full Disk Access"),
]
DEVELOPER_COMMANDS = [
    ("command", "make run"),
    ("result", "✔ Built  Storage Manager.app"),
    ("command", "make check"),
    ("output", "✔ Formatting (swift format)                 0 findings"),
    ("output", "✔ Unit tests (Swift Testing)                0 findings"),
    ("output", "✔ Every text translated                     0 findings"),
    ("note", "  … and the other steps"),
    ("result", "✔ All steps passed · no errors, no warnings"),
]
# The install steps: the guide's picture, its caption and a small line below.
STEPS = [
    ("1-disk-image.svg", "1 · Drag the app into Applications",
     "Open Storage-Manager.dmg first."),
    ("2-warning.svg", "2 · Open it and click “Done”", "macOS has not checked the app yet."),
    ("3-open-anyway.svg", "3 · Click “Open Anyway”",
     "System Settings › Privacy & Security, only once."),
    ("5-access-window.png", "4 · Click “Open System Settings”",
     "The app asks for Full Disk Access."),
    ("4-full-disk-access.svg", "4 · Turn Storage Manager on",
     "Then click “Restart App” in the app."),
]
# The tour: the page as make snapshots names it, its caption and a small line below.
TOUR = [
    ("overview", "Overview", "How much you can free, and the steps to get there."),
    ("explorer", "Folders", "Every folder sorted by size; a click opens it."),
    ("largeFiles", "Large Files", "Everything above the size you choose, as tiles or a list."),
    ("cleaner", "Clean Up", "Pick what may go. Running apps and macOS stay untouched."),
    ("duplicates", "Duplicates", "Extra copies go to the Trash, after you confirm."),
    ("apps", "Unused Apps", "Apps you have not opened for months, with their size."),
]


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


def tile(left: float, top: float, color: str, glyph: str, number: int) -> str:
    """The section icon of the guides, at 52.8 × 49.3 so its tile is 44 pixels wide."""
    top_color, bottom_color = doc_assets.COLORS[color]
    icon = doc_assets.ICON_TEMPLATE.format(
        top=top_color, bottom=bottom_color, glyph=GLYPHS[glyph])
    unique = icon.replace('id="t"', f'id="t{number}"').replace("url(#t)", f"url(#t{number})")
    placed = f'x="{left:g}" y="{top:g}" width="52.8" height="49.3"'
    return unique.replace('width="60" height="56"', placed)


def svg(width: float, height: float, label: str, body: list[str]) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:g}" height="{height:g}" '
            f'viewBox="0 0 {width:g} {height:g}" role="img" aria-label="{escape(label)}">\n'
            + "\n".join(body) + "\n</svg>\n")


def write(name: str, theme: str, content: str) -> Path:
    path = OUT / f"{name}-{theme}.svg"
    path.write_text(content)
    return path


def wrapped(sentence: str, limit: int) -> list[str]:
    lines = [""]
    for word in sentence.split():
        fits = len(lines[-1]) + 1 + len(word) <= limit or not lines[-1]
        lines[-1:] = [f"{lines[-1]} {word}".strip()] if fits else [lines[-1], word]
    return lines


# MARK: Button and grids


def download_button(theme: str) -> Path:
    colors = THEMES[theme]
    top, bottom = doc_assets.COLORS["blue"]
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
        f'stroke-linecap="round" stroke-linejoin="round">{GLYPHS["download"]}</g>',
        text(100, 46, "Download for Mac", 24, "#FFFFFF", 600),
        text(100, 70, "Free · macOS 27 · Apple silicon", 14, "#E8F0FF"),
    ]
    return write("download", theme, svg(380, 104, "Download Storage Manager for Mac", body))


def grid(name: str, items: list[tuple[str, str, str, str]], theme: str, columns: int,
         letters_per_line: int) -> Path:
    colors = THEMES[theme]
    column_width = WIDTH / columns
    body = []
    for number, (glyph, color, title, sentence) in enumerate(items):
        left, top = number % columns * column_width, number // columns * GRID_ROW
        body.append(tile(left - 2, top + 3, color, glyph, number))
        body.append(text(left + 58, top + 22, title, 16, colors["text"], 600))
        body += [text(left + 58, top + 44 + row * 19, line, 13.5, colors["muted"])
                 for row, line in enumerate(wrapped(sentence, letters_per_line))]
    rows = -(-len(items) // columns)
    label = "; ".join(f"{title}: {sentence}" for _, _, title, sentence in items)
    return write(name, theme, svg(WIDTH, rows * GRID_ROW - 18, label, body))


def languages(theme: str, columns: int = 4) -> Path:
    colors = THEMES[theme]
    column_width = WIDTH / columns
    body = []
    for number, (code, own_name, english_name) in enumerate(LANGUAGES):
        left, top = number % columns * column_width, number // columns * LANGUAGE_ROW
        body += [
            f'<rect x="{left:g}" y="{top + 6:g}" width="34" height="34" rx="9" '
            f'fill="{colors["chip"]}"/>',
            text(left + 17, top + 28, code, 12, colors["chip_text"], 700, "middle"),
            text(left + 46, top + 21, own_name, 14.5, colors["text"], 600),
            text(left + 46, top + 38, english_name, 12, colors["muted"]),
        ]
    rows = -(-len(LANGUAGES) // columns)
    label = f"{len(LANGUAGES)} languages: " + ", ".join(english for _, _, english in LANGUAGES)
    return write("languages", theme, svg(WIDTH, rows * LANGUAGE_ROW, label, body))


# MARK: Terminals


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


def terminal(name: str, title: str, lines: list[tuple[str, str]], label: str, theme: str) -> Path:
    colors = THEMES[theme]
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
        text(WIDTH / 2, 25, title, 13, colors["muted"], 500, "middle", MONO),
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
    return write(name, theme, svg(WIDTH, height, label, body))


# MARK: Slideshows


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


def slideshow(name: str, pictures: list[tuple[str, str, str]], label: str, theme: str,
              height: float) -> Path:
    """pictures: each picture's markup, its caption and the small line below the caption."""
    colors = THEMES[theme]
    light, deep = colors["backdrop"]
    count = len(pictures)
    body = [f'<defs><linearGradient id="bd" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="1" stop-color="{deep}"/>'
            f'</linearGradient><filter id="sh" x="-10%" y="-10%" width="120%" height="130%">'
            f'<feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="{colors["shadow"]}" '
            f'flood-opacity=".25"/></filter></defs>']
    for number, (picture, caption, line) in enumerate(pictures):
        hidden = ' opacity="0"' if number else ""
        body.append(f'<g{hidden}>{appearing(number, count)}'
                    f'<rect width="{WIDTH}" height="{height:g}" rx="24" fill="url(#bd)"/>{picture}'
                    + text(WIDTH / 2, height - 62, caption, 20, colors["text"], 600, "middle")
                    + text(WIDTH / 2, height - 38, line, 14, colors["muted"], 400, "middle")
                    + dots(number, count, height, colors) + "</g>")
    return write(name, theme, svg(WIDTH, height, label, body))


def dots(current: int, count: int, height: float, colors: dict) -> str:
    """One dot per picture, the current one wide and in the accent color."""
    first = WIDTH / 2 - count * 11
    return "".join(
        f'<rect x="{first + number * 22 - (6 if number == current else 0):g}" y="{height - 26:g}" '
        f'width="{20 if number == current else 8}" height="8" rx="4" '
        f'fill="{colors["chip_text"] if number == current else colors["muted"]}" '
        f'fill-opacity="{1 if number == current else 0.35}"/>'
        for number in range(count))


def guide_picture(path: Path, left: float, top: float, width: float) -> str:
    """A guide's own SVG, drawn inside the slideshow with a shadow."""
    source = path.read_text().strip()
    view = source.split('viewBox="', 1)[1].split('"', 1)[0]
    inner = source[source.index(">") + 1:source.rindex("</svg>")]
    return (f'<g filter="url(#sh)"><svg x="{left:g}" y="{top:g}" width="{width:g}" '
            f'height="{picture_height(path, width):.1f}" viewBox="{view}">{inner}</svg></g>')


def photo(path: Path, left: float, top: float, width: float, corner: float) -> str:
    """A screenshot as a small JPEG inside the SVG, its corners rounded like the window's."""
    height = picture_height(path, width)
    with tempfile.TemporaryDirectory() as folder:
        jpeg = Path(folder) / "picture.jpg"
        subprocess.run(["sips", "-s", "format", "jpeg",
                        "-s", "formatOptions", str(SCREENSHOT_QUALITY),
                        "-Z", str(SCREENSHOT_PIXELS), str(path), "--out", str(jpeg)],
                       check=True, capture_output=True)
        data = base64.b64encode(jpeg.read_bytes()).decode()
    clip = f"c{path.stem}"
    box = f'x="{left:g}" y="{top:g}" width="{width:g}" height="{height:.1f}"'
    return (f'<defs><clipPath id="{clip}"><rect {box} rx="{corner}"/></clipPath></defs>'
            f'<g filter="url(#sh)"><rect {box} rx="{corner}" fill="#fff"/></g>'
            f'<image {box} clip-path="url(#{clip})" href="data:image/jpeg;base64,{data}"/>')


def picture_height(path: Path, width: float) -> float:
    if path.suffix == ".svg":
        view = path.read_text().split('viewBox="', 1)[1].split('"', 1)[0]
        _, _, view_width, view_height = map(float, view.split())
        return width * view_height / view_width
    sizes = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                           check=True, capture_output=True, text=True).stdout.split()
    return width * int(sizes[-1]) / int(sizes[-3])


def install_steps(theme: str, area_top: float = 30, area_height: float = 370,
                  width: float = 620) -> Path:
    pictures = []
    for file, caption, line in STEPS:
        path = GUIDE_PICTURES / file
        left = (WIDTH - width) / 2
        top = area_top + (area_height - picture_height(path, width)) / 2
        is_drawing = path.suffix == ".svg"
        drawn = (guide_picture(path, left, top, width) if is_drawing
                 else photo(path, left, top, width, 12))
        pictures.append((drawn, caption, line))
    label = "Installing step by step: " + "; ".join(caption for _, caption, _ in STEPS)
    return slideshow("install", pictures, label, theme, area_top + area_height + 100)


def tour(theme: str, shots: Path) -> Path:
    width = WIDTH - 90
    pictures = [(photo(shots / f"{page}-{theme}.png", 45, 36, width, 13), caption, line)
                for page, caption, line in TOUR]
    tallest = max(picture_height(shots / f"{page}-{theme}.png", width) for page, _, _ in TOUR)
    label = "A tour through Storage Manager: " + "; ".join(f"{c}: {l}" for _, c, l in TOUR)
    return slideshow("tour", pictures, label, theme, 36 + tallest + 104)


# MARK: Run


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--shots", type=Path, default=SHOTS,
                        help="the folder with <page>-<appearance>.png, as make snapshots leaves it")
    shots = parser.parse_args().shots
    heading("Storage Manager · README pictures", relative_path(OUT))
    OUT.mkdir(exist_ok=True)
    missing = [f"{page}-{theme}.png" for theme in THEMES for page, _, _ in TOUR
               if not (shots / f"{page}-{theme}.png").exists()]
    if missing:
        frame("Nothing drawn", [f"{shots} lacks {', '.join(missing)}",
                                "Run make snapshots first, or name the folder with --shots."],
              FAILURE)
        raise SystemExit(1)
    drawn = []
    for theme in THEMES:
        drawn += [download_button(theme), grid("features", FEATURES, theme, 3, 33),
                  grid("promises", PROMISES, theme, 4, 24), languages(theme),
                  terminal("terminal-install", "Terminal — zsh", INSTALL_COMMANDS,
                           "Installing from the terminal: attach the disk image, copy the app, "
                           "detach it, allow the first launch and open the app", theme),
                  terminal("terminal-develop", "storage-manager — zsh", DEVELOPER_COMMANDS,
                           "make run builds and opens the app; make check runs every check", theme),
                  install_steps(theme), tour(theme, shots)]
    frame("Drawn", [f"{len(drawn)} pictures in {relative_path(OUT)}"], SUCCESS)


if __name__ == "__main__":
    main()
