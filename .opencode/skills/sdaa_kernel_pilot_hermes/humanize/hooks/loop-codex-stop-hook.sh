#!/usr/bin/env bash
#
# RLCR 循环的 Stop Hook
#
# 拦截 Claude 的退出尝试并使用 Codex 审查工作。
# 如果 Codex 不确认完成，则阻止退出并反馈审查结果。
#
# 状态目录：.humanize/rlcr/<timestamp>/
# 状态文件：state.md（current_round、max_iterations、codex 配置）
# 摘要文件：round-N-summary.md（Claude 的工作摘要）
# 审查提示：round-N-review-prompt.md（发送给 Codex 的提示）
# 审查结果：round-N-review-result.md（Codex 的审查）
#

set -euo pipefail

# ========================================
# 默认配置
# ========================================

# DEFAULT_CODEX_MODEL 和 DEFAULT_CODEX_EFFORT 由 loop-common.sh（下面源码引入）提供
DEFAULT_CODEX_TIMEOUT=5400

# ========================================
# 读取钩子输入
# ========================================

HOOK_INPUT=$(cat)
# 清洗无效 UTF-8 字节（此处尚未加载 loop-common.sh，不能用 read_hook_input）。
# 关键：iconv 调用必须容错。在某些钩子运行环境下 iconv 会以退出码 126 失败
# （exec 失败：ETXTBSY/受限运行环境），而未加保护的 `HOOK_INPUT=$(... | iconv ...)`
# 在 set -e + pipefail 下会让整个 Stop 钩子以 126 退出、无 stderr，静默跳过
# Codex 审查门（典型表现：'No stderr output'）。这里用 || true 吞掉失败，并且只在
# iconv 真正产出非空结果时替换，否则保留原始（合法）输入，绝不中止、绝不清空输入。
if command -v iconv >/dev/null 2>&1; then
    _ci=$(printf '%s' "$HOOK_INPUT" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true)
    if [[ -n "$_ci" ]]; then HOOK_INPUT="$_ci"; fi
    unset _ci
fi

# 注意：我们故意在这里不检查 stop_hook_active。
# 对于迭代循环，当 Claude 从先前被阻止的停止继续时，stop_hook_active 将为 true。
# 我们希望每次迭代都运行 Codex 审查。
# 循环终止由以下控制：
# - 没有活跃循环目录（没有 state.md）-> 在下面提前退出
# - Codex 输出 MARKER_COMPLETE -> 允许退出
# - current_round >= max_iterations -> 允许退出

# ========================================
# 查找活跃循环
# ========================================

# 源码引入共享循环函数和模板加载器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/loop-common.sh"

PROJECT_ROOT="$(resolve_project_root)" || exit 0
LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"

# 源码引入可移植的 git 操作超时包装器
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/scripts/portable-timeout.sh"

# 源码引入方法论分析库
source "$SCRIPT_DIR/lib/methodology-analysis.sh"

# git 操作的默认超时（30 秒）
GIT_TIMEOUT=30

# 模板目录由 loop-common.sh 通过 template-loader.sh 设置

# 从钩子输入中提取 session_id 用于会话感知的循环过滤
HOOK_SESSION_ID=$(extract_session_id "$HOOK_INPUT")

LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID" true)

# 如果没有活跃循环（或 session_id 不匹配），允许退出
if [[ -z "$LOOP_DIR" ]]; then
    exit 0
fi

# ========================================
# 后台任务守卫
# ========================================
# 委托给 handle_bg_task_short_circuit（hooks/lib/loop-bg-tasks.sh），
# 它按顺序运行四个内聚的守卫：
#   1. 调用者歧义标记守卫（没有 session_id + 标记存在）
#   2. 跨会话驻留循环守卫（外部会话进入）
#   3. 待处理后台任务短路（此会话有异步工作正在进行）
#   4. 同会话过期标记清理（后台工作刚完成）
# 当任何守卫短路时，它在 stdout 上发出适当的 JSON 并直接 `exit 0`；
# 我们永远不会从该调用返回。当没有守卫触发时，我们继续下面的正常门控逻辑。
handle_bg_task_short_circuit "$LOOP_DIR" "$HOOK_INPUT" "$HOOK_SESSION_ID"

# ========================================
# 检测循环阶段：正常或 Finalize
# ========================================
# 正常循环：state.md 存在
# Finalize 阶段：finalize-state.md 存在（Codex COMPLETE 之后，最终完成之前）

STATE_FILE=$(resolve_active_state_file "$LOOP_DIR")
if [[ -z "$STATE_FILE" ]]; then
    # 未找到状态文件，允许退出
    exit 0
fi

IS_FINALIZE_PHASE=false
[[ "$STATE_FILE" == *"/finalize-state.md" ]] && IS_FINALIZE_PHASE=true

IS_METHODOLOGY_ANALYSIS_PHASE=false
[[ "$STATE_FILE" == *"/methodology-analysis-state.md" ]] && IS_METHODOLOGY_ANALYSIS_PHASE=true

# ========================================
# 解析状态文件（使用共享函数）
# ========================================

# 首先提取原始前置元数据以检查实际存在哪些字段
# 这防止了对缺失关键字段静默使用默认值
RAW_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")

# 在解析之前检查关键字段是否存在（解析会应用默认值）
RAW_CURRENT_ROUND=$(echo "$RAW_FRONTMATTER" | grep "^current_round:" || true)
RAW_MAX_ITERATIONS=$(echo "$RAW_FRONTMATTER" | grep "^max_iterations:" || true)
RAW_FULL_REVIEW_ROUND=$(echo "$RAW_FRONTMATTER" | grep "^full_review_round:" || true)
RAW_BITLESSON_REQUIRED=$(echo "$RAW_FRONTMATTER" | grep "^bitlesson_required:" || true)
RAW_BITLESSON_FILE=$(echo "$RAW_FRONTMATTER" | grep "^bitlesson_file:" || true)
RAW_BITLESSON_ALLOW_EMPTY_NONE=$(echo "$RAW_FRONTMATTER" | grep "^bitlesson_allow_empty_none:" || true)

# 使用容错解析提取值
# 注意：parse_state_file 对缺失的 current_round/max_iterations 应用默认值
if ! parse_state_file "$STATE_FILE" 2>/dev/null; then
    echo "Warning: parse_state_file returned non-zero, proceeding to schema validation" >&2
fi

# 将 STATE_* 变量映射到本地名称以保持向后兼容性
PLAN_TRACKED="$STATE_PLAN_TRACKED"
START_BRANCH="$STATE_START_BRANCH"
BASE_BRANCH="${STATE_BASE_BRANCH:-}"
BASE_COMMIT="${STATE_BASE_COMMIT:-}"
PLAN_FILE="$STATE_PLAN_FILE"
CURRENT_ROUND="$STATE_CURRENT_ROUND"
MAX_ITERATIONS="$STATE_MAX_ITERATIONS"
PUSH_EVERY_ROUND="$STATE_PUSH_EVERY_ROUND"
FULL_REVIEW_ROUND="${STATE_FULL_REVIEW_ROUND:-5}"
REVIEW_STARTED="$STATE_REVIEW_STARTED"
CODEX_EXEC_MODEL="${STATE_CODEX_MODEL:-$DEFAULT_CODEX_MODEL}"
CODEX_EXEC_EFFORT="${STATE_CODEX_EFFORT:-$DEFAULT_CODEX_EFFORT}"
CODEX_REVIEW_MODEL="$CODEX_EXEC_MODEL"
CODEX_REVIEW_EFFORT="high"
CODEX_TIMEOUT="${STATE_CODEX_TIMEOUT:-${CODEX_TIMEOUT:-$DEFAULT_CODEX_TIMEOUT}}"
ASK_CODEX_QUESTION="${STATE_ASK_CODEX_QUESTION:-false}"
AGENT_TEAMS="${STATE_AGENT_TEAMS:-false}"
PRIVACY_MODE="${STATE_PRIVACY_MODE:-true}"
STRICT_SUCCESS="${STATE_STRICT_SUCCESS:-false}"
BITLESSON_REQUIRED="false"
if [[ -n "$RAW_BITLESSON_REQUIRED" ]]; then
    BITLESSON_REQUIRED=$(echo "$RAW_BITLESSON_REQUIRED" | sed 's/^bitlesson_required:[[:space:]]*//' | tr -d ' "')
fi
BITLESSON_FILE_REL=".humanize/bitlesson.md"
if [[ -n "$RAW_BITLESSON_FILE" ]]; then
    BITLESSON_FILE_REL=$(echo "$RAW_BITLESSON_FILE" | sed 's/^bitlesson_file:[[:space:]]*//' | sed 's/^"//; s/"$//')
