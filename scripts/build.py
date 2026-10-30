#!/usr/bin/env python3
"""Builds Speicher-Explorer.app with its icon, translations and signature.

Start:  make build, or make build INSTALL_APP=1 to copy the app to ~/Applications as well
Needs:  Xcode 27; settings come from the environment (the Makefile passes them on):
        BUILD_FOLDER (default: build), BUNDLE_ID (another identifier, as for the demo),
        SIGN_IDENTITY (default: ad hoc) and, for the identity of make identity,
        SIGNING_KEYCHAIN and SIGNING_KEYCHAIN_PASSWORD
release.py builds through build() and signs the disk image through sign().
"""

import os
import shutil
import sys
from pathlib import Path

from checks import console, project
from checks.project import PROJECT, has_xcode

# MARK: Settings

APP_NAME = "Speicher-Explorer.app"
BINARY = PROJECT / ".build" / "release" / "SpeicherExplorer"
# The sizes in points macOS asks for in an app icon; each one also comes twice as large for
# Retina screens.
ICON_SIZES = (16, 32, 128, 256, 512)
INSTALLED_APP = Path.home() / "Applications" / APP_NAME
AD_HOC_IDENTITY = "-"  # signs without a certificate (ad hoc)


# MARK: Steps


def run(command: list[str | Path]) -> str:
    """Runs a command in the project folder and stops the script when it fails."""
    result = project.run([str(part) for part in command])
    if not result.succeeded:
        console.failed("Failed", str(command[0]))
        console.note(result.output.strip())
        sys.exit(1)
    return result.output


def compile_app() -> None:
    if not has_xcode():
        sys.exit(1)
    status = console.wait(
        "Compiling (release; errors appear below)",
        ["swift", "build", "--configuration", "release", "--quiet"],
        PROJECT,
    )
    if status != 0:
        sys.exit(status)
    console.passed("Compiled", "release")


def assemble(app: Path, bundle_id: str) -> None:
    shutil.rmtree(app, ignore_errors=True)
    for folder in ("MacOS", "Resources"):
        (app / "Contents" / folder).mkdir(parents=True)
    shutil.copy2(BINARY, app / "Contents" / "MacOS")
    shutil.copy2(PROJECT / "Info.plist", app / "Contents")
    for translation in sorted((PROJECT / "Resources").glob("*.lproj")):
        shutil.copytree(translation, app / "Contents" / "Resources" / translation.name)
    # A build with another bundle identifier (the demo) gets its own permissions and settings, so
    # it never takes over the Full Disk Access of the signed app.
    if bundle_id:
        run(["/usr/libexec/PlistBuddy", "-c", f"Set :CFBundleIdentifier {bundle_id}",
             app / "Contents" / "Info.plist"])
    console.passed("Put together", bundle_id or "the identifier from Info.plist")


def add_icon(app: Path, build_folder: Path) -> None:
    picture = build_folder / "icon.png"
    icon_set = build_folder / "AppIcon.iconset"
    run([BINARY, "--render-icon", picture])  # the app draws its own icon with SwiftUI
    shutil.rmtree(icon_set, ignore_errors=True)
    icon_set.mkdir()
    for size in ICON_SIZES:
        scale_icon(picture, size, icon_set / f"icon_{size}x{size}.png")
        scale_icon(picture, size * 2, icon_set / f"icon_{size}x{size}@2x.png")
    run(["iconutil", "--convert", "icns", icon_set,
         "--output", app / "Contents" / "Resources" / "AppIcon.icns"])
    console.passed("Icon drawn", f"{len(ICON_SIZES)} sizes, each also for Retina")


def scale_icon(picture: Path, pixels: int, destination: Path) -> None:
    run(["sips", "--resampleHeightWidth", str(pixels), str(pixels), picture, "--out", destination])


def sign(target: Path, identity: str) -> None:
    """With a fixed identity macOS keeps granted permissions across rebuilds; ad hoc it asks
    again after every build. make identity creates one and writes it to local.mk."""
    options = ["--force", "--options", "runtime", "--sign", identity]
    keychain = os.environ.get("SIGNING_KEYCHAIN", "")
    if keychain and identity != AD_HOC_IDENTITY:
        password = os.environ.get("SIGNING_KEYCHAIN_PASSWORD", "")
        run(["security", "unlock-keychain", "-p", password, keychain])
        options += ["--keychain", keychain]
    # codesign talks even when it succeeds ("replacing existing signature"); run() shows it only
    # when it fails.
    run(["codesign", *options, target])
    console.passed("Signed", "ad hoc" if identity == AD_HOC_IDENTITY else identity)


def build(build_folder: Path, identity: str, bundle_id: str = "") -> Path:
    app = build_folder / APP_NAME
    compile_app()
    assemble(app, bundle_id)
    add_icon(app, build_folder)
    sign(app, identity)
    return app


def shown(path: Path) -> str:
    """A path inside the project as the project sees it, such as build/Speicher-Explorer.app."""
    return str(path.relative_to(PROJECT) if path.is_relative_to(PROJECT) else path)


def install(app: Path) -> None:
    shutil.rmtree(INSTALLED_APP, ignore_errors=True)
    INSTALLED_APP.parent.mkdir(exist_ok=True)
    shutil.copytree(app, INSTALLED_APP, symlinks=True)


# MARK: Run


def main() -> None:
    build_folder = PROJECT / os.environ.get("BUILD_FOLDER", "build")
    console.heading("Speicher-Explorer · build", shown(build_folder / APP_NAME))
    identity = os.environ.get("SIGN_IDENTITY") or AD_HOC_IDENTITY
    app = build(build_folder, identity, os.environ.get("BUNDLE_ID", ""))
    if os.environ.get("INSTALL_APP"):
        install(app)
        console.frame("Installed", [str(INSTALLED_APP)], console.SUCCESS)
    else:
        console.frame("Built", [shown(app)], console.SUCCESS)


if __name__ == "__main__":
    main()
