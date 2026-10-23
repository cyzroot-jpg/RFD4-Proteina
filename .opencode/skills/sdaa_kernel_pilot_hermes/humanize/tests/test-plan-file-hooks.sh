#!/usr/bin/env bash
#
# RLCR 循环期间计划文件钩子的测试
#
# 测试：
# - UserPromptSubmit 钩子（loop-plan-file-validator.sh）
# - Write 验证器阻止 plan.md
# - Edit 验证器阻止 plan.md
# - Bash 验证器阻止 plan.md 修改
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
TESTS_SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; echo "  Expected: $2"; echo "  Got: $3"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1 - $2"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); }

# 设置测试环境
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# 设置隔离的缓存目录以避免沙箱环境中的权限问题
export XDG_CACHE_HOME="$TEST_DIR/.cache"
mkdir -p "$XDG_CACHE_HOME"

# 创建模拟 codex 以防止调用真实 codex（速度慢）
# 此模拟默认输出 COMPLETE
setup_mock_codex() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << 'MOCKEOF'
#!/usr/bin/env bash
# test-plan-file-hooks.sh 的模拟 codex
if [[ "$1" == "exec" ]]; then
    echo "Mock review output"
    echo "COMPLETE"
elif [[ "$1" == "review" ]]; then
    echo "Mock code review: No issues found."
fi
exit 0
MOCKEOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# 为所有测试初始化模拟 codex
setup_mock_codex

# 默认分支名称（在第一次 git init 后设置）
DEFAULT_BRANCH=""

create_round_contract() {
    local loop_dir="$1"
    local round="$2"

    cat > "$loop_dir/round-${round}-contract.md" << EOF
# Round $round Contract

- Mainline Objective: Keep plan-file integrity checks aligned
- Target ACs: AC-1
- Blocking Side Issues In Scope: none
- Queued Side Issues Out of Scope: none
- Success Criteria: current round artifacts are present and coherent
EOF
}

setup_test_loop() {
    cd "$TEST_DIR"

    # 仅在尚未初始化时初始化 git
    if [[ ! -d ".git" ]]; then
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        echo "initial" > init.txt
        git add init.txt
        git -c commit.gpgsign=false commit -q -m "Initial commit"
        # 捕获默认分支名称（main 或 master 取决于 git 版本）
        DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    fi

    # 获取当前分支名称（处理 'main' 和 'master' 默认值）
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # 创建循环目录结构
    LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
    rm -rf "$LOOP_DIR"
    mkdir -p "$LOOP_DIR"

    # 创建计划文件（gitignore 中）
    mkdir -p plans
    cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test the RLCR loop
## Requirements
- Requirement 1
EOF
    cat >> .gitignore << 'EOF'
plans/
.humanize*
.cache/
bin/
EOF
    git add .gitignore
    git -c commit.gpgsign=false commit -q -m "Add gitignore"

    # 创建计划备份
    cp plans/test-plan.md "$LOOP_DIR/plan.md"

    # 创建带有 v1.5.0+ 字段的状态文件（plan_file 在 YAML 中被引用）
    # 使用实际分支名称以处理 'main' 和 'master' 默认值
    cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $CURRENT_BRANCH
base_branch: $CURRENT_BRANCH
review_started: false
mainline_stall_count: 0
last_mainline_verdict: unknown
drift_status: normal
---
EOF

    create_round_contract "$LOOP_DIR" 0
}

echo "=== Test: UserPromptSubmit Hook ==="
echo ""

# 测试 1：钩子在有效状态下通过
setup_test_loop
export CLAUDE_PROJECT_DIR="$TEST_DIR"

echo "测试 1：钩子在有效状态下通过"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$RESULT" ]]; then
    pass "Hook passes with valid state"
else
    fail "Hook with valid state" "exit 0, no output" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 1.5: Hook correctly parses YAML-quoted plan_file
echo "Test 1.5: Hook correctly parses YAML-quoted plan_file"
# 钩子应该去除引号并正确找到计划文件
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# 如果 plan_file 未被正确解析，它将无法找到文件
# 并可能阻止。成功意味着空输出和退出 0。
if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$RESULT" ]]; then
    pass "Hook correctly parses YAML-quoted plan_file"
