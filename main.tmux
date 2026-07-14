#!/usr/bin/env bash

set -e

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -r herdr_status_placeholder='\#{tmux_herdr_status}'

declare -r harness_config='@tmux_herdr_harness'
declare -r split_direction_config='@tmux_herdr_split_direction'

declare -r key_dashboard_config='@tmux_herdr_key_dashboard'
declare -r key_attach_config='@tmux_herdr_key_attach'
declare -r key_new_agent_config='@tmux_herdr_key_new_agent'
declare -r key_new_agent_branch_config='@tmux_herdr_key_new_agent_branch'

declare -r background_config='@tmux_herdr_status_background'
declare -r idle_foreground_config='@tmux_herdr_status_idle_foreground'
declare -r working_foreground_config='@tmux_herdr_status_working_foreground'
declare -r blocked_foreground_config='@tmux_herdr_status_blocked_foreground'

function tmux_option() {
    local -r option=$(tmux show-option -gqv "$1")
    local -r fallback="$2"
    echo "${option:-$fallback}"
}

function init_tmux_herdr() {
    local -r \
        harness=$(tmux_option "$harness_config" "claude") \
        split_direction=$(tmux_option "$split_direction_config" "h") \
        key_dashboard=$(tmux_option "$key_dashboard_config" "h") \
        key_attach=$(tmux_option "$key_attach_config" "a") \
        key_new_agent=$(tmux_option "$key_new_agent_config" "N") \
        key_new_agent_branch=$(tmux_option "$key_new_agent_branch_config" "B")

    tmux bind-key "$key_dashboard" run-shell "$CURRENT_DIR/main.sh agent_dashboard"
    tmux bind-key "$key_attach" run-shell "$CURRENT_DIR/main.sh attach_agent"
    tmux bind-key "$key_new_agent" run-shell "$CURRENT_DIR/main.sh new_agent \"$harness\" \"$split_direction\""
    tmux bind-key "$key_new_agent_branch" run-shell "$CURRENT_DIR/main.sh new_agent_branch \"$harness\" \"$split_direction\""

    "$CURRENT_DIR/scripts/init.sh"
}

function init_tmux_herdr_status() {
    local -r \
        background=$(tmux_option "$background_config" "colour238") \
        idle_foreground=$(tmux_option "$idle_foreground_config" "green") \
        working_foreground=$(tmux_option "$working_foreground_config" "yellow") \
        blocked_foreground=$(tmux_option "$blocked_foreground_config" "red")

    local -r herdr_status="#[default]#[bg=$background]#(\"$CURRENT_DIR/scripts/status_bar.sh\" \"$idle_foreground\" \"$working_foreground\" \"$blocked_foreground\")#[default]"

    local -r status_left_value="$(tmux_option "status-left")"
    tmux set-option -gq "status-left" "${status_left_value/$herdr_status_placeholder/$herdr_status}"

    local -r status_right_value="$(tmux_option "status-right")"
    tmux set-option -gq "status-right" "${status_right_value/$herdr_status_placeholder/$herdr_status}"
}

init_tmux_herdr
init_tmux_herdr_status
