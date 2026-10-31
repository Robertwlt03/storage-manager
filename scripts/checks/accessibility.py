"""Checks that every image in the app tells VoiceOver what to do with it.

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index finds every image the app's code creates)
An image either carries meaning and gets a name (.accessibilityLabel), or it decorates a text
beside it and stays silent (.accessibilityHidden(true)). Without that decision VoiceOver reads a
symbol's technical name, such as "folder fill". The decision belongs in the image's own chain of
modifiers, where the next reader sees it.
"""

import re
from pathlib import Path

from checks.index_store import Kind, Role
from checks.project import Codebase, app, compiler_index, lines_of, place

# MARK: Settings

SWIFTUI_IMAGE = "s:7SwiftUI5ImageV"  # how the unique names of SwiftUI's Image and its makers start
DECISION = re.compile(r"\.accessibility(?:Label|Hidden)\(")
MODIFIER_LINE = re.compile(r"^\s*\.")  # a line that goes on with the modifiers of the line above


# MARK: Step


def accessibility_findings() -> list[str]:
    return accessibility_problems(app())


def accessibility_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    app_code = set(codebase.swift_sources)
    images = {
        (found.path, found.line) for found in index.occurrences
        if found.roles & Role.REFERENCE and found.kind == Kind.INITIALIZER
        and found.unique_name.startswith(SWIFTUI_IMAGE) and found.path in app_code
    }
    return [
        f"{place(path, line)}: an image without an accessibility decision; give it "
        ".accessibilityLabel(…) when it carries meaning, "
        ".accessibilityHidden(true) when it decorates"
        for path, line in sorted(images) if not DECISION.search(modifier_chain(path, line))
    ]


def modifier_chain(path: Path, line: int) -> str:
    """The image's line and the lines below it that continue its modifiers."""
    lines = lines_of(path)
    chain = [lines[line - 1]]
    for following in lines[line:]:
        if not MODIFIER_LINE.match(following):
            break
        chain.append(following)
    return "\n".join(chain)
