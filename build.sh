#!/bin/bash
# Builds build/Speicher-Explorer.app. With --install it also copies the app to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=.build/release/SpeicherExplorer
"$BIN" --check-contrast > /dev/null || { "$BIN" --check-contrast | grep FAIL; exit 1; }

APP=build/Speicher-Explorer.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

"$BIN" --render-icon build/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" > /dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Speicher-Explorer.app
  cp -R "$APP" ~/Applications/
  echo "Installiert: ~/Applications/Speicher-Explorer.app"
else
  echo "Fertig: $APP"
fi
