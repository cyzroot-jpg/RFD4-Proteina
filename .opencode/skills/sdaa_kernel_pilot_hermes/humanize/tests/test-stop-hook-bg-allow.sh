#!/usr/bin/env bash
#
# loop-codex-stop-hook.sh 中后台任务短路的测试。
#
# 当当前 Claude Code 会话已派发尚未完成的后台工作（通过 Agent
# run_in_background=true 或 Bash run_in_background=true）时，
# RLCR 停止钩子必须以面向用户的 systemMessage 退出 0，而不是
# 运行任何闸门或 Codex 审查。磁盘上的循环状态必须保持不变，
# 以便下一个自然停止（后台任务完成后）重新进入正常审查流程。
#
# 此处验证的验收标准（参见
# .humanize/rlcr/2026-04-16_13-19-26/goal-tracker.md 获取权威列表）：
#   AC-1   无后台派发                              -> 正常 Codex 流程
#   AC-2   待处理子代理                            -> exit 0 + systemMessage
#   AC-3   待处理 shell                            -> exit 0 + systemMessage
#   AC-4   子代理启动 + 完成                       -> 正常 Codex 流程
#   AC-5   2 个子代理 + 1 个 shell                 -> systemMessage 提及 "3 background"
#   AC-6   缺失 transcript 路径                    -> 正常 Codex 流程（失败关闭）
#   AC-7   无活跃循环                              -> exit 0，无 systemMessage，无 Codex
#   AC-8   完成阶段有待处理后台                    -> exit 0 + systemMessage
#   AC-9   通过 rlcr-stop-gate.sh                  -> exit 0（包装器 ALLOW）
#   AC-10  波浪号 transcript 路径                  -> 触发短路
#   AC-11  跨会话 bg-pending.marker                -> "parked" systemMessage，构件完整
#   AC-12  find_active_loop 优先精确会话           -> 返回较旧的精确匹配目录
#   AC-13  同会话恢复                              -> 移除过期标记
#   AC-14  跨会话停止带标记                        -> 保留标记和存储的 session_id
#   AC-15  task_notification 完成格式              -> 标记启动已完成
#   AC-16  混合旧版 + SDK 完成                     -> 解析为空待处理集
#   AC-17  不可读 transcript 带标记                -> 保留标记和 session_id
#   AC-18  find_active_loop 默认忽略标记           -> 验证器保持隔离
#   AC-19  钩子输入省略 session_id                 -> 触发跨会话守卫
#   AC-20  格式错误的 transcript 带标记            -> 保留标记（失败关闭）
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

STOP_HOOK="$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh"
GATE_SCRIPT="$PROJECT_ROOT/scripts/rlcr-stop-gate.sh"

setup_test_dir

export XDG_CACHE_HOME="$TEST_DIR/.cache"
mkdir -p "$XDG_CACHE_HOME"

# 假 HOME 根目录在 $TEST_DIR 内，使波浪号路径回归测试（AC-10、
# AC-10b、AC-10c）不会写入真实用户主目录。需要波浪号展开的钩子、
# 辅助函数和包装器调用使用 HOME 设置为此目录；其他调用保持真实 HOME。
# 清理由 setup_test_dir EXIT 陷阱覆盖，因为 FAKE_HOME 在 $TEST_DIR 下。
FAKE_HOME="$TEST_DIR/fake-home"
mkdir -p "$FAKE_HOME"

# ----------------------------------------------------------------------
# 存活探针测试使用的模拟 lsof 二进制文件（AC-23、AC-24）。
# lsof-alive 退出 0（模拟 >= 1 个持有者：任务正在运行）。
# lsof-dead  退出 1（模拟 0 个持有者：任务已孤立/死亡）。
# ----------------------------------------------------------------------
setup_mock_lsof() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/lsof-alive" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_DIR/bin/lsof-alive"

    cat > "$TEST_DIR/bin/lsof-dead" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_DIR/bin/lsof-dead"
}

# ----------------------------------------------------------------------
# 模拟 codex CLI：记录调用标记并打印预设反馈。
# ----------------------------------------------------------------------
setup_mock_codex() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << 'EOF'
#!/usr/bin/env bash
if [[ -n "${MOCK_CODEX_MARKER:-}" ]]; then
    : > "$MOCK_CODEX_MARKER"
fi
printf '%s\n' "${MOCK_CODEX_OUTPUT:-Mock review feedback}"
exit 0
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# ----------------------------------------------------------------------
# 构建一个最小的"活跃循环"项目，满足停止钩子在调用 Codex 之前
# 强制执行的所有闸门（以便想要到达 Codex 审查流程的测试在不期望
# 后台待处理时可以干净通过）。
# ----------------------------------------------------------------------
create_full_fixture() {
    local repo_dir="$1"
    local finalize_phase="${2:-false}"

    init_test_git_repo "$repo_dir"

    printf 'plans/\n' > "$repo_dir/.gitignore"
    git -C "$repo_dir" add .gitignore
    git -C "$repo_dir" commit -q -m "Add test gitignore"

    mkdir -p "$repo_dir/plans"
    cat > "$repo_dir/plans/test-plan.md" << 'EOF'
# Test Plan

Exercise the background-task short-circuit.
EOF

    local branch base_commit loop_dir
    branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)
    base_commit=$(git -C "$repo_dir" rev-parse HEAD)
    loop_dir="$repo_dir/.humanize/rlcr/2026-03-01_00-00-00"
    mkdir -p "$loop_dir"

    cp "$repo_dir/plans/test-plan.md" "$loop_dir/plan.md"

    local state_name="state.md"
    if [[ "$finalize_phase" == "true" ]]; then
        state_name="finalize-state.md"
    fi

    cat > "$loop_dir/$state_name" << EOF
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $branch
base_branch: $branch
base_commit: $base_commit
review_started: false
ask_codex_question: false
agent_teams: false
---
EOF

    local summary_name="round-0-summary.md"
    if [[ "$finalize_phase" == "true" ]]; then
        summary_name="finalize-summary.md"
    fi
    cat > "$loop_dir/$summary_name" << 'EOF'
# Summary

Exercised the background-task short-circuit.
EOF

    cat > "$loop_dir/goal-tracker.md" << 'EOF'
# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Exercise background-task short-circuit.
### Acceptance Criteria
- AC-1: Hook reaches Codex review when no bg tasks are pending.
## MUTABLE SECTION
### Plan Version: 1 (Updated: Round 0)
#### Active Tasks
| Task | Target AC | Status | Notes |
|------|-----------|--------|-------|
| Exercise stop hook | AC-1 | completed | - |
EOF

    # 回显循环目录，以便调用者可以访问状态构件。
    echo "$loop_dir"
}

# 一个完全没有 RLCR 状态文件的项目。
create_empty_project() {
    local repo_dir="$1"
    init_test_git_repo "$repo_dir"
}

# ----------------------------------------------------------------------
# Transcript 夹具构建器。
# 每个向 stdout 打印 JSONL transcript。
# ----------------------------------------------------------------------
emit_tool_use_assistant() {
    local tool_use_id="$1" tool_name="$2" extra_input_json="$3"
    local input_json="{\"run_in_background\":true${extra_input_json}}"
    jq -c -n \
        --arg id "$tool_use_id" \
        --arg name "$tool_name" \
        --argjson input "$input_json" \
        '{
          type:"assistant",
          message:{
            role:"assistant",
            content:[
              {type:"tool_use", id:$id, name:$name, input:$input}
            ]
          }
        }'
}

emit_async_agent_launch_result() {
    local tool_use_id="$1" agent_id="$2"
    jq -c -n \
        --arg id "$tool_use_id" \
        --arg aid "$agent_id" \
        '{
          type:"user",
          message:{
            role:"user",
            content:[{tool_use_id:$id, type:"tool_result",
                      content:[{type:"text", text:"Async agent launched"}]}]
          },
          toolUseResult:{isAsync:true, status:"async_launched", agentId:$aid}
        }'
}

emit_bg_shell_launch_result() {
    local tool_use_id="$1" bg_task_id="$2"
    jq -c -n \
        --arg id "$tool_use_id" \
        --arg bid "$bg_task_id" \
        '{
          type:"user",
          message:{
            role:"user",
            content:[{tool_use_id:$id, type:"tool_result",
                      content:[{type:"text", text:"Shell started in background"}]}]
          },
          toolUseResult:{backgroundTaskId:$bid}
        }'
}

emit_task_completion_event() {
    local task_id="$1" tool_use_id="$2" status="${3:-completed}"
    local notif
    notif=$(printf '<task-notification>\n<task-id>%s</task-id>\n<tool-use-id>%s</tool-use-id>\n<status>%s</status>\n</task-notification>' \
        "$task_id" "$tool_use_id" "$status")
    jq -c -n --arg content "$notif" \
        '{type:"queue-operation", operation:"enqueue", content:$content}'
}

