#!/usr/bin/env bash
#
# loop-common.sh 中 command_modifies_file 函数的测试脚本
#
# 测试用于检测文件修改命令的正则表达式模式，
# 确保通过 Bash 正确阻止文件写入。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

TESTS_PASSED=0
TESTS_FAILED=0

# 测试辅助函数
pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Command: $2"
    echo "  Expected: $3"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# 断言命令应该被检测为修改目标文件
assert_modifies() {
    local command="$1"
    local pattern="${2:-goal-tracker\\.md}"
    local command_lower
    command_lower=$(to_lower "$command")

    if command_modifies_file "$command_lower" "$pattern"; then
        pass "Correctly detected modification: $command"
    else
        fail "Should detect modification" "$command" "should match pattern"
    fi
}

# 断言命令不应该被检测为修改目标文件
assert_not_modifies() {
    local command="$1"
    local pattern="${2:-goal-tracker\\.md}"
    local command_lower
    command_lower=$(to_lower "$command")

    if command_modifies_file "$command_lower" "$pattern"; then
        fail "Should NOT detect modification" "$command" "should not match pattern"
    else
        pass "Correctly ignored: $command"
    fi
}

echo "========================================"
echo "Testing command_modifies_file patterns"
echo "========================================"
echo ""

# ========================================
# 测试组 1：重定向运算符（> >>）
# ========================================
echo "Test Group 1: Redirection operators"
echo ""

assert_modifies "echo x > goal-tracker.md"
assert_modifies "echo x >> goal-tracker.md"
assert_modifies "cat foo >> goal-tracker.md"
assert_modifies "printf 'text' > goal-tracker.md"
assert_modifies "echo 'data' > /path/to/goal-tracker.md"
assert_modifies "ECHO X > GOAL-TRACKER.MD"

# ========================================
# 测试组 2：tee 命令
# ========================================
echo ""
echo "Test Group 2: tee command"
echo ""

assert_modifies "tee goal-tracker.md"
assert_modifies "tee -a goal-tracker.md"
assert_modifies "echo x | tee goal-tracker.md"
assert_modifies "echo x | tee -a goal-tracker.md"
assert_modifies "cat file | tee /path/to/goal-tracker.md"

# ========================================
# 测试组 3：就地编辑器（sed、awk、perl）
# ========================================
echo ""
echo "Test Group 3: In-place editors"
echo ""

assert_modifies "sed -i 's/x/y/' goal-tracker.md"
assert_modifies "sed -i.bak 's/x/y/' goal-tracker.md"
assert_modifies "sed -i '' 's/x/y/' goal-tracker.md"
assert_modifies "awk -i inplace '{print}' goal-tracker.md"
assert_modifies "perl -i -pe 's/x/y/' goal-tracker.md"
assert_modifies "perl -pie 's/x/y/' goal-tracker.md"

# ========================================
# 测试组 4：文件操作（mv、cp、rm）
# ========================================
echo ""
echo "Test Group 4: File operations"
echo ""

assert_modifies "mv temp.md goal-tracker.md"
assert_modifies "cp backup.md goal-tracker.md"
assert_modifies "rm goal-tracker.md"
assert_modifies "rm -f goal-tracker.md"
assert_modifies "rm -rf goal-tracker.md"
assert_modifies "mv /tmp/new.md /path/to/goal-tracker.md"

# ========================================
# 测试组 5：其他修改器（dd、truncate、exec）
# ========================================
echo ""
echo "Test Group 5: Other modifiers"
echo ""

assert_modifies "dd if=/dev/zero of=goal-tracker.md"
assert_modifies "truncate -s 0 goal-tracker.md"
assert_modifies "exec 3> goal-tracker.md"
assert_modifies "printf '%s' data > goal-tracker.md"

# ========================================
# 测试组 6：不应该被捕获的命令
# ========================================
echo ""
echo "Test Group 6: Commands that should NOT be caught (false positives)"
echo ""

assert_not_modifies "cat goal-tracker.md"
assert_not_modifies "grep goal goal-tracker.md"
assert_not_modifies "head -10 goal-tracker.md"
assert_not_modifies "tail -10 goal-tracker.md"
assert_not_modifies "wc -l goal-tracker.md"
assert_not_modifies "less goal-tracker.md"
assert_not_modifies "echo goal-tracker.md"
assert_not_modifies "ls goal-tracker.md"
assert_not_modifies "file goal-tracker.md"
assert_not_modifies "stat goal-tracker.md"
assert_not_modifies "diff goal-tracker.md other.md"

# ========================================
# 测试组 7：边界情况
# ========================================
echo ""
echo "Test Group 7: Edge cases"
echo ""

# 不同位置的文件名
assert_modifies "> goal-tracker.md"
assert_modifies "echo test >goal-tracker.md"

# 多个源文件到单个目标
# 注意："cp file1.md file2.md goal-tracker.md"（多个源）不会被检测，
# 因为模式期望 "cp src dest" 格式。这是一个已知的限制。
# 更常见的 "cp src goal-tracker.md" 情况会被检测到。

# 使用变量（应该仍然匹配字面模式）
assert_not_modifies 'echo x > $FILE'
assert_not_modifies "cat file.md | grep pattern"

# ========================================
# 测试组 8：状态文件模式
# ========================================
echo ""
echo "Test Group 8: State file patterns"
echo ""

assert_modifies "echo x > state.md" "state\\.md"
assert_modifies "sed -i 's/round: 0/round: 99/' state.md" "state\\.md"
assert_not_modifies "cat state.md" "state\\.md"

# ========================================
# 测试组 9：摘要文件模式
# ========================================
echo ""
echo "Test Group 9: Summary file patterns"
echo ""

assert_modifies "echo x > round-5-summary.md" "round-[0-9]+-summary\\.md"
assert_modifies "cat data >> round-10-summary.md" "round-[0-9]+-summary\\.md"
assert_not_modifies "cat round-5-summary.md" "round-[0-9]+-summary\\.md"

# ========================================
# 总结
# ========================================
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
