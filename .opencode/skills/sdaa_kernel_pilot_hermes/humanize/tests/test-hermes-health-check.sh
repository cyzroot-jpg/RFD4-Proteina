#!/usr/bin/env bash
#
# Hermes health-check tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

HEALTH_SCRIPT="$SCRIPT_DIR/../scripts/hermes-health-check.sh"

echo "=========================================="
echo "Hermes Health Check Tests"
echo "=========================================="
echo ""

setup_test_dir
MOCK_PROJECT="$TEST_DIR/project"
mkdir -p \
    "$MOCK_PROJECT/humanize/scripts" \
    "$MOCK_PROJECT/humanize/hooks" \
    "$MOCK_PROJECT/humanize/skills/humanize-kernel-agent-loop" \
    "$MOCK_PROJECT/humanize/skills/teco-ops-op-test" \
    "$MOCK_PROJECT/external/teco-ops-wiki/scripts" \
    "$MOCK_PROJECT/external/teco-ops-wiki/data"

cat > "$MOCK_PROJECT/humanize/scripts/ask-hermes.sh" <<'EOF_ASK'
#!/usr/bin/env bash
echo OK
EOF_ASK
chmod +x "$MOCK_PROJECT/humanize/scripts/ask-hermes.sh"
touch "$MOCK_PROJECT/humanize/scripts/setup-rlcr-loop.sh"
touch "$MOCK_PROJECT/humanize/scripts/hermes-stop-gate.sh"
touch "$MOCK_PROJECT/humanize/scripts/hermes-rlcr-runner.sh"
touch "$MOCK_PROJECT/humanize/scripts/install-hermes-hooks.sh"
touch "$MOCK_PROJECT/humanize/hooks/loop-hermes-pre-verify-hook.sh"
touch "$MOCK_PROJECT/humanize/skills/humanize-kernel-agent-loop/SKILL.md"
touch "$MOCK_PROJECT/humanize/skills/teco-ops-op-test/SKILL.md"
touch "$MOCK_PROJECT/external/teco-ops-wiki/SKILL.md"
touch "$MOCK_PROJECT/external/teco-ops-wiki/scripts/query.py"
touch "$MOCK_PROJECT/external/teco-ops-wiki/scripts/get_page.py"
touch "$MOCK_PROJECT/external/teco-ops-wiki/data/tags.yaml"

MOCK_BIN="$TEST_DIR/bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/hermes" <<'EOF_HERMES'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
    echo "Hermes Agent v0.18.0"
    exit 0
fi
echo "mock hermes"
EOF_HERMES
chmod +x "$MOCK_BIN/hermes"

EXIT_CODE=0
OUTPUT=$(
    PATH="$MOCK_BIN:$PATH" \
    "$HEALTH_SCRIPT" --project-root "$MOCK_PROJECT" --skip-live --skip-wiki-query 2>&1
) || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]] && echo "$OUTPUT" | grep -q "Hermes KernelPilot health check passed"; then
    pass "health check passes with required mock files"
else
    fail "health check passes with required mock files" "exit 0 + pass message" "exit=$EXIT_CODE output=$OUTPUT"
fi

rm -f "$MOCK_PROJECT/humanize/skills/teco-ops-op-test/SKILL.md"
EXIT_CODE=0
OUTPUT=$(
    PATH="$MOCK_BIN:$PATH" \
    "$HEALTH_SCRIPT" --project-root "$MOCK_PROJECT" --skip-live --skip-wiki-query 2>&1
) || EXIT_CODE=$?

if [[ "$EXIT_CODE" -ne 0 ]] && echo "$OUTPUT" | grep -q "teco-ops native test skill"; then
    pass "health check fails when the native test skill is missing"
else
    fail "health check fails when the native test skill is missing" "non-zero + teco-ops native test skill" "exit=$EXIT_CODE output=$OUTPUT"
fi

print_test_summary "Hermes Health Check Test Summary"
