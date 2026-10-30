#!/bin/bash
# Stops with a hint when the developer tools point to the Command Line Tools instead of Xcode,
# because SwiftUI's macros for macOS 27 ship only with Xcode.
#
# Start:  scripts/require-xcode.sh   (build.sh and scripts/check.py call it)
# Needs:  nothing
set -euo pipefail

# MARK: Settings

DEVELOPER_FOLDER="${DEVELOPER_DIR:-$(xcode-select --print-path)}"  # DEVELOPER_DIR: Apple's name

# MARK: Run

main() {
  if [[ "$DEVELOPER_FOLDER" != *Xcode* ]]; then
    echo "Xcode 27 is needed. Install it, then switch once:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app"
    exit 1
  fi
}

main "$@"
