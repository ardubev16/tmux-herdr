#!/usr/bin/env bash

set -eou pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function agent_dashboard() {
    # TODO: implement toggle
    tmux display-popup -w 90% -h 90% -E "$CURRENT_DIR/scripts/agent_dashboard.sh"
}

function attach_agent() {
    # TODO: check if agent is running for this repo
    # TODO: handle graceful panel close (leader+x ??)
    # TODO: handle different cases:
    #   - horizontal split
    #   - vertical split
    #   - use focused pane
    tmux split-window -h "$CURRENT_DIR/scripts/attach_agent.sh"
}

function new_agent() {
    true
    # TODO: Implement
}

if [[ $# -lt 1 ]]; then
    exit 1
fi

command="$1"
shift

case "$command" in
agent_dashboard)
    agent_dashboard "$@"
    ;;
attach_agent)
    attach_agent "$@"
    ;;
new_agent)
    new_agent "$@"
    ;;
agents_status)
    "$CURRENT_DIR/scripts/agents_status.sh" "$@"
    ;;
*)
    exit 1
    ;;
esac