emit_sdk_task_notification() {
    local task_id="$1" tool_use_id="$2" status="${3:-completed}"
    jq -c -n --arg tid "$task_id" --arg tu "$tool_use_id" --arg st "$status" \
        '{type:"system", subtype:"task_notification", task_id:$tid, tool_use_id:$tu, status:$st}'
}

write_transcript() {
    local path="$1"
    shift
    : > "$path"
    for line in "$@"; do
        printf '%s\n' "$line" >> "$path"
    done
}

# ----------------------------------------------------------------------
# 使用精心构造的钩子输入 JSON 调用停止钩子。可选的第三个参数
# 仅为钩子调用覆盖 HOME，使波浪号路径回归可以指向 $TEST_DIR
# 下的假 HOME，而不会泄漏到真实用户主目录。
# 设置 RUN_EXIT_CODE、RUN_OUTPUT、RUN_MARKER。
# ----------------------------------------------------------------------
run_stop_hook_with_input() {
    local repo_dir="$1" hook_input_json="$2" home_override="${3:-}" lsof_bin_override="${4:-}"

    RUN_MARKER="$repo_dir/codex-called.marker"
    rm -f "$RUN_MARKER"

    set +e
    RUN_OUTPUT=$(
        cd "$repo_dir"
        [[ -n "$home_override" ]] && export HOME="$home_override"
        [[ -n "$lsof_bin_override" ]] && export LSOF_BIN="$lsof_bin_override"
        CLAUDE_PROJECT_DIR="$repo_dir" \
        MOCK_CODEX_MARKER="$RUN_MARKER" \
        MOCK_CODEX_OUTPUT="Mock review feedback" \
        "$STOP_HOOK" <<<"$hook_input_json" 2>&1
    )
    RUN_EXIT_CODE=$?
    set -e
}

assert_systemmessage_only() {
    local test_name="$1" repo_dir="$2" state_file="$3" expected_count_regex="$4"

    local before_hash after_hash
    before_hash=$(sha256sum "$state_file" 2>/dev/null | awk '{print $1}')

    if [[ "$RUN_EXIT_CODE" -ne 0 ]]; then
        fail "$test_name" "exit 0 with systemMessage" \
            "exit $RUN_EXIT_CODE; output: $RUN_OUTPUT"
        return
    fi
    if [[ -f "$RUN_MARKER" ]]; then
        fail "$test_name" "Codex NOT invoked" \
            "marker present (Codex was called); output: $RUN_OUTPUT"
        return
    fi
    local system_message
    system_message=$(printf '%s' "$RUN_OUTPUT" | jq -r '.systemMessage // empty' 2>/dev/null || echo "")
    if [[ -z "$system_message" ]]; then
        fail "$test_name" "JSON output with systemMessage" \
            "no systemMessage in output: $RUN_OUTPUT"
        return
    fi
    if [[ -n "$expected_count_regex" ]]; then
        if ! printf '%s' "$system_message" | grep -Eq "$expected_count_regex"; then
            fail "$test_name" \
                "systemMessage matches /$expected_count_regex/" \
                "got: $system_message"
            return
        fi
    fi
    after_hash=$(sha256sum "$state_file" 2>/dev/null | awk '{print $1}')
    if [[ "$before_hash" != "$after_hash" ]]; then
        fail "$test_name" "state file unchanged" \
            "hash changed ($before_hash -> $after_hash)"
        return
    fi
    pass "$test_name"
}

assert_reached_codex() {
    local test_name="$1"
    if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -f "$RUN_MARKER" ]]; then
        pass "$test_name"
    else
        fail "$test_name" "exit 0 and Codex invoked (marker present)" \
            "exit $RUN_EXIT_CODE, marker=$(test -f "$RUN_MARKER" && echo present || echo missing); output: $RUN_OUTPUT"
    fi
}

setup_mock_codex
setup_mock_lsof

# Transcript 位于任何测试仓库之外，以避免触发停止钩子中的 git 清洁闸门。
TRANSCRIPTS_DIR="$TEST_DIR/transcripts"
mkdir -p "$TRANSCRIPTS_DIR"

echo "=========================================="
echo "Stop Hook Background-Task Allow Tests"
echo "=========================================="
echo ""

# ---------------- AC-1 ----------------
echo "Test AC-1: No bg dispatches -> reaches Codex"
AC1_REPO="$TEST_DIR/ac1"
create_full_fixture "$AC1_REPO" > /dev/null
AC1_TRANSCRIPT="$TRANSCRIPTS_DIR/ac1.jsonl"
write_transcript "$AC1_TRANSCRIPT" '{"type":"user","message":{"role":"user","content":"hello"}}'

