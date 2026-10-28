#!/bin/bash
# Builds Speicher-Explorer.app into $BUILD_DIR (default: build). With --install it also copies it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=.build/release/SpeicherExplorer
"$BIN" --check-contrast > /dev/null || { "$BIN" --check-contrast | grep FAIL; exit 1; }

BUILD_DIR="${BUILD_DIR:-build}"
APP="$BUILD_DIR/Speicher-Explorer.app"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
"$APP/Contents/MacOS/SpeicherExplorer" --check-strings

"$BIN" --render-icon "$BUILD_DIR/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}.png" > /dev/null
  sips -z $((s * 2)) $((s * 2)) "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
# With a fixed identity macOS keeps granted permissions across rebuilds; ad hoc it asks again after every build.
# Create one with scripts/create-signing-identity.sh and pass it: SIGN_IDENTITY="Speicher-Explorer Dev" ./build.sh
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Speicher-Explorer.app
  cp -R "$APP" ~/Applications/
  echo "Installiert: ~/Applications/Speicher-Explorer.app"
else
  echo "Fertig: $APP"
fi
