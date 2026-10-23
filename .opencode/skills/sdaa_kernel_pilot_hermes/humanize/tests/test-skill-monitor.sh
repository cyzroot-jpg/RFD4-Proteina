#!/usr/bin/env bash
#
# _humanize_monitor_skill（监控技能）的测试
#
# 测试技能监控器的 --once 模式输出和辅助函数。
# 此处不测试交互模式（需要终端）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
    echo "  PASS: $1"
}

fail() {
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
    echo "  FAIL: $1"
    [[ -n "${2:-}" ]] && echo "        $2"
}

# ========================================
# 测试环境设置
# ========================================

TEST_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# 设置模拟 Git 仓库和技能调用
setup_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    touch dummy && git add dummy && git commit -q -m "init"

    # 加载 humanize.sh（它会加载 monitor-common.sh 和 monitor-skill.sh）
    source "$PROJECT_ROOT/scripts/humanize.sh"
}

# 创建一个已完成的技能调用目录
# 用法：create_skill_invocation <unique_id> <status> <model> <effort> <duration> <question>
create_skill_invocation() {
    local unique_id="$1"
    local status="$2"
    local model="${3:-gpt-5.5}"
    local effort="${4:-high}"
    local duration="${5:-15s}"
    local question="${6:-How should I structure this?}"

    local dir=".humanize/skill/$unique_id"
    mkdir -p "$dir"

    # 创建 input.md
    cat > "$dir/input.md" << EOF
# Ask Codex Input

## Question

$question

## Configuration

- Model: $model
- Effort: $effort
- Timeout: 3600s
- Timestamp: $(echo "$unique_id" | cut -d- -f1-3 | tr '_' ' ')
EOF

    # 创建 metadata.md（状态为 "running" 时除外）
    if [[ "$status" != "running" ]]; then
        cat > "$dir/metadata.md" << EOF
---
model: $model
effort: $effort
timeout: 3600
exit_code: $( [[ "$status" == "success" ]] && echo 0 || echo 1 )
duration: $duration
status: $status
started_at: 2026-02-19T21:02:35Z
---
EOF
    fi

    # 为成功的调用创建 output.md
    if [[ "$status" == "success" ]]; then
        echo "This is the response from the model." > "$dir/output.md"
    fi
}

# ========================================
# 测试：目录未找到
# ========================================

echo "=== Skill Monitor: Directory Checks ==="

setup_test_env
output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]] && grep -q "directory not found" <<< "$output"; then
    pass "Returns error when .humanize/skill does not exist"
else
    fail "Should error when skill dir missing" "got: $output"
fi

# ========================================
# 测试：空技能目录
# ========================================

echo "=== Skill Monitor: Empty Directory ==="

setup_test_env
mkdir -p .humanize/skill
output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if [[ $rc -ne 0 ]] && grep -q "No skill invocations found" <<< "$output"; then
    pass "Returns error when no invocations exist"
else
    fail "Should error when no invocations" "got: $output"
fi

# ========================================
# 测试：单次已完成调用
# ========================================

echo "=== Skill Monitor: Single Invocation ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_21-02-35-12345-abc123" "success" "gpt-5.5" "high" "15s" "How should I structure the auth module?"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if [[ $rc -eq 0 ]]; then
    pass "--once mode exits successfully with one invocation"
else
    fail "--once mode should succeed" "exit code: $rc"
fi

if grep -q "Total Invocations: 1" <<< "$output"; then
    pass "Shows total invocation count"
else
    fail "Should show total count" "got: $output"
fi

if grep -q "Success: 1" <<< "$output"; then
    pass "Shows success count"
else
    fail "Should show success count" "got: $output"
fi

if grep -q "success" <<< "$output"; then
    pass "Shows success status for focused invocation"
else
    fail "Should show success status" "got: $output"
fi

if grep -q "gpt-5.5" <<< "$output"; then
    pass "Shows model name"
else
    fail "Should show model" "got: $output"
fi

if grep -q "15s" <<< "$output"; then
    pass "Shows duration"
else
    fail "Should show duration" "got: $output"
fi

if grep -q "How should I structure the auth module" <<< "$output"; then
    pass "Shows question text"
else
    fail "Should show question" "got: $output"
fi

if grep -q "This is the response" <<< "$output"; then
    pass "Shows output content"
else
    fail "Should show output" "got: $output"
fi

# ========================================
# 测试：多次调用（混合状态）
# ========================================

echo "=== Skill Monitor: Multiple Invocations ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_20-00-00-111-aaa" "success" "gpt-5.5" "high" "10s" "First question"
create_skill_invocation "2026-02-19_20-30-00-222-bbb" "error" "gpt-5.5" "high" "5s" "Second question"
create_skill_invocation "2026-02-19_21-00-00-333-ccc" "timeout" "gpt-5.5" "high" "3600s" "Third question"
create_skill_invocation "2026-02-19_21-30-00-444-ddd" "success" "gpt-5.5" "high" "20s" "Latest question"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "Total Invocations: 4" <<< "$output"; then
    pass "Counts all invocations"
else
    fail "Should count all invocations" "got: $(echo "$output" | grep 'Total')"
fi

if grep -q "Success: 2" <<< "$output"; then
    pass "Counts success invocations"