fi
if [[ -z "$BITLESSON_FILE_REL" ]] || \
   [[ ! "$BITLESSON_FILE_REL" =~ ^[a-zA-Z0-9._/-]+$ ]] || \
   [[ "$BITLESSON_FILE_REL" = /* ]] || \
   [[ "$BITLESSON_FILE_REL" =~ (^|/)\.\.(/|$) ]]; then
    BITLESSON_FILE_REL=".humanize/bitlesson.md"
fi
BITLESSON_FILE="$PROJECT_ROOT/$BITLESSON_FILE_REL"
BITLESSON_ALLOW_EMPTY_NONE="true"
if [[ -n "$RAW_BITLESSON_ALLOW_EMPTY_NONE" ]]; then
    BITLESSON_ALLOW_EMPTY_NONE=$(echo "$RAW_BITLESSON_ALLOW_EMPTY_NONE" | sed 's/^bitlesson_allow_empty_none:[[:space:]]*//' | tr -d ' "')
fi
if [[ "${HUMANIZE_ALLOW_EMPTY_BITLESSON_NONE:-}" == "true" ]]; then
    BITLESSON_ALLOW_EMPTY_NONE="true"
fi
if [[ "$BITLESSON_ALLOW_EMPTY_NONE" != "true" && "$BITLESSON_ALLOW_EMPTY_NONE" != "false" ]]; then
    BITLESSON_ALLOW_EMPTY_NONE="true"
fi
MAINLINE_STALL_COUNT="${STATE_MAINLINE_STALL_COUNT:-0}"
LAST_MAINLINE_VERDICT="${STATE_LAST_MAINLINE_VERDICT:-$MAINLINE_VERDICT_UNKNOWN}"
DRIFT_STATUS="${STATE_DRIFT_STATUS:-$DRIFT_STATUS_NORMAL}"
# 重新验证 Codex Model 和 Effort 的 YAML 安全性（以防 state.md 被手动编辑）
# 使用与 setup-rlcr-loop.sh 相同的验证模式
if [[ ! "$CODEX_EXEC_MODEL" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: Invalid codex_model in state file: $CODEX_EXEC_MODEL" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_UNEXPECTED"
    exit 0
fi
if [[ ! "$CODEX_EXEC_EFFORT" =~ ^(xhigh|high|medium|low)$ ]]; then
    echo "Error: Invalid codex effort in state file: $CODEX_EXEC_EFFORT" >&2
    echo "  Must be one of: xhigh, high, medium, low" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_UNEXPECTED"
    exit 0
fi

# 验证关键字段是否实际存在（不仅仅是默认值）
# 这防止了将截断的状态文件静默视为第 0 轮
if [[ -z "$RAW_CURRENT_ROUND" ]]; then
    echo "Error: State file missing required field: current_round" >&2
    echo "  State file may be truncated or corrupted" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_UNEXPECTED"
    exit 0
fi
if [[ -z "$RAW_MAX_ITERATIONS" ]]; then
    echo "Error: State file missing required field: max_iterations" >&2
    echo "  State file may be truncated or corrupted" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_UNEXPECTED"
    exit 0
fi

# 验证数字字段
if [[ ! "$CURRENT_ROUND" =~ ^[0-9]+$ ]]; then
    echo "Warning: State file corrupted (current_round not numeric), stopping loop" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_UNEXPECTED"
    exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Warning: State file corrupted (max_iterations not numeric), using default" >&2
    MAX_ITERATIONS=84
fi

if [[ ! "$MAINLINE_STALL_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Warning: Invalid mainline_stall_count '$MAINLINE_STALL_COUNT', defaulting to 0" >&2
    MAINLINE_STALL_COUNT=0
fi
LAST_MAINLINE_VERDICT=$(normalize_mainline_progress_verdict "$LAST_MAINLINE_VERDICT")
DRIFT_STATUS=$(normalize_drift_status "$DRIFT_STATUS")
if [[ "$STRICT_SUCCESS" != "true" && "$STRICT_SUCCESS" != "false" ]]; then
    echo "Warning: Invalid strict_success '$STRICT_SUCCESS', defaulting to false" >&2
    STRICT_SUCCESS="false"
fi

# ========================================
# 快速检查 0：模式验证（v1.1.2+ 字段）
# ========================================
# 如果模式过时，以意外方式终止循环

if [[ -z "$PLAN_TRACKED" || -z "$START_BRANCH" ]]; then
    REASON="RLCR loop state file is missing required fields (plan_tracked or start_branch).

This indicates the loop was started with an older version of humanize.

**Options:**
1. Cancel the loop: \`/humanize:cancel-rlcr-loop\`
2. Update humanize plugin to version 1.1.2+
3. Restart the RLCR loop with the updated plugin"
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - state schema outdated" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# ========================================
# 快速检查 0.1：模式验证（v1.5.0+ 字段）
# ========================================
# 验证 v1.5.0+ 状态文件的 review_started 和 base_branch 字段

if [[ -z "$REVIEW_STARTED" || ( "$REVIEW_STARTED" != "true" && "$REVIEW_STARTED" != "false" ) ]]; then
    REASON="RLCR loop state file is missing or has invalid review_started field.

This indicates the loop was started with an older version of humanize (pre-1.5.0).

**Options:**
1. Cancel the loop: \`/humanize:cancel-rlcr-loop\`
2. Update humanize plugin to version 1.5.0+
3. Restart the RLCR loop with the updated plugin"
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - state schema outdated (missing review_started)" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

if [[ -z "$BASE_BRANCH" ]]; then
    REASON="RLCR loop state file is missing base_branch field.

This indicates the loop was started with an older version of humanize (pre-1.5.0).

**Options:**
1. Cancel the loop: \`/humanize:cancel-rlcr-loop\`
2. Update humanize plugin to version 1.5.0+
3. Restart the RLCR loop with the updated plugin"
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - state schema outdated (missing base_branch)" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# ========================================
# 快速检查 0.2：模式警告（v1.5.2+ 字段）
# ========================================
# 警告缺失的 full_review_round 字段（在 v1.5.2 中引入）
# 这是一个非阻塞警告 - 我们使用默认值（5）继续

if [[ -z "$RAW_FULL_REVIEW_ROUND" ]]; then
    echo "Note: State file missing full_review_round field (introduced in v1.5.2)." >&2
    echo "  Using default value: 5 (Full Alignment Checks at rounds 4, 9, 14, ...)" >&2
    echo "  To use configurable Full Alignment Check intervals, upgrade to humanize v1.5.2+" >&2
    echo "  and restart the RLCR loop with --full-review-round <N> option." >&2
fi

# ========================================
# 快速检查 0.5：分支一致性
# ========================================

# 使用 || GIT_EXIT_CODE=$? 防止 set -e 在非零退出时中止
CURRENT_BRANCH=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null) || GIT_EXIT_CODE=$?
GIT_EXIT_CODE=${GIT_EXIT_CODE:-0}
if [[ $GIT_EXIT_CODE -ne 0 || -z "$CURRENT_BRANCH" ]]; then
    REASON="Git operation failed or timed out.

Cannot verify branch consistency. This may indicate:
- Git is not responding
- Repository is in an invalid state
- Network issues (if remote operations are involved)

Please check git status manually and try again."
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - git operation failed" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

if [[ -n "$START_BRANCH" && "$CURRENT_BRANCH" != "$START_BRANCH" ]]; then
    REASON="Git branch changed during RLCR loop.

Started on: $START_BRANCH
Current: $CURRENT_BRANCH

Branch switching is not allowed. Switch back to $START_BRANCH or cancel the loop."
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - branch changed" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# ========================================
# 快速检查 0.6：计划文件完整性
# ========================================
# 在审查阶段（review_started=true）跳过此检查
# 在审查阶段，计划文件不再需要 - 只有代码审查重要。
# 这对于没有真实计划文件的 skip-impl 模式尤其重要。

if [[ "$REVIEW_STARTED" == "true" ]]; then
    echo "审查阶段：跳过计划文件完整性检查（计划不再需要）" >&2
else

BACKUP_PLAN="$LOOP_DIR/plan.md"
FULL_PLAN_PATH="$PROJECT_ROOT/$PLAN_FILE"

# 检查备份是否存在
if [[ ! -f "$BACKUP_PLAN" ]]; then
    REASON="Plan file backup not found in loop directory.

Please copy the plan file to the loop directory:
  cp \"$FULL_PLAN_PATH\" \"$BACKUP_PLAN\"

This backup is required for plan integrity verification."
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - plan backup missing" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# 检查原始计划文件是否仍与备份匹配
if [[ ! -f "$FULL_PLAN_PATH" ]]; then
    REASON="Project plan file has been deleted.

Original: $PLAN_FILE
Backup available at: $BACKUP_PLAN

You can restore from backup if needed. Plan file modifications are not allowed during RLCR loop."
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - plan file deleted" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# 检查计划文件完整性
# 对于已跟踪的文件：检查 git 状态（未提交）和内容差异（已提交的更改）
# 对于 gitignore 的文件：仅检查内容差异
if [[ "$PLAN_TRACKED" == "true" ]]; then
    # 已跟踪文件：首先检查 git 状态是否有未提交的更改
    PLAN_GIT_STATUS=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" status --porcelain "$PLAN_FILE" 2>/dev/null || echo "")
    if [[ -n "$PLAN_GIT_STATUS" ]]; then
        REASON="Plan file has uncommitted modifications.

File: $PLAN_FILE
Status: $PLAN_GIT_STATUS

This RLCR loop was started with --track-plan-file. Plan file modifications are not allowed during the loop."
        jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - plan file modified (uncommitted)" \
            '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
        exit 0
    fi
fi

# 现在允许计划更改：plan.md 是原始文件的符号链接，因此此差异总是通过
if ! diff -q "$FULL_PLAN_PATH" "$BACKUP_PLAN" &>/dev/null; then
    FALLBACK="# Plan File Modified

The plan file \`$PLAN_FILE\` has been modified since the RLCR loop started.

**Modifying plan files is forbidden during an active RLCR loop.**

If you need to change the plan:
1. Cancel the current loop: \`/humanize:cancel-rlcr-loop\`
2. Update the plan file
3. Start a new loop: \`/humanize:start-rlcr-loop $PLAN_FILE\`

Backup available at: \`$BACKUP_PLAN\`"
    REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/plan-file-modified.md" "$FALLBACK" \
        "PLAN_FILE=$PLAN_FILE" \
        "BACKUP_PATH=$BACKUP_PLAN")
    jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - plan file modified" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

fi  # 计划文件完整性的 REVIEW_STARTED != true 检查结束

# ========================================
# 快速检查：所有任务是否已完成？
# ========================================
# 在运行昂贵的 Codex 审查之前，检查 Claude 是否仍有未完成的任务。
# 如果是，立即阻止并告诉 Claude 完成。
# 支持旧版 TodoWrite 和新版 Task 系统（TaskCreate/TaskUpdate）。

TODO_CHECKER="$SCRIPT_DIR/check-todos-from-transcript.py"

if [[ -f "$TODO_CHECKER" ]]; then
    # 将钩子输入传递给任务检查器
    TODO_RESULT=$(echo "$HOOK_INPUT" | python3 "$TODO_CHECKER" 2>&1) || TODO_EXIT=$?
    TODO_EXIT=${TODO_EXIT:-0}

    if [[ "$TODO_EXIT" -eq 2 ]]; then
        # 解析错误 - 阻止并显示错误
        REASON="Task checker encountered a parse error.

Error: $TODO_RESULT

This may indicate an issue with the hook input or transcript format.
Please try again or cancel the loop if this persists."
        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Blocked - task checker parse error" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi

    if [[ "$TODO_EXIT" -eq 1 ]]; then
        # 发现未完成的任务 - 立即阻止，不进行 Codex 审查
        # 从结果中提取未完成的任务列表
        INCOMPLETE_LIST=$(echo "$TODO_RESULT" | tail -n +2)

        FALLBACK="# Incomplete Tasks

Complete these tasks before exiting:

{{INCOMPLETE_LIST}}"
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/incomplete-todos.md" "$FALLBACK" \
            "INCOMPLETE_LIST=$INCOMPLETE_LIST")

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Blocked - incomplete tasks detected, please finish all tasks first" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi
fi

# ========================================
# 辅助函数：清理过期的 index.lock
# ========================================
# git status（和其他 git 命令）在刷新索引时临时创建 .git/index.lock。
# 如果 git 进程在操作中途被杀死（例如被超时包装器杀死），
# 锁文件可能被遗留，导致后续的 git add/commit 失败：
#   fatal: Unable to create '.git/index.lock': File exists.
# 此辅助函数移除过期的锁，以便 Claude 的提交不会失败。
cleanup_stale_index_lock() {
    # 解析相对于 PROJECT_ROOT 的 git 目录，而不是钩子的 cwd，
    # 这样即使钩子从插件/缓存目录而非项目根目录执行，
    # index.lock 清理也能定位到正确的仓库。
    local project_root="${1:-$PROJECT_ROOT}"
    local git_dir
    git_dir=$(git -C "$project_root" rev-parse --git-dir 2>/dev/null) || return 0
    # git rev-parse --git-dir 可能返回相对路径；将其转换为绝对路径。
    if [[ "$git_dir" != /* ]]; then
        git_dir="$project_root/$git_dir"
    fi
    if [[ -f "$git_dir/index.lock" ]]; then
        echo "Removing stale $git_dir/index.lock" >&2
        rm -f "$git_dir/index.lock"
    fi
}

# ========================================
# 缓存 Git 状态输出
# ========================================
# 缓存 git 状态输出以避免多次调用。
# 供下面的大文件检查和 git 清洁检查使用。
# 重要：在 git 失败时关闭失败以防止绕过检查。

GIT_STATUS_CACHED=""
GIT_IS_REPO=false

if command -v git &>/dev/null && run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null 2>&1; then
    GIT_IS_REPO=true
    # 捕获退出码以检测超时/失败 - 不要使用 || echo ""，那会导致失败开放
    GIT_STATUS_EXIT=0
    GIT_STATUS_CACHED=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null) || GIT_STATUS_EXIT=$?

    if [[ $GIT_STATUS_EXIT -ne 0 ]]; then
        # Git 状态失败或超时 - 通过阻止退出实现关闭失败
        # 超时的 git 状态可能留下了过期的 index.lock
        cleanup_stale_index_lock
        FALLBACK="# Git Status Failed

Git status operation failed or timed out (exit code {{GIT_STATUS_EXIT}}).

Cannot verify repository state. Please check git status manually and try again."
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/git-status-failed.md" "$FALLBACK" \
            "GIT_STATUS_EXIT=$GIT_STATUS_EXIT")
        jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - git status failed (exit $GIT_STATUS_EXIT)" \
            '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
        exit 0
    fi
fi

# ========================================
# 快速检查：大文件检测
# ========================================
# 检查是否有任何已跟踪或新文件超过行数限制。
# 大文件应拆分为更小的模块。

MAX_LINES=2000

if [[ "$GIT_IS_REPO" == "true" ]]; then
    LARGE_FILES=""

    while IFS= read -r line; do
        # 跳过空行
        if [ -z "$line" ]; then
            continue
        fi

        # 提取文件名（跳过前 3 个字符："XY "）
        filename="${line#???}"

        # 处理重命名："old -> new" 格式
        case "$filename" in
            *" -> "*) filename="${filename##* -> }" ;;
        esac

        # 解析相对于 PROJECT_ROOT 的文件名（git status --porcelain
        # 返回项目相对路径，但钩子可能从不同的工作目录运行）。
        filename="$PROJECT_ROOT/$filename"

        # 跳过已删除的文件
        if [ ! -f "$filename" ]; then
            continue
        fi

        # 获取文件扩展名并转换为小写
        ext="${filename##*.}"
        ext_lower=$(to_lower "$ext")

        # 根据扩展名确定文件类型
        case "$ext_lower" in
            py|js|ts|tsx|jsx|java|c|cpp|cc|cxx|h|hpp|cs|go|rs|rb|php|swift|kt|kts|scala|sh|bash|zsh)
                file_type="code"
                ;;
            md|rst|txt|adoc|asciidoc)
                file_type="documentation"
                ;;
            *)
                continue
                ;;
        esac

        # 计算行数并修剪空白（跨 shell 可移植）
        line_count=$(wc -l < "$filename" 2>/dev/null | tr -d ' ') || continue

        # 在比较之前验证 line_count 是数字
        [[ "$line_count" =~ ^[0-9]+$ ]] || continue

        if [ "$line_count" -gt "$MAX_LINES" ]; then
            LARGE_FILES="${LARGE_FILES}
- \`${filename}\`: ${line_count} lines (${file_type} file)"
        fi
    done <<< "$GIT_STATUS_CACHED"

    if [ -n "$LARGE_FILES" ]; then
        FALLBACK="# Large Files Detected

Files exceeding {{MAX_LINES}} lines:

{{LARGE_FILES}}

Split these into smaller modules before continuing."
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/large-files.md" "$FALLBACK" \
            "MAX_LINES=$MAX_LINES" \
            "LARGE_FILES=$LARGE_FILES")

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Blocked - large files detected (>${MAX_LINES} lines), please split into smaller modules" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi
fi

# ========================================
# 方法论分析阶段完成处理器
# ========================================
# 当处于方法论分析阶段时，检查分析是否完成。
# 如果完成，将状态重命名为原始退出原因的终端状态。
# 如果未完成，阻止并要求 Claude 完成分析。
# 跳过所有其他检查（摘要、bitlesson、目标跟踪器、最大迭代次数）。
# 重要：这必须在 git 清洁检查之前运行，因为方法论产物
# （.humanize/rlcr/...）如果 .humanize 被跟踪，可能使工作树看起来脏，
# 这会在到达此处理器之前阻止退出。

if [[ "$IS_METHODOLOGY_ANALYSIS_PHASE" == "true" ]]; then
    if complete_methodology_analysis; then
        # 在允许终端状态转换之前，重新验证工作树是否干净。
        # 主 git 清洁门控在方法论分支中被跳过，因此如果没有此检查，
        # 在分析阶段进行的已跟踪编辑（例如签署后的源代码修改）
        # 可能在完成标记出现时未经审查就溜过去。
        #
        # 应用主门控使用的相同 .humanize/ 未跟踪排除，
        # 以便 .humanize/rlcr/... 下的方法论产物写入不会触发检查。
        if [[ "$GIT_IS_REPO" == "true" ]]; then
            HUMANIZE_UNTRACKED_PATTERN='^\?\? \.humanize[-/]'
            GIT_STATUS_FOR_BLOCK=$(echo "$GIT_STATUS_CACHED" | grep -vE "$HUMANIZE_UNTRACKED_PATTERN" || true)
            if [[ -n "$GIT_STATUS_FOR_BLOCK" ]]; then
                cleanup_stale_index_lock
                FALLBACK="# Git Not Clean

Methodology analysis is complete, but the working tree still has uncommitted changes:

{{GIT_ISSUES}}

Please commit all changes before allowing the loop to exit.
{{SPECIAL_NOTES}}"
                REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/git-not-clean.md" "$FALLBACK" \
                    "GIT_ISSUES=uncommitted changes after methodology analysis" \
                    "SPECIAL_NOTES=")

                jq -n \
                    --arg reason "$REASON" \
                    --arg msg "Loop: Blocked - uncommitted changes detected after methodology analysis, please commit first" \
                    '{
                        "decision": "block",
                        "reason": $reason,
                        "systemMessage": $msg
                    }'
                exit 0
            fi
        fi
        # 分析完成且树干净。现在进行终端重命名，
        # 以便活动状态文件在此清洁门控通过之前保持原位。
        _meth_exit_reason=$(cat "$LOOP_DIR/.methodology-exit-reason" 2>/dev/null | tr -d '[:space:]' || echo "")
        if [[ -n "$_meth_exit_reason" ]]; then
            mv "$LOOP_DIR/methodology-analysis-state.md" "$LOOP_DIR/${_meth_exit_reason}-state.md" 2>/dev/null || true
            rm -f "$LOOP_DIR/.methodology-exit-reason"
            echo "Methodology analysis complete. State preserved as: $LOOP_DIR/${_meth_exit_reason}-state.md" >&2
        fi
        exit 0
    else
        # 分析尚未完成，阻止
        block_methodology_analysis_incomplete
        exit 0
    fi
fi

# ========================================
# 快速检查：Git 是否干净且已推送？
# ========================================
# 在运行昂贵的 Codex 审查之前，检查是否所有更改都已提交并推送。
# 这确保工作被正确保存。

# 使用上面缓存的 git 状态
if [[ "$GIT_IS_REPO" == "true" ]]; then
    GIT_ISSUES=""
    SPECIAL_NOTES=""

    if git_has_tracked_humanize_state "$PROJECT_ROOT"; then
        cleanup_stale_index_lock
        REASON=$(git_tracked_humanize_blocked_message)

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Blocked - tracked Humanize state detected, remove it from git first" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi

    # 使用缓存状态检查未提交的更改（已暂存或未暂存）。
    # 从脏判定中排除未跟踪的 .humanize/ 路径和 .humanize-* 短横线分隔的旧变体，
    # 因为 .humanize/ 下的本地插件状态（.humanize/bitlesson.md、config.json、rlcr/）
    # 是故意不跟踪的。
    HUMANIZE_UNTRACKED_PATTERN='^\?\? \.humanize[-/]'
    GIT_STATUS_FOR_BLOCK=$(echo "$GIT_STATUS_CACHED" | grep -vE "$HUMANIZE_UNTRACKED_PATTERN" || true)
    if [[ -n "$GIT_STATUS_FOR_BLOCK" ]]; then
        GIT_ISSUES="uncommitted changes"

        # 检查未跟踪文件中的特殊情况（使用原始状态作为注释）
        UNTRACKED=$(echo "$GIT_STATUS_CACHED" | grep '^??' || true)

        # 检查 .humanize/ 或 .humanize-* 短横线分隔的旧变体是否未跟踪。
        if echo "$UNTRACKED" | grep -qE "$HUMANIZE_UNTRACKED_PATTERN"; then
            HUMANIZE_LOCAL_NOTE=$(load_template "$TEMPLATE_DIR" "block/git-not-clean-humanize-local.md" 2>/dev/null)
            if [[ -z "$HUMANIZE_LOCAL_NOTE" ]]; then
                HUMANIZE_LOCAL_NOTE="Note: .humanize/ and .humanize-* directories are intentionally untracked."
            fi
            SPECIAL_NOTES="$SPECIAL_NOTES$HUMANIZE_LOCAL_NOTE"
        fi

        # 检查其他未跟踪的文件（潜在的产物）
        OTHER_UNTRACKED=$(echo "$UNTRACKED" | grep -vE "$HUMANIZE_UNTRACKED_PATTERN" || true)
        if [[ -n "$OTHER_UNTRACKED" ]]; then
            UNTRACKED_NOTE=$(load_template "$TEMPLATE_DIR" "block/git-not-clean-untracked.md" 2>/dev/null)
            if [[ -z "$UNTRACKED_NOTE" ]]; then
                UNTRACKED_NOTE="Review untracked files - add to .gitignore or commit them."
            fi
            SPECIAL_NOTES="$SPECIAL_NOTES$UNTRACKED_NOTE"
        fi
    fi

    # 如果有未提交的更改则阻止
    if [[ -n "$GIT_ISSUES" ]]; then
        # 在 Claude 尝试 git add/commit 之前清理过期的 index.lock
        cleanup_stale_index_lock
        # Git 有未提交的更改 - 阻止并提醒 Claude 提交
        FALLBACK="# Git Not Clean

Detected: {{GIT_ISSUES}}

Please commit all changes before exiting.
{{SPECIAL_NOTES}}"
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/git-not-clean.md" "$FALLBACK" \
            "GIT_ISSUES=$GIT_ISSUES" \
            "SPECIAL_NOTES=$SPECIAL_NOTES")

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Blocked - $GIT_ISSUES detected, please commit first" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi

    # ========================================
    # 检查未推送的提交（仅当 push_every_round 为 true 时）
    # ========================================

    if [[ "$PUSH_EVERY_ROUND" == "true" ]]; then
        # 检查本地分支是否领先于远程（未推送的提交）
        GIT_AHEAD=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" status -sb 2>/dev/null | grep -o 'ahead [0-9]*' || true)
        if [[ -n "$GIT_AHEAD" ]]; then
            AHEAD_COUNT=$(echo "$GIT_AHEAD" | grep -o '[0-9]*')
            CURRENT_BRANCH=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

            FALLBACK="# Unpushed Commits

You have {{AHEAD_COUNT}} unpushed commit(s) on branch {{CURRENT_BRANCH}}.

Please push before exiting."
            REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/unpushed-commits.md" "$FALLBACK" \
                "AHEAD_COUNT=$AHEAD_COUNT" \
                "CURRENT_BRANCH=$CURRENT_BRANCH")

            jq -n \
                --arg reason "$REASON" \
                --arg msg "Loop: Blocked - $AHEAD_COUNT unpushed commit(s) detected, please push first" \
                '{
                    "decision": "block",
                    "reason": $reason,
                    "systemMessage": $msg
                }'
            exit 0
        fi
    fi
fi

# ========================================
# 检查摘要文件是否存在
# ========================================

# 在 Finalize 阶段，期望 finalize-summary.md 而不是 round-N-summary.md
if [[ "$IS_FINALIZE_PHASE" == "true" ]]; then
    SUMMARY_FILE="$LOOP_DIR/finalize-summary.md"
    ROUND_CONTRACT_FILE=""
else
    SUMMARY_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-summary.md"
    ROUND_CONTRACT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-contract.md"
fi

if [[ ! -f "$SUMMARY_FILE" ]]; then
    # 摘要文件不存在 - Claude 没有写入它
    # 阻止退出并提醒 Claude 写入摘要

    FALLBACK="# Work Summary Missing

Please write your work summary to: {{SUMMARY_FILE}}"
    REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/work-summary-missing.md" "$FALLBACK" \
        "SUMMARY_FILE=$SUMMARY_FILE")

    if [[ "$IS_FINALIZE_PHASE" == "true" ]]; then
        SYSTEM_MSG="Loop: Finalize Phase - summary file missing"
    else
        SYSTEM_MSG="Loop: Summary file missing for round $CURRENT_ROUND"
    fi

    jq -n \
        --arg reason "$REASON" \
        --arg msg "$SYSTEM_MSG" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
fi

# 检查轮次合同是否存在
# ========================================

# 仅在防漂移活跃时（原始状态中存在 drift_status）强制执行轮次合同。
# 早于防漂移功能的旧循环不会有此字段。
RAW_DRIFT_STATUS=$(echo "$RAW_FRONTMATTER" | grep "^drift_status:" || true)
if [[ "$IS_FINALIZE_PHASE" != "true" ]] && [[ -n "$RAW_DRIFT_STATUS" ]]; then
    if [[ ! -f "$ROUND_CONTRACT_FILE" ]]; then
        FALLBACK="# Round Contract Missing

Before trying to exit, write the current round contract to: {{ROUND_CONTRACT_FILE}}

The round contract must restate:
- The single mainline objective for this round
- The target ACs
- Which side issues are truly blocking
- Which side issues are queued and out of scope
- The success criteria for this round"
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/round-contract-missing.md" "$FALLBACK" \
            "ROUND_CONTRACT_FILE=$ROUND_CONTRACT_FILE")

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Round contract missing for round $CURRENT_ROUND" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi
fi

# ========================================
# 检查 BitLesson Delta 部分（所有非 Finalize 轮次）
# ========================================

if [[ "$IS_FINALIZE_PHASE" != "true" ]] && [[ "$BITLESSON_REQUIRED" == "true" ]]; then
    BITLESSON_DELTA_RESULT=$(bash "$PLUGIN_ROOT/scripts/bitlesson-validate-delta.sh" \
        --summary-file "$SUMMARY_FILE" \
        --bitlesson-file "$BITLESSON_FILE" \
        --bitlesson-relpath "$BITLESSON_FILE_REL" \
        --allow-empty-none "$BITLESSON_ALLOW_EMPTY_NONE" \
        --template-dir "$TEMPLATE_DIR" \
        --current-round "$CURRENT_ROUND") || {
        echo "Error: bitlesson-validate-delta.sh failed" >&2
        exit 1
    }
    if [[ -n "$BITLESSON_DELTA_RESULT" ]]; then
        echo "$BITLESSON_DELTA_RESULT"
        exit 0
    fi
fi

# ========================================
# 检查目标跟踪器初始化（仅第 0 轮，在 Finalize 阶段跳过）
# ========================================

GOAL_TRACKER_FILE="$LOOP_DIR/goal-tracker.md"

# 在 Finalize 阶段、审查阶段或 review_started 已为 true（skip-impl 模式）时跳过此检查
# - Finalize 阶段：目标跟踪器在 COMPLETE 之前已初始化
# - 审查阶段：后续轮次可能仅更新可变部分，因此第 0 轮占位符检查不再适用
if [[ "$IS_FINALIZE_PHASE" != "true" ]] && [[ "$REVIEW_STARTED" != "true" ]] && [[ "$CURRENT_ROUND" -eq 0 ]] && [[ -f "$GOAL_TRACKER_FILE" ]]; then
    # 检查 goal-tracker.md 是否仍包含占位符文本
    # 提取每个部分并检查该部分内的通用占位符模式
    # 这避免了与特定占位符措辞的耦合，并防止文件中其他地方
    # 偶然提及占位符文本导致的误报

    HAS_GOAL_PLACEHOLDER=false
    HAS_AC_PLACEHOLDER=false
    HAS_TASKS_PLACEHOLDER=false

    # 提取 Ultimate Goal 部分（### Ultimate Goal 到下一个标题）
    # 使用 awk 提取开始和结束模式之间的行，不包括结束模式
    GOAL_SECTION=$(awk '/^### Ultimate Goal/{found=1; next} /^##/{found=0} found' "$GOAL_TRACKER_FILE" 2>/dev/null)
    # 检查此部分内的通用占位符模式 "[To be "
    if echo "$GOAL_SECTION" | grep -qE '\[To be [a-z]'; then
        HAS_GOAL_PLACEHOLDER=true
    fi

    # 提取 Acceptance Criteria 部分（### Acceptance Criteria 到下一个标题）
    AC_SECTION=$(awk '/^### Acceptance Criteria/{found=1; next} /^##/{found=0} found' "$GOAL_TRACKER_FILE" 2>/dev/null)
    # 检查此部分内的通用占位符模式 "[To be "
    if echo "$AC_SECTION" | grep -qE '\[To be [a-z]'; then
        HAS_AC_PLACEHOLDER=true
    fi

    # 提取 Active Tasks 部分（#### Active Tasks 到下一个标题或 EOF）
    # Active Tasks 是 4 级标题，因此匹配任何 ## 或更高
    TASKS_SECTION=$(awk '/^#### Active Tasks/{found=1; next} /^##/{found=0} found' "$GOAL_TRACKER_FILE" 2>/dev/null)
    # 检查此部分内的通用占位符模式 "[To be "
    if echo "$TASKS_SECTION" | grep -qE '\[To be [a-z]'; then
        HAS_TASKS_PLACEHOLDER=true
    fi

    # 构建缺失项目列表
    MISSING_ITEMS=""
    if [[ "$HAS_GOAL_PLACEHOLDER" == "true" ]]; then
        MISSING_ITEMS="$MISSING_ITEMS
- **Ultimate Goal**: Still contains placeholder text"
    fi
    if [[ "$HAS_AC_PLACEHOLDER" == "true" ]]; then
        MISSING_ITEMS="$MISSING_ITEMS
- **Acceptance Criteria**: Still contains placeholder text"
    fi
    if [[ "$HAS_TASKS_PLACEHOLDER" == "true" ]]; then
        MISSING_ITEMS="$MISSING_ITEMS
- **Active Tasks**: Still contains placeholder text"
    fi

    if [[ -n "$MISSING_ITEMS" ]]; then
        FALLBACK="# Goal Tracker Not Initialized

Please fill in the Goal Tracker ({{GOAL_TRACKER_FILE}}):
{{MISSING_ITEMS}}"
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/goal-tracker-not-initialized.md" "$FALLBACK" \
            "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
            "MISSING_ITEMS=$MISSING_ITEMS")

        jq -n \
            --arg reason "$REASON" \
            --arg msg "Loop: Goal Tracker not initialized in Round 0" \
            '{
                "decision": "block",
                "reason": $reason,
                "systemMessage": $msg
            }'
        exit 0
    fi
fi

# ========================================
# 检查最大迭代次数（在 Finalize 阶段跳过 - 已在 COMPLETE 之后）
# ========================================

NEXT_ROUND=$((CURRENT_ROUND + 1))

# 在 Finalize 阶段或审查阶段跳过最大迭代次数检查
# - Finalize 阶段：已从 codex 收到 COMPLETE
# - 审查阶段：必须继续直到 [P?] 问题被清除，无论迭代次数如何
if [[ "$IS_FINALIZE_PHASE" != "true" ]] && [[ "$REVIEW_STARTED" != "true" ]] && [[ $NEXT_ROUND -gt $MAX_ITERATIONS ]] && [[ "$STRICT_SUCCESS" != "true" ]]; then
    echo "RLCR 循环未完成，但已达到最大迭代次数（${MAX_ITERATIONS}）。正在退出。" >&2
    # 在最终退出之前尝试进入方法论分析阶段
    if enter_methodology_analysis_phase "maxiter" "Reached max iterations ($MAX_ITERATIONS) without completion"; then
        exit 0
    fi
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_MAXITER"
    exit 0
elif [[ "$IS_FINALIZE_PHASE" != "true" ]] && [[ "$REVIEW_STARTED" != "true" ]] && [[ $NEXT_ROUND -gt $MAX_ITERATIONS ]]; then
    echo "严格成功模式：已达到最大迭代次数（${MAX_ITERATIONS}），但循环将继续直到满足验收标准。" >&2
fi

# ========================================
# Finalize 阶段完成（跳过 Codex 审查）
# ========================================
# 如果我们处于 Finalize 阶段且所有检查都已通过，则完成循环
# 不执行 Codex 审查 - 这是 Codex 已确认 COMPLETE 后的最终步骤

if [[ "$IS_FINALIZE_PHASE" == "true" ]]; then
    echo "Finalize 阶段完成。所有检查已通过。" >&2
    # 在最终退出之前尝试进入方法论分析阶段
    if enter_methodology_analysis_phase "complete" "All acceptance criteria met and code review passed"; then
        exit 0
    fi
    # 方法论分析已跳过或已完成 - 继续正常退出
    mv "$STATE_FILE" "$LOOP_DIR/complete-state.md"
    echo "State preserved as: $LOOP_DIR/complete-state.md" >&2
    exit 0
fi

# ========================================
# 文档路径（静态默认）
# ========================================

DOCS_PATH="docs"

# ========================================
# 构建 Codex 审查提示
# ========================================

PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-prompt.md"
REVIEW_PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-review-prompt.md"
REVIEW_RESULT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-review-result.md"

SUMMARY_CONTENT=$(cat "$SUMMARY_FILE")

# 目标跟踪器更新请求的共享提示部分（在完整对齐和常规审查中使用）
GOAL_TRACKER_SECTION_FALLBACK="## Goal Tracker Updates
If Claude's summary includes a Goal Tracker Update Request section, apply the requested changes to {{GOAL_TRACKER_FILE}}."
GOAL_TRACKER_UPDATE_SECTION=$(load_and_render_safe "$TEMPLATE_DIR" "codex/goal-tracker-update-section.md" "$GOAL_TRACKER_SECTION_FALLBACK" \
    "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE")

# 确定这是否是完整对齐检查轮次（每 FULL_REVIEW_ROUND 轮一次）
# 完整对齐检查发生在轮次 (N-1)、(2N-1)、(3N-1) 等，其中 N=FULL_REVIEW_ROUND
# 验证 FULL_REVIEW_ROUND 是正整数（如果无效/损坏则默认为 5）
if ! [[ "$FULL_REVIEW_ROUND" =~ ^[0-9]+$ ]] || [[ "$FULL_REVIEW_ROUND" -lt 2 ]]; then
    echo "Warning: Invalid full_review_round value '$FULL_REVIEW_ROUND', defaulting to 5" >&2
    FULL_REVIEW_ROUND=5
fi
FULL_ALIGNMENT_CHECK=false
if [[ $((CURRENT_ROUND % FULL_REVIEW_ROUND)) -eq $((FULL_REVIEW_ROUND - 1)) ]]; then
    FULL_ALIGNMENT_CHECK=true
fi

# 计算模板的派生值
LOOP_TIMESTAMP=$(basename "$LOOP_DIR")
COMPLETED_ITERATIONS=$((CURRENT_ROUND + 1))
# 将先前轮次索引限制在最小值 0 以避免负文件引用
# 这可能在 --full-review-round 2 时发生，其中第一次对齐检查在第 1 轮
PREV_ROUND=$(( CURRENT_ROUND > 0 ? CURRENT_ROUND - 1 : 0 ))
PREV_PREV_ROUND=$(( CURRENT_ROUND > 1 ? CURRENT_ROUND - 2 : 0 ))

# 积分组件：累积的提交历史和最近的轮次引用
# 在 git log 中使用 BASE_COMMIT 之前，验证它是 HEAD 的祖先（不仅仅是有效的对象）
if [[ -n "$BASE_COMMIT" ]] && git -C "$PROJECT_ROOT" merge-base --is-ancestor "$BASE_COMMIT" HEAD 2>/dev/null; then
    COMMIT_HISTORY=$(git -C "$PROJECT_ROOT" log --oneline --no-decorate --reverse "$BASE_COMMIT"..HEAD 2>/dev/null | tail -80)
else
    COMMIT_HISTORY=$(git -C "$PROJECT_ROOT" log --oneline --no-decorate --reverse -30 2>/dev/null)
    # 注释以便 Codex 知道这不是完整的循环历史
    [[ -n "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(base commit unavailable, showing recent branch commits)
${COMMIT_HISTORY}"
fi
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

RECENT_ROUND_FILES=""
for (( r = CURRENT_ROUND - 1; r >= 0 && r >= CURRENT_ROUND - 3; r-- )); do
    RECENT_ROUND_FILES+="- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-summary.md
- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-review-result.md
"
done
[[ -z "$RECENT_ROUND_FILES" ]] && RECENT_ROUND_FILES="(first round, no prior history)"

COMMIT_HISTORY_SECTION_FALLBACK="## Development History (Integral Context)
\`\`\`
${COMMIT_HISTORY}
\`\`\`
### Recent Round Files
Read these files before conducting your review to understand the trajectory of work:
${RECENT_ROUND_FILES}"
COMMIT_HISTORY_SECTION=$(load_and_render_safe "$TEMPLATE_DIR" "codex/commit-history-section.md" "$COMMIT_HISTORY_SECTION_FALLBACK" \
    "COMMIT_HISTORY=$COMMIT_HISTORY" \
    "RECENT_ROUND_FILES=$RECENT_ROUND_FILES")

# 构建审查提示
FULL_ALIGNMENT_FALLBACK="# Full Alignment Review (Round {{CURRENT_ROUND}})

Review Claude's work against the plan and goal tracker. Check all goals are being met.

## Claude's Summary
{{SUMMARY_CONTENT}}

{{COMMIT_HISTORY_SECTION}}

{{GOAL_TRACKER_UPDATE_SECTION}}

Write your review to {{REVIEW_RESULT_FILE}}. End with COMPLETE if done, or list issues."

REGULAR_REVIEW_FALLBACK="# Code Review (Round {{CURRENT_ROUND}})

Review Claude's work for this round.

## Claude's Summary
{{SUMMARY_CONTENT}}

{{COMMIT_HISTORY_SECTION}}

{{GOAL_TRACKER_UPDATE_SECTION}}

Write your review to {{REVIEW_RESULT_FILE}}. End with COMPLETE if done, or list issues."

if [[ "$FULL_ALIGNMENT_CHECK" == "true" ]]; then
    # 完整对齐检查提示
    load_and_render_safe "$TEMPLATE_DIR" "codex/full-alignment-review.md" "$FULL_ALIGNMENT_FALLBACK" \
        "CURRENT_ROUND=$CURRENT_ROUND" \
        "PLAN_FILE=$PLAN_FILE" \
        "SUMMARY_CONTENT=$SUMMARY_CONTENT" \
        "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
        "DOCS_PATH=$DOCS_PATH" \
        "GOAL_TRACKER_UPDATE_SECTION=$GOAL_TRACKER_UPDATE_SECTION" \
        "COMMIT_HISTORY_SECTION=$COMMIT_HISTORY_SECTION" \
        "COMPLETED_ITERATIONS=$COMPLETED_ITERATIONS" \
        "LOOP_TIMESTAMP=$LOOP_TIMESTAMP" \
        "PREV_ROUND=$PREV_ROUND" \
        "PREV_PREV_ROUND=$PREV_PREV_ROUND" \
        "REVIEW_RESULT_FILE=$REVIEW_RESULT_FILE" > "$REVIEW_PROMPT_FILE"

else
    # 带有目标对齐部分的常规审查提示
    load_and_render_safe "$TEMPLATE_DIR" "codex/regular-review.md" "$REGULAR_REVIEW_FALLBACK" \
        "CURRENT_ROUND=$CURRENT_ROUND" \
        "PLAN_FILE=$PLAN_FILE" \
        "PROMPT_FILE=$PROMPT_FILE" \
        "SUMMARY_CONTENT=$SUMMARY_CONTENT" \
        "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
        "DOCS_PATH=$DOCS_PATH" \
        "GOAL_TRACKER_UPDATE_SECTION=$GOAL_TRACKER_UPDATE_SECTION" \
        "COMMIT_HISTORY_SECTION=$COMMIT_HISTORY_SECTION" \
        "COMPLETED_ITERATIONS=$COMPLETED_ITERATIONS" \
        "LOOP_TIMESTAMP=$LOOP_TIMESTAMP" \
        "PREV_ROUND=$PREV_ROUND" \
        "PREV_PREV_ROUND=$PREV_PREV_ROUND" \
        "REVIEW_RESULT_FILE=$REVIEW_RESULT_FILE" > "$REVIEW_PROMPT_FILE"
fi

# ========================================
# 共享设置：缓存目录和 Codex 参数
# ========================================
# 在 REVIEW_STARTED 守卫之前初始化这些，以便它们在实现阶段
# （codex exec）和审查阶段（codex review）都可用

# 首先，检查 Codex CLI 是否存在
if ! command -v codex >/dev/null 2>&1; then
    REASON="# Codex CLI Not Found

The 'codex' CLI is not installed or not in PATH.
RLCR loop requires it to perform reviews.

**To fix:**
1. Install Codex CLI: https://github.com/openai/codex
2. Retry the exit

Or use \`/cancel-rlcr-loop\` to end the loop."

    cat <<EOF
{
    "decision": "block",
    "reason": $(echo "$REASON" | jq -Rs .)
}
EOF
    exit 0
fi

# 调试日志文件放在 XDG_CACHE_HOME/humanize/<project-path>/<timestamp>/ 以避免污染项目目录
# 尊重 XDG_CACHE_HOME 以便在受限环境中进行测试（回退到 $HOME/.cache）
# 这防止 Claude 和 Codex 在工作期间读取这些调试文件
# 项目路径被清理以将有问题的字符替换为 '-'
# LOOP_TIMESTAMP 已在上面通过 basename "$LOOP_DIR" 设置
# 清理项目根路径：将 / 和其他有问题的字符替换为 -
# 这匹配 Claude Code 的约定（例如 /home/sihao/github.com/foo -> -home-sihao-github-com-foo）
SANITIZED_PROJECT_PATH=$(echo "$PROJECT_ROOT" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$CACHE_BASE/humanize/$SANITIZED_PROJECT_PATH/$LOOP_TIMESTAMP"
mkdir -p "$CACHE_DIR"

# portable-timeout.sh 已在上面源码引入

# 为嵌套的 Codex 审查器调用禁用原生钩子以防止 Stop-hook 递归。
# 探测已安装的 Codex CLI 是否支持 --disable；缓存每个循环的结果，
# 以便较旧的构建不会因未知参数错误而失败。
CODEX_DISABLE_HOOKS_ARGS=()
_CODEX_FEATURE_CACHE="$CACHE_DIR/.codex-disable-hooks-supported"
if [[ -f "$_CODEX_FEATURE_CACHE" ]]; then
    [[ "$(cat "$_CODEX_FEATURE_CACHE")" == "yes" ]] && CODEX_DISABLE_HOOKS_ARGS=(--disable hooks)
else
    CODEX_HELP_OUTPUT="$(codex --help </dev/null 2>&1 || true)"
    if grep -q -- '--disable' <<< "$CODEX_HELP_OUTPUT"; then
        CODEX_DISABLE_HOOKS_ARGS=(--disable hooks)
        echo "yes" > "$_CODEX_FEATURE_CACHE" 2>/dev/null
    else
        echo "no" > "$_CODEX_FEATURE_CACHE" 2>/dev/null
    fi
fi

# 构建摘要审查的命令参数（codex exec）
CODEX_EXEC_ARGS=("-m" "$CODEX_EXEC_MODEL")
if [[ -n "$CODEX_EXEC_EFFORT" ]]; then
    CODEX_EXEC_ARGS+=("-c" "model_reasoning_effort=${CODEX_EXEC_EFFORT}")
fi

CODEX_AUTO_FLAG="--full-auto"
if [[ "${HUMANIZE_CODEX_BYPASS_SANDBOX:-}" == "true" ]] || [[ "${HUMANIZE_CODEX_BYPASS_SANDBOX:-}" == "1" ]]; then
    CODEX_AUTO_FLAG="--dangerously-bypass-approvals-and-sandbox"
fi
CODEX_EXEC_ARGS+=("$CODEX_AUTO_FLAG" "-C" "$PROJECT_ROOT")

# 构建 codex review 的 Codex 命令参数
CODEX_REVIEW_ARGS=("-c" "model=${CODEX_REVIEW_MODEL}" "-c" "review_model=${CODEX_REVIEW_MODEL}")
if [[ -n "$CODEX_REVIEW_EFFORT" ]]; then
    CODEX_REVIEW_ARGS+=("-c" "model_reasoning_effort=${CODEX_REVIEW_EFFORT}")
fi

# ========================================
# 代码审查阶段的辅助函数
# ========================================

# 运行代码审查并保存调试文件
# 参数：$1=轮次编号
# 设置：CODEX_REVIEW_EXIT_CODE、CODEX_REVIEW_LOG_FILE
# 返回：配置的审查 CLI 的退出码
run_codex_code_review() {
    local round="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # 确定审查基准：优先使用 BASE_COMMIT（在循环开始时捕获）而不是 BASE_BRANCH
    # 使用固定的提交 SHA 可防止在 main 上工作时将分支与自身比较，
    # 因为分支引用随着每次提交而前进，但捕获的 SHA 保持固定
    local review_base="${BASE_COMMIT:-$BASE_BRANCH}"
    local review_base_type="branch"
    if [[ -n "$BASE_COMMIT" ]]; then
        review_base_type="commit"
    fi

    CODEX_REVIEW_CMD_FILE="$CACHE_DIR/round-${round}-codex-review.cmd"
    CODEX_REVIEW_LOG_FILE="$CACHE_DIR/round-${round}-codex-review.log"
    local prompt_file="$LOOP_DIR/round-${round}-review-prompt.md"

    # 创建描述代码审查调用的审计提示文件
    local prompt_fallback="# Code Review Phase - Round ${round}

This file documents the code review invocation for audit purposes.
Compatibility note: Codex 0.130.0 rejects [PROMPT] input, including - stdin, when --base is used.
Humanize must not pass prompt input when --base is used; this file is audit-only.
Provider: codex

## Review Configuration
- Base Branch: ${BASE_BRANCH}
- Base Commit: ${BASE_COMMIT:-N/A}
- Review Base (${review_base_type}): ${review_base}
- Review Round: ${round}
- Timestamp: ${timestamp}
"
    load_and_render_safe "$TEMPLATE_DIR" "codex/code-review-phase.md" "$prompt_fallback" \
        "REVIEW_ROUND=$round" \
        "BASE_BRANCH=$BASE_BRANCH" \
        "BASE_COMMIT=${BASE_COMMIT:-N/A}" \
        "REVIEW_BASE=$review_base" \
        "REVIEW_BASE_TYPE=$review_base_type" \
        "TIMESTAMP=$timestamp" > "$prompt_file"

    echo "Code review prompt (audit) saved to: $prompt_file" >&2

    {
        echo "# Code review invocation debug info"
        echo "# Timestamp: $timestamp"
        echo "# Working directory: $PROJECT_ROOT"
        echo "# Base branch: $BASE_BRANCH"
        echo "# Base commit: ${BASE_COMMIT:-N/A}"
        echo "# Review base ($review_base_type): $review_base"
        echo "# Timeout: $CODEX_TIMEOUT seconds"
        echo ""
        echo "codex review ${CODEX_DISABLE_HOOKS_ARGS[*]+"${CODEX_DISABLE_HOOKS_ARGS[*]}"} --base $review_base ${CODEX_REVIEW_ARGS[*]}"
    } > "$CODEX_REVIEW_CMD_FILE"

    echo "Code review command saved to: $CODEX_REVIEW_CMD_FILE" >&2
    echo "Running codex review with timeout ${CODEX_TIMEOUT}s in $PROJECT_ROOT (base: $review_base)..." >&2

    CODEX_REVIEW_EXIT_CODE=0
    (cd "$PROJECT_ROOT" && run_with_timeout "$CODEX_TIMEOUT" codex review ${CODEX_DISABLE_HOOKS_ARGS[@]+"${CODEX_DISABLE_HOOKS_ARGS[@]}"} --base "$review_base" "${CODEX_REVIEW_ARGS[@]}") \
        > "$CODEX_REVIEW_LOG_FILE" 2>&1 || CODEX_REVIEW_EXIT_CODE=$?

    echo "Code review exit code: $CODEX_REVIEW_EXIT_CODE" >&2
    echo "Code review log saved to: $CODEX_REVIEW_LOG_FILE" >&2

    return "$CODEX_REVIEW_EXIT_CODE"
}

# 注意：detect_review_issues() 定义在 loop-common.sh 中，并在上面源码引入

# 运行代码审查并处理结果
# 参数：$1=轮次编号，$2=成功系统消息
# 此函数整合了以下常见模式：
#   1. 运行 codex review（无提示 - 仅使用 --base）
#   2. 检查结果并处理结果
# 成功时（无问题），调用 enter_finalize_phase 并退出
# 发现问题时，调用 continue_review_loop_with_issues 并退出
# 失败时，调用 block_review_failure 并退出
#
# 轮次编号：在第 N 轮 COMPLETE 之后，所有审查阶段文件使用第 N+1 轮
# 调用者传递 CURRENT_ROUND + 1 作为轮次编号参数
run_and_handle_code_review() {
    local round="$1"
    local success_msg="$2"

    echo "Running codex review against base branch: $BASE_BRANCH..." >&2

    # 使用辅助函数运行 codex review
    # 重要：审查失败是阻塞错误 - 不要跳到 finalize
    if ! run_codex_code_review "$round"; then
        block_review_failure "$round" "Codex review command failed" "$CODEX_REVIEW_EXIT_CODE"
    fi

    # 检查 stdout 和结果文件中的 [P0-9] 问题（计划要求）
    # detect_review_issues 返回：0=发现问题，1=无问题，2=stdout 缺失（硬错误）
    local merged_content=""
    local detect_exit=0
    merged_content=$(detect_review_issues "$round") || detect_exit=$?

    if [[ "$detect_exit" -eq 2 ]]; then
        # stdout 缺失/为空是硬错误 - 阻止并要求重试
        block_review_failure "$round" "Codex review produced no stdout output" "N/A"
    elif [[ "$detect_exit" -eq 0 ]] && [[ -n "$merged_content" ]]; then
        # 发现问题 - 继续审查循环
        continue_review_loop_with_issues "$round" "$merged_content"
    else
        # 未发现问题（退出码 1）- 继续到 finalize
        echo "代码审查通过，没有问题。继续到 finalize 阶段。" >&2
        enter_finalize_phase "" "$success_msg"
    fi
}

# 使用适当的提示进入 finalize 阶段
# 参数：$1=跳过原因（如果未跳过则为空），$2=系统消息
enter_finalize_phase() {
    local skip_reason="$1"
    local system_msg="$2"

    mv "$STATE_FILE" "$LOOP_DIR/finalize-state.md"
    echo "State file renamed to: $LOOP_DIR/finalize-state.md" >&2

    local finalize_summary_file="$LOOP_DIR/finalize-summary.md"
    local finalize_prompt

    if [[ -n "$skip_reason" ]]; then
        local fallback="# Finalize Phase (Review Skipped)

**Warning**: Code review was skipped due to: {{REVIEW_SKIP_REASON}}

The implementation could not be fully validated. You are now in the **Finalize Phase**.

## Important Notice
Since the code review was skipped, please manually verify your changes before finalizing:
1. Review your code changes for any obvious issues
2. Run any available tests to verify correctness
3. Check for common code quality issues

## Simplification (Optional)
If time permits, use the \`code-simplifier:code-simplifier\` agent via the Task tool to simplify and refactor your code. Focus more on changes between branch from {{BASE_BRANCH}} to {{START_BRANCH}}.

## Constraints
- Must NOT change existing functionality
- Must NOT fail existing tests
- Must NOT introduce new bugs
- Only perform functionality-equivalent code refactoring and simplification

## Before Exiting
1. Complete all todos
2. Commit your changes
3. Write your finalize summary to: {{FINALIZE_SUMMARY_FILE}}"

        finalize_prompt=$(load_and_render_safe "$TEMPLATE_DIR" "claude/finalize-phase-skipped-prompt.md" "$fallback" \
            "FINALIZE_SUMMARY_FILE=$finalize_summary_file" \
            "PLAN_FILE=$PLAN_FILE" \
            "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
            "REVIEW_SKIP_REASON=$skip_reason" \
            "BASE_BRANCH=$BASE_BRANCH" \
            "START_BRANCH=$START_BRANCH")
    else
        local fallback="# Finalize Phase

Codex review has passed. The implementation is complete.

You are now in the **Finalize Phase**. Use the \`code-simplifier:code-simplifier\` agent via the Task tool to simplify and refactor your code.

## Constraints
- Must NOT change existing functionality
- Must NOT fail existing tests
- Must NOT introduce new bugs
- Only perform functionality-equivalent code refactoring and simplification

## Focus
Focus on the code changes made during this RLCR session. Focus more on changes between branch from {{BASE_BRANCH}} to {{START_BRANCH}}.

## Before Exiting
1. Complete all todos
2. Commit your changes
3. Write your finalize summary to: {{FINALIZE_SUMMARY_FILE}}"

        finalize_prompt=$(load_and_render_safe "$TEMPLATE_DIR" "claude/finalize-phase-prompt.md" "$fallback" \
            "FINALIZE_SUMMARY_FILE=$finalize_summary_file" \
            "PLAN_FILE=$PLAN_FILE" \
            "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
            "BASE_BRANCH=$BASE_BRANCH" \
            "START_BRANCH=$START_BRANCH")
    fi

    jq -n \
        --arg reason "$finalize_prompt" \
        --arg msg "$system_msg" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

# 向后续提示追加任务标签路由提醒。
# 参数：$1=提示文件路径
append_task_tag_routing_note() {
    local prompt_file="$1"

    cat >> "$prompt_file" << 'ROUTING_EOF'

## Task Tag Routing Reminder

Follow the plan's per-task routing tags strictly:
- `coding` task -> Claude executes directly
- `analyze` task -> execute via `/humanize:ask-codex`, then integrate the result
- Keep Goal Tracker Active Tasks columns `Tag` and `Owner` aligned with execution
ROUTING_EOF
}

# 当主线进度在太多连续轮次中停滞时停止循环。
# 参数：$1=停滞计数，$2=上次裁决
stop_for_mainline_drift() {
    local stall_count="$1"
    local last_verdict="$2"

    upsert_state_fields "$STATE_FILE" \
        "${FIELD_MAINLINE_STALL_COUNT}=${stall_count}" \
        "${FIELD_LAST_MAINLINE_VERDICT}=${last_verdict}" \
        "${FIELD_DRIFT_STATUS}=${DRIFT_STATUS_REPLAN_REQUIRED}"

    local fallback="# Mainline Drift Circuit Breaker

The RLCR loop has been stopped because the mainline failed to advance for {{STALL_COUNT}} consecutive implementation rounds.

- Last mainline verdict: {{LAST_VERDICT}}
- Drift status: replan_required

This loop should not continue automatically. Revisit the original plan, recover the round contract, and restart with a narrower mainline objective."
    local reason
    reason=$(load_and_render_safe "$TEMPLATE_DIR" "block/mainline-drift-stop.md" "$fallback" \
        "STALL_COUNT=$stall_count" \
        "LAST_VERDICT=$last_verdict" \
        "PLAN_FILE=$PLAN_FILE")

    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_STOP"

    jq -n \
        --arg reason "$reason" \
        --arg msg "Loop: Stopped - mainline drift circuit breaker triggered" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

# 当实现审查输出省略必需的主线裁决时阻止退出。
# 参数：$1=审查结果文件，$2=审查提示文件
block_missing_mainline_verdict() {
    local review_result_file="$1"
    local review_prompt_file="$2"

    local fallback="# Mainline Verdict Missing

The implementation review output is missing the required line:

\`Mainline Progress Verdict: ADVANCED / STALLED / REGRESSED\`

Humanize cannot safely update drift state or choose the correct next-round prompt without this verdict.

Retry the exit so Codex reruns the implementation review.

Files:
- Review result: {{REVIEW_RESULT_FILE}}
- Review prompt: {{REVIEW_PROMPT_FILE}}"
    local reason
    reason=$(load_and_render_safe "$TEMPLATE_DIR" "block/mainline-verdict-missing.md" "$fallback" \
        "REVIEW_RESULT_FILE=$review_result_file" \
        "REVIEW_PROMPT_FILE=$review_prompt_file")

    jq -n \
        --arg reason "$reason" \
        --arg msg "Loop: Blocked - implementation review missing Mainline Progress Verdict" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

# 发现问题时继续审查循环
# 参数：$1=轮次编号，$2=审查内容
continue_review_loop_with_issues() {
    local round="$1"
    local review_content="$2"

    echo "Code review found issues. Continuing review loop..." >&2

    # 更新状态文件中的轮次编号
    local temp_file="${STATE_FILE}.tmp.$$"
    sed "s/^current_round: .*/current_round: $round/" "$STATE_FILE" > "$temp_file"
    mv "$temp_file" "$STATE_FILE"

    # 为 Claude 构建审查修复提示
    local next_prompt_file="$LOOP_DIR/round-${round}-prompt.md"
    local next_summary_file="$LOOP_DIR/round-${round}-summary.md"
    if [[ ! -f "$next_summary_file" ]]; then
        cat > "$next_summary_file" << EOF
# Review Round $round Summary

## Work Completed
- [Describe what was implemented in this phase]

## Files Changed
- [List created/modified files]

## Validation
- [List tests/commands run and outcomes]

## Remaining Items
- [List unresolved items, if any]

## BitLesson Delta
- Action: none|add|update
- Lesson ID(s): NONE
- Notes: [what changed and why]
EOF
    fi
    local next_contract_file="$LOOP_DIR/round-${round}-contract.md"

    local fallback="# Code Review Findings

You are in the **Review Phase** of the RLCR loop. Codex has performed a code review and found issues.

## Review Results

{{REVIEW_CONTENT}}

## Instructions

1. Re-anchor on the original plan and current goal tracker before changing code
2. Refresh the round contract at {{ROUND_CONTRACT_FILE}}
3. Address only the issues that are truly blocking the current mainline objective or code-review acceptance
4. Record non-blocking follow-up items as queued, not as the main goal
5. Commit your changes after fixing the issues
6. Write your summary to: {{SUMMARY_FILE}}"

    load_and_render_safe "$TEMPLATE_DIR" "claude/review-phase-prompt.md" "$fallback" \
        "REVIEW_CONTENT=$review_content" \
        "SUMMARY_FILE=$next_summary_file" \
        "BITLESSON_FILE=$BITLESSON_FILE" \
        "PLAN_FILE=$PLAN_FILE" \
        "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
        "ROUND_CONTRACT_FILE=$next_contract_file" \
        "CURRENT_ROUND=$round" > "$next_prompt_file"
    if [[ "$BITLESSON_REQUIRED" == "true" ]] && ! grep -q 'bitlesson-selector' "$next_prompt_file"; then
        cat >> "$next_prompt_file" << EOF

## BitLesson Selection (REQUIRED FOR EACH FIX TASK)

Before implementing each fix task, you MUST:

1. Read @$BITLESSON_FILE
2. Run \`bitlesson-selector\` for each fix task/sub-task to select relevant lesson IDs
3. Follow the selected lesson IDs (or \`NONE\`) during implementation

Reference: @$BITLESSON_FILE
EOF
    fi
    append_task_tag_routing_note "$next_prompt_file"

    jq -n \
        --arg reason "$(cat "$next_prompt_file")" \
        --arg msg "Loop: Review Phase Round $round - Fix code review issues" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

# 当 codex review 失败或未产生输出时阻止退出
# 这是硬错误 - 审查阶段不能被跳过
# 参数：$1=轮次编号，$2=失败原因，$3=退出码（可选）
block_review_failure() {
    local round="$1"
    local failure_reason="$2"
    local exit_code="${3:-unknown}"

    echo "错误：Codex review 失败。阻止退出并要求重试。" >&2

    local stderr_content=""
    local stderr_file="$CACHE_DIR/round-${round}-codex-review.log"
    if [[ -f "$stderr_file" ]]; then
        stderr_content=$(tail -50 "$stderr_file" 2>/dev/null || echo "(unable to read stderr)")
    fi

    local fallback="# Codex Review Failed

The code review could not be completed. This is a blocking error that requires retry.

## Error Details

**Reason**: {{FAILURE_REASON}}
**Round**: {{ROUND_NUMBER}}
**Base Branch**: {{BASE_BRANCH}}
**Exit Code**: {{EXIT_CODE}}

## What Happened

The \`codex review\` command failed to produce valid output. This can occur due to:
- Network connectivity issues
- Codex service timeout or unavailability
- Invalid review configuration
- Internal Codex errors

## Required Action

**You must retry the exit.** The review phase cannot be skipped - the loop must continue until code review passes with no \`[P0-9]\` issues found.

Steps to retry:
1. Ensure your changes are committed
2. Write your summary to the expected file
3. Attempt to exit again

If this error persists, consider canceling and restarting the loop: \`/humanize:cancel-rlcr-loop\`

## Debug Information

Stderr (last 50 lines):
\`\`\`
{{STDERR_CONTENT}}
\`\`\`"

    local reason
    reason=$(load_and_render_safe "$TEMPLATE_DIR" "block/codex-review-failed.md" "$fallback" \
        "FAILURE_REASON=$failure_reason" \
        "ROUND_NUMBER=$round" \
        "BASE_BRANCH=$BASE_BRANCH" \
        "EXIT_CODE=$exit_code" \
        "STDERR_CONTENT=$stderr_content" \
        "REVIEW_RESULT_FILE=$LOOP_DIR/round-${round}-review-result.md" \
        "CODEX_CMD_FILE=$CACHE_DIR/round-${round}-codex-review.cmd" \
        "CODEX_LOG_FILE=$CACHE_DIR/round-${round}-codex-review.log")

    jq -n \
        --arg reason "$reason" \
        --arg msg "Loop: Blocked - Codex review failed, retry required" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

# ========================================
# 运行 Codex 审查（仅实现阶段）
# ========================================
# 在审查阶段跳过摘要审查 - 审查阶段使用 codex review 代替

if [[ "$REVIEW_STARTED" == "true" ]]; then
    echo "在审查阶段 - 跳过 codex exec 摘要审查，将改为运行 codex review..." >&2
    # 直接跳转到下面的审查阶段部分（在 COMPLETE/STOP 处理之后）
else

echo "正在通过 codex 运行第 $CURRENT_ROUND 轮的摘要审查..." >&2

CODEX_CMD_FILE="$CACHE_DIR/round-${CURRENT_ROUND}-codex-run.cmd"
CODEX_STDOUT_FILE="$CACHE_DIR/round-${CURRENT_ROUND}-codex-run.out"
CODEX_STDERR_FILE="$CACHE_DIR/round-${CURRENT_ROUND}-codex-run.log"

# 保存命令用于调试
CODEX_PROMPT_CONTENT=$(cat "$REVIEW_PROMPT_FILE")
{
    echo "# Codex invocation debug info"
    echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Working directory: $PROJECT_ROOT"
    echo "# Timeout: $CODEX_TIMEOUT seconds"
    echo ""
    echo "codex exec ${CODEX_DISABLE_HOOKS_ARGS[*]+"${CODEX_DISABLE_HOOKS_ARGS[*]}"} ${CODEX_EXEC_ARGS[*]} \"<prompt>\""
    echo ""
    echo "# Prompt content:"
    echo "$CODEX_PROMPT_CONTENT"
} > "$CODEX_CMD_FILE"

echo "Codex command saved to: $CODEX_CMD_FILE" >&2
echo "Running summary review with timeout ${CODEX_TIMEOUT}s..." >&2

CODEX_EXIT_CODE=0
printf '%s' "$CODEX_PROMPT_CONTENT" | run_with_timeout "$CODEX_TIMEOUT" codex exec ${CODEX_DISABLE_HOOKS_ARGS[@]+"${CODEX_DISABLE_HOOKS_ARGS[@]}"} "${CODEX_EXEC_ARGS[@]}" - \
    > "$CODEX_STDOUT_FILE" 2> "$CODEX_STDERR_FILE" || CODEX_EXIT_CODE=$?

echo "Codex exit code: $CODEX_EXIT_CODE" >&2
echo "Codex stdout saved to: $CODEX_STDOUT_FILE" >&2
echo "Codex stderr saved to: $CODEX_STDERR_FILE" >&2

# ========================================
# 检查 Codex 执行结果
# ========================================

# 辅助函数：打印 Codex 失败并阻止退出以重试
# 使用 JSON 输出和 exit 0（按照 Claude Code 钩子规范）而不是 exit 2
codex_failure_exit() {
    local error_type="$1"
    local details="$2"

    REASON="# Codex Review Failed

**Error Type:** $error_type

$details

**Debug files:**
- Command: $CODEX_CMD_FILE
- Stdout: $CODEX_STDOUT_FILE
- Stderr: $CODEX_STDERR_FILE

Please retry or use \`/cancel-rlcr-loop\` to end the loop."

    cat <<EOF
{
    "decision": "block",
    "reason": $(echo "$REASON" | jq -Rs .)
}
EOF
    exit 0
}

# 检查 1：Codex 退出码表示失败
if [[ "$CODEX_EXIT_CODE" -ne 0 ]]; then
    STDERR_CONTENT=""
    if [[ -f "$CODEX_STDERR_FILE" ]]; then
        STDERR_CONTENT=$(tail -30 "$CODEX_STDERR_FILE" 2>/dev/null || echo "(unable to read stderr)")
    fi

    codex_failure_exit "Non-zero exit code ($CODEX_EXIT_CODE)" \
"Codex exited with code $CODEX_EXIT_CODE.
This may indicate:
  - Invalid arguments or configuration
  - Authentication failure
  - Network issues
  - Prompt format issues (e.g., multiline handling)

Stderr output (last 30 lines):
$STDERR_CONTENT"
fi

# 检查 Codex 是否创建了审查结果文件（它应该写入工作区）
# 如果没有，检查它是否写入了 stdout
if [[ ! -f "$REVIEW_RESULT_FILE" ]]; then
    # Codex 可能将输出写入了 stdout
    if [[ -s "$CODEX_STDOUT_FILE" ]]; then
        echo "在 stdout 中找到 Codex 输出，正在复制到审查结果文件..." >&2
        if ! cp "$CODEX_STDOUT_FILE" "$REVIEW_RESULT_FILE" 2>/dev/null; then
            codex_failure_exit "Failed to copy stdout to review result file" \
"Codex wrote output to stdout but copying to review file failed.
Source: $CODEX_STDOUT_FILE
Target: $REVIEW_RESULT_FILE

This may indicate permission issues or disk space problems.
Check if the loop directory is writable."
        fi
    fi
fi

# 检查 2：审查结果文件仍不存在
if [[ ! -f "$REVIEW_RESULT_FILE" ]]; then
    STDERR_CONTENT=""
    if [[ -f "$CODEX_STDERR_FILE" ]]; then
        STDERR_CONTENT=$(tail -30 "$CODEX_STDERR_FILE" 2>/dev/null || echo "(no stderr output)")
    fi

    STDOUT_CONTENT=""
    if [[ -f "$CODEX_STDOUT_FILE" ]]; then
        STDOUT_CONTENT=$(tail -30 "$CODEX_STDOUT_FILE" 2>/dev/null || echo "(no stdout output)")
    fi

    codex_failure_exit "Review result file not created" \
"Expected file: $REVIEW_RESULT_FILE
Codex completed (exit code 0) but did not create the review result file.

This may indicate:
  - Codex did not understand the prompt
  - Codex wrote to wrong path
  - Workspace/permission issues

Stdout (last 30 lines):
$STDOUT_CONTENT

Stderr (last 30 lines):
$STDERR_CONTENT"
fi

# 检查 3：审查结果文件为空
if [[ ! -s "$REVIEW_RESULT_FILE" ]]; then
    codex_failure_exit "Review result file is empty" \
"File exists but is empty: $REVIEW_RESULT_FILE
Codex created the file but wrote no content.

This may indicate Codex encountered an internal error."
fi

# 读取审查结果
REVIEW_CONTENT=$(cat "$REVIEW_RESULT_FILE")

# 检查最后一个非空行是否正好是 "COMPLETE" 或 "STOP"
# 该词必须在自己的行上以避免误报，如 "CANNOT COMPLETE"
# 使用严格匹配：仅允许词前后的空白
LAST_LINE=$(echo "$REVIEW_CONTENT" | grep -v '^[[:space:]]*$' | tail -1)
LAST_LINE_TRIMMED=$(echo "$LAST_LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

NEXT_MAINLINE_STALL_COUNT="$MAINLINE_STALL_COUNT"
NEXT_LAST_MAINLINE_VERDICT="$LAST_MAINLINE_VERDICT"
NEXT_DRIFT_STATUS="$DRIFT_STATUS"
DRIFT_REPLAN_REQUIRED=false
MAINLINE_DRIFT_STOP=false

if [[ "$REVIEW_STARTED" != "true" ]]; then
    EXTRACTED_MAINLINE_VERDICT=$(extract_mainline_progress_verdict "$REVIEW_CONTENT")

    if [[ "$LAST_LINE_TRIMMED" != "$MARKER_STOP" ]] && [[ "$EXTRACTED_MAINLINE_VERDICT" == "$MAINLINE_VERDICT_UNKNOWN" ]]; then
        echo "Implementation review output is missing Mainline Progress Verdict. Blocking exit for safety." >&2
        block_missing_mainline_verdict "$REVIEW_RESULT_FILE" "$REVIEW_PROMPT_FILE"
    fi

    case "$EXTRACTED_MAINLINE_VERDICT" in
        "$MAINLINE_VERDICT_ADVANCED")
            NEXT_MAINLINE_STALL_COUNT=0
            NEXT_LAST_MAINLINE_VERDICT="$MAINLINE_VERDICT_ADVANCED"
            NEXT_DRIFT_STATUS="$DRIFT_STATUS_NORMAL"
            ;;
        "$MAINLINE_VERDICT_STALLED"|"$MAINLINE_VERDICT_REGRESSED")
            NEXT_MAINLINE_STALL_COUNT=$((MAINLINE_STALL_COUNT + 1))
            NEXT_LAST_MAINLINE_VERDICT="$EXTRACTED_MAINLINE_VERDICT"
            if [[ "$NEXT_MAINLINE_STALL_COUNT" -ge 2 ]]; then
                NEXT_DRIFT_STATUS="$DRIFT_STATUS_REPLAN_REQUIRED"
                DRIFT_REPLAN_REQUIRED=true
            else
                NEXT_DRIFT_STATUS="$DRIFT_STATUS_NORMAL"
            fi
            if [[ "$NEXT_MAINLINE_STALL_COUNT" -ge 3 ]]; then
                MAINLINE_DRIFT_STOP=true
            fi
            ;;
        *)
            :
            ;;
    esac

    if [[ "$LAST_LINE_TRIMMED" == "$MARKER_COMPLETE" ]]; then
        NEXT_MAINLINE_STALL_COUNT=0
        NEXT_LAST_MAINLINE_VERDICT="$MAINLINE_VERDICT_ADVANCED"
        NEXT_DRIFT_STATUS="$DRIFT_STATUS_NORMAL"
        DRIFT_REPLAN_REQUIRED=false
        MAINLINE_DRIFT_STOP=false
    fi
fi

# 处理 COMPLETE - 进入审查阶段或 Finalize 阶段
if [[ "$LAST_LINE_TRIMMED" == "$MARKER_COMPLETE" ]]; then
    # 在审查阶段，COMPLETE 信号被忽略 - 只有 [P0-9] 的缺失才触发 finalize
    if [[ "$REVIEW_STARTED" == "true" ]]; then
        echo "在审查阶段忽略 COMPLETE 信号。Codex review 决定退出。" >&2
        # 继续到下面的 codex review 逻辑
    else
        # 实现阶段完成 - 过渡到审查阶段
        # 最大迭代次数检查
        if [[ $CURRENT_ROUND -ge $MAX_ITERATIONS && "$STRICT_SUCCESS" != "true" ]]; then
            echo "Codex review 通过但已达到最大迭代次数（${MAX_ITERATIONS}）。以 MAXITER 终止。" >&2
            if enter_methodology_analysis_phase "maxiter" "Codex confirmed COMPLETE but at max iterations ($MAX_ITERATIONS)"; then
                exit 0
            fi
            end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_MAXITER"
            exit 0
        elif [[ $CURRENT_ROUND -ge $MAX_ITERATIONS ]]; then
            echo "严格成功模式：COMPLETE 在最大迭代次数之后到达；继续进入审查/finalize 而不是 maxiter 退出。" >&2
        fi

        # 在任何跳过路径之前初始化跳过跟踪变量
        REVIEW_SKIPPED=""
        REVIEW_SKIP_REASON=""

        # 检查 base_branch 是否可用于代码审查
        if [[ -z "$BASE_BRANCH" ]]; then
            echo "警告：未配置 base_branch，跳过代码审查阶段。" >&2
            REVIEW_SKIPPED="true"
            REVIEW_SKIP_REASON="No base_branch configured for code review"
        else
            echo "实现完成。正在进入审查阶段..." >&2

            # 更新状态以指示审查阶段已开始并清除漂移计数器。
            upsert_state_fields "$STATE_FILE" \
                "${FIELD_REVIEW_STARTED}=true" \
                "${FIELD_MAINLINE_STALL_COUNT}=0" \
                "${FIELD_LAST_MAINLINE_VERDICT}=${MAINLINE_VERDICT_ADVANCED}" \
                "${FIELD_DRIFT_STATUS}=${DRIFT_STATUS_NORMAL}"
            REVIEW_STARTED="true"

            # 创建标记文件以验证审查阶段是否正确进入
            # 同时记录哪一轮构建完成以供监视器显示
            echo "build_finish_round=$CURRENT_ROUND" > "$LOOP_DIR/.review-phase-started"

            # 运行代码审查并处理结果（可能在问题/失败/成功时退出）
            # 传递 CURRENT_ROUND + 1 以便所有审查阶段文件使用下一轮次编号
            echo "实现完成。正在运行初始代码审查..." >&2
            run_and_handle_code_review "$((CURRENT_ROUND + 1))" "Loop: Finalize Phase - Simplify and refactor code before completion"
        fi
    fi
fi

fi  # 实现阶段 codex exec 块结束（当 review_started 为 true 时跳过）

# ========================================
# 审查阶段：运行代码审查（当 review_started 为 true 时）
# ========================================
# 当处于审查阶段时，我们需要在每次退出尝试时运行 codex review
# 循环继续直到在审查输出中未找到 [P0-9] 模式

if [[ "$REVIEW_STARTED" == "true" && -n "$BASE_BRANCH" ]]; then
    # 验证审查阶段是否正确进入（标记文件必须存在）
    # 这防止了有人直接编辑 state.md 的手动切换攻击
    if [[ ! -f "$LOOP_DIR/.review-phase-started" ]]; then
        REASON="Review phase state inconsistency detected.

The state file indicates review_started=true, but no review phase marker exists.
This can happen if the state file was manually edited.

**To fix:**
Reset the state by canceling and restarting the loop.

Use \`/humanize:cancel-rlcr-loop\` to end this loop."
        jq -n --arg reason "$REASON" --arg msg "Loop: Blocked - invalid review phase state" \
            '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
        exit 0
    fi

    echo "审查阶段：正在运行代码审查..." >&2

    # 运行代码审查并处理结果（可能在问题/失败/成功时退出）
    # 传递 CURRENT_ROUND + 1 以便所有审查阶段文件使用下一轮次编号
    run_and_handle_code_review "$((CURRENT_ROUND + 1))" "Loop: Finalize Phase - Code review passed"
fi

if [[ "$MAINLINE_DRIFT_STOP" == "true" ]] && [[ "$STRICT_SUCCESS" == "true" ]] && [[ "$LAST_LINE_TRIMMED" != "$MARKER_COMPLETE" ]]; then
    echo "严格成功模式：主线漂移断路器被抑制；强制恢复/重新计划轮次。" >&2
    MAINLINE_DRIFT_STOP=false
    DRIFT_REPLAN_REQUIRED=true
    NEXT_DRIFT_STATUS="$DRIFT_STATUS_REPLAN_REQUIRED"
    REVIEW_CONTENT="$REVIEW_CONTENT

## Strict Success Mode Override

The reviewer detected repeated mainline drift. Do not stop the loop. Re-anchor on the original acceptance criteria, choose a narrower recovery objective, and continue until the target is actually met."
fi

if [[ "$MAINLINE_DRIFT_STOP" == "true" ]] && [[ "$LAST_LINE_TRIMMED" != "$MARKER_STOP" ]] && [[ "$LAST_LINE_TRIMMED" != "$MARKER_COMPLETE" ]]; then
    echo "主线进度在连续 $NEXT_MAINLINE_STALL_COUNT 轮中停滞。触发漂移断路器。" >&2
    stop_for_mainline_drift "$NEXT_MAINLINE_STALL_COUNT" "$NEXT_LAST_MAINLINE_VERDICT"
fi

# 处理 STOP - 断路器触发
if [[ "$LAST_LINE_TRIMMED" == "$MARKER_STOP" && "$STRICT_SUCCESS" == "true" ]]; then
    echo "严格成功模式：STOP 标记被抑制；强制恢复/重新计划轮次。" >&2
    DRIFT_REPLAN_REQUIRED=true
    NEXT_DRIFT_STATUS="$DRIFT_STATUS_REPLAN_REQUIRED"
    if [[ "$NEXT_MAINLINE_STALL_COUNT" -lt 1 ]]; then
        NEXT_MAINLINE_STALL_COUNT=1
    fi
    NEXT_LAST_MAINLINE_VERDICT="$MAINLINE_VERDICT_STALLED"
    REVIEW_CONTENT="$REVIEW_CONTENT

## Strict Success Mode Override

The reviewer requested STOP, but this loop is configured to stop only after the acceptance target is met. Treat the STOP rationale as recovery input: replan, choose a smaller falsifiable milestone, and continue."
elif [[ "$LAST_LINE_TRIMMED" == "$MARKER_STOP" ]]; then
    echo "" >&2
    echo "========================================" >&2
    if [[ "$FULL_ALIGNMENT_CHECK" == "true" ]]; then
        echo "断路器已触发" >&2
        echo "========================================" >&2
        echo "Codex 在完整对齐检查期间检测到开发停滞（第 $CURRENT_ROUND 轮）。" >&2
        echo "循环已停止以防止进一步的非生产性迭代。" >&2
        echo "" >&2
        echo "查看 .humanize/rlcr/$(basename "$LOOP_DIR")/ 中的历史轮次文件以了解出了什么问题。" >&2
        echo "考虑：" >&2
        echo "  - 重新审视原始计划以获得清晰度" >&2
        echo "  - 将任务分解为更小的部分" >&2
        echo "  - 手动解决阻塞问题" >&2
    else
        echo "意外的断路器" >&2
        echo "========================================" >&2
        echo "Codex 在非对齐轮次（第 $CURRENT_ROUND 轮）期间输出了 STOP。" >&2
        echo "这很不寻常 - STOP 通常只在完整对齐检查期间预期（每 $FULL_REVIEW_ROUND 轮一次）。" >&2
        echo "接受 STOP 请求并终止循环。" >&2
        echo "" >&2
        echo "查看审查结果以了解 Codex 为何请求提前停止：" >&2
        echo "  $REVIEW_RESULT_FILE" >&2
    fi
    echo "========================================" >&2
    # 在最终退出之前尝试进入方法论分析阶段
    if enter_methodology_analysis_phase "stop" "Circuit breaker triggered - stagnation detected at round $CURRENT_ROUND"; then
        exit 0
    fi
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_STOP"
    exit 0
fi

# ========================================
# 审查发现问题 - 继续循环
# ========================================

# 为下一轮更新状态文件
upsert_state_fields "$STATE_FILE" \
    "${FIELD_CURRENT_ROUND}=${NEXT_ROUND}" \
    "${FIELD_MAINLINE_STALL_COUNT}=${NEXT_MAINLINE_STALL_COUNT}" \
    "${FIELD_LAST_MAINLINE_VERDICT}=${NEXT_LAST_MAINLINE_VERDICT}" \
    "${FIELD_DRIFT_STATUS}=${NEXT_DRIFT_STATUS}"

# 创建下一轮提示
NEXT_PROMPT_FILE="$LOOP_DIR/round-${NEXT_ROUND}-prompt.md"
NEXT_SUMMARY_FILE="$LOOP_DIR/round-${NEXT_ROUND}-summary.md"
if [[ ! -f "$NEXT_SUMMARY_FILE" ]]; then
    cat > "$NEXT_SUMMARY_FILE" << EOF
# Round $NEXT_ROUND Summary

## Work Completed
- [Describe what was implemented in this phase]

## Files Changed
- [List created/modified files]

## Validation
- [List tests/commands run and outcomes]

## Remaining Items
- [List unresolved items, if any]

## BitLesson Delta
- Action: none|add|update
- Lesson ID(s): NONE
- Notes: [what changed and why]
EOF
fi
NEXT_CONTRACT_FILE="$LOOP_DIR/round-${NEXT_ROUND}-contract.md"

# 从模板构建下一轮提示
NEXT_ROUND_FALLBACK="# Next Round Instructions

Review the feedback below and address all issues.

Before executing tasks in this round:
1. Read @{{BITLESSON_FILE}}
2. Run \`bitlesson-selector\` for each task/sub-task
3. Follow selected lesson IDs (or \`NONE\`)

## Codex Review
{{REVIEW_CONTENT}}

Reference: {{PLAN_FILE}}, {{GOAL_TRACKER_FILE}}, {{ROUND_CONTRACT_FILE}}, {{BITLESSON_FILE}}"
DRIFT_REPLAN_FALLBACK="# Drift Recovery Required

The mainline has not advanced for {{STALL_COUNT}} consecutive implementation rounds.

Last mainline verdict: {{LAST_MAINLINE_VERDICT}}

Before writing code:
- Re-read @{{PLAN_FILE}}
- Re-read @{{GOAL_TRACKER_FILE}}
- Re-read the recent round summaries and review results
- Rewrite @{{ROUND_CONTRACT_FILE}} with a recovery-focused mainline objective

Do not spend this round clearing queued work. Recover mainline progress first.

## Codex Review
{{REVIEW_CONTENT}}"

if [[ "$DRIFT_REPLAN_REQUIRED" == "true" ]]; then
    load_and_render_safe "$TEMPLATE_DIR" "claude/drift-replan-prompt.md" "$DRIFT_REPLAN_FALLBACK" \
        "PLAN_FILE=$PLAN_FILE" \
        "REVIEW_CONTENT=$REVIEW_CONTENT" \
        "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
        "BITLESSON_FILE=$BITLESSON_FILE" \
        "ROUND_CONTRACT_FILE=$NEXT_CONTRACT_FILE" \
        "CURRENT_ROUND=$NEXT_ROUND" \
        "STALL_COUNT=$NEXT_MAINLINE_STALL_COUNT" \
        "LAST_MAINLINE_VERDICT=$NEXT_LAST_MAINLINE_VERDICT" > "$NEXT_PROMPT_FILE"
else
    load_and_render_safe "$TEMPLATE_DIR" "claude/next-round-prompt.md" "$NEXT_ROUND_FALLBACK" \
        "PLAN_FILE=$PLAN_FILE" \
        "REVIEW_CONTENT=$REVIEW_CONTENT" \
        "GOAL_TRACKER_FILE=$GOAL_TRACKER_FILE" \
        "BITLESSON_FILE=$BITLESSON_FILE" \
        "ROUND_CONTRACT_FILE=$NEXT_CONTRACT_FILE" \
        "CURRENT_ROUND=$NEXT_ROUND" \
        "STALL_COUNT=$NEXT_MAINLINE_STALL_COUNT" \
        "LAST_MAINLINE_VERDICT=$NEXT_LAST_MAINLINE_VERDICT" > "$NEXT_PROMPT_FILE"
fi

if [[ "$DRIFT_REPLAN_REQUIRED" == "true" ]] && [[ "$BITLESSON_REQUIRED" == "true" ]] && ! grep -q 'bitlesson-selector' "$NEXT_PROMPT_FILE"; then
    cat >> "$NEXT_PROMPT_FILE" << EOF

## BitLesson Selection (REQUIRED FOR EACH TASK)

Before executing each task or sub-task, you MUST:

1. Read @$BITLESSON_FILE
2. Run \`bitlesson-selector\` for each task/sub-task to select relevant lesson IDs
3. Follow the selected lesson IDs (or \`NONE\`) during implementation

Reference: @$BITLESSON_FILE
EOF
fi

if [[ "$AGENT_TEAMS" == "true" ]]; then
    ENFORCEMENT_BLOCK="**Delegation Warning**: Do NOT implement code yourself in Agent Teams mode; delegate all coding tasks to team members."

    TEMP_PROMPT_FILE="${NEXT_PROMPT_FILE}.tmp.$$"
    awk -v enforcement="$ENFORCEMENT_BLOCK" '
        BEGIN { injected = 0 }
        !injected && /^## Original Implementation Plan/ {
            print ""
            print enforcement
            print ""
            injected = 1
        }
        { print }
        END {
            if (!injected) {
                print ""
                print enforcement
                print ""
            }
        }
    ' "$NEXT_PROMPT_FILE" > "$TEMP_PROMPT_FILE"
    mv "$TEMP_PROMPT_FILE" "$NEXT_PROMPT_FILE"
fi

# 检查审查内容中的开放问题并在启用时注入通知
# 检测：包含 "Open Question" 子字符串且总长度 < 40 字符的行
if [[ "$ASK_CODEX_QUESTION" == "true" ]]; then
    HAS_OPEN_QUESTION=false
    while IFS= read -r line; do
        if [[ ${#line} -lt 40 ]] && echo "$line" | grep -q "Open Question"; then
            HAS_OPEN_QUESTION=true
            break
        fi
    done < "$REVIEW_RESULT_FILE"

    if [[ "$HAS_OPEN_QUESTION" == "true" ]]; then
        echo "在 Codex 审查中检测到开放问题 - 注入 AskUserQuestion 通知" >&2
        OPEN_QUESTION_NOTICE=$(load_template "$TEMPLATE_DIR" "claude/open-question-notice.md" 2>/dev/null)
        if [[ -z "$OPEN_QUESTION_NOTICE" ]]; then
            OPEN_QUESTION_NOTICE="**IMPORTANT**: Codex has found Open Question(s). You must use \`AskUserQuestion\` to clarify those questions with user first, before proceeding to resolve any other Codex's findings."
        fi
        # 在 "<!-- CODEX's REVIEW RESULT  END  -->" 行 + "---" 行和 "## Goal Tracker Reference" 之间插入通知
        TEMP_PROMPT_FILE="${NEXT_PROMPT_FILE}.tmp.$$"
        awk -v notice="$OPEN_QUESTION_NOTICE" '
            /<!-- CODEX.*REVIEW RESULT.*END.*-->/ {
                print
                getline
                if (/^---/) {
                    print
                    print ""
                    print notice
                    next
                }
            }
            { print }
        ' "$NEXT_PROMPT_FILE" > "$TEMP_PROMPT_FILE"
        mv "$TEMP_PROMPT_FILE" "$NEXT_PROMPT_FILE"
    fi
fi

# 为完整对齐检查后的轮次添加特殊指令
if [[ "$FULL_ALIGNMENT_CHECK" == "true" ]]; then
    POST_ALIGNMENT=$(load_template "$TEMPLATE_DIR" "claude/post-alignment-action-items.md" 2>/dev/null)
    if [[ -n "$POST_ALIGNMENT" ]]; then
        echo "$POST_ALIGNMENT" >> "$NEXT_PROMPT_FILE"
    fi
fi

# 添加包含提交/摘要指令的页脚
FOOTER_FALLBACK="## Before Exiting
Commit your changes and write summary to {{NEXT_SUMMARY_FILE}}"
load_and_render_safe "$TEMPLATE_DIR" "claude/next-round-footer.md" "$FOOTER_FALLBACK" \
    "NEXT_SUMMARY_FILE=$NEXT_SUMMARY_FILE" >> "$NEXT_PROMPT_FILE"
append_task_tag_routing_note "$NEXT_PROMPT_FILE"

# 仅在 push_every_round 为 true 时添加推送指令
if [[ "$PUSH_EVERY_ROUND" == "true" ]]; then
    PUSH_NOTE=$(load_template "$TEMPLATE_DIR" "claude/push-every-round-note.md" 2>/dev/null)
    if [[ -z "$PUSH_NOTE" ]]; then
        PUSH_NOTE="Also push your changes after committing."
    fi
    echo "$PUSH_NOTE" >> "$NEXT_PROMPT_FILE"
fi

# 添加目标跟踪器更新请求模板
GOAL_UPDATE_REQUEST=$(load_template "$TEMPLATE_DIR" "claude/goal-tracker-update-request.md" 2>/dev/null)
if [[ -z "$GOAL_UPDATE_REQUEST" ]]; then
    GOAL_UPDATE_REQUEST="Include a Goal Tracker Update Request section in your summary if needed."
fi
echo "$GOAL_UPDATE_REQUEST" >> "$NEXT_PROMPT_FILE"

# 添加 agent-teams 续接指令（仅在实现阶段，不在审查阶段）
# 加载续接标题和共享核心模板以获得完整的团队领导指导
if [[ "$AGENT_TEAMS" == "true" ]] && [[ "$REVIEW_STARTED" != "true" ]]; then
    AGENT_TEAMS_CONTINUE=$(load_template "$TEMPLATE_DIR" "claude/agent-teams-continue.md" 2>/dev/null)
    AGENT_TEAMS_CORE=$(load_template "$TEMPLATE_DIR" "claude/agent-teams-core.md" 2>/dev/null)
    if [[ -n "$AGENT_TEAMS_CONTINUE" ]] && [[ -n "$AGENT_TEAMS_CORE" ]]; then
        echo "" >> "$NEXT_PROMPT_FILE"
        echo "$AGENT_TEAMS_CONTINUE" >> "$NEXT_PROMPT_FILE"
        echo "" >> "$NEXT_PROMPT_FILE"
        echo "$AGENT_TEAMS_CORE" >> "$NEXT_PROMPT_FILE"
    else
        cat >> "$NEXT_PROMPT_FILE" << 'AGENT_TEAMS_FALLBACK_EOF'

## Agent Teams Continuation

Continue using **Agent Teams mode** as the **Team Leader**.
Split remaining work among team members and coordinate their efforts.
Do NOT do implementation work yourself - delegate all coding to team members.
AGENT_TEAMS_FALLBACK_EOF
    fi
fi

# 构建系统消息
SYSTEM_MSG="Loop: Round $NEXT_ROUND/$MAX_ITERATIONS - Codex found issues to address"
if [[ "$DRIFT_REPLAN_REQUIRED" == "true" ]]; then
    SYSTEM_MSG="Loop: Round $NEXT_ROUND/$MAX_ITERATIONS - Mainline drift detected, replan required"
fi

# 阻止退出并发送审查反馈
jq -n \
    --arg reason "$(cat "$NEXT_PROMPT_FILE")" \
    --arg msg "$SYSTEM_MSG" \
    '{
        "decision": "block",
        "reason": $reason,
        "systemMessage": $msg
    }'

exit 0
