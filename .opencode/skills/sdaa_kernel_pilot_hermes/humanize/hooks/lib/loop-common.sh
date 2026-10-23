#!/usr/bin/env bash
#
# RLCR 循环钩子的通用函数
#
# 此库提供被以下脚本使用的共享功能：
# - loop-read-validator.sh
# - loop-write-validator.sh
# - loop-edit-validator.sh
# - loop-bash-validator.sh
# - loop-plan-file-validator.sh
# - loop-codex-stop-hook.sh
# - setup-rlcr-loop.sh
# - cancel-rlcr-loop.sh
#

# 源码守卫：防止重复源码引入（readonly 变量会失败）
[[ -n "${_LOOP_COMMON_LOADED:-}" ]] && return 0 2>/dev/null || true
_LOOP_COMMON_LOADED=1

# ========================================
# 常量
# ========================================

# 状态文件字段名
readonly FIELD_PLAN_TRACKED="plan_tracked"
readonly FIELD_START_BRANCH="start_branch"
readonly FIELD_BASE_BRANCH="base_branch"
readonly FIELD_BASE_COMMIT="base_commit"
readonly FIELD_PLAN_FILE="plan_file"
readonly FIELD_CURRENT_ROUND="current_round"
readonly FIELD_MAX_ITERATIONS="max_iterations"
readonly FIELD_PUSH_EVERY_ROUND="push_every_round"
readonly FIELD_CODEX_MODEL="codex_model"
readonly FIELD_CODEX_EFFORT="codex_effort"
readonly FIELD_CODEX_TIMEOUT="codex_timeout"
readonly FIELD_REVIEW_STARTED="review_started"
readonly FIELD_FULL_REVIEW_ROUND="full_review_round"
readonly FIELD_ASK_CODEX_QUESTION="ask_codex_question"
readonly FIELD_SESSION_ID="session_id"
readonly FIELD_AGENT_TEAMS="agent_teams"
readonly FIELD_PRIVACY_MODE="privacy_mode"
readonly FIELD_STRICT_SUCCESS="strict_success"
readonly FIELD_MAINLINE_STALL_COUNT="mainline_stall_count"
readonly FIELD_LAST_MAINLINE_VERDICT="last_mainline_verdict"
readonly FIELD_DRIFT_STATUS="drift_status"

readonly MAINLINE_VERDICT_ADVANCED="advanced"
readonly MAINLINE_VERDICT_STALLED="stalled"
readonly MAINLINE_VERDICT_REGRESSED="regressed"
readonly MAINLINE_VERDICT_UNKNOWN="unknown"

readonly DRIFT_STATUS_NORMAL="normal"
readonly DRIFT_STATUS_REPLAN_REQUIRED="replan_required"

# 默认 Codex 配置（单一事实来源 - 所有脚本引用此配置）
# 脚本可以在源码引入之前预设 DEFAULT_CODEX_MODEL/DEFAULT_CODEX_EFFORT 以覆盖。
# 配置支持的默认值在 config-loader.sh 源码引入后从合并层次结构加载。
# 优先级：预设值 > 配置值 > 硬编码回退（gpt-5.5/high）
#
# 实际赋值发生在下面的"配置支持的默认值"部分，
# 在 config-loader.sh 源码引入且合并配置可用之后。

# Codex 审查标记
readonly MARKER_COMPLETE="COMPLETE"
readonly MARKER_STOP="STOP"

# 退出原因（与 end_loop 函数一起使用）
# complete   - Codex 确认所有目标已实现（正常成功）
# cancel     - 用户使用 /cancel-rlcr-loop 取消
# maxiter    - 达到最大迭代次数限制
# stop       - Codex 触发断路器（检测到停滞）
# unexpected - 系统错误或无效状态（例如损坏的状态文件）
readonly EXIT_COMPLETE="complete"
readonly EXIT_CANCEL="cancel"
readonly EXIT_MAXITER="maxiter"
readonly EXIT_STOP="stop"
readonly EXIT_UNEXPECTED="unexpected"

# ========================================
# JSON 输入验证
# ========================================

# 从 stdin 读取钩子输入并清洗无效 UTF-8 字节
# 用法：HOOK_INPUT=$(read_hook_input)
# 工具输出（PostToolUse）或粘贴内容可能携带无效 UTF-8 字节；
# 直接拒绝会让整条钩子链报错（"Input contains invalid UTF-8 sequences"）。
# 这里用 iconv -c 丢弃无效字节后继续，安全语义不变（空字节仍在
# validate_hook_input 中拒绝；丢弃的字节本来也无法进入 jq 解析）。
read_hook_input() {
    local raw cleaned
    raw=$(cat)
    # iconv 必须容错：偶发 exec 失败（退出码 126）时退回原始输入。绝不能让此函数
    # 因 iconv 失败而在 set -e 下中止（调用方 `X=$(read_hook_input)` 未加保护会随之
    # 以 126 退出、无 stderr），也绝不能返回空输入。
    if command -v iconv >/dev/null 2>&1; then
        cleaned=$(printf '%s' "$raw" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true)
        if [[ -n "$cleaned" ]]; then
            printf '%s' "$cleaned"
            return 0
        fi
    fi
    printf '%s' "$raw"
}

# 验证 JSON 输入并提取 tool_name
# 用法：validate_hook_input "$json_input"
# 返回：0 如果是带 tool_name 的有效 JSON，1 如果无效
# 设置：VALIDATED_TOOL_NAME、VALIDATED_TOOL_INPUT
#
# 非 UTF-8 处理行为：
# - 空字节（0x00）：以退出 1 拒绝
# - 无效 UTF-8 序列（0x80-0xFF 在有效 UTF-8 之外）：被 jq 作为无效 JSON 拒绝
# - 有效的 UTF-8 非 ASCII 字符：接受（jq 正确处理 Unicode）
validate_hook_input() {
    local input="$1"

    # 拒绝空字节（安全性）- 不使用 grep -P 的可移植检查（BSD 不兼容）
    # tr -cd '\0' 仅保留空字节，wc -c 计数它们
    if [[ $(printf '%s' "$input" | tr -cd '\0' | wc -c) -gt 0 ]]; then
        echo "Error: Input contains null bytes" >&2
        return 1
    fi

    # 非 UTF-8 字节：清洗后继续（read_hook_input 已处理；这里兜底）。
    # iconv 必须容错：偶发 exec 失败（退出码 126）时保留原始输入，决不中止或清空。
    if command -v iconv >/dev/null 2>&1; then
        local _ci
        _ci=$(printf '%s' "$input" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true)
        if [[ -n "$_ci" ]]; then input="$_ci"; fi
    fi

    # 使用 jq 验证 JSON 语法
    if ! printf '%s' "$input" | jq -e '.' >/dev/null 2>&1; then
        echo "Error: Invalid JSON syntax" >&2
        return 1
    fi

    # 提取 tool_name；缺失视为与本钩子无关的事件，交由调用方按工具名不匹配放行，
    # 不能报错退出（部分宿主事件不携带 tool_name，报错会刷非阻塞错误）
    VALIDATED_TOOL_NAME=$(printf '%s' "$input" | jq -r '.tool_name // empty')

    # 提取 tool_input（Read/Write/Bash 需要）
    VALIDATED_TOOL_INPUT=$(printf '%s' "$input" | jq -r '.tool_input // empty')

    return 0
}

# 验证 tool_input 中存在特定字段
# 用法：require_tool_input_field "$json_input" "field_name"
# 返回：0 如果字段存在且非空，否则返回 1
require_tool_input_field() {
    local input="$1"
    local field="$2"

    local value
    value=$(printf '%s' "$input" | jq -r ".tool_input.$field // empty")

    if [[ -z "$value" ]]; then
        echo "Error: Missing required field: tool_input.$field" >&2
        return 1
    fi

    return 0
}

# 检查 JSON 是否深度嵌套（潜在的 DoS 攻击）
# 用法：is_deeply_nested "$json_input" [max_depth]
# 返回：0 如果太深嵌套，否则返回 1
is_deeply_nested() {
    local input="$1"
    local max_depth="${2:-30}"

    # 使用 jq 检查深度 - 递归下降上的 getpath 给我们深度
    local actual_depth
    actual_depth=$(printf '%s' "$input" | jq '[paths | length] | max // 0' 2>/dev/null || echo "0")

    if [[ "$actual_depth" -gt "$max_depth" ]]; then
        echo "Error: JSON structure exceeds maximum depth of $max_depth (actual: $actual_depth)" >&2
        return 0
    fi

    return 1
}

# ========================================
# 库设置
# ========================================

# 源码引入模板加载器
LOOP_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LOOP_COMMON_PLUGIN_ROOT="$(cd "$LOOP_COMMON_DIR/../.." && pwd)"
export PLUGIN_ROOT="${PLUGIN_ROOT:-$LOOP_COMMON_PLUGIN_ROOT}"

