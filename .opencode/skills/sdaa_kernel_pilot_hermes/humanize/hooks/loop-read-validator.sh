#!/usr/bin/env bash
#
# PreToolUse 钩子：验证 RLCR 循环文件的读取访问
#
# 阻止 Claude 读取：
# - 错误轮次的提示/摘要/合同文件（过时信息）
# - 错误位置的轮次文件（不在 .humanize/rlcr/ 中）
# - 旧会话目录的轮次文件
# - Todos 文件（应使用原生 Task 工具代替）
# - 旧 RLCR 会话的 goal-tracker.md
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

if [[ "$TOOL_NAME" != "Read" ]]; then
    exit 0
fi

# Read 工具需要 file_path 参数；缺失说明事件载荷异常，无可校验内容，放行不报错
if ! require_tool_input_field "$HOOK_INPUT" "file_path" 2>/dev/null; then
    exit 0
fi

FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""')
FILE_PATH_LOWER=$(to_lower "$FILE_PATH")

# 从钩子输入中提取 session_id 用于会话感知的循环过滤
HOOK_SESSION_ID=$(extract_session_id "$HOOK_INPUT")

# ========================================
# 阻止 Todos 文件
# ========================================

if is_round_file_type "$FILE_PATH_LOWER" "todos"; then
    PROJECT_ROOT="$(resolve_project_root)" || exit 0
    LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"
    LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")
    if [[ -z "$LOOP_DIR" ]] || ! is_allowlisted_file "$FILE_PATH" "$LOOP_DIR"; then
        todos_blocked_message "Read" >&2
        exit 2
    fi
fi

# ========================================
# 方法论分析阶段读取限制
# ========================================
# 在方法论分析期间，将循环目录内文件的读取限制为
# 仅分析代理需要的产物。这防止了项目特定信息泄漏到分析报告中。
# 循环目录外的文件是允许的（Claude 需要系统文件）。
# 此检查必须在下面的摘要/提示早期退出之前进行，
# 否则循环目录中的非摘要/提示文件将逃脱限制。

PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root 2>/dev/null || true)}"
[[ -z "$PROJECT_ROOT" ]] && exit 0
LOOP_BASE_DIR="${LOOP_BASE_DIR:-$PROJECT_ROOT/.humanize/rlcr}"
# 仅使用会话匹配的循环。不要回退到未过滤的搜索，
# 因为这会错误地限制在同一仓库中打开的无关会话。
# 限制：生成的代理（不同的 session_id）不受钩子限制；
# 它们的清理由分析提示词强制执行。
ACTIVE_LOOP_DIR="${LOOP_DIR:-$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")}"
_MA_CHECK_DIR="$ACTIVE_LOOP_DIR"

if [[ -n "$_MA_CHECK_DIR" ]]; then
    _MA_STATE=$(resolve_active_state_file "$_MA_CHECK_DIR")
    if [[ "$_MA_STATE" == *"/methodology-analysis-state.md" ]]; then
        # 规范化以防止路径遍历
        # 如果 realpath 失败（文件在 BSD/macOS 上尚不存在），解析父目录
        _ma_real_path=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
        if [[ -z "$_ma_real_path" ]]; then
            _ma_parent=$(realpath "$(dirname "$FILE_PATH")" 2>/dev/null || echo "")
            [[ -n "$_ma_parent" ]] && _ma_real_path="$_ma_parent/$(basename "$FILE_PATH")"
        fi
        _ma_real_loop=$(realpath "$_MA_CHECK_DIR" 2>/dev/null || echo "")
        # 当 realpath 不可用时回退到原始路径（较旧的 macOS/BSD）
        # 确保路径是绝对路径，以便前缀守卫不能被绕过。
        # 拒绝包含 ".." 段的路径以防止在无法规范化时的遍历绕过（关闭失败）。
        if [[ -z "$_ma_real_path" ]]; then
            if [[ "$FILE_PATH" == *".."* ]]; then
                echo "# Read Blocked During Methodology Analysis