AC1_INPUT=$(jq -c -n --arg tp "$AC1_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC1_REPO" "$AC1_INPUT"
assert_reached_codex "AC-1: transcript without bg dispatches proceeds to Codex review"

# ---------------- AC-2 ----------------
echo "Test AC-2: One pending background subagent -> exit 0 + systemMessage"
AC2_REPO="$TEST_DIR/ac2"
AC2_LOOP=$(create_full_fixture "$AC2_REPO")
AC2_STATE="$AC2_LOOP/state.md"
AC2_TRANSCRIPT="$TRANSCRIPTS_DIR/ac2.jsonl"
AC2_LINE_LAUNCH=$(emit_tool_use_assistant "toolu_A" "Agent" ',"description":"x","prompt":"x"')
AC2_LINE_RESULT=$(emit_async_agent_launch_result "toolu_A" "agent_pending_A")
write_transcript "$AC2_TRANSCRIPT" "$AC2_LINE_LAUNCH" "$AC2_LINE_RESULT"

AC2_INPUT=$(jq -c -n --arg tp "$AC2_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC2_REPO" "$AC2_INPUT"
assert_systemmessage_only \
    "AC-2: pending subagent triggers exit 0 + systemMessage, state untouched" \
    "$AC2_REPO" "$AC2_STATE" "1 background task"

# ---------------- AC-3 ----------------
echo "Test AC-3: One pending background shell -> exit 0 + systemMessage"
AC3_REPO="$TEST_DIR/ac3"
AC3_LOOP=$(create_full_fixture "$AC3_REPO")
AC3_STATE="$AC3_LOOP/state.md"
AC3_TRANSCRIPT="$TRANSCRIPTS_DIR/ac3.jsonl"
AC3_LINE_LAUNCH=$(emit_tool_use_assistant "toolu_B" "Bash" ',"command":"sleep 30"')
AC3_LINE_RESULT=$(emit_bg_shell_launch_result "toolu_B" "shell_pending_B")
write_transcript "$AC3_TRANSCRIPT" "$AC3_LINE_LAUNCH" "$AC3_LINE_RESULT"

AC3_INPUT=$(jq -c -n --arg tp "$AC3_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC3_REPO" "$AC3_INPUT"
assert_systemmessage_only \
    "AC-3: pending background shell triggers exit 0 + systemMessage" \
    "$AC3_REPO" "$AC3_STATE" "1 background task"

# ---------------- AC-4 ----------------
echo "Test AC-4: Launched subagent with completion notification -> reaches Codex"
AC4_REPO="$TEST_DIR/ac4"
create_full_fixture "$AC4_REPO" > /dev/null
AC4_TRANSCRIPT="$TRANSCRIPTS_DIR/ac4.jsonl"
AC4_LAUNCH=$(emit_tool_use_assistant "toolu_C" "Agent" ',"description":"x","prompt":"x"')
AC4_RESULT=$(emit_async_agent_launch_result "toolu_C" "agent_done_C")
AC4_COMPLETE=$(emit_task_completion_event "agent_done_C" "toolu_C" "completed")
write_transcript "$AC4_TRANSCRIPT" "$AC4_LAUNCH" "$AC4_RESULT" "$AC4_COMPLETE"

AC4_INPUT=$(jq -c -n --arg tp "$AC4_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC4_REPO" "$AC4_INPUT"
assert_reached_codex "AC-4: subagent with matching completion notification proceeds to Codex review"

# ---------------- AC-5 ----------------
echo "Test AC-5: 2 pending subagents + 1 pending shell -> systemMessage mentions 3"
AC5_REPO="$TEST_DIR/ac5"
AC5_LOOP=$(create_full_fixture "$AC5_REPO")
AC5_STATE="$AC5_LOOP/state.md"
AC5_TRANSCRIPT="$TRANSCRIPTS_DIR/ac5.jsonl"
AC5_L1_LAUNCH=$(emit_tool_use_assistant "toolu_D1" "Agent" ',"description":"x","prompt":"x"')
AC5_L1_RESULT=$(emit_async_agent_launch_result "toolu_D1" "agent_pending_D1")
AC5_L2_LAUNCH=$(emit_tool_use_assistant "toolu_D2" "Agent" ',"description":"y","prompt":"y"')
AC5_L2_RESULT=$(emit_async_agent_launch_result "toolu_D2" "agent_pending_D2")
AC5_L3_LAUNCH=$(emit_tool_use_assistant "toolu_D3" "Bash" ',"command":"sleep 30"')
AC5_L3_RESULT=$(emit_bg_shell_launch_result "toolu_D3" "shell_pending_D3")
write_transcript "$AC5_TRANSCRIPT" \
    "$AC5_L1_LAUNCH" "$AC5_L1_RESULT" \
    "$AC5_L2_LAUNCH" "$AC5_L2_RESULT" \
    "$AC5_L3_LAUNCH" "$AC5_L3_RESULT"

AC5_INPUT=$(jq -c -n --arg tp "$AC5_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC5_REPO" "$AC5_INPUT"
assert_systemmessage_only \
    "AC-5: 2 pending subagents + 1 pending shell -> systemMessage mentions '3 background task(s)'" \
    "$AC5_REPO" "$AC5_STATE" "3 background task\\(s\\)"

# ---------------- AC-6 ----------------
echo "Test AC-6: missing transcript path -> reaches Codex (fail-closed)"
AC6_REPO="$TEST_DIR/ac6"
create_full_fixture "$AC6_REPO" > /dev/null
AC6_INPUT=$(jq -c -n --arg tp "/nonexistent/file-$$.jsonl" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC6_REPO" "$AC6_INPUT"
assert_reached_codex "AC-6: missing transcript_path proceeds to Codex review (fail-closed)"

# 另外：空 transcript_path 字段
AC6B_REPO="$TEST_DIR/ac6b"
create_full_fixture "$AC6B_REPO" > /dev/null
AC6B_INPUT='{"transcript_path":""}'
run_stop_hook_with_input "$AC6B_REPO" "$AC6B_INPUT"
assert_reached_codex "AC-6b: empty transcript_path string proceeds to Codex review"

# 以及：完全没有 transcript_path 键
AC6C_REPO="$TEST_DIR/ac6c"
create_full_fixture "$AC6C_REPO" > /dev/null
AC6C_INPUT='{}'
run_stop_hook_with_input "$AC6C_REPO" "$AC6C_INPUT"
assert_reached_codex "AC-6c: hook input with no transcript_path proceeds to Codex review"

# ---------------- AC-7 ----------------
echo "Test AC-7: No active loop -> exit 0, no systemMessage, no Codex"
AC7_REPO="$TEST_DIR/ac7"
create_empty_project "$AC7_REPO"
AC7_TRANSCRIPT="$TRANSCRIPTS_DIR/ac7.jsonl"
AC7_LAUNCH=$(emit_tool_use_assistant "toolu_E" "Agent" ',"description":"x","prompt":"x"')
AC7_RESULT=$(emit_async_agent_launch_result "toolu_E" "agent_pending_E")
write_transcript "$AC7_TRANSCRIPT" "$AC7_LAUNCH" "$AC7_RESULT"
AC7_INPUT=$(jq -c -n --arg tp "$AC7_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC7_REPO" "$AC7_INPUT"

AC7_SYS_MSG=$(printf '%s' "$RUN_OUTPUT" | jq -r '.systemMessage // empty' 2>/dev/null || echo "")
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ ! -f "$RUN_MARKER" ]] && [[ -z "$AC7_SYS_MSG" ]]; then
    pass "AC-7: no active loop takes original exit-0 path without systemMessage"
else
    fail "AC-7: no active loop takes original exit-0 path without systemMessage" \
        "exit 0, no Codex marker, no systemMessage" \
        "exit $RUN_EXIT_CODE, marker=$(test -f "$RUN_MARKER" && echo present || echo missing), systemMessage='$AC7_SYS_MSG'; output: $RUN_OUTPUT"
fi

# ---------------- AC-8 ----------------
echo "Test AC-8: Finalize phase + pending bg -> exit 0 + systemMessage"
AC8_REPO="$TEST_DIR/ac8"
AC8_LOOP=$(create_full_fixture "$AC8_REPO" true)
AC8_STATE="$AC8_LOOP/finalize-state.md"
AC8_TRANSCRIPT="$TRANSCRIPTS_DIR/ac8.jsonl"
AC8_LAUNCH=$(emit_tool_use_assistant "toolu_F" "Agent" ',"description":"x","prompt":"x"')
AC8_RESULT=$(emit_async_agent_launch_result "toolu_F" "agent_pending_F")
write_transcript "$AC8_TRANSCRIPT" "$AC8_LAUNCH" "$AC8_RESULT"
AC8_INPUT=$(jq -c -n --arg tp "$AC8_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC8_REPO" "$AC8_INPUT"
assert_systemmessage_only \
    "AC-8: finalize phase with pending bg task -> exit 0 + systemMessage" \
    "$AC8_REPO" "$AC8_STATE" "1 background task"

# ---------------- AC-9 ----------------
echo "Test AC-9: rlcr-stop-gate.sh forwards transcript_path to hook"
AC9_REPO="$TEST_DIR/ac9"
create_full_fixture "$AC9_REPO" > /dev/null
AC9_TRANSCRIPT="$TRANSCRIPTS_DIR/ac9.jsonl"
AC9_LAUNCH=$(emit_tool_use_assistant "toolu_G" "Agent" ',"description":"x","prompt":"x"')
AC9_RESULT=$(emit_async_agent_launch_result "toolu_G" "agent_pending_G")
write_transcript "$AC9_TRANSCRIPT" "$AC9_LAUNCH" "$AC9_RESULT"

AC9_OUT="$AC9_REPO/gate-out.txt"
# 显式传递 --project-root，使外部运行器继承的 CLAUDE_PROJECT_DIR
# 不能将闸门重定向到外部仓库。
set +e
(
    cd "$AC9_REPO"
    "$GATE_SCRIPT" --project-root "$AC9_REPO" --transcript-path "$AC9_TRANSCRIPT"
) > "$AC9_OUT" 2>&1
AC9_EXIT=$?
set -e

if [[ "$AC9_EXIT" -eq 0 ]] && grep -q "^ALLOW:" "$AC9_OUT"; then
    pass "AC-9: rlcr-stop-gate.sh exits 0 with ALLOW when bg tasks are pending"
else
    AC9_BODY=$(cat "$AC9_OUT" 2>/dev/null || true)
    fail "AC-9: rlcr-stop-gate.sh exits 0 with ALLOW when bg tasks are pending" \
        "exit 0 and output containing ALLOW:" \
        "exit $AC9_EXIT; output: $AC9_BODY"
fi

# ---------------- AC-10 / AC-10b / AC-10c ----------------
# 回归：真实会话将 transcript_path 传递为 "~/.claude/projects/..."。
# 如果没有波浪号展开，文件检查 `[[ -f "~/..." ]]` 始终为 false，
# 因此短路会静默错过待处理的后台任务。
#
# 夹具位于 $TEST_DIR 内的假 HOME 下，使测试在沙箱或只读 HOME
# 环境中保持可移植。只有需要波浪号展开的特定钩子/辅助/包装器
# 调用使用 HOME=$FAKE_HOME；其余测试保持真实 HOME。
echo "Test AC-10: '~/...' transcript path still triggers short-circuit"
AC10_REPO="$TEST_DIR/ac10"
AC10_LOOP=$(create_full_fixture "$AC10_REPO")
AC10_STATE="$AC10_LOOP/state.md"

mkdir -p "$FAKE_HOME/session-data"
AC10_TRANSCRIPT="$FAKE_HOME/session-data/ac10.jsonl"
AC10_LAUNCH=$(emit_tool_use_assistant "toolu_H" "Agent" ',"description":"x","prompt":"x"')
AC10_RESULT=$(emit_async_agent_launch_result "toolu_H" "agent_pending_H")
write_transcript "$AC10_TRANSCRIPT" "$AC10_LAUNCH" "$AC10_RESULT"

# 构建波浪号形式的字符串。不要让 shell 展开 "~"。
AC10_TILDE_PATH="~/session-data/ac10.jsonl"
AC10_INPUT=$(jq -c -n --arg tp "$AC10_TILDE_PATH" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC10_REPO" "$AC10_INPUT" "$FAKE_HOME"
assert_systemmessage_only \
    "AC-10: '~/'-prefixed transcript_path is expanded and short-circuits on pending bg" \
    "$AC10_REPO" "$AC10_STATE" "1 background task"

# 同时证明辅助函数在假 HOME 下直接对 "~/..." 参数工作。
# 避免在钩子自身的规范化背后掩盖辅助函数回归。
AC10_HELPER_OUT=$(
    cd "$AC10_REPO"
    HOME="$FAKE_HOME"
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    list_pending_background_task_ids "$AC10_TILDE_PATH" 2>/dev/null | sort -u
)
if printf '%s\n' "$AC10_HELPER_OUT" | grep -qx 'agent_pending_H'; then
    pass "AC-10b: list_pending_background_task_ids expands '~/...' directly"
else
    fail "AC-10b: list_pending_background_task_ids expands '~/...' directly" \
        "output containing 'agent_pending_H'" "$AC10_HELPER_OUT"
fi

# 验证带有波浪号形式 --transcript-path 的闸门包装器路径也
# 到达短路。AC-9 使用绝对 transcript 路径；这用 "~/..." 形式
# 覆盖相同的代码路径。
#
# 新夹具使仓库没有先前的 bg-pending.marker（AC-10 留下了一个）。
# 钩子中的模糊调用者守卫仅在标记已存在时静默包装器；
# 干净仓库会落入正常短路，使 systemMessage 出现在包装器输出中。
echo "Test AC-10c: rlcr-stop-gate.sh with '~/...' --transcript-path -> ALLOW"
AC10C_REPO="$TEST_DIR/ac10c"
create_full_fixture "$AC10C_REPO" > /dev/null
mkdir -p "$FAKE_HOME/session-data-c"
AC10C_TRANSCRIPT="$FAKE_HOME/session-data-c/ac10c.jsonl"
AC10C_LAUNCH=$(emit_tool_use_assistant "toolu_H2" "Agent" ',"description":"x","prompt":"x"')
AC10C_RESULT=$(emit_async_agent_launch_result "toolu_H2" "agent_pending_H2")
write_transcript "$AC10C_TRANSCRIPT" "$AC10C_LAUNCH" "$AC10C_RESULT"
AC10C_TILDE_PATH="~/session-data-c/ac10c.jsonl"

AC10C_OUT="$TEST_DIR/ac10c-out.txt"
set +e
(
    cd "$AC10C_REPO"
    HOME="$FAKE_HOME" "$GATE_SCRIPT" \
        --project-root "$AC10C_REPO" \
        --transcript-path "$AC10C_TILDE_PATH"
) > "$AC10C_OUT" 2>&1
AC10C_EXIT=$?
set -e

if [[ "$AC10C_EXIT" -eq 0 ]] \
   && grep -q "^ALLOW:" "$AC10C_OUT" \
   && grep -q "background task" "$AC10C_OUT"; then
    pass "AC-10c: rlcr-stop-gate.sh expands '~/...' and emits ALLOW with systemMessage"
else
    AC10C_BODY=$(cat "$AC10C_OUT" 2>/dev/null || true)
    fail "AC-10c: rlcr-stop-gate.sh expands '~/...' and emits ALLOW with systemMessage" \
        "exit 0 + output containing ALLOW: and 'background task'" \
        "exit $AC10C_EXIT; output: $AC10C_BODY"
fi

# ---------------- AC-11 / AC-11b ----------------
# 跨会话驻留循环守卫：当仓库中的循环携带 bg-pending.marker
# 且其存储的 session_id 与调用者不匹配时，停止钩子必须以
# 专用的"parked by another session" systemMessage 退出 0，
# 并保持所有磁盘构件完整。当前会话无权推进或清理外来驻留循环，
# 因为其 transcript 无法观察其他会话的后台任务。
echo "Test AC-11: cross-session bg-pending.marker emits 'parked' systemMessage"
AC11_REPO="$TEST_DIR/ac11"
AC11_LOOP=$(create_full_fixture "$AC11_REPO")
AC11_STATE="$AC11_LOOP/state.md"
AC11_MARKER="$AC11_LOOP/bg-pending.marker"

# 用显式存储的 session_id 覆盖 state.md，使 find_active_loop
# 在我们稍后传递不同 session_id 时看到真实的不匹配。
AC11_BRANCH=$(git -C "$AC11_REPO" rev-parse --abbrev-ref HEAD)
AC11_BASE_COMMIT=$(git -C "$AC11_REPO" rev-parse HEAD)
cat > "$AC11_STATE" <<EOF_AC11
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC11_BRANCH
base_branch: $AC11_BRANCH
base_commit: $AC11_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_alpha
---
EOF_AC11
AC11_STATE_HASH_BEFORE=$(sha256sum "$AC11_STATE" | awk '{print $1}')

# 模拟先前会话采取短路后留下的状态。
: > "$AC11_MARKER"

AC11_TRANSCRIPT="$TRANSCRIPTS_DIR/ac11.jsonl"
AC11_LAUNCH=$(emit_tool_use_assistant "toolu_I" "Agent" ',"description":"x","prompt":"x"')
AC11_RESULT=$(emit_async_agent_launch_result "toolu_I" "agent_pending_I")
write_transcript "$AC11_TRANSCRIPT" "$AC11_LAUNCH" "$AC11_RESULT"

AC11_INPUT=$(jq -c -n --arg tp "$AC11_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_beta"}')
run_stop_hook_with_input "$AC11_REPO" "$AC11_INPUT"
AC11_SYS_MSG=$(printf '%s' "$RUN_OUTPUT" | jq -r '.systemMessage // empty' 2>/dev/null || echo "")
AC11_STATE_HASH_AFTER=$(sha256sum "$AC11_STATE" | awk '{print $1}')
if [[ "$RUN_EXIT_CODE" -eq 0 ]] \
   && [[ ! -f "$RUN_MARKER" ]] \
   && [[ -f "$AC11_MARKER" ]] \
   && [[ "$AC11_STATE_HASH_BEFORE" == "$AC11_STATE_HASH_AFTER" ]] \
   && printf '%s' "$AC11_SYS_MSG" | grep -qi "parked"; then
    pass "AC-11: cross-session stop exits with 'parked' systemMessage; marker and session_id untouched"
else
    fail "AC-11: cross-session stop exits with 'parked' systemMessage; marker and session_id untouched" \
        "exit 0 + systemMessage matches /parked/ + marker stays + state.md byte-identical + no Codex" \
        "exit $RUN_EXIT_CODE, codex_marker=$(test -f "$RUN_MARKER" && echo present || echo missing), bg_marker=$(test -f "$AC11_MARKER" && echo present || echo missing), state_unchanged=$([[ "$AC11_STATE_HASH_BEFORE" == "$AC11_STATE_HASH_AFTER" ]] && echo yes || echo no), systemMessage='$AC11_SYS_MSG'; output: $RUN_OUTPUT"
fi

# 负面对应：相同的会话不匹配但没有标记时仍必须拒绝循环
# （在循环未被显式驻留时保持现有的会话绑定隔离）。
echo "Test AC-11b: cross-session without marker is still rejected"
AC11B_REPO="$TEST_DIR/ac11b"
AC11B_LOOP=$(create_full_fixture "$AC11B_REPO")
AC11B_STATE="$AC11B_LOOP/state.md"
AC11B_BRANCH=$(git -C "$AC11B_REPO" rev-parse --abbrev-ref HEAD)
AC11B_BASE_COMMIT=$(git -C "$AC11B_REPO" rev-parse HEAD)
cat > "$AC11B_STATE" <<EOF_AC11B
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC11B_BRANCH
base_branch: $AC11B_BRANCH
base_commit: $AC11B_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_alpha
---
EOF_AC11B
# 故意在 AC11B_LOOP 中不放置标记。

AC11B_TRANSCRIPT="$TRANSCRIPTS_DIR/ac11b.jsonl"
AC11B_LAUNCH=$(emit_tool_use_assistant "toolu_J" "Agent" ',"description":"x","prompt":"x"')
AC11B_RESULT=$(emit_async_agent_launch_result "toolu_J" "agent_pending_J")
write_transcript "$AC11B_TRANSCRIPT" "$AC11B_LAUNCH" "$AC11B_RESULT"

AC11B_INPUT=$(jq -c -n --arg tp "$AC11B_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_beta"}')
run_stop_hook_with_input "$AC11B_REPO" "$AC11B_INPUT"
AC11B_SYS_MSG=$(printf '%s' "$RUN_OUTPUT" | jq -r '.systemMessage // empty' 2>/dev/null || echo "")
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ ! -f "$RUN_MARKER" ]] && [[ -z "$AC11B_SYS_MSG" ]]; then
    pass "AC-11b: cross-session without marker keeps existing isolation (no adoption)"
else
    fail "AC-11b: cross-session without marker keeps existing isolation (no adoption)" \
        "exit 0, no Codex marker, no systemMessage" \
        "exit $RUN_EXIT_CODE, marker=$(test -f "$RUN_MARKER" && echo present || echo missing), systemMessage='$AC11B_SYS_MSG'; output: $RUN_OUTPUT"
fi

# AC-11c：短路应实际写入 bg-pending.marker，使 AC-11 中的
# 采纳路径可从真实使用中到达（不仅从合成测试设置中）。
echo "Test AC-11c: short-circuit writes bg-pending.marker"
AC11C_REPO="$TEST_DIR/ac11c"
AC11C_LOOP=$(create_full_fixture "$AC11C_REPO")
AC11C_MARKER="$AC11C_LOOP/bg-pending.marker"
[[ -e "$AC11C_MARKER" ]] && rm -f "$AC11C_MARKER"

AC11C_TRANSCRIPT="$TRANSCRIPTS_DIR/ac11c.jsonl"
AC11C_LAUNCH=$(emit_tool_use_assistant "toolu_K" "Agent" ',"description":"x","prompt":"x"')
AC11C_RESULT=$(emit_async_agent_launch_result "toolu_K" "agent_pending_K")
write_transcript "$AC11C_TRANSCRIPT" "$AC11C_LAUNCH" "$AC11C_RESULT"

AC11C_INPUT=$(jq -c -n --arg tp "$AC11C_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC11C_REPO" "$AC11C_INPUT"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -f "$AC11C_MARKER" ]]; then
    pass "AC-11c: short-circuit path writes bg-pending.marker into loop dir"
else
    fail "AC-11c: short-circuit path writes bg-pending.marker into loop dir" \
        "exit 0 and bg-pending.marker present" \
        "exit $RUN_EXIT_CODE, marker=$(test -f "$AC11C_MARKER" && echo present || echo missing); output: $RUN_OUTPUT"
fi

# ---------------- AC-12 ----------------
# 多个并发 RLCR 循环下的会话隔离：当调用者自己的精确匹配目录
# 存在于列表中时，find_active_loop 必须返回它，即使较新的兄弟目录
# （属于另一个会话）也有 bg-pending.marker。标记回退仅用于
# 不存在精确匹配时的孤立恢复。
echo "Test AC-12: find_active_loop prefers exact session match over marker"
AC12_BASE="$TEST_DIR/ac12-loops"
mkdir -p "$AC12_BASE/2026-03-02_00-00-00"
mkdir -p "$AC12_BASE/2026-03-01_00-00-00"

cat > "$AC12_BASE/2026-03-02_00-00-00/state.md" <<'EOF_AC12_NEWER'
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
session_id: session_foreign
---
EOF_AC12_NEWER
: > "$AC12_BASE/2026-03-02_00-00-00/bg-pending.marker"

cat > "$AC12_BASE/2026-03-01_00-00-00/state.md" <<'EOF_AC12_OLDER'
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
session_id: session_home
---
EOF_AC12_OLDER

AC12_RESULT=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    find_active_loop "$AC12_BASE" "session_home"
)
if [[ "$AC12_RESULT" == "$AC12_BASE/2026-03-01_00-00-00" ]]; then
    pass "AC-12: find_active_loop returns older exact-match dir over newer marker dir"
else
    fail "AC-12: find_active_loop returns older exact-match dir over newer marker dir" \
        "$AC12_BASE/2026-03-01_00-00-00" "$AC12_RESULT"
fi

if [[ -f "$AC12_BASE/2026-03-02_00-00-00/bg-pending.marker" ]]; then
    pass "AC-12b: foreign session's marker untouched by find_active_loop scan"
else
    fail "AC-12b: foreign session's marker untouched by find_active_loop scan" \
        "newer dir marker still present" "marker was removed"
fi

# ---------------- AC-13 ----------------
# 后台完成后的同会话恢复：先前短路的过期标记必须在下次停止时
# 清理（没有后台待处理时）。State.md session_id 保持不变，因为
# 它已经匹配。
echo "Test AC-13: same-session resume removes stale bg-pending.marker"
AC13_REPO="$TEST_DIR/ac13"
AC13_LOOP=$(create_full_fixture "$AC13_REPO")
AC13_STATE="$AC13_LOOP/state.md"
AC13_BRANCH=$(git -C "$AC13_REPO" rev-parse --abbrev-ref HEAD)
AC13_BASE_COMMIT=$(git -C "$AC13_REPO" rev-parse HEAD)
cat > "$AC13_STATE" <<EOF_AC13
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC13_BRANCH
base_branch: $AC13_BRANCH
base_commit: $AC13_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_home
---
EOF_AC13
: > "$AC13_LOOP/bg-pending.marker"

AC13_TRANSCRIPT="$TRANSCRIPTS_DIR/ac13.jsonl"
write_transcript "$AC13_TRANSCRIPT" '{"type":"user","message":{"role":"user","content":"hello"}}'
AC13_INPUT=$(jq -c -n --arg tp "$AC13_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_home"}')
run_stop_hook_with_input "$AC13_REPO" "$AC13_INPUT"

if [[ ! -f "$AC13_LOOP/bg-pending.marker" ]]; then
    pass "AC-13: marker removed on non-short-circuit resume (same session)"
else
    fail "AC-13: marker removed on non-short-circuit resume (same session)" \
        "marker absent" "marker still present"
fi

if grep -q "^session_id: session_home$" "$AC13_STATE"; then
    pass "AC-13b: same-session resume leaves state.md session_id unchanged"
else
    fail "AC-13b: same-session resume leaves state.md session_id unchanged" \
        "session_id: session_home" "$(grep '^session_id:' "$AC13_STATE" || echo '(missing)')"
fi

# ---------------- AC-14 ----------------
# 防劫持：进入的不同会话不得重写存储的 session_id，也不得删除
# bg-pending.marker，即使其自身的 transcript 显示没有待处理后台事件。
# 外来会话的 transcript 无法观察驻留会话的后台活动，因此新会话
# 看到的任何内容都不是权威的。跨会话守卫接管。
echo "Test AC-14: cross-session stop preserves marker and stored session_id"
AC14_REPO="$TEST_DIR/ac14"
AC14_LOOP=$(create_full_fixture "$AC14_REPO")
AC14_STATE="$AC14_LOOP/state.md"
AC14_MARKER="$AC14_LOOP/bg-pending.marker"
AC14_BRANCH=$(git -C "$AC14_REPO" rev-parse --abbrev-ref HEAD)
AC14_BASE_COMMIT=$(git -C "$AC14_REPO" rev-parse HEAD)
cat > "$AC14_STATE" <<EOF_AC14
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC14_BRANCH
base_branch: $AC14_BRANCH
base_commit: $AC14_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_foreign
---
EOF_AC14
: > "$AC14_MARKER"

AC14_TRANSCRIPT="$TRANSCRIPTS_DIR/ac14.jsonl"
write_transcript "$AC14_TRANSCRIPT" '{"type":"user","message":{"role":"user","content":"hello"}}'
AC14_INPUT=$(jq -c -n --arg tp "$AC14_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_home"}')
run_stop_hook_with_input "$AC14_REPO" "$AC14_INPUT"

if [[ -f "$AC14_MARKER" ]]; then
    pass "AC-14: cross-session stop preserves bg-pending.marker"
else
    fail "AC-14: cross-session stop preserves bg-pending.marker" \
        "marker still present" "marker was removed (foreign-session hijack)"
fi

if grep -q "^session_id: session_foreign$" "$AC14_STATE"; then
    pass "AC-14b: cross-session stop leaves stored session_id intact"
else
    fail "AC-14b: cross-session stop leaves stored session_id intact" \
        "session_id: session_foreign" "$(grep '^session_id:' "$AC14_STATE" || echo '(missing)')"
fi

# ---------------- AC-15 ----------------
# 完成识别：当前 Claude Code transcript 格式以后台任务完成形式发出
#   type: "system", subtype: "task_notification", task_id: "..."
# 辅助函数必须识别此形式（不仅是旧版队列操作 XML 块），
# 否则已启动的任务将永远保持"pending"。
echo "Test AC-15: task_notification system records mark launches completed"
AC15_TRANSCRIPT="$TRANSCRIPTS_DIR/ac15.jsonl"
AC15_LAUNCH=$(emit_tool_use_assistant "toolu_L" "Agent" ',"description":"x","prompt":"x"')
AC15_RESULT=$(emit_async_agent_launch_result "toolu_L" "agent_done_L")
AC15_NOTIF=$(emit_sdk_task_notification "agent_done_L" "toolu_L" "completed")
write_transcript "$AC15_TRANSCRIPT" "$AC15_LAUNCH" "$AC15_RESULT" "$AC15_NOTIF"

AC15_PENDING=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    list_pending_background_task_ids "$AC15_TRANSCRIPT" 2>/dev/null
)
if [[ -z "$AC15_PENDING" ]]; then
    pass "AC-15: task_notification completion removes the matching launch from pending"
else
    fail "AC-15: task_notification completion removes the matching launch from pending" \
        "empty pending list" "got: $AC15_PENDING"
fi

# ---------------- AC-16 ----------------
# 混合格式的完成识别：两次启动，一次通过旧版队列操作 XML 块完成，
# 另一次通过当前 system/task_notification 记录完成。两个来源的
# 并集必须解析为空待处理集。
echo "Test AC-16: helper unions legacy queue-operation and task_notification completions"
AC16_TRANSCRIPT="$TRANSCRIPTS_DIR/ac16.jsonl"
AC16_L1=$(emit_tool_use_assistant "toolu_M1" "Agent" ',"description":"x","prompt":"x"')
AC16_R1=$(emit_async_agent_launch_result "toolu_M1" "agent_legacy_M1")
AC16_C1=$(emit_task_completion_event "agent_legacy_M1" "toolu_M1" "completed")
AC16_L2=$(emit_tool_use_assistant "toolu_M2" "Agent" ',"description":"y","prompt":"y"')
AC16_R2=$(emit_async_agent_launch_result "toolu_M2" "agent_sdk_M2")
AC16_C2=$(emit_sdk_task_notification "agent_sdk_M2" "toolu_M2" "completed")
write_transcript "$AC16_TRANSCRIPT" \
    "$AC16_L1" "$AC16_R1" "$AC16_C1" \
    "$AC16_L2" "$AC16_R2" "$AC16_C2"

AC16_PENDING=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    list_pending_background_task_ids "$AC16_TRANSCRIPT" 2>/dev/null
)
if [[ -z "$AC16_PENDING" ]]; then
    pass "AC-16: mixed legacy+SDK completion records resolve to empty pending set"
else
    fail "AC-16: mixed legacy+SDK completion records resolve to empty pending set" \
        "empty pending list" "got: $AC16_PENDING"
fi

# ---------------- AC-17 ----------------
# 无法验证完成时的标记保留：如果 transcript_path 缺失或不可读，
# has_pending_background_tasks 失败关闭（返回无待处理）。在这种情况下，
# 非短路清理不得擦除 bg-pending.marker 或重写 session_id，
# 因为跨会话恢复信号仍然需要。
echo "Test AC-17: missing transcript preserves bg-pending.marker and session_id"
AC17_REPO="$TEST_DIR/ac17"
AC17_LOOP=$(create_full_fixture "$AC17_REPO")
AC17_STATE="$AC17_LOOP/state.md"
AC17_BRANCH=$(git -C "$AC17_REPO" rev-parse --abbrev-ref HEAD)
AC17_BASE_COMMIT=$(git -C "$AC17_REPO" rev-parse HEAD)
cat > "$AC17_STATE" <<EOF_AC17
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC17_BRANCH
base_branch: $AC17_BRANCH
base_commit: $AC17_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_foreign
---
EOF_AC17
: > "$AC17_LOOP/bg-pending.marker"

# 钩子输入没有 transcript_path -> has_pending_background_tasks
# 失败关闭；清理路径必须保持标记和 session_id 完整。
AC17_INPUT='{"session_id":"session_home"}'
run_stop_hook_with_input "$AC17_REPO" "$AC17_INPUT"

if [[ -f "$AC17_LOOP/bg-pending.marker" ]]; then
    pass "AC-17: unreadable transcript preserves bg-pending.marker"
else
    fail "AC-17: unreadable transcript preserves bg-pending.marker" \
        "marker still present" "marker was removed"
fi

if grep -q "^session_id: session_foreign$" "$AC17_STATE"; then
    pass "AC-17b: unreadable transcript leaves stored session_id untouched"
else
    fail "AC-17b: unreadable transcript leaves stored session_id untouched" \
        "session_id: session_foreign" "$(grep '^session_id:' "$AC17_STATE" || echo '(missing)')"
fi

# AC-17c：提供了 transcript_path 但指向不存在的文件（同样不可读）。
# 相同保证：保留标记 + 存储的 session_id。
echo "Test AC-17c: transcript_path pointing at non-existent file preserves marker"
AC17C_REPO="$TEST_DIR/ac17c"
AC17C_LOOP=$(create_full_fixture "$AC17C_REPO")
AC17C_STATE="$AC17C_LOOP/state.md"
AC17C_BRANCH=$(git -C "$AC17C_REPO" rev-parse --abbrev-ref HEAD)
AC17C_BASE_COMMIT=$(git -C "$AC17C_REPO" rev-parse HEAD)
cat > "$AC17C_STATE" <<EOF_AC17C
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC17C_BRANCH
base_branch: $AC17C_BRANCH
base_commit: $AC17C_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_foreign
---
EOF_AC17C
: > "$AC17C_LOOP/bg-pending.marker"

AC17C_INPUT=$(jq -c -n --arg tp "$TRANSCRIPTS_DIR/never-written.jsonl" \
    '{transcript_path:$tp, session_id:"session_home"}')
run_stop_hook_with_input "$AC17C_REPO" "$AC17C_INPUT"

if [[ -f "$AC17C_LOOP/bg-pending.marker" ]] \
   && grep -q "^session_id: session_foreign$" "$AC17C_STATE"; then
    pass "AC-17c: missing-file transcript_path preserves marker and session_id"
else
    fail "AC-17c: missing-file transcript_path preserves marker and session_id" \
        "marker present and session_id: session_foreign" \
        "marker=$(test -f "$AC17C_LOOP/bg-pending.marker" && echo present || echo missing); session_id=$(grep '^session_id:' "$AC17C_STATE" || echo '(missing)')"
fi

# ---------------- AC-18 ----------------
# 验证器隔离：find_active_loop 的基于标记的采纳通过其第三个
# 位置参数选择加入。默认调用者（read/write/bash 等验证器）
# 必须继续看到严格的 session-id 隔离；不同会话的驻留循环
# 不得通过 bg-pending.marker 对它们可见。
echo "Test AC-18: find_active_loop default invocation ignores foreign marker"
AC18_BASE="$TEST_DIR/ac18-loops"
mkdir -p "$AC18_BASE/2026-03-02_00-00-00"
cat > "$AC18_BASE/2026-03-02_00-00-00/state.md" <<'EOF_AC18'
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
session_id: session_foreign
---
EOF_AC18
: > "$AC18_BASE/2026-03-02_00-00-00/bg-pending.marker"

AC18_DEFAULT=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    find_active_loop "$AC18_BASE" "session_home"
)
if [[ -z "$AC18_DEFAULT" ]]; then
    pass "AC-18: find_active_loop default (no opt-in) ignores foreign marker dir"
