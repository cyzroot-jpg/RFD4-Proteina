#!/usr/bin/env bash
#
# Hermes native hook installer tests.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

INSTALL_HOOKS_SCRIPT="$PROJECT_ROOT/scripts/install-hermes-hooks.sh"

echo "=========================================="
echo "Hermes Hook Install Tests"
echo "=========================================="
echo ""

setup_test_dir

CONFIG_DIR="$TEST_DIR/hermes"
RUNTIME_ROOT="$TEST_DIR/runtime/humanize"
mkdir -p "$CONFIG_DIR" "$RUNTIME_ROOT/hooks"
touch "$RUNTIME_ROOT/hooks/loop-hermes-pre-verify-hook.sh"
chmod +x "$RUNTIME_ROOT/hooks/loop-hermes-pre-verify-hook.sh"

cat > "$CONFIG_DIR/config.yaml" <<'CONFIG_EOF'
model:
  provider: openai
  default: glm-5.2
hooks:
  post_tool_call:
    - command: /tmp/existing-post-hook.sh
      timeout: 10
CONFIG_EOF

bash "$INSTALL_HOOKS_SCRIPT" \
    --hermes-config-dir "$CONFIG_DIR" \
    --runtime-root "$RUNTIME_ROOT" > "$TEST_DIR/out.txt" 2>&1

CONFIG_OUT="$(cat "$CONFIG_DIR/config.yaml")"
ALLOWLIST_OUT="$(cat "$CONFIG_DIR/shell-hooks-allowlist.json")"

if echo "$CONFIG_OUT" | grep -q 'pre_verify:' && echo "$CONFIG_OUT" | grep -q 'loop-hermes-pre-verify-hook.sh' && echo "$CONFIG_OUT" | grep -q 'timeout: 3600'; then
    pass "Hermes hook installer writes pre_verify hook config"
else
    fail "Hermes hook installer writes pre_verify hook config" "pre_verify hook command with timeout 3600" "$CONFIG_OUT"
fi

if echo "$CONFIG_OUT" | grep -q 'post_tool_call:' && echo "$CONFIG_OUT" | grep -q '/tmp/existing-post-hook.sh'; then
    pass "Hermes hook installer preserves existing hooks"
else
    fail "Hermes hook installer preserves existing hooks" "existing post_tool_call hook remains" "$CONFIG_OUT"
fi

if echo "$ALLOWLIST_OUT" | grep -q '"event": "pre_verify"' && echo "$ALLOWLIST_OUT" | grep -q 'loop-hermes-pre-verify-hook.sh'; then
    pass "Hermes hook installer writes shell hook allowlist"
else
    fail "Hermes hook installer writes shell hook allowlist" "pre_verify allowlist entry" "$ALLOWLIST_OUT"
fi

DRY_CONFIG_DIR="$TEST_DIR/dry-hermes"
mkdir -p "$DRY_CONFIG_DIR"
set +e
DRY_OUT=$(bash "$INSTALL_HOOKS_SCRIPT" --hermes-config-dir "$DRY_CONFIG_DIR" --runtime-root "$RUNTIME_ROOT" --dry-run 2>&1)
DRY_EXIT=$?
set -e

if [[ "$DRY_EXIT" -eq 0 ]] && echo "$DRY_OUT" | grep -q 'DRY-RUN install Hermes pre_verify hook'; then
    pass "Hermes hook installer supports dry run"
else
    fail "Hermes hook installer supports dry run" "dry-run log and exit 0" "exit=$DRY_EXIT output=$DRY_OUT"
fi

print_test_summary "Hermes Hook Install Test Summary"
