#!/usr/bin/env bash
#
# template-loader.sh 的测试脚本
#
# 运行此脚本以验证模板加载和渲染函数正常工作。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/hooks/lib/template-loader.sh"

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    echo "  Expected: $2"
    echo "  Got: $3"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "========================================"
echo "Testing template-loader.sh"
echo "========================================"
echo ""

# ========================================
# 测试 1：get_template_dir
# ========================================
echo "Test 1: get_template_dir"
TEMPLATE_DIR=$(get_template_dir "$PROJECT_ROOT/hooks/lib")
EXPECTED_DIR="$PROJECT_ROOT/prompt-template"

if [[ "$TEMPLATE_DIR" == "$EXPECTED_DIR" ]]; then
    pass "get_template_dir returns correct path"
else
    fail "get_template_dir returns wrong path" "$EXPECTED_DIR" "$TEMPLATE_DIR"
fi

# ========================================
# 测试 2：load_template - 已存在的文件
# ========================================
echo ""
echo "Test 2: load_template - existing file"
CONTENT=$(load_template "$TEMPLATE_DIR" "block/git-push.md")

if [[ -n "$CONTENT" ]] && echo "$CONTENT" | grep -q "Git Push Blocked"; then
    pass "load_template loads existing file correctly"
else
    fail "load_template failed to load existing file" "Content containing 'Git Push Blocked'" "$CONTENT"
fi

# ========================================
# 测试 3：load_template - 不存在的文件
# ========================================
echo ""
echo "Test 3: load_template - non-existing file"
CONTENT=$(load_template "$TEMPLATE_DIR" "non-existing-file.md" 2>/dev/null)

if [[ -z "$CONTENT" ]]; then
    pass "load_template returns empty for non-existing file"
else
    fail "load_template should return empty for non-existing file" "(empty)" "$CONTENT"
fi

# ========================================
# 测试 4：render_template - 单个变量
# ========================================
echo ""
echo "Test 4: render_template - single variable"
TEMPLATE="Hello {{NAME}}, welcome!"
RESULT=$(render_template "$TEMPLATE" "NAME=World")
EXPECTED="Hello World, welcome!"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template replaces single variable"
else
    fail "render_template single variable replacement" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 5：render_template - 多个变量
# ========================================
echo ""
echo "Test 5: render_template - multiple variables"
TEMPLATE="Round {{ROUND}}: {{STATUS}} - Path: {{PATH}}"
RESULT=$(render_template "$TEMPLATE" "ROUND=5" "STATUS=complete" "PATH=/tmp/test")
EXPECTED="Round 5: complete - Path: /tmp/test"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template replaces multiple variables"
else
    fail "render_template multiple variable replacement" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 6：render_template - 多行内容
# ========================================
echo ""
echo "Test 6: render_template - multiline content"
TEMPLATE="# Header
Line 1: {{VAR1}}
Line 2: {{VAR2}}
End"
RESULT=$(render_template "$TEMPLATE" "VAR1=value1" "VAR2=value2")
EXPECTED="# Header
Line 1: value1
Line 2: value2
End"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template handles multiline content"
else
    fail "render_template multiline handling" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 7：render_template - 值中的特殊字符
# ========================================
echo ""
echo "Test 7: render_template - special characters in value"
TEMPLATE="Path: {{PATH}}"
RESULT=$(render_template "$TEMPLATE" "PATH=/home/user/test-file.md")
EXPECTED="Path: /home/user/test-file.md"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template handles special characters in values"
else
    fail "render_template special characters" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 8：load_and_render - 集成测试
# ========================================
echo ""
echo "Test 8: load_and_render - integration test"
RESULT=$(load_and_render "$TEMPLATE_DIR" "block/wrong-round-number.md" \
    "ACTION=edit" \
    "CLAUDE_ROUND=3" \
    "FILE_TYPE=summary" \
    "CURRENT_ROUND=5" \
    "CORRECT_PATH=/tmp/round-5-summary.md")

if grep -q "Wrong Round Number" <<<"$RESULT" && \
   grep -q "round-3-summary.md" <<<"$RESULT" && \
   grep -q "current round is \*\*5\*\*" <<<"$RESULT"; then
    pass "load_and_render works correctly with real template"
else
    fail "load_and_render integration test" "Content with replaced variables" "$RESULT"
fi