else
    fail "AC-18: find_active_loop default (no opt-in) ignores foreign marker dir" \
        "empty result (validators stay isolated)" "got: $AC18_DEFAULT"
fi

AC18_OPTIN=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    find_active_loop "$AC18_BASE" "session_home" true
)
if [[ "$AC18_OPTIN" == "$AC18_BASE/2026-03-02_00-00-00" ]]; then
    pass "AC-18b: find_active_loop with opt-in does return the marker dir"
else
    fail "AC-18b: find_active_loop with opt-in does return the marker dir" \
        "$AC18_BASE/2026-03-02_00-00-00" "$AC18_OPTIN"
fi

# ---------------- AC-19 ----------------
# 空会话调用者 + bg-pending.marker 存在：调用者可能是驻留循环的
# 所有者通过未转发 session_id 的包装器调用，或者可能是不同会话。
# 钩子无法从输入中区分它们，因此安全响应是静默 `exit 0`，
# 没有 systemMessage 和磁盘变更。真实的 Claude 停止钩子
# （始终填充 session_id）驱动实际的驻留和清理。
echo "Test AC-19: ambiguous caller (empty session_id + marker) exits silently"
AC19_REPO="$TEST_DIR/ac19"
AC19_LOOP=$(create_full_fixture "$AC19_REPO")
AC19_STATE="$AC19_LOOP/state.md"
AC19_MARKER="$AC19_LOOP/bg-pending.marker"
AC19_BRANCH=$(git -C "$AC19_REPO" rev-parse --abbrev-ref HEAD)
AC19_BASE_COMMIT=$(git -C "$AC19_REPO" rev-parse HEAD)
cat > "$AC19_STATE" <<EOF_AC19
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC19_BRANCH
base_branch: $AC19_BRANCH
base_commit: $AC19_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_alpha
---
EOF_AC19
AC19_STATE_HASH_BEFORE=$(sha256sum "$AC19_STATE" | awk '{print $1}')
: > "$AC19_MARKER"

