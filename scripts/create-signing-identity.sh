#!/bin/bash
# Creates a self-signed code-signing identity in a keychain of its own, once per Mac, so every
# rebuild keeps the same identity and macOS keeps Full Disk Access.
#
# Start:  make identity
# Needs:  nothing; macOS asks for your password once, to trust the certificate for code signing.
# The keychain's random password goes to local.mk, which git ignores; it protects only this
# development certificate, and nothing leaves this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/console.sh

# MARK: Settings

IDENTITY_NAME="Speicher-Explorer Dev"
KEYCHAIN="$HOME/Library/Keychains/speicher-explorer-signing.keychain-db"
SETTINGS_FILE=local.mk
VALID_DAYS=3650  # ten years
KEY_BITS=2048
WORK_FOLDER=$(mktemp -d)
trap 'rm -rf "$WORK_FOLDER"' EXIT  # the key files never stay on disk

# MARK: Steps

unlock_existing_keychain() {
  local password
  password=$(sed -n 's/^SIGNING_KEYCHAIN_PASSWORD *= *//p' "$SETTINGS_FILE")
  security unlock-keychain -p "$password" "$KEYCHAIN"
}

create_keychain() {
  local password=$1
  security create-keychain -p "$password" "$KEYCHAIN"
  security set-keychain-settings "$KEYCHAIN"  # without options: it never locks itself
}

create_certificate() {
  local password=$1
  cat > "$WORK_FOLDER/certificate.conf" <<CONFIGURATION
[req]
distinguished_name = name
x509_extensions = usage
prompt = no
[name]
CN = $IDENTITY_NAME
[usage]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CONFIGURATION
  /usr/bin/openssl req -x509 -newkey "rsa:$KEY_BITS" -nodes -days "$VALID_DAYS" \
    -config "$WORK_FOLDER/certificate.conf" \
    -keyout "$WORK_FOLDER/key.pem" -out "$WORK_FOLDER/certificate.pem" 2> /dev/null
  # Key and certificate together as one identity, the form the keychain imports.
  /usr/bin/openssl pkcs12 -export -name "$IDENTITY_NAME" \
    -inkey "$WORK_FOLDER/key.pem" -in "$WORK_FOLDER/certificate.pem" \
    -out "$WORK_FOLDER/identity.p12" -passout pass:"$password"
}

import_identity() {
  local password=$1
  # codesign may use the key without asking: the access list (-T) and the partition list.
  security import "$WORK_FOLDER/identity.p12" -k "$KEYCHAIN" -P "$password" \
    -T /usr/bin/codesign > /dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$KEYCHAIN" \
    > /dev/null
}

write_settings() {
  local password=$1
  touch "$SETTINGS_FILE"
  # Keep whatever else local.mk holds and replace only the signing lines.
  grep -v -E '^(SIGN_IDENTITY|SIGNING_KEYCHAIN|SIGNING_KEYCHAIN_PASSWORD) *=' "$SETTINGS_FILE" \
    > "$WORK_FOLDER/settings" || true
  cat "$WORK_FOLDER/settings" - > "$SETTINGS_FILE" <<SETTINGS
SIGN_IDENTITY = $IDENTITY_NAME
SIGNING_KEYCHAIN = $KEYCHAIN
SIGNING_KEYCHAIN_PASSWORD = $password
SETTINGS
  console_passed "Settings written" "$SETTINGS_FILE"
}

# Newer macOS keeps Full Disk Access across rebuilds only for a certificate it trusts for code
# signing; without that trust it ties the grant to each build's exact contents.
trust_for_code_signing() {
  local certificate="$WORK_FOLDER/trusted.pem"
  security find-certificate -c "$IDENTITY_NAME" -p "$KEYCHAIN" > "$certificate"
  if security verify-cert -c "$certificate" -p codeSign > /dev/null 2>&1; then
    console_passed "Trusted for code signing" "$IDENTITY_NAME"
    return
  fi
  console_step "macOS now asks once for your password" "to trust $IDENTITY_NAME for code signing"
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$certificate"
  console_passed "Trusted for code signing" "$IDENTITY_NAME"
}

# MARK: Run

main() {
  console_heading "Speicher-Explorer · signing identity" "$IDENTITY_NAME"
  if [ -f "$KEYCHAIN" ]; then
    console_step "The signing keychain already exists" "$KEYCHAIN"
    unlock_existing_keychain
    trust_for_code_signing
    return
  fi
  local password
  password=$(uuidgen)
  create_keychain "$password"
  create_certificate "$password"
  import_identity "$password"
  write_settings "$password"
  console_passed "Identity created" "in its own keychain"
  trust_for_code_signing
  console_frame success "Signing identity ready" "local.mk signs with it" \
    "Grant Full Disk Access to the app once after the next make run"
}

main "$@"
