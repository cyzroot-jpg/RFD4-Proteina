#!/usr/bin/env bash
#
# PreToolUse 钩子：验证 RLCR 循环的 Edit 路径
#
# 阻止 Claude 编辑：
# - Todos 文件（应使用原生 Task 工具代替）
# - 提示文件（只读，由 Codex 生成）
# - 状态文件（由钩子管理，不是 Claude）
# - 错误轮次编号的合同文件
# - 活跃循环之外的目标跟踪器编辑或更改不可变部分的编辑
#

set -euo pipefail

# 加载共享函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/loop-common.sh"

# ========================================
# 解析钩子输入
# ========================================

HOOK_INPUT=$(read_hook_input)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""')

if [[ "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""')
FILE_PATH_LOWER=$(to_lower "$FILE_PATH")

# 从钩子输入中提取 session_id 用于会话感知的循环过滤
HOOK_SESSION_ID=$(extract_session_id "$HOOK_INPUT")

# ========================================
# 阻止 Todos 和提示文件
# ========================================

if is_round_file_type "$FILE_PATH_LOWER" "todos"; then
    PROJECT_ROOT="$(resolve_project_root)" || exit 0
    LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"
    LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")
    if [[ -z "$LOOP_DIR" ]] || ! is_allowlisted_file "$FILE_PATH" "$LOOP_DIR"; then
        todos_blocked_message "Edit" >&2
        exit 2
    fi
fi

if is_round_file_type "$FILE_PATH_LOWER" "prompt"; then
    prompt_write_blocked_message >&2
    exit 2
fi

# ========================================
# 方法论分析阶段编辑限制
# ========================================
# 在方法论分析期间，只能编辑方法论产物。
# 这防止了 Codex 签署后对源代码的修改。
# 此检查必须在下面的 humanize 循环目录早期退出之前进行。

PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root 2>/dev/null || true)}"
[[ -z "$PROJECT_ROOT" ]] && exit 0
LOOP_BASE_DIR="${LOOP_BASE_DIR:-$PROJECT_ROOT/.humanize/rlcr}"
# 仅使用会话匹配的循环。不要回退到未过滤的搜索，
# 因为这会错误地限制在同一仓库中打开的无关会话。
# 限制：生成的代理（不同的 session_id）不受钩子限制；
# 它们的清理由分析提示词强制执行。
_MA_LOOP_DIR="${LOOP_DIR:-$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")}"

if [[ -n "$_MA_LOOP_DIR" ]] && [[ -f "$_MA_LOOP_DIR/methodology-analysis-state.md" ]]; then
    # 如果 realpath 失败（文件在 BSD/macOS 上尚不存在），解析父目录
    _ma_real_path=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
    if [[ -z "$_ma_real_path" ]]; then
        _ma_parent=$(realpath "$(dirname "$FILE_PATH")" 2>/dev/null || echo "")
        [[ -n "$_ma_parent" ]] && _ma_real_path="$_ma_parent/$(basename "$FILE_PATH")"
    fi
    _ma_real_loop=$(realpath "$_MA_LOOP_DIR" 2>/dev/null || echo "")
    # 当 realpath 不可用时回退到原始路径（较旧的 macOS/BSD）
    # 确保路径是绝对路径并拒绝 ".." 以防止遍历绕过。
    if [[ -z "$_ma_real_path" ]]; then
        if [[ "$FILE_PATH" == *".."* ]]; then
            echo "# Edit Blocked During Methodology Analysis

Path contains traversal segments that cannot be resolved without realpath." >&2
            exit 2
        fi
        # 如果叶子是我们无法解析的符号链接，则关闭失败；
        # 原始路径会满足循环目录前缀检查，同时指向循环外的目标，
        # 让 basename 允许列表在方法论分析模式期间批准对任意文件的编辑。
        if [[ -L "$FILE_PATH" ]]; then
            echo "# Edit Blocked During Methodology Analysis

