#!/usr/bin/env bash
#
# rlcr-stop-gate 包装器项目根目录检测的测试
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

GATE_SCRIPT="$SCRIPT_DIR/../scripts/rlcr-stop-gate.sh"

echo "=========================================="
echo "RLCR Stop Gate Wrapper Tests"
echo "=========================================="
echo ""

# 构建一个最小活跃循环，在缺少摘要文件时应阻止。
setup_active_loop_fixture() {
    local project_dir="$1"

    init_test_git_repo "$project_dir"
    local branch
    branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD)

    mkdir -p "$project_dir/.humanize/rlcr/2026-03-01_00-00-00"

    cat > "$project_dir/plan.md" << 'PLANEOF'
# Test Plan

Line 1
Line 2
Line 3
Line 4
PLANEOF

    cp "$project_dir/plan.md" "$project_dir/.humanize/rlcr/2026-03-01_00-00-00/plan.md"

    cat > "$project_dir/.humanize/rlcr/2026-03-01_00-00-00/state.md" <<EOF_STATE
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: $branch
base_branch: $branch
base_commit: deadbeef
review_started: false
ask_codex_question: true
session_id:
agent_teams: false
---
EOF_STATE
}

# 单次 setup_test_dir 调用，避免 EXIT 陷阱覆盖和临时目录泄漏。
setup_test_dir

# 测试 1：默认项目根目录应为调用者当前目录（非插件安装目录）
T1_DIR="$TEST_DIR/t1"
mkdir -p "$T1_DIR"
setup_active_loop_fixture "$T1_DIR/project"

set +e
(
    cd "$T1_DIR/project"
    CLAUDE_PROJECT_DIR="" "$GATE_SCRIPT"
) > "$T1_DIR/out.txt" 2>&1
EXIT1=$?
set -e

if [[ "$EXIT1" -eq 10 ]]; then
    pass "rlcr-stop-gate default project root uses cwd and blocks active loop"
