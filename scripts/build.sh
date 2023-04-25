#!/bin/sh

# For private git repositories, ssh-agent should already be set up.

# Configurable variables:
# BUILD_DIR - The relative directory where the Go compiler puts the resulting binary. Defaults to 'build'.
# TARGET_DIR - put here the resulting folder structure and files. Defaults to 'target'.
# LEDGER_ENABLED - Ledger device support is enabled in the binary. Defaults to 'true'.
# CGO_ENABLED - Golang parameter to enable C library support. Required for cross-compiling. Defaults to '1'.

# Cross-compiling might work on the same operating system (GOOS) and different architecture (GOARCH).

set -eu

fail() {
  echo "ERROR: $*"
  exit 1
}

test $# = 3 || fail "Usage: $0 <github_repository> <tag> <binary_name>"
REPO_URL="$1"
TAG="$2"
BINARY="$3"
BUILD_DIR="${BUILD_DIR:-build}"
TARGET_DIR="${TARGET_DIR:-target}"
GOOS="$(go env GOOS)"
GOARCH="$(go env GOARCH)"

# Remove trailing /
REPO_URL="${REPO_URL%%/}"
# Remove https://github.com/
REPO_STUB="${REPO_URL##https://github.com/}"
# Remove git@github.com:
REPO_STUB="${REPO_URL##git@github.com:}"
test -n "$(echo "${REPO_STUB}" | grep /)" || fail "cannot parse input repository: no / found"
ORG="$(echo "${REPO_STUB}" | cut -d/ -f1)"
test -n "$ORG" || fail "cannot parse input repository: org/repo not found"
REPO="$(echo "${REPO_STUB}" | cut -d/ -f2-)"
test -z "$(echo "${REPO}" | grep /)" || fail "cannot parse input repository: too many / found"

if [ -z "${RETRY:-}" ]; then
  git clone -b "$TAG" "$REPO_URL" || fail "cannot clone repository: ${REPO_URL}"
else
  git clone -b "$TAG" "$REPO_URL" || echo "cannot clone repository: ${REPO_URL}"
fi

export LEDGER_ENABLED="${LEDGER_ENABLED:-true}" # required 'true' for Ledger device support
export CGO_ENABLED="${CGO_ENABLED:-1}" # required '1' for WASM support
mkdir -p "${TARGET_DIR}/usr/local/bin" "${TARGET_DIR}/usr/local/lib/${BINARY}"

# Build binary and place it in the target folder
if [ -f "build/${BINARY}.sh" ]; then
    # shellcheck source=build/osmosisd.sh
    . "build/${BINARY}.sh"
  else
    test -f "${REPO}/Makefile" || fail "no Makefile found or custom build script found"
    BUILD=2
    make -n -B -C "${REPO}" build || BUILD=1
    if [ "$BUILD" -eq 1 ]; then
      make -n -B -C "${REPO}" install || BUILD=0
    fi
    case "$BUILD" in
      2)
        make -B -C "${REPO}" build || fail "make build failed"
        test -d "${REPO}/${BUILD_DIR}" || fail "make build did not produce build folder"
        test -x "${REPO}/${BUILD_DIR}/${BINARY}" || fail "could not find built binary after running make build"
        mv "${REPO}/${BUILD_DIR}/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}"
        ;;
      1)
        make -B -C "${REPO}" install || fail "make install failed."
        test -x "${GOPATH}/bin/go/${BINARY}" || fail "could not find built binary after running make install"
        mv "${GOPATH}/bin/go/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}"
        ;;
      0)
        make -B -C "${REPO}"
        if [ -x "${REPO}/${BUILD_DIR}/${BINARY}" ]; then
          mv "${REPO}/${BUILD_DIR}/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}"
        else
          if [ -x "${GOPATH}/bin/go/${BINARY}" ]; then
            mv "${GOPATH}/bin/go/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}"
          else
            fail "could not find built binary after running make"
          fi
        fi
        ;;
      *)
        fail "invalid Makefile test"
        ;;
    esac
fi

# Get WASMVM dependency.
WASMVM_JSON="$(cd "${REPO}" && go list -json -m github.com/CosmWasm/wasmvm 2> /dev/null || echo "NotFound")"
if [ "${WASMVM_JSON}" = "NotFound" ]; then
  echo "No WASMVM library found in the dependencies."
else
  VERSION="$(echo "${WASMVM_JSON}" | jq -r .Version)"
  WASMVM_DIR="$(echo "${WASMVM_JSON}" | jq -r .Dir)"
  echo "WASMVM version ${VERSION} found in directory ${WASMVM_DIR}."
  WASMVM_SEARCH_PATH="${WASMVM_DIR}"
  if [ -d "${WASMVM_DIR}/internal/api" ]; then
    WASMVM_SEARCH_PATH="${WASMVM_DIR}/internal/api"
  else
    if [ -d "${WASMVM_DIR}/api" ]; then
      WASMVM_SEARCH_PATH="${WASMVM_DIR}/api"
    fi
  fi
  case "$GOOS" in
    "darwin")
      # Details: https://developer.apple.com/documentation/xcode/embedding-nonstandard-code-structures-in-a-bundle
      install_name_tool -add_rpath "@executable_path/../lib/${BINARY}" "${TARGET_DIR}/usr/local/bin/${BINARY}"
      find "${WASMVM_SEARCH_PATH}" -name 'libwasmvm*.dylib' -type f -exec cp "{}" "${TARGET_DIR}/usr/local/lib/${BINARY}/" \;
      ;;
    "linux")
      find "${WASMVM_SEARCH_PATH}" -name 'libwasmvm*.so' -type f -exec cp "{}" "${TARGET_DIR}/usr/local/lib/${BINARY}/" \;
      ;;
    *)
      fail "unsupported operating system ${GOOS}"
      ;;
  esac
fi
echo "BUILT ${GOOS}/${GOARCH} $BINARY $TAG."
