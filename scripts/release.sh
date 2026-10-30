#!/bin/bash
# Builds the disk image to share: the app, a link to the Applications folder and the illustrated
# installation guide, in dist/Speicher-Explorer-<version>.dmg.
#
# Start:  make release
# Needs:  Xcode 27 and a signing identity in SIGN_IDENTITY (make identity writes it to local.mk).
#         Free: the self-signed identity; users confirm the first start once ("Open Anyway").
#         Paid: SIGN_IDENTITY="Developer ID Application: …" and NOTARY_PROFILE=<profile> also
#         notarize the image, so macOS opens it without any warning.
set -euo pipefail
cd "$(dirname "$0")/.."

# MARK: Settings

IDENTITY="${SIGN_IDENTITY:?Create a signing identity first: make identity}"
NAME="Speicher-Explorer"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
APP_FOLDER="dist/app"
DISK_IMAGE="dist/$NAME-$VERSION.dmg"
CONTENTS="dist/contents"  # what the disk image shows, put together before it is packed
APPLE_IDENTITY_PREFIX="Developer ID Application:"

# MARK: Steps

build_signed_app() {
  BUILD_FOLDER="$APP_FOLDER" SIGN_IDENTITY="$IDENTITY" ./build.sh
  codesign --verify --strict "$APP_FOLDER/$NAME.app"
}

gather_contents() {
  rm -rf "$CONTENTS" "$DISK_IMAGE"
  mkdir -p "$CONTENTS/Anleitung"
  cp -R "$APP_FOLDER/$NAME.app" "$CONTENTS/"
  ln -s /Applications "$CONTENTS/Programme"
  cp -R docs/anleitung/. "$CONTENTS/Anleitung/"
}

pack_disk_image() {
  # UDZO: a compressed, read-only image, the usual format for sharing apps.
  hdiutil create -volname "$NAME" -srcfolder "$CONTENTS" -format UDZO -ov "$DISK_IMAGE" \
    > /dev/null
  rm -rf "$CONTENTS"
  SIGN_IDENTITY="$IDENTITY" scripts/sign.sh "$DISK_IMAGE"
}

notarize_when_possible() {
  if [[ "$IDENTITY" == "$APPLE_IDENTITY_PREFIX"* && -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DISK_IMAGE" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DISK_IMAGE"
    echo "Notarized: macOS opens the app without a warning."
  fi
}

# MARK: Run

main() {
  build_signed_app
  gather_contents
  pack_disk_image
  notarize_when_possible
  echo "Done: $DISK_IMAGE"
}

main "$@"
