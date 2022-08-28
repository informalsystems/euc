#!/bin/sh
# GitHub Actions script to create the installation package content for macOS packages.
set -eux

INPUT="${1:-cosmos-v0.0.0}"
export COSMOS_VERSION="${INPUT##cosmos-}"
BINARY_NUMBER="$(jq -r '.package|length' config.json)"

NAMES_COMMA_SEPARATED=""
for i in $(seq 0 $((BINARY_NUMBER - 1)));
do
  PACKAGE="$(jq '.package['"$i"']' config.json)"
  NAME="$(echo "$PACKAGE" | jq -r .name)"
  BUILD="$(echo "$PACKAGE" | jq -r .build)"
  VERSION="$(echo "$PACKAGE" | jq -r .version)"
  LINK="https://github.com/informalsystems/euc/releases/download/${NAME}-${BUILD}/${NAME}_${VERSION}_mac.pkg"
  echo "Getting $LINK"
  wget -q -O "${NAME}_${VERSION}_mac.pkg" "$LINK"
  NAMES_COMMA_SEPARATED="${NAMES_COMMA_SEPARATED},${NAME}"
done
export BINARIES="${NAMES_COMMA_SEPARATED##,}"

cp LICENSE Resources/LICENSE

wget -q -O stemplate https://github.com/freshautomations/stemplate/releases/download/v0.6.1/stemplate_darwin_amd64
chmod 755 stemplate
./stemplate Distribution.template --string COSMOS_VERSION --list BINARIES --output Distribution

cat Distribution
