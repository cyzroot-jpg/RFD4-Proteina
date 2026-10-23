#!/usr/bin/env bash
#
# PreToolUse 钩子：验证 RLCR 循环的 Write 路径
#
# 阻止 Claude 写入：
# - Todos 文件（应使用原生 Task 工具代替）
# - 提示文件（只读，由 Codex 生成）
# - 错误轮次编号的摘要文件
# - 错误轮次编号的合同文件
# - .humanize/rlcr/ 外的摘要文件
# - 活跃循环外的目标跟踪器写入或更改不可变部分的写入
#

set -euo pipefail

# 加载共享函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/loop-common.sh"

# ========================================
# 解析钩子输入
# ========================================

HOOK_INPUT=$(read_hook_input)

# 验证 JSON 输入结构
if ! validate_hook_input "$HOOK_INPUT"; then
    exit 1
fi

# 检查深度嵌套的 JSON（潜在的 DoS 攻击）
if is_deeply_nested "$HOOK_INPUT" 30; then
    exit 1
fi

TOOL_NAME="$VALIDATED_TOOL_NAME"

if [[ "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# Write 工具需要 file_path 参数；缺失说明事件载荷异常，无可校验内容，放行不报错
if ! require_tool_input_field "$HOOK_INPUT" "file_path" 2>/dev/null; then
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
        todos_blocked_message "Write" >&2
        exit 2
    fi
fi

if is_round_file_type "$FILE_PATH_LOWER" "prompt"; then
    prompt_write_blocked_message >&2
    exit 2
fi

# ========================================
# 方法论分析阶段写入限制
# ========================================
# 在方法论分析期间，只能写入方法论产物。
# 这防止了 Codex 签署后对源代码的修改。
# 此检查必须在下面的文件类型早期退出之前进行。

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
    # 确保路径是绝对路径，以便前缀守卫不能被绕过。
    # 拒绝包含 ".." 段的路径以防止在无法规范化时的遍历绕过（关闭失败）。
    if [[ -z "$_ma_real_path" ]]; then
        if [[ "$FILE_PATH" == *".."* ]]; then
            echo "# Write Blocked During Methodology Analysis

Path contains traversal segments that cannot be resolved without realpath." >&2
            exit 2
        fi
        # 如果叶子是我们无法解析的符号链接，则关闭失败；
        # 原始路径会满足循环目录前缀检查，同时指向循环外的目标，
        # 让 basename 允许列表在方法论分析模式期间批准对任意文件的写入。
        if [[ -L "$FILE_PATH" ]]; then
            echo "# Write Blocked During Methodology Analysis

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
    echo "# Write Blocked During Methodology Analysis

During the methodology analysis phase, only methodology artifacts can be written.
Allowed: methodology-analysis-report.md, methodology-analysis-done.md" >&2
    exit 2
fi

# ========================================
# 确定文件类型
# ========================================

IS_SUMMARY_FILE=$(is_round_file_type "$FILE_PATH_LOWER" "summary" && echo "true" || echo "false")
IS_CONTRACT_FILE=$(is_round_file_type "$FILE_PATH_LOWER" "contract" && echo "true" || echo "false")
IS_FINALIZE_SUMMARY=$(is_finalize_summary_path "$FILE_PATH_LOWER" && echo "true" || echo "false")
IN_HUMANIZE_LOOP_DIR=$(is_in_humanize_loop_dir "$FILE_PATH" && echo "true" || echo "false")

# 如果不是摘要文件、不是合同文件、不是 finalize 摘要，且不在 .humanize/rlcr 中，则正常允许
if [[ "$IS_SUMMARY_FILE" == "false" ]] && [[ "$IS_CONTRACT_FILE" == "false" ]] && [[ "$IS_FINALIZE_SUMMARY" == "false" ]] && [[ "$IN_HUMANIZE_LOOP_DIR" == "false" ]]; then
    exit 0
fi

# 对于 .humanize/rlcr 中的 state.md、finalize-state.md、methodology-analysis-state.md、goal-tracker.md 和 plan.md，我们需要进一步验证
# 对于 .humanize/rlcr 中不是摘要/合同的其他文件，允许它们
FILENAME=$(basename "$FILE_PATH")
IS_PLAN_BACKUP=$([[ "$FILENAME" == "plan.md" ]] && echo "true" || echo "false")
if [[ "$IN_HUMANIZE_LOOP_DIR" == "true" ]] && [[ "$IS_SUMMARY_FILE" == "false" ]] && [[ "$IS_CONTRACT_FILE" == "false" ]] && [[ "$IS_FINALIZE_SUMMARY" == "false" ]]; then
    if ! is_state_file_path "$FILE_PATH_LOWER" && ! is_finalize_state_file_path "$FILE_PATH_LOWER" && ! is_methodology_analysis_state_file_path "$FILE_PATH_LOWER" && ! is_goal_tracker_path "$FILE_PATH_LOWER" && [[ "$IS_PLAN_BACKUP" != "true" ]]; then
        exit 0
    fi
fi

# ========================================
# 查找活跃循环和当前轮次
# ========================================

# 如果未由先前的 todos 检查设置，则重新初始化
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
# 阻止状态文件写入（state.md、finalize-state.md、methodology-analysis-state.md）
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

# ========================================
# 允许 Finalize 摘要文件
# ========================================
# 在 Finalize 阶段，允许写入 finalize-summary.md
# 这必须在"摘要文件在 .humanize/rlcr 外"检查之前检查

if [[ "$IS_FINALIZE_SUMMARY" == "true" ]] && [[ "$IN_HUMANIZE_LOOP_DIR" == "true" ]]; then
    # 验证它在活跃循环目录中
    if [[ "$FILE_PATH" == "$ACTIVE_LOOP_DIR/finalize-summary.md" ]]; then
        exit 0
    fi
fi

# 一旦循环进入 Finalize 阶段，就没有活跃的轮次合同。
if [[ "$IS_FINALIZE_PHASE" == "true" ]] && [[ "$IS_CONTRACT_FILE" == "true" ]]; then
    finalize_contract_blocked_message "write to" >&2
    exit 2
fi

# ========================================
# 阻止计划备份写入
# ========================================

if [[ "$IS_PLAN_BACKUP" == "true" ]]; then
    if [[ "$FILE_PATH" == *"/.humanize/rlcr/"* ]]; then
        FALLBACK="Writing to plan.md backup is not allowed during RLCR loop."
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/plan-backup-protected.md" "$FALLBACK")
        echo "$REASON" >&2
        exit 2
    fi
fi

# ========================================
# 验证目标跟踪器写入
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
        if ! require_tool_input_field "$HOOK_INPUT" "content"; then
            exit 1
        fi

        UPDATED_CONTENT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.content // ""')
        if ! goal_tracker_mutable_update_allowed "$GOAL_TRACKER_PATH" "$UPDATED_CONTENT"; then
            goal_tracker_blocked_message "$CURRENT_ROUND" "$GOAL_TRACKER_PATH" >&2
            exit 2
        fi
    fi

    exit 0
fi

# ========================================
# 阻止 .humanize/rlcr 外的摘要/合同文件
# ========================================

if [[ "$IS_SUMMARY_FILE" == "true" || "$IS_CONTRACT_FILE" == "true" ]] && [[ "$IN_HUMANIZE_LOOP_DIR" == "false" ]]; then
    if [[ "$IS_CONTRACT_FILE" == "true" ]]; then
        CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-contract.md"
        FALLBACK="# Wrong Round Contract Location

Write the round contract to the correct path: {{CORRECT_PATH}}"
        load_and_render_safe "$TEMPLATE_DIR" "block/wrong-contract-location.md" "$FALLBACK" \
            "CORRECT_PATH=$CORRECT_PATH" >&2
    else
        CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-summary.md"
        FALLBACK="# Wrong Summary Location

Write summary to the correct path: {{CORRECT_PATH}}"
        load_and_render_safe "$TEMPLATE_DIR" "block/wrong-summary-location.md" "$FALLBACK" \
            "CORRECT_PATH=$CORRECT_PATH" >&2
    fi
    exit 2
fi

# ========================================
# 提取路径组件（可移植 - 在 bash 和 zsh 中工作）
# ========================================

CLAUDE_FILENAME=$(echo "$FILE_PATH" | sed -n 's|.*\.humanize/rlcr/[^/]*/\(.*\)$|\1|p')
if [[ -z "$CLAUDE_FILENAME" ]]; then
    CLAUDE_FILENAME=$(echo "$FILE_PATH" | sed -n 's|.*\.humanize/rlcr/\(.*\)$|\1|p')
fi
if [[ -z "$CLAUDE_FILENAME" ]]; then
    exit 0
fi

# ========================================
# 验证轮次编号（用于摘要/合同文件）
# ========================================

if [[ "$IS_SUMMARY_FILE" == "true" || "$IS_CONTRACT_FILE" == "true" ]]; then
    CLAUDE_ROUND=$(extract_round_number "$CLAUDE_FILENAME")
    FILE_TYPE=$([[ "$IS_CONTRACT_FILE" == "true" ]] && echo "contract" || echo "summary")

    if [[ -n "$CLAUDE_ROUND" ]] && [[ "$CLAUDE_ROUND" != "$CURRENT_ROUND" ]] && ! is_allowlisted_file "$FILE_PATH" "$ACTIVE_LOOP_DIR"; then
        CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-${FILE_TYPE}.md"
        FALLBACK="# Wrong Round Number

You tried to {{ACTION}} round-{{CLAUDE_ROUND}}-{{FILE_TYPE}}.md but current round is **{{CURRENT_ROUND}}**.

Write to: {{CORRECT_PATH}}"
        load_and_render_safe "$TEMPLATE_DIR" "block/wrong-round-number.md" "$FALLBACK" \
            "ACTION=write to" \
            "CLAUDE_ROUND=$CLAUDE_ROUND" \
            "FILE_TYPE=$FILE_TYPE" \
            "CURRENT_ROUND=$CURRENT_ROUND" \
            "CORRECT_PATH=$CORRECT_PATH" >&2
        exit 2
    fi
fi

# ========================================
# 验证目录路径
# ========================================

CORRECT_PATH="$ACTIVE_LOOP_DIR/$CLAUDE_FILENAME"

# 比较前缀规范形式，以免检查被以不同祖先形式表达的等效路径
# （例如 /var/... vs /private/var/... 在 macOS 上）所愚弄 -- 而不取消引用叶子。
# 在这里使用完整的 realpath 会让在 <loop>/<CLAUDE_FILENAME> 处植入的符号链接
# 指向循环目录外，批准通过链接的写入，将 Claude 的写入范围扩展到循环目录之外。
# canonicalize_path_prefix 仅解析父目录；basename 按字面比较。
_WRITE_FILE_REAL=$(canonicalize_path_prefix "$FILE_PATH")
_WRITE_CORRECT_REAL=$(canonicalize_path_prefix "$CORRECT_PATH")
if [[ "${_WRITE_FILE_REAL:-$FILE_PATH}" != "${_WRITE_CORRECT_REAL:-$CORRECT_PATH}" ]]; then
    FALLBACK="# Wrong Directory Path

You tried to {{ACTION}} {{FILE_PATH}} but the correct path is {{CORRECT_PATH}}"
    load_and_render_safe "$TEMPLATE_DIR" "block/wrong-directory-path.md" "$FALLBACK" \
        "ACTION=write to" \
        "FILE_PATH=$FILE_PATH" \
        "CORRECT_PATH=$CORRECT_PATH" >&2
    exit 2
fi

exit 0