else
    fail "Should count 2 successes" "got: $(echo "$output" | grep 'Success')"
fi

if grep -q "Error: 1" <<< "$output"; then
    pass "Counts error invocations"
else
    fail "Should count 1 error" "got: $(echo "$output" | grep 'Error')"
fi

if grep -q "Timeout: 1" <<< "$output"; then
    pass "Counts timeout invocations"
else
    fail "Should count 1 timeout" "got: $(echo "$output" | grep 'Timeout')"
fi

# 最新的应该是最新的（2026-02-19_21-30-00）
if grep "Focused:" <<< "$output" | grep -q "2026-02-19_21-30-00"; then
    pass "Shows the most recent invocation with content as focused"
else
    fail "Should show newest with content as focused" "got: $(echo "$output" | grep 'Focused:')"
fi

if grep -q "Latest question" <<< "$output"; then
    pass "Shows question from latest invocation"
else
    fail "Should show latest question" "got: $output"
fi

# ========================================
# 测试：正在运行的调用（无 metadata.md）
# ========================================

echo "=== Skill Monitor: Running Invocation ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_21-00-00-111-aaa" "success" "gpt-5.5" "high" "10s" "Completed question"
create_skill_invocation "2026-02-19_21-30-00-222-bbb" "running" "gpt-5.5" "high" "" "Running question"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "Running: 1" <<< "$output"; then
    pass "Counts running invocations"
else
    fail "Should count 1 running" "got: $(echo "$output" | grep 'Running')"
fi

if grep -q "running" <<< "$output"; then
    pass "Shows running status for focused invocation"
else
    fail "Should show running status" "got: $output"
fi

# ========================================
# 测试：最近调用列表
# ========================================

echo "=== Skill Monitor: Recent Invocations List ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_20-00-00-111-aaa" "success" "gpt-5.5" "high" "10s" "Question one"
create_skill_invocation "2026-02-19_20-30-00-222-bbb" "error" "gpt-5.5" "high" "5s" "Question two"
create_skill_invocation "2026-02-19_21-00-00-333-ccc" "success" "gpt-5.5" "high" "20s" "Question three"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "Recent Invocations" <<< "$output"; then
    pass "Shows recent invocations section"
else
    fail "Should show recent section" "got: $output"
fi

# 检查调用是否出现在输出中
if grep -q "2026-02-19_21-00-00-333-ccc" <<< "$output"; then
    pass "Lists invocations in recent section"
else
    fail "Should list invocations" "got: $(echo "$output" | grep '2026-02-19')"
fi

# ========================================
# 测试：从 input.md 中提取问题
# ========================================

echo "=== Skill Monitor: Question Extraction ==="

setup_test_env
mkdir -p .humanize/skill
# 创建一个带有多行问题的调用（只提取第一行）
local_dir=".humanize/skill/2026-02-19_22-00-00-555-eee"
mkdir -p "$local_dir"
cat > "$local_dir/input.md" << 'EOF'
# Ask Codex Input

## Question

What are the performance bottlenecks in the API layer?

Additional context about the question.

## Configuration

- Model: gpt-5.5
- Effort: high
- Timeout: 3600s
EOF
cat > "$local_dir/metadata.md" << 'EOF'
---
model: gpt-5.5
effort: high
timeout: 3600
exit_code: 0
duration: 25s
status: success
started_at: 2026-02-19T22:00:00Z
---
EOF
echo "Performance analysis result" > "$local_dir/output.md"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "What are the performance bottlenecks" <<< "$output"; then
    pass "Extracts first line of question"
else
    fail "Should extract question first line" "got: $output"
fi

# 不应包含第二行
if ! grep -q "Additional context" <<< "$output"; then
    pass "Does not include subsequent lines from question"
else
    fail "Should only show first line" "got: $output"
fi

# ========================================
# 测试：空响应调用
# ========================================

echo "=== Skill Monitor: Empty Response ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_21-00-00-111-aaa" "empty_response" "gpt-5.5" "high" "30s" "Why is the sky blue?"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "Empty: 1" <<< "$output"; then
    pass "Counts empty response invocations"
else
    fail "Should count 1 empty" "got: $(echo "$output" | grep 'Empty')"
fi

if grep -q "No output available" <<< "$output"; then
    pass "Shows no output message for empty response"
else
    fail "Should show no output message" "got: $output"
fi

# ========================================
# 测试：非技能目录被忽略
# ========================================

echo "=== Skill Monitor: Non-skill Dir Filtering ==="

setup_test_env
mkdir -p .humanize/skill
create_skill_invocation "2026-02-19_21-00-00-111-aaa" "success" "gpt-5.5" "high" "10s" "Real question"
# 创建一个不匹配的目录
mkdir -p ".humanize/skill/not-a-skill-dir"
echo "junk" > ".humanize/skill/not-a-skill-dir/input.md"

output=$(_humanize_monitor_skill --once 2>&1) && rc=0 || rc=$?
if grep -q "Total Invocations: 1" <<< "$output"; then
    pass "Ignores non-timestamp directories"
else
    fail "Should only count valid skill dirs" "got: $(echo "$output" | grep 'Total')"
fi

# ========================================
# 总结
# ========================================

echo ""
echo "=========================================="
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
