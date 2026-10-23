#!/usr/bin/env bash
#
# Hermes stop-gate tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

GATE_SCRIPT="$SCRIPT_DIR/../scripts/hermes-stop-gate.sh"

echo "=========================================="
echo "Hermes Stop Gate Tests"
echo "=========================================="
echo ""

setup_test_dir

create_active_loop() {
    local project_dir="$1"
    local session_id="$2"
    local verdict_fixture="${3:-complete}"

    init_test_git_repo "$project_dir"
    mkdir -p "$project_dir/.humanize/rlcr/$session_id"

    cat > "$project_dir/plan.md" <<'PLAN_EOF'
# Test Plan

Implement the requested kernel optimization.
PLAN_EOF

    cat > "$project_dir/.humanize/rlcr/$session_id/state.md" <<EOF_STATE
---
current_round: 0
max_iterations: 3
hermes_provider: deepseek
hermes_model: deepseek-chat
hermes_timeout: 30
plan_file: plan.md
review_started: false
---
EOF_STATE

    if [[ "$verdict_fixture" != "missing-summary" ]]; then
        cat > "$project_dir/.humanize/rlcr/$session_id/round-0-summary.md" <<'SUMMARY_EOF'
# Round 0 Summary

The implementation compiles and benchmark results improved.
SUMMARY_EOF
    fi
}

create_mock_hermes() {
    local bin_dir="$1"
    local body="$2"
    local marker="${3:-COMPLETE}"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/hermes" <<EOF_MOCK
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$marker"
printf '%s\n' "$body"
EOF_MOCK
    chmod +x "$bin_dir/hermes"
}

T1_DIR="$TEST_DIR/t1"
create_active_loop "$T1_DIR/project" "2026-07-03_00-00-00"
create_mock_hermes "$T1_DIR/bin" "review accepted"

set +e
(
    cd "$T1_DIR/project"
    export PATH="$T1_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T1_DIR/project"
    export XDG_CACHE_HOME="$T1_DIR/cache"
    "$GATE_SCRIPT" --project-root "$T1_DIR/project"
) > "$T1_DIR/out.txt" 2>&1
EXIT1=$?
set -e

REVIEW_RESULT="$T1_DIR/project/.humanize/rlcr/2026-07-03_00-00-00/round-0-review-result.md"
REVIEW_PROMPT="$T1_DIR/project/.humanize/rlcr/2026-07-03_00-00-00/round-0-review-prompt.md"

if [[ "$EXIT1" -eq 0 ]]; then
    pass "Hermes stop gate allows COMPLETE verdict"