# ========================================
# 测试 9：render_template - 模板中不存在的变量（应为空操作）
# ========================================
echo ""
echo "Test 9: render_template - unused variable"
TEMPLATE="Hello {{NAME}}"
RESULT=$(render_template "$TEMPLATE" "NAME=World" "UNUSED=ignored")
EXPECTED="Hello World"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template ignores unused variables"
else
    fail "render_template unused variable handling" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 10：render_template - 未替换的变量（保持原样）
# ========================================
echo ""
echo "Test 10: render_template - unreplaced variable stays as-is"
TEMPLATE="Hello {{NAME}}, your ID is {{ID}}"
RESULT=$(render_template "$TEMPLATE" "NAME=World")
EXPECTED="Hello World, your ID is {{ID}}"

if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "render_template keeps unreplaced variables"
else
    fail "render_template unreplaced variable" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 11：load_and_render_safe - 缺失模板使用回退
# ========================================
echo ""
echo "Test 11: load_and_render_safe - missing template uses fallback"
FALLBACK="Fallback message: {{VAR}}"
RESULT=$(load_and_render_safe "$TEMPLATE_DIR" "non-existing.md" "$FALLBACK" "VAR=test_value")

if grep -q "Fallback message: test_value" <<<"$RESULT"; then
    pass "load_and_render_safe uses fallback for missing template"
else
    fail "load_and_render_safe fallback" "Fallback message: test_value" "$RESULT"
fi

# ========================================
# 测试 12：load_and_render_safe - 已存在的模板正常工作
# ========================================
echo ""
echo "Test 12: load_and_render_safe - existing template works normally"
FALLBACK="This should not appear"
RESULT=$(load_and_render_safe "$TEMPLATE_DIR" "block/git-push.md" "$FALLBACK")

if grep -q "Git Push Blocked" <<<"$RESULT" && ! grep -q "should not appear" <<<"$RESULT"; then
    pass "load_and_render_safe uses template when available"
else
    fail "load_and_render_safe with existing template" "Git Push Blocked (not fallback)" "$RESULT"
fi

# ========================================
# 测试 13：validate_template_dir - 有效目录
# ========================================
echo ""
echo "Test 13: validate_template_dir - valid directory"
if validate_template_dir "$TEMPLATE_DIR" 2>/dev/null; then
    pass "validate_template_dir accepts valid directory"
else
    fail "validate_template_dir valid" "return 0" "returned non-zero"
fi

# ========================================
# 测试 14：validate_template_dir - 无效目录
# ========================================
echo ""
echo "Test 14: validate_template_dir - invalid directory"
if ! validate_template_dir "/non/existing/path" 2>/dev/null; then
    pass "validate_template_dir rejects invalid directory"
else
    fail "validate_template_dir invalid" "return 1" "returned 0"
fi

# ========================================
# 测试 15-30：值中的 Shell 元字符
# ========================================
# 这些测试确保包含 shell 特殊字符的模板值被字面渲染，
# 不进行解释。

echo ""
echo "========================================"
echo "Shell Metacharacter Tests"
echo "========================================"

# 测试 15：& 号 - shell 后台运算符
echo ""
echo "Test 15: Ampersand in value"
TEMPLATE="Note: {{NOTE}}"
RESULT=$(render_template "$TEMPLATE" "NOTE=A & B")
EXPECTED="Note: A & B"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Ampersand renders literally"
else
    fail "Ampersand in value" "$EXPECTED" "$RESULT"
fi

# 测试 16：反斜杠（\）- 转义字符
echo ""
echo "Test 16: Backslash in value"
TEMPLATE="Path: {{PATH}}"
RESULT=$(render_template "$TEMPLATE" 'PATH=C:\Users\test')
EXPECTED='Path: C:\Users\test'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Backslash renders literally"
else
    fail "Backslash in value" "$EXPECTED" "$RESULT"
fi

# 测试 17：美元符号（$）- 变量展开
echo ""
echo "Test 17: Dollar sign in value"
TEMPLATE="Price: {{PRICE}}"
RESULT=$(render_template "$TEMPLATE" 'PRICE=$100')
EXPECTED='Price: $100'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Dollar sign renders literally"
else
    fail "Dollar sign in value" "$EXPECTED" "$RESULT"
fi

