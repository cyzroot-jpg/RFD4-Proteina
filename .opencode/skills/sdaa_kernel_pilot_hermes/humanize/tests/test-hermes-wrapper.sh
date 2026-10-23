#!/usr/bin/env bash
#
# ask-hermes.sh tests. These use --dry-run so provider credentials are not
# required.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

ASK_HERMES_SCRIPT="$SCRIPT_DIR/../scripts/ask-hermes.sh"

echo "=========================================="
echo "Ask Hermes Tests"
echo "=========================================="
echo ""

setup_test_dir
MOCK_PROJECT="$TEST_DIR/project"
init_test_git_repo "$MOCK_PROJECT"

run_ask_hermes() {
    (
        cd "$MOCK_PROJECT"
        export CLAUDE_PROJECT_DIR="$MOCK_PROJECT"
        export XDG_CACHE_HOME="$TEST_DIR/cache"
        bash "$ASK_HERMES_SCRIPT" "$@"
    )
}

EXIT_CODE=0
OUTPUT=$(run_ask_hermes --help 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q "ask-hermes"; then
    pass "--help exits 0 with usage"
else
    fail "--help exits 0 with usage" "exit 0 + ask-hermes" "exit=$EXIT_CODE output=$OUTPUT"
fi

EXIT_CODE=0
OUTPUT=$(run_ask_hermes 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "No question"; then
    pass "empty question exits 1"
else
    fail "empty question exits 1" "exit 1 + No question" "exit=$EXIT_CODE output=$OUTPUT"
fi

EXIT_CODE=0
OUTPUT=$(run_ask_hermes --hermes-timeout abc "review this" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "positive integer"; then
    pass "non-numeric timeout exits 1"
else
    fail "non-numeric timeout exits 1" "exit 1 + positive integer" "exit=$EXIT_CODE output=$OUTPUT"
fi

EXIT_CODE=0
STDOUT=$(run_ask_hermes --dry-run --hermes-model hermes-test "review this" 2>/dev/null) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$STDOUT" | grep -q "DRY_RUN"; then
    pass "dry run exits 0 and returns dry-run output"
else
    fail "dry run exits 0" "exit 0 + DRY_RUN" "exit=$EXIT_CODE stdout=$STDOUT"
fi

LATEST_METADATA=$(find "$MOCK_PROJECT/.humanize/skill" -name metadata.md -print | sort | tail -1)
if [[ -n "$LATEST_METADATA" ]] && grep -q "tool: hermes" "$LATEST_METADATA" && grep -q "status: dry_run" "$LATEST_METADATA"; then
    pass "dry run writes Hermes metadata"
else
    fail "dry run writes Hermes metadata" "tool/status metadata" "${LATEST_METADATA:-missing}"
fi

print_test_summary "Ask Hermes Test Summary"
