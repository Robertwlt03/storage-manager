"""Finds images and other media files that nothing uses any more.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
A picture, icon or video in the repository counts as used when another file names it: a guide
shows it, a script draws from it or the app loads it. One that no file names is dead weight and is
reported, like dead code.
"""

from pathlib import Path

from checks.project import Codebase, app, is_text, place

# MARK: Settings

MEDIA_ENDINGS = {
    ".svg", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".icns", ".pdf", ".mov", ".mp4",
}


# MARK: Step


def unused_file_findings() -> list[str]:
    return unused_file_problems(app())


def unused_file_problems(codebase: Codebase) -> list[str]:
    media = [path for path in codebase.text_files if path.suffix.lower() in MEDIA_ENDINGS]
    readable = {path: path.read_text() for path in codebase.text_files if is_text(path)}
    return [
        f"{place(path, 1)}: no file names {path.name}; remove it, or show it where it belongs"
        for path in media if not is_named_elsewhere(path, readable)
    ]


def is_named_elsewhere(path: Path, readable: dict[Path, str]) -> bool:
    return any(path.name in text for other, text in readable.items() if other != path)