# 测试 18：反引号（`）- 命令替换
echo ""
echo "Test 18: Backticks in value"
TEMPLATE="Code: {{CODE}}"
RESULT=$(render_template "$TEMPLATE" 'CODE=`whoami`')
EXPECTED='Code: `whoami`'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Backticks render literally"
else
    fail "Backticks in value" "$EXPECTED" "$RESULT"
fi

# 测试 19：管道（|）- 命令管道
echo ""
echo "Test 19: Pipe in value"
TEMPLATE="Cmd: {{CMD}}"
RESULT=$(render_template "$TEMPLATE" 'CMD=cat file | grep foo')
EXPECTED='Cmd: cat file | grep foo'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Pipe renders literally"
else
    fail "Pipe in value" "$EXPECTED" "$RESULT"
fi

# 测试 20：分号（;）- 命令分隔符
echo ""
echo "Test 20: Semicolon in value"
TEMPLATE="Cmds: {{CMDS}}"
RESULT=$(render_template "$TEMPLATE" 'CMDS=cmd1; cmd2; cmd3')
EXPECTED='Cmds: cmd1; cmd2; cmd3'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Semicolon renders literally"
else
    fail "Semicolon in value" "$EXPECTED" "$RESULT"
fi

# 测试 21：Glob 模式（*, ?, []）
echo ""
echo "Test 21: Glob patterns in value"
TEMPLATE="Pattern: {{PATTERN}}"
RESULT=$(render_template "$TEMPLATE" 'PATTERN=*.txt, file?.md, [a-z].sh')
EXPECTED='Pattern: *.txt, file?.md, [a-z].sh'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Glob patterns render literally"
else
    fail "Glob patterns in value" "$EXPECTED" "$RESULT"
fi

# 测试 22：括号（）- 子 shell
echo ""
echo "Test 22: Parentheses in value"
TEMPLATE="Expr: {{EXPR}}"
RESULT=$(render_template "$TEMPLATE" 'EXPR=(a + b) * c')
EXPECTED='Expr: (a + b) * c'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Parentheses render literally"
else
    fail "Parentheses in value" "$EXPECTED" "$RESULT"
fi

# 测试 23：尖括号（<>）- 重定向
echo ""
echo "Test 23: Angle brackets in value"
TEMPLATE="Redir: {{REDIR}}"
RESULT=$(render_template "$TEMPLATE" 'REDIR=cat < input > output 2>&1')
EXPECTED='Redir: cat < input > output 2>&1'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Angle brackets render literally"
else
    fail "Angle brackets in value" "$EXPECTED" "$RESULT"
fi

# 测试 24：双引号（"）
echo ""
echo "Test 24: Double quotes in value"
TEMPLATE="Quoted: {{QUOTED}}"
RESULT=$(render_template "$TEMPLATE" 'QUOTED=He said "hello"')
EXPECTED='Quoted: He said "hello"'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Double quotes render literally"
else
    fail "Double quotes in value" "$EXPECTED" "$RESULT"
fi

# 测试 25：单引号（'）
echo ""
echo "Test 25: Single quotes in value"
TEMPLATE="Quoted: {{QUOTED}}"
RESULT=$(render_template "$TEMPLATE" "QUOTED=It's working")
EXPECTED="Quoted: It's working"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Single quotes render literally"
else
    fail "Single quotes in value" "$EXPECTED" "$RESULT"
fi

# 测试 26：井号（#）- 注释
echo ""
echo "Test 26: Hash in value"
TEMPLATE="Comment: {{COMMENT}}"
RESULT=$(render_template "$TEMPLATE" 'COMMENT=# This is a comment')
EXPECTED='Comment: # This is a comment'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Hash renders literally"
else
    fail "Hash in value" "$EXPECTED" "$RESULT"
fi

# 测试 27：波浪号（~）- 主目录
echo ""
echo "Test 27: Tilde in value"
TEMPLATE="Home: {{HOME_PATH}}"
RESULT=$(render_template "$TEMPLATE" 'HOME_PATH=~/documents')
EXPECTED='Home: ~/documents'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Tilde renders literally"
else
    fail "Tilde in value" "$EXPECTED" "$RESULT"
fi

# 测试 28：组合 shell 元字符
echo ""
echo "Test 28: Combined metacharacters"
TEMPLATE="Complex: {{COMPLEX}}"
RESULT=$(render_template "$TEMPLATE" 'COMPLEX=$HOME/*.txt | grep "test" & echo done')
EXPECTED='Complex: $HOME/*.txt | grep "test" & echo done'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Combined metacharacters render literally"
else
    fail "Combined metacharacters in value" "$EXPECTED" "$RESULT"
