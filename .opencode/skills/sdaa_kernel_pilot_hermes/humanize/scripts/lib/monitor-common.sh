#!/usr/bin/env bash
#
# monitor-common.sh - humanize 监控函数的共享工具
#
# 此文件包含 humanize 监控函数使用的通用函数。
# 它应该由 humanize.sh 导入，而不是直接执行。

# ========================================
# ANSI 颜色常量
# ========================================

# 这些定义为函数以允许动态求值
# （某些终端可能不支持所有颜色）
monitor_color_green() { echo "\033[1;32m"; }
monitor_color_yellow() { echo "\033[1;33m"; }
monitor_color_cyan() { echo "\033[1;36m"; }
monitor_color_magenta() { echo "\033[1;35m"; }
monitor_color_red() { echo "\033[1;31m"; }
monitor_color_reset() { echo "\033[0m"; }
monitor_color_bg() { echo "\033[44m"; }
monitor_color_bold() { echo "\033[1m"; }
monitor_color_dim() { echo "\033[2m"; }
monitor_color_blue() { echo "\033[1;34m"; }

# ========================================
# 文件工具
# ========================================

# 获取文件大小（跨平台: Linux 使用 -c%s, macOS 使用 -f%z）
# 用法: monitor_get_file_size "/path/to/file"
# 返回: 文件大小（字节），如果文件不存在则返回 0
monitor_get_file_size() {
    local file="$1"
    stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0
}

# 按时间戳名称模式（YYYY-MM-DD_HH-MM-SS）查找最新目录
# 用法: monitor_find_latest_session "/path/to/loop/dir"
# 返回: 最新会话目录的路径，如果未找到则返回空字符串
monitor_find_latest_session() {
    local loop_dir="$1"
    local latest_session=""

    if [[ ! -d "$loop_dir" ]]; then
        echo ""
        return
    fi

    # 使用 find 代替 glob 以避免 zsh 的 "no matches found" 错误
    while IFS= read -r session_dir; do
        [[ -z "$session_dir" ]] && continue
        [[ ! -d "$session_dir" ]] && continue

        local session_name=$(basename "$session_dir")
        if [[ "$session_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
            if [[ -z "$latest_session" ]] || [[ "$session_name" > "$(basename "$latest_session")" ]]; then
                latest_session="$session_dir"
            fi
        fi
    done < <(find "$loop_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    echo "$latest_session"
}

# ========================================
# 终端工具
# ========================================

# 设置带有固定表头的分屏视图终端
# 用法: monitor_setup_terminal <header_height>
monitor_setup_terminal() {
    local header_height="$1"

    # 清屏
    clear

    # 设置滚动区域（为状态栏留出顶部行）
    printf "\033[${header_height};%dr" $(tput lines)

    # 将光标移动到滚动区域
    tput cup "$header_height" 0
}

# 恢复终端到正常状态
# 用法: monitor_restore_terminal
monitor_restore_terminal() {
    # 重置滚动区域到全屏
    printf "\033[r"

    # 移动到底部
    tput cup $(tput lines) 0
}

# ========================================
# 信号处理
# ========================================

# 设置信号处理器以实现干净的 Ctrl+C 处理
# 此函数应以清理函数名作为参数调用
#
# 用法: monitor_setup_signal_handlers "cleanup_function_name"
#
# 清理函数应该:
# 1. 设置 cleanup_done 标志以防止多次调用
# 2. 设置 monitor_running=false 以停止循环
# 3. 终止任何后台进程
# 4. 恢复终端状态
#
# 示例清理函数:
#   _cleanup() {
#       [[ "$cleanup_done" == "true" ]] && return
#       cleanup_done=true
#       monitor_running=false
#       trap - INT TERM 2>/dev/null || true
#       [[ -n "$TAIL_PID" ]] && kill "$TAIL_PID" 2>/dev/null
#       monitor_restore_terminal
#       echo "Stopped."
#   }
#
# 注意: 此函数是文档参考。实际的信号设置应在每个监控函数中内联完成，
# 以正确处理局部变量的作用域（cleanup_done、monitor_running 等）。

# ========================================
# 状态颜色辅助函数
# ========================================

# 获取循环状态的颜色代码
# 用法: color=$(monitor_get_status_color "active")
monitor_get_status_color() {
    local status="$1"
    case "$status" in
        active|methodology-analysis) echo "\033[1;32m" ;;  # green
        completed) echo "\033[1;36m" ;;  # cyan
        failed|error|timeout) echo "\033[1;31m" ;;  # red
        cancelled) echo "\033[1;33m" ;;  # yellow
        max-iterations) echo "\033[1;31m" ;;  # red
        unknown) echo "\033[2m" ;;  # dim
        *) echo "\033[1;33m" ;;  # yellow (default for unknown states)
    esac
}

