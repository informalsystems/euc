#!/bin/sh

# Secrets for local execution:
# - App Store Connect API private key in the file 'private.key'. (Configurable file name.)
# (GitHub has these in its secrets store and deploys them as needed.)

# Configurable variables:
# MAC_STORE_KEY - Path to the App Store Connect API private key file. Defaults to 'private.key'.
# MAC_STORE_KEY_ID - App Store Connect API Key ID.
# MAC_STORE_KEY_ISSUER - App Store Connect API Key Issuer.

set -eu

fail() {
  echo "ERROR: $*"
  exit 1
}

test $# -eq 1 || fail "Usage: $0 <PACKAGE>"
PACKAGE="${1}"

MAC_STORE_KEY="${MAC_STORE_KEY:-private.key}"
MAC_STORE_KEY_ID="${MAC_STORE_KEY_ID:-C9K4QDD7R2}"
MAC_STORE_KEY_ISSUER="${MAC_STORE_KEY_ISSUER:-f929b2b3-9fe7-449f-9d8a-036ab57f629c}"

# Notarize package
echo "Notarizing package ${PACKAGE}..."
OUT="$(xcrun notarytool submit "$PACKAGE" --wait -f json --key "${MAC_STORE_KEY}" --key-id "${MAC_STORE_KEY_ID}" --issuer "${MAC_STORE_KEY_ISSUER}")"
if [ -n "$OUT" ]; then
  echo "$OUT"
  STATUS="$(echo "$OUT" | jq -r .status)"
  ID="$(echo "$OUT" | jq -r .id)"
  test "$STATUS" = "Accepted" || fail "Notarization not accepted."
  LOG="$(xcrun notarytool log "$ID" --key "${MAC_STORE_KEY}" --key-id "${MAC_STORE_KEY_ID}" --issuer "${MAC_STORE_KEY_ISSUER}")"
  echo "$LOG"
  ISSUES="$(echo "$LOG" | jq -r .issues)"
  test "$ISSUES" = "null" || fail "Notarization log shows issues."
else
  echo "Notarization did not return anything. Skipping to stapling."
fi

# Staple package
xcrun stapler staple "$PACKAGE"
xcrun stapler validate "$PACKAGE"