else
    OUTPUT1=$(cat "$T1_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate default project root uses cwd and blocks active loop" "exit 10" "exit $EXIT1; output: $OUTPUT1"
fi

if grep -q "^BLOCK:" "$T1_DIR/out.txt" 2>/dev/null; then
    pass "rlcr-stop-gate reports a real loop blocking reason"
else
    OUTPUT1=$(cat "$T1_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate reports a real loop blocking reason" "output containing BLOCK:" "$OUTPUT1"
fi

# 测试 2：--project-root 覆盖从目标仓库外部工作
T2_DIR="$TEST_DIR/t2"
mkdir -p "$T2_DIR"
setup_active_loop_fixture "$T2_DIR/project"

set +e
(
    cd "$T2_DIR"
    "$GATE_SCRIPT" --project-root "$T2_DIR/project"
) > "$T2_DIR/out.txt" 2>&1
EXIT2=$?
set -e

if [[ "$EXIT2" -eq 10 ]]; then
    pass "rlcr-stop-gate --project-root override blocks using target repo loop"
else
    OUTPUT2=$(cat "$T2_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate --project-root override blocks using target repo loop" "exit 10" "exit $EXIT2; output: $OUTPUT2"
fi

if grep -q "^BLOCK:" "$T2_DIR/out.txt" 2>/dev/null; then
    pass "rlcr-stop-gate --project-root output contains expected block reason"
else
    OUTPUT2=$(cat "$T2_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate --project-root output contains expected block reason" "output containing BLOCK:" "$OUTPUT2"
fi

# 测试 3：已跟踪的 Humanize 状态在正常循环验证之前阻止
T3_DIR="$TEST_DIR/t3"
mkdir -p "$T3_DIR"
setup_active_loop_fixture "$T3_DIR/project"
echo "tracked" > "$T3_DIR/project/.humanize/rlcr/2026-03-01_00-00-00/goal-tracker.md"
git -C "$T3_DIR/project" add -f .humanize/rlcr/2026-03-01_00-00-00/goal-tracker.md

set +e
(
    cd "$T3_DIR/project"
    CLAUDE_PROJECT_DIR="" "$GATE_SCRIPT"
) > "$T3_DIR/out.txt" 2>&1
EXIT3=$?
set -e

if [[ "$EXIT3" -eq 10 ]]; then
    pass "rlcr-stop-gate blocks tracked Humanize state"
else
    OUTPUT3=$(cat "$T3_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate blocks tracked Humanize state" "exit 10" "exit $EXIT3; output: $OUTPUT3"
fi

if grep -q "Tracked Humanize State Blocked" "$T3_DIR/out.txt" 2>/dev/null; then
    pass "rlcr-stop-gate reports tracked Humanize state with dedicated reason"
else
    OUTPUT3=$(cat "$T3_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate reports tracked Humanize state with dedicated reason" "output containing Tracked Humanize State Blocked" "$OUTPUT3"
fi

# 测试 4：以 .humanize- 开头的无关点文件不得被视为循环状态。
# .humanize-backup 和 .humanizeconfig 被 git add 验证器明确允许
# （tests/test-humanize-escape.sh）；已跟踪状态守卫必须保持一致并忽略它们。
T4_DIR="$TEST_DIR/t4"
mkdir -p "$T4_DIR"
setup_active_loop_fixture "$T4_DIR/project"
echo "not loop state" > "$T4_DIR/project/.humanize-backup"
echo "not loop state" > "$T4_DIR/project/.humanizeconfig"
git -C "$T4_DIR/project" add -f .humanize-backup .humanizeconfig

set +e
(
    cd "$T4_DIR/project"
    CLAUDE_PROJECT_DIR="" "$GATE_SCRIPT"
) > "$T4_DIR/out.txt" 2>&1
EXIT4=$?
set -e

if [[ "$EXIT4" -eq 10 ]]; then
    pass "rlcr-stop-gate does not confuse .humanize-backup with loop state"
else
    OUTPUT4=$(cat "$T4_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate does not confuse .humanize-backup with loop state" "exit 10" "exit $EXIT4; output: $OUTPUT4"
fi

if ! grep -q "Tracked Humanize State Blocked" "$T4_DIR/out.txt" 2>/dev/null; then
    pass "rlcr-stop-gate does not emit tracked-state reason for .humanize-backup"
else
    OUTPUT4=$(cat "$T4_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate does not emit tracked-state reason for .humanize-backup" "no Tracked Humanize State Blocked line" "$OUTPUT4"
fi

# 测试 5：无活跃循环 -> 闸门允许退出（exit 0）
T5_DIR="$TEST_DIR/t5"
mkdir -p "$T5_DIR/empty-project"

set +e
(
    cd "$T5_DIR/empty-project"
    CLAUDE_PROJECT_DIR="" "$GATE_SCRIPT"
) > "$T5_DIR/out.txt" 2>&1
EXIT5=$?
set -e

if [[ "$EXIT5" -eq 0 ]]; then
    pass "rlcr-stop-gate exits 0 when no active loop exists"
else
    OUTPUT5=$(cat "$T5_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate exits 0 when no active loop exists" "exit 0" "exit $EXIT5; output: $OUTPUT5"
fi

if grep -q "^ALLOW:" "$T5_DIR/out.txt" 2>/dev/null; then
    pass "rlcr-stop-gate reports ALLOW when no active loop"
else
    OUTPUT5=$(cat "$T5_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate reports ALLOW when no active loop" "output containing ALLOW:" "$OUTPUT5"
fi

# 测试 6：空 session_id 不得从钩子输入 JSON 中删除 transcript_path
# （回归问题：当任何选定字段为空时，用作普通对象值的 `select(length > 0)`
# 会将整个封闭对象折叠为空，即使只有 session_id 缺失也会清除
# transcript_path 等转发字段）。修复方法用显式 if/then/else 替换
# 普通 select，使每个字段在输入为空时独立变为 null。
T6_DIR="$TEST_DIR/t6"
mkdir -p "$T6_DIR/bin"

# 模拟钩子，回显收到的原始 stdin，以便我们可以检查
# rlcr-stop-gate.sh 构建的 JSON，而不依赖真实钩子的
# 待处理后台逻辑。
cat > "$T6_DIR/bin/loop-codex-stop-hook.sh" <<'MOCK_HOOK_EOF'
#!/usr/bin/env bash
set -euo pipefail
INPUT="$(cat)"
# Emit a JSON block so the gate wrapper walks the non-"allow on empty"
# branch. We set decision:"block" AND include a recognizable reason the
# test can grep for.
printf '%s\n' "$INPUT" > "${MOCK_HOOK_INPUT_LOG:-/dev/null}"
printf '%s\n' '{"decision":"block","reason":"mock-hook","systemMessage":"mock"}'
MOCK_HOOK_EOF
chmod +x "$T6_DIR/bin/loop-codex-stop-hook.sh"

# rlcr-stop-gate.sh 期望的布局：HUMANIZE_ROOT/hooks/loop-codex-stop-hook.sh。
# 我们设置一个指向模拟钩子的假插件根目录，并将闸门包装器复制到旁边，
# 使相对解析指向模拟钩子。
mkdir -p "$T6_DIR/plugin/scripts" "$T6_DIR/plugin/hooks/lib"
cp "$T6_DIR/bin/loop-codex-stop-hook.sh" "$T6_DIR/plugin/hooks/loop-codex-stop-hook.sh"
cp "$GATE_SCRIPT" "$T6_DIR/plugin/scripts/rlcr-stop-gate.sh"
# rlcr-stop-gate 加载 hooks/lib/project-root.sh 来解析 PROJECT_ROOT。
REAL_PROJECT_ROOT_LIB="$(dirname "$GATE_SCRIPT")/../hooks/lib/project-root.sh"
cp "$REAL_PROJECT_ROOT_LIB" "$T6_DIR/plugin/hooks/lib/project-root.sh"
chmod +x "$T6_DIR/plugin/scripts/rlcr-stop-gate.sh"

T6_INPUT_LOG="$T6_DIR/hook-input.json"
T6_TRANSCRIPT="$T6_DIR/fake-transcript.jsonl"
: > "$T6_TRANSCRIPT"

set +e
(
    cd "$T6_DIR"
    # 固定 CLAUDE_PROJECT_DIR，使 rlcr-stop-gate 即使在测试夹具不是
    # Git 仓库时也能解析根目录。此测试验证空 session_id 的 JSON 对象
    # 折叠回归；项目根解析是正交的，不得用 ALLOW 短路闸门。
    CLAUDE_PROJECT_DIR="$T6_DIR" \
    MOCK_HOOK_INPUT_LOG="$T6_INPUT_LOG" \
    "$T6_DIR/plugin/scripts/rlcr-stop-gate.sh" \
        --transcript-path "$T6_TRANSCRIPT" \
        --json
) > "$T6_DIR/out.txt" 2>&1
EXIT6=$?
set -e

if [[ ! -f "$T6_INPUT_LOG" ]]; then
    fail "rlcr-stop-gate forwards transcript_path when session_id is empty" \
        "mock hook to capture hook input JSON" \
        "captured input log missing; gate output: $(cat "$T6_DIR/out.txt" 2>/dev/null || true)"
else
    T6_TRANSCRIPT_SEEN=$(jq -r '.transcript_path // "__MISSING__"' "$T6_INPUT_LOG" 2>/dev/null || echo "__PARSE_ERROR__")
    T6_SESSION_SEEN=$(jq -r '.session_id | if . == null then "__NULL__" else . end' "$T6_INPUT_LOG" 2>/dev/null || echo "__PARSE_ERROR__")
    if [[ "$T6_TRANSCRIPT_SEEN" == "$T6_TRANSCRIPT" ]] && [[ "$T6_SESSION_SEEN" == "__NULL__" ]]; then
        pass "rlcr-stop-gate forwards transcript_path when session_id is empty (jq object-collapse fix)"
    else
        fail "rlcr-stop-gate forwards transcript_path when session_id is empty (jq object-collapse fix)" \
            "transcript_path=$T6_TRANSCRIPT, session_id=__NULL__" \
            "transcript_path=$T6_TRANSCRIPT_SEEN, session_id=$T6_SESSION_SEEN; raw: $(cat "$T6_INPUT_LOG" 2>/dev/null || true)"
    fi
fi

# 退出码 10，因为模拟钩子总是返回 decision:"block"；确保
# 包装器到达了决策分支，而不是退出 20（包装器错误）
# 或 0（因丢失 transcript_path 而产生的虚假 ALLOW）。
if [[ "$EXIT6" -eq 10 ]]; then
    pass "rlcr-stop-gate reaches decision branch with empty session_id + real transcript_path"
else
    T6_BODY=$(cat "$T6_DIR/out.txt" 2>/dev/null || true)
    fail "rlcr-stop-gate reaches decision branch with empty session_id + real transcript_path" \
        "exit 10 (mock hook returns block)" "exit $EXIT6; output: $T6_BODY"
fi

# 关于忽略继承的 CLAUDE_PROJECT_DIR 的断言在 rebase 到
# upstream/dev 期间被移除：上游的 `resolve_project_root` 故意
# 将 CLAUDE_PROJECT_DIR 作为首选信号（CLAUDE_PROJECT_DIR -> git
# toplevel，无 pwd 回退）。这是上游有意的设计选择，不是回归，
# 因此那两个旧断言不再适用。下面的 --project-root 显式覆盖
# 检查仍然有效，是 CLI 标志的正确契约。

# --project-root 必须仍然覆盖默认的 cwd / 继承的环境，
# 以便调用者可以显式定位不同的仓库。
T5_DIR="$TEST_DIR/t5-explicit-override"
mkdir -p "$T5_DIR/empty-cwd"
setup_active_loop_fixture "$T5_DIR/target-project"

set +e
(
    cd "$T5_DIR/empty-cwd"
    CLAUDE_PROJECT_DIR="$T5_DIR/empty-cwd" "$GATE_SCRIPT" --project-root "$T5_DIR/target-project"
) > "$T5_DIR/out.txt" 2>&1
EXIT5=$?
set -e

if [[ "$EXIT5" -eq 10 ]]; then
    pass "[P1 Round 18] --project-root override still wins over cwd + inherited env"
else
    OUTPUT5=$(cat "$T5_DIR/out.txt" 2>/dev/null || true)
    fail "[P1 Round 18] --project-root override no longer works" \
        "exit 10 (target has active loop)" "exit $EXIT5; output: $OUTPUT5"
fi

print_test_summary "RLCR Stop Gate Wrapper Test Summary"
exit $?