AC19_TRANSCRIPT="$TRANSCRIPTS_DIR/ac19.jsonl"
write_transcript "$AC19_TRANSCRIPT" '{"type":"user","message":{"role":"user","content":"hello"}}'

# 没有任何 session_id 键的钩子输入（镜像不带 --session-id
# 调用的 rlcr-stop-gate.sh）。
AC19_INPUT=$(jq -c -n --arg tp "$AC19_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC19_REPO" "$AC19_INPUT"
AC19_SYS_MSG=$(printf '%s' "$RUN_OUTPUT" | jq -r '.systemMessage // empty' 2>/dev/null || echo "")
AC19_STATE_HASH_AFTER=$(sha256sum "$AC19_STATE" | awk '{print $1}')
if [[ "$RUN_EXIT_CODE" -eq 0 ]] \
   && [[ ! -f "$RUN_MARKER" ]] \
   && [[ -f "$AC19_MARKER" ]] \
   && [[ "$AC19_STATE_HASH_BEFORE" == "$AC19_STATE_HASH_AFTER" ]] \
   && [[ -z "$AC19_SYS_MSG" ]]; then
    pass "AC-19: ambiguous caller exits silently; marker and state.md preserved"
else
    fail "AC-19: ambiguous caller exits silently; marker and state.md preserved" \
        "exit 0 + no systemMessage + marker stays + state.md byte-identical + no Codex" \
        "exit $RUN_EXIT_CODE, codex_marker=$(test -f "$RUN_MARKER" && echo present || echo missing), bg_marker=$(test -f "$AC19_MARKER" && echo present || echo missing), state_unchanged=$([[ "$AC19_STATE_HASH_BEFORE" == "$AC19_STATE_HASH_AFTER" ]] && echo yes || echo no), systemMessage='$AC19_SYS_MSG'; output: $RUN_OUTPUT"
fi

# ---------------- AC-20 ----------------
# 当 transcript 存在但无法解析时，非短路清理不得丢弃
# bg-pending.marker。辅助函数对格式错误的 JSON 是失败关闭的；
# 该失败不得被视为"无待处理"。
echo "Test AC-20: malformed transcript preserves bg-pending.marker"
AC20_REPO="$TEST_DIR/ac20"
AC20_LOOP=$(create_full_fixture "$AC20_REPO")
AC20_STATE="$AC20_LOOP/state.md"
AC20_MARKER="$AC20_LOOP/bg-pending.marker"
AC20_BRANCH=$(git -C "$AC20_REPO" rev-parse --abbrev-ref HEAD)
AC20_BASE_COMMIT=$(git -C "$AC20_REPO" rev-parse HEAD)
cat > "$AC20_STATE" <<EOF_AC20
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC20_BRANCH
base_branch: $AC20_BRANCH
base_commit: $AC20_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_home
---
EOF_AC20
: > "$AC20_MARKER"

# 写入故意格式错误的 transcript（截断的 JSON 对象），
# 使 list_pending_background_task_ids 的 jq 调用解析失败。
AC20_TRANSCRIPT="$TRANSCRIPTS_DIR/ac20.jsonl"
printf '%s\n' '{"type":"user","message":' > "$AC20_TRANSCRIPT"

AC20_INPUT=$(jq -c -n --arg tp "$AC20_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_home"}')
run_stop_hook_with_input "$AC20_REPO" "$AC20_INPUT"

if [[ -f "$AC20_MARKER" ]]; then
    pass "AC-20: malformed transcript preserves bg-pending.marker"
else
    fail "AC-20: malformed transcript preserves bg-pending.marker" \
        "marker still present (cleanup must not fire on fail-closed helper)" \
        "marker was removed"
fi

# ---------------- AC-21 ----------------
# Transcript 扫描边界：Claude transcript 是会话范围的，可能包含
# 早于 RLCR 循环的后台启动。辅助函数通过 `.timestamp >= since_ts`
# （从循环目录基名派生）过滤启动事件，因此只有循环开始后进行的
# 启动才算作待处理。
echo "Test AC-21: pre-loop launches are filtered out by since_ts"
AC21_TRANSCRIPT="$TRANSCRIPTS_DIR/ac21.jsonl"

# 整个测试套件夹具使用的循环边界是 2026-03-01 00:00:00。
# 构建两次启动：一次在该边界之前（应被过滤），一次在之后
# （应仍算作待处理）。
AC21_PRE_LAUNCH=$(jq -c -n '{
    type:"user",
    timestamp:"2026-02-28T10:00:00.000Z",
    toolUseResult:{isAsync:true, agentId:"agent_pre_loop"}
}')
AC21_POST_LAUNCH=$(jq -c -n '{
    type:"user",
    timestamp:"2026-03-01T10:00:00.000Z",
    toolUseResult:{isAsync:true, agentId:"agent_in_loop"}
}')
write_transcript "$AC21_TRANSCRIPT" "$AC21_PRE_LAUNCH" "$AC21_POST_LAUNCH"

AC21_SINCE="2026-03-01T00:00:00.000Z"
AC21_FILTERED=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    list_pending_background_task_ids "$AC21_TRANSCRIPT" "$AC21_SINCE" 2>/dev/null | sort -u
)
if [[ "$AC21_FILTERED" == "agent_in_loop" ]]; then
    pass "AC-21: list_pending_background_task_ids filters launches before since_ts"
