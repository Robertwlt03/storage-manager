#!/usr/bin/env python3
"""Builds the disk image to share: the app, a link to the Applications folder and the illustrated
installation guide, in dist/Storage-Manager.dmg. The name has no version, so the README's
download link (releases/latest/download/Storage-Manager.dmg) always gets the newest one.

Start:  make release
Needs:  Xcode 27 and a signing identity in SIGN_IDENTITY (make identity writes it to local.mk).
        Free: the self-signed identity; users confirm the first start once ("Open Anyway").
        Paid: SIGN_IDENTITY="Developer ID Application: …" and NOTARY_PROFILE=<profile> also
        notarize the image, so macOS opens it without any warning.
"""

import os
import plistlib
import shutil
import sys
from pathlib import Path

from build import APP_NAME, build, run, shown, sign
from checks import console
from checks.project import PROJECT

# MARK: Settings

DISK_IMAGE_NAME = "Storage Manager"  # the volume's name; the file uses hyphens
DISK_IMAGE_FILE = "Storage-Manager"  # no space, so a download link needs no escaping
RELEASE_FOLDER = PROJECT / "dist"
APP_FOLDER = RELEASE_FOLDER / "app"
CONTENTS = RELEASE_FOLDER / "contents"  # what the disk image shows, gathered before packing
DEVELOPER_ID_PREFIX = "Developer ID Application:"


# MARK: Steps


def version() -> str:
    with (PROJECT / "Info.plist").open("rb") as info_plist:
        return plistlib.load(info_plist)["CFBundleShortVersionString"]


def build_signed_app(identity: str) -> None:
    app = build(APP_FOLDER, identity)
    run(["codesign", "--verify", "--strict", app])
    console.passed("Signature verified", shown(app))


def gather_contents() -> None:
    shutil.rmtree(CONTENTS, ignore_errors=True)
    shutil.copytree(APP_FOLDER / APP_NAME, CONTENTS / APP_NAME, symlinks=True)
    (CONTENTS / "Applications").symlink_to("/Applications")
    shutil.copytree(PROJECT / "docs" / "guide", CONTENTS / "Guide")
    console.passed("Gathered", "the app, the Applications link and the guide")


def pack(disk_image: Path, identity: str) -> None:
    # UDZO: a compressed, read-only image, the usual format for sharing apps.
    status = console.wait("Packing the disk image", [
        "hdiutil", "create", "-quiet", "-volname", DISK_IMAGE_NAME, "-srcfolder", str(CONTENTS),
        "-format", "UDZO", "-ov", str(disk_image),
    ])
    shutil.rmtree(CONTENTS, ignore_errors=True)
    if status != 0:
        sys.exit(status)
    sign(disk_image, identity)


def notarize_when_possible(disk_image: Path, identity: str) -> None:
    profile = os.environ.get("NOTARY_PROFILE", "")
    if not identity.startswith(DEVELOPER_ID_PREFIX) or not profile:
        return
    status = console.wait("Waiting for Apple to notarize the disk image", [
        "xcrun", "notarytool", "submit", str(disk_image), "--keychain-profile", profile, "--wait",
    ])
    if status != 0:
        sys.exit(status)
    run(["xcrun", "stapler", "staple", disk_image])
    console.passed("Notarized", "macOS opens the app without a warning")


# MARK: Run


def main() -> None:
    release_version = version()
    console.heading("Storage Manager · release", f"version {release_version}")
    identity = os.environ.get("SIGN_IDENTITY", "")
    if not identity:
        console.frame("No disk image", ["Create a signing identity first: make identity"],
                      console.FAILURE)
        sys.exit(1)
    disk_image = RELEASE_FOLDER / f"{DISK_IMAGE_FILE}.dmg"
    build_signed_app(identity)
    gather_contents()
    pack(disk_image, identity)
    notarize_when_possible(disk_image, identity)
    console.frame("Disk image ready", [shown(disk_image)], console.SUCCESS)


if __name__ == "__main__":
    main()
