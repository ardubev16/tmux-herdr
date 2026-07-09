#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function _herdr_interactive() {
    HERDR_SESSION=tmux-herdr \
        HERDR_CONFIG_PATH="$CURRENT_DIR/../herdr/config.toml" \
        herdr "$@"
}

function _herdr() {
    local out
    out=$(_herdr_interactive "$@")

    # echo -e "$*\n$(echo "$out" | jq --color-output)\n" >&2
    [[ -z $out ]] && return 1
    echo "$out"
}

function get_repo_metadata() {
    local -n _repo_full_path="$1" _repo_name="$2" _project_name="$3"

    local _git_dir
    _git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || {
        echo "Not a git repo."
        return 1
    }

    _repo_full_path=$(dirname "$_git_dir")
    _repo_name=$(basename "$_repo_full_path")
    _project_name=$(basename "$(dirname "$_repo_full_path")")
}

function select_branch() {
    local fzf_out fzf_exit=0
    branches=$(git branch)
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

function create_workspace() {
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

function create_worktree() {
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

function cleanup_extra_panes() {
    local -r ws_id="$1" pane_id="$2"

    local -a extra_panes
    mapfile -t extra_panes < <(_herdr pane list --workspace "$ws_id" |
        jq --raw-output \
            --arg pane_id "$pane_id" \
            '.result.panes | map(select(.pane_id != $pane_id).pane_id) | .[]')

    for pane in "${extra_panes[@]}"; do
        _herdr pane close "$pane"
    done
}

function start_agent() {
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

        cleanup_extra_panes "$ws_id" "$pane_id"
    fi
}

function select_agent() {
    local -r name="$1"

    local agents
    mapfile -t agents < <(_herdr agent list | jq --raw-output '.result.agents | map(.name) | .[]' | grep "$name")

    [[ ${#agents[@]} == 0 ]] && return 1

    if [[ ${#agents[@]} == 1 ]]; then
        echo "${agents[0]}"
    else
        printf "%s\n" "${agents[@]}" | fzf
    fi
}

function new_agent() {
    local -r harness="$1"

    local repo_full_path repo_name project_name branch_name
    get_repo_metadata repo_full_path repo_name project_name
    branch_name=$(select_branch)

    local -r workspace_name="${project_name}::${repo_name}"
    local -r agent_name="${workspace_name}::${branch_name}"

    local ws_id wt_id
    ws_id=$(create_workspace "$workspace_name" "$repo_full_path")
    wt_id=$(create_worktree "$ws_id" "$branch_name" "$repo_full_path")

    start_agent "$wt_id" "$agent_name" "$repo_full_path" "$harness"

    _herdr agent focus "$agent_name" >/dev/null
}
