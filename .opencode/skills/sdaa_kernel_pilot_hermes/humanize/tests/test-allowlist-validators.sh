#!/usr/bin/env bash
#
# RLCR 循环验证器中的允许列表行为测试
#
# 测试：
# - loop-common.sh 中的 is_allowlisted_file() 函数
# - todos、summaries 和 contracts 的读取验证器允许列表
# - todos、summaries 和 contracts 的写入验证器允许列表
# - todos、summaries 和 contracts 的编辑验证器允许列表
# - todos 文件的 Bash 验证器允许列表（路径受限）
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

# 测试辅助函数
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; echo "  Expected: $2"; echo "  Got: $3"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# 设置测试环境
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

setup_test_loop() {
    cd "$TEST_DIR"

    if [[ ! -d ".git" ]]; then
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        echo "initial" > init.txt
        git add init.txt
        git -c commit.gpgsign=false commit -q -m "Initial commit"
    fi

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # 创建循环目录结构
    LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
    mkdir -p "$LOOP_DIR"

    # 创建状态文件
    cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 5
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $current_branch
base_branch: main
review_started: false
---
EOF
}

echo "=== Test: is_allowlisted_file() Function ==="
echo ""

setup_test_loop
ACTIVE_LOOP_DIR="$LOOP_DIR"

# 测试 1：允许列表中的文件 - round-1-todos.md
echo "Test 1: round-1-todos.md is allowlisted"
if is_allowlisted_file "$ACTIVE_LOOP_DIR/round-1-todos.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-1-todos.md is allowlisted"
else
    fail "round-1-todos.md allowlist" "true" "false"
fi

# 测试 2：允许列表中的文件 - round-2-todos.md
echo "Test 2: round-2-todos.md is allowlisted"
if is_allowlisted_file "$ACTIVE_LOOP_DIR/round-2-todos.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-2-todos.md is allowlisted"
else
    fail "round-2-todos.md allowlist" "true" "false"
fi

# 测试 3：允许列表中的文件 - round-0-summary.md
echo "Test 3: round-0-summary.md is allowlisted"
if is_allowlisted_file "$ACTIVE_LOOP_DIR/round-0-summary.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-0-summary.md is allowlisted"
else
    fail "round-0-summary.md allowlist" "true" "false"
fi

# 测试 4：允许列表中的文件 - round-1-summary.md
echo "Test 4: round-1-summary.md is allowlisted"
if is_allowlisted_file "$ACTIVE_LOOP_DIR/round-1-summary.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-1-summary.md is allowlisted"
else
    fail "round-1-summary.md allowlist" "true" "false"
fi

# 测试 5：不在允许列表中的文件 - round-3-todos.md
echo "Test 5: round-3-todos.md is NOT allowlisted"
if ! is_allowlisted_file "$ACTIVE_LOOP_DIR/round-3-todos.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-3-todos.md is NOT allowlisted"
else
    fail "round-3-todos.md blocked" "false" "true"
fi

# 测试 6：不在允许列表中的文件 - round-2-summary.md
echo "Test 6: round-2-summary.md is NOT allowlisted"
if ! is_allowlisted_file "$ACTIVE_LOOP_DIR/round-2-summary.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-2-summary.md is NOT allowlisted"
else
    fail "round-2-summary.md blocked" "false" "true"
fi

# 测试 6b：不在允许列表中的文件 - round-0-contract.md
echo "Test 6b: round-0-contract.md is NOT allowlisted"
if ! is_allowlisted_file "$ACTIVE_LOOP_DIR/round-0-contract.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-0-contract.md is NOT allowlisted"
else
    fail "round-0-contract.md blocked" "false" "true"
fi

# 测试 7：错误目录 - 允许列表中的文件名但路径错误
echo "Test 7: round-1-todos.md in wrong directory is NOT allowlisted"
if ! is_allowlisted_file "/other/path/round-1-todos.md" "$ACTIVE_LOOP_DIR"; then
    pass "round-1-todos.md in wrong directory is blocked"
else
    fail "wrong directory check" "false" "true"
fi

echo ""
echo "=== Test: Write Validator Allowlist ==="
echo ""

setup_test_loop
export CLAUDE_PROJECT_DIR="$TEST_DIR"

# 测试 8：写入验证器允许在活跃循环目录中的 round-1-todos.md
echo "Test 8: Write validator allows round-1-todos.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Write validator allows round-1-todos.md"
else
    fail "Write validator round-1-todos.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 9：写入验证器允许 round-0-summary.md（非当前轮次）
echo "Test 9: Write validator allows round-0-summary.md (historical)"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-0-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Write validator allows round-0-summary.md"
else
    fail "Write validator round-0-summary.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 9b：写入验证器允许当前轮次的 contract