Path contains traversal segments that cannot be resolved without realpath." >&2
                exit 2
            fi
            # 如果文件是我们无法解析的符号链接，则关闭失败；
            # 原始路径会跳过项目根前缀守卫，允许项目外的符号链接
            # 指回受限的项目内容。
            if [[ -L "$FILE_PATH" ]]; then
                echo "# Read Blocked During Methodology Analysis

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
            if [[ "$_MA_CHECK_DIR" == /* ]]; then
                _ma_real_loop="$_MA_CHECK_DIR"
            else
                _ma_real_loop="$PROJECT_ROOT/$_MA_CHECK_DIR"
            fi
        fi
        if [[ "$_ma_real_path" == "$_ma_real_loop/"* ]]; then
            _ma_basename=$(basename "$_ma_real_path")
            # 允许列表：仅方法论产物（不是原始开发记录）。
            # 原始记录（round-*-summary.md、round-*-review-result.md）被故意排除，
            # 以便源会话无法读取项目特定内容，必须仅依赖清理后的
            # methodology-analysis-report.md 作为所有面向用户的输出。
            # 生成的 Opus 代理直接读取原始记录（由于不同的 session_id 不受钩子限制
            # -- 参见上面的限制注释）。
            case "$_ma_basename" in
                methodology-analysis-report.md|methodology-analysis-done.md|methodology-analysis-state.md)
                    exit 0
                    ;;
                *)
                    echo "# Read Blocked During Methodology Analysis

Only methodology artifacts can be read from the loop directory during this phase.
Allowed: methodology-analysis-report.md, methodology-analysis-done.md, methodology-analysis-state.md" >&2
                    exit 2
                    ;;
            esac
        fi
        # 项目根目录内的文件被阻止（项目特定信息）
        # 项目根目录外的文件是允许的（系统文件、配置等）
        _ma_project_real=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
        if [[ -n "$_ma_project_real" ]]; then
            _ma_path_check="${_ma_real_path:-$FILE_PATH}"
            if [[ "$_ma_path_check" == "$_ma_project_real/"* ]] || \
               [[ "$_ma_path_check" == "$PROJECT_ROOT/"* ]]; then
                echo "# Read Blocked During Methodology Analysis

Reading project files is not allowed during the methodology analysis phase.
Only methodology artifacts within the loop directory can be read.
Allowed: methodology-analysis-report.md, methodology-analysis-done.md, methodology-analysis-state.md" >&2
                exit 2
            fi
        fi
        exit 0
    fi
fi

# ========================================
# 检查受限的 RLCR 文件
# ========================================

IS_GOAL_TRACKER=$(is_goal_tracker_path "$FILE_PATH_LOWER" && echo "true" || echo "false")
IS_ROUND_FILE=$(
    if is_round_file_type "$FILE_PATH_LOWER" "summary" || \
       is_round_file_type "$FILE_PATH_LOWER" "prompt" || \
       is_round_file_type "$FILE_PATH_LOWER" "contract"; then
        echo "true"
    else
        echo "false"
    fi
)

IN_HUMANIZE_LOOP_DIR=$(is_in_humanize_loop_dir "$FILE_PATH" && echo "true" || echo "false")
if [[ "$IS_ROUND_FILE" != "true" ]] && ! { [[ "$IS_GOAL_TRACKER" == "true" ]] && [[ "$IN_HUMANIZE_LOOP_DIR" == "true" ]]; }; then
    exit 0
fi

CLAUDE_FILENAME=$(basename "$FILE_PATH")

# ========================================
# 查找活跃循环和当前轮次
# ========================================

# 如果上面的方法论分析检查已设置，则重用 ACTIVE_LOOP_DIR
ACTIVE_LOOP_DIR="${ACTIVE_LOOP_DIR:-${LOOP_DIR:-$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")}}"

if [[ -z "$ACTIVE_LOOP_DIR" ]]; then
    exit 0
fi

# 从状态文件检测循环阶段
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

if [[ "$IS_FINALIZE_PHASE" == "true" ]] && is_round_file_type "$FILE_PATH_LOWER" "contract"; then
    finalize_contract_blocked_message "read" >&2
    exit 2
fi

# ========================================
# 验证目标跟踪器路径
# ========================================

if [[ "$IS_GOAL_TRACKER" == "true" ]] && [[ "$IN_HUMANIZE_LOOP_DIR" == "true" ]]; then
    CORRECT_PATH="$ACTIVE_LOOP_DIR/goal-tracker.md"
    NORMALIZED_FILE_PATH=$(_normalize_path "$FILE_PATH")
    NORMALIZED_CORRECT_PATH=$(_normalize_path "$CORRECT_PATH")

    if [[ "$NORMALIZED_FILE_PATH" != "$NORMALIZED_CORRECT_PATH" ]]; then
        FALLBACK="# Wrong Goal Tracker Path

Read the active loop goal tracker instead: {{CORRECT_PATH}}"
        load_and_render_safe "$TEMPLATE_DIR" "block/wrong-file-location.md" "$FALLBACK" \
            "FILE_PATH=$FILE_PATH" \
            "ACTIVE_LOOP_DIR=$ACTIVE_LOOP_DIR" \
            "CURRENT_ROUND=$CURRENT_ROUND" \
            "CORRECT_PATH=$CORRECT_PATH" >&2
        exit 2
    fi

    exit 0
fi

# ========================================
# 提取轮次编号和文件类型
# ========================================

CLAUDE_ROUND=$(extract_round_number "$CLAUDE_FILENAME")
if [[ -z "$CLAUDE_ROUND" ]]; then
    exit 0
fi

# 根据文件名确定文件类型
FILE_TYPE=""
if is_round_file_type "$FILE_PATH_LOWER" "summary"; then
    FILE_TYPE="summary"
elif is_round_file_type "$FILE_PATH_LOWER" "prompt"; then
    FILE_TYPE="prompt"
elif is_round_file_type "$FILE_PATH_LOWER" "contract"; then
    FILE_TYPE="contract"
fi

# ========================================
# 验证文件位置
# ========================================

if [[ "$IN_HUMANIZE_LOOP_DIR" == "false" ]]; then
    CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-${FILE_TYPE}.md"
    FALLBACK="# Wrong File Location

Reading {{FILE_PATH}} is blocked. Read from the active loop: {{ACTIVE_LOOP_DIR}}"
    load_and_render_safe "$TEMPLATE_DIR" "block/wrong-file-location.md" "$FALLBACK" \
        "FILE_PATH=$FILE_PATH" \
        "ACTIVE_LOOP_DIR=$ACTIVE_LOOP_DIR" \
        "CURRENT_ROUND=$CURRENT_ROUND" >&2
    exit 2
fi

# ========================================
# 验证轮次编号
# ========================================

if [[ "$CLAUDE_ROUND" != "$CURRENT_ROUND" ]] && ! is_allowlisted_file "$FILE_PATH" "$ACTIVE_LOOP_DIR"; then
    FALLBACK="# Wrong Round File

You tried to read round-{{CLAUDE_ROUND}}-{{FILE_TYPE}}.md but current round is **{{CURRENT_ROUND}}**.

Read from: {{ACTIVE_LOOP_DIR}}"
    load_and_render_safe "$TEMPLATE_DIR" "block/wrong-round-file.md" "$FALLBACK" \
        "CLAUDE_ROUND=$CLAUDE_ROUND" \
        "FILE_TYPE=$FILE_TYPE" \
        "CURRENT_ROUND=$CURRENT_ROUND" \
        "ACTIVE_LOOP_DIR=$ACTIVE_LOOP_DIR" \
        "FILE_PATH=$FILE_PATH" >&2
    exit 2
fi

# ========================================
# 验证目录路径
# ========================================

CORRECT_PATH="$ACTIVE_LOOP_DIR/$CLAUDE_FILENAME"

# 比较前缀规范形式 -- 参见 loop-write-validator.sh 了解原因；
# 同样的推理适用于读取路径。否则，在叶子处植入的符号链接
# 会让 Read 跟随链接到循环目录外，仍然通过此验证器。
_READ_FILE_REAL=$(canonicalize_path_prefix "$FILE_PATH")
_READ_CORRECT_REAL=$(canonicalize_path_prefix "$CORRECT_PATH")
if [[ "${_READ_FILE_REAL:-$FILE_PATH}" != "${_READ_CORRECT_REAL:-$CORRECT_PATH}" ]]; then
    FALLBACK="# Wrong Directory Path

You tried to {{ACTION}} {{FILE_PATH}} but the correct path is {{CORRECT_PATH}}"
    load_and_render_safe "$TEMPLATE_DIR" "block/wrong-directory-path.md" "$FALLBACK" \
        "ACTION=read" \
        "FILE_PATH=$FILE_PATH" \
        "CORRECT_PATH=$CORRECT_PATH" >&2
    exit 2
fi

exit 0
