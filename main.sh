#!/usr/bin/env bash

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/_common.sh"

function agent_dashboard() {
    # TODO: implement toggle
    tmux display-popup -w 90% -h 90% -E "$SCRIPTS_DIR/agent_dashboard.sh"
}

function attach_agent() {
    # TODO: check if agent is running for this repo
    # TODO: handle graceful panel close (leader+x ??)
    # TODO: handle different cases:
    #   - horizontal split
    #   - vertical split
    #   - use focused pane
    tmux split-window -h "$SCRIPTS_DIR/attach_agent.sh"
}

function shell_basename() {
    basename "$(tmux show-option -gqv default-shell)"
}

function find_shell_pane() {
    local -r default_shell="$1"
    tmux list-panes -F '#{pane_id} #{pane_current_command}' |
        awk -v shell="$default_shell" '$2 == shell { print $1; exit }'
}

function _spawn_new_agent() {
    local -r harness="$1" split_direction="$2" branch_name="$3"
    local -r default_shell="$(shell_basename)"

    local focused_pane focused_command
    read -r focused_pane focused_command <<<"$(tmux display-message -p '#{pane_id} #{pane_current_command}')"

    local target_pane
    if [[ "$focused_command" == "$default_shell" ]]; then
        target_pane="$focused_pane"
    else
        target_pane=$(find_shell_pane "$default_shell")
    fi

    if [[ -n "$target_pane" ]]; then
        tmux select-pane -t "$target_pane"
        tmux send-keys -t "$target_pane" "$CURRENT_DIR/scripts/new_agent.sh '$harness' '$branch_name'" Enter
    else
        local -r pane_path="$(tmux display-message -p -t "$focused_pane" '#{pane_current_path}')"
        tmux split-window -c "$pane_path" "-$split_direction" "$CURRENT_DIR/scripts/new_agent.sh" "$harness" "$branch_name"
    fi
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
    # TODO: Two keybindings for start and attach:
    # 1. leader+B -> fzf branches -> agent
    # 2. leader+N -> agent with current branch
    new_agent "$@"
    ;;
    ;;
*)
    exit 1
    ;;
esac