echo "Test 9b: Write validator allows round-5-contract.md (current round)"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Write validator allows round-5-contract.md"
else
    fail "Write validator round-5-contract.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 10：写入验证器阻止 round-3-todos.md（不在允许列表中）
echo "Test 10: Write validator blocks round-3-todos.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-3-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Write validator blocks round-3-todos.md"
else
    fail "Write validator round-3-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 11：写入验证器阻止 round-2-summary.md（不在允许列表中）
echo "Test 11: Write validator blocks round-2-summary.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-2-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "round"; then
    pass "Write validator blocks round-2-summary.md"
else
    fail "Write validator round-2-summary.md" "exit 2 with round error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 11b：写入验证器阻止过期轮次的 contract
echo "Test 11b: Write validator blocks round-3-contract.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-3-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "round"; then
    pass "Write validator blocks round-3-contract.md"
else
    fail "Write validator round-3-contract.md" "exit 2 with round error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Edit Validator Allowlist ==="
echo ""

# 测试 12：编辑验证器允许在活跃循环目录中的 round-2-todos.md
echo "Test 12: Edit validator allows round-2-todos.md"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-2-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Edit validator allows round-2-todos.md"
else
    fail "Edit validator round-2-todos.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 13：编辑验证器允许 round-1-summary.md（历史记录）
echo "Test 13: Edit validator allows round-1-summary.md (historical)"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-1-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Edit validator allows round-1-summary.md"
else
    fail "Edit validator round-1-summary.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 13b：编辑验证器允许当前轮次的 contract
echo "Test 13b: Edit validator allows round-5-contract.md (current round)"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Edit validator allows round-5-contract.md"
else
    fail "Edit validator round-5-contract.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 13c：编辑验证器阻止过期轮次的 contract
echo "Test 13c: Edit validator blocks round-0-contract.md"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-0-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "round"; then
    pass "Edit validator blocks round-0-contract.md"
else
    fail "Edit validator round-0-contract.md" "exit 2 with round error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 14：编辑验证器阻止 round-4-todos.md
echo "Test 14: Edit validator blocks round-4-todos.md"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-4-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Edit validator blocks round-4-todos.md"
else
    fail "Edit validator round-4-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Read Validator Allowlist ==="
echo ""

# 测试 15：读取验证器允许 round-1-todos.md
echo "Test 15: Read validator allows round-1-todos.md"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Read validator allows round-1-todos.md"
else
    fail "Read validator round-1-todos.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 16：读取验证器允许 round-0-summary.md（历史记录）
echo "Test 16: Read validator allows round-0-summary.md (historical)"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-0-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Read validator allows round-0-summary.md"
else
    fail "Read validator round-0-summary.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 16b：读取验证器允许当前轮次的 contract
echo "Test 16b: Read validator allows round-5-contract.md (current round)"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Read validator allows round-5-contract.md"
else
    fail "Read validator round-5-contract.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 17：读取验证器阻止 round-3-todos.md
echo "Test 17: Read validator blocks round-3-todos.md"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-3-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Read validator blocks round-3-todos.md"
else
    fail "Read validator round-3-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 18：读取验证器阻止 round-3-summary.md（不在允许列表中）
echo "Test 18: Read validator blocks round-3-summary.md"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-3-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "round"; then
    pass "Read validator blocks round-3-summary.md"
else
    fail "Read validator round-3-summary.md" "exit 2 with round error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 18b：读取验证器阻止过期轮次的 contract
echo "Test 18b: Read validator blocks round-3-contract.md"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-3-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "round"; then
    pass "Read validator blocks round-3-contract.md"
else
    fail "Read validator round-3-contract.md" "exit 2 with round error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Bash Validator Allowlist (Path-Restricted) ==="
echo ""

# 测试 19：Bash 验证器允许在活跃循环目录路径中的 round-1-todos.md
echo "Test 19: Bash validator allows round-1-todos.md in active loop dir"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$LOOP_DIR'/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Bash validator allows round-1-todos.md in active loop dir"
else
    fail "Bash validator round-1-todos.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 20：Bash 验证器允许在活跃循环目录路径中的 round-2-todos.md
echo "Test 20: Bash validator allows round-2-todos.md in active loop dir"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "cat data | tee '$LOOP_DIR'/round-2-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Bash validator allows round-2-todos.md in active loop dir"
else
    fail "Bash validator round-2-todos.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 20b：Bash 验证器阻止 round-5-contract.md
echo "Test 20b: Bash validator blocks round-5-contract.md"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "contract"; then
    pass "Bash validator blocks round-5-contract.md"
else
    fail "Bash validator round-5-contract.md" "exit 2 with contract error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 21：Bash 验证器阻止在错误目录中的 round-1-todos.md
