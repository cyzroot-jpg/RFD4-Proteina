#!/usr/bin/env bash
#
# Hermes pre_verify hook tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

HOOK_SCRIPT="$SCRIPT_DIR/../hooks/loop-hermes-pre-verify-hook.sh"

echo "=========================================="
echo "Hermes Pre-Verify Hook Tests"
echo "=========================================="
echo ""

setup_test_dir

create_loop() {
    local project_dir="$1"
    local session_id="$2"
    local round="${3:-0}"

    init_test_git_repo "$project_dir"
    mkdir -p "$project_dir/.humanize/rlcr/$session_id"
    cat > "$project_dir/.humanize/rlcr/$session_id/state.md" <<EOF_STATE
---
current_round: $round
max_iterations: 3
hermes_provider: openai
hermes_model: glm-5.2
hermes_timeout: 3600
plan_file: plan.md
review_started: false
---
EOF_STATE
}

run_hook() {
    local project_dir="$1"
    (
        cd "$project_dir"
        printf '{"hook_event_name":"pre_verify","cwd":"%s","session_id":"test-session","extra":{"coding":true}}\n' "$project_dir" | "$HOOK_SCRIPT"
    )
}

T1_DIR="$TEST_DIR/t1"
mkdir -p "$T1_DIR/project"
set +e
OUT1="$(run_hook "$T1_DIR/project" 2>&1)"
EXIT1=$?
set -e

if [[ "$EXIT1" -eq 0 && -z "$OUT1" ]]; then
    pass "Hermes pre_verify hook allows when no RLCR loop exists"
else
    fail "Hermes pre_verify hook allows when no RLCR loop exists" "exit 0 and empty output" "exit=$EXIT1 output=$OUT1"
fi

T2_DIR="$TEST_DIR/t2"
create_loop "$T2_DIR/project" "2026-07-05_00-00-00" 0
set +e
OUT2="$(run_hook "$T2_DIR/project" 2>&1)"
EXIT2=$?
set -e

if [[ "$EXIT2" -eq 0 ]] && echo "$OUT2" | grep -q '"action":"continue"' && echo "$OUT2" | grep -q 'round-0-summary.md'; then
    pass "Hermes pre_verify hook asks for missing round summary"
else
    fail "Hermes pre_verify hook asks for missing round summary" "continue JSON mentioning round-0-summary.md" "exit=$EXIT2 output=$OUT2"
fi

T3_DIR="$TEST_DIR/t3"
create_loop "$T3_DIR/project" "2026-07-05_00-00-01" 0
cat > "$T3_DIR/project/.humanize/rlcr/2026-07-05_00-00-01/round-0-summary.md" <<'SUMMARY_EOF'
# Round 0 Summary

Implementation and tests are ready for review.
SUMMARY_EOF
set +e
OUT3="$(run_hook "$T3_DIR/project" 2>&1)"
EXIT3=$?
set -e

if [[ "$EXIT3" -eq 0 ]] && echo "$OUT3" | grep -q '"action":"continue"' && echo "$OUT3" | grep -q 'hermes-stop-gate.sh'; then
    pass "Hermes pre_verify hook asks for foreground stop gate when review is missing"
else
    fail "Hermes pre_verify hook asks for foreground stop gate when review is missing" "continue JSON mentioning hermes-stop-gate.sh" "exit=$EXIT3 output=$OUT3"
fi

T4_DIR="$TEST_DIR/t4"
create_loop "$T4_DIR/project" "2026-07-05_00-00-02" 1
LOOP4="$T4_DIR/project/.humanize/rlcr/2026-07-05_00-00-02"
cat > "$LOOP4/transitions.jsonl" <<'LEDGER_EOF'
{"from":0,"to":1,"verdict":"NEEDS_CHANGES"}
LEDGER_EOF
cat > "$LOOP4/round-1-prompt.md" <<'PROMPT_EOF'
# Hermes RLCR Round 1

Read this before continuing.
PROMPT_EOF
touch "$LOOP4/round-1-prompt.md.pending"
set +e
OUT4="$(run_hook "$T4_DIR/project" 2>&1)"
EXIT4=$?
set -e

if [[ "$EXIT4" -eq 0 ]] && echo "$OUT4" | grep -q '"action":"continue"' && echo "$OUT4" | grep -q 'hermes-rlcr-runner.sh'; then
    pass "Hermes pre_verify hook requires runner acknowledgement for next prompt"
else
    fail "Hermes pre_verify hook requires runner acknowledgement for next prompt" "continue JSON mentioning hermes-rlcr-runner.sh" "exit=$EXIT4 output=$OUT4"
fi

T5_DIR="$TEST_DIR/t5"
create_loop "$T5_DIR/project" "2026-07-05_00-00-03" 0
LOOP5="$T5_DIR/project/.humanize/rlcr/2026-07-05_00-00-03"
cat > "$LOOP5/transitions.jsonl" <<'LEDGER_EOF'
{"from":0,"to":0,"verdict":"COMPLETE"}
LEDGER_EOF
cat > "$LOOP5/round-0-summary.md" <<'SUMMARY_EOF'
# Round 0 Summary

Complete.
SUMMARY_EOF
cat > "$LOOP5/round-0-review-result.md" <<'REVIEW_EOF'
COMPLETE
Review accepted.
REVIEW_EOF
set +e
OUT5="$(run_hook "$T5_DIR/project" 2>&1)"
EXIT5=$?
set -e

if [[ "$EXIT5" -eq 0 && -z "$OUT5" ]]; then
    pass "Hermes pre_verify hook allows after COMPLETE review"
else
    fail "Hermes pre_verify hook allows after COMPLETE review" "exit 0 and empty output" "exit=$EXIT5 output=$OUT5"
fi

print_test_summary "Hermes Pre-Verify Hook Test Summary"