# 共享的项目根解析器（CLAUDE_PROJECT_DIR -> git toplevel，realpath 规范化）。
# 必须在任何调用者需要 PROJECT_ROOT 之前加载。
source "$LOOP_COMMON_DIR/project-root.sh"

_lc_errexit=false; [[ -o errexit ]] && _lc_errexit=true
_lc_nounset=false; [[ -o nounset ]] && _lc_nounset=true
_lc_pipefail=false; [[ -o pipefail ]] && _lc_pipefail=true
source "$LOOP_COMMON_PLUGIN_ROOT/scripts/lib/config-loader.sh"
$_lc_errexit && set -e || set +e
$_lc_nounset && set -u || set +u
$_lc_pipefail && set -o pipefail || set +o pipefail
unset _lc_errexit _lc_nounset _lc_pipefail

_LOOP_COMMON_PROJECT_ROOT="$(resolve_project_root 2>/dev/null || true)"
# 配置加载是尽力而为的：使用 || true 以便配置加载失败不会在调用者的
# 依赖检查（jq、codex）到达之前中止源码引入。
# Stderr 不被抑制，以便格式错误的配置警告保持可见。
#
# 当没有项目根可用时跳过配置加载（例如 humanize.sh 从 .bashrc/.zshrc
# 在非仓库目录如 $HOME 中源码引入）。将空的 project_root 传递给
# load_merged_config 会在每次 shell 启动时在 stderr 上显示使用错误。
if [[ -n "$_LOOP_COMMON_PROJECT_ROOT" ]]; then
    _LOOP_COMMON_CONFIG="$(load_merged_config "$LOOP_COMMON_PLUGIN_ROOT" "$_LOOP_COMMON_PROJECT_ROOT")" || true
else
    _LOOP_COMMON_CONFIG=""
fi

# 从合并配置加载 bitlesson 模型（控制 bitlesson-select.sh 使用的 CLI）
DEFAULT_BITLESSON_MODEL="$(get_config_value "$_LOOP_COMMON_CONFIG" "bitlesson_model" 2>/dev/null || true)"
DEFAULT_BITLESSON_MODEL="${DEFAULT_BITLESSON_MODEL:-haiku}"

