#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/_common.sh"

MINIMUM_HERDR_VERSION="0.7.1"

function check_minimum_herdr_version() {
    # src: https://gist.github.com/jonlabelle/6691d740f404b9736116c22195a8d706
    function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

    local herdr_version
    herdr_version=$(_herdr --version | awk '{print $2}')

    if version_lt "$herdr_version" "$MINIMUM_HERDR_VERSION"; then
        echo "Herdr version $herdr_version is too old. Minimum supported version: $MINIMUM_HERDR_VERSION"
        exit 1
    fi
}

# HACK: This is a workaround since at the time of writing there doesn't seem to
# be a way to start a server in the background in a headless way.
function init_herdr_session() {
    _herdr 2>/dev/null &
    pid="$!"
    # NOTE: If in interactive mode reset the terminal before something breaks
    # from the weird TUI that tries to spawn. Useful for debugging.
    [[ $- == *i* ]] && reset

    wait_for_herdr_server
    kill -9 "$pid"

    _herdr server reload-config
}

check_minimum_herdr_version
init_herdr_session
