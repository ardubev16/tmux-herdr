#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/_common.sh"

agent_name=$(new_agent "$1")
_herdr_interactive agent attach "$agent_name"