# 从合并配置加载 codex model/effort，以便 .humanize/config.json 可以为所有
# 使用 Codex 的功能（RLCR、ask-codex）设置持久默认值。
# 优先级：调用者预设 > 配置值 > 硬编码回退（gpt-5.5/high）
_cfg_codex_model="$(get_config_value "$_LOOP_COMMON_CONFIG" "codex_model" 2>/dev/null || true)"
if [[ -n "$_cfg_codex_model" && ! "$_cfg_codex_model" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Warning: Invalid codex_model in merged config: $_cfg_codex_model" >&2
    echo "  Ignoring configured codex_model; using caller preset or fallback" >&2
    _cfg_codex_model=""
elif [[ -n "$_cfg_codex_model" && ! "$_cfg_codex_model" =~ ^(gpt-|o[0-9]) ]]; then
    echo "Warning: Unsupported codex_model in merged config: $_cfg_codex_model" >&2
    echo "  Must start with a Codex model prefix: gpt- or o[0-9]" >&2
    echo "  Ignoring configured codex_model; using caller preset or fallback" >&2
    _cfg_codex_model=""
fi
DEFAULT_CODEX_MODEL="${DEFAULT_CODEX_MODEL:-${_cfg_codex_model:-gpt-5.5}}"
_cfg_codex_effort="$(get_config_value "$_LOOP_COMMON_CONFIG" "codex_effort" 2>/dev/null || true)"
if [[ -n "$_cfg_codex_effort" && ! "$_cfg_codex_effort" =~ ^(xhigh|high|medium|low)$ ]]; then
    echo "Warning: Invalid codex_effort in merged config: $_cfg_codex_effort" >&2
    echo "  Must be one of: xhigh, high, medium, low" >&2
    echo "  Ignoring configured codex_effort; using caller preset or fallback" >&2
    _cfg_codex_effort=""
fi
DEFAULT_CODEX_EFFORT="${DEFAULT_CODEX_EFFORT:-${_cfg_codex_effort:-high}}"

# 从合并配置加载 agent_teams（控制 RLCR 是否默认使用代理团队）
# 优先级：调用者预设（例如 --agent-teams 标志）> 配置值 > 硬编码回退（false）
_cfg_agent_teams="$(get_config_value "$_LOOP_COMMON_CONFIG" "agent_teams" 2>/dev/null || true)"
DEFAULT_AGENT_TEAMS="${DEFAULT_AGENT_TEAMS:-${_cfg_agent_teams:-false}}"
unset _cfg_codex_model _cfg_codex_effort _cfg_agent_teams

unset _LOOP_COMMON_PROJECT_ROOT _LOOP_COMMON_CONFIG

source "$LOOP_COMMON_DIR/template-loader.sh"

# 初始化模板目录（可被源码引入脚本覆盖）
TEMPLATE_DIR="${TEMPLATE_DIR:-$(get_template_dir "$LOOP_COMMON_DIR")}"

# 验证模板目录存在（警告但不失败 - 允许优雅降级）
if ! validate_template_dir "$TEMPLATE_DIR" 2>/dev/null; then
    echo "Warning: Template directory validation failed. Using inline fallbacks." >&2
fi

# 从钩子 JSON 输入中提取 session_id
# 用法：extract_session_id "$json_input"
# 将 session_id 输出到 stdout，如果不可用则输出空字符串
extract_session_id() {
    local input="$1"
    printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || echo ""
}

# 后台任务辅助函数（expand_leading_tilde、extract_transcript_path、
# derive_loop_start_iso_ts、list/has/count_pending_background_task[_ids]、
# handle_bg_task_short_circuit）位于 loop-bg-tasks.sh 中，
# 在此文件底部源码引入，以便 loop-common.sh 的每个现有消费者
# 继续透明地获取它们。

# 解析循环目录的活跃状态文件
# 首先检查 finalize-state.md，然后检查 state.md
# 用法：resolve_active_state_file "$loop_dir"
# 将状态文件路径输出到 stdout，如果未找到则输出空字符串
resolve_active_state_file() {
    local loop_dir="$1"

    if [[ -f "$loop_dir/methodology-analysis-state.md" ]]; then
        echo "$loop_dir/methodology-analysis-state.md"
    elif [[ -f "$loop_dir/finalize-state.md" ]]; then
        echo "$loop_dir/finalize-state.md"
    elif [[ -f "$loop_dir/state.md" ]]; then
        echo "$loop_dir/state.md"
    else
        echo ""
    fi
}

# 解析循环目录中的任何状态文件（活跃或终端）
# 首先检查活跃状态（state.md、finalize-state.md），然后回退到任何终端状态文件
# （*-state.md，如 complete-state.md、cancel-state.md）。
# 用法：resolve_any_state_file "$loop_dir"
# 将状态文件路径输出到 stdout，如果未找到则输出空字符串
resolve_any_state_file() {
    local loop_dir="$1"

    # 优先选择活跃状态
    if [[ -f "$loop_dir/methodology-analysis-state.md" ]]; then
        echo "$loop_dir/methodology-analysis-state.md"
        return
    elif [[ -f "$loop_dir/finalize-state.md" ]]; then
        echo "$loop_dir/finalize-state.md"
        return
    elif [[ -f "$loop_dir/state.md" ]]; then
        echo "$loop_dir/state.md"
        return
    fi

    # 回退到任何终端状态文件
    local terminal_state
    terminal_state=$(ls -1 "$loop_dir"/*-state.md 2>/dev/null | head -1)
    echo "${terminal_state:-}"
}

# 查找匹配可选 session_id 过滤器的最近活跃循环目录
#
# 没有 session_id 过滤器：仅检查单个最新目录。
#   如果它有 state.md 或 finalize-state.md，则返回它；否则返回空。
#   这保留了僵尸循环保护：较旧的目录永远不会被检查，
#   因此较旧目录中的过期 state.md 不会被意外复活。
#
# 有 session_id 过滤器：查找属于该会话的最新目录
#   （匹配任何 *state.md 文件，包括终端状态），然后检查它是否仍活跃。
#   如果会话的最新目录处于终端状态（complete-state.md、cancel-state.md 等），
#   立即返回空 -- 防止过期的较旧循环被复活。这启用了同一项目中
#   不同 session ID 的多个并发 RLCR 循环。
#
# 空的存储 session_id 匹配任何过滤器（预会话状态文件的向后兼容）。
#
# 第三个参数 `allow_bg_marker_fallback`（默认 "false"）：当为 "true" 时，
# session-filter 分支还考虑持有 `bg-pending.marker` 文件和活跃状态文件的
# 不匹配会话目录。只有 RLCR stop hook 选择加入此功能；
# 所有其他调用者（read/write/bash/plan-file 验证器等）保持严格的会话隔离。
#
# 将目录路径输出到 stdout，如果未找到则输出空字符串
find_active_loop() {
    local loop_base_dir="$1"
    local filter_session_id="${2:-}"
    local allow_bg_marker_fallback="${3:-false}"

    if [[ ! -d "$loop_base_dir" ]]; then
        echo ""
        return
    fi

    if [[ -z "$filter_session_id" ]]; then
        # 无过滤器：仅检查单个最新目录（僵尸循环保护）
        local newest_dir
        newest_dir=$(ls -1d "$loop_base_dir"/*/ 2>/dev/null | sort -r | head -1)

        if [[ -n "$newest_dir" ]]; then
            local state_file
            state_file=$(resolve_active_state_file "${newest_dir%/}")
            if [[ -n "$state_file" ]]; then
                echo "${newest_dir%/}"
                return
            fi
        fi
        echo ""
        return
    fi

    # session 过滤器：从最新到最旧迭代。
    #
    # 调用者自己的（精确存储的 session_id）匹配优先于任何基于标记的采用：
    # 在同一仓库中有多个活跃 RLCR 循环时，不同会话驻留的较新目录
    # 不能在实际属于调用者的较旧目录之前返回。标记候选在扫描期间被记录，
    # 仅在没有找到精确匹配时用作回退。僵尸循环保护
    # （此会话的终端最新返回空）仍然优先于标记回退。
    local dir
    local marker_candidate=""
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        local trimmed_dir="${dir%/}"

        local any_state
        any_state=$(resolve_any_state_file "$trimmed_dir")
        if [[ -z "$any_state" ]]; then
            continue
        fi

        local stored_session_id
        stored_session_id=$(awk -v key="${FIELD_SESSION_ID}" 'BEGIN{f=0} /^---$/{f++; next} f==1 && $0 ~ "^"key":"{sub("^"key":[[:space:]]*",""); print; exit}' "$any_state" 2>/dev/null | tr -d ' ')

        # 空的存储 session_id 匹配任何会话（向后兼容）。
        if [[ -z "$stored_session_id" ]] || [[ "$stored_session_id" == "$filter_session_id" ]]; then
            # 此会话的最新目录 -- 仅在活跃时返回。
            local active_state
            active_state=$(resolve_active_state_file "$trimmed_dir")
            if [[ -n "$active_state" ]]; then
                echo "$trimmed_dir"
                return
            fi
            # 会话的最新循环处于终端状态；也不要落入基于标记的采用。
            echo ""
            return
        fi

        # 会话不匹配。只有 stop hook 选择加入基于标记的采用；
        # 验证器和其他调用者保持严格隔离，因此仅在调用者明确允许时才记录候选。
        if [[ "$allow_bg_marker_fallback" == "true" ]] \
           && [[ -z "$marker_candidate" ]] \
           && [[ -f "$trimmed_dir/bg-pending.marker" ]]; then
            local candidate_state
            candidate_state=$(resolve_active_state_file "$trimmed_dir")
            if [[ -n "$candidate_state" ]]; then
                marker_candidate="$trimmed_dir"
            fi
            # 终端循环上的标记是过期的；不要动它。
        fi
    done < <(ls -1d "$loop_base_dir"/*/ 2>/dev/null | sort -r)

    # 没有精确的会话匹配。仅在调用者明确选择加入时回退到基于标记的采用
    # -- stop hook 使用此功能来显示"被另一个会话驻留"通知，
    # 或在先前会话在后台完成到达之前死亡后恢复其自己的驻留循环。
    if [[ "$allow_bg_marker_fallback" == "true" ]] && [[ -n "$marker_candidate" ]]; then
        echo "$marker_candidate"
        return
    fi

    echo ""
}

# 从 state.md 提取当前轮次编号
# 将轮次编号输出到 stdout，默认为 0
# 注意：对于完整状态解析，请使用 parse_state_file()
get_current_round() {
    local state_file="$1"

    local frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$state_file" 2>/dev/null || echo "")

    local current_round
    current_round=$(echo "$frontmatter" | grep "^${FIELD_CURRENT_ROUND}:" | sed "s/${FIELD_CURRENT_ROUND}: *//" | tr -d ' ')

    echo "${current_round:-0}"
}

# 从前置元数据内容中提取状态字段（内部辅助函数）
# 用法：_parse_state_fields
# 要求在调用之前设置 STATE_FRONTMATTER
# 设置所有 STATE_* 字段变量，不应用默认值
_parse_state_fields() {
    # 使用一致的引号处理解析字段
    # 保留旧版引号剥离以与较旧的状态文件向后兼容
    STATE_PLAN_TRACKED=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_PLAN_TRACKED}:" | sed "s/${FIELD_PLAN_TRACKED}: *//" | tr -d ' ' || true)
    STATE_START_BRANCH=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_START_BRANCH}:" | sed "s/${FIELD_START_BRANCH}: *//; s/^\"//; s/\"\$//" || true)
    STATE_BASE_BRANCH=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_BASE_BRANCH}:" | sed "s/${FIELD_BASE_BRANCH}: *//; s/^\"//; s/\"\$//" || true)
    STATE_BASE_COMMIT=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_BASE_COMMIT}:" | sed "s/${FIELD_BASE_COMMIT}: *//; s/^\"//; s/\"\$//" || true)
    STATE_PLAN_FILE=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_PLAN_FILE}:" | sed "s/${FIELD_PLAN_FILE}: *//; s/^\"//; s/\"\$//" || true)
    STATE_CURRENT_ROUND=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_CURRENT_ROUND}:" | sed "s/${FIELD_CURRENT_ROUND}: *//" | tr -d ' ' || true)
    STATE_MAX_ITERATIONS=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_MAX_ITERATIONS}:" | sed "s/${FIELD_MAX_ITERATIONS}: *//" | tr -d ' ' || true)
    STATE_PUSH_EVERY_ROUND=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_PUSH_EVERY_ROUND}:" | sed "s/${FIELD_PUSH_EVERY_ROUND}: *//" | tr -d ' ' || true)
    STATE_CODEX_MODEL=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_CODEX_MODEL}:" | sed "s/${FIELD_CODEX_MODEL}: *//" | tr -d ' ' || true)
    STATE_CODEX_EFFORT=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_CODEX_EFFORT}:" | sed "s/${FIELD_CODEX_EFFORT}: *//" | tr -d ' ' || true)
    STATE_CODEX_TIMEOUT=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_CODEX_TIMEOUT}:" | sed "s/${FIELD_CODEX_TIMEOUT}: *//" | tr -d ' ' || true)
    STATE_REVIEW_STARTED=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_REVIEW_STARTED}:" | sed "s/${FIELD_REVIEW_STARTED}: *//" | tr -d ' ' || true)
    STATE_FULL_REVIEW_ROUND=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_FULL_REVIEW_ROUND}:" | sed "s/${FIELD_FULL_REVIEW_ROUND}: *//" | tr -d ' ' || true)
    STATE_ASK_CODEX_QUESTION=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_ASK_CODEX_QUESTION}:" | sed "s/${FIELD_ASK_CODEX_QUESTION}: *//" | tr -d ' ' || true)
    STATE_SESSION_ID=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_SESSION_ID}:" | sed "s/${FIELD_SESSION_ID}: *//" || true)
    STATE_AGENT_TEAMS=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_AGENT_TEAMS}:" | sed "s/${FIELD_AGENT_TEAMS}: *//" | tr -d ' ' || true)
    STATE_PRIVACY_MODE=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_PRIVACY_MODE}:" | sed "s/${FIELD_PRIVACY_MODE}: *//" | tr -d ' ' || true)
    STATE_STRICT_SUCCESS=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_STRICT_SUCCESS}:" | sed "s/${FIELD_STRICT_SUCCESS}: *//" | tr -d ' ' || true)
    STATE_MAINLINE_STALL_COUNT=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_MAINLINE_STALL_COUNT}:" | sed "s/${FIELD_MAINLINE_STALL_COUNT}: *//" | tr -d ' ' || true)
    STATE_LAST_MAINLINE_VERDICT=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_LAST_MAINLINE_VERDICT}:" | sed "s/${FIELD_LAST_MAINLINE_VERDICT}: *//" | tr -d ' ' || true)
    STATE_DRIFT_STATUS=$(echo "$STATE_FRONTMATTER" | grep "^${FIELD_DRIFT_STATUS}:" | sed "s/${FIELD_DRIFT_STATUS}: *//" | tr -d ' ' || true)
}

