#!/usr/bin/env bash
#
# Finalize 阶段功能的测试
#
# 正面测试用例：
# - T-POS-1: COMPLETE 触发 Finalize 入口
# - T-POS-2: Finalize 阶段完成流程
# - T-POS-3: Finalize-state 被检测为活跃循环
# - T-POS-4: Finalize 摘要文件可写
# - T-POS-5: 正常 RLCR 轮次不受影响
#
# 负面测试用例：
# - T-NEG-1: 最大迭代次数跳过 Finalize
# - T-NEG-2: Finalize 仍然需要 git 干净
# - T-NEG-3: Finalize 仍然需要摘要
# - T-NEG-4: Finalize 仍然需要待办事项完成
# - T-NEG-5: Finalize-state 文件受保护
# - T-NEG-6: Complete-state 不被检测为活跃
# - T-NEG-7: Finalize 阶段不触发 Codex
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

# 加载 loop-common.sh 以获取辅助函数
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

# 创建一个输出 COMPLETE 或自定义内容的模拟 codex
# 第二个参数（可选）是 codex 审查输出（默认为干净审查）
setup_mock_codex() {
    local output="$1"
    local review_output="${2:-No issues found.}"
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << EOF
#!/usr/bin/env bash
# 模拟 codex - 输出提供的内容
subcommand=""
for arg in "\$@"; do
    if [[ "\$arg" == "exec" || "\$arg" == "review" ]]; then
        subcommand="\$arg"
        break
    fi
done
if [[ "\$subcommand" == "exec" ]]; then
    cat << 'REVIEW'
$output
REVIEW
elif [[ "\$subcommand" == "review" ]]; then
    # 处理 codex 审查命令
    cat << 'REVIEWOUT'
$review_output
REVIEWOUT
fi
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# 创建一个跟踪是否被调用的模拟 codex
# 第二个参数（可选）是 codex 审查输出（默认为干净审查）
setup_mock_codex_with_tracking() {
    local output="$1"
    local review_output="${2:-No issues found.}"
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << EOF
#!/usr/bin/env bash
# 跟踪 codex 是否被调用
echo "CODEX_WAS_CALLED" > "$TEST_DIR/codex_called.marker"
subcommand=""
for arg in "\$@"; do
    if [[ "\$arg" == "exec" || "\$arg" == "review" ]]; then
        subcommand="\$arg"
        break
    fi
done
if [[ "\$subcommand" == "exec" ]]; then
    cat << 'REVIEW'
$output
REVIEW
elif [[ "\$subcommand" == "review" ]]; then
    cat << 'REVIEWOUT'
$review_output
REVIEWOUT
fi
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
    rm -f "$TEST_DIR/codex_called.marker"
}

# 创建一个在审查时失败的模拟 codex（非零退出）
# 参数: $1=exec_output, $2=review_exit_code（默认 1）
setup_mock_codex_review_failure() {
    local exec_output="$1"
    local review_exit_code="${2:-1}"
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << EOF
#!/usr/bin/env bash
# 模拟 codex - 审查命令失败
subcommand=""
for arg in "\$@"; do
    if [[ "\$arg" == "exec" || "\$arg" == "review" ]]; then
        subcommand="\$arg"
        break
    fi
done
if [[ "\$subcommand" == "exec" ]]; then
    cat << 'REVIEW'
$exec_output
REVIEW
elif [[ "\$subcommand" == "review" ]]; then
    # 模拟非零退出失败
    echo "Error: Codex review failed" >&2
    exit $review_exit_code
fi
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# 创建一个在审查时产生空标准输出的模拟 codex
# 参数: $1=exec_output
setup_mock_codex_review_empty_stdout() {
    local exec_output="$1"
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << EOF
#!/usr/bin/env bash
# 模拟 codex - 审查时产生空标准输出
subcommand=""
for arg in "\$@"; do
    if [[ "\$arg" == "exec" || "\$arg" == "review" ]]; then
        subcommand="\$arg"
        break
    fi
done
if [[ "\$subcommand" == "exec" ]]; then
    cat << 'REVIEW'
$exec_output
REVIEW
elif [[ "\$subcommand" == "review" ]]; then
    # 成功退出但不产生输出
    exit 0
fi
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

setup_test_repo() {
    cd "$TEST_DIR"

    if [[ ! -d ".git" ]]; then
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        echo "init" > init.txt
        git add init.txt
        git -c commit.gpgsign=false commit -q -m "Initial"

        # 创建计划文件
        mkdir -p plans
        cat > plans/test-plan.md << 'EOF'
# Test Plan
## Goal
Test the RLCR loop
## Requirements
- Requirement 1
- Requirement 2
- Requirement 3
EOF
        # 将 .humanize、bin 和 .cache 添加到 gitignore（它们由测试创建）
        cat >> .gitignore << 'GITIGNORE'
plans/
.humanize/
.humanize*
bin/
transcript.jsonl
.cache/
GITIGNORE
        git add .gitignore
        git -c commit.gpgsign=false commit -q -m "Add gitignore"
    fi
}

setup_loop_dir() {
    local round="$1"
    local max_iter="${2:-42}"

    LOOP_DIR="$TEST_DIR/.humanize/rlcr/2024-01-01_12-00-00"
    mkdir -p "$LOOP_DIR"

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    cat > "$LOOP_DIR/state.md" << EOF
---
current_round: $round
max_iterations: $max_iter
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 5400
push_every_round: false
plan_file: plans/test-plan.md
plan_tracked: false
start_branch: $current_branch
base_branch: main
review_started: false
mainline_stall_count: 0
last_mainline_verdict: unknown
drift_status: normal
started_at: 2024-01-01T12:00:00Z
---
EOF

    # 创建计划备份
    cp plans/test-plan.md "$LOOP_DIR/plan.md"

    # 创建目标跟踪器
    cat > "$LOOP_DIR/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test finalize phase
### Acceptance Criteria
| ID | Criterion |
|----|-----------|
| AC-1 | Test passes |
---
## MUTABLE SECTION
#### Active Tasks
| Task | Target AC | Status |
|------|-----------|--------|
| Test | AC-1 | completed |
EOF

    cat > "$LOOP_DIR/round-${round}-contract.md" << EOF
# Round $round Contract

- Mainline Objective: Verify finalize phase coverage
- Target ACs: AC-1
- Blocking Side Issues In Scope: none
- Queued Side Issues Out of Scope: none
- Success Criteria: current round artifacts are complete
EOF
}

echo "=== Test: Finalize Phase Feature ==="
echo ""

# ========================================
# 测试：辅助函数
# ========================================
echo "=== Helper Function Tests ==="
echo ""

# 测试：is_finalize_state_file_path
echo "Test: is_finalize_state_file_path matches finalize-state.md"
if is_finalize_state_file_path "finalize-state.md"; then
    pass "is_finalize_state_file_path matches finalize-state.md"
else
    fail "is_finalize_state_file_path" "true" "false"
fi

echo "Test: is_finalize_state_file_path does not match state.md"
if is_finalize_state_file_path "state.md"; then
    fail "is_finalize_state_file_path on state.md" "false" "true"
else
    pass "is_finalize_state_file_path does not match state.md"
fi

echo "Test: is_finalize_state_file_path matches full path"
if is_finalize_state_file_path "/path/to/loop/finalize-state.md"; then
    pass "is_finalize_state_file_path matches full path"
else
    fail "is_finalize_state_file_path full path" "true" "false"
fi

# 测试：is_finalize_summary_path
echo "Test: is_finalize_summary_path matches finalize-summary.md"
if is_finalize_summary_path "finalize-summary.md"; then
    pass "is_finalize_summary_path matches finalize-summary.md"
else
    fail "is_finalize_summary_path" "true" "false"
fi

echo "Test: is_finalize_summary_path does not match round-N-summary.md"
if is_finalize_summary_path "round-0-summary.md"; then
    fail "is_finalize_summary_path on round-N-summary.md" "false" "true"
else
    pass "is_finalize_summary_path does not match round-N-summary.md"
fi

echo "Test: finalize_state_file_blocked_message function exists"
if type finalize_state_file_blocked_message &>/dev/null; then
    pass "finalize_state_file_blocked_message function exists"
else
    fail "finalize_state_file_blocked_message" "function defined" "function not found"
fi

echo ""
echo "=== T-POS-3: Finalize-State Detection ==="
echo ""

setup_test_repo
setup_loop_dir 5
export CLAUDE_PROJECT_DIR="$TEST_DIR"

# 将 state.md 替换为 finalize-state.md
mv "$LOOP_DIR/state.md" "$LOOP_DIR/finalize-state.md"

echo "T-POS-3: finalize-state.md detected as active loop"
ACTIVE_LOOP=$(find_active_loop "$TEST_DIR/.humanize/rlcr")
if [[ -n "$ACTIVE_LOOP" ]]; then
    pass "finalize-state.md detected as active loop"
else
    fail "finalize-state.md detection" "active loop found" "no active loop"
fi

echo ""
echo "=== T-NEG-6: Complete-State Not Active ==="
echo ""

# 替换为 complete-state.md
rm -f "$LOOP_DIR/finalize-state.md"
cat > "$LOOP_DIR/complete-state.md" << 'EOF'
---
current_round: 5
max_iterations: 42
---
EOF

echo "T-NEG-6: complete-state.md not detected as active loop"
ACTIVE_LOOP=$(find_active_loop "$TEST_DIR/.humanize/rlcr")
if [[ -z "$ACTIVE_LOOP" ]]; then
    pass "complete-state.md not detected as active loop"
else
    fail "complete-state.md detection" "no active loop" "$ACTIVE_LOOP"
fi

echo ""
echo "=== T-POS-5: Normal RLCR Rounds Unaffected ==="
echo ""

rm -f "$LOOP_DIR/complete-state.md"
setup_loop_dir 3

echo "T-POS-5: state.md still detected as active loop"
ACTIVE_LOOP=$(find_active_loop "$TEST_DIR/.humanize/rlcr")
if [[ -n "$ACTIVE_LOOP" ]]; then
    pass "state.md still detected as active loop"
else
    fail "state.md detection" "active loop found" "no active loop"
fi

echo ""
echo "=== T-POS-4 & T-NEG-5: Write Validator Tests ==="
echo ""

# 重置到 finalize 阶段
setup_loop_dir 5
mv "$LOOP_DIR/state.md" "$LOOP_DIR/finalize-state.md"

echo "T-POS-4: Write validator allows finalize-summary.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/finalize-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Write validator allows finalize-summary.md"
else
    fail "Write validator finalize-summary.md" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5: Write validator blocks finalize-state.md"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/finalize-state.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "finalize"; then
    pass "Write validator blocks finalize-state.md"
else
    fail "Write validator finalize-state.md" "exit 2 with finalize error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5aa: Write validator blocks round contract during Finalize Phase"
HOOK_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-write-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "contract"; then
    pass "Write validator blocks finalize-phase round contract"
else
    fail "Write validator finalize-phase contract" "exit 2 with contract error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5b: Edit validator blocks finalize-state.md"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/finalize-state.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "finalize"; then
    pass "Edit validator blocks finalize-state.md"
else
    fail "Edit validator finalize-state.md" "exit 2 with finalize error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5bb: Edit validator blocks round contract during Finalize Phase"
HOOK_INPUT='{"tool_name": "Edit", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-edit-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "contract"; then
    pass "Edit validator blocks finalize-phase round contract"
else
    fail "Edit validator finalize-phase contract" "exit 2 with contract error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5c: Bash validator blocks finalize-state.md modification"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "echo test > '$LOOP_DIR'/finalize-state.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "finalize"; then
    pass "Bash validator blocks finalize-state.md modification"
else
    fail "Bash validator finalize-state.md" "exit 2 with finalize error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5d: Bash validator blocks mv FROM finalize-state.md (source protection)"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "mv '$LOOP_DIR'/finalize-state.md /tmp/backup.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "finalize"; then
    pass "Bash validator blocks mv FROM finalize-state.md"
else
    fail "Bash validator mv FROM finalize-state.md" "exit 2 with finalize error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "T-NEG-5e: Bash validator blocks cp FROM finalize-state.md (source protection)"
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "cp '$LOOP_DIR'/finalize-state.md /tmp/backup.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "finalize"; then
    pass "Bash validator blocks cp FROM finalize-state.md"
else
    fail "Bash validator cp FROM finalize-state.md" "exit 2 with finalize error" "exit $EXIT_CODE, output: $RESULT"
fi

echo ""
echo "=== T-POS-2 & T-NEG-2/3/7: Stop Hook Finalize Phase Tests ==="
echo ""

# Stop Hook 测试设置
setup_test_repo
setup_loop_dir 5
mv "$LOOP_DIR/state.md" "$LOOP_DIR/finalize-state.md"
setup_mock_codex_with_tracking "All looks good.

COMPLETE"

# T-NEG-3：缺少摘要阻止退出
echo "T-NEG-3: Finalize phase blocks exit when summary missing"
# 确保摘要不存在
rm -f "$LOOP_DIR/finalize-summary.md"
# 创建空的 hook 输入（Stop hook 的最小输入）
HOOK_INPUT='{"stop_hook_active": false, "transcript": []}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 检查是否因缺少摘要消息而阻止
if echo "$RESULT" | grep -q '"decision".*block' && echo "$RESULT" | grep -qi "summary"; then
    pass "Finalize phase blocks exit when summary missing"
else
    fail "Finalize phase missing summary check" "block with summary error" "exit $EXIT_CODE, output: $RESULT"
fi

# T-NEG-7：验证 Codex 未被调用
echo "T-NEG-7: Finalize phase does not invoke Codex"
if [[ ! -f "$TEST_DIR/codex_called.marker" ]]; then
    pass "Finalize phase does not invoke Codex (summary check)"
else
    fail "Finalize phase Codex invocation" "Codex not called" "Codex was called"
fi

# T-NEG-2：Git 不干净阻止退出
echo "T-NEG-2: Finalize phase blocks exit when git not clean"
# 创建 finalize-summary.md 以通过该检查
cat > "$LOOP_DIR/finalize-summary.md" << 'EOF'
# Finalize Summary
Simplified code.
EOF
# 创建未提交的更改
echo "uncommitted" > "$TEST_DIR/dirty.txt"
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
if echo "$RESULT" | grep -q '"decision".*block' && echo "$RESULT" | grep -qi "uncommitted\|git\|clean"; then
    pass "Finalize phase blocks exit when git not clean"
else
    fail "Finalize phase git clean check" "block with git error" "exit $EXIT_CODE, output: $RESULT"
fi

# 清理 git 状态
rm -f "$TEST_DIR/dirty.txt"

# T-POS-2：所有检查通过时 Finalize 阶段完成
echo "T-POS-2: Finalize phase completes when all checks pass"
# 确保 git 干净
git -C "$TEST_DIR" status --porcelain
# 清除 codex 标记
rm -f "$TEST_DIR/codex_called.marker"
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该允许退出（退出 0，无阻止决策）
if [[ $EXIT_CODE -eq 0 ]] && ! echo "$RESULT" | grep -q '"decision".*block'; then
    # 同时验证状态文件已重命名为 complete-state.md
    if [[ -f "$LOOP_DIR/complete-state.md" ]] && [[ ! -f "$LOOP_DIR/finalize-state.md" ]]; then
        pass "Finalize phase completes and renames to complete-state.md"
    else
        fail "Finalize phase completion" "finalize-state.md renamed to complete-state.md" "state files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
    fi
else
    fail "Finalize phase completion" "exit 0, no block" "exit $EXIT_CODE, output: $RESULT"
fi

# T-NEG-7 续：验证完成期间 Codex 未被调用
echo "T-NEG-7b: Finalize phase completion does not invoke Codex"
if [[ ! -f "$TEST_DIR/codex_called.marker" ]]; then
    pass "Finalize phase completion does not invoke Codex"
else
    fail "Finalize phase completion Codex" "Codex not called" "Codex was called"
fi

echo ""
echo "=== T-POS-1 & T-NEG-1: COMPLETE Handling Tests ==="
echo ""

# 为 COMPLETE 处理测试重置测试环境
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10  # current_round: 3, max_iterations: 10
setup_mock_codex "All requirements met.

Mainline Progress Verdict: ADVANCED

COMPLETE"

# 为当前轮次创建摘要
cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
Implemented all features.
EOF

echo "T-POS-1: COMPLETE triggers Finalize Phase entry"
HOOK_INPUT='{"stop_hook_active": false, "transcript": []}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该用 Finalize 阶段提示阻止并创建 finalize-state.md
if echo "$RESULT" | grep -q '"decision".*block' && [[ -f "$LOOP_DIR/finalize-state.md" ]] && [[ ! -f "$LOOP_DIR/state.md" ]]; then
    # 同时检查提示是否提到代码简化器
    if echo "$RESULT" | grep -qi "simplif"; then
        pass "COMPLETE triggers Finalize Phase (state.md -> finalize-state.md, block with Finalize prompt)"
    else
        fail "COMPLETE Finalize prompt" "prompt mentioning simplification" "output: $RESULT"
    fi
else
    fail "COMPLETE Finalize entry" "block with finalize-state.md" "exit $EXIT_CODE, files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none'), output: $RESULT"
fi

# T-NEG-1：最大迭代次数跳过 Finalize
echo "T-NEG-1: Max iterations skips Finalize Phase"
rm -rf "$TEST_DIR/.humanize"
setup_loop_dir 10 10  # current_round: 10, max_iterations: 10 (at max)
# 为当前轮次创建摘要
cat > "$LOOP_DIR/round-10-summary.md" << 'EOF'
# Round 10 Summary
Final iteration.
EOF
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 不应该创建 finalize-state.md，应该创建 maxiter-state.md
if [[ -f "$LOOP_DIR/maxiter-state.md" ]] && [[ ! -f "$LOOP_DIR/finalize-state.md" ]] && [[ ! -f "$LOOP_DIR/state.md" ]]; then
    pass "Max iterations skips Finalize Phase (creates maxiter-state.md)"
else
    fail "Max iterations skip Finalize" "maxiter-state.md (no finalize-state.md)" "files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
fi

echo ""
echo "=== T-NEG-8: Review Phase Blocks on Codex Review Failure ==="
echo ""

# T-NEG-8a：COMPLETE 触发审查，但 codex 审查失败（非零退出）
# 应该阻止而不是跳到 finalize
echo "T-NEG-8a: COMPLETE with codex review failure blocks exit (non-zero exit)"
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10  # current_round: 3, max_iterations: 10
setup_mock_codex_review_failure "All requirements met.

Mainline Progress Verdict: ADVANCED

COMPLETE" 1

# 为当前轮次创建摘要
cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
Implemented all features.
EOF

HOOK_INPUT='{"stop_hook_active": false, "transcript": []}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e

# 应该阻止（不允许退出）且不创建 finalize-state.md 或 complete-state.md
# state.md 应该仍然存在（或 review_started 应该为 true）
if echo "$RESULT" | grep -q '"decision".*block'; then
    # 检查我们没有转换到 finalize
    if [[ ! -f "$LOOP_DIR/finalize-state.md" ]] && [[ ! -f "$LOOP_DIR/complete-state.md" ]]; then
        pass "COMPLETE with codex review failure blocks exit"
    else
        fail "Review failure blocks" "no finalize-state.md or complete-state.md" "files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
    fi
else
    fail "Review failure blocks" "block decision" "exit $EXIT_CODE, decision not block, output: $(echo "$RESULT" | head -5)"
fi

# T-NEG-8b：验证阻止消息提到审查失败
echo "T-NEG-8b: Block message indicates review failure"
if echo "$RESULT" | grep -qi "review.*fail\|codex.*fail\|retry"; then
    pass "Block message indicates review failure"
else
    fail "Review failure message" "message mentioning review failure/retry" "output does not indicate failure"
fi

# T-NEG-8c：验证 state.md 仍然存在且 review_started: true
echo "T-NEG-8c: state.md preserved with review_started: true after failure"
if [[ -f "$LOOP_DIR/state.md" ]]; then
    if grep -q "review_started: true" "$LOOP_DIR/state.md"; then
        pass "state.md preserved with review_started: true"
    else
        fail "State preservation" "state.md with review_started: true" "state.md exists but review_started is not true: $(grep review_started "$LOOP_DIR/state.md" 2>/dev/null || echo 'field not found')"
    fi
else
    fail "State preservation" "state.md exists" "state.md not found, files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
fi

echo ""
echo "=== T-NEG-9: Review Phase Blocks on Empty Codex Review Output ==="
echo ""

# T-NEG-9a：COMPLETE 触发审查，但 codex 审查产生空标准输出
# 应该阻止而不是跳到 finalize
echo "T-NEG-9a: COMPLETE with empty codex review output blocks exit"
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 4 10  # current_round: 4, max_iterations: 10
setup_mock_codex_review_empty_stdout "All requirements met.

Mainline Progress Verdict: ADVANCED

COMPLETE"

# 为当前轮次创建摘要
cat > "$LOOP_DIR/round-4-summary.md" << 'EOF'
# Round 4 Summary
Implemented all features.
EOF

HOOK_INPUT='{"stop_hook_active": false, "transcript": []}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e

# 应该阻止（不允许退出）且不创建 finalize-state.md 或 complete-state.md
if echo "$RESULT" | grep -q '"decision".*block'; then
    # 检查我们没有转换到 finalize
    if [[ ! -f "$LOOP_DIR/finalize-state.md" ]] && [[ ! -f "$LOOP_DIR/complete-state.md" ]]; then
        pass "COMPLETE with empty codex review output blocks exit"
    else
        fail "Empty review blocks" "no finalize-state.md or complete-state.md" "files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
    fi
else
    fail "Empty review blocks" "block decision" "exit $EXIT_CODE, decision not block, output: $(echo "$RESULT" | head -5)"
fi

# T-NEG-9b：验证日志文件存在且为空（合并 stdout+stderr）
echo "T-NEG-9b: Codex review log file exists and is empty"
# 使用与 loop-codex-stop-hook.sh 相同的逻辑计算真实缓存目录
# 缓存路径: $XDG_CACHE_HOME/humanize/$SANITIZED_PROJECT_PATH/$LOOP_TIMESTAMP/round-N-codex-review.log
LOOP_TIMESTAMP=$(basename "$LOOP_DIR")
# 规范化测试目录以匹配 loop-codex-stop-hook.sh 通过 resolve_project_root 计算的结果
CANONICAL_TEST_DIR=$(realpath "$TEST_DIR" 2>/dev/null || echo "$TEST_DIR")
SANITIZED_PROJECT_PATH=$(echo "$CANONICAL_TEST_DIR" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
REVIEW_CACHE_DIR="$XDG_CACHE_HOME/humanize/$SANITIZED_PROJECT_PATH/$LOOP_TIMESTAMP"
# 第 5 轮因为我们传递 CURRENT_ROUND + 1 (4 + 1 = 5) 给 run_and_handle_code_review
REVIEW_LOG="$REVIEW_CACHE_DIR/round-5-codex-review.log"
if [[ -f "$REVIEW_LOG" ]] && [[ ! -s "$REVIEW_LOG" ]]; then
    pass "Codex review log file exists and is empty"
else
    if [[ ! -f "$REVIEW_LOG" ]]; then
        fail "Empty log verification" "log file exists (at $REVIEW_LOG)" "file does not exist"
    else
        fail "Empty log verification" "log file is empty" "log file has content: $(cat "$REVIEW_LOG" | head -3)"
    fi
fi

# T-NEG-9c：验证阻止消息提到空输出或重试
echo "T-NEG-9c: Block message indicates empty output or need for retry"
if echo "$RESULT" | grep -qi "empty\|no.*output\|retry\|fail"; then
    pass "Block message indicates empty output or retry needed"
else
    fail "Empty output message" "message mentioning empty output/retry" "output does not indicate empty/retry"
fi

# T-NEG-9d：验证 state.md 仍然存在且 review_started: true
echo "T-NEG-9d: state.md preserved with review_started: true after empty output"
if [[ -f "$LOOP_DIR/state.md" ]]; then
    if grep -q "review_started: true" "$LOOP_DIR/state.md"; then
        pass "state.md preserved with review_started: true"
    else
        fail "State preservation" "state.md with review_started: true" "state.md exists but review_started is not true: $(grep review_started "$LOOP_DIR/state.md" 2>/dev/null || echo 'field not found')"
    fi
else
    fail "State preservation" "state.md exists" "state.md not found, files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none')"
fi

echo ""
echo "=== T-NEG-4: Finalize Phase Requires Todos Complete ==="
echo ""

# T-NEG-4 设置：带有未完成待办事项的 Finalize 阶段
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 5
mv "$LOOP_DIR/state.md" "$LOOP_DIR/finalize-state.md"
setup_mock_codex_with_tracking "COMPLETE"

# 创建 finalize-summary.md 以通过摘要检查
cat > "$LOOP_DIR/finalize-summary.md" << 'EOF'
# Finalize Summary
Code simplification complete.
EOF

# 创建带有未完成待办事项的转录
TRANSCRIPT_FILE="$TEST_DIR/transcript.jsonl"
cat > "$TRANSCRIPT_FILE" << 'EOF'
{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "TodoWrite", "input": {"todos": [{"content": "Task 1", "status": "completed", "activeForm": "Doing Task 1"}, {"content": "Task 2", "status": "in_progress", "activeForm": "Doing Task 2"}]}}]}}
EOF

echo "T-NEG-4: Finalize phase blocks exit when todos incomplete"
HOOK_INPUT='{"stop_hook_active": false, "transcript_path": "'$TRANSCRIPT_FILE'"}'
rm -f "$TEST_DIR/codex_called.marker"
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该用未完成待办事项消息阻止
if echo "$RESULT" | grep -q '"decision".*block' && echo "$RESULT" | grep -qi "todo\|task"; then
    pass "Finalize phase blocks exit when todos incomplete"
else
    fail "Finalize phase incomplete todos check" "block with todos error" "exit $EXIT_CODE, output: $RESULT"
fi

# 验证 Codex 未被调用（检查在 Codex 审查之前，但 Finalize 无论如何跳过 Codex）
echo "T-NEG-4b: Codex not invoked during incomplete todos check"
if [[ ! -f "$TEST_DIR/codex_called.marker" ]]; then
    pass "Codex not invoked during incomplete todos check"
else
    fail "Codex invocation during todos check" "Codex not called" "Codex was called"
fi

echo ""
echo "=== T-POS-5: Normal RLCR Rounds Unaffected (Stop Hook) ==="
echo ""

# T-POS-5 设置：带有非 COMPLETE Codex 审查的正常轮次
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10  # current_round: 3, max_iterations: 10

# 创建一个输出审查反馈的模拟 Codex（非 COMPLETE）
setup_mock_codex "## Review Feedback

Mainline Progress Verdict: ADVANCED

Some issues need to be addressed:
- Issue 1: Fix the bug in function X
- Issue 2: Add tests for edge case Y

Please address these issues and try again.

CONTINUE"

# 为当前轮次创建摘要 (required to pass summary check)
cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
Implemented the feature.
EOF

# 创建所有待办事项已完成的转录（以通过待办检查）
TRANSCRIPT_FILE="$TEST_DIR/transcript.jsonl"
cat > "$TRANSCRIPT_FILE" << 'EOF'
{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "TodoWrite", "input": {"todos": [{"content": "Implement feature", "status": "completed", "activeForm": "Implementing"}]}}]}}
EOF

