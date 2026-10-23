#!/usr/bin/env bash
#
# 免责声明
# ----------
# 作者: Sihao Liu
#
# 这是一个 CLI 工具的状态行脚本，恰好包含了与 Humanize 插件
# 关联的 RLCR 状态字段。它被包含在此仓库中纯粹是为了社区分享。
#
# 按原样提供 -- 仅作为参考和模板。
# 只有最后一个字段（RLCR）与此仓库相关；其余是通用的会话信息。
# Humanize 插件的未来更新通常不会涉及对此脚本的更改。
#
# Claude Code 状态行 - 显示使用信息
# 格式: <model> | [context bar] | $X.XX @ Xh:Ym:Zs

input=$(cat)

# 使用 jq 提取值
get_value() {
    echo "$input" | jq -r "$1 // empty" 2>/dev/null
}

# 将毫秒格式化为 Xh:Ym:Zs
format_duration() {
    local ms=$1
    local total_sec=$((ms / 1000))
    local hours=$((total_sec / 3600))
    local mins=$(((total_sec % 3600) / 60))
    local secs=$((total_sec % 60))
    printf "%dh:%dm:%ds" "$hours" "$mins" "$secs"
}

# 确定会话目录的 RLCR 显示状态
_resolve_rlcr_display() {
    local session_dir="$1"

    if [[ -f "$session_dir/methodology-analysis-state.md" ]]; then
        echo "Analyzing"
    elif [[ -f "$session_dir/finalize-state.md" ]]; then
        echo "Finalizing"
    elif [[ -f "$session_dir/state.md" ]]; then
        echo "Active"
    else
        local terminal_file
        terminal_file=$(ls -1 "$session_dir"/*-state.md 2>/dev/null | head -1)
        if [[ -n "$terminal_file" ]]; then
            local bname
            bname=$(basename "$terminal_file")
            local reason="${bname%-state.md}"
            # 首字母大写（Bash 3 兼容）
            local first_char
            first_char=$(printf '%s' "$reason" | cut -c1 | tr '[:lower:]' '[:upper:]')
            local rest
            rest=$(printf '%s' "$reason" | cut -c2-)
            echo "${first_char}${rest}"
        else
            echo "Off"
        fi
    fi
}

# 获取当前会话的 RLCR 循环状态
# 镜像了 humanize hooks/lib/loop-common.sh 中的 find_active_loop() 逻辑
get_rlcr_status() {
    local rlcr_dir="$1"
    local filter_session_id="$2"

    if [[ ! -d "$rlcr_dir" ]]; then
        echo "Off"
        return
    fi

    # 预扫描: 如果任何状态文件有 session_id，则忽略没有的
    local has_sid_aware=false
    if grep -rqE '^session_id: *.+' "$rlcr_dir"/*/*.md 2>/dev/null; then
        has_sid_aware=true
    fi

    if [[ -z "$filter_session_id" ]]; then
        if ! $has_sid_aware; then
            # 没有会话感知文件: 仅检查最新的目录（僵尸循环保护）
            local newest_dir
            newest_dir=$(ls -1d "$rlcr_dir"/*/ 2>/dev/null | sort -r | head -1)
            if [[ -z "$newest_dir" ]]; then
                echo "Off"
                return
            fi
            _resolve_rlcr_display "${newest_dir%/}"
            return
        fi
        # 存在会话感知文件: 查找最新的会话感知目录
        local dir
        while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            local trimmed="${dir%/}"
            local any_state=""
            if [[ -f "$trimmed/methodology-analysis-state.md" ]]; then
                any_state="$trimmed/methodology-analysis-state.md"
            elif [[ -f "$trimmed/finalize-state.md" ]]; then
                any_state="$trimmed/finalize-state.md"
            elif [[ -f "$trimmed/state.md" ]]; then
                any_state="$trimmed/state.md"
            else
                any_state=$(ls -1 "$trimmed"/*-state.md 2>/dev/null | head -1)
            fi
            [[ -z "$any_state" ]] && continue
            local stored_sid
            stored_sid=$(awk '/^---$/{n++; next} n==1 && /^session_id:/{sub(/^session_id: */, ""); gsub(/ /, ""); print; exit}' "$any_state" 2>/dev/null)
            if [[ -n "$stored_sid" ]]; then
                _resolve_rlcr_display "$trimmed"
                return
            fi
        done < <(ls -1d "$rlcr_dir"/*/ 2>/dev/null | sort -r)
        echo "Off"
        return
    fi

    # 带有 session_id: 从最新到最旧迭代，查找匹配的会话
    local dir
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        local trimmed="${dir%/}"

        # 查找任何状态文件（活跃或终端）
        local any_state=""
        if [[ -f "$trimmed/finalize-state.md" ]]; then
            any_state="$trimmed/finalize-state.md"
        elif [[ -f "$trimmed/state.md" ]]; then
            any_state="$trimmed/state.md"
        else
            any_state=$(ls -1 "$trimmed"/*-state.md 2>/dev/null | head -1)
        fi
        [[ -z "$any_state" ]] && continue

        # 从 YAML frontmatter 中提取存储的 session_id
        local stored_sid
        stored_sid=$(awk '/^---$/{n++; next} n==1 && /^session_id:/{sub(/^session_id: */, ""); gsub(/ /, ""); print; exit}' "$any_state" 2>/dev/null)

        # 当存在会话感知条目时跳过会话无感知条目
        if [[ -z "$stored_sid" ]]; then
            $has_sid_aware && continue
            _resolve_rlcr_display "$trimmed"
            return
        fi
        if [[ "$stored_sid" == "$filter_session_id" ]]; then
            _resolve_rlcr_display "$trimmed"
            return
        fi
    done < <(ls -1d "$rlcr_dir"/*/ 2>/dev/null | sort -r)

    echo "Off"
}

# 获取 RLCR 状态的颜色
get_rlcr_color() {
    case "$1" in
        Active|Finalizing) echo "\e[32m" ;;
        Complete) echo "\e[36m" ;;
        Cancel|Stop|Pause) echo "\e[33m" ;;
        Maxiter|Failed|Timeout) echo "\e[31m" ;;
        Off) echo "\e[2m" ;;
        *) echo "\e[33m" ;;
    esac
}

# 获取所有原始值
MODEL=$(get_value '.model.display_name')
CWD=$(get_value '.cwd')
SESSION_ID=$(get_value '.session_id')
TRANSCRIPT_PATH=$(get_value '.transcript_path')

# 解析会话显示名称（来自 /rename 的 customTitle，或完整的 session_id）
# 主要来源: transcript jsonl（即使在活跃会话期间也有 custom-title 事件）
# 回退: sessions-index.json（可能还没有活跃会话）
get_session_display() {
    local sid="$1"
    local transcript="$2"
    local cwd="$3"
    [[ -z "$sid" ]] && return

    # 解析项目目录名称以进行文件查找
    local proj_dir_name
    proj_dir_name=$(echo "$cwd" | sed 's|[/.]|-|g')

    # 如果未提供 transcript_path，则从项目目录和 session_id 构建
    if [[ -z "$transcript" || ! -f "$transcript" ]]; then
        transcript="$HOME/.claude/projects/${proj_dir_name}/${sid}.jsonl"
    fi

    # 首先尝试 transcript jsonl（对于大文件 grep 比 jq 更快）
    if [[ -f "$transcript" ]]; then
        local title
        title=$(grep '"type":"custom-title"' "$transcript" 2>/dev/null | tail -1 | jq -r '.customTitle // empty' 2>/dev/null)
        if [[ -n "$title" ]]; then
            echo "$title"
            return
        fi
    fi

    # 回退: sessions-index.json（用于恢复的会话，其中 transcript 可能不同）
    local idx_file="$HOME/.claude/projects/${proj_dir_name}/sessions-index.json"
    if [[ -f "$idx_file" ]]; then
        local title
        title=$(jq -r --arg sid "$sid" \
            '(.entries[] | select(.sessionId == $sid) | .customTitle) // empty' \
            "$idx_file" 2>/dev/null)
        if [[ -n "$title" ]]; then
            echo "$title"
            return
        fi
    fi

    # 回退: 完整的 session_id
    echo "$sid"
}

# 从用户设置获取快速模式状态
get_fast_mode() {
    local settings="$HOME/.claude/settings.json"
    if [[ -f "$settings" ]]; then
        local val
        val=$(jq -r '.fastMode // false' "$settings" 2>/dev/null)
        if [[ "$val" == "true" ]]; then
            echo "On"
            return
        fi
    fi
    echo "Off"
}

SESSION_DISPLAY=$(get_session_display "$SESSION_ID" "$TRANSCRIPT_PATH" "$CWD")
FAST_MODE=$(get_fast_mode)

# 获取当前工作目录的 git 分支名称
if [[ -n "$CWD" && -d "$CWD" ]]; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi
BRANCH=${BRANCH:-"?"}
COST=$(get_value '.cost.total_cost_usd')
DURATION=$(get_value '.cost.total_duration_ms')
LINES_ADDED=$(get_value '.cost.total_lines_added')
LINES_REMOVED=$(get_value '.cost.total_lines_removed')

# 格式化费用（2 位小数）
COST_STR=$(printf "%.2f" "${COST:-0}")

# 将持续时间格式化为 h:m:s
DURATION_STR=$(format_duration "${DURATION:-0}")

# 如果为 null/empty 则使用默认值
LINES_ADDED=${LINES_ADDED:-0}
LINES_REMOVED=${LINES_REMOVED:-0}

# 确定 RLCR 状态
if [[ -n "$CWD" && -d "$CWD/.humanize" ]]; then
    RLCR_STATUS=$(get_rlcr_status "$CWD/.humanize/rlcr" "$SESSION_ID")
else
    RLCR_STATUS="Off"
fi
RLCR_COLOR=$(get_rlcr_color "$RLCR_STATUS")

# 获取快速模式状态的颜色
get_fast_color() {
    case "$1" in
        On) echo "\e[33m" ;;   # 黄色 - 注意，这很昂贵
        Off) echo "\e[2m" ;;   # 暗色
    esac
}

FAST_COLOR=$(get_fast_color "$FAST_MODE")

# 构建上下文使用进度条
# 格式: [###60%###|  40%   ]
# 颜色: 剩余 >70% 绿色, 30-70% 黄色, <30% 红色
build_context_bar() {
    local used_pct=${1:-0}
    local remaining_pct=$((100 - used_pct))
    local bar_width=20

    # 根据剩余百分比为剩余部分着色
    local remain_color
    if [[ $remaining_pct -gt 70 ]]; then
        remain_color="\e[32m"    # 绿色
    elif [[ $remaining_pct -ge 30 ]]; then
        remain_color="\e[33m"    # 黄色
    else
        remain_color="\e[31m"    # 红色
    fi

    # 已使用部分: 白色背景 + 黑色前景
    local used_style="\e[47;30m"
    local reset="\e[0m"

    local used_width=$(( (used_pct * bar_width + 50) / 100 ))
    local remain_width=$(( bar_width - used_width ))

    # 构建已使用部分: 带白色背景的空格，百分比标签居中
    local used_label="${used_pct}%"
    local used_str=""
    local i
    for (( i = 0; i < used_width; i++ )); do
        used_str+=" "
    done
    if [[ $used_width -ge ${#used_label} ]]; then
        local offset=$(( (used_width - ${#used_label}) / 2 ))
        used_str="${used_str:0:offset}${used_label}${used_str:offset+${#used_label}}"
    fi

    # 构建剩余部分: 空格，百分比标签居中
    local remain_label="${remaining_pct}%"
    local remain_str=""
    for (( i = 0; i < remain_width; i++ )); do
        remain_str+=" "
    done
    if [[ $remain_width -ge ${#remain_label} ]]; then
        local offset=$(( (remain_width - ${#remain_label}) / 2 ))
        remain_str="${remain_str:0:offset}${remain_label}${remain_str:offset+${#remain_label}}"
    fi

    printf "[%b%s%b|%b%s%b]" "$used_style" "$used_str" "$reset" "$remain_color" "$remain_str" "$reset"
}

CONTEXT_USED=$(get_value '.context_window.used_percentage')
CONTEXT_USED=${CONTEXT_USED:-0}
# Round to integer
CONTEXT_USED=$(printf "%.0f" "$CONTEXT_USED")
CONTEXT_BAR=$(build_context_bar "$CONTEXT_USED")

# 定义颜色
CORAL="\e[38;5;173m"      # Claude 品牌色 - 用于 MODEL
CYAN="\e[36m"             # 信息 - 用于 CWD
YELLOW="\e[33m"           # 用于 BRANCH
GREEN="\e[32m"            # 正向 - 用于 COST 和 LINES_ADDED
RED="\e[31m"              # 负向 - 用于 LINES_REMOVED
BLUE="\e[34m"             # 标签 - 用于 Session
MAGENTA="\e[35m"          # 标签 - 用于 RLCR 和 Fast
RESET="\e[0m"

# 缩短 CWD: 将 $HOME 替换为 ~
TILDE='~'
CWD_SHORT="${CWD/#$HOME/$TILDE}"

# 去除 ANSI 转义序列以获取可见文本长度
strip_ansi() {
    printf '%b' "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# 构建各个字段: 彩色（F）和纯文本（P）对
F1=$(printf "%b%s%b" "$CORAL" "${MODEL:-?}" "$RESET")
P1="${MODEL:-?}"

F2="$CONTEXT_BAR"
P2=$(strip_ansi "$CONTEXT_BAR")

F3=$(printf "%b\$%s%b @ %s" "$GREEN" "$COST_STR" "$RESET" "$DURATION_STR")
P3=$(printf "\$%s @ %s" "$COST_STR" "$DURATION_STR")

F4=$(printf "%b%s%b [%b%s%b]" "$CYAN" "${CWD_SHORT:-?}" "$RESET" "$YELLOW" "$BRANCH" "$RESET")
P4=$(printf "%s [%s]" "${CWD_SHORT:-?}" "$BRANCH")

F5=$(printf "lines: %b+%s%b, %b-%s%b" "$GREEN" "$LINES_ADDED" "$RESET" "$RED" "$LINES_REMOVED" "$RESET")
P5=$(printf "lines: +%s, -%s" "$LINES_ADDED" "$LINES_REMOVED")

F6=$(printf "%bSession:%b %b%s%b" "$MAGENTA" "$RESET" "$CYAN" "${SESSION_DISPLAY:-?}" "$RESET")
P6=$(printf "Session: %s" "${SESSION_DISPLAY:-?}")

F7=$(printf "%bFast:%b %b%s%b" "$MAGENTA" "$RESET" "$FAST_COLOR" "$FAST_MODE" "$RESET")
P7=$(printf "Fast: %s" "$FAST_MODE")

F8=$(printf "%bRLCR:%b %b%s%b" "$MAGENTA" "$RESET" "$RLCR_COLOR" "$RLCR_STATUS" "$RESET")
P8=$(printf "RLCR: %s" "$RLCR_STATUS")

FIELDS=("$F1" "$F2" "$F3" "$F4" "$F5" "$F6" "$F7" "$F8")
PLAINS=("$P1" "$P2" "$P3" "$P4" "$P5" "$P6" "$P7" "$P8")

# 通过 /dev/tty 获取终端宽度（stdin 是管道的，所以 tput/stty 需要真实的 TTY）
TERM_WIDTH=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
TERM_WIDTH=${TERM_WIDTH:-$(tput cols 2>/dev/tty || echo 80)}
MAX_WIDTH=$(( TERM_WIDTH * 75 / 100 ))

# 贪婪地将字段打包到行中，当添加字段超过 MAX_WIDTH 时换行
SEPARATOR=" | "
SEP_WIDTH=${#SEPARATOR}
cur_line=""
cur_plain=""

for i in "${!FIELDS[@]}"; do
    if [[ -z "$cur_line" ]]; then
        cur_line="${FIELDS[$i]}"
        cur_plain="${PLAINS[$i]}"
    elif [[ $(( ${#cur_plain} + SEP_WIDTH + ${#PLAINS[$i]} )) -le $MAX_WIDTH ]]; then
        cur_line="${cur_line}${SEPARATOR}${FIELDS[$i]}"
        cur_plain="${cur_plain}${SEPARATOR}${PLAINS[$i]}"
    else
        printf "%s\n" "$cur_line"
        cur_line="${FIELDS[$i]}"
        cur_plain="${PLAINS[$i]}"
    fi
done
[[ -n "$cur_line" ]] && printf "%s\n" "$cur_line"
