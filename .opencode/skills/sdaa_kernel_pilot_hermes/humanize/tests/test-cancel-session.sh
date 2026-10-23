#!/usr/bin/env bash
#
# scripts/cancel-rlcr-session.sh 的测试。
#
# 验证第 4 轮 (T7) 添加的会话范围取消辅助函数：
#   - 缺少 --session-id 时以退出码 3 拒绝
#   - 不存在的会话 id 以退出码 1 拒绝
#   - 取消会话 A 不会影响同级活跃会话 B
#   - state.md 被重命名为 cancel-state.md 且创建 .cancel-requested
#   - 处于 finalize 阶段的会话需要 --force（否则退出码 2）
#
# 所有测试夹具位于每个测试的 mktemp 树下。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER="$PLUGIN_ROOT/scripts/cancel-rlcr-session.sh"

echo "========================================"
echo "cancel-rlcr-session.sh (T7)"
echo "========================================"

if [[ ! -x "$HELPER" ]]; then
    echo "FAIL: $HELPER not found or not executable" >&2
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

_pass() { printf '\033[0;32mPASS\033[0m: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { printf '\033[0;31mFAIL\033[0m: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_ROOT="$TMP_DIR/proj"
RLCR_DIR="$PROJECT_ROOT/.humanize/rlcr"
mkdir -p "$RLCR_DIR"

SESSION_A="2026-04-17_10-00-00"
SESSION_B="2026-04-17_11-00-00"
SESSION_FINALIZE="2026-04-17_12-00-00"

mkdir -p "$RLCR_DIR/$SESSION_A" "$RLCR_DIR/$SESSION_B" "$RLCR_DIR/$SESSION_FINALIZE"
: > "$RLCR_DIR/$SESSION_A/state.md"
: > "$RLCR_DIR/$SESSION_B/state.md"
: > "$RLCR_DIR/$SESSION_FINALIZE/finalize-state.md"

# ─── 测试 1：缺少 --session-id ───
if "$HELPER" --project "$PROJECT_ROOT" >/dev/null 2>&1; then
    _fail "missing --session-id should exit non-zero"
else
    rc=$?
    if [[ "$rc" -eq 3 ]]; then
        _pass "missing --session-id exits with code 3"
    else
        _fail "missing --session-id should exit 3, got $rc"
    fi
fi

# ─── 测试 2：不存在的会话 id ───
if "$HELPER" --project "$PROJECT_ROOT" --session-id 9999-99-99 >/dev/null 2>&1; then
    _fail "non-existent session should exit non-zero"
else
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
        _pass "non-existent session exits with code 1"
    else
        _fail "non-existent session should exit 1, got $rc"
    fi
fi

# ─── 测试 3：成功取消会话 A ───
out=$("$HELPER" --project "$PROJECT_ROOT" --session-id "$SESSION_A" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "^CANCELLED $SESSION_A$" <<<"$out"; then
    _pass "cancel of active session A succeeds (exit 0, CANCELLED line present)"
else
    _fail "cancel of session A failed: rc=$rc out=$out"
fi

# ─── 测试 4：state.md 重命名为 cancel-state.md ───
if [[ -f "$RLCR_DIR/$SESSION_A/cancel-state.md" && ! -f "$RLCR_DIR/$SESSION_A/state.md" ]]; then
    _pass "session A: state.md renamed to cancel-state.md"
else
    _fail "session A: rename did not happen"
fi

# ─── 测试 5：创建 .cancel-requested 信号文件 ───
if [[ -f "$RLCR_DIR/$SESSION_A/.cancel-requested" ]]; then
    _pass "session A: .cancel-requested signal file present"
else
    _fail "session A: .cancel-requested missing"
fi

# ─── 测试 6：会话 B 不受影响 ───
if [[ -f "$RLCR_DIR/$SESSION_B/state.md" && ! -f "$RLCR_DIR/$SESSION_B/cancel-state.md" && ! -f "$RLCR_DIR/$SESSION_B/.cancel-requested" ]]; then
    _pass "session B: untouched while session A was cancelled"
else
    _fail "session B: should be untouched but was modified"
fi

# ─── 测试 7：finalize 阶段需要 --force ───
if "$HELPER" --project "$PROJECT_ROOT" --session-id "$SESSION_FINALIZE" >/dev/null 2>&1; then
    _fail "finalize-phase session should require --force"
else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        _pass "finalize-phase session without --force exits with code 2"
    else
        _fail "finalize-phase should exit 2, got $rc"
    fi
fi

# ─── 测试 8：finalize 阶段使用 --force 成功 ───
out=$("$HELPER" --project "$PROJECT_ROOT" --session-id "$SESSION_FINALIZE" --force 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]] && [[ -f "$RLCR_DIR/$SESSION_FINALIZE/cancel-state.md" ]]; then
    _pass "finalize-phase session with --force is cancelled"
else
    _fail "finalize-phase --force failed: rc=$rc out=$out"
fi

# ─── 测试 9a：尝试路径遍历的会话 id 被拒绝 ───
# 在同级目录中放置 state.md，使遍历绕过会重命名它；
# 调用后，该文件必须仍然存在且未被修改。
SIBLING_DIR="$PROJECT_ROOT/.humanize/sibling"
mkdir -p "$SIBLING_DIR"
: > "$SIBLING_DIR/state.md"

for malicious_id in "../sibling" "../../etc" "/absolute/path" "..\\foo" "foo/bar" ".hidden" "."; do
    if "$HELPER" --project "$PROJECT_ROOT" --session-id "$malicious_id" >/dev/null 2>&1; then
        _fail "path-traversal session-id should be rejected: $malicious_id"
    else
        rc=$?
        if [[ "$rc" -eq 3 ]]; then
            _pass "rejects unsafe session-id '$malicious_id' with exit 3"
        else
            _fail "unsafe session-id '$malicious_id' should exit 3, got $rc"
        fi
    fi
done

if [[ -f "$SIBLING_DIR/state.md" ]]; then
    _pass "sibling state.md untouched after traversal attempts"
else
    _fail "sibling state.md was mutated by a traversal attempt"
fi

# ─── 测试 10：旧版位置参数形式仍然有效 ───
SESSION_LEGACY="2026-04-17_13-00-00"
mkdir -p "$RLCR_DIR/$SESSION_LEGACY"
: > "$RLCR_DIR/$SESSION_LEGACY/state.md"
out=$("$HELPER" --project "$PROJECT_ROOT" "$SESSION_LEGACY" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]] && [[ -f "$RLCR_DIR/$SESSION_LEGACY/cancel-state.md" ]]; then
    _pass "legacy positional session-id form still works"
else
    _fail "legacy positional form failed: rc=$rc out=$out"
fi

echo
echo "========================================"
printf 'Passed: \033[0;32m%d\033[0m\n' "$PASS_COUNT"
printf 'Failed: \033[0;31m%d\033[0m\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

printf '\033[0;32mAll cancel-session tests passed!\033[0m\n'
