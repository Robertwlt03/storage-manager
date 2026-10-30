"""Checks that the app reads and writes the disk only in code that is free of the main thread.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index shows every interface the app's code calls)
In this project every type runs on the main thread unless it is marked `nonisolated`, and the main
thread draws the window: a slow disk there makes the app stutter and keeps the Mac awake longer.
So every call that reaches the disk stands inside a declaration marked `nonisolated` or a task
started with `Task.detached`. The diagnostics, which test the app themselves, are left out.
"""

import re
from pathlib import Path

from checks.index_store import Occurrence, Role
from checks.nesting import braces_of, swift_code
from checks.project import Codebase, app, compiler_index, place, relative_path

# MARK: Settings

# What reaches the disk, by a readable name and the start of the index's unique name.
DISK_INTERFACES = {
    "FileManager": "c:objc(cs)NSFileManager(im)",
    "fts": "c:@F@fts_",
    "stat": "c:@F@stat",
    "lstat": "c:@F@lstat",
    "getattrlist": "c:@F@getattrlist",
    "opendir": "c:@F@opendir",
    "readdir": "c:@F@readdir",
    "Data(contentsOf:)": "s:10Foundation4DataV10contentsOf",
    "String(contentsOf:)": "s:SS10FoundationE10contentsOf",
    "URL.resourceValues": "s:10Foundation3URLV14resourceValues",
    "Bundle(path:)": "c:objc(cs)NSBundle(im)initWithPath",
    "NSDictionary(contentsOfFile:)": "c:objc(cs)NSDictionary(im)initWithContentsOf",
    "NSWorkspace.icon(forFile:)": "c:objc(cs)NSWorkspace(im)iconForFile",
    "Quick Look thumbnails": "c:objc(cs)QLThumbnailGenerator",
}
# The text before a brace that opens code free of the main thread.
OFF_THE_MAIN_THREAD = re.compile(r"""
    \b nonisolated \b (?! \s* \( \s* unsafe )     # nonisolated, but not nonisolated(unsafe)
    | \b Task\.detached \b                         # a task of its own
""", re.VERBOSE)
LEFT_OUT = ("Sources/Diagnostics/",)


# MARK: Step


def disk_access_findings() -> list[str]:
    return disk_access_problems(app())


def disk_access_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    app_code = {
        path for path in codebase.swift_sources if not relative_path(path).startswith(LEFT_OUT)
    }
    findings = set()
    for found in index.occurrences:
        interface = disk_interface(found)
        if interface and found.path in app_code and not runs_off_the_main_thread(found):
            findings.add(
                f"{place(found.path, found.line)}: {interface} reaches the disk on the main "
                "thread; move it into a nonisolated service or a Task.detached"
            )
    return sorted(findings)


def disk_interface(found: Occurrence) -> str | None:
    if not found.roles & Role.REFERENCE:
        return None
    matching = (
        name for name, start in DISK_INTERFACES.items() if found.unique_name.startswith(start)
    )
    return next(matching, None)


def runs_off_the_main_thread(found: Occurrence) -> bool:
    return any(OFF_THE_MAIN_THREAD.search(text) for text in enclosing_texts(found.path, found))


def enclosing_texts(path: Path, found: Occurrence) -> list[str]:
    """The text before each brace that is still open where the call stands."""
    open_texts = []
    for line, column, text_before, character in braces_of(swift_code(path)):
        if (line, column) > (found.line, found.column):
            break
        if character == "{":
            open_texts.append(text_before)
        elif open_texts:
            open_texts.pop()
    return open_texts
