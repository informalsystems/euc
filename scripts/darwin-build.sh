#!/bin/sh

# For private git repositories, ssh-agent should already be set up.

# Configurable variables:
# BUILD_DIR - The relative directory where the Go compiler puts the resulting binary. Defaults to 'build'.
# TARGET_DIR - put here the resulting folder structure and files. Defaults to 'target'.

set -eu

fail() {
  echo "ERROR: $*"
  exit 1
}

test $# = 3 || fail "Usage: $0 <github_repository> <tag> <binary_name>"
#REPO_URL="$1"
#TAG="$2"
BINARY="$3"
BUILD_DIR="${BUILD_DIR:-build}"
TARGET_DIR="${TARGET_DIR:-target}"
GOOS="$(go env GOOS)"
GOARCH="$(go env GOARCH)"

test "$(uname -s)" = "Darwin" || fail "this script will only work on MacOS"
test "$GOOS" = "darwin" || fail "this script will only build for MacOS"

# Build amd64 and arm64 versions
MY_DIR="$(dirname "$0")"
GOARCH=amd64 "${MY_DIR}/build.sh" "$@"
mv "${TARGET_DIR}/usr/local/bin/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}_amd64"
GOARCH=arm64 "${MY_DIR}/build.sh" "$@"
mv "${TARGET_DIR}/usr/local/bin/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}_arm64"

# Merge binaries
lipo -create "${TARGET_DIR}/usr/local/bin/${BINARY}_amd64" "${TARGET_DIR}/usr/local/bin/${BINARY}_arm64" -output "${TARGET_DIR}/usr/local/bin/${BINARY}"
rm "${TARGET_DIR}/usr/local/bin/${BINARY}_amd64" "${TARGET_DIR}/usr/local/bin/${BINARY}_arm64"

echo "Finished MacOS binary."
