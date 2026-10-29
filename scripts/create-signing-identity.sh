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

if [ -f "$KEYCHAIN" ]; then
  echo "The signing keychain already exists: $KEYCHAIN"
  echo "To start over, delete it in Keychain Access and run this again."
  exit 0
fi

PASSWORD=$(uuidgen)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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
echo "Grant Full Disk Access to the app once after the next make run."