else
    fail "AC-21: list_pending_background_task_ids filters launches before since_ts" \
        "only 'agent_in_loop' (pre-loop launch excluded)" "got: $AC21_FILTERED"
fi

# AC-21b：确认 derive 辅助函数在 TZ=UTC 下产生预期的 ISO-8601 格式，
# 其中本地挂钟 == UTC，因此不应用偏移。
AC21B_DERIVED=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    export TZ="UTC"
    derive_loop_start_iso_ts "/tmp/.humanize/rlcr/2026-03-01_00-00-00"
)
if [[ "$AC21B_DERIVED" == "2026-03-01T00:00:00.000Z" ]]; then
    pass "AC-21b: derive_loop_start_iso_ts under TZ=UTC preserves the wall-clock"
else
    fail "AC-21b: derive_loop_start_iso_ts under TZ=UTC preserves the wall-clock" \
        "2026-03-01T00:00:00.000Z" "$AC21B_DERIVED"
fi

# AC-21d：setup-rlcr-loop.sh 使用本地挂钟命名目录，因此非 UTC
# 调用者必须看到边界偏移到实际 UTC。
# JST（UTC+9）示例：09:00 JST == 00:00 UTC。
AC21D_DERIVED=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    export TZ="Asia/Tokyo"
    derive_loop_start_iso_ts "/tmp/.humanize/rlcr/2026-03-01_09-00-00"
)
if [[ "$AC21D_DERIVED" == "2026-03-01T00:00:00.000Z" ]]; then
    pass "AC-21d: derive_loop_start_iso_ts converts JST wall-clock to correct UTC"
