#!/bin/bash
# Stops with a hint when the tools point to the Command Line Tools instead of Xcode: SwiftUI's
# macros for macOS 27 ship only with Xcode. build.sh and scripts/check.py both ask here.
if [[ "${DEVELOPER_DIR:-$(xcode-select --print-path)}" != *Xcode* ]]; then
  echo "Xcode 27 is needed. Install it, then switch once:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi
