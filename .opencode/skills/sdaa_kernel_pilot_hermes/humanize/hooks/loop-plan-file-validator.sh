#!/usr/bin/env bash
#
# RLCR 循环期间计划文件验证的 UserPromptSubmit 钩子
#
# 验证：
# - 状态模式版本（需要 plan_tracked、start_branch 字段）
# - 分支一致性（循环期间不允许切换）
# - 计划文件跟踪状态一致性
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 源码引入共享循环函数和模板加载器
source "$SCRIPT_DIR/lib/loop-common.sh"

PROJECT_ROOT="$(resolve_project_root)" || exit 0

# 源码引入可移植的 git 操作超时包装器
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/scripts/portable-timeout.sh"

# git 操作的默认超时（30 秒）
GIT_TIMEOUT=30

# 读取钩子输入（UserPromptSubmit 钩子需要）
INPUT=$(read_hook_input)

# 从钩子输入中提取 session_id 用于会话感知的循环过滤
HOOK_SESSION_ID=$(extract_session_id "$INPUT")

# 使用共享函数查找活跃循环（按 session_id 过滤）
LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"
LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")

# 如果没有活跃循环，允许退出
if [[ -z "$LOOP_DIR" ]]; then
    exit 0
fi

# 检测是否处于 Finalize 阶段（finalize-state.md 存在）
STATE_FILE=$(resolve_active_state_file "$LOOP_DIR")

# 使用严格验证解析状态文件（格式错误时关闭失败）
if ! parse_state_file_strict "$STATE_FILE" 2>/dev/null; then
    echo "Error: Malformed state file, blocking operation for safety" >&2
    exit 1
fi

# 将 STATE_* 变量映射到本地名称以保持向后兼容性
PLAN_TRACKED="$STATE_PLAN_TRACKED"
PLAN_FILE="$STATE_PLAN_FILE"
START_BRANCH="$STATE_START_BRANCH"

# ========================================
# 模式验证（v1.1.2+ 必需字段）
# ========================================

# 输出模式验证错误的辅助函数
schema_validation_error() {
    local field_name="$1"
    local fallback="RLCR loop state file is missing required field: \`${field_name}\`\n\nThis indicates the loop was started with an older version of humanize.\n\n**Options:**\n1. Cancel the loop: \`/humanize:cancel-rlcr-loop\`\n2. Update humanize plugin to version 1.1.2+\n3. Restart the RLCR loop with the updated plugin"

    local reason
    reason=$(load_and_render_safe "$TEMPLATE_DIR" "block/schema-outdated.md" "$fallback" "FIELD_NAME=$field_name")

    # 为 JSON 转义换行符
    local escaped_reason
    escaped_reason=$(echo "$reason" | jq -Rs '.')

    cat << EOF
{
  "decision": "block",
  "reason": $escaped_reason
}
EOF
}

# 检查必需字段（使用 loop-common.sh 中的 FIELD_* 常量）
REQUIRED_FIELDS=("${FIELD_PLAN_TRACKED}:$PLAN_TRACKED" "${FIELD_START_BRANCH}:$START_BRANCH")
for field_entry in "${REQUIRED_FIELDS[@]}"; do
    field_name="${field_entry%%:*}"
    field_value="${field_entry#*:}"

    if [[ -z "$field_value" ]]; then
        schema_validation_error "$field_name"
        exit 0
    fi
done

# ========================================
# 分支一致性检查
# ========================================

# 使用 || GIT_EXIT_CODE=$? 防止 set -e 在非零退出时中止
CURRENT_BRANCH=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null) || GIT_EXIT_CODE=$?
GIT_EXIT_CODE=${GIT_EXIT_CODE:-0}
if [[ $GIT_EXIT_CODE -ne 0 || -z "$CURRENT_BRANCH" ]]; then
    cat << EOF
{
  "decision": "block",
  "reason": "Git operation failed or timed out.\\n\\nCannot verify branch consistency. Please check git status and try again."
}
EOF
    exit 0
fi
if [[ -n "$START_BRANCH" && "$CURRENT_BRANCH" != "$START_BRANCH" ]]; then
    cat << EOF
{
  "decision": "block",
  "reason": "Git branch has changed during RLCR loop.\\n\\nStarted on: $START_BRANCH\\nCurrent: $CURRENT_BRANCH\\n\\nBranch switching is not allowed during an active RLCR loop. Please switch back to the original branch or cancel the loop with /humanize:cancel-rlcr-loop"
}
EOF
    exit 0
