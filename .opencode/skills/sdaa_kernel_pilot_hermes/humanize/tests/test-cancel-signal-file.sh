#!/usr/bin/env bash
#
# cancel-rlcr-loop 信号文件机制测试
#
# 测试：
# - 正向：信号文件存在时允许 mv state.md 到 cancel-state.md
# - 反向：没有信号文件时阻止 mv state.md 到 cancel-state.md
# - 反向：即使有信号文件也阻止其他 state.md 修改
# - 反向：错误目录中的信号文件不授权取消
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 测试辅助函数
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; echo "  Expected: $2"; echo "  Got: $3"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# 设置测试环境
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# 引入公共库
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

echo "=== Test: Cancel Signal File Mechanism ==="
echo ""

# ========================================
# 设置：创建带有 state.md 的测试循环目录
# ========================================

setup_test_loop() {
    local test_name="$1"
    rm -rf "$TEST_DIR/.humanize" 2>/dev/null || true
    LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
    mkdir -p "$LOOP_DIR"
    cat > "$LOOP_DIR/state.md" << 'EOF'
---
current_round: 3
max_iterations: 10
plan_file: plan.md
plan_tracked: false
start_branch: main
base_branch: main
review_started: false
---
EOF
    export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

# 模拟钩子验证的辅助函数
# 使用 jq 正确编码命令字符串（处理特殊字符如 ${}）
run_bash_validator() {
    local command="$1"
    local hook_input
    hook_input=$(jq -n --arg cmd "$command" '{
        "tool_name": "Bash",
        "tool_input": {
            "command": $cmd
        }
    }')
    echo "$hook_input" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1
    return ${PIPESTATUS[1]}
}

# ========================================
# 正向测试 1：有信号文件时允许 mv
# ========================================

echo "POSITIVE TEST 1: mv state.md to cancel-state.md allowed when signal file exists"
setup_test_loop "positive-1"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    pass "mv state.md to cancel-state.md allowed with signal file"
else
    fail "mv allowed with signal" "exit 0" "exit $EXIT_CODE: $OUTPUT"
fi

# ========================================
# 正向测试 2：不同路径格式时允许 mv
# ========================================

echo "POSITIVE TEST 2: mv allowed with relative-style path"
setup_test_loop "positive-2"
touch "$LOOP_DIR/.cancel-requested"
# 使用带 ./ 前缀的命令测试略有不同的路径格式
COMMAND="mv ${LOOP_DIR}/./state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    pass "mv state.md allowed with ./ path format"
else
    fail "mv allowed with ./ path" "exit 0" "exit $EXIT_CODE: $OUTPUT"
fi

# ========================================
# 反向测试 1：没有信号文件时阻止 mv
# ========================================

echo "NEGATIVE TEST 1: mv state.md to cancel-state.md blocked without signal file"
setup_test_loop "negative-1"
# 不创建信号文件
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv state.md blocked without signal file"
else
    fail "mv blocked without signal" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 2：即使有信号文件也阻止其他 state.md 修改
# ========================================

echo "NEGATIVE TEST 2: echo > state.md blocked even with signal file"
setup_test_loop "negative-2"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="echo 'hack' > ${LOOP_DIR}/state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "echo > state.md blocked even with signal file"
else
    fail "echo blocked with signal" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 3：即使有信号也阻止 sed -i
# ========================================

echo "NEGATIVE TEST 3: sed -i state.md blocked even with signal file"
setup_test_loop "negative-3"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="sed -i 's/round: 3/round: 99/' ${LOOP_DIR}/state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "sed -i state.md blocked even with signal file"
else
    fail "sed blocked with signal" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 4：mv 到错误目标被阻止
# ========================================

echo "NEGATIVE TEST 4: mv state.md to wrong destination blocked even with signal"
setup_test_loop "negative-4"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/hacked-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv state.md to wrong destination blocked"
else
    fail "mv to wrong dest blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 5：错误目录中的信号文件
# ========================================

echo "NEGATIVE TEST 5: Signal file in wrong directory does not authorize"
setup_test_loop "negative-5"
# 在错误的目录（父目录）中创建信号文件
touch "$TEST_DIR/.humanize/rlcr/.cancel-requested"
# 不在活跃循环目录中
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Signal file in wrong directory does not authorize"
else
    fail "wrong dir signal blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 6：即使有信号也阻止 rm state.md
# ========================================

echo "NEGATIVE TEST 6: rm state.md blocked even with signal file"
setup_test_loop "negative-6"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="rm ${LOOP_DIR}/state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "rm state.md blocked even with signal file"
else
    fail "rm blocked with signal" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 7：命令注入尝试被阻止
# ========================================

echo "NEGATIVE TEST 7: Command injection via && blocked even with signal"
setup_test_loop "negative-7"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md && rm -rf /"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Command injection via && blocked"
else
    fail "injection via && blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 8：通过 ; 的命令注入被阻止
# ========================================

echo "NEGATIVE TEST 8: Command injection via semicolon blocked even with signal"
setup_test_loop "negative-8"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md; echo hacked"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Command injection via semicolon blocked"
else
    fail "injection via semicolon blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 9：mv state.md 到非 state.md 目标被阻止（绕过修复）
# ========================================

echo "NEGATIVE TEST 9: mv state.md to arbitrary destination blocked (even with signal)"
setup_test_loop "negative-9"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md /tmp/arbitrary-file.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv state.md to arbitrary destination blocked"
else
    fail "mv state.md bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 10：命令替换 $() 注入被阻止
# ========================================

echo "NEGATIVE TEST 10: Command substitution via \$() blocked even with signal"
setup_test_loop "negative-10"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md\$(rm -rf /)"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Command substitution via \$() blocked"
else
    fail "injection via \$() blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 11：反引号命令替换被阻止
# ========================================

echo "NEGATIVE TEST 11: Backtick command substitution blocked even with signal"
setup_test_loop "negative-11"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md\`rm -rf /\`"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Backtick command substitution blocked"
else
    fail "injection via backticks blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 12：换行符分隔的命令注入被阻止
# ========================================
# 注意：直接测试 is_cancel_authorized 辅助函数，因为 JSON 解析
# 命令字符串中的字面换行符并不简单

echo "NEGATIVE TEST 12: Newline-separated command injection blocked in helper"
setup_test_loop "negative-12"
touch "$LOOP_DIR/.cancel-requested"
# 带有嵌入换行符的命令 - 直接测试辅助函数
COMMAND_WITH_NEWLINE="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md
rm -rf /"
COMMAND_LOWER=$(to_lower "$COMMAND_WITH_NEWLINE")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "injection via newline blocked" "returns 1" "returns 0"
else
    pass "Newline-separated command injection blocked"
fi

# ========================================
# 正向测试 3：允许带单引号路径的 mv
# ========================================
# 测试带引号的路径是否正常工作
# 注意：这里使用单引号，因为双引号会破坏测试工具中的 JSON 解析

echo "POSITIVE TEST 3: mv with single-quoted paths allowed with signal"
setup_test_loop "positive-3"
touch "$LOOP_DIR/.cancel-requested"
# 使用单引号包围路径以测试带引号路径处理
COMMAND="mv '${LOOP_DIR}/state.md' '${LOOP_DIR}/cancel-state.md'"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    pass "mv with single-quoted paths allowed with signal file"
else
    fail "mv with quoted paths" "exit 0" "exit $EXIT_CODE: $OUTPUT"
fi

# ========================================
# 反向测试 13：带 -- 选项的 mv 被阻止（state.md 作为源）
# ========================================

echo "NEGATIVE TEST 13: mv -- state.md /tmp/foo blocked (options before source)"
setup_test_loop "negative-13"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv -- ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv -- state.md /tmp/foo blocked"
else
    fail "mv -- state.md bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 14：cp -f state.md 被阻止（选项在源之前）
# ========================================

echo "NEGATIVE TEST 14: cp -f state.md /backup blocked (options before source)"
setup_test_loop "negative-14"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="cp -f ${LOOP_DIR}/state.md /tmp/backup.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "cp -f state.md blocked"
else
    fail "cp -f state.md bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 15：带 3 个参数的 mv 被阻止（额外参数）
# ========================================

echo "NEGATIVE TEST 15: mv state.md /tmp cancel-state.md blocked (3 args)"
setup_test_loop "negative-15"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv ${LOOP_DIR}/state.md /tmp ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv with 3 args (extra argument) blocked"
else
    fail "mv 3 args blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 正向测试 4：允许字面 $LOOP_DIR 风格命令（文档化格式）
# ========================================
# 测试带有 ${LOOP_DIR} 变量语法的文档化取消命令格式
# is_cancel_authorized 函数将其规范化为实际路径
# 重要：我们传递字面 ${loop_dir} 字符串而不预展开，
# 以验证规范化是否正确工作

echo "POSITIVE TEST 4: Literal LOOP_DIR variable syntax allowed with signal (helper)"
setup_test_loop "positive-4"
touch "$LOOP_DIR/.cancel-requested"
# 传递字面 ${loop_dir} 字符串以测试 is_cancel_authorized 中的规范化
# 注意：command_lower 接收小写的变量名
COMMAND_LOWER='mv "${loop_dir}state.md" "${loop_dir}cancel-state.md"'
# 不要预展开 - 辅助函数应该将 ${loop_dir} 规范化为实际路径

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    pass "Literal LOOP_DIR variable syntax allowed (helper normalizes)"
else
    fail "LOOP_DIR variable syntax (helper)" "returns 0" "returns 1"
fi

# ========================================
# 正向测试 5：通过验证器的字面 LOOP_DIR（文档化格式）
# ========================================
# 使用字面 ${LOOP_DIR} 变量语法测试完整的验证器流程
# 这验证了文档化的取消命令格式端到端工作

echo "POSITIVE TEST 5: Literal LOOP_DIR through validator with signal"
setup_test_loop "positive-5"
touch "$LOOP_DIR/.cancel-requested"
# 传递带有 ${loop_dir} 的字面命令（小写用于 command_lower 匹配）
# 注意：run_bash_validator 将命令小写，因此我们使用小写变量名
COMMAND='mv "${loop_dir}state.md" "${loop_dir}cancel-state.md"'

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Literal LOOP_DIR through validator allowed"
else
    fail "LOOP_DIR through validator" "exit 0" "exit $EXIT_CODE: $OUTPUT"
fi

# ========================================
# 反向测试 16：mv -- 'state.md' 被阻止（带引号的相对路径）
# ========================================
# 使用单引号，因为双引号会破坏测试工具中的 JSON 解析

echo "NEGATIVE TEST 16: mv -- quoted relative state.md blocked"
setup_test_loop "negative-16"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv -- 'state.md' /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "mv -- quoted relative state.md blocked"
else
    fail "quoted relative state.md blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 17：state.md 之前的额外参数被阻止
# ========================================

echo "NEGATIVE TEST 17: mv /tmp/extra state.md cancel-state.md blocked (extra arg before)"
setup_test_loop "negative-17"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="mv /tmp/extra.txt ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Extra arg before state.md blocked"
else
    fail "extra arg before state.md blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 18：隐藏变量如 ${IFS} 被阻止
# ========================================

echo "NEGATIVE TEST 18: Hidden variable injection blocked"
setup_test_loop "negative-18"
touch "$LOOP_DIR/.cancel-requested"
# Try to use ${IFS} to hide extra arguments
COMMAND_LOWER='mv ${LOOP_DIR}/state.md${ifs}extra ${LOOP_DIR}/cancel-state.md'
# Replace LOOP_DIR but leave ${ifs}
COMMAND_LOWER="${COMMAND_LOWER//\$\{LOOP_DIR\}/$LOOP_DIR}"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "hidden variable blocked" "returns 1" "returns 0"
else
    pass "Hidden variable injection blocked"
fi

# ========================================
# 反向测试 19：sudo mv state.md 被阻止（前缀绕过尝试）
# ========================================

echo "NEGATIVE TEST 19: sudo mv state.md blocked (prefix bypass)"
setup_test_loop "negative-19"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="sudo mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "sudo mv state.md blocked"
else
    fail "sudo mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 20：前导空格的 mv state.md 被阻止
# ========================================

echo "NEGATIVE TEST 20: Leading whitespace mv state.md blocked"
setup_test_loop "negative-20"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="  mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Leading whitespace mv state.md blocked"
else
    fail "whitespace mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 21：env 前缀的 mv state.md 被阻止
# ========================================

echo "NEGATIVE TEST 21: env prefix mv state.md blocked"
setup_test_loop "negative-21"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="env PATH=/bin mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "env prefix mv state.md blocked"
else
    fail "env mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 22：sudo -u root mv state.md 被阻止（带选项的前缀）
# ========================================

echo "NEGATIVE TEST 22: sudo -u root mv state.md blocked (prefix with options)"
setup_test_loop "negative-22"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="sudo -u root mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "sudo -u root mv state.md blocked"
else
    fail "sudo -u root mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 23：command -- mv state.md 被阻止（带选项的前缀）
# ========================================

echo "NEGATIVE TEST 23: command -- mv state.md blocked (prefix with options)"
setup_test_loop "negative-23"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="command -- mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "command -- mv state.md blocked"
else
    fail "command -- mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 24：通过分号链接的命令被阻止
# ========================================

echo "NEGATIVE TEST 24: true; mv state.md blocked (chained via semicolon)"
setup_test_loop "negative-24"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="true; mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Chained command via semicolon blocked"
else
    fail "chained via semicolon blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 25：通过 && 链接的命令被阻止
# ========================================

echo "NEGATIVE TEST 25: true && mv state.md blocked (chained via &&)"
setup_test_loop "negative-25"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="true && mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Chained command via && blocked"
else
    fail "chained via && blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 26：通过 || 链接的命令被阻止
# ========================================

echo "NEGATIVE TEST 26: false || mv state.md blocked (chained via ||)"
setup_test_loop "negative-26"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="false || mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Chained command via || blocked"
else
    fail "chained via || blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 27：通过管道链接的命令被阻止
# ========================================

echo "NEGATIVE TEST 27: echo foo | mv state.md blocked (chained via pipe)"
setup_test_loop "negative-27"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="echo foo | mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Chained command via pipe blocked"
else
    fail "chained via pipe blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 28：后台运算符 & 绕过被阻止
# ========================================

echo "NEGATIVE TEST 28: true & mv state.md blocked (background operator)"
setup_test_loop "negative-28"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="true & mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Background operator & bypass blocked"
else
    fail "background & bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 29：无尾部空格的后台 &（true& mv）
# ========================================

echo "NEGATIVE TEST 29: true& mv state.md blocked (no trailing space after &)"
setup_test_loop "negative-29"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="true& mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Background & without trailing space blocked"
else
    fail "true& mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 30：无前导空格的后台 &（true &mv）
# ========================================

echo "NEGATIVE TEST 30: true &mv state.md blocked (no leading space before &)"
setup_test_loop "negative-30"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="true &mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Background & without leading space blocked"
else
    fail "true &mv bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 31：管道+stderr |& 绕过被阻止
# ========================================

echo "NEGATIVE TEST 31: echo foo |& mv state.md blocked (pipe+stderr)"
setup_test_loop "negative-31"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="echo foo |& mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Pipe+stderr |& bypass blocked"
else
    fail "pipe+stderr |& bypass blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 32：sh -c 包装器绕过被阻止
# ========================================

echo "NEGATIVE TEST 32: sh -c wrapper bypass blocked"
setup_test_loop "negative-32"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="sh -c 'mv ${LOOP_DIR}/state.md /tmp/foo.txt'"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "sh -c wrapper bypass blocked"
else
    fail "sh -c wrapper blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 33：bash -c 包装器绕过被阻止
# ========================================

echo "NEGATIVE TEST 33: bash -c wrapper bypass blocked"
setup_test_loop "negative-33"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="bash -c 'mv ${LOOP_DIR}/state.md /tmp/foo.txt'"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "bash -c wrapper bypass blocked"
else
    fail "bash -c wrapper blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 34：重定向前缀的 mv state.md 被阻止（2>/tmp/x mv）
# ========================================

echo "NEGATIVE TEST 34: 2>/tmp/x mv state.md blocked (redirection prefix)"
setup_test_loop "negative-34"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="2>/tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Redirection-prefixed 2>/tmp/x mv blocked"
else
    fail "redirection 2>/tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 35：重定向前缀的 mv state.md 被阻止（>/tmp/x mv）
# ========================================

echo "NEGATIVE TEST 35: >/tmp/x mv state.md blocked (redirection prefix)"
setup_test_loop "negative-35"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">/tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Redirection-prefixed >/tmp/x mv blocked"
else
    fail "redirection >/tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 36：重定向前缀的 mv state.md 被阻止（2>&1 mv）
# ========================================

echo "NEGATIVE TEST 36: 2>&1 mv state.md blocked (fd redirection prefix)"
setup_test_loop "negative-36"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="2>&1 mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Redirection-prefixed 2>&1 mv blocked"
else
    fail "redirection 2>&1 mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 37：带空格的重定向前缀的 mv state.md 被阻止（2> /tmp/x mv）
# ========================================

echo "NEGATIVE TEST 37: 2> /tmp/x mv state.md blocked (spaced redirection)"
setup_test_loop "negative-37"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="2> /tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Spaced redirection 2> /tmp/x mv blocked"
else
    fail "spaced redirection 2> /tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 38：&> 重定向前缀的 mv state.md 被阻止（&>/tmp/x mv）
# ========================================

echo "NEGATIVE TEST 38: &>/tmp/x mv state.md blocked (&> redirection)"
setup_test_loop "negative-38"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&>/tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "&> redirection &>/tmp/x mv blocked"
else
    fail "&> redirection &>/tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 39：带空格的 &> 重定向前缀的 mv state.md 被阻止（&> /tmp/x mv）
# ========================================

echo "NEGATIVE TEST 39: &> /tmp/x mv state.md blocked (spaced &> redirection)"
setup_test_loop "negative-39"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&> /tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Spaced &> redirection &> /tmp/x mv blocked"
else
    fail "spaced &> redirection &> /tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 40：追加重定向前缀的 mv state.md 被阻止（>>/tmp/x mv）
# ========================================

echo "NEGATIVE TEST 40: >>/tmp/x mv state.md blocked (append redirection)"
setup_test_loop "negative-40"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">>/tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Append redirection >>/tmp/x mv blocked"
else
    fail "append redirection >>/tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 41：带空格的追加重定向前缀的 mv state.md 被阻止（>> /tmp/x mv）
# ========================================

echo "NEGATIVE TEST 41: >> /tmp/x mv state.md blocked (spaced append redirection)"
setup_test_loop "negative-41"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">> /tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Spaced append redirection >> /tmp/x mv blocked"
else
    fail "spaced append redirection >> /tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 42：stderr 追加重定向前缀的 mv state.md 被阻止（2>> /tmp/x mv）
# ========================================

echo "NEGATIVE TEST 42: 2>> /tmp/x mv state.md blocked (stderr append redirection)"
setup_test_loop "negative-42"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="2>> /tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Stderr append redirection 2>> /tmp/x mv blocked"
else
    fail "stderr append redirection 2>> /tmp/x mv blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 43：双引号重定向目标被阻止（>> "/tmp/x y" mv）
# ========================================

echo "NEGATIVE TEST 43: >> \"/tmp/x y\" mv state.md blocked (double-quoted target)"
setup_test_loop "negative-43"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">> \"/tmp/x y\" mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Double-quoted redirection target >> \"/tmp/x y\" mv blocked"
else
    fail "double-quoted redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 44：单引号重定向目标被阻止（>> '/tmp/x y' mv）
# ========================================

echo "NEGATIVE TEST 44: >> '/tmp/x y' mv state.md blocked (single-quoted target)"
setup_test_loop "negative-44"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">> '/tmp/x y' mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Single-quoted redirection target >> '/tmp/x y' mv blocked"
else
    fail "single-quoted redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 45：双引号 &> 重定向目标被阻止（&> "/tmp/x y" mv）
# ========================================

echo "NEGATIVE TEST 45: &> \"/tmp/x y\" mv state.md blocked (double-quoted &> target)"
setup_test_loop "negative-45"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&> \"/tmp/x y\" mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Double-quoted &> redirection target blocked"
else
    fail "double-quoted &> redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 46：&>> 带空格目标被阻止（&>> /tmp/x mv）
# ========================================

echo "NEGATIVE TEST 46: &>> /tmp/x mv state.md blocked (&>> spaced target)"
setup_test_loop "negative-46"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&>> /tmp/x mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "&>> spaced target blocked"
else
    fail "&>> spaced target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 47：转义空格重定向目标被阻止（>> /tmp/x\ y mv）
# ========================================

echo "NEGATIVE TEST 47: >> /tmp/x\\ y mv state.md blocked (escaped-space target)"
setup_test_loop "negative-47"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">> /tmp/x\\ y mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Escaped-space redirection target blocked"
else
    fail "escaped-space redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 48：带转义空格目标的 &>> 被阻止（&>> /tmp/x\ y mv）
# ========================================

echo "NEGATIVE TEST 48: &>> /tmp/x\\ y mv state.md blocked (&>> escaped-space target)"
setup_test_loop "negative-48"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&>> /tmp/x\\ y mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "&>> escaped-space target blocked"
else
    fail "&>> escaped-space target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 49：ANSI-C 引用重定向目标被阻止（>> $'/tmp/x y' mv）
# ========================================

echo "NEGATIVE TEST 49: >> \$'/tmp/x y' mv state.md blocked (ANSI-C quoting)"
setup_test_loop "negative-49"
touch "$LOOP_DIR/.cancel-requested"
COMMAND=">> \$'/tmp/x y' mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "ANSI-C quoting redirection target blocked"
else
    fail "ANSI-C quoting redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 50：ANSI-C 引用 &> 重定向目标被阻止（&> $'/tmp/x y' mv）
# ========================================

echo "NEGATIVE TEST 50: &> \$'/tmp/x y' mv state.md blocked (ANSI-C quoting &>)"
setup_test_loop "negative-50"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&> \$'/tmp/x y' mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "ANSI-C quoting &> redirection target blocked"
else
    fail "ANSI-C quoting &> redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 51：ANSI-C 引用 &>> 重定向目标被阻止（&>> $'/tmp/x y' mv）
# ========================================

echo "NEGATIVE TEST 51: &>> \$'/tmp/x y' mv state.md blocked (ANSI-C quoting &>>)"
setup_test_loop "negative-51"
touch "$LOOP_DIR/.cancel-requested"
COMMAND="&>> \$'/tmp/x y' mv ${LOOP_DIR}/state.md /tmp/foo.txt"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "ANSI-C quoting &>> redirection target blocked"
else
    fail "ANSI-C quoting &>> redirection target blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 52：即使有信号也阻止无关的 state.md 路径
# ========================================

echo "NEGATIVE TEST 52: mv /tmp/state.md /tmp/cancel-state.md blocked (wrong directory)"
setup_test_loop "negative-52"
touch "$LOOP_DIR/.cancel-requested"
# 尝试移动活跃循环目录外的 state.md - 应该被阻止
COMMAND="mv /tmp/state.md /tmp/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 2 ]]; then
    pass "Unrelated state.md path blocked even with signal"
else
    fail "unrelated state.md path blocked" "exit 2" "exit $EXIT_CODE"
fi

# ========================================
# 反向测试 53：无活跃循环（无 state.md）
# ========================================

echo "NEGATIVE TEST 53: Validator allows commands when no active loop"
rm -rf "$TEST_DIR/.humanize" 2>/dev/null || true
LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$LOOP_DIR"
# 未创建 state.md - 循环不活跃
COMMAND="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"

set +e
OUTPUT=$(run_bash_validator "$COMMAND")
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Commands allowed when no active loop (no state.md)"
else
    fail "no active loop allows" "exit 0" "exit $EXIT_CODE"
fi

# ========================================
# 测试 is_cancel_authorized 辅助函数
# ========================================

echo ""
echo "=== Test: is_cancel_authorized Helper Function ==="
echo ""

# 直接测试辅助函数
echo "HELPER TEST 1: is_cancel_authorized returns true with signal and correct command"
setup_test_loop "helper-1"
touch "$LOOP_DIR/.cancel-requested"
COMMAND_LOWER="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    pass "is_cancel_authorized returns true with signal and correct command"
else
    fail "helper true case" "returns 0" "returns 1"
fi

echo "HELPER TEST 2: is_cancel_authorized returns false without signal file"
setup_test_loop "helper-2"
# 没有信号文件
COMMAND_LOWER="mv ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper no signal" "returns 1" "returns 0"
else
    pass "is_cancel_authorized returns false without signal file"
fi

echo "HELPER TEST 3: is_cancel_authorized returns false with wrong command"
setup_test_loop "helper-3"
touch "$LOOP_DIR/.cancel-requested"
COMMAND_LOWER="rm ${LOOP_DIR}/state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper wrong cmd" "returns 1" "returns 0"
else
    pass "is_cancel_authorized returns false with wrong command"
fi

echo "HELPER TEST 4: is_cancel_authorized returns false with 3 arguments"
setup_test_loop "helper-4"
touch "$LOOP_DIR/.cancel-requested"
COMMAND_LOWER="mv ${LOOP_DIR}/state.md /tmp ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper 3 args" "returns 1" "returns 0"
else
    pass "is_cancel_authorized returns false with 3 arguments (extra arg)"
fi

echo "HELPER TEST 5: is_cancel_authorized allows quoted paths with signal"
setup_test_loop "helper-5"
touch "$LOOP_DIR/.cancel-requested"
COMMAND_LOWER="mv \"${LOOP_DIR}/state.md\" \"${LOOP_DIR}/cancel-state.md\""
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    pass "is_cancel_authorized allows quoted paths"
else
    fail "helper quoted paths" "returns 0" "returns 1"
fi

echo "HELPER TEST 6: is_cancel_authorized rejects extra args before state.md"
setup_test_loop "helper-6"
touch "$LOOP_DIR/.cancel-requested"
COMMAND_LOWER="mv /tmp/extra.txt ${LOOP_DIR}/state.md ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper extra arg before" "returns 1" "returns 0"
else
    pass "is_cancel_authorized rejects extra args before state.md"
fi

echo "HELPER TEST 7: is_cancel_authorized rejects hidden variables"
setup_test_loop "helper-7"
touch "$LOOP_DIR/.cancel-requested"
# 带有狡猾的 ${ifs} 变量的命令
COMMAND_LOWER="mv ${LOOP_DIR}/state.md\${ifs}extra ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper hidden var" "returns 1" "returns 0"
else
    pass "is_cancel_authorized rejects hidden variables"
fi

echo "HELPER TEST 8: is_cancel_authorized accepts symlinked-prefix path"
# Regression test: when the user supplies the active-loop path through a
# symlinked prefix (e.g. /var/... on macOS resolves to /private/var/...),
# the authorization check must canonicalize both sides so it still matches.
# We simulate the scenario by creating an all-lowercase sibling layout
# (mktemp dirs contain mixed case, which would defeat realpath once the
# command is lowercased on case-sensitive filesystems), then symlinking
# from there back to the real loop dir.
setup_test_loop "helper-8"
touch "$LOOP_DIR/.cancel-requested"

SYMLINK_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/humanize-symlink-XXXXXXXX" | tr '[:upper:]' '[:lower:]')
# mktemp already lowercases when we pipe it; re-run if the resulting dir does
# not actually exist (shouldn't happen but defensive for portability).
[[ -d "$SYMLINK_ROOT" ]] || { rm -rf "$SYMLINK_ROOT" 2>/dev/null; SYMLINK_ROOT="${TMPDIR:-/tmp}/humanize-symlink-lowercase-$$"; mkdir -p "$SYMLINK_ROOT"; }

SYMLINK_LOOP_DIR="$SYMLINK_ROOT/via-symlink"
ln -sfn "$LOOP_DIR" "$SYMLINK_LOOP_DIR"

CANONICAL_LOOP_DIR="$(cd "$LOOP_DIR" && pwd -P)"
COMMAND_LOWER="mv ${SYMLINK_LOOP_DIR}/state.md ${SYMLINK_LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$CANONICAL_LOOP_DIR" "$COMMAND_LOWER"; then
    pass "is_cancel_authorized accepts symlinked-prefix path after realpath"
else
    fail "helper symlink prefix" "returns 0 (authorized)" "returns non-zero"
fi

rm -rf "$SYMLINK_ROOT" 2>/dev/null || true

echo "HELPER TEST 9: is_cancel_authorized rejects destination symlink alias"
# Regression test for a P1 security issue: if the destination argument is a
# symlink that points at <loop>/cancel-state.md, canonicalizing the full
# path (leaf dereferenced) would let the alias pass authorization. `mv`
# would then operate on the link path itself, corrupting loop state and
# leaking state.md contents outside the loop dir. The fix resolves symlinks
# only in the parent directory and preserves the basename verbatim.
setup_test_loop "helper-9"
touch "$LOOP_DIR/.cancel-requested"
# Create the target file so the symlink would resolve if the prefix-only
# canonicalizer were relaxed back to full canonicalization.
touch "$LOOP_DIR/cancel-state.md"
ln -sfn "$LOOP_DIR/cancel-state.md" "$TEST_DIR/dest-alias"

COMMAND_LOWER="mv ${LOOP_DIR}/state.md ${TEST_DIR}/dest-alias"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper dest symlink alias" "returns non-zero (rejected)" "returns 0 (authorized)"
else
    pass "is_cancel_authorized rejects destination symlink alias"
fi
rm -f "$TEST_DIR/dest-alias" "$LOOP_DIR/cancel-state.md"

echo "HELPER TEST 10: is_cancel_authorized rejects source symlink alias"
# Regression test for a P1 security issue: if the source argument is a
# symlink aliasing <loop>/state.md, dereferencing the leaf would let it
# pass authorization. The on-disk symlink check (src_original) below
# would still catch this specific case because it probes the real path,
# but we defend in depth: the path comparison must reject the alias on
# its own.
setup_test_loop "helper-10"
touch "$LOOP_DIR/.cancel-requested"
ln -sfn "$LOOP_DIR/state.md" "$TEST_DIR/src-alias"

COMMAND_LOWER="mv ${TEST_DIR}/src-alias ${LOOP_DIR}/cancel-state.md"
COMMAND_LOWER=$(to_lower "$COMMAND_LOWER")

if is_cancel_authorized "$LOOP_DIR" "$COMMAND_LOWER"; then
    fail "helper src symlink alias" "returns non-zero (rejected)" "returns 0 (authorized)"
else
    pass "is_cancel_authorized rejects source symlink alias"
fi
rm -f "$TEST_DIR/src-alias"

# ========================================
# 总结
# ========================================

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

exit $TESTS_FAILED
