#!/bin/sh
# GitHub Actions script to gather configuration from the local config.json file
# and the chain registry on the Internet.
set -eu

# Find (optional) config.json 'network' configuration for custom settings - Output: CHAIN_NAME
DAEMON_NAME="$(echo "$1" | cut -d- -f1)"
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
  wget -q -O "${CHAIN_NAME}_chain.json" "https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
  echo "::debug::Download finished without errors."
else
  echo "::debug::Chain file already exists, skipping download."
fi

# Merge local network configuration with the chain registry file
if [ "$LOCAL_NETWORK_CONFIG" = "null" ]; then
  COMPILED_NETWORK_CONFIG="${CHAIN_NAME}_chain.json"
else
  echo "$LOCAL_NETWORK_CONFIG" > "${CHAIN_NAME}_local_network_config.json"
  COMPILED_NETWORK_CONFIG="$(jq -s '.[0] * .[1]' "${CHAIN_NAME}_chain.json" "${CHAIN_NAME}_local_network_config.json")"
fi
echo "$COMPILED_NETWORK_CONFIG" > "${CHAIN_NAME}_compiled_network_config.json"

# Overwrite local network configuration with the compiled local+registry configuration.
CONFIG="$(jq -s '.[0] + {network: [.[1]]}' config.json "${CHAIN_NAME}_compiled_network_config.json" | tr -d '\n')"
echo "::set-output name=config::$CONFIG"
