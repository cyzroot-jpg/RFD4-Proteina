#!/usr/bin/env bash
#
# Hermes install target tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-skill.sh"

echo "=========================================="
echo "Hermes Install Tests"
echo "=========================================="
echo ""

setup_test_dir

OUTPUT=$(
    bash "$INSTALL_SCRIPT" \
        --target hermes \
        --hermes-skills-dir "$TEST_DIR/hermes/skills" \
        --hermes-config-dir "$TEST_DIR/hermes/config" \
        --command-bin-dir "$TEST_DIR/bin" \
        --dry-run 2>&1
)

if echo "$OUTPUT" | grep -q "target: hermes" && echo "$OUTPUT" | grep -q "hermes skills dir"; then
    pass "dry-run recognizes Hermes target"
else
    fail "dry-run recognizes Hermes target" "target/hermes log lines" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "syncing \\[hermes\\] skill: humanize" && echo "$OUTPUT" | grep -q "DRY-RUN"; then
    pass "dry-run syncs Hermes skill bundle"
else
    fail "dry-run syncs Hermes skill bundle" "syncing [hermes] skill + DRY-RUN" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "installing native Hermes pre_verify hook" && echo "$OUTPUT" | grep -q "DRY-RUN install Hermes pre_verify hook"; then
    pass "dry-run installs Hermes native hook"
else
    fail "dry-run installs Hermes native hook" "native Hermes hook dry-run logs" "$OUTPUT"
fi

EXIT_CODE=0
BAD_OUTPUT=$(bash "$INSTALL_SCRIPT" --target invalid 2>&1 >/dev/null) || EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]] && echo "$BAD_OUTPUT" | grep -q "hermes"; then
    pass "invalid target error lists Hermes"
else
    fail "invalid target error lists Hermes" "non-zero + hermes in message" "exit=$EXIT_CODE output=$BAD_OUTPUT"
fi

print_test_summary "Hermes Install Test Summary"
