#!/bin/bash
# Builds Speicher-Explorer.app into $BUILD_DIR (default: build). With --install it also copies it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

# SwiftUI's macros for macOS 27 ship only with Xcode, not with the Command Line Tools.
if [[ "${DEVELOPER_DIR:-$(xcode-select --print-path)}" != *Xcode* ]]; then
  echo "Xcode 27 is needed. Install it, then switch once: sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi

swift build -c release
BIN=.build/release/SpeicherExplorer

BUILD_DIR="${BUILD_DIR:-build}"
APP="$BUILD_DIR/Speicher-Explorer.app"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
# A build with another bundle identifier (the demo) gets its own permissions and settings, so it
# never takes over the Full Disk Access of the signed app.
if [ -n "${BUNDLE_ID:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
fi
cp -R Resources/*.lproj "$APP/Contents/Resources/"

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
  echo "Installed: ~/Applications/Speicher-Explorer.app"
else
  echo "Done: $APP"
fi