Path is a symlink that cannot be resolved without realpath." >&2
            exit 2
        fi
        if [[ "$FILE_PATH" == /* ]]; then
            _ma_real_path="$FILE_PATH"
        else
            _ma_real_path="$PROJECT_ROOT/$FILE_PATH"
        fi
    fi
    if [[ -z "$_ma_real_loop" ]]; then
        if [[ "$_MA_LOOP_DIR" == /* ]]; then
            _ma_real_loop="$_MA_LOOP_DIR"
        else
            _ma_real_loop="$PROJECT_ROOT/$_MA_LOOP_DIR"
        fi
    fi
    if [[ "$_ma_real_path" == "$_ma_real_loop/"* ]]; then
        _ma_basename=$(basename "$_ma_real_path")
        case "$_ma_basename" in
            methodology-analysis-report.md|methodology-analysis-done.md)
                exit 0
                ;;
        esac
    fi
    echo "# Edit Blocked During Methodology Analysis

During the methodology analysis phase, only methodology artifacts can be edited.
Allowed: methodology-analysis-report.md, methodology-analysis-done.md" >&2
    exit 2
fi

# ========================================
# 检查文件是否在 .humanize/rlcr 中
# ========================================

if ! is_in_humanize_loop_dir "$FILE_PATH"; then
    exit 0
fi

# ========================================
# 查找活跃循环和当前轮次
# ========================================

PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root 2>/dev/null || true)}"
[[ -z "$PROJECT_ROOT" ]] && exit 0
LOOP_BASE_DIR="${LOOP_BASE_DIR:-$PROJECT_ROOT/.humanize/rlcr}"
ACTIVE_LOOP_DIR="${LOOP_DIR:-$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")}"

if [[ -z "$ACTIVE_LOOP_DIR" ]]; then
    exit 0
fi

# 检测是否处于 Finalize 阶段（finalize-state.md 存在）
STATE_FILE_TO_PARSE=$(resolve_active_state_file "$ACTIVE_LOOP_DIR")
IS_FINALIZE_PHASE=false
if [[ "$STATE_FILE_TO_PARSE" == *"/finalize-state.md" ]]; then
    IS_FINALIZE_PHASE=true
fi

# 使用严格验证解析状态文件（格式错误时关闭失败）
if ! parse_state_file_strict "$STATE_FILE_TO_PARSE" 2>/dev/null; then
    echo "Error: Malformed state file, blocking operation for safety" >&2
    exit 1
fi
CURRENT_ROUND="$STATE_CURRENT_ROUND"

# ========================================
# 阻止状态文件编辑（state.md、finalize-state.md、methodology-analysis-state.md）
# ========================================
# 注意：首先检查最具体的模式，因为 is_state_file_path 匹配任何 *state.md

if is_methodology_analysis_state_file_path "$FILE_PATH_LOWER"; then
    methodology_analysis_state_file_blocked_message >&2
    exit 2
fi

if is_finalize_state_file_path "$FILE_PATH_LOWER"; then
    finalize_state_file_blocked_message >&2
    exit 2
fi

if is_state_file_path "$FILE_PATH_LOWER"; then
    state_file_blocked_message >&2
    exit 2
fi

if [[ "$IS_FINALIZE_PHASE" == "true" ]] && is_round_file_type "$FILE_PATH_LOWER" "contract"; then
    finalize_contract_blocked_message "edit" >&2
    exit 2
fi

# ========================================
# 阻止计划备份编辑
# ========================================

FILENAME=$(basename "$FILE_PATH")
if [[ "$FILENAME" == "plan.md" ]]; then
    if [[ "$FILE_PATH" == *"/.humanize/rlcr/"* ]]; then
        FALLBACK="Editing plan.md backup is not allowed during RLCR loop."
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/plan-backup-protected.md" "$FALLBACK")
        echo "$REASON" >&2
        exit 2
    fi
fi

# ========================================
# 验证目标跟踪器编辑
# ========================================

if is_goal_tracker_path "$FILE_PATH_LOWER"; then
    GOAL_TRACKER_PATH="$ACTIVE_LOOP_DIR/goal-tracker.md"
    # 使用 canonicalize_path 解析符号链接（例如 /var -> /private/var 在 macOS 上）
    NORMALIZED_FILE_PATH=$(canonicalize_path "$FILE_PATH" 2>/dev/null || _normalize_path "$FILE_PATH")
    NORMALIZED_GOAL_TRACKER_PATH=$(canonicalize_path "$GOAL_TRACKER_PATH" 2>/dev/null || _normalize_path "$GOAL_TRACKER_PATH")

    if [[ "$NORMALIZED_FILE_PATH" != "$NORMALIZED_GOAL_TRACKER_PATH" ]]; then
        goal_tracker_blocked_message "$CURRENT_ROUND" "$GOAL_TRACKER_PATH" >&2
        exit 2
    fi

    if [[ "$CURRENT_ROUND" -gt 0 ]]; then
        if ! echo "$HOOK_INPUT" | jq -e '.tool_input | has("old_string") and has("new_string")' >/dev/null 2>&1; then
            echo "Error: Missing required field: tool_input.old_string or tool_input.new_string" >&2
            exit 1
        fi
        OLD_STRING=$(echo "$HOOK_INPUT" | jq -r '.tool_input.old_string // ""')
        if [[ -z "$OLD_STRING" ]]; then
            echo "Error: Missing required field: tool_input.old_string" >&2
            exit 1
        fi

        NEW_STRING=$(echo "$HOOK_INPUT" | jq -r '.tool_input.new_string // ""')
        REPLACE_ALL=$(echo "$HOOK_INPUT" | jq -r '.tool_input.replace_all // false')

        if ! UPDATED_CONTENT=$(preview_edit_result "$GOAL_TRACKER_PATH" "$OLD_STRING" "$NEW_STRING" "$REPLACE_ALL" 2>/dev/null); then
            goal_tracker_blocked_message "$CURRENT_ROUND" "$GOAL_TRACKER_PATH" >&2
            exit 2
        fi

        if ! goal_tracker_mutable_update_allowed "$GOAL_TRACKER_PATH" "$UPDATED_CONTENT"; then
            goal_tracker_blocked_message "$CURRENT_ROUND" "$GOAL_TRACKER_PATH" >&2
            exit 2
        fi
    fi

    exit 0
fi

# ========================================
# 验证摘要/合同文件轮次编号
# ========================================

if is_round_file_type "$FILE_PATH_LOWER" "summary" || is_round_file_type "$FILE_PATH_LOWER" "contract"; then
    # 从路径中提取文件名（可移植 - 在 bash 和 zsh 中工作）
    CLAUDE_FILENAME=$(echo "$FILE_PATH" | sed -n 's|.*\.humanize/rlcr/[^/]*/\(.*\)$|\1|p')
    if [[ -z "$CLAUDE_FILENAME" ]]; then
        CLAUDE_FILENAME=$(echo "$FILE_PATH" | sed -n 's|.*\.humanize/rlcr/\(.*\)$|\1|p')
    fi

    if [[ -n "$CLAUDE_FILENAME" ]]; then
        CLAUDE_ROUND=$(extract_round_number "$CLAUDE_FILENAME")
        FILE_TYPE=$([[ "$FILE_PATH_LOWER" == *"-contract.md" ]] && echo "contract" || echo "summary")

        if [[ -n "$CLAUDE_ROUND" ]] && [[ "$CLAUDE_ROUND" != "$CURRENT_ROUND" ]] && ! is_allowlisted_file "$FILE_PATH" "$ACTIVE_LOOP_DIR"; then
            CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-${FILE_TYPE}.md"
            FALLBACK="# Wrong Round Number

You tried to {{ACTION}} round-{{CLAUDE_ROUND}}-{{FILE_TYPE}}.md but current round is **{{CURRENT_ROUND}}**.

Edit: {{CORRECT_PATH}}"
            load_and_render_safe "$TEMPLATE_DIR" "block/wrong-round-number.md" "$FALLBACK" \
                "ACTION=edit" \
                "CLAUDE_ROUND=$CLAUDE_ROUND" \
                "FILE_TYPE=$FILE_TYPE" \
                "CURRENT_ROUND=$CURRENT_ROUND" \
                "CORRECT_PATH=$CORRECT_PATH" >&2
            exit 2
        fi
    fi
fi

exit 0