echo "T-POS-5: Normal round with non-COMPLETE review blocks with feedback"
HOOK_INPUT='{"stop_hook_active": false, "transcript_path": "'$TRANSCRIPT_FILE'"}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e
# T-POS-5 的关键断言：
# 1. 应该阻止（不允许退出）
# 2. state.md 应该仍然存在（未重命名为 finalize-state.md 或 complete-state.md）
# 3. 应该为下一轮产生反馈（在输出中或通过轮次文件）
if echo "$RESULT" | grep -q '"decision".*block' && [[ -f "$LOOP_DIR/state.md" ]] && [[ ! -f "$LOOP_DIR/finalize-state.md" ]] && [[ ! -f "$LOOP_DIR/complete-state.md" ]]; then
    pass "Normal round blocks with feedback, keeps state.md intact (not renamed)"
else
    fail "Normal round behavior" "block with state.md intact" "exit $EXIT_CODE, files: $(ls $LOOP_DIR/*state*.md 2>/dev/null || echo 'none'), output: $RESULT"
fi

# 附加检查：state.md 轮次应该为下一轮递增
parse_state_file "$LOOP_DIR/state.md"
if [[ "$STATE_CURRENT_ROUND" == "4" ]]; then
    pass "Normal round increments current_round to 4"
else
    fail "Normal round increment" "current_round: 4" "current_round: $STATE_CURRENT_ROUND"
fi

# T-POS-5c：验证审查结果文件已创建（证明 Codex 审查被调用）
echo "T-POS-5c: Codex review result file created"
if [[ -f "$LOOP_DIR/round-3-review-result.md" ]]; then
    pass "Codex review result file round-3-review-result.md created"
else
    fail "Codex review result file" "round-3-review-result.md exists" "file not found in $LOOP_DIR"
fi

# T-POS-5d：验证审查反馈内容包含在阻止输出中
# 模拟 Codex 输出 "Issue 1: Fix the bug" - 这应该出现在原因中
echo "T-POS-5d: Block output contains Codex review feedback"
if echo "$RESULT" | grep -q "Issue 1"; then
    pass "Block output contains Codex review feedback"
else
    fail "Review feedback in output" "output contains 'Issue 1' from Codex review" "output does not contain expected feedback"
fi

echo ""
echo "=== T-POS-6 / T-NEG-10: Mainline Drift State Machine ==="
echo ""

# T-POS-6：连续两轮停滞触发漂移恢复提示
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10
perl -0pi -e 's/mainline_stall_count: 0/mainline_stall_count: 1/' "$LOOP_DIR/state.md"
perl -0pi -e 's/last_mainline_verdict: unknown/last_mainline_verdict: stalled/' "$LOOP_DIR/state.md"

setup_mock_codex "## Review Feedback

Mainline Progress Verdict: STALLED

- Mainline gap: AC-1 still lacks a passing implementation path
- Blocking side issue: current approach keeps looping on the same failing path

Please recover the mainline before trying again.

CONTINUE"

cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
Tried another implementation pass, but AC-1 is still not advancing.
EOF

TRANSCRIPT_FILE="$TEST_DIR/transcript.jsonl"
cat > "$TRANSCRIPT_FILE" << 'EOF'
{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "TodoWrite", "input": {"todos": [{"content": "[mainline] Recover AC-1", "status": "completed", "activeForm": "Recovering AC-1"}]}}]}}
EOF

echo "T-POS-6: Two stalled rounds trigger drift recovery prompt"
HOOK_INPUT='{"stop_hook_active": false, "transcript_path": "'$TRANSCRIPT_FILE'"}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e

if echo "$RESULT" | grep -q '"decision".*block' && [[ -f "$LOOP_DIR/round-4-prompt.md" ]]; then
    pass "Drift recovery round blocks exit and creates next prompt"
else
    fail "Drift recovery prompt creation" "block with round-4 prompt" "exit $EXIT_CODE, output: $RESULT"
fi

if grep -q "Drift Recovery Mode" "$LOOP_DIR/round-4-prompt.md"; then
    pass "Drift recovery prompt uses special replan template"
else
    fail "Drift recovery prompt template" "Drift Recovery Mode in prompt" "$(cat "$LOOP_DIR/round-4-prompt.md")"
fi

parse_state_file "$LOOP_DIR/state.md"
if [[ "$STATE_CURRENT_ROUND" == "4" ]] && [[ "$STATE_MAINLINE_STALL_COUNT" == "2" ]] && [[ "$STATE_LAST_MAINLINE_VERDICT" == "stalled" ]] && [[ "$STATE_DRIFT_STATUS" == "replan_required" ]]; then
    pass "State records drift recovery requirement after second stalled round"
else
    fail "Drift recovery state update" "round=4 stall=2 verdict=stalled drift=replan_required" \
        "round=$STATE_CURRENT_ROUND stall=$STATE_MAINLINE_STALL_COUNT verdict=$STATE_LAST_MAINLINE_VERDICT drift=$STATE_DRIFT_STATUS"
fi

# T-NEG-10a：缺少主线进度判定阻止退出并保留状态
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10
perl -0pi -e 's/mainline_stall_count: 0/mainline_stall_count: 1/' "$LOOP_DIR/state.md"
perl -0pi -e 's/last_mainline_verdict: unknown/last_mainline_verdict: stalled/' "$LOOP_DIR/state.md"