else
    fail "AC-21d: derive_loop_start_iso_ts converts JST wall-clock to correct UTC" \
        "2026-03-01T00:00:00.000Z (9am JST = 0am UTC)" "$AC21D_DERIVED"
fi

# AC-21e：PST（UTC-8）示例。选择仍在 PST 的 3 月 1 日（DST
# 直到 2026 年 3 月 8 日才开始），因此偏移为固定的 -8 小时：
# 00:00 PST == 08:00 UTC。
AC21E_DERIVED=$(
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh"
    export TZ="America/Los_Angeles"
    derive_loop_start_iso_ts "/tmp/.humanize/rlcr/2026-03-01_00-00-00"
)
if [[ "$AC21E_DERIVED" == "2026-03-01T08:00:00.000Z" ]]; then
    pass "AC-21e: derive_loop_start_iso_ts converts PST wall-clock to correct UTC"
else
    fail "AC-21e: derive_loop_start_iso_ts converts PST wall-clock to correct UTC" \
        "2026-03-01T08:00:00.000Z (0am PST = 8am UTC before DST)" "$AC21E_DERIVED"
fi

# AC-21c：通过停止钩子的端到端测试。仅循环前启动 -> 钩子
# 不得短路（没有"属于"此循环的待处理后台）。
echo "Test AC-21c: stop hook ignores pre-loop launches for this loop"
AC21C_REPO="$TEST_DIR/ac21c"
AC21C_LOOP=$(create_full_fixture "$AC21C_REPO")
AC21C_MARKER="$AC21C_LOOP/bg-pending.marker"
AC21C_TRANSCRIPT="$TRANSCRIPTS_DIR/ac21c.jsonl"
write_transcript "$AC21C_TRANSCRIPT" "$AC21_PRE_LAUNCH"
AC21C_INPUT=$(jq -c -n --arg tp "$AC21C_TRANSCRIPT" \
    '{transcript_path:$tp, session_id:"session_home"}')
run_stop_hook_with_input "$AC21C_REPO" "$AC21C_INPUT"

# 过滤掉循环前启动后，transcript 没有循环内待处理后台 ->
# 无短路 -> 无标记写入 -> 钩子进入正常流程（在此夹具中将调用 Codex）。
if [[ ! -f "$AC21C_MARKER" ]] && [[ -f "$RUN_MARKER" ]]; then
    pass "AC-21c: pre-loop launch does not write bg-pending.marker; Codex runs"
else
    fail "AC-21c: pre-loop launch does not write bg-pending.marker; Codex runs" \
        "no bg marker AND Codex invoked" \
        "bg_marker=$(test -f "$AC21C_MARKER" && echo present || echo missing); codex_marker=$(test -f "$RUN_MARKER" && echo present || echo missing)"
fi

