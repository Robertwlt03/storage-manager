#!/bin/bash
# Creates a local, self-signed code-signing identity in the login keychain (once per Mac).
# build.sh signs with it, so every rebuild keeps the same identity and macOS keeps the granted permissions
# instead of asking again after each build. The certificate never leaves this Mac.
set -euo pipefail
NAME="${1:-Speicher-Explorer Dev}"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "Signing identity \"$NAME\" already exists."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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
PASS=$(uuidgen)
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -out "$TMP/identity.p12" -passout pass:"$PASS"
security import "$TMP/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign > /dev/null
echo "Signing identity \"$NAME\" created."
