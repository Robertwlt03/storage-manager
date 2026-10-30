#!/bin/bash
# Builds Speicher-Explorer.app with its icon, translations and signature.
#
# Start:  make build, or ./build.sh --install to copy the app to ~/Applications as well
# Needs:  Xcode 27; settings come from the environment (the Makefile passes them on):
#         BUILD_FOLDER (default: build), BUNDLE_ID (another identifier, as for the demo)
#         and SIGN_IDENTITY (default: ad hoc, see scripts/sign.sh)
set -euo pipefail
cd "$(dirname "$0")"
. scripts/console.sh

# MARK: Settings

BUILD_FOLDER="${BUILD_FOLDER:-build}"
APP="$BUILD_FOLDER/Speicher-Explorer.app"
BINARY=".build/release/SpeicherExplorer"
ICON_PICTURE="$BUILD_FOLDER/icon.png"
ICON_SET="$BUILD_FOLDER/AppIcon.iconset"
# The sizes in points macOS asks for in an app icon; each one also comes twice as large for
# Retina screens.
ICON_SIZES=(16 32 128 256 512)
INSTALLED_APP=~/Applications/Speicher-Explorer.app

# MARK: Steps

compile() {
  scripts/require-xcode.sh
  console_step "Compiling" "release; errors appear below"
  swift build --configuration release --quiet
  console_passed "Compiled" "release"
}

assemble_app() {
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp "$BINARY" "$APP/Contents/MacOS/"
  cp Info.plist "$APP/Contents/"
  cp -R Resources/*.lproj "$APP/Contents/Resources/"
  # A build with another bundle identifier (the demo) gets its own permissions and settings, so
  # it never takes over the Full Disk Access of the signed app.
  if [ -n "${BUNDLE_ID:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
  fi
  console_passed "Put together" "${BUNDLE_ID:-the identifier from Info.plist}"
}

add_icon() {
  "$BINARY" --render-icon "$ICON_PICTURE"  # the app draws its own icon with SwiftUI
  rm -rf "$ICON_SET"
  mkdir -p "$ICON_SET"
  for size in "${ICON_SIZES[@]}"; do
    scale_icon "$size" "icon_${size}x${size}.png"
    scale_icon $((size * 2)) "icon_${size}x${size}@2x.png"
  done
  iconutil --convert icns "$ICON_SET" --output "$APP/Contents/Resources/AppIcon.icns"
  console_passed "Icon drawn" "${#ICON_SIZES[@]} sizes, each also for Retina"
}

scale_icon() {
  local pixels=$1 file_name=$2
  sips --resampleHeightWidth "$pixels" "$pixels" "$ICON_PICTURE" --out "$ICON_SET/$file_name" \
    > /dev/null
}

install_when_asked() {
  if [ "${1:-}" = "--install" ]; then
    mkdir -p ~/Applications
    rm -rf "$INSTALLED_APP"
    cp -R "$APP" ~/Applications/
    console_frame success "$PASSED_MARK Installed: $INSTALLED_APP"
  else
    console_frame success "$PASSED_MARK Built: $APP"
  fi
}

# MARK: Run

main() {
  console_heading "Speicher-Explorer · build" "$APP"
  compile
  assemble_app
  add_icon
  # With a fixed identity macOS keeps granted permissions across rebuilds; ad hoc it asks again
  # after every build. make identity creates one and writes it to local.mk.
  scripts/sign.sh "$APP"
  install_when_asked "$@"
}

main "$@"