# ---------------- AC-22 ----------------
# 在没有标记的仓库上不带 --session-id 的包装器：应与正常的
# 同会话路径行为相同，即 transcript 中的待处理后台写入标记，
# 包装器输出显示"background task" systemMessage。这确认了
# 模糊调用者守卫仅在先前存在的标记上触发，而不是在每次
# 无会话调用上触发。
echo "Test AC-22: wrapper without session_id, no prior marker, pending bg -> ALLOW with systemMessage"
AC22_REPO="$TEST_DIR/ac22"
create_full_fixture "$AC22_REPO" > /dev/null
AC22_LOOP="$AC22_REPO/.humanize/rlcr/2026-03-01_00-00-00"
AC22_MARKER="$AC22_LOOP/bg-pending.marker"
AC22_TRANSCRIPT="$TRANSCRIPTS_DIR/ac22.jsonl"
AC22_LAUNCH=$(jq -c -n '{
    type:"user",
    timestamp:"2026-03-01T10:00:00.000Z",
    toolUseResult:{isAsync:true, agentId:"agent_wrapper_pending"}
}')
write_transcript "$AC22_TRANSCRIPT" "$AC22_LAUNCH"

AC22_OUT="$TEST_DIR/ac22-out.txt"
set +e
(
    cd "$AC22_REPO"
    "$GATE_SCRIPT" --project-root "$AC22_REPO" --transcript-path "$AC22_TRANSCRIPT"
) > "$AC22_OUT" 2>&1
AC22_EXIT=$?
set -e

if [[ "$AC22_EXIT" -eq 0 ]] \
   && grep -q "^ALLOW:" "$AC22_OUT" \
   && grep -q "background task" "$AC22_OUT" \
   && [[ -f "$AC22_MARKER" ]]; then
    pass "AC-22: wrapper without session_id + no prior marker + pending bg -> writes marker, surfaces systemMessage"
else
    AC22_BODY=$(cat "$AC22_OUT" 2>/dev/null || true)
    fail "AC-22: wrapper without session_id + no prior marker + pending bg -> writes marker, surfaces systemMessage" \
        "exit 0 + ALLOW + 'background task' + marker written" \
        "exit $AC22_EXIT; marker=$(test -f "$AC22_MARKER" && echo present || echo missing); output: $AC22_BODY"
fi

# AC-22b：在已有标记的仓库上不带 --session-id 的包装器
# （例如由先前钩子调用设置）。必须静默退出 0 -- 无 systemMessage，
# 无状态变更。镜像 Codex 标记的真实场景：rlcr-stop-gate.sh
# 被不知情的调用者重新运行。
echo "Test AC-22b: wrapper without session_id, prior marker -> silent ALLOW"
AC22B_REPO="$TEST_DIR/ac22b"
AC22B_LOOP=$(create_full_fixture "$AC22B_REPO")
AC22B_STATE="$AC22B_LOOP/state.md"
AC22B_MARKER="$AC22B_LOOP/bg-pending.marker"
AC22B_BRANCH=$(git -C "$AC22B_REPO" rev-parse --abbrev-ref HEAD)
AC22B_BASE_COMMIT=$(git -C "$AC22B_REPO" rev-parse HEAD)
cat > "$AC22B_STATE" <<EOF_AC22B
---
current_round: 0
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 60
push_every_round: false
full_review_round: 5
plan_file: "plans/test-plan.md"
plan_tracked: false
start_branch: $AC22B_BRANCH
base_branch: $AC22B_BRANCH
base_commit: $AC22B_BASE_COMMIT
review_started: false
ask_codex_question: false
agent_teams: false
session_id: session_alpha
---
EOF_AC22B
AC22B_STATE_HASH_BEFORE=$(sha256sum "$AC22B_STATE" | awk '{print $1}')
: > "$AC22B_MARKER"

AC22B_OUT="$TEST_DIR/ac22b-out.txt"
set +e
(
    cd "$AC22B_REPO"
    "$GATE_SCRIPT" --project-root "$AC22B_REPO"
) > "$AC22B_OUT" 2>&1
AC22B_EXIT=$?
set -e

AC22B_STATE_HASH_AFTER=$(sha256sum "$AC22B_STATE" | awk '{print $1}')
if [[ "$AC22B_EXIT" -eq 0 ]] \
   && grep -q "^ALLOW:" "$AC22B_OUT" \
   && ! grep -qi "parked" "$AC22B_OUT" \
   && [[ -f "$AC22B_MARKER" ]] \
   && [[ "$AC22B_STATE_HASH_BEFORE" == "$AC22B_STATE_HASH_AFTER" ]]; then
    pass "AC-22b: wrapper without session_id + existing marker -> silent ALLOW; marker and state preserved"
else
    AC22B_BODY=$(cat "$AC22B_OUT" 2>/dev/null || true)
    fail "AC-22b: wrapper without session_id + existing marker -> silent ALLOW; marker and state preserved" \
        "exit 0 + ALLOW: (no 'parked') + marker kept + state.md byte-identical" \
        "exit $AC22B_EXIT; marker=$(test -f "$AC22B_MARKER" && echo present || echo missing); state_unchanged=$([[ "$AC22B_STATE_HASH_BEFORE" == "$AC22B_STATE_HASH_AFTER" ]] && echo yes || echo no); output: $AC22B_BODY"
fi

# ---------------- AC-23 ----------------
# 存活探针阳性：输出文件被至少一个进程打开（lsof 退出 0）的
# 待处理任务仍必须被视为正在运行。短路必须触发并发出 systemMessage。
echo "Test AC-23: liveness probe - alive task (lsof has holder) -> still short-circuits"
AC23_REPO="$TEST_DIR/ac23"
AC23_LOOP=$(create_full_fixture "$AC23_REPO")
AC23_STATE="$AC23_LOOP/state.md"
AC23_TRANSCRIPT="$TRANSCRIPTS_DIR/ac23.jsonl"
AC23_TASK_ID="agent_probe_alive"
AC23_LAUNCH=$(emit_tool_use_assistant "toolu_AC23" "Agent" ',"description":"x","prompt":"x"')
AC23_RESULT=$(emit_async_agent_launch_result "toolu_AC23" "$AC23_TASK_ID")
write_transcript "$AC23_TRANSCRIPT" "$AC23_LAUNCH" "$AC23_RESULT"

AC23_UID=$(id -u)
AC23_SLUG=$(basename "$TRANSCRIPTS_DIR")
AC23_TASKS_DIR="/tmp/claude-${AC23_UID}/${AC23_SLUG}/ac23/tasks"
mkdir -p "$AC23_TASKS_DIR"
touch "$AC23_TASKS_DIR/${AC23_TASK_ID}.output"

AC23_INPUT=$(jq -c -n --arg tp "$AC23_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC23_REPO" "$AC23_INPUT" "" "$TEST_DIR/bin/lsof-alive"
rm -rf "/tmp/claude-${AC23_UID}/${AC23_SLUG}/ac23" 2>/dev/null || true
assert_systemmessage_only \
    "AC-23: alive task (lsof has holder) still triggers short-circuit" \
    "$AC23_REPO" "$AC23_STATE" "1 background task"

# ---------------- AC-24 ----------------
# 存活探针阴性：输出文件没有打开的文件描述符（lsof 退出 1）的
# 待处理任务在没有完成事件的情况下被杀死。探针必须丢弃它，
# 使钩子进入正常 Codex 审查。
echo "Test AC-24: liveness probe - dead/orphaned task (lsof no holder) -> reaches Codex"
AC24_REPO="$TEST_DIR/ac24"
create_full_fixture "$AC24_REPO" > /dev/null
AC24_TRANSCRIPT="$TRANSCRIPTS_DIR/ac24.jsonl"
AC24_TASK_ID="agent_probe_dead"
AC24_LAUNCH=$(emit_tool_use_assistant "toolu_AC24" "Agent" ',"description":"x","prompt":"x"')
AC24_RESULT=$(emit_async_agent_launch_result "toolu_AC24" "$AC24_TASK_ID")
write_transcript "$AC24_TRANSCRIPT" "$AC24_LAUNCH" "$AC24_RESULT"

AC24_UID=$(id -u)
AC24_SLUG=$(basename "$TRANSCRIPTS_DIR")
AC24_TASKS_DIR="/tmp/claude-${AC24_UID}/${AC24_SLUG}/ac24/tasks"
mkdir -p "$AC24_TASKS_DIR"
touch "$AC24_TASKS_DIR/${AC24_TASK_ID}.output"

AC24_INPUT=$(jq -c -n --arg tp "$AC24_TRANSCRIPT" '{transcript_path:$tp}')
run_stop_hook_with_input "$AC24_REPO" "$AC24_INPUT" "" "$TEST_DIR/bin/lsof-dead"
rm -rf "/tmp/claude-${AC24_UID}/${AC24_SLUG}/ac24" 2>/dev/null || true
assert_reached_codex "AC-24: dead/orphaned task (lsof no holder) is pruned; Codex review runs"

print_test_summary "Stop Hook Background-Task Allow Test Summary"
exit $?
