#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux bind-key h run-shell "$CURRENT_DIR/main.sh agent_dashboard"
tmux bind-key a run-shell "$CURRENT_DIR/main.sh attach_agent"
tmux bind-key N run-shell "$CURRENT_DIR/main.sh new_agent"

# TODO: Add symbols with different colors to bottom bar:
#   - Active agents
#   - Blocked agents
#   - Finished agents
