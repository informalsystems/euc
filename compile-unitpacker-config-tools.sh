#!/bin/sh
# GitHub Actions script to gather configuration from the local config.json file
set -eux

# Find tool configuration from config.json - Output: TOOL_CONFIG 
TOOL_NAME="$(echo "$1" | sed 's/^\(.*\)-v.*$/\1/')"
TOOL_CONFIG="$(jq '.tools | map(select(.name == "'"$TOOL_NAME"'"))[0]' config.json)"
echo "$TOOL_CONFIG" > "${TOOL_NAME}_config.json"

# Get the 'os' and 'tool' for unitpacker.
CONFIG="$(jq -s '{os: .[0].os} + {tools: [.[1]]}' config.json "${TOOL_NAME}_config.json" | tr -d '\n')"
echo "::set-output name=config::$CONFIG"