# ========================================
# 状态文件检测
# ========================================

# 在会话目录中查找状态文件
# 返回: state_file_path|loop_status
# - 如果 state.md 存在: 返回 "path/state.md|active"
# - 如果 <STOP_REASON>-state.md 存在: 返回 "path/<file>|<stop_reason>"
# - 如果未找到状态文件: 返回 "|unknown"
#
# 用法: monitor_find_state_file "/path/to/session"
monitor_find_state_file() {
    local session_dir="$1"

    if [[ -z "$session_dir" || ! -d "$session_dir" ]]; then
        echo "|unknown"
        return
    fi

    # 优先级 1: 活跃状态文件表示正在运行的循环
    if [[ -f "$session_dir/methodology-analysis-state.md" ]]; then
        echo "$session_dir/methodology-analysis-state.md|methodology-analysis"
        return
    fi
    if [[ -f "$session_dir/state.md" ]]; then
        echo "$session_dir/state.md|active"
        return
    fi

    # 优先级 2: 查找 <STOP_REASON>-state.md 文件
    # 常见的停止原因: completed, failed, cancelled, timeout, error, approve, maxiter
    local state_file=""
    local stop_reason=""
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ -f "$f" ]]; then
            state_file="$f"
            # 从文件名中提取停止原因（例如 "completed-state.md" -> "completed"）
            local basename=$(basename "$f")
            stop_reason="${basename%-state.md}"
            break
        fi
    done < <(find "$session_dir" -maxdepth 1 -name '*-state.md' -type f 2>/dev/null)

    if [[ -n "$state_file" ]]; then
        echo "$state_file|$stop_reason"
    else
        echo "|unknown"
    fi
}

# ========================================
# YAML Frontmatter 解析
# ========================================

# 从 YAML frontmatter 中提取值
# 用法: monitor_get_yaml_value "key" "/path/to/file.md"
# 返回: 值，如果未找到则返回空字符串
monitor_get_yaml_value() {
    local key="$1"
    local file="$2"

    [[ ! -f "$file" ]] && return

    # 提取 frontmatter（在第一个和第二个 --- 之间）
    local frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$file" 2>/dev/null)

    # 提取键的值
    echo "$frontmatter" | grep -E "^${key}:" | sed "s/${key}: *//" | tr -d '"'
}

# ========================================
# 进度显示辅助函数
# ========================================

# 格式化时间戳以供显示
# 将 ISO 格式（2026-01-18T10:00:00Z）转换为可读格式
# 用法: monitor_format_timestamp "2026-01-18T10:00:00Z"
monitor_format_timestamp() {
    local timestamp="$1"

    if [[ "$timestamp" == "N/A" || -z "$timestamp" ]]; then
        echo "N/A"
        return
    fi

    # 将 ISO 格式转换为更可读的格式
    echo "$timestamp" | sed 's/T/ /; s/Z/ UTC/'
}

# 截断字符串以供显示，添加省略号
# 用法: monitor_truncate_string "long string" <max_length> <direction>
# direction: "start"（保留末尾）或 "end"（保留开头，默认）
monitor_truncate_string() {
    local str="$1"
    local max_len="$2"
    local direction="${3:-end}"

    if [[ ${#str} -le $max_len ]]; then
        echo "$str"
        return
    fi

    if [[ "$direction" == "start" ]]; then
        # 保留末尾，截断开头
        local suffix_len=$((max_len - 3))
        echo "...${str: -$suffix_len}"
    else
        # 保留开头，截断末尾
        local prefix_len=$((max_len - 3))
        echo "${str:0:$prefix_len}..."
    fi
}

# ========================================
# 目标跟踪器解析
# ========================================

# 从 goal-tracker.md 解析问题分解
# 返回: blocking_issues|queued_issues|open_issues
# 用法: parse_goal_tracker_issue_counts "/path/to/goal-tracker.md"
parse_goal_tracker_issue_counts() {
    local tracker_file="$1"
    if [[ ! -f "$tracker_file" ]]; then
        echo "0|0|0"
        return
    fi

    _count_table_rows() {
        local start_pattern="$1"
        local end_pattern="$2"
        local row_count
        row_count=$(sed -n "/${start_pattern}/,/${end_pattern}/p" "$tracker_file" | grep -cE '^\|' || true)
        row_count=${row_count:-0}
        echo $((row_count > 2 ? row_count - 2 : 0))
    }

    local blocking_issues
    local queued_issues
    local open_issues

    blocking_issues=$(_count_table_rows '### Blocking Side Issues' '^###')
    queued_issues=$(_count_table_rows '### Queued Side Issues' '^###')
    open_issues=$((blocking_issues + queued_issues))

    if [[ "$open_issues" -eq 0 ]]; then
        open_issues=$(_count_table_rows '### Open Issues' '^###')
        blocking_issues="$open_issues"
    fi

    echo "${blocking_issues}|${queued_issues}|${open_issues}"
}

# 解析 goal-tracker.md 并返回摘要值
# 返回: total_acs|completed_acs|active_tasks|completed_tasks|deferred_tasks|open_issues|goal_summary
# 用法: parse_goal_tracker "/path/to/goal-tracker.md"
parse_goal_tracker() {
    local tracker_file="$1"
    if [[ ! -f "$tracker_file" ]]; then
        echo "0|0|0|0|0|0|No goal tracker"
        return
    fi

    # 辅助函数：计算 markdown 表格部分的数据行数（总行数减去表头和分隔符）
    _count_table_rows() {
        local start_pattern="$1"
        local end_pattern="$2"
        local row_count
        row_count=$(sed -n "/${start_pattern}/,/${end_pattern}/p" "$tracker_file" | grep -cE '^\|' || true)
        row_count=${row_count:-0}
        echo $((row_count > 2 ? row_count - 2 : 0))
    }

    # 统计验收标准（支持表格和列表格式）
    # 在下一个章节标题（##）处停止，以避免计算其他部分的 AC
    local total_acs
    total_acs=$(sed -n '/### Acceptance Criteria/,/^##/p' "$tracker_file" \
        | grep -cE '(^\|\s*\*{0,2}[A]?[C]-?[0-9]+|^-\s*\*{0,2}[A]?[C]-?[0-9]+)' || true)
    total_acs=${total_acs:-0}

    # 统计活跃任务
    local total_active_section_rows
    local completed_in_active
    local deferred_in_active

    total_active_section_rows=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | grep -cE '^\|' || true)
    total_active_section_rows=${total_active_section_rows:-0}
    local total_active_data_rows=$((total_active_section_rows > 2 ? total_active_section_rows - 2 : 0))

    completed_in_active=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | sed 's/\*\*//g' \
        | grep -ciE '^\|[^|]+\|[^|]+\|[[:space:]]*completed[[:space:]]*\|' || true)
    completed_in_active=${completed_in_active:-0}

    deferred_in_active=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | sed 's/\*\*//g' \
        | grep -ciE '^\|[^|]+\|[^|]+\|[[:space:]]*deferred[[:space:]]*\|' || true)
    deferred_in_active=${deferred_in_active:-0}

    local active_tasks=$((total_active_data_rows - completed_in_active - deferred_in_active))
    [[ "$active_tasks" -lt 0 ]] && active_tasks=0

    # 统计已完成任务
    local completed_tasks
    completed_tasks=$(_count_table_rows '### Completed and Verified' '^###')

    # 统计已验证的 AC（已完成部分中的唯一 AC 条目）
    local completed_acs
    completed_acs=$(sed -n '/### Completed and Verified/,/^###/p' "$tracker_file" \
        | grep -oE '^\|\s*[A]?[C]-?[0-9]+' | sort -u | wc -l | tr -d ' ')
    completed_acs=${completed_acs:-0}

    # 统计已推迟任务
    local deferred_tasks
    deferred_tasks=$(_count_table_rows '### Explicitly Deferred' '^###')

    # 统计未关闭问题（新架构优先使用阻塞/排队的附带问题；旧架构使用 Open Issues）
    local issue_parts_raw
    local open_issues
    issue_parts_raw=$(parse_goal_tracker_issue_counts "$tracker_file")
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        local -a issue_parts
        issue_parts=("${(@s:|:)issue_parts_raw}")
        open_issues="${issue_parts[3]}"
    else
        local -a issue_parts
        IFS='|' read -r -a issue_parts <<< "$issue_parts_raw"
        open_issues="${issue_parts[2]}"
    fi

    # 提取终极目标摘要
    local goal_summary
    goal_summary=$(sed -n '/### Ultimate Goal/,/^###/p' "$tracker_file" \
        | grep -v '^###' | grep -v '^$' | grep -v '^\[To be' \
        | head -1 | sed 's/^[[:space:]]*//' | cut -c1-60)
    goal_summary="${goal_summary:-No goal defined}"

    echo "${total_acs}|${completed_acs}|${active_tasks}|${completed_tasks}|${deferred_tasks}|${open_issues}|${goal_summary}"
}

