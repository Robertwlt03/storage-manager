#!/bin/bash
# Signs the given app or disk image with SIGN_IDENTITY ("-" or none: ad hoc). The identity from
# make identity lives in a keychain of its own (SIGNING_KEYCHAIN in local.mk), unlocked here first.
set -euo pipefail

IDENTITY="${SIGN_IDENTITY:--}"
ARGUMENTS=(--force --sign "$IDENTITY")
if [ -n "${SIGNING_KEYCHAIN:-}" ] && [ "$IDENTITY" != "-" ]; then
  security unlock-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
  ARGUMENTS+=(--keychain "$SIGNING_KEYCHAIN")
fi
codesign "${ARGUMENTS[@]}" "$1"