setup_mock_codex "## Review Feedback

- Mainline gap: AC-1 still lacks a passing implementation path
- Blocking side issue: current approach keeps looping on the same failing path

Please restate the mainline more clearly.

CONTINUE"

cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
Tried another implementation pass, but the review omitted the verdict line.
EOF

echo "T-NEG-10a: Missing Mainline Progress Verdict blocks exit"
HOOK_INPUT='{"stop_hook_active": false, "transcript_path": "'$TRANSCRIPT_FILE'"}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e

if echo "$RESULT" | grep -q '"decision".*block' && echo "$RESULT" | grep -qi "verdict"; then
    pass "Missing Mainline Progress Verdict blocks exit"
else
    fail "Missing Mainline Progress Verdict" "block with verdict error" "exit $EXIT_CODE, output: $RESULT"
fi

if [[ ! -f "$LOOP_DIR/round-4-prompt.md" ]]; then
    pass "Missing verdict does not generate next-round prompt"
else
    fail "Missing verdict prompt generation" "no round-4 prompt" "$(cat "$LOOP_DIR/round-4-prompt.md")"
fi

parse_state_file "$LOOP_DIR/state.md"
if [[ "$STATE_CURRENT_ROUND" == "3" ]] && [[ "$STATE_MAINLINE_STALL_COUNT" == "1" ]] && [[ "$STATE_LAST_MAINLINE_VERDICT" == "stalled" ]] && [[ "$STATE_DRIFT_STATUS" == "normal" ]]; then
    pass "Missing verdict preserves prior drift state"