# 解析状态文件前置元数据并设置变量（带默认值的容错模式）
# 用法：parse_state_file "$STATE_FILE"
# 设置以下变量（调用者必须声明它们）：
#   STATE_FRONTMATTER - 原始前置元数据内容
#   STATE_PLAN_TRACKED - "true" 或 "false"
#   STATE_START_BRANCH - 分支名称
#   STATE_BASE_BRANCH - 代码审查的基础分支
#   STATE_PLAN_FILE - 计划文件路径
#   STATE_CURRENT_ROUND - 当前轮次编号
#   STATE_MAX_ITERATIONS - 最大迭代次数
#   STATE_PUSH_EVERY_ROUND - "true" 或 "false"
#   STATE_CODEX_MODEL - codex 模型名称
#   STATE_CODEX_EFFORT - codex effort 级别
#   STATE_CODEX_TIMEOUT - codex 超时（秒）
#   STATE_REVIEW_STARTED - "true" 或 "false"
#   STATE_FULL_REVIEW_ROUND - 完整对齐检查的间隔（默认：5）
#   STATE_ASK_CODEX_QUESTION - "true" 或 "false"（v1.6.5+）
#   STATE_AGENT_TEAMS - "true" 或 "false"
#   STATE_STRICT_SUCCESS - "true" 或 "false"
#   STATE_MAINLINE_STALL_COUNT - 连续停滞/退化的实现轮次
#   STATE_LAST_MAINLINE_VERDICT - advanced/stalled/regressed/unknown
#   STATE_DRIFT_STATUS - normal/replan_required
# 返回：成功时为 0，文件未找到时为 1
# 注意：对于严格验证，请使用 parse_state_file_strict()
parse_state_file() {
    local state_file="$1"

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    STATE_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$state_file" 2>/dev/null || echo "")

    _parse_state_fields

    # 仅对非模式关键字段应用默认值
    # 注意：review_started 在这里不设置默认值，以便我们可以检测缺失的模式字段
    # 并在 stop hook 中用适当的消息阻止
    STATE_CURRENT_ROUND="${STATE_CURRENT_ROUND:-0}"
    STATE_MAX_ITERATIONS="${STATE_MAX_ITERATIONS:-10}"
    STATE_PUSH_EVERY_ROUND="${STATE_PUSH_EVERY_ROUND:-false}"
    STATE_FULL_REVIEW_ROUND="${STATE_FULL_REVIEW_ROUND:-5}"
    STATE_ASK_CODEX_QUESTION="${STATE_ASK_CODEX_QUESTION:-true}"
    STATE_AGENT_TEAMS="${STATE_AGENT_TEAMS:-false}"
    # 对于早于此字段的旧循环，将 privacy_mode 默认为 "true"
    STATE_PRIVACY_MODE="${STATE_PRIVACY_MODE:-true}"
    STATE_STRICT_SUCCESS="${STATE_STRICT_SUCCESS:-false}"
    STATE_MAINLINE_STALL_COUNT="${STATE_MAINLINE_STALL_COUNT:-0}"
    STATE_LAST_MAINLINE_VERDICT="${STATE_LAST_MAINLINE_VERDICT:-$MAINLINE_VERDICT_UNKNOWN}"
    STATE_DRIFT_STATUS="${STATE_DRIFT_STATUS:-$DRIFT_STATUS_NORMAL}"
    # STATE_REVIEW_STARTED 保持原样（如果缺失则为空，以允许模式验证）

    return 0
}

# 拒绝格式错误文件的严格状态文件解析器
# 用法：parse_state_file_strict "$STATE_FILE"
# 设置与 parse_state_file() 相同的变量
# 返回：成功时为 0，验证失败时为非零
#   1 - 文件未找到
#   2 - 缺少 YAML 前置元数据分隔符
#   3 - 缺少必需字段（current_round 或 max_iterations）
#   4 - 非数字的 current_round 值
#   5 - 非数字的 max_iterations 值
parse_state_file_strict() {
    local state_file="$1"

    if [[ ! -f "$state_file" ]]; then
        echo "Error: State file not found: $state_file" >&2
        return 1
    fi

    # 检查 YAML 前置元数据分隔符（必须至少有两个 --- 行）
    local separator_count
    separator_count=$(grep -c '^---$' "$state_file" 2>/dev/null || echo "0")
    if [[ "$separator_count" -lt 2 ]]; then
        echo "Error: Missing YAML frontmatter separators (---)" >&2
        return 2
    fi

    # 提取前置元数据并解析所有字段（重用共享辅助函数，不应用默认值）
    STATE_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$state_file" 2>/dev/null || echo "")
    _parse_state_fields

    # 验证必需字段存在
    if [[ -z "$STATE_CURRENT_ROUND" ]]; then
        echo "Error: Missing required field: current_round" >&2
        return 3
    fi
    if [[ -z "$STATE_MAX_ITERATIONS" ]]; then
        echo "Error: Missing required field: max_iterations" >&2
        return 3
    fi
    if [[ -z "$STATE_REVIEW_STARTED" ]]; then
        echo "Error: Missing required field: review_started" >&2
        return 3
    fi
    if [[ -z "$STATE_BASE_BRANCH" ]]; then
        echo "Error: Missing required field: base_branch" >&2
        return 3
    fi

    # 验证 current_round 是数字（包括 0 和负数）
    if ! [[ "$STATE_CURRENT_ROUND" =~ ^-?[0-9]+$ ]]; then
        echo "Error: Non-numeric current_round value: $STATE_CURRENT_ROUND" >&2
        return 4
    fi

    # 验证 max_iterations 是数字
    if ! [[ "$STATE_MAX_ITERATIONS" =~ ^-?[0-9]+$ ]]; then
        echo "Error: Non-numeric max_iterations value: $STATE_MAX_ITERATIONS" >&2
        return 5
    fi

    # 验证 review_started 是布尔值
    if [[ "$STATE_REVIEW_STARTED" != "true" && "$STATE_REVIEW_STARTED" != "false" ]]; then
        echo "Error: Invalid review_started value (must be true or false): $STATE_REVIEW_STARTED" >&2
        return 6
    fi

    # 仅对可选字段应用默认值
    STATE_PUSH_EVERY_ROUND="${STATE_PUSH_EVERY_ROUND:-false}"
    STATE_FULL_REVIEW_ROUND="${STATE_FULL_REVIEW_ROUND:-5}"
    STATE_ASK_CODEX_QUESTION="${STATE_ASK_CODEX_QUESTION:-true}"
    STATE_AGENT_TEAMS="${STATE_AGENT_TEAMS:-false}"
    STATE_PRIVACY_MODE="${STATE_PRIVACY_MODE:-true}"
    STATE_STRICT_SUCCESS="${STATE_STRICT_SUCCESS:-false}"
    STATE_MAINLINE_STALL_COUNT="${STATE_MAINLINE_STALL_COUNT:-0}"
    STATE_LAST_MAINLINE_VERDICT="${STATE_LAST_MAINLINE_VERDICT:-$MAINLINE_VERDICT_UNKNOWN}"
    STATE_DRIFT_STATUS="${STATE_DRIFT_STATUS:-$DRIFT_STATUS_NORMAL}"

    return 0
}

# 将主线进度裁决规范化为安全枚举。
# 用法：normalize_mainline_progress_verdict "ADVANCED"
normalize_mainline_progress_verdict() {
    local verdict_lower
    verdict_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    case "$verdict_lower" in
        "$MAINLINE_VERDICT_ADVANCED"|"$MAINLINE_VERDICT_STALLED"|"$MAINLINE_VERDICT_REGRESSED")
            echo "$verdict_lower"
            ;;
        *)
            echo "$MAINLINE_VERDICT_UNKNOWN"
            ;;
    esac
}

# 将漂移状态规范化为安全枚举。
# 用法：normalize_drift_status "replan_required"
normalize_drift_status() {
    local status_lower
    status_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    case "$status_lower" in
        "$DRIFT_STATUS_REPLAN_REQUIRED")
            echo "$DRIFT_STATUS_REPLAN_REQUIRED"
            ;;
        *)
            echo "$DRIFT_STATUS_NORMAL"
            ;;
    esac
}

# 从 Codex 审查内容中提取"主线进度裁决"。
# 输出以下之一：advanced、stalled、regressed、unknown
# 用法：extract_mainline_progress_verdict "$review_content"
extract_mainline_progress_verdict() {
    local review_content="$1"
    local verdict_line
    local verdict_value

    verdict_line=$(printf '%s\n' "$review_content" | grep -Ei 'Mainline Progress Verdict:[[:space:]]*(ADVANCED|STALLED|REGRESSED)([^A-Za-z]|$)' | tail -1 || true)
    if [[ -z "$verdict_line" ]]; then
        echo "$MAINLINE_VERDICT_UNKNOWN"
        return
    fi

    # 使用 grep -oEi（可移植）而不是 sed /I（仅 GNU）提取裁决词。
    # 前面的 grep -Ei 已经确保行包含三个裁决之一。
    # 拒绝包含多个裁决关键字的行（例如占位符模板格式），
    # 以避免静默接受模糊的裁决。
    local _verdict_matches
    _verdict_matches=$(printf '%s\n' "$verdict_line" | grep -oEi 'ADVANCED|STALLED|REGRESSED')
    local _match_count
    _match_count=$(printf '%s\n' "$_verdict_matches" | wc -l)
    if [[ "$_match_count" -gt 1 ]]; then
        echo "$MAINLINE_VERDICT_UNKNOWN"
        return
    fi
    verdict_value=$(printf '%s\n' "$_verdict_matches" | head -1)
    normalize_mainline_progress_verdict "$verdict_value"
}