fi

# 测试 29：多个 & 号（gsub & bug 的回归测试）
echo ""
echo "Test 29: Multiple ampersands"
TEMPLATE="Items: {{ITEMS}}"
RESULT=$(render_template "$TEMPLATE" "ITEMS=A & B & C & D")
EXPECTED="Items: A & B & C & D"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Multiple ampersands render correctly"
else
    fail "Multiple ampersands in value" "$EXPECTED" "$RESULT"
fi

# 测试 30：带反斜杠的 Windows 风格路径
echo ""
echo "Test 30: Windows paths"
TEMPLATE="WinPath: {{WINPATH}}"
RESULT=$(render_template "$TEMPLATE" 'WINPATH=C:\Program Files\App\bin\run.exe')
EXPECTED='WinPath: C:\Program Files\App\bin\run.exe'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Windows paths render correctly"
else
    fail "Windows paths in value" "$EXPECTED" "$RESULT"
fi

# 测试 31：类似正则表达式的模式
echo ""
echo "Test 31: Regex patterns"
TEMPLATE="Regex: {{REGEX}}"
RESULT=$(render_template "$TEMPLATE" 'REGEX=\d+\.\d+\s*$')
EXPECTED='Regex: \d+\.\d+\s*$'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Regex patterns render correctly"
else
    fail "Regex patterns in value" "$EXPECTED" "$RESULT"
fi

# 测试 32：类似 JSON 的内容
echo ""
echo "Test 32: JSON content"
TEMPLATE="JSON: {{JSON}}"
RESULT=$(render_template "$TEMPLATE" 'JSON={"key": "value", "count": 42}')
EXPECTED='JSON: {"key": "value", "count": 42}'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "JSON content renders correctly"
else
    fail "JSON content in value" "$EXPECTED" "$RESULT"
fi

# 测试 33：带元字符的多行值
echo ""
echo "Test 33: Multiline with metacharacters"
TEMPLATE="Content: {{CONTENT}}"
MULTILINE_VAL='Line 1: $VAR & stuff
Line 2: path\to\file
Line 3: `command`'
RESULT=$(render_template "$TEMPLATE" "CONTENT=$MULTILINE_VAL")
EXPECTED="Content: $MULTILINE_VAL"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Multiline with metacharacters renders correctly"
else
    fail "Multiline with metacharacters" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 34-36：占位符注入防护
# ========================================
# 这些测试确保注入值中的 {{VAR}} 模式不会被替换，
# 防止提示损坏。

echo ""
echo "========================================"
echo "Placeholder Injection Prevention Tests"
echo "========================================"

# 测试 34：包含后续变量占位符的值
echo ""
echo "Test 34: Placeholder in value (later variable)"
TEMPLATE="A: {{VAR_A}}, B: {{VAR_B}}"
# VAR_A contains {{VAR_B}} but VAR_B should NOT replace it
RESULT=$(render_template "$TEMPLATE" "VAR_A=contains {{VAR_B}} here" "VAR_B=replaced")
EXPECTED="A: contains {{VAR_B}} here, B: replaced"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Placeholder in value not replaced (later variable)"
else
    fail "Placeholder injection prevention (later)" "$EXPECTED" "$RESULT"
fi

# 测试 35：包含先前变量占位符的值
echo ""
echo "Test 35: Placeholder in value (earlier variable)"
TEMPLATE="A: {{VAR_A}}, B: {{VAR_B}}"
# VAR_B contains {{VAR_A}} - should also NOT be replaced
RESULT=$(render_template "$TEMPLATE" "VAR_A=first" "VAR_B=contains {{VAR_A}} here")
EXPECTED="A: first, B: contains {{VAR_A}} here"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Placeholder in value not replaced (earlier variable)"
else
    fail "Placeholder injection prevention (earlier)" "$EXPECTED" "$RESULT"
fi

# 测试 36：真实场景 - 带模板语法的 REVIEW_CONTENT
echo ""
echo "Test 36: Realistic injection scenario"
TEMPLATE="Plan: {{PLAN_FILE}}
Review: {{REVIEW_CONTENT}}
Goal: {{GOAL_TRACKER_FILE}}"
REVIEW="Codex says: check {{GOAL_TRACKER_FILE}} and {{PLAN_FILE}} for context"
RESULT=$(render_template "$TEMPLATE" \
    "PLAN_FILE=/path/plan.md" \
    "REVIEW_CONTENT=$REVIEW" \
    "GOAL_TRACKER_FILE=/path/goals.md")