else
    fail "Missing verdict state preservation" "round=3 stall=1 verdict=stalled drift=normal" \
        "round=$STATE_CURRENT_ROUND stall=$STATE_MAINLINE_STALL_COUNT verdict=$STATE_LAST_MAINLINE_VERDICT drift=$STATE_DRIFT_STATUS"
fi

# T-NEG-10：第三轮连续停滞/回退停止循环
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 3 10
perl -0pi -e 's/mainline_stall_count: 0/mainline_stall_count: 2/' "$LOOP_DIR/state.md"
perl -0pi -e 's/last_mainline_verdict: unknown/last_mainline_verdict: stalled/' "$LOOP_DIR/state.md"
perl -0pi -e 's/drift_status: normal/drift_status: replan_required/' "$LOOP_DIR/state.md"

setup_mock_codex "## Review Feedback

Mainline Progress Verdict: REGRESSED

- Mainline gap: this round moved farther from AC-1
- Blocking side issue: recent fixes keep undoing the prior mainline path

Stop and replan.

CONTINUE"

cat > "$LOOP_DIR/round-3-summary.md" << 'EOF'
# Round 3 Summary
The latest attempt regressed the mainline objective again.
EOF

echo "T-NEG-10: Third stalled/regressed round triggers circuit breaker"
HOOK_INPUT='{"stop_hook_active": false, "transcript_path": "'$TRANSCRIPT_FILE'"}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh" 2>&1)
EXIT_CODE=$?
set -e