# 在状态文件中更新插入简单的 YAML 前置元数据字段。
# 值不得包含换行符。
# 用法：upsert_state_fields "/path/to/state.md" "field=value" "other=value"
upsert_state_fields() {
    local state_file="$1"
    shift

    local temp_file="${state_file}.tmp.$$"

    awk -v assignments="$*" '
        BEGIN {
            count = split(assignments, pairs, " ");
            for (i = 1; i <= count; i++) {
                eq = index(pairs[i], "=");
                key = substr(pairs[i], 1, eq - 1);
                val = substr(pairs[i], eq + 1);
                keys[key] = val;
                order[i] = key;
            }
            separator_count = 0;
        }
        {
            if ($0 == "---") {
                separator_count++;
                if (separator_count == 2) {
                    for (i = 1; i <= count; i++) {
                        key = order[i];
                        if (!(key in seen)) {
                            print key ": " keys[key];
                            seen[key] = 1;
                        }
                    }
                }
                print;
                next;
            }

            handled = 0;
            for (i = 1; i <= count; i++) {
                key = order[i];
                if ($0 ~ ("^" key ":")) {
                    print key ": " keys[key];
                    seen[key] = 1;
                    handled = 1;
                    break;
                }
            }

            if (!handled) {
                print;
            }
        }
    ' "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
}

