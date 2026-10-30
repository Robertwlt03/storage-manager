"""Guards what the app promises its users: it never goes online, and it removes files only where
it asks first (see the README and ARCHITECTURE.md).

Start:  imported by scripts/check.py, not started on its own
Needs:  Xcode 27 (the compiler's index shows every interface the app's code calls)
Each promise names the interfaces that would break it and the only places, if any, where they
may be called. A call anywhere else is reported, so the promise holds for code written later too.
"""

from dataclasses import dataclass

from checks.index_store import Role
from checks.project import Codebase, app, compiler_index, place, relative_path

# MARK: Settings


@dataclass(frozen=True)
class Promise:
    message: str
    # The interfaces that would break the promise, by a readable name and the start of the
    # unique name the compiler's index gives them. The unique name keeps apart what shares a
    # name: FileManager's removeItem deletes a file, a Set's remove only forgets a value.
    interfaces: dict[str, str]
    allowed_in: tuple[str, ...] = ()  # files, relative to the project, that may call them


NO_NETWORK = Promise(
    "goes online, but the app promises to keep everything on this Mac",
    {
        "URLSession": "c:objc(cs)NSURLSession",
        "NSURLConnection": "c:objc(cs)NSURLConnection",
        "the Network framework": "s:7Network",
        "WebKit": "c:objc(cs)WKWebView",
        "CloudKit": "c:objc(cs)CK",
        "a socket": "c:@F@socket",
        "a host name lookup": "c:@F@getaddrinfo",
    },
)
# Only these services remove files; each acts after the user confirmed (see AppModel).
ONLY_AFTER_ASKING = Promise(
    "removes files outside the services that ask first",
    {
        "FileManager.removeItem": "c:objc(cs)NSFileManager(im)removeItem",
        "FileManager.trashItem": "c:objc(cs)NSFileManager(im)trashItem",
        "FileManager.replaceItem": "c:objc(cs)NSFileManager(im)replaceItem",
        "NSWorkspace.recycle": "c:objc(cs)NSWorkspace(im)recycle",
        "unlink": "c:@F@unlink",
        "rmdir": "c:@F@rmdir",
        "remove": "c:@F@remove",
    },
    allowed_in=(
        "Sources/Services/CleanerService.swift",
        "Sources/Services/CopyService.swift",
        "Sources/Services/AppUsageService.swift",
    ),
)
PROMISES = (NO_NETWORK, ONLY_AFTER_ASKING)


# MARK: Step


def promise_findings() -> list[str]:
    return promise_problems(app())


def promise_problems(codebase: Codebase) -> list[str]:
    index = compiler_index(codebase)
    if index.build_problems:
        return list(index.build_problems)
    app_code = set(codebase.swift_sources)
    findings = []
    for found in index.occurrences:
        if found.roles & Role.REFERENCE and found.path in app_code:
            findings += [
                f"{place(found.path, found.line)}: {interface} {promise.message}"
                for promise in PROMISES for interface in broken_by(promise, found)
            ]
    return sorted(set(findings))


def broken_by(promise: Promise, found) -> list[str]:
    """The readable names of the interfaces this use calls, unless its file may call them."""
    if relative_path(found.path) in promise.allowed_in:
        return []
    return [
        readable for readable, unique_start in promise.interfaces.items()
        if found.unique_name.startswith(unique_start)
    ]
