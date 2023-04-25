#!/bin/sh

# Secrets for local execution:
# - GPG Agent set up with private key
# (GitHub has these in its secrets store and deploys them as needed.)

# Configurable variables:
# SOURCE_DIR - the folder that will be packaged. Defaults to 'target'.
# PACKAGE - the output package name. Defaults to ${BINARY_NAME}_${VERSION}_linux.zip based on the input parameters.

set -eu

fail() {
  echo "ERROR: $*"
  exit 1
}

test $# -eq 2 || fail "Usage: $0 <BINARY_NAME> <VERSION>"
export BINARY_NAME="${1}"
export VERSION="${2}"

SOURCE_DIR="${SOURCE_DIR:-target}"
SOURCE_DIR="${SOURCE_DIR%%/}"
PACKAGE="${PACKAGE:-${BINARY_NAME}_${VERSION}_linux}.zip"

#test "$(uname -s)" = "Linux" || fail "this script will only work on Linux"

# Sign files
find "${SOURCE_DIR}" -type f | while IFS= read -r file
do
  gpg --detach-sign --armor "$file"
  gpg --verify "${file}.asc"
done

# Build and sign package
# shellcheck disable=SC2046
zip -j "$PACKAGE" $(find "${SOURCE_DIR}" -type f)
gpg --detach-sign --armor "$PACKAGE"
gpg --verify "${PACKAGE}.asc"
