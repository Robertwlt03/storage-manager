#!/bin/bash
# Creates a self-signed code-signing identity in a keychain of its own (once per Mac).
# build.sh unlocks that keychain and signs with it, so every rebuild keeps the same identity and
# macOS keeps Full Disk Access, without ever asking for the login password or the login keychain.
# The keychain's random password is written to local.mk, which git ignores; it protects only this
# development certificate, and nothing leaves this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Speicher-Explorer Dev"
KEYCHAIN="$HOME/Library/Keychains/speicher-explorer-signing.keychain-db"
SETTINGS=local.mk

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Newer macOS keeps Full Disk Access across rebuilds only for a certificate it trusts for code
# signing; without that trust it ties the grant to each build's exact contents. Trusting it asks
# for the password once, in a regular macOS dialog.
trust_for_code_signing() {
  local certificate="$TMP/certificate.pem"
  security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$certificate"
  if security verify-cert -c "$certificate" -p codeSign > /dev/null 2>&1; then
    echo "macOS already trusts \"$NAME\" for code signing."
    return
  fi
  echo "macOS now asks once for your password to trust \"$NAME\" for code signing."
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$certificate"
}

if [ -f "$KEYCHAIN" ]; then
  echo "The signing keychain already exists: $KEYCHAIN"
  PASSWORD=$(sed -n 's/^SIGNING_KEYCHAIN_PASSWORD *= *//p' "$SETTINGS")
  security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
  trust_for_code_signing
  exit 0
fi

PASSWORD=$(uuidgen)

# A keychain only for this project, which does not lock itself after a while.
security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2> /dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -out "$TMP/identity.p12" -passout pass:"$PASSWORD"

# codesign may use the key without asking: the access list and, on newer macOS, the partition list.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign > /dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" \
  > /dev/null

# Keep whatever else local.mk holds and replace only the signing lines.
touch "$SETTINGS"
grep -v -E '^(SIGN_IDENTITY|SIGNING_KEYCHAIN|SIGNING_KEYCHAIN_PASSWORD) *=' "$SETTINGS" \
  > "$TMP/settings" || true
{
  cat "$TMP/settings"
  echo "SIGN_IDENTITY = $NAME"
  echo "SIGNING_KEYCHAIN = $KEYCHAIN"
  echo "SIGNING_KEYCHAIN_PASSWORD = $PASSWORD"
} > "$SETTINGS"

echo "Signing identity \"$NAME\" created in its own keychain; local.mk now signs with it."
trust_for_code_signing
echo "Grant Full Disk Access to the app once after the next make run."
