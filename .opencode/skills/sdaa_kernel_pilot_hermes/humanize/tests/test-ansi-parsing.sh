#!/usr/bin/env bash
#
# 测试运行器输出解析中的 ANSI 转义码处理
#
# 测试 run-all-tests.sh 中使用的可移植 ANSI 剥离方法，
# 确保在 GNU (Linux) 和 BSD (macOS) sed 上都能正确工作。
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "========================================"
echo "Testing ANSI Escape Code Parsing"
echo "========================================"
echo ""

# 测试 run-all-tests.sh 中使用的可移植 ANSI 剥离方法
# 使用 $'\033'（ANSI-C 引用），在 GNU 和 BSD sed 上都能工作

# ========================================
# 测试 1：基本 ANSI 颜色剥离
# ========================================
echo "Test 1: Basic ANSI color stripping"
input=$'Passed: \033[0;32m43\033[0m'
esc=$'\033'
result=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
expected="Passed: 43"
if [[ "$result" == "$expected" ]]; then
    pass "Basic color stripping works"
else
    fail "Basic color stripping" "$expected" "$result"
fi

# ========================================
# 测试 2：一行中的多个颜色
# ========================================
echo ""
echo "Test 2: Multiple colors in one line"
input=$'\033[1mBold\033[0m and \033[0;31mRed\033[0m and \033[0;32mGreen\033[0m'
result=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
expected="Bold and Red and Green"
if [[ "$result" == "$expected" ]]; then
    pass "Multiple colors stripped correctly"
else
    fail "Multiple colors" "$expected" "$result"
fi

# ========================================
# 测试 3：从彩色输出中提取 Passed 计数
# ========================================
echo ""
echo "Test 3: Extract Passed count from colored output"
input=$'Passed: \033[0;32m357\033[0m'
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
passed=$(echo "$output_stripped" | grep -oE 'Passed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || echo "0")
if [[ "$passed" == "357" ]]; then
    pass "Passed count extracted correctly"
else
    fail "Passed count extraction" "357" "$passed"
fi

# ========================================
# 测试 4：从彩色输出中提取 Failed 计数
# ========================================
echo ""
echo "Test 4: Extract Failed count from colored output"
input=$'Failed: \033[0;31m5\033[0m'
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
failed=$(echo "$output_stripped" | grep -oE 'Failed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || echo "0")
if [[ "$failed" == "5" ]]; then
    pass "Failed count extracted correctly"
else
    fail "Failed count extraction" "5" "$failed"
fi

# ========================================
# 测试 5：零计数提取
# ========================================
echo ""
echo "Test 5: Zero count extraction"
input=$'Failed: \033[0;31m0\033[0m'
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
failed=$(echo "$output_stripped" | grep -oE 'Failed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || echo "0")
if [[ "$failed" == "0" ]]; then
    pass "Zero count extracted correctly"
else
    fail "Zero count extraction" "0" "$failed"
fi

# ========================================
# 测试 6：复杂多行输出模拟
# ========================================
echo ""
echo "Test 6: Complex multi-line output (simulating test suite)"
input=$'========================================
Test Summary
========================================
Passed: \033[0;32m43\033[0m
Failed: \033[0;31m2\033[0m

\033[0;31mSome tests failed!\033[0m'
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
passed=$(echo "$output_stripped" | grep -oE 'Passed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | tail -1 || echo "0")
failed=$(echo "$output_stripped" | grep -oE 'Failed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | tail -1 || echo "0")
if [[ "$passed" == "43" && "$failed" == "2" ]]; then
    pass "Complex multi-line output parsed correctly"
else
    fail "Complex multi-line output" "passed=43, failed=2" "passed=$passed, failed=$failed"
fi

# ========================================
# 测试 7：无 ANSI 码（纯文本）
# ========================================
echo ""
echo "Test 7: No ANSI codes (plain text)"
input="Passed: 100"
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
passed=$(echo "$output_stripped" | grep -oE 'Passed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || echo "0")
if [[ "$passed" == "100" ]]; then
    pass "Plain text without ANSI codes works"
else
    fail "Plain text parsing" "100" "$passed"
fi

# ========================================
# 测试 8：粗体和颜色组合
# ========================================
echo ""
echo "Test 8: Bold and color combined"
input=$'\033[1;32mPassed: 50\033[0m'
output_stripped=$(echo "$input" | sed "s/${esc}\\[[0-9;]*m//g")
passed=$(echo "$output_stripped" | grep -oE 'Passed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || echo "0")
if [[ "$passed" == "50" ]]; then
    pass "Bold+color combined works"
else
    fail "Bold+color combined" "50" "$passed"
fi

# ========================================
# 摘要
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
