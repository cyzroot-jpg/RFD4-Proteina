#!/usr/bin/env bash
#
# 代码审查日志文件分析行为的测试
#
# 测试 detect_review_issues() 是否正确地：
# - 检测每行前 10 个字符中的 [P0-9] 模式
# - 仅扫描日志文件的最后 50 行
# - 从第一个匹配行提取内容到末尾
# - 返回适当的退出码
#
# 被测试的算法：
# 1. 扫描日志文件的最后 50 行
# 2. 找到前 10 个字符中出现 [P?]（? 是数字）的第一行
# 3. 如果找到：从该行提取到末尾并输出
# 4. 如果未找到：无问题，返回 1
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# 设置隔离的缓存目录
export XDG_CACHE_HOME="$TEST_DIR/.cache"
mkdir -p "$XDG_CACHE_HOME"

# 加载包含 detect_review_issues 的 loop-common.sh
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

echo "=== Test: Code Review Log File Analysis ==="
echo ""

# 设置测试循环目录结构
setup_test_env() {
    LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
    CACHE_DIR="$XDG_CACHE_HOME/humanize/codex-review"
    mkdir -p "$LOOP_DIR"
    mkdir -p "$CACHE_DIR"
    export LOOP_DIR CACHE_DIR
}

# ========================================
# 测试 1：前 10 个字符中的 [P?] - 应该检测到
# ========================================
echo "Test 1: detect_review_issues finds [P?] in first 10 characters"
setup_test_env

cat > "$CACHE_DIR/round-1-codex-review.log" << 'EOF'
Some debug output from codex
More debug lines
thinking about the code
- [P1] Missing null check - /path/to/file.py:42-45
  The function does not check for null input before processing.
- [P2] Another issue - /path/to/other.py:10-15
  Description of the issue.
EOF

set +e
OUTPUT=$(detect_review_issues 1 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P1\]' && echo "$OUTPUT" | grep -q '\[P2\]'; then
    pass "Issues detected with [P?] in first 10 chars"
else
    fail "Issues in first 10 chars" "return 0, output contains [P1] and [P2]" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 2：[P?] 不在前 10 个字符中 - 不应该检测到
# ========================================
echo "Test 2: detect_review_issues ignores [P?] not in first 10 characters"
setup_test_env

cat > "$CACHE_DIR/round-2-codex-review.log" << 'EOF'
Some debug output from codex
More debug lines
This line has [P1] but not in first 10 chars - should be ignored
Another line mentioning [P2] somewhere in the middle
Final line of output
EOF

set +e
OUTPUT=$(detect_review_issues 2 2>/dev/null)
RESULT=$?
set -e

# [P?] 不在前 10 个字符中，所以应该返回 1（未发现问题）
if [[ $RESULT -eq 1 ]]; then
    pass "[P?] not in first 10 chars returns 1 (no issues)"
else
    fail "[P?] position check" "return 1 (no issues)" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 3：完全没有 [P?] - 应该返回 1
# ========================================
echo "Test 3: detect_review_issues returns 1 when no [P?] patterns"
setup_test_env

cat > "$CACHE_DIR/round-3-codex-review.log" << 'EOF'
Code review complete
No issues found
All checks passed
The code looks good
EOF

set +e
OUTPUT=$(detect_review_issues 3 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 1 ]]; then
    pass "No [P?] returns 1"
else
    fail "No issues detection" "return 1" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 4：缺少日志文件 - 应该返回 2
# ========================================
echo "Test 4: detect_review_issues returns error code 2 when log file is missing"
setup_test_env

rm -f "$CACHE_DIR/round-4-codex-review.log" 2>/dev/null || true

set +e
OUTPUT=$(detect_review_issues 4 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 2 ]]; then
    pass "Missing log file returns 2 (hard error)"
else
    fail "Missing log file handling" "return 2 (hard error)" "return $RESULT"
fi

# ========================================
# 测试 5：空日志文件 - 应该返回 2
# ========================================
echo "Test 5: detect_review_issues returns error code 2 when log file is empty"
setup_test_env

touch "$CACHE_DIR/round-5-codex-review.log"

set +e
OUTPUT=$(detect_review_issues 5 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 2 ]]; then
    pass "Empty log file returns 2 (hard error)"
else
    fail "Empty log file handling" "return 2 (hard error)" "return $RESULT"
fi

# ========================================
# 测试 6：超过 50 行的日志文件，[P?] 在文件末尾
# ========================================
echo "Test 6: detect_review_issues finds [P?] late in a long log"
setup_test_env

# 创建一个 60 行的日志文件，第 55 行有 [P1]
{
    for i in $(seq 1 54); do
        echo "Debug line $i - some processing output"
    done
    echo "- [P1] Bug found in the code - /path/to/file.py:100"
    for i in $(seq 56 60); do
        echo "More output line $i"
    done
} > "$CACHE_DIR/round-6-codex-review.log"

set +e
OUTPUT=$(detect_review_issues 6 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P1\]'; then
    pass "[P?] found late in long log"
