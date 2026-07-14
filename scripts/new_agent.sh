#!/usr/bin/env bash

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

agent_name=$(new_agent "$1" "$2")
_herdr_interactive agent attach "$agent_name"
