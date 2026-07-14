#!/usr/bin/env bash

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

function get_agent_counts() {
    _herdr agent list |
        jq --raw-output 'reduce .result.agents[].agent_status as $status ({}; .[$status] += 1) |
            ((.idle // 0) + (.done // 0)),
            (.working // 0),
            (.blocked // 0)' | xargs
}

function render_status_bar() {
    local -r idle_foreground="$1" working_foreground="$2" blocked_foreground="$3"

    local idle_count working_count blocked_count
    read -r idle_count working_count blocked_count <<<"$(get_agent_counts)"

    local -r \
        idle="#[fg=$idle_foreground] ⦿ $idle_count " \
        working="#[fg=$working_foreground] ⦿ $working_count " \
        blocked="#[fg=$blocked_foreground] ⦿ $blocked_count "

    echo "$idle$working$blocked"
}

render_status_bar "$@"