else
    fail "[P?] late in long log" "return 0, output contains [P1]" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 7：超过 50 行的日志文件，[P?] 在文件开头 - 不应该检测到
# ========================================
echo "Test 7: detect_review_issues ignores [P?] early in a long log (outside last 50 lines)"
setup_test_env

# 创建一个 70 行的日志文件，第 5 行有 [P1]（在文件开头）
# 由于我们只扫描最后 50 行，70 行中的第 5 行在窗口之外
{
    for i in $(seq 1 4); do
        echo "Debug line $i"
    done
    echo "- [P1] This is early in the file - /path/to/file.py:1"
    for i in $(seq 6 70); do
        echo "More output line $i - no issues here"
    done
} > "$CACHE_DIR/round-7-codex-review.log"

set +e
OUTPUT=$(detect_review_issues 7 2>/dev/null)
RESULT=$?
set -e

# [P1] 在 70 行中的第 5 行 - 在最后 50 行窗口之外，应该返回 1
if [[ $RESULT -eq 1 ]]; then
    pass "[P?] early in file ignored (outside last 50 lines)"
else
    fail "[P?] early in file" "return 1 (no issues)" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 8：多个 [P?] 行 - 第一个是提取的起点
# ========================================
echo "Test 8: detect_review_issues extracts from first [P?] line to end"
setup_test_env

cat > "$CACHE_DIR/round-8-codex-review.log" << 'EOF'
Debug output line 1
Debug output line 2
- [P0] Critical issue - /path/to/critical.py:10
  This is a critical bug.
- [P2] Minor issue - /path/to/minor.py:20
  This is a minor issue.
Final debug line
EOF

set +e
OUTPUT=$(detect_review_issues 8 2>/dev/null)
RESULT=$?
set -e

# 应该从 [P0] 行提取到末尾，包括 [P2] 和最后一行
if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P0\]' && echo "$OUTPUT" | grep -q '\[P2\]' && echo "$OUTPUT" | grep -q "Final debug"; then
    pass "Extraction from first [P?] to end works"
else
    fail "Multi-issue extraction" "return 0, contains [P0], [P2], and final line" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 9：[P?] 恰好在位置 0（第一个字符）
# ========================================
echo "Test 9: detect_review_issues finds [P?] at very start of line"
setup_test_env

cat > "$CACHE_DIR/round-9-codex-review.log" << 'EOF'
Debug output
[P3] Issue at start of line - /path/to/file.py:5
  Description of the issue.
EOF

set +e
OUTPUT=$(detect_review_issues 9 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P3\]'; then
    pass "[P?] at position 0 detected"
else
    fail "[P?] at position 0" "return 0, output contains [P3]" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 10：带破折号前缀的 [P?]（常见格式）
# ========================================
echo "Test 10: detect_review_issues finds [P?] with dash prefix"
setup_test_env

cat > "$CACHE_DIR/round-10-codex-review.log" << 'EOF'
Review started
Analyzing files...
- [P1] Security vulnerability - /path/to/auth.py:50
  Password stored in plain text.
EOF

set +e
OUTPUT=$(detect_review_issues 10 2>/dev/null)
RESULT=$?
set -e

# "- [P1]" - [P1] 从位置 2 开始，在前 10 个字符范围内
if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P1\]'; then
    pass "[P?] with dash prefix detected"
else
    fail "[P?] with dash prefix" "return 0, output contains [P1]" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 测试 11：发现问题时创建结果文件
# ========================================
echo "Test 11: detect_review_issues creates result file when issues found"
setup_test_env

cat > "$CACHE_DIR/round-11-codex-review.log" << 'EOF'
Debug line
- [P2] Test issue - /file.py:1
  Issue description
EOF

# 确保结果文件不存在
rm -f "$LOOP_DIR/round-11-review-result.md" 2>/dev/null || true

set +e
OUTPUT=$(detect_review_issues 11 2>/dev/null)
RESULT=$?
set -e

# 检查结果文件是否已创建
if [[ $RESULT -eq 0 ]] && [[ -f "$LOOP_DIR/round-11-review-result.md" ]]; then
    pass "Result file created when issues found"
else
    fail "Result file creation" "return 0, result file exists" "return $RESULT, file exists: $(test -f "$LOOP_DIR/round-11-review-result.md" && echo yes || echo no)"
fi

# ========================================
# 测试 12：恰好 50 行，第 1 行有 [P?]
# ========================================
echo "Test 12: detect_review_issues handles exactly 50 lines"
setup_test_env

{
    echo "- [P1] First line issue - /file.py:1"
    for i in $(seq 2 50); do
        echo "Line $i content"
    done
} > "$CACHE_DIR/round-12-codex-review.log"

set +e
OUTPUT=$(detect_review_issues 12 2>/dev/null)
RESULT=$?
set -e

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | grep -q '\[P1\]'; then
    pass "Exactly 50 lines handled correctly"
else
    fail "Exactly 50 lines" "return 0, output contains [P1]" "return $RESULT, output: $OUTPUT"
fi

# ========================================
# 总结
# ========================================
echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
