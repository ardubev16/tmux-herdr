#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s inherit_errexit

declare -r HERDR_SESSION_NAME=tmux-herdr
declare SCRIPTS_DIR
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare debug_enabled=""
[[ "$(tmux show-option -gqv '@tmux_herdr_debug')" == on ]] && debug_enabled=1

function _herdr_pause() {
    [[ -t 0 ]] || return 0
    read -rsn1 -p "Press any key to close this pane..." >&2
    echo >&2
}

function die() {
    echo "$1" >&2
    _herdr_pause
    exit 1
}

function _herdr_err_trap() {
    local -r exit_code=$? line=$1 command=$2

    if [[ -n $debug_enabled ]]; then
        echo "tmux-herdr: error (exit $exit_code) at line $line: $command" >&2
    else
        echo "tmux-herdr: unexpected error (exit $exit_code). Set '@tmux_herdr_debug on' for details." >&2
    fi
    _herdr_pause
    exit "$exit_code"
}
trap '_herdr_err_trap $LINENO "$BASH_COMMAND"' ERR

function _herdr_interactive() {
    HERDR_SESSION="$HERDR_SESSION_NAME" \
        HERDR_CONFIG_PATH="$SCRIPTS_DIR/../herdr/config.toml" \
        herdr "$@"
}

function _herdr() {
    local out
    out=$(_herdr_interactive "$@")

    [[ -n $debug_enabled ]] && echo -e "$*\n$(echo "$out" | jq --color-output)\n" >&2

    [[ -z $out ]] && return 1
    echo "$out"
}

function wait_for_server() {
    local -r max_retries=10

    local session_running="" retries=0
    while [[ $session_running != "true" && $retries -lt $max_retries ]]; do
        session_running=$(_herdr session list --json |
            jq --raw-output \
                --arg name "$HERDR_SESSION_NAME" \
                '.sessions | map(select(.name == $name).running) | .[]')
        retries=$((retries + 1))
        sleep 0.1
    done

    [[ $session_running != "true" ]] && return 1

    return 0
}

function get_repo_metadata() {
    local -n _repo_full_path="$1" _repo_name="$2" _project_name="$3"
    local -r _path="${4:-.}"

    local _git_dir
    _git_dir=$(git -C "$_path" rev-parse --absolute-git-dir 2>/dev/null) || {
        echo "Not a git repo." >&2
        return 1
    }

    _repo_full_path=$(dirname "$_git_dir")
    _repo_name=$(basename "$_repo_full_path")
    _project_name=$(basename "$(dirname "$_repo_full_path")")
}

function select_branch() {
    local -r path="$1"
    local fzf_out fzf_exit=0
    branches=$(git -C "$path" branch)
    fzf_out=$({
        grep '^\*' <<<"$branches"
        grep -v '^\*' <<<"$branches"
    } | fzf --print-query --prompt="⎇ branch: ") || fzf_exit=$?

    # NOTE: Ctrl-C returns 130
    [[ $fzf_exit == 130 ]] && return 130

    local -r query=$(sed -n '1p' <<<"$fzf_out")
    local -r selection=$(sed -n '2p' <<<"$fzf_out")

    local branch_name
    if [[ -n "$selection" ]]; then
        branch_name="${selection:2}"
    else
        branch_name="$query"
    fi

    echo "$branch_name"
}

function _create_workspace() {
    local -r name="$1" path="$2"

    local ws_id
    ws_id=$(_herdr workspace list |
        jq --raw-output \
            --arg label "$name" \
            '.result.workspaces | map(select(.label == $label).workspace_id)[0]')

    if [[ $ws_id == "null" ]]; then
        ws_id=$(_herdr workspace create --label "$name" --cwd "$path" |
            jq --raw-output '.result.workspace.workspace_id')
    fi

    echo "$ws_id"
}

function _create_worktree() {
    local -r ws_id="$1" branch="$2" path="$3"

    local wt_id
    wt_id=$(_herdr worktree list --workspace "$ws_id" |
        jq --raw-output \
            --arg branch "$branch" \
            '.result.worktrees | map(select(.branch == $branch).open_workspace_id)[0]')

    if [[ $wt_id == "null" ]]; then
        local wt_path
        wt_path=$(_herdr worktree list --cwd "$path" |
            jq --raw-output \
                --arg branch "$branch" \
                '.result.worktrees | map(select(.branch == $branch).path)[0]')

        if [[ $wt_path == "null" ]]; then
            wt_id=$(_herdr worktree create --cwd "$path" --branch "$branch" --label "$branch" |
                jq --raw-output '.result.worktree.open_workspace_id')
        else
            wt_id=$(_herdr worktree open --cwd "$path" --path "$wt_path" --label "$branch" |
                jq --raw-output '.result.worktree.open_workspace_id')
        fi
    fi

    echo "$wt_id"
}

function _cleanup_extra_panes() {
    local -r ws_id="$1" pane_id="$2"

    local -a extra_panes
    mapfile -t extra_panes < <(_herdr pane list --workspace "$ws_id" |
        jq --raw-output \
            --arg pane_id "$pane_id" \
            '.result.panes | map(select(.pane_id != $pane_id).pane_id) | .[]')

    for pane in "${extra_panes[@]}"; do
        _herdr pane close "$pane" >/dev/null
    done
}

function _start_agent() {
    local -r ws_id="$1" name="$2" repo_path="$3" harness="$4"

    local pane_id
    pane_id=$(_herdr agent list |
        jq --raw-output \
            --arg name "$name" \
            '.result.agents | map(select(.name == $name).pane_id)[0]')

    if [[ $pane_id == "null" ]]; then
        local cwd
        cwd=$(_herdr workspace list |
            jq --raw-output \
                --arg ws_id "$ws_id" \
                '.result.workspaces | map(select(.workspace_id == $ws_id).worktree.checkout_path)[0]')

        if [[ $cwd == "null" ]]; then
            cwd="$repo_path"
        fi
        pane_id=$(_herdr agent start "$name" --workspace "$ws_id" --cwd "$cwd" -- "$harness" |
            jq --raw-output '.result.agent.pane_id')

        _cleanup_extra_panes "$ws_id" "$pane_id"
    fi
}

function repo_prefix() {
    local -r project_name="$1" repo_name="$2"
    echo "${project_name}::${repo_name}"
}

function new_agent() {
    local -r harness="$1" branch_name="$2"

    local repo_full_path repo_name project_name
    get_repo_metadata repo_full_path repo_name project_name

    local -r workspace_name="$(repo_prefix "$project_name" "$repo_name")"
    local -r agent_name="${workspace_name}::${branch_name}"

    local ws_id wt_id
    ws_id=$(_create_workspace "$workspace_name" "$repo_full_path")
    wt_id=$(_create_worktree "$ws_id" "$branch_name" "$repo_full_path")

    _start_agent "$wt_id" "$agent_name" "$repo_full_path" "$harness"

    _herdr agent focus "$agent_name" >/dev/null

    echo "$agent_name"
}
