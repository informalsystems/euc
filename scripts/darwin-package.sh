#!/bin/sh

# Secrets for local execution:
# - Developer ID Application certificate, private key and CA certificate in the Apple Keychain
# - Developer ID Installer certificate and private key in the Apple Keychain
# (GitHub has these in its secrets store and deploys them as needed.)

# Configurable variables:
# SOURCE_DIR - the folder that will be packaged. Defaults to 'target'.
# PACKAGE - the output package name. Defaults to ${BINARY_NAME}_${VERSION}_mac.pkg based on the input parameters.
# MAC_APP_CERTIFICATE_CN - Common Name on the Application certificate.
# MAC_INST_CERTIFICATE_CN - Common Name on the Installer certificate.

set -eu

fail() {
  echo "ERROR: $*"
  exit 1
}

test $# -eq 2 || fail "Usage: $0 <BINARY_NAME> <VERSION>"
test -n "$(which stemplate)" || fail "stemplate required: https://github.com/freshautomations/stemplate/releases"
export BINARY_NAME="${1}"
export VERSION="${2}"

SOURCE_DIR="${SOURCE_DIR:-target}"
SOURCE_DIR="${SOURCE_DIR%%/}"
PACKAGE="${PACKAGE:-${BINARY_NAME}_${VERSION}_mac}.pkg"
MAC_APP_CERTIFICATE_CN="${MAC_APP_CERTIFICATE_CN:-Developer ID Application: Cephalopod Equipment Corp (7H8VTXM3P2)}"
MAC_INST_CERTIFICATE_CN="${MAC_INST_CERTIFICATE_CN:-Developer ID Installer: Cephalopod Equipment Corp (7H8VTXM3P2)}"

# Sign files
find "${SOURCE_DIR}" -type f | while IFS= read -r file
do
  # Only sign Darwin binary files (executables and libraries)
  test -n "$(file -b "$file" | grep "^Mach-O")" || continue
  # Sign file
  if [ -z "${RETRY:-}" ]; then
    codesign --timestamp -o runtime --sign "$MAC_APP_CERTIFICATE_CN" -v "$file"
  else
    codesign --timestamp -o runtime --sign "$MAC_APP_CERTIFICATE_CN" -v "$file" || echo "Skipping, ${file}..."
  fi
  codesign -v "$file"
done

# Build and sign package
stemplate "$(dirname "$0")/Info.plist.template" --string BINARY_NAME,VERSION --output "${SOURCE_DIR}/usr/local/lib/${BINARY_NAME}/Info.plist"
pkgbuild --root "${SOURCE_DIR}" "$PACKAGE" --timestamp --sign "$MAC_INST_CERTIFICATE_CN"