echo "Test 21: Bash validator blocks round-1-todos.md in wrong directory"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > /tmp/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Bash validator blocks round-1-todos.md in wrong directory"
else
    fail "Bash validator wrong dir round-1-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 22：Bash 验证器阻止 round-3-todos.md（不在允许列表中）
echo "Test 22: Bash validator blocks round-3-todos.md"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$LOOP_DIR'/round-3-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Bash validator blocks round-3-todos.md"
else
    fail "Bash validator round-3-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 23：Bash 验证器阻止没有完整路径的通用 round-1-todos.md
echo "Test 23: Bash validator blocks generic round-1-todos.md without full path"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Bash validator blocks generic round-1-todos.md"
else
    fail "Bash validator generic round-1-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 24：Bash 验证器阻止在旧循环目录中的 round-1-todos.md
echo "Test 24: Bash validator blocks round-1-todos.md in old loop directory"
OLD_LOOP="$TEST_DIR/.humanize/rlcr/2023-01-01_00-00-00"
mkdir -p "$OLD_LOOP"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$OLD_LOOP'/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Bash validator blocks round-1-todos.md in old loop directory"
else
    fail "Bash validator old loop round-1-todos.md" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 25：Bash 验证器阻止同名不同根目录（安全测试）
echo "Test 25: Bash validator blocks same-basename different-root"
ACTIVE_LOOP_BASENAME=$(basename "$LOOP_DIR")
DIFFERENT_ROOT="/tmp/.humanize/rlcr/${ACTIVE_LOOP_BASENAME}"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$DIFFERENT_ROOT'/round-1-todos.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "todos"; then
    pass "Bash validator blocks same-basename different-root"
else
    fail "Bash validator same-basename different-root" "exit 2 with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Bash Validator Hook Wrapper Blocking ==="
echo ""

assert_hook_wrapper_blocked() {
    local test_name="$1"
    local command="$2"
    local hook_input

    hook_input=$(jq -nc --arg command "$command" '{tool_name: "Bash", tool_input: {command: $command}}')

    set +e
    RESULT=$(echo "$hook_input" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
    EXIT_CODE=$?
    set -e

    if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "direct execution"; then
        pass "$test_name"
    else
        fail "$test_name" "exit 2 with direct execution block" "exit $EXIT_CODE, output: $RESULT, command: $command"
    fi
}

echo "Test 26: Bash validator blocks bare bash hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks bare bash hook execution" \
    "bash hooks/loop-codex-stop-hook.sh"

echo "Test 27: Bash validator blocks bare zsh hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks bare zsh hook execution" \
    "zsh hooks/loop-codex-stop-hook.sh"

echo "Test 28: Bash validator blocks env-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks env-wrapped hook execution" \
    "env FOO=1 bash hooks/loop-codex-stop-hook.sh"

echo "Test 29: Bash validator blocks command-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks command-wrapped hook execution" \
    "command bash hooks/loop-codex-stop-hook.sh"

echo "Test 30: Bash validator blocks assignment-prefixed hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks assignment-prefixed hook execution" \
    "VAR=1 bash hooks/loop-codex-stop-hook.sh"

echo "Test 31: Bash validator blocks combined wrapper hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks combined wrapper hook execution" \
    "VAR=1 env FOO=2 bash hooks/loop-codex-stop-hook.sh"

echo "Test 32: Bash validator blocks assignment-prefixed stop gate execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks assignment-prefixed stop gate execution" \
    "VAR=1 ./scripts/rlcr-stop-gate.sh"

echo "Test 33: Bash validator blocks timeout-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks timeout-wrapped hook execution" \
    "timeout 1 bash hooks/loop-codex-stop-hook.sh"

echo "Test 34: Bash validator blocks nice-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks nice-wrapped hook execution" \
    "nice -n 10 bash hooks/loop-codex-stop-hook.sh"

echo "Test 35: Bash validator blocks nohup-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks nohup-wrapped hook execution" \
    "nohup bash hooks/loop-codex-stop-hook.sh"

echo "Test 36: Bash validator blocks strace-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks strace-wrapped hook execution" \
    "strace -f bash hooks/loop-codex-stop-hook.sh"

echo "Test 37: Bash validator blocks ltrace-wrapped hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks ltrace-wrapped hook execution" \
    "ltrace -f bash hooks/loop-codex-stop-hook.sh"

echo "Test 38: Bash validator blocks timeout+env hook execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks timeout+env hook execution" \
    "timeout --signal=TERM 1 env FOO=1 bash hooks/loop-codex-stop-hook.sh"

echo "Test 39: Bash validator blocks nohup+nice stop gate execution"
assert_hook_wrapper_blocked \
    "Bash validator blocks nohup+nice stop gate execution" \
    "nohup nice -n 5 ./scripts/rlcr-stop-gate.sh"

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

exit $TESTS_FAILED