fi

# ========================================
# 计划文件跟踪状态检查
# ========================================

FULL_PLAN_PATH="$PROJECT_ROOT/$PLAN_FILE"

if [[ "$PLAN_TRACKED" == "true" ]]; then
    # 必须被跟踪且干净
    # 使用 || LS_FILES_EXIT=$? 防止 set -e 在非零退出时中止
    # ls-files --error-unmatch 返回：0（已跟踪），1（未跟踪），124（超时），其他（错误）
    run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" ls-files --error-unmatch "$PLAN_FILE" &>/dev/null || LS_FILES_EXIT=$?
    LS_FILES_EXIT=${LS_FILES_EXIT:-0}
    if [[ $LS_FILES_EXIT -eq 124 ]]; then
        # 超时 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation timed out while checking plan file tracking status.\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    elif [[ $LS_FILES_EXIT -ne 0 && $LS_FILES_EXIT -ne 1 ]]; then
        # 意外的 git 错误 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation failed while checking plan file tracking status (exit code: $LS_FILES_EXIT).\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    fi
    PLAN_IS_TRACKED=$([[ $LS_FILES_EXIT -eq 0 ]] && echo "true" || echo "false")

    # 使用 || STATUS_EXIT=$? 防止 set -e 在非零退出时中止
    # git status --porcelain 返回：0（成功），124（超时），其他（错误）
    PLAN_GIT_STATUS=$(run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" status --porcelain "$PLAN_FILE" 2>/dev/null) || STATUS_EXIT=$?
    STATUS_EXIT=${STATUS_EXIT:-0}
    if [[ $STATUS_EXIT -eq 124 ]]; then
        # 超时 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation timed out while checking plan file status.\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    elif [[ $STATUS_EXIT -ne 0 ]]; then
        # 意外的 git 错误 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation failed while checking plan file status (exit code: $STATUS_EXIT).\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    fi

    if [[ "$PLAN_IS_TRACKED" != "true" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Plan file is no longer tracked in git.\\n\\nFile: $PLAN_FILE\\n\\nThis RLCR loop was started with --track-plan-file, but the plan file has been removed from git tracking."
}
EOF
        exit 0
    fi

    if [[ -n "$PLAN_GIT_STATUS" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Plan file has uncommitted modifications.\\n\\nFile: $PLAN_FILE\\nStatus: $PLAN_GIT_STATUS\\n\\nThis RLCR loop was started with --track-plan-file. Plan file modifications are not allowed during the loop."
}
EOF
        exit 0
    fi
else
    # 必须被 gitignore（未跟踪）
    # 检查 git 命令是否成功 - 超时/错误时关闭失败
    # ls-files --error-unmatch 返回：0（已跟踪），1（未跟踪），124（超时），其他（错误）
    run_with_timeout "$GIT_TIMEOUT" git -C "$PROJECT_ROOT" ls-files --error-unmatch "$PLAN_FILE" &>/dev/null || LS_FILES_EXIT=$?
    LS_FILES_EXIT=${LS_FILES_EXIT:-0}
    if [[ $LS_FILES_EXIT -eq 124 ]]; then
        # 超时 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation timed out while checking plan file tracking status.\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    elif [[ $LS_FILES_EXIT -ne 0 && $LS_FILES_EXIT -ne 1 ]]; then
        # 意外的 git 错误 - 关闭失败
        cat << EOF
{
  "decision": "block",
  "reason": "Git operation failed while checking plan file tracking status (exit code: $LS_FILES_EXIT).\\n\\nPlease check git status and try again."
}
EOF
        exit 0
    fi
    PLAN_IS_TRACKED=$([[ $LS_FILES_EXIT -eq 0 ]] && echo "true" || echo "false")

    if [[ "$PLAN_IS_TRACKED" == "true" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Plan file is now tracked in git but loop was started without --track-plan-file.\\n\\nFile: $PLAN_FILE\\n\\nThe plan file must remain gitignored during this RLCR loop."
}
EOF
        exit 0
    fi
fi

exit 0