else
    fail "Hook parsing YAML-quoted plan_file" "exit 0, no output" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 2：状态文件缺少 v1.5.0 必需字段时钩子阻止
echo "Test 2: Hook blocks when state file is missing required fields (v1.5.0+ schema)"
cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
start_branch: $DEFAULT_BRANCH
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# v1.5.0+ 需要 review_started 和 base_branch - 验证器拒绝格式错误的状态
if echo "$RESULT" | grep -qi "malformed\|blocking"; then
    pass "Hook blocks on malformed state (missing v1.5.0 fields)"
else
    fail "Hook blocking malformed state" "malformed state error" "$RESULT"
fi

# 测试 3：缺少 start_branch 字段时钩子阻止
echo "测试 3：缺少 start_branch 字段时钩子阻止 (also missing v1.5.0 fields)"
cat > "$LOOP_DIR/state.md" << 'EOF'
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# v1.5.0+ 需要 start_branch、review_started 和 base_branch - 验证器拒绝格式错误的状态
if echo "$RESULT" | grep -qi "malformed\|blocking"; then
    pass "Hook blocks on malformed state (missing start_branch and v1.5.0 fields)"
else
    fail "Hook blocking malformed state" "malformed state error" "$RESULT"
fi

# 为剩余测试恢复有效状态
setup_test_loop

# 测试 4：分支更改时钩子阻止
echo "测试 4：分支更改时钩子阻止"
git checkout -q -b feature-branch
cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $DEFAULT_BRANCH
base_branch: $DEFAULT_BRANCH
review_started: false
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]] && echo "$RESULT" | grep -q "branch"; then
    pass "Hook blocks on branch change"
else
    fail "Hook blocking branch change" "block with branch error" "$RESULT"
fi
git checkout -q "$DEFAULT_BRANCH"

echo ""
echo "=== Test: Write Validator ==="
echo ""

# 恢复状态
setup_test_loop

# Test 5: Write validator blocks plan.md in loop directory
echo "Test 5: Block writes to plan.md backup"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Write validator blocks plan.md backup"
else
    fail "Write validator blocking plan.md" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Edit Validator ==="
echo ""

# Test 6: Edit validator blocks plan.md in loop directory
echo "Test 6: Block edits to plan.md backup"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Edit validator blocks plan.md backup"
else
    fail "Edit validator blocking plan.md" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Bash Validator ==="
echo ""

# Test 7: Bash validator blocks modifications to plan.md
echo "Test 7: Block bash modifications to plan.md backup"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$LOOP_DIR'/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks plan.md modification"
else
    fail "Bash validator blocking plan.md" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8: Bash validator blocks rm on plan.md
echo "Test 8: Block bash rm on plan.md backup"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "rm '$LOOP_DIR'/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks rm on plan.md"
else
    fail "Bash validator blocking rm" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8a: Bash validator blocks direct .humanize/rlcr/plan.md (no intermediate dir)
# 这是针对正则表达式绕过漏洞的修复 #1 测试
echo "Test 8a: Block bash modifications to direct .humanize/rlcr/plan.md"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo evil > .humanize/rlcr/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks direct .humanize/rlcr/plan.md"
else
    fail "Bash validator direct plan.md" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: Command Injection Bypass Prevention ==="
echo ""

# Test 8.1: Block command substitution bypass attempt
echo "Test 8.1: Block command substitution bypass"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > .humanize/rlcr/$(date +%Y)/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks command substitution bypass"
else
    fail "Command substitution bypass" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8.2: Block glob expansion bypass attempt
