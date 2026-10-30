#!/bin/bash
# Signs an app or a disk image, so macOS can tell each build comes from the same developer.
#
# Start:  scripts/sign.sh <app or disk image>   (build.sh and release.sh call it)
# Needs:  SIGN_IDENTITY ("-" or none: ad hoc); the identity from make identity lives in a
#         keychain of its own (SIGNING_KEYCHAIN and its password in local.mk), unlocked here.
set -euo pipefail

# MARK: Settings

TARGET="$1"
IDENTITY="${SIGN_IDENTITY:--}"
AD_HOC="-"

# MARK: Steps

uses_own_keychain() {
  [ -n "${SIGNING_KEYCHAIN:-}" ] && [ "$IDENTITY" != "$AD_HOC" ]
}

unlock_own_keychain() {
  security unlock-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
}

# MARK: Run

main() {
  local options=(--force --sign "$IDENTITY")
  if uses_own_keychain; then
    unlock_own_keychain
    options+=(--keychain "$SIGNING_KEYCHAIN")
  fi
  codesign "${options[@]}" "$TARGET"
}

main "$@"
