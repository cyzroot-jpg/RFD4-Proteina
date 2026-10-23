#!/usr/bin/env bash
#
# 所有测试脚本共享的测试辅助函数
#
# 用法：source "$SCRIPT_DIR/test-helpers.sh"（从 tests/）
# 用法：source "$SCRIPT_DIR/../test-helpers.sh"（从 tests/robustness/）
#

# ========================================
# 颜色
# ========================================

readonly TEST_RED='\033[0;31m'
readonly TEST_GREEN='\033[0;32m'
readonly TEST_YELLOW='\033[1;33m'
readonly TEST_NC='\033[0m'

# ========================================
# 测试计数器
# ========================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ========================================
# 测试结果函数
# ========================================

pass() {
    echo -e "${TEST_GREEN}PASS${TEST_NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${TEST_RED}FAIL${TEST_NC}: $1"
    if [[ $# -ge 2 ]]; then
        echo "  Expected: $2"
    fi
    if [[ $# -ge 3 ]]; then
        echo "  Got: $3"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    echo -e "${TEST_YELLOW}SKIP${TEST_NC}: $1"
    if [[ $# -ge 2 ]]; then
        echo "  Reason: $2"
    fi
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# ========================================
# 摘要函数
# ========================================

print_test_summary() {
    local title="${1:-Test Summary}"
    echo ""
    echo "========================================"
    echo "$title"
    echo "========================================"
    echo -e "Passed: ${TEST_GREEN}$TESTS_PASSED${TEST_NC}"
    echo -e "Failed: ${TEST_RED}$TESTS_FAILED${TEST_NC}"
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "Skipped: ${TEST_YELLOW}$TESTS_SKIPPED${TEST_NC}"
    fi
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${TEST_GREEN}All tests passed!${TEST_NC}"
        return 0
    else
        echo -e "${TEST_RED}Some tests failed!${TEST_NC}"
        return 1
    fi
}

# ========================================
# 测试目录设置
# ========================================

# 创建带有自动清理的临时测试目录
# 设置 TEST_DIR 变量
setup_test_dir() {
    TEST_DIR=$(mktemp -d)
    trap "rm -rf $TEST_DIR" EXIT
}

# 在目录中创建模拟 git 仓库
# 用法：init_test_git_repo "$dir"
init_test_git_repo() {
    local dir="$1"
    mkdir -p "$dir"
    cd "$dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test User"
    git config commit.gpgsign false
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial commit"
    cd - > /dev/null
}