# 从 codex review 日志文件中检测审查问题
# 返回：
#   0 - 发现问题（调用者应继续审查循环）
#   1 - 未发现问题（调用者可以继续到 finalize）
#   2 - 日志文件缺失/为空（硬错误 - 调用者必须阻止并要求重试）
# 输出：如果发现问题，将提取的审查内容输出到 stdout
# 参数：$1=轮次编号
# 必需的全局变量：LOOP_DIR、CACHE_DIR
#
# 算法：
# 1. 扫描日志文件的最后 50 行，查找每行前 10 个字符中的 [P?] 标记。
#    真正的审查问题只出现在日志末尾附近；扫描整个文件可能会因
#    早期调试输出产生误报，并且在非常大的日志上可能遇到参数列表过长限制。
# 2. 找到第一个在前 10 个字符中出现 [P?]（? 是数字）的行。
# 3. 如果找到：从该行提取到末尾并输出。
# 4. 如果未找到：无问题，返回 1。
#
# 注意：codex review 输出到 stderr，因此我们分析包含 stdout 和 stderr
# （用 2>&1 重定向）的组合日志文件。
detect_review_issues() {
    local round="$1"
    local log_file="$CACHE_DIR/round-${round}-codex-review.log"
    local result_file="$LOOP_DIR/round-${round}-review-result.md"

    # 检查日志文件是否存在且非空
    if [[ ! -f "$log_file" || ! -s "$log_file" ]]; then
        echo "Error: Codex review log file not found or empty: $log_file" >&2
        return 2
    fi

    local total_lines
    total_lines=$(wc -l < "$log_file")
    echo "Analyzing log file: $log_file ($total_lines lines)" >&2

    # 仅扫描最后 50 行 - 真正的问题总是出现在末尾附近
    local scan_lines=50
    local start_line=$((total_lines > scan_lines ? total_lines - scan_lines + 1 : 1))

    # 使用 awk 在 tail 上查找前 10 个字符中出现 [P?] 的第一行
    local relative_line
    relative_line=$(tail -n "$scan_lines" "$log_file" | awk '
        substr($0, 1, 10) ~ /\[P[0-9]\]/ {
            print NR
            exit
        }
    ')

    if [[ -n "$relative_line" && "$relative_line" -gt 0 ]]; then
        # 将相对行（在 tail 内）转换为完整文件中的绝对行
        local found_line=$((start_line + relative_line - 1))
        echo "Found [P?] issue at line $found_line" >&2

        # 从 found_line 提取到末尾
        local extracted_content
        extracted_content=$(sed -n "${found_line},\$p" "$log_file")

        # 保存到结果文件以供审计
        printf '%s\n' "$extracted_content" > "$result_file"
        echo "Review issues extracted to: $result_file" >&2

        # 为调用者输出内容
        printf '## Codex Review Issues\n\n%s\n' "$extracted_content"
        return 0
    fi

    echo "No [P?] issues found in log file" >&2
    return 1
}

# 将字符串转换为小写
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# 检查路径（小写）是否匹配轮次文件模式
# 用法：is_round_file "$lowercase_path" "summary|prompt|todos|contract"
is_round_file_type() {
    local path_lower="$1"
    local file_type="$2"

    echo "$path_lower" | grep -qE "round-[0-9]+-${file_type}\\.md\$"
}

# 从文件名中提取轮次编号
# 用法：extract_round_number "round-5-summary.md"
# 输出轮次编号或空字符串
extract_round_number() {
    local filename="$1"
    local filename_lower
    filename_lower=$(to_lower "$filename")

    # 使用 ERE（-E）以便 | 交替在 GNU 和 BSD sed（macOS）上都能工作
    echo "$filename_lower" | sed -En 's/.*round-([0-9]+)-(summary|prompt|todos|contract)\.md$/\1/p'
}

# 检查文件是否在活跃循环的允许列表中
# 用法：is_allowlisted_file "$file_path" "$active_loop_dir"
# 返回：0 如果在允许列表中，否则返回 1
is_allowlisted_file() {
    local file_path="$1"
    local active_loop_dir="$2"

    # 规范化两个路径以解析符号链接（例如 /var -> /private/var 在 macOS 上）。
    local canonical_file canonical_loop
    canonical_file=$(canonicalize_path "$file_path" 2>/dev/null || echo "$file_path")
    canonical_loop=$(canonicalize_path "$active_loop_dir" 2>/dev/null || echo "$active_loop_dir")

    local allowlist=(
        "round-1-todos.md"
        "round-2-todos.md"
        "round-0-summary.md"
        "round-1-summary.md"
    )

    for allowed in "${allowlist[@]}"; do
        if [[ "$canonical_file" == "$canonical_loop/$allowed" ]]; then
            return 0
        fi
    done

    return 1
}

# 阻止 todos 文件访问的标准消息
# 用法：todos_blocked_message "Read|Write|Bash"
todos_blocked_message() {
    local action="$1"
    local fallback="# Todos File Access Blocked

Do NOT create or access round-*-todos.md files. Use the native Task tools instead (TaskCreate, TaskUpdate, TaskList)."

    load_and_render_safe "$TEMPLATE_DIR" "block/todos-file-access.md" "$fallback"
}

# 阻止提示文件写入的标准消息
prompt_write_blocked_message() {
    local fallback="# Prompt File Write Blocked

You cannot write to round-*-prompt.md files. These contain instructions FROM Codex TO you."

    load_and_render_safe "$TEMPLATE_DIR" "block/prompt-file-write.md" "$fallback"
}

# 阻止状态文件修改的标准消息
state_file_blocked_message() {
    local fallback="# State File Modification Blocked

You cannot modify state.md. This file is managed by the loop system."

    load_and_render_safe "$TEMPLATE_DIR" "block/state-file-modification.md" "$fallback"
}

# 阻止 finalize-state 文件修改的标准消息
finalize_state_file_blocked_message() {
    local fallback="# Finalize State File Modification Blocked

You cannot modify finalize-state.md. This file is managed by the loop system during the Finalize Phase."

    load_and_render_safe "$TEMPLATE_DIR" "block/finalize-state-file-modification.md" "$fallback"
}

# 在 Finalize 阶段阻止轮次合同访问的标准消息
# 用法：finalize_contract_blocked_message "read"
finalize_contract_blocked_message() {
    local action="$1"
    local fallback="# Finalize Contract Access Blocked

There is no active round contract during the Finalize Phase.

Do not {{ACTION}} historical round contract files.
Use finalize-summary.md for finalize-only notes and goal-tracker.md for current state."

    load_and_render_safe "$TEMPLATE_DIR" "block/finalize-contract-access.md" "$fallback" \
        "ACTION=$action"
}

# 通过 Bash 阻止摘要文件修改的标准消息
# 用法：summary_bash_blocked_message "$correct_summary_path"
summary_bash_blocked_message() {
    local correct_path="$1"
    local fallback="# Bash Write Blocked

Do not use Bash commands to modify summary files. Use the Write or Edit tool instead: {{CORRECT_PATH}}"

    load_and_render_safe "$TEMPLATE_DIR" "block/summary-bash-write.md" "$fallback" "CORRECT_PATH=$correct_path"
}

# 在第 0 轮通过 Bash 阻止目标跟踪器修改的标准消息
# 用法：goal_tracker_bash_blocked_message "$correct_goal_tracker_path"
goal_tracker_bash_blocked_message() {
    local correct_path="$1"
    local fallback="# Bash Write Blocked

Do not use Bash commands to modify goal-tracker.md. Use the Write or Edit tool instead: {{CORRECT_PATH}}"

    load_and_render_safe "$TEMPLATE_DIR" "block/goal-tracker-bash-write.md" "$fallback" "CORRECT_PATH=$correct_path"
}

# 检查路径（小写）是否指向 goal-tracker.md
is_goal_tracker_path() {
    local path_lower="$1"
    echo "$path_lower" | grep -qE 'goal-tracker\.md$'
}

# 从目标跟踪器内容流中提取不可变部分。
# 支持当前跟踪器（带 --- 分隔符）和直接从 IMMUTABLE SECTION
# 跳到 MUTABLE SECTION 的较旧跟踪器。
extract_goal_tracker_immutable_from_stream() {
    awk '
        /^## IMMUTABLE SECTION[[:space:]]*$/ { capture=1 }
        capture && /^## MUTABLE SECTION[[:space:]]*$/ { exit }
        capture && /^---[[:space:]]*$/ { exit }
        capture { print }
    '
}

# 从磁盘上的目标跟踪器文件中提取不可变部分。
# 用法：extract_goal_tracker_immutable_from_file "/path/to/goal-tracker.md"
extract_goal_tracker_immutable_from_file() {
    local tracker_file="$1"
    if [[ ! -f "$tracker_file" ]]; then
        return 1
    fi
    extract_goal_tracker_immutable_from_stream < "$tracker_file"
}

# 从内存中的目标跟踪器字符串中提取不可变部分。
# 用法：extract_goal_tracker_immutable_from_text "$content"
extract_goal_tracker_immutable_from_text() {
    local tracker_content="$1"
    printf '%s' "$tracker_content" | extract_goal_tracker_immutable_from_stream
}

# 检查提议的目标跟踪器更新是否保留了不可变部分。
# 用法：goal_tracker_mutable_update_allowed "/path/to/current.md" "$new_content"
goal_tracker_mutable_update_allowed() {
    local tracker_file="$1"
    local updated_content="$2"

    local current_immutable=""
    local updated_immutable=""
    current_immutable=$(extract_goal_tracker_immutable_from_file "$tracker_file" 2>/dev/null || true)
    updated_immutable=$(extract_goal_tracker_immutable_from_text "$updated_content" 2>/dev/null || true)

    # 没有 IMMUTABLE SECTION 的旧跟踪器：无条件允许编辑。
    [[ -n "$current_immutable" ]] || return 0
    [[ "$current_immutable" == "$updated_immutable" ]]
}

# 为字面 Edit 操作渲染编辑后的内容。
# 如果无法生成编辑预览则返回非零。
# 用法：preview_edit_result "/path/to/file" "$old_string" "$new_string" "true|false"
preview_edit_result() {
    local file_path="$1"
    local old_string="$2"
    local new_string="$3"
    local replace_all="${4:-false}"

    command -v perl >/dev/null 2>&1 || return 1

    FILE_PATH="$file_path" \
    OLD_STRING="$old_string" \
    NEW_STRING="$new_string" \
    REPLACE_ALL="$replace_all" \
    perl -0pe '
        BEGIN {
            $old = $ENV{"OLD_STRING"};
            $new = $ENV{"NEW_STRING"};
            $replace_all = $ENV{"REPLACE_ALL"} eq "true";
        }
        if ($replace_all) {
            s/\Q$old\E/$new/g;
        } else {
            s/\Q$old\E/$new/;
        }
    ' "$file_path"
}

# 检查路径（小写）是否指向 state.md
is_state_file_path() {
    local path_lower="$1"
    echo "$path_lower" | grep -qE 'state\.md$'
}

# 检查路径（小写）是否指向 finalize-state.md
is_finalize_state_file_path() {
    local path_lower="$1"
    echo "$path_lower" | grep -qE 'finalize-state\.md$'
}

# 检查路径（小写）是否指向 methodology-analysis-state.md
is_methodology_analysis_state_file_path() {
    local path_lower="$1"
    echo "$path_lower" | grep -qE 'methodology-analysis-state\.md$'
}

# 阻止 methodology-analysis-state 文件修改的标准消息
methodology_analysis_state_file_blocked_message() {
    local fallback="# Methodology Analysis State File Modification Blocked

You cannot modify methodology-analysis-state.md. This file is managed by the loop system during the Methodology Analysis Phase."

    load_and_render_safe "$TEMPLATE_DIR" "block/methodology-analysis-state-file-modification.md" "$fallback"
}

# 检查路径（小写）是否指向 finalize-summary.md
is_finalize_summary_path() {
    local path_lower="$1"
    echo "$path_lower" | grep -qE 'finalize-summary\.md$'
}

# 通过移除 /./ 和将 // 折叠为 / 来规范化路径
# 这允许像 /path/to/./state.md 这样的路径匹配 /path/to/state.md
_normalize_path() {
    echo "$1" | sed 's|/\./|/|g; s|//|/|g'
}

# 检查取消操作是否通过信号文件授权
# 用法：is_cancel_authorized "$active_loop_dir" "$command_lower"
# 返回：0 如果已授权，否则返回非零
#   1 - 缺少信号文件
#   2 - 安全违规（注入、命令替换等）
#   3 - 混合引号样式
#   4 - 多个尾随空格
#   5 - 无效的命令结构
#   6 - 源文件是符号链接（文件系统检查）
#
# 安全说明：
# - 在验证之前将 $loop_dir/${loop_dir} 规范化为实际路径
# - 拒绝 $(cmd) 命令替换和反引号
# - 拒绝规范化后的任何剩余 $（防止隐藏变量如 ${IFS}）
# - 强制恰好两个参数：state.md 或 finalize-state.md 源和 cancel-state.md 目标
# - 拒绝用于命令链接的 shell 运算符
# - 拒绝混合引号样式和多个尾随空格
# - 如果源文件是符号链接则拒绝
is_cancel_authorized() {
    local active_loop_dir="$1"
    local command_lower="$2"

    local cancel_signal="$active_loop_dir/.cancel-requested"

    # 信号文件必须存在
    if [[ ! -f "$cancel_signal" ]]; then
        return 1
    fi

    # 安全性：拒绝命令替换和反引号
    if echo "$command_lower" | grep -qE '\$\(|`'; then
        return 2
    fi

    # 拒绝换行符（多命令注入）
    if [[ "$command_lower" == *$'\n'* ]]; then
        return 2
    fi

    # 拒绝用于命令链接的 shell 运算符
    if echo "$command_lower" | grep -qE ';|&&|\|\||\|'; then
        return 2
    fi

    # 拒绝多个尾随空格
    if echo "$command_lower" | grep -qE '[[:space:]]{2,}$'; then
        return 4
    fi

    # 规范化循环目录（幂等：resolve_project_root 已经规范化，
    # 但调用者可能提供非规范化的覆盖）。即将到来的字符串比较的两侧
    # 必须通过相同的转换规范化，否则用户命令中的符号链接前缀
    # （例如 /var/... vs /private/var/... 在 macOS 上）将虚假失败授权检查。
    local canonical_loop_dir
    canonical_loop_dir="$(canonicalize_path "${active_loop_dir%/}")"
    canonical_loop_dir="${canonical_loop_dir:-${active_loop_dir%/}}"

    # 规范化：将 $loop_dir 和 ${loop_dir} 替换为实际路径
    local normalized="$command_lower"
    local loop_dir_lower
    loop_dir_lower="${canonical_loop_dir}/"
    loop_dir_lower=$(echo "$loop_dir_lower" | tr '[:upper:]' '[:lower:]')

    normalized="${normalized//\$\{loop_dir\}/$loop_dir_lower}"
    normalized="${normalized//\$loop_dir/$loop_dir_lower}"

    # 规范化后，拒绝任何剩余的 $（防止隐藏变量如 ${IFS}）
    if echo "$normalized" | grep -qE '\$'; then
        return 2
    fi

    # 必须以 mv 开头后跟空格
    if ! echo "$normalized" | grep -qE '^mv[[:space:]]+'; then
        return 5
    fi

    # 提取 "mv " 之后的参数
    local args
    args=$(echo "$normalized" | sed 's/^mv[[:space:]]*//')

    # 检测两个参数中使用的引号类型
    # 通过检测 ' 和 " 是否都用作分隔符来检查混合引号
    local has_single=false has_double=false
    local first_char
    first_char=$(echo "$args" | cut -c1)
    if [[ "$first_char" == '"' ]]; then
        has_double=true
    elif [[ "$first_char" == "'" ]]; then
        has_single=true
    fi

    # 跳过第一个参数以检查第二个
    local args_after_first
    if [[ "$first_char" == '"' ]]; then
        args_after_first=$(echo "$args" | sed 's/^"[^"]*"[[:space:]]*//')
    elif [[ "$first_char" == "'" ]]; then
        args_after_first=$(echo "$args" | sed "s/^'[^']*'[[:space:]]*//")
    else
        args_after_first=$(echo "$args" | sed 's/^[^[:space:]]*[[:space:]]*//')
    fi

    local second_char
    second_char=$(echo "$args_after_first" | cut -c1)
    if [[ "$second_char" == '"' ]]; then
        has_double=true
    elif [[ "$second_char" == "'" ]]; then
        has_single=true
    fi

    # 拒绝混合引号样式
    if [[ "$has_single" == "true" ]] && [[ "$has_double" == "true" ]]; then
        return 3
    fi

    # 解析参数，尊重引号
    local src dest
    if echo "$args" | grep -qE "^[\"']"; then
        local quote_char
        quote_char=$(echo "$args" | cut -c1)
        if [[ "$quote_char" == '"' ]]; then
            src=$(echo "$args" | sed -n 's/^"\([^"]*\)".*/\1/p')
            args=$(echo "$args" | sed 's/^"[^"]*"[[:space:]]*//')
        else
            src=$(echo "$args" | sed -n "s/^'\\([^']*\\)'.*/\\1/p")
            args=$(echo "$args" | sed "s/^'[^']*'[[:space:]]*//")
        fi
    else
        src=$(echo "$args" | sed 's/[[:space:]].*//')
        args=$(echo "$args" | sed 's/^[^[:space:]]*[[:space:]]*//')
    fi

    if echo "$args" | grep -qE "^[\"']"; then
        local quote_char
        quote_char=$(echo "$args" | cut -c1)
        if [[ "$quote_char" == '"' ]]; then
            dest=$(echo "$args" | sed -n 's/^"\([^"]*\)".*/\1/p')
            args=$(echo "$args" | sed 's/^"[^"]*"[[:space:]]*//')
        else
            dest=$(echo "$args" | sed -n "s/^'\\([^']*\\)'.*/\\1/p")
            args=$(echo "$args" | sed "s/^'[^']*'[[:space:]]*//")
        fi
    else
        dest=$(echo "$args" | sed 's/[[:space:]].*//')
        args=$(echo "$args" | sed 's/^[^[:space:]]*//')
    fi

    if [[ -z "$src" ]] || [[ -z "$dest" ]]; then
        return 5
    fi

    # 检查额外参数
    args=$(echo "$args" | sed 's/^[[:space:]]*//')
    if [[ -n "$args" ]]; then
        return 5
    fi

    # 规范化和验证源路径。
    #
    # 使用 canonicalize_path_prefix（不是 canonicalize_path）：我们需要解析
    # 父目录中的符号链接，以便符号链接的项目前缀匹配 canonical_loop_dir，
    # 但我们不能取消引用叶子处的符号链接。否则像 /tmp/alias -> <loop>/state.md
    # 这样的符号链接会规范化为 <loop>/state.md 并通过检查，但 `mv` 会操作
    # 链接路径本身，逃离循环目录和/或损坏循环状态。下面的磁盘符号链接拒绝
    # （src_original 检查）仍然触发，因为它探测 canonical_loop_dir 下的真实 state.md。
    #
    # 规范化后重新小写，因为在不区分大小写的文件系统上 realpath 可能
    # 恢复路径组件的原始大小写，这将与已经小写的 expected_* 值不同。
    src=$(_normalize_path "$src")
    local src_canonical
    src_canonical="$(canonicalize_path_prefix "$src")"
    src_canonical="${src_canonical:-$src}"
    src_canonical=$(echo "$src_canonical" | tr '[:upper:]' '[:lower:]')
    local expected_src_state="${loop_dir_lower}state.md"
    local expected_src_finalize="${loop_dir_lower}finalize-state.md"
    local expected_src_methodology="${loop_dir_lower}methodology-analysis-state.md"
    if [[ "$src_canonical" != "$expected_src_state" ]] && [[ "$src_canonical" != "$expected_src_finalize" ]] && [[ "$src_canonical" != "$expected_src_methodology" ]]; then
        return 5
    fi

    # 规范化和验证目标路径。使用 canonicalize_path_prefix，
    # 原因与 src 相同：指向真实 cancel-state.md 的符号链接别名
    # 不能通过授权，因为 `mv` 到符号链接会替换链接而不是创建
    # <loop>/cancel-state.md，损坏循环状态并将 state.md 移出循环目录。
    dest=$(_normalize_path "$dest")
    local dest_canonical
    dest_canonical="$(canonicalize_path_prefix "$dest")"
    dest_canonical="${dest_canonical:-$dest}"
    dest_canonical=$(echo "$dest_canonical" | tr '[:upper:]' '[:lower:]')
    local expected_dest="${loop_dir_lower}cancel-state.md"
    if [[ "$dest_canonical" != "$expected_dest" ]]; then
        return 5
    fi

    # 安全性：如果源文件是符号链接则拒绝（文件系统检查）
    # 通过与预期路径比较（不是子字符串匹配）确定源文件
    # 这避免了当循环目录路径包含 "finalize" 或 "methodology" 时的漏洞
    # 使用 canonical_loop_dir 以便符号链接检查针对真实的磁盘路径
    # 而不是用户提供的非规范形式。
    local src_original
    if [[ "$src_canonical" == "$expected_src_methodology" ]]; then
        src_original="${canonical_loop_dir}/methodology-analysis-state.md"
    elif [[ "$src_canonical" == "$expected_src_finalize" ]]; then
        src_original="${canonical_loop_dir}/finalize-state.md"
    else
        src_original="${canonical_loop_dir}/state.md"
    fi
    if [[ -L "$src_original" ]]; then
        return 6  # Source is a symlink
    fi

    return 0
}

# 检查路径是否在 .humanize/rlcr 目录内
is_in_humanize_loop_dir() {
    local path="$1"
    echo "$path" | grep -q '\.humanize/rlcr/'
}

# 检查 git add 命令是否会将 .humanize 文件添加到版本控制
# 用法：git_adds_humanize "$command_lower"
# 如果命令会添加 .humanize 文件则返回 0，否则返回 1
#
# 重要：此函数从验证器接收小写输入。
# Git 标志如 -A 在小写后变成 -a，因此我们匹配两者。
#
# 处理：
# - git -C <dir> add（add 子命令之前的 git 选项）
# - 链式命令：cd repo && git add .humanize
# - Shell 运算符：;、&&、||、|
#
# 阻止：
# - git add .humanize 或 git add .humanize/
# - git add .humanize/* 或 git add .humanize/**
# - git add -f .humanize*（强制添加）
# - git add -f . 或 git add --force .（强制添加全部 - 绕过 gitignore）
# - git add -f -A 或 git add --force --all（强制添加全部）
# - git add -fA 或类似的组合标志
# - git add -A 或 git add --all（当 .humanize 存在时）
# - git add . 或 git add *（当 .humanize 存在且未被 gitignore 时）
#
git_adds_humanize() {
    local cmd="$1"

    # 按 shell 运算符拆分命令并检查每个段
    # 这处理链式命令，如：cd repo && git add .humanize
    local segments
    segments=$(echo "$cmd" | sed '
        s/&&/\n/g
        s/||/\n/g
        s/|/\n/g
        s/;/\n/g
    ')

    while IFS= read -r segment; do
        [[ -z "$segment" ]] && continue

        # 检查此段是否包含 git add 命令
        # 模式：git（带可选标志/选项）后跟 add
        # 处理：
        # - git add
        # - git -C dir add（带单独参数的短选项）
        # - git --git-dir=x add（带 = 参数的长选项）
        # - git -c key=value add（带 = 参数的短选项）
        # 模式允许 git 和 add 之间的任何非 add 令牌
        if ! echo "$segment" | grep -qE '(^|[[:space:]])git[[:space:]]+([^[:space:]]+[[:space:]]+)*add([[:space:]]|$)'; then
            continue
        fi

        # 提取 "add" 之后的部分进行分析
        local add_args
        add_args=$(echo "$segment" | sed -n 's/.*[[:space:]]add[[:space:]]*//p')

        # 规范化 add_args：为路径匹配剥离引号
        # 这处理：git add ".humanize"、git add '.humanize'
        local add_args_normalized
        add_args_normalized=$(echo "$add_args" | sed "s/[\"']//g")

        # 检查直接的 .humanize 引用（无论其他标志如何都被阻止）
        # 处理：.humanize、./.humanize、path/to/.humanize、".humanize"、'.humanize'
        # 模式在开头、空格后、/ 或 ./ 后匹配 .humanize，且后跟结尾、/ 或空格
        # 这避免了过度阻止 .humanizeconfig 或 .humanize-backup。
        if echo "$add_args_normalized" | grep -qE '(^|[[:space:]]|/)\.humanize($|/|[[:space:]])'; then
            return 0
        fi

        # 检查 -f 或 --force 标志（包括组合标志如 -fa、-af）
        local has_force=false
        if echo "$add_args" | grep -qE '(^|[[:space:]])--force([[:space:]]|$)'; then
            has_force=true
        elif echo "$add_args" | grep -qE '(^|[[:space:]])-[a-z]*f[a-z]*([[:space:]]|$)'; then
            has_force=true
        fi

        # 检查 -A/--all 标志（包括组合标志如 -fa、-af）
        # 注意：输入是小写的，所以 -A 变成 -a
        local has_all=false
        if echo "$add_args" | grep -qE '(^|[[:space:]])--all([[:space:]]|$)'; then
            has_all=true
        elif echo "$add_args" | grep -qE '(^|[[:space:]])-[a-z]*a[a-z]*([[:space:]]|$)'; then
            has_all=true
        fi

        # 检查广泛范围目标：单独的 . 或 *
        local has_broad_scope=false
        if echo "$add_args" | grep -qE '(^|[[:space:]])(\.|\*)([[:space:]]|$)'; then
            has_broad_scope=true
        fi

        # 强制添加任何广泛范围（强制完全绕过 gitignore）
        if [[ "$has_force" == "true" ]]; then
            if [[ "$has_all" == "true" ]] || [[ "$has_broad_scope" == "true" ]]; then
                return 0
            fi
        fi

        # 检查 .humanize 是否存在 - 非强制阻止需要
        if [[ ! -d ".humanize" ]]; then
            continue
        fi

        # 当 .humanize 存在时 git add -A/--all
        # 总是阻止，因为 -A 添加所有更改包括未跟踪的文件
        if [[ "$has_all" == "true" ]]; then
            return 0
        fi

        # 当 .humanize 存在且未被 gitignore 时 git add . 或 git add *
        # 仅在 .humanize 未被 gitignore 保护时阻止
        if [[ "$has_broad_scope" == "true" ]]; then
            if ! git check-ignore -q .humanize 2>/dev/null; then
                return 0
            fi
        fi
    done <<< "$segments"

    return 1
}

# 阻止 git add .humanize 命令的标准消息
# 用法：git_add_humanize_blocked_message
git_add_humanize_blocked_message() {
    local fallback="# Git Add Blocked: .humanize Protection

The \`.humanize/\` directory contains local loop state that should NOT be committed.

Your command was blocked because it would add .humanize files to version control.

## Allowed Commands

Use specific file paths instead of broad patterns:

    git add <specific-file>
    git add src/
    git add -p  # patch mode

## Blocked Commands

These commands are blocked when .humanize exists:

    git add .humanize      # direct reference
    git add -A             # adds all including .humanize
    git add --all          # adds all including .humanize
    git add .              # may include .humanize if not gitignored
    git add -f .           # force bypasses gitignore

## Adding .humanize to .gitignore

If you need to add \`.humanize*\` to \`.gitignore\`, follow these steps:

1. Edit \`.gitignore\` to append \`.humanize*\`
2. Run: \`git add .gitignore\`
3. Run: \`git commit -m \"Add humanize local folder into gitignore\"\`

IMPORTANT: The commit message must NOT contain the literal string \".humanize\" to avoid triggering this protection."

    load_and_render_safe "$TEMPLATE_DIR" "block/git-add-humanize.md" "$fallback"
}

# 如果本地 Humanize 运行时状态已进入 git 跟踪或索引则返回成功。
# 未跟踪的 .humanize 状态是允许的；已跟踪或已暂存的状态必须被阻止。
# 用法：git_has_tracked_humanize_state [project_root]
#
# 故意限定在 .humanize/ 范围内以与 git_adds_humanize 保持一致，
# 它明确允许不相关的路径如 .humanize-backup 或 .humanizeconfig
# （参见 tests/test-humanize-escape.sh）。ls-files 覆盖已提交的条目
# 和通过 git add 暂存的路径；用户已通过 git rm --cached 暂存移除的路径
# 被正确省略，以便用户可以自行解除阻塞而不被重新阻止。
git_has_tracked_humanize_state() {
    local project_root="${1:-.}"

    if [[ ! -d "$project_root/.git" ]] && ! git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1; then
        return 1
    fi

    if git -C "$project_root" ls-files -- .humanize 2>/dev/null | grep -q '.'; then
        return 0
    fi

    return 1
}

# 阻止已跟踪/已暂存的 .humanize 状态的标准消息。
# 用法：git_tracked_humanize_blocked_message
git_tracked_humanize_blocked_message() {
    local fallback="# Tracked Humanize State Blocked

Detected tracked or staged files under \`.humanize/\`.

These files are local Humanize loop state and must remain outside version control.

## Required Fix

1. Remove Humanize state from the index:

       git rm --cached -r .humanize

2. Keep only real project files staged.
3. Retry the stop action after the local state is no longer tracked.

## Important

- Do NOT use \`git add -f\` on Humanize state files.
- Do NOT commit RLCR trackers, round summaries, contracts, or cancel/finalize markers."

    load_and_render_safe "$TEMPLATE_DIR" "block/git-tracked-humanize.md" "$fallback"
}

# 阻止直接执行钩子脚本的标准消息
# 用法：stop_hook_direct_execution_blocked_message
stop_hook_direct_execution_blocked_message() {
    local fallback="# Direct Execution of Hook Scripts Blocked

You are attempting to directly execute a hook script via Bash. This is not allowed during an active loop.

Hook scripts are managed by the hooks system and are triggered automatically at the appropriate time. You should NOT execute them manually.

Simply complete your work and end your response. The hooks system will handle the rest automatically."

    load_and_render_safe "$TEMPLATE_DIR" "block/stop-hook-direct-execution.md" "$fallback"
}

# 检查 shell 命令是否尝试修改匹配给定模式的文件
# 用法：command_modifies_file "$command_lower" "goal-tracker\.md"
# 如果命令尝试修改文件则返回 0，否则返回 1
command_modifies_file() {
    local command_lower="$1"
    local file_pattern="$2"

    local patterns=(
        ">[[:space:]]*[^[:space:]]*${file_pattern}"
        ">>[[:space:]]*[^[:space:]]*${file_pattern}"
        "tee[[:space:]]+(-a[[:space:]]+)?[^[:space:]]*${file_pattern}"
        "sed[[:space:]]+-i[^|]*${file_pattern}"
        "awk[[:space:]]+-i[[:space:]]+inplace[^|]*${file_pattern}"
        "perl[[:space:]]+-[^[:space:]]*i[^|]*${file_pattern}"
        "(mv|cp)[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]*${file_pattern}"
        "rm[[:space:]]+(-[rfv]+[[:space:]]+)?[^[:space:]]*${file_pattern}"
        "dd[[:space:]].*of=[^[:space:]]*${file_pattern}"
        "truncate[[:space:]]+[^|]*${file_pattern}"
        "printf[[:space:]].*>[[:space:]]*[^[:space:]]*${file_pattern}"
        "exec[[:space:]]+[0-9]*>[[:space:]]*[^[:space:]]*${file_pattern}"
    )

    for pattern in "${patterns[@]}"; do
        if echo "$command_lower" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

# 在第 0 轮之后阻止目标跟踪器修改的标准消息
# 用法：goal_tracker_blocked_message "$current_round" "$correct_goal_tracker_path"
goal_tracker_blocked_message() {
    local current_round="$1"
    local correct_path="$2"
    local fallback="# Goal Tracker Update Blocked (Round {{CURRENT_ROUND}})

After Round 0, you may update only the **MUTABLE SECTION** of the active goal tracker.

Use Write or Edit on: {{CORRECT_PATH}}

Rules:
- Keep the **IMMUTABLE SECTION** unchanged
- Do not modify goal-tracker.md via Bash
- Do not write to an old loop session's tracker"

    load_and_render_safe "$TEMPLATE_DIR" "block/goal-tracker-modification.md" "$fallback" \
        "CURRENT_ROUND=$current_round" \
        "CORRECT_PATH=$correct_path"
}

# 通过重命名 state.md 来指示退出原因以结束循环
# 用法：end_loop "$loop_dir" "$state_file" "complete|cancel|maxiter|stop|unexpected"
# 参数：
#   $1 - loop_dir：循环目录的路径
#   $2 - state_file：state.md 文件的路径
#   $3 - reason：complete、cancel、maxiter、stop、unexpected 之一
# 返回：成功时为 0，失败时为 1
end_loop() {
    local loop_dir="$1"
    local state_file="$2"
    local reason="$3"  # complete、cancel、maxiter、stop、unexpected

    # 验证原因
    case "$reason" in
        complete|cancel|maxiter|stop|unexpected)
            ;;
        *)
            echo "Error: Invalid end_loop reason: $reason" >&2
            return 1
            ;;
    esac

    local target_name="${reason}-state.md"

    if [[ -f "$state_file" ]]; then
        mv "$state_file" "$loop_dir/$target_name"
        echo "Loop ended: $reason" >&2
        echo "State preserved as: $loop_dir/$target_name" >&2
        return 0
    else
        echo "Warning: State file not found, cannot end loop" >&2
        return 1
    fi
}

# 源码引入后台任务辅助函数。在底部源码引入，以便上面的每个函数
# 对只需要 loop-common.sh 的调用者可用，而后台感知的调用者
# （stop hook、测试套件）仍然通过 loop-common.sh 的单一源码引入获取后台辅助函数。
#
# _LOOP_COMMON_DIR 在这里设置而不是在文件顶部，因为 loop-bg-tasks.sh
# 与此文件在同一目录中，我们希望无论 loop-common.sh 如何被源码引入都能定位它。
_LOOP_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=loop-bg-tasks.sh
source "$_LOOP_COMMON_DIR/loop-bg-tasks.sh"
