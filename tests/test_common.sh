#!/usr/bin/env bash
# Self-check for the debug/error-handling helpers in scripts/_common.sh.
# No tmux/herdr binaries required - both are mocked. Run: ./test_common.sh
set -uo pipefail

fail=0

function assert_contains() {
    local -r desc="$1" haystack="$2" needle="$3" expect="${4:-true}"
    local matched=false
    [[ "$haystack" == *"$needle"* ]] && matched=true
    if [[ "$matched" == "$expect" ]]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        echo "  expected $([[ $expect == true ]] && echo to || echo NOT to) contain: $needle"
        echo "  got: $haystack"
        fail=1
    fi
}

# Sources _common.sh in a throwaway bash subprocess with tmux/herdr mocked
# and stdin pinned to /dev/null, then runs $2. Prints captured stdout+stderr
# followed by "EXIT:<code>" from the *actual* subprocess exit status (not an
# echo from inside, since a trap-triggered exit never reaches later lines).
function run_case() {
    local -r debug="$1" snippet="$2"

    local -r SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts"

    local out
    out=$(MOCK_DEBUG="$debug" bash -c '
        function tmux() {
            [[ "$1" == show-option && "$3" == "@tmux_herdr_debug" ]] && echo "$MOCK_DEBUG"
            return 0
        }
        function herdr() { echo "{\"result\":true}"; }
        . "'"$SCRIPTS_DIR"'/_common.sh"
        '"$snippet"'
    ' </dev/null 2>&1)
    printf '%s\nEXIT:%s\n' "$out" "$?"
}

out=$(run_case off 'false')
assert_contains "debug off: unexpected error gets generic message" "$out" "unexpected error"
assert_contains "debug off: exits 1" "$out" "EXIT:1"

out=$(run_case on 'false')
assert_contains "debug on: unexpected error shows line/command" "$out" "at line"

out=$(run_case on 'function inner() { false; }; inner')
assert_contains "errtrace: failure inside a function still trips the trap" "$out" "at line"

out=$(run_case off 'die "custom problem"')
assert_contains "die(): prints its own message" "$out" "custom problem"
assert_contains "die(): exits 1" "$out" "EXIT:1"

out=$(run_case off 'get_repo_metadata a b c /nonexistent-path-xyz')
assert_contains "soft-fail: still reports Not a git repo" "$out" "Not a git repo."
assert_contains "soft-fail: uncaught call also gets generic trap line (accepted)" "$out" "unexpected error"

out=$(run_case on '_herdr agent list')
assert_contains "debug on: _herdr dumps raw I/O" "$out" "result"

out=$(run_case off '
    function herdr() {
        if [[ "$1" == pane && "$2" == list ]]; then
            echo "{\"result\":{\"panes\":[{\"pane_id\":\"p1\"},{\"pane_id\":\"p2\"}]}}"
        elif [[ "$1" == pane && "$2" == close ]]; then
            echo "{\"id\":\"cli:pane:close\",\"result\":{\"type\":\"ok\"}}"
        fi
    }
    out=$(_cleanup_extra_panes ws1 p1)
    echo "captured=[$out]"
')
assert_contains "_cleanup_extra_panes: pane close result does not leak to stdout" "$out" "cli:pane:close" false
assert_contains "_cleanup_extra_panes: caller sees empty stdout" "$out" "captured=[]"

exit "$fail"