else
    OUTPUT1=$(cat "$T1_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate allows COMPLETE verdict" "exit 0" "exit $EXIT1; output: $OUTPUT1"
fi

if [[ -f "$REVIEW_RESULT" ]] && grep -q '^COMPLETE$' "$REVIEW_RESULT"; then
    pass "Hermes stop gate writes review result"
else
    fail "Hermes stop gate writes review result" "round-0-review-result.md with COMPLETE" "${REVIEW_RESULT:-missing}"
fi

if [[ -f "$REVIEW_PROMPT" ]] && grep -q "Round 0 Summary" "$REVIEW_PROMPT" && grep -q "Reply with one marker line" "$REVIEW_PROMPT"; then
    pass "Hermes stop gate writes review prompt"
else
    fail "Hermes stop gate writes review prompt" "round-0-review-prompt.md with summary and instructions" "${REVIEW_PROMPT:-missing}"
fi

T2_DIR="$TEST_DIR/t2"
create_active_loop "$T2_DIR/project" "2026-07-03_00-00-01" "missing-summary"
create_mock_hermes "$T2_DIR/bin" "should not be called"

set +e
(
    cd "$T2_DIR/project"
    export PATH="$T2_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T2_DIR/project"
    "$GATE_SCRIPT" --project-root "$T2_DIR/project"
) > "$T2_DIR/out.txt" 2>&1
EXIT2=$?
set -e

if [[ "$EXIT2" -eq 10 ]]; then
    pass "Hermes stop gate blocks missing round summary"
else
    OUTPUT2=$(cat "$T2_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate blocks missing round summary" "exit 10" "exit $EXIT2; output: $OUTPUT2"
fi

if grep -q "Missing round summary" "$T2_DIR/out.txt"; then
    pass "Hermes stop gate reports missing summary reason"
else
    OUTPUT2=$(cat "$T2_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate reports missing summary reason" "Missing round summary" "$OUTPUT2"
fi

T3_DIR="$TEST_DIR/t3"
create_active_loop "$T3_DIR/project" "2026-07-03_00-00-02"
create_mock_hermes "$T3_DIR/bin" "tighten benchmark evidence" "NEEDS_CHANGES"

set +e
(
    cd "$T3_DIR/project"
    export PATH="$T3_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T3_DIR/project"
    export XDG_CACHE_HOME="$T3_DIR/cache"
    "$GATE_SCRIPT" --project-root "$T3_DIR/project"
) > "$T3_DIR/out.txt" 2>&1
EXIT3=$?
set -e

NEXT_PROMPT="$T3_DIR/project/.humanize/rlcr/2026-07-03_00-00-02/round-1-prompt.md"
STATE3="$T3_DIR/project/.humanize/rlcr/2026-07-03_00-00-02/state.md"

if [[ "$EXIT3" -eq 10 ]]; then
    pass "Hermes stop gate blocks NEEDS_CHANGES verdict"
else
    OUTPUT3=$(cat "$T3_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate blocks NEEDS_CHANGES verdict" "exit 10" "exit $EXIT3; output: $OUTPUT3"
fi

if grep -q '^current_round: 1$' "$STATE3"; then
    pass "Hermes stop gate advances state for next round"
else
    fail "Hermes stop gate advances state for next round" "current_round: 1" "$(cat "$STATE3")"
fi

if [[ -f "$NEXT_PROMPT" ]] && grep -q "tighten benchmark evidence" "$NEXT_PROMPT"; then
    pass "Hermes stop gate writes next round prompt with review findings"
else
    fail "Hermes stop gate writes next round prompt with review findings" "round-1-prompt.md with review findings" "${NEXT_PROMPT:-missing}"
fi

if [[ -f "${NEXT_PROMPT}.pending" && ! -f "${NEXT_PROMPT}.read" ]]; then
    pass "Hermes stop gate marks the next prompt as unread"
else
    fail "Hermes stop gate marks the next prompt as unread" "round-1-prompt.md.pending and no .read marker" "$(ls -1 "$T3_DIR/project/.humanize/rlcr/2026-07-03_00-00-02" 2>/dev/null || true)"
fi

TRANSITIONS3="$T3_DIR/project/.humanize/rlcr/2026-07-03_00-00-02/transitions.jsonl"
if [[ -f "$TRANSITIONS3" ]] && grep -q '"from":0' "$TRANSITIONS3" && grep -q '"to":1' "$TRANSITIONS3" && grep -q '"verdict":"NEEDS_CHANGES"' "$TRANSITIONS3"; then
    pass "Hermes stop gate records NEEDS_CHANGES transition"
else
    fail "Hermes stop gate records NEEDS_CHANGES transition" "transition from 0 to 1 with NEEDS_CHANGES" "$(cat "$TRANSITIONS3" 2>/dev/null || true)"
fi

T4_DIR="$TEST_DIR/t4"
create_active_loop "$T4_DIR/project" "2026-07-03_00-00-03"
mkdir -p "$T4_DIR/project/.humanize/rlcr/2026-07-03_00-00-03/review.lock.d"
mkdir -p "$T4_DIR/bin"
cat > "$T4_DIR/bin/hermes" <<EOF_MOCK_LOCK
#!/usr/bin/env bash
set -euo pipefail
touch "$T4_DIR/hermes-called"
printf '%s\n' "COMPLETE"
EOF_MOCK_LOCK
chmod +x "$T4_DIR/bin/hermes"

set +e
(
    cd "$T4_DIR/project"
    export PATH="$T4_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T4_DIR/project"
    "$GATE_SCRIPT" --project-root "$T4_DIR/project"
) > "$T4_DIR/out.txt" 2>&1
EXIT4=$?
set -e

if [[ "$EXIT4" -eq 10 ]]; then
    pass "Hermes stop gate blocks concurrent reviews"
else
    OUTPUT4=$(cat "$T4_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate blocks concurrent reviews" "exit 10" "exit $EXIT4; output: $OUTPUT4"
fi

if grep -q "review already in progress" "$T4_DIR/out.txt" && [[ ! -f "$T4_DIR/hermes-called" ]]; then
    pass "Hermes stop gate does not start Hermes while locked"
else
    OUTPUT4=$(cat "$T4_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate does not start Hermes while locked" "locked message and no hermes call" "$OUTPUT4"
fi

T5_DIR="$TEST_DIR/t5"
create_active_loop "$T5_DIR/project" "2026-07-03_00-00-04"
STATE5="$T5_DIR/project/.humanize/rlcr/2026-07-03_00-00-04/state.md"
LOOP5="$T5_DIR/project/.humanize/rlcr/2026-07-03_00-00-04"
awk '
    /^current_round:[[:space:]]*/ { print "current_round: 1"; next }
    { print }
' "$STATE5" > "$STATE5.tmp" && mv "$STATE5.tmp" "$STATE5"
cat > "$LOOP5/transitions.jsonl" <<'LEDGER_EOF'
{"from":0,"to":0,"verdict":"COMPLETE"}
LEDGER_EOF
cat > "$LOOP5/round-1-summary.md" <<'SUMMARY_EOF'
# Round 1 Summary

Manual state advance should be rejected.
SUMMARY_EOF
create_mock_hermes "$T5_DIR/bin" "should not be called"

set +e
(
    cd "$T5_DIR/project"
    export PATH="$T5_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T5_DIR/project"
    "$GATE_SCRIPT" --project-root "$T5_DIR/project"
) > "$T5_DIR/out.txt" 2>&1
EXIT5=$?
set -e

if [[ "$EXIT5" -eq 10 ]] && grep -q "transition ledger mismatch" "$T5_DIR/out.txt"; then
    pass "Hermes stop gate blocks manual state edits"
else
    OUTPUT5=$(cat "$T5_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate blocks manual state edits" "exit 10 with transition ledger mismatch" "exit $EXIT5; output: $OUTPUT5"
fi

T6_DIR="$TEST_DIR/t6"
create_active_loop "$T6_DIR/project" "2026-07-03_00-00-05"
STATE6="$T6_DIR/project/.humanize/rlcr/2026-07-03_00-00-05/state.md"
LOOP6="$T6_DIR/project/.humanize/rlcr/2026-07-03_00-00-05"
awk '
    /^current_round:[[:space:]]*/ { print "current_round: 1"; next }
    { print }
' "$STATE6" > "$STATE6.tmp" && mv "$STATE6.tmp" "$STATE6"
cat > "$LOOP6/transitions.jsonl" <<'LEDGER_EOF'
{"from":0,"to":1,"verdict":"NEEDS_CHANGES"}
LEDGER_EOF
cat > "$LOOP6/round-1-prompt.md" <<'PROMPT_EOF'
# Hermes RLCR Round 1

Read this before implementing the next round.
PROMPT_EOF
touch "$LOOP6/round-1-prompt.md.pending"
cat > "$LOOP6/round-1-summary.md" <<'SUMMARY_EOF'
# Round 1 Summary

This review should be rejected because the prompt was not acknowledged.
SUMMARY_EOF
create_mock_hermes "$T6_DIR/bin" "should not be called"

set +e
(
    cd "$T6_DIR/project"
    export PATH="$T6_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T6_DIR/project"
    "$GATE_SCRIPT" --project-root "$T6_DIR/project"
) > "$T6_DIR/out.txt" 2>&1
EXIT6=$?
set -e

if [[ "$EXIT6" -eq 10 ]] && grep -q "prompt was not acknowledged" "$T6_DIR/out.txt"; then
    pass "Hermes stop gate blocks unread next-round prompts"
else
    OUTPUT6=$(cat "$T6_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate blocks unread next-round prompts" "exit 10 with prompt acknowledgement message" "exit $EXIT6; output: $OUTPUT6"
fi

T7_DIR="$TEST_DIR/t7"
create_active_loop "$T7_DIR/project" "2026-07-03_00-00-06"
mkdir -p "$T7_DIR/bin"
cat > "$T7_DIR/bin/hermes" <<'EOF_MOCK_PROSE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "The implementation is buggy -- x + 2 instead of x * 2. No tests were run."
printf '%s\n' ""
printf '%s\n' "**NEEDS_CHANGES**"
EOF_MOCK_PROSE
chmod +x "$T7_DIR/bin/hermes"

set +e
(
    cd "$T7_DIR/project"
    export PATH="$T7_DIR/bin:$PATH"
    export CLAUDE_PROJECT_DIR="$T7_DIR/project"
    export XDG_CACHE_HOME="$T7_DIR/cache"
    "$GATE_SCRIPT" --project-root "$T7_DIR/project"
) > "$T7_DIR/out.txt" 2>&1
EXIT7=$?
set -e

# Regression test: a real deepseek-chat response explained its reasoning
# before concluding with a markdown-bold marker on the last line instead of a
# bare marker on the first line. The gate must still recognize NEEDS_CHANGES
# instead of misclassifying "The" as an unknown verdict.
if [[ "$EXIT7" -eq 10 ]] && grep -q "Hermes requested another round" "$T7_DIR/out.txt"; then
    pass "Hermes stop gate parses a trailing markdown-bold verdict marker"
else
    OUTPUT7=$(cat "$T7_DIR/out.txt" 2>/dev/null || true)
    fail "Hermes stop gate parses a trailing markdown-bold verdict marker" "exit 10 with NEEDS_CHANGES handling" "exit $EXIT7; output: $OUTPUT7"
fi

if ! grep -q "unknown verdict" "$T7_DIR/out.txt"; then
    pass "Hermes stop gate does not misread prose as the verdict"
else
    fail "Hermes stop gate does not misread prose as the verdict" "no 'unknown verdict' message" "$(cat "$T7_DIR/out.txt" 2>/dev/null || true)"
fi

print_test_summary "Hermes Stop Gate Test Summary"
