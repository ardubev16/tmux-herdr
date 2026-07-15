#!/usr/bin/env bash

set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/_common.sh"

declare -r agent_pane_option='@herdr_agent_name'

function agent_dashboard() {
    tmux display-popup -w 90% -h 90% -E "$SCRIPTS_DIR/agent_dashboard.sh"
}

function shell_basename() {
    basename "$(tmux show-option -gqv default-shell)"
}

function find_pane_by() {
    local -r format="$1" value="$2"
    tmux list-panes -F "#{pane_id} #{$format}" |
        awk -v val="$value" '$2 == val { print $1; exit }'
}

function _repo_prefix() {
    local -r pane_path="$1"
    local repo_full_path repo_name project_name
    get_repo_metadata repo_full_path repo_name project_name "$pane_path" 2>/dev/null || return 0
    repo_prefix "$project_name" "$repo_name"
}

function _spawn_new_agent() {
    local -r harness="$1" split_direction="$2" branch_name="$3"

    local focused_pane focused_command pane_path
    read -r focused_pane focused_command pane_path <<<"$(tmux display-message -p '#{pane_id} #{pane_current_command} #{pane_current_path}')"

    local -r prefix="$(_repo_prefix "$pane_path")"
    local -r agent_name="${prefix}::${branch_name}"

    local -r existing_pane="$(find_pane_by "$agent_pane_option" "$agent_name")"
    if [[ -n "$existing_pane" ]]; then
        tmux select-pane -t "$existing_pane"
        return 0
    fi

    local -r default_shell="$(shell_basename)"

    local target_pane
    if [[ "$focused_command" == "$default_shell" ]]; then
        target_pane="$focused_pane"
    else
        target_pane=$(find_pane_by "pane_current_command" "$default_shell")
    fi

    if [[ -n "$target_pane" ]]; then
        tmux select-pane -t "$target_pane"
        tmux respawn-pane -k -t "$target_pane" "$SCRIPTS_DIR/new_agent.sh" "$harness" "$branch_name"
    else
        target_pane="$(tmux split-window -P -F '#{pane_id}' -c "$pane_path" "-$split_direction" "$SCRIPTS_DIR/new_agent.sh" "$harness" "$branch_name")"
    fi
    tmux set-option -p -t "$target_pane" "$agent_pane_option" "$agent_name"
}

function new_agent() {
    local -r harness="$1" split_direction="$2"
    local -r branch_name="$(git -C "$(tmux display-message -p '#{pane_current_path}')" branch --show-current)"
    _spawn_new_agent "$harness" "$split_direction" "$branch_name"
}

function new_agent_branch() {
    local -r harness="$1" split_direction="$2"

    local -r current_path=$(tmux display-message -p '#{pane_current_path}')
    local -r tmpfile="$(mktemp)"

    local popup_exit=0
    tmux display-popup -E "$SCRIPTS_DIR/select_branch.sh '$current_path' '$tmpfile'" || popup_exit=$?

    local -r branch_name="$(<"$tmpfile")"
    rm -f "$tmpfile"

    [[ "$popup_exit" == 130 || -z "$branch_name" ]] && return 0

    _spawn_new_agent "$harness" "$split_direction" "$branch_name"
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
new_agent)
    new_agent "$@"
    ;;
new_agent_branch)
    new_agent_branch "$@"
    ;;
*)
    exit 1
    ;;
esac