EXPECTED="Plan: /path/plan.md
Review: Codex says: check {{GOAL_TRACKER_FILE}} and {{PLAN_FILE}} for context
Goal: /path/goals.md"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Realistic injection scenario handled correctly"
else
    fail "Realistic injection scenario" "$EXPECTED" "$RESULT"
fi

# ========================================
# 测试 37-41：附加边界情况
# ========================================
# 这些测试覆盖模板渲染的附加边界情况。

echo ""
echo "========================================"
echo "Additional Edge Case Tests"
echo "========================================"

# 测试 37：空变量替换
echo ""
echo "Test 37: Empty variable substitution"
TEMPLATE="Hello {{NAME}}, status: {{STATUS}}"
RESULT=$(render_template "$TEMPLATE" "NAME=" "STATUS=active")
EXPECTED="Hello , status: active"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Empty variable substitution works"
else
    fail "Empty variable substitution" "$EXPECTED" "$RESULT"
fi

# 测试 38：模板中的 Unicode 字符
echo ""
echo "Test 38: Unicode characters in template"
TEMPLATE="Greeting: {{GREETING}}"
RESULT=$(render_template "$TEMPLATE" "GREETING=Hello World")
EXPECTED="Greeting: Hello World"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Unicode in template renders correctly"
else
    fail "Unicode in template" "$EXPECTED" "$RESULT"
fi

# 测试 38.1：模板中的实际非 ASCII Unicode（带重音的 e）
echo ""
echo "Test 38.1: Non-ASCII Unicode in template"
# 使用法语带重音的单词 "caf\xc3\xa9"（带尖音的咖啡）
TEMPLATE=$'Caf\xc3\xa9: {{ITEM}}'
RESULT=$(render_template "$TEMPLATE" "ITEM=espresso")
EXPECTED=$'Caf\xc3\xa9: espresso'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Non-ASCII Unicode in template renders correctly"
else
    fail "Non-ASCII Unicode in template" "$EXPECTED" "$RESULT"
fi

# 测试 39：值中的 Unicode 字符
echo ""
echo "Test 39: Unicode characters in value"
TEMPLATE="Message: {{MSG}}"
RESULT=$(render_template "$TEMPLATE" "MSG=Bonjour mon ami")
EXPECTED="Message: Bonjour mon ami"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Unicode in value renders correctly"
else
    fail "Unicode in value" "$EXPECTED" "$RESULT"
fi

# 测试 39.1：值中的实际非 ASCII Unicode（带重音字符）
echo ""
echo "Test 39.1: Non-ASCII Unicode in value"
TEMPLATE="Location: {{PLACE}}"
# 使用 "Caf\xc3\xa9"（带尖音的咖啡）和 "\xc3\xa0"（带沉音的 a）
RESULT=$(render_template "$TEMPLATE" $'PLACE=Caf\xc3\xa9 \xc3\xa0 Paris')
EXPECTED=$'Location: Caf\xc3\xa9 \xc3\xa0 Paris'
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Non-ASCII Unicode in value renders correctly"
else
    fail "Non-ASCII Unicode in value" "$EXPECTED" "$RESULT"
fi

# 测试 40：变量名边界情况 - 下划线前缀
echo ""
echo "Test 40: Variable with underscore prefix"
TEMPLATE="Value: {{_PRIVATE}}"
RESULT=$(render_template "$TEMPLATE" "_PRIVATE=secret")
EXPECTED="Value: secret"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Underscore-prefixed variable works"
else
    fail "Underscore-prefixed variable" "$EXPECTED" "$RESULT"
fi

# 测试 41：带数字的变量名
echo ""
echo "Test 41: Variable name with numbers"
TEMPLATE="Round: {{ROUND_1}} and {{ROUND_2}}"
RESULT=$(render_template "$TEMPLATE" "ROUND_1=first" "ROUND_2=second")
EXPECTED="Round: first and second"
if [[ "$RESULT" == "$EXPECTED" ]]; then
    pass "Variable names with numbers work"
else
    fail "Variable names with numbers" "$EXPECTED" "$RESULT"
fi

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
