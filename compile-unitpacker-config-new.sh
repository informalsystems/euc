#!/bin/sh
# GitHub Actions script to gather configuration from the local config.json file
# and the chain registry on the Internet.
set -eux

# Find (optional) config.json 'network' configuration for custom settings - Output: CHAIN_NAME
DAEMON_NAME="$(echo "$1" | sed 's/^\(.*\)-x.*$/\1/')"
LOCAL_NETWORK_CONFIG="$(jq '.network | map(select(.daemon_name == "'"$DAEMON_NAME"'"))[0]' config.json)"
if [ "$LOCAL_NETWORK_CONFIG" = "null" ]; then
  CHAIN_NAME="$DAEMON_NAME"
else
  CHAIN_NAME="$(echo "$LOCAL_NETWORK_CONFIG" | jq -r '.chain_name')"
  if [ "$CHAIN_NAME" = "null" ]; then
    CHAIN_NAME="$DAEMON_NAME"
  fi
fi

# Get chain registry information - Output ${CHAIN_NAME}_chain.json file
if [ ! -f "${CHAIN_NAME}_chain.json" ]; then
  # In our test environment, wget might be missing.
  if [ -n "${ACT+x}" ]; then
    apt-get install -y wget
  fi
  echo "::debug::Downloading data from chain registry for chain '${CHAIN_NAME}'."
  wget -q -O "${CHAIN_NAME}_chain.json" "https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json" || \
    echo "::warning file=compile-unitpacker-config.sh::Chain registry download for ${CHAIN_NAME} failed or chain not in registry."
  echo "::debug::Download finished."
else
  echo "::debug::Chain file already exists, skipping download."
fi

# 1. Merge local network configuration with the chain registry file.
# 2. Change codebase.git_repo to owner/repo from full URL. (Needed for GitHub actions/checkout.)
if [ "$LOCAL_NETWORK_CONFIG" = "null" ]; then
  COMPILED_NETWORK_CONFIG="${CHAIN_NAME}_chain.json"
else
  echo "$LOCAL_NETWORK_CONFIG" > "${CHAIN_NAME}_local_network_config.json"
  COMPILED_NETWORK_CONFIG="$(jq -s '.[0] * .[1]' "${CHAIN_NAME}_chain.json" "${CHAIN_NAME}_local_network_config.json")"
fi
# Homework: do the string replacement using jq only.
GIT_REPO="$(echo "$COMPILED_NETWORK_CONFIG" | jq -r '.codebase.git_repo' )"
GIT_REPO="${GIT_REPO##https://github.com/}"
GIT_REPO="${GIT_REPO%%/}"
echo "$COMPILED_NETWORK_CONFIG" | jq ".codebase.git_repo=\"${GIT_REPO}\"" > "${CHAIN_NAME}_compiled_network_config.json"

# Overwrite local network configuration with the compiled local+registry configuration.
# Keep only the 'os' and 'network' keys for unitpacker. It will start len(os)*len(network) number of executions.
CONFIG="$(jq -s '{os: .[0].os} + {network: [.[1]]}' config.json "${CHAIN_NAME}_compiled_network_config.json" | tr -d '\n')"
echo "::set-output name=config::$CONFIG"
