#!/bin/bash
# Builds a disk image to share: dist/Speicher-Explorer-<version>.dmg with the app, a link to the Applications
# folder and the illustrated installation guide.
#
# Signing (free): SIGN_IDENTITY defaults to the self-signed "Speicher-Explorer Dev" from create-signing-identity.sh.
#   Users confirm the first start once ("Open Anyway"); permissions then survive every update.
# Signing (Apple, paid): SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=<notarytool profile>
#   additionally notarizes the image, so macOS opens it without any warning.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-Speicher-Explorer Dev}"
NAME="Speicher-Explorer"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG="dist/$NAME-$VERSION.dmg"
STAGE="dist/stage"

BUILD_DIR=dist/app SIGN_IDENTITY="$IDENTITY" ./build.sh
codesign --verify --strict "dist/app/$NAME.app"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE/Anleitung"
cp -R "dist/app/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Programme"
cp -R docs/anleitung/. "$STAGE/Anleitung/"

hdiutil create -volname "$NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG" > /dev/null
codesign --force --sign "$IDENTITY" "$DMG"

if [[ "$IDENTITY" == "Developer ID Application:"* && -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "Notarized: macOS opens the app without a warning."
fi
rm -rf "$STAGE"
echo "Done: $DMG"
