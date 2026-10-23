#!/usr/bin/env bash
#
# Hermes RLCR runner tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

RUNNER_SCRIPT="$SCRIPT_DIR/../scripts/hermes-rlcr-runner.sh"

echo "=========================================="
echo "Hermes RLCR Runner Tests"
echo "=========================================="
echo ""

setup_test_dir

PROJECT_DIR="$TEST_DIR/project"
LOOP_DIR="$PROJECT_DIR/.humanize/rlcr/2026-07-03_00-00-00"
init_test_git_repo "$PROJECT_DIR"
mkdir -p "$LOOP_DIR"

cat > "$LOOP_DIR/state.md" <<'STATE_EOF'
---
current_round: 1
max_iterations: 3
hermes_provider: deepseek
hermes_model: deepseek-chat
hermes_timeout: 30
plan_file: plan.md
review_started: false
---
STATE_EOF

cat > "$LOOP_DIR/round-1-prompt.md" <<'PROMPT_EOF'
# Hermes RLCR Round 1

Use the Hermes review findings before implementing the next smallest change.
PROMPT_EOF
touch "$LOOP_DIR/round-1-prompt.md.pending"

set +e
(
    cd "$PROJECT_DIR"
    "$RUNNER_SCRIPT" --project-root "$PROJECT_DIR"
) > "$TEST_DIR/out.txt" 2>&1
EXIT1=$?
set -e

if [[ "$EXIT1" -eq 0 ]]; then
    pass "Hermes RLCR runner exits successfully"
else
    OUTPUT1=$(cat "$TEST_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes RLCR runner exits successfully" "exit 0" "exit $EXIT1; output: $OUTPUT1"
fi

if grep -q "Hermes RLCR Round 1" "$TEST_DIR/out.txt" && grep -q "Acknowledged prompt read" "$TEST_DIR/out.txt"; then
    pass "Hermes RLCR runner displays and acknowledges prompt"
else
    OUTPUT1=$(cat "$TEST_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes RLCR runner displays and acknowledges prompt" "prompt content and acknowledgement" "$OUTPUT1"
fi

if [[ -f "$LOOP_DIR/round-1-prompt.md.read" && ! -f "$LOOP_DIR/round-1-prompt.md.pending" ]]; then
    pass "Hermes RLCR runner writes read marker and clears pending marker"
else
    fail "Hermes RLCR runner writes read marker and clears pending marker" ".read exists and .pending removed" "$(ls -1 "$LOOP_DIR")"
fi

print_test_summary "Hermes RLCR Runner Test Summary"
