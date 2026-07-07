#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/_common.sh"

get_repo_metadata repo_full_path repo_name project_name

agent_name=$(select_agent "${project_name}::${repo_name}")
_herdr_interactive agent attach "$agent_name"