echo "Test 8.2: Block glob expansion bypass"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > .humanize/rlcr/*/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks glob expansion bypass"
else
    fail "Glob expansion bypass" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8.3: Block brace expansion bypass attempt
echo "Test 8.3: Block brace expansion bypass"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "tee .humanize/rlcr/{a,b,c}/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks brace expansion bypass"
else
    fail "Brace expansion bypass" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8.4: Block piped command bypass attempt
echo "Test 8.4: Block piped command bypass"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "cat input.txt | tee .humanize/rlcr/2024-01-01_12-00-00/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks piped command bypass"
else
    fail "Piped command bypass" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 8.5: Block backtick command substitution bypass
echo "Test 8.5: Block backtick command substitution bypass"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > .humanize/rlcr/`echo test`/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "plan"; then
    pass "Bash validator blocks backtick substitution bypass"
else
    fail "Backtick substitution bypass" "exit 2 with plan error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== Test: YAML Quote Parsing ==="
echo ""

# Test 8.6: Hook correctly parses quoted start_branch (strips quotes)
echo "Test 8.6: Hook correctly strips quotes from start_branch"
setup_test_loop
# 创建带引用分支名称的状态
cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: "$DEFAULT_BRANCH"
base_branch: $DEFAULT_BRANCH
review_started: false
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# Should pass (no output, exit 0) - quotes should be stripped and branch should match current
if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$RESULT" ]]; then
    pass "Hook correctly strips quotes from start_branch"
else
    fail "Quote stripping from start_branch" "exit 0, no output" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 8.7：钩子检测带引用值的分支不匹配
echo "Test 8.7: Hook detects branch mismatch with quoted start_branch"
setup_test_loop
cat > "$LOOP_DIR/state.md" << 'EOF'
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: "different-branch"
base_branch: main
review_started: false
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# Should block due to branch mismatch (current is main, state says different-branch)
if [[ $EXIT_CODE -eq 0 ]] && echo "$RESULT" | grep -q "branch"; then
    pass "Hook detects branch mismatch with quoted start_branch"
else
    fail "Branch mismatch detection with quotes" "block with branch error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 8.8：Stop hook 正确解析两个引用字段
echo "Test 8.8: Stop hook parses quoted plan_file and start_branch"
setup_test_loop
cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: "$DEFAULT_BRANCH"
base_branch: $DEFAULT_BRANCH
review_started: false
---
EOF
# 创建摘要以通过该检查
cat > "$LOOP_DIR/round-0-summary.md" << 'SUMEOF'
# Summary
Work done.
SUMEOF
# 创建目标跟踪器
cat > "$LOOP_DIR/goal-tracker.md" << 'GTEOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | done | - |
GTEOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 不应该因 YAML 解析失败 - 如果失败，应该是其他原因（codex 缺失等）
if ! echo "$RESULT" | grep -qi "yaml\|parse error\|invalid.*field"; then
    pass "Stop hook parses quoted plan_file and start_branch"
else
    fail "Stop hook YAML parsing" "no YAML parse errors" "output: $RESULT"
fi

# 测试 8.8b：缺少轮次合同时 Stop hook 阻止
echo "测试 8.8b：缺少轮次合同时 Stop hook 阻止"
setup_test_loop
rm -f "$LOOP_DIR/round-0-contract.md"
cat > "$LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
cat > "$LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | done | - |
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "contract"; then
    pass "Stop hook blocks when round contract is missing"
else
    fail "Stop hook missing round contract" "block with contract error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 8.9：钩子正确处理带连字符的 plan_file 路径
echo "Test 8.9: Hook handles plan_file with hyphens in path"
setup_test_loop
mkdir -p "$TEST_DIR/my-plans"
cat > "$TEST_DIR/my-plans/test-plan.md" << 'EOF'
# Test Plan
## Goal
Test the RLCR loop
## Requirements
- Requirement 1
EOF
cp "$TEST_DIR/my-plans/test-plan.md" "$LOOP_DIR/plan.md"
cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "my-plans/test-plan.md"
plan_tracked: false
start_branch: "$DEFAULT_BRANCH"
base_branch: $DEFAULT_BRANCH
review_started: false
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$RESULT" ]]; then
    pass "Hook handles plan_file with hyphens in path"
else
    fail "Plan file path with hyphens" "exit 0, no output" "exit $EXIT_CODE, output: $RESULT"
fi

# Restore for remaining tests
setup_test_loop

echo ""
echo "=== Test: Stop Hook Plan File Integrity ==="
echo ""

# 测试 9：计划文件被修改时 Stop hook 阻止
echo "Test 9: Stop hook blocks when plan file is modified"
setup_test_loop
# 修改项目计划文件（与备份不同）
echo "# Modified content" >> "$TEST_DIR/plans/test-plan.md"
# 创建摘要文件以使钩子不会首先在该检查上失败
cat > "$LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
# 创建目标跟踪器 以使钩子不会在该检查上失败
cat > "$LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Plan Evolution Log
| Round | Change | Reason | Impact on AC |
|-------|--------|--------|--------------|
| 0 | Initial plan | - | - |
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | in_progress | - |
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 钩子应该输出带有 "block" 决策的 JSON 并提到计划文件已修改
if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "plan.*modified"; then
    pass "Stop hook blocks when plan file is modified"
else
    fail "Stop hook plan modification detection" "block with plan modified error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 10：计划文件被删除时 Stop hook 阻止
echo "测试 10：计划文件被删除时 Stop hook 阻止"
setup_test_loop
# 删除项目计划文件
rm -f "$TEST_DIR/plans/test-plan.md"
# 创建必要文件
cat > "$LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
cat > "$LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | done | - |
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "plan.*deleted"; then
    pass "Stop hook blocks when plan file is deleted"
else
    fail "Stop hook plan deletion detection" "block with plan deleted error" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 11：计划备份缺失时 Stop hook 阻止
echo "测试 11：计划备份缺失时 Stop hook 阻止"
setup_test_loop
# 移除备份
rm -f "$LOOP_DIR/plan.md"
cat > "$LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "backup.*not found\|plan.*backup"; then
    pass "Stop hook blocks when plan backup is missing"
else
    fail "Stop hook plan backup detection" "block with backup missing error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 12: Stop hook detects tracked file modifications (Fix #3 - Race condition)
echo "Test 12: Stop hook detects tracked plan file modifications"
cd "$TEST_DIR"
rm -rf tracked-stop-test 2>/dev/null || true
mkdir -p tracked-stop-test
cd tracked-stop-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
# 获取此新仓库的默认分支名称
TEST12_BRANCH=$(git rev-parse --abbrev-ref HEAD)
# 创建跟踪的计划文件
cat > tracked-plan.md << 'EOF'
# Tracked Plan
## Goal
Test tracked file
## Requirements
- Requirement 1
EOF
git add tracked-plan.md
git -c commit.gpgsign=false commit -q -m "Add plan"
# Create loop directory
TRACKED_LOOP_DIR="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$TRACKED_LOOP_DIR"
cp tracked-plan.md "$TRACKED_LOOP_DIR/plan.md"
cat > "$TRACKED_LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: tracked-plan.md
plan_tracked: true
start_branch: $TEST12_BRANCH
base_branch: $TEST12_BRANCH
review_started: false
---
EOF
cat > "$TRACKED_LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$TRACKED_LOOP_DIR" 0
cat > "$TRACKED_LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | done | - |
EOF
# 现在修改跟踪的计划文件（模拟竞态条件）
echo "# Modified" >> tracked-plan.md
export CLAUDE_PROJECT_DIR="$PWD"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该通过 git status 检测修改
if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "plan.*modif\|uncommitted"; then
    pass "Stop hook detects tracked plan file modifications"
else
    fail "Stop hook tracked file detection" "block with modification error" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 13: Stop hook returns JSON block for outdated schema (Fix #5)
echo "Test 13: Stop hook returns JSON block for outdated schema"
cd "$TEST_DIR"
setup_test_loop
export CLAUDE_PROJECT_DIR="$TEST_DIR"
# 创建没有 plan_tracked 的状态（旧 schema）
cat > "$LOOP_DIR/state.md" << 'EOF'
---
current_round: 0
max_iterations: 42
plan_file: plans/test-plan.md
---
EOF
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该返回带有阻止决策的 JSON，而不是静默退出
if echo "$RESULT" | grep -q '"decision".*"block"' && echo "$RESULT" | grep -qi "schema\|missing.*field\|plan_tracked"; then
    pass "Stop hook returns JSON block for outdated schema"
else
    fail "Stop hook schema blocking" "JSON block response" "exit $EXIT_CODE, output: $RESULT"
fi

# 测试 14：Stop hook 阻止已提交更改的跟踪文件（内容与备份不同）
# 这测试安全修复：即使 git status 是干净的，内容也必须与备份匹配
echo "Test 14: Stop hook blocks tracked file with committed changes"
cd "$TEST_DIR"
rm -rf tracked-commit-test 2>/dev/null || true
mkdir -p tracked-commit-test
cd tracked-commit-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
# 获取此新仓库的默认分支名称
TEST14_BRANCH=$(git rev-parse --abbrev-ref HEAD)
# 创建跟踪的计划文件
cat > tracked-plan.md << 'EOF'
# Tracked Plan
## Goal
Test tracked file
## Requirements
- Requirement 1
EOF
git add tracked-plan.md
git -c commit.gpgsign=false commit -q -m "Add plan"
# Create loop directory and backup
TRACKED_LOOP_DIR="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$TRACKED_LOOP_DIR"
cp tracked-plan.md "$TRACKED_LOOP_DIR/plan.md"
cat > "$TRACKED_LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: tracked-plan.md
plan_tracked: true
start_branch: $TEST14_BRANCH
base_branch: $TEST14_BRANCH
review_started: false
---
EOF
cat > "$TRACKED_LOOP_DIR/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$TRACKED_LOOP_DIR" 0
cat > "$TRACKED_LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test goal
### Acceptance Criteria
- Criterion 1
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | done | - |
EOF
# 修改并提交计划文件（git status 将是干净的）
echo "# Modified and committed" >> tracked-plan.md
git add tracked-plan.md
git -c commit.gpgsign=false commit -q -m "Modify plan"
# 验证计划文件的 git status 是干净的
GIT_STATUS_CHECK=$(git status --porcelain tracked-plan.md)
if [[ -n "$GIT_STATUS_CHECK" ]]; then
    fail "Test 14 setup" "clean git status" "git status: $GIT_STATUS_CHECK"
else
    export CLAUDE_PROJECT_DIR="$PWD"
    set +e
    RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
    EXIT_CODE=$?
    set -e
    # 应该通过内容差异检测修改（不是 git status）
    if echo "$RESULT" | grep -q '"decision"' && echo "$RESULT" | grep -qi "plan.*modif"; then
        pass "Stop hook blocks tracked file with committed changes"
    else
        fail "Stop hook committed file detection" "block with modification error" "exit $EXIT_CODE, output: $RESULT"
    fi
fi

echo ""
echo "=== Test: Section-Specific Placeholder Detection ==="
echo ""

# 测试 14.1：仅缺少 Ultimate Goal 占位符时 Stop hook 仅报告该占位符
echo "Test 14.1: Stop hook only reports Ultimate Goal placeholder"
cd "$TEST_DIR"
rm -rf placeholder-test-14-1 2>/dev/null || true
mkdir -p placeholder-test-14-1
cd placeholder-test-14-1
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
# 将 .humanize 添加到 gitignore 以不触发未提交更改
echo ".humanize*" > .gitignore
git add init.txt .gitignore
git -c commit.gpgsign=false commit -q -m "Initial"
TEST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
# 创建 gitignore 的计划
mkdir -p plans
echo "plans/" >> .gitignore
cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test
EOF
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Add gitignore"
# Create loop directory
LOOP_DIR_14_1="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$LOOP_DIR_14_1"
cp plans/test-plan.md "$LOOP_DIR_14_1/plan.md"
cat > "$LOOP_DIR_14_1/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $TEST_BRANCH
base_branch: $TEST_BRANCH
review_started: false
---
EOF
cat > "$LOOP_DIR_14_1/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$LOOP_DIR_14_1" 0
# 目标跟踪器仅有 Ultimate Goal 占位符（AC 和 Tasks 已填写）
cat > "$LOOP_DIR_14_1/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
[To be extracted from plan by Claude in Round 0]
### Acceptance Criteria
- AC1: Real acceptance criterion
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | in_progress | Real task |
EOF
export CLAUDE_PROJECT_DIR="$PWD"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该报告 Ultimate Goal 缺失项行，但不报告 AC 或 Active Tasks 缺失项行
# The exact format is: **<Section>**: Still contains placeholder text
if echo "$RESULT" | grep -qF '**Ultimate Goal**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Acceptance Criteria**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Active Tasks**: Still contains placeholder text'; then
    pass "Stop hook only reports Ultimate Goal placeholder"
else
    fail "Section-specific Ultimate Goal" "only **Ultimate Goal**: Still contains placeholder text" "output: $RESULT"
fi

# 测试 14.2：仅缺少 Acceptance Criteria 占位符时 Stop hook 仅报告该占位符
echo "Test 14.2: Stop hook only reports Acceptance Criteria placeholder"
cd "$TEST_DIR"
rm -rf placeholder-test-14-2 2>/dev/null || true
mkdir -p placeholder-test-14-2
cd placeholder-test-14-2
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
echo ".humanize*" > .gitignore
git add init.txt .gitignore
git -c commit.gpgsign=false commit -q -m "Initial"
TEST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p plans
echo "plans/" >> .gitignore
cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test
EOF
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Add gitignore"
LOOP_DIR_14_2="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$LOOP_DIR_14_2"
cp plans/test-plan.md "$LOOP_DIR_14_2/plan.md"
cat > "$LOOP_DIR_14_2/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $TEST_BRANCH
base_branch: $TEST_BRANCH
review_started: false
---
EOF
cat > "$LOOP_DIR_14_2/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$LOOP_DIR_14_2" 0
# 目标跟踪器仅有 AC 占位符（Goal 和 Tasks 已填写）
cat > "$LOOP_DIR_14_2/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Implement the feature completely
### Acceptance Criteria
[To be defined by Claude in Round 0 based on the plan]
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Task 1 | AC1 | in_progress | Real task |
EOF
export CLAUDE_PROJECT_DIR="$PWD"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该报告 Acceptance Criteria 缺失项行，但不报告 Goal 或 Active Tasks 缺失项行
# The exact format is: **<Section>**: Still contains placeholder text
if echo "$RESULT" | grep -qF '**Acceptance Criteria**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Ultimate Goal**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Active Tasks**: Still contains placeholder text'; then
    pass "Stop hook only reports Acceptance Criteria placeholder"
else
    fail "Section-specific Acceptance Criteria" "only **Acceptance Criteria**: Still contains placeholder text" "output: $RESULT"
fi

# 测试 14.3：仅缺少 Active Tasks 占位符时 Stop hook 仅报告该占位符
echo "Test 14.3: Stop hook only reports Active Tasks placeholder"
cd "$TEST_DIR"
rm -rf placeholder-test-14-3 2>/dev/null || true
mkdir -p placeholder-test-14-3
cd placeholder-test-14-3
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
echo ".humanize*" > .gitignore
git add init.txt .gitignore
git -c commit.gpgsign=false commit -q -m "Initial"
TEST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p plans
echo "plans/" >> .gitignore
cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test
EOF
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Add gitignore"
LOOP_DIR_14_3="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$LOOP_DIR_14_3"
cp plans/test-plan.md "$LOOP_DIR_14_3/plan.md"
cat > "$LOOP_DIR_14_3/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $TEST_BRANCH
base_branch: $TEST_BRANCH
review_started: false
---
EOF
cat > "$LOOP_DIR_14_3/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$LOOP_DIR_14_3" 0
# 目标跟踪器仅有 Active Tasks 占位符（Goal 和 AC 已填写）
cat > "$LOOP_DIR_14_3/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Implement the feature completely
### Acceptance Criteria
- AC1: Real acceptance criterion
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
[To be populated by Claude based on plan]
EOF
export CLAUDE_PROJECT_DIR="$PWD"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该报告 Active Tasks 缺失项行，但不报告 Goal 或 AC 缺失项行
# The exact format is: **<Section>**: Still contains placeholder text
if echo "$RESULT" | grep -qF '**Active Tasks**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Ultimate Goal**: Still contains placeholder text' && \
   ! echo "$RESULT" | grep -qF '**Acceptance Criteria**: Still contains placeholder text'; then
    pass "Stop hook only reports Active Tasks placeholder"
else
    fail "Section-specific Active Tasks" "only **Active Tasks**: Still contains placeholder text" "output: $RESULT"
fi

# 测试 14.4：所有占位符存在时 Stop hook 报告全部三个
echo "Test 14.4: Stop hook reports all three placeholders when all missing"
cd "$TEST_DIR"
rm -rf placeholder-test-14-4 2>/dev/null || true
mkdir -p placeholder-test-14-4
cd placeholder-test-14-4
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
echo ".humanize*" > .gitignore
git add init.txt .gitignore
git -c commit.gpgsign=false commit -q -m "Initial"
TEST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p plans
echo "plans/" >> .gitignore
cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test
EOF
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Add gitignore"
LOOP_DIR_14_4="$PWD/.humanize/rlcr/2024-01-01_12-00-00"
mkdir -p "$LOOP_DIR_14_4"
cp plans/test-plan.md "$LOOP_DIR_14_4/plan.md"
cat > "$LOOP_DIR_14_4/state.md" << EOF
---
current_round: 0
max_iterations: 42
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $TEST_BRANCH
base_branch: $TEST_BRANCH
review_started: false
---
EOF
cat > "$LOOP_DIR_14_4/round-0-summary.md" << 'EOF'
# Summary
Work done.
EOF
create_round_contract "$LOOP_DIR_14_4" 0
# 目标跟踪器包含所有占位符
cat > "$LOOP_DIR_14_4/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
[To be extracted from plan by Claude in Round 0]
### Acceptance Criteria
[To be defined by Claude in Round 0 based on the plan]
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
[To be populated by Claude based on plan]
EOF
export CLAUDE_PROJECT_DIR="$PWD"
set +e
RESULT=$(echo '{}' | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该报告所有三个缺失项行
# The exact format is: **<Section>**: Still contains placeholder text
if echo "$RESULT" | grep -qF '**Ultimate Goal**: Still contains placeholder text' && \
   echo "$RESULT" | grep -qF '**Acceptance Criteria**: Still contains placeholder text' && \
   echo "$RESULT" | grep -qF '**Active Tasks**: Still contains placeholder text'; then
    pass "Stop hook reports all three placeholders when all missing"
else
    fail "All placeholders reported" "all three **<Section>**: Still contains placeholder text lines" "output: $RESULT"
fi

echo ""
echo "=== Test: Legacy Path Handling (NEGATIVE TESTS) ==="
echo ""

# Test 15: Bash validator ALLOWS writes to legacy .humanize-loop.local (it's not a loop dir anymore)
echo "Test 15: Bash validator allows writes to legacy .humanize-loop.local"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > .humanize-loop.local/2024-01-01/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该退出 0（允许），因为遗留路径不再被视为循环目录
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Bash validator allows writes to legacy .humanize-loop.local"
else
    fail "Bash validator legacy path" "exit 0 (allowed)" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 16: Write validator ALLOWS writes to legacy .humanize-loop.local plan.md
echo "Test 16: Write validator allows writes to legacy .humanize-loop.local plan.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$TEST_DIR'/.humanize-loop.local/2024-01-01/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Write validator allows writes to legacy .humanize-loop.local plan.md"
else
    fail "Write validator legacy path" "exit 0 (allowed)" "exit $EXIT_CODE, output: $RESULT"
fi

# Test 17: Edit validator ALLOWS edits to legacy .humanize-loop.local plan.md
echo "Test 17: Edit validator allows edits to legacy .humanize-loop.local plan.md"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$TEST_DIR'/.humanize-loop.local/2024-01-01/plan.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Edit validator allows edits to legacy .humanize-loop.local plan.md"
else
    fail "Edit validator legacy path" "exit 0 (allowed)" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

exit $TESTS_FAILED