if [[ -f "$LOOP_DIR/stop-state.md" ]] && echo "$RESULT" | grep -qi "drift"; then
    pass "Third stalled/regressed round stops the loop with drift message"
else
    fail "Drift circuit breaker" "stop-state.md and drift message" "exit $EXIT_CODE, files: $(ls "$LOOP_DIR"/*state*.md 2>/dev/null || echo 'none'), output: $RESULT"
fi

parse_state_file "$LOOP_DIR/stop-state.md"
if [[ "$STATE_MAINLINE_STALL_COUNT" == "3" ]] && [[ "$STATE_LAST_MAINLINE_VERDICT" == "regressed" ]] && [[ "$STATE_DRIFT_STATUS" == "replan_required" ]]; then
    pass "Stopped loop preserves final drift state"
else
    fail "Preserved drift state on stop" "stall=3 verdict=regressed drift=replan_required" \
        "stall=$STATE_MAINLINE_STALL_COUNT verdict=$STATE_LAST_MAINLINE_VERDICT drift=$STATE_DRIFT_STATUS"
fi

echo ""
echo "=== Validator Finalize Phase State Parsing Tests ==="
echo ""

# 测试验证器正确解析 finalize-state.md
rm -rf "$TEST_DIR/.humanize"
setup_test_repo
setup_loop_dir 5
mv "$LOOP_DIR/state.md" "$LOOP_DIR/finalize-state.md"

echo "Test: Bash validator parses finalize-state.md correctly"
# 当只有 finalize-state.md 存在时，bash 验证器不应报错
HOOK_INPUT='{"tool_name": "Bash", "tool_input": {"command": "ls"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-bash-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Bash validator parses finalize-state.md without errors"
else
    fail "Bash validator finalize-state.md parsing" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

echo "Test: Read validator parses finalize-state.md correctly"
# 尝试读取当前轮次摘要（第 5 轮）
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-summary.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# 应该允许读取当前轮次文件
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Read validator parses finalize-state.md and allows current round"
else
    fail "Read validator finalize-state.md parsing" "exit 0" "exit $EXIT_CODE, output: $RESULT"
fi

echo "Test: Read validator blocks round contract during Finalize Phase"
HOOK_INPUT='{"tool_name": "Read", "tool_input": {"file_path": "'$LOOP_DIR'/round-5-contract.md"}}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-read-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -eq 2 ]] && echo "$RESULT" | grep -qi "contract"; then
    pass "Read validator blocks finalize-phase round contract"
else
    fail "Read validator finalize-phase contract" "exit 2 with contract error" "exit $EXIT_CODE, output: $RESULT"
fi

echo "Test: Plan-file validator parses finalize-state.md correctly"
# 当只有 finalize-state.md 存在时，plan-file 验证器不应报错
HOOK_INPUT='{"prompt": "test prompt"}'
set +e
RESULT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/hooks/loop-plan-file-validator.sh" 2>&1)
EXIT_CODE=$?
set -e
# 当 schema 有效且分支一致时应该成功（退出 0）
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Plan-file validator parses finalize-state.md without errors"
else
    fail "Plan-file validator finalize-state.md parsing" "exit 0" "exit $EXIT_CODE, output: $RESULT"
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
