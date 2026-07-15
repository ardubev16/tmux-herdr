#!/usr/bin/env bash
# Self-check for the debug/error-handling helpers in scripts/_common.sh.
# No tmux/herdr binaries required - both are mocked. Run: ./test_common.sh
set -uo pipefail

fail=0

function assert_contains() {
    local -r desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        echo "  expected to contain: $needle"
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

exit "$fail"
