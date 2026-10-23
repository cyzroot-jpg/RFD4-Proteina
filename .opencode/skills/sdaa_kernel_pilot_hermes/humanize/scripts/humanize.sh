#!/usr/bin/env bash
# humanize.sh - Humanize shell 工具
# rc.d 配置的一部分
# 兼容 bash 和 zsh

# 导入共享监控工具（按计划: scripts/lib/monitor-common.sh）
HUMANIZE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$HUMANIZE_SCRIPT_DIR/lib/monitor-common.sh" ]]; then
    source "$HUMANIZE_SCRIPT_DIR/lib/monitor-common.sh"
fi

# 导入共享循环库（提供 DEFAULT_CODEX_MODEL 和其他常量）
HUMANIZE_HOOKS_LIB_DIR="$(cd "$HUMANIZE_SCRIPT_DIR/../hooks/lib" && pwd)"
if [[ -f "$HUMANIZE_HOOKS_LIB_DIR/loop-common.sh" ]]; then
    source "$HUMANIZE_HOOKS_LIB_DIR/loop-common.sh"
fi

# ========================================
# 公共辅助函数（可直接调用以进行测试）
# ========================================

# 将管道分隔的字符串拆分为数组（bash/zsh 兼容）
# 用法: humanize_split_to_array "output_array_name" "value1|value2|value3"
humanize_split_to_array() {
    local arr_name="$1"
    local input="$2"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # zsh: 使用参数扩展按 | 分割
        eval "$arr_name=(\"\${(@s:|:)input}\")"
    else
        # bash: 使用 read -ra
        eval "IFS='|' read -ra $arr_name <<< \"\$input\""
    fi
}

# 从 goal-tracker.md 解析问题分解
# 返回: blocking_issues|queued_issues|open_issues
humanize_parse_goal_tracker_issue_counts() {
    local tracker_file="$1"
    if [[ ! -f "$tracker_file" ]]; then
        echo "0|0|0"
        return
    fi

    _count_table_data_rows() {
        local row_count
        row_count=$(sed -n "/$1/,/$2/p" "$tracker_file" | grep -cE '^\|' || true)
        row_count=${row_count:-0}
        echo $((row_count > 2 ? row_count - 2 : 0))
    }

    local blocking_issues
    local queued_issues
    local open_issues

    blocking_issues=$(_count_table_data_rows '### Blocking Side Issues' '^###')
    queued_issues=$(_count_table_data_rows '### Queued Side Issues' '^###')
    open_issues=$((blocking_issues + queued_issues))

    # 旧版架构只有 Open Issues；为安全起见将其视为阻塞问题。
    if [[ "$open_issues" -eq 0 ]]; then
        open_issues=$(_count_table_data_rows '### Open Issues' '^###')
        blocking_issues="$open_issues"
    fi

    echo "${blocking_issues}|${queued_issues}|${open_issues}"
}

# 解析 goal-tracker.md 并返回摘要值
# 返回: total_acs|completed_acs|active_tasks|completed_tasks|deferred_tasks|open_issues|goal_summary
humanize_parse_goal_tracker() {
    local tracker_file="$1"
    if [[ ! -f "$tracker_file" ]]; then
        echo "0|0|0|0|0|0|No goal tracker"
        return
    fi

    # 辅助函数：计算 markdown 表格部分的数据行数（总行数减去表头和分隔符）
    # 用法: _count_table_data_rows "section_start_pattern" "section_end_pattern"
    _count_table_data_rows() {
        local row_count
        row_count=$(sed -n "/$1/,/$2/p" "$tracker_file" | grep -cE '^\|' || true)
        row_count=${row_count:-0}
        echo $((row_count > 2 ? row_count - 2 : 0))
    }

    # 统计验收标准（支持表格和列表格式）
    # 从该部分提取唯一的 AC 标识符（AC-1、AC-2.5 等），
    # 使用与 completed_acs 相同的方法以保持计数一致
    local total_acs
    total_acs=$(sed -n '/### Acceptance Criteria/,/^---$/p' "$tracker_file" \
        | grep -aoE 'AC-?[0-9]+(\.[0-9]+)?' | sort -u | wc -l | tr -d ' ')
    total_acs=${total_acs:-0}

    # 统计活跃任务（未完成且未推迟的任务）
    # 统计状态为 pending、partial、in_progress、todo 等的任务
    local active_tasks
    local total_active_section_rows
    local completed_in_active
    local deferred_in_active

    # 统计活跃任务部分的总表格行数（包括表头和分隔符）
    total_active_section_rows=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | grep -cE '^\|' || true)
    total_active_section_rows=${total_active_section_rows:-0}
    # 减去表头行和分隔符行（2 行）
    local total_active_data_rows=$((total_active_section_rows > 2 ? total_active_section_rows - 2 : 0))

    # 统计活跃任务部分中已完成的任务（状态列包含 "completed"）
    completed_in_active=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | sed 's/\*\*//g' \
        | grep -ciE '^\|[^|]+\|[^|]+\|[[:space:]]*completed[[:space:]]*\|' || true)
    completed_in_active=${completed_in_active:-0}

    # 统计活跃任务部分中已推迟的任务（状态列包含 "deferred"）
    deferred_in_active=$(sed -n '/#### Active Tasks/,/^###/p' "$tracker_file" \
        | sed 's/\*\*//g' \
        | grep -ciE '^\|[^|]+\|[^|]+\|[[:space:]]*deferred[[:space:]]*\|' || true)
    deferred_in_active=${deferred_in_active:-0}

    # 活跃 = 总数据行 - 已完成 - 已推迟
    active_tasks=$((total_active_data_rows - completed_in_active - deferred_in_active))
    [[ "$active_tasks" -lt 0 ]] && active_tasks=0

    # 统计已完成任务
    local completed_tasks
    completed_tasks=$(_count_table_data_rows '### Completed and Verified' '^###')

    # 统计已验证的 AC（已完成部分中的唯一 AC 条目）
    # 从该部分的任何位置提取所有 AC 标识符（AC-1、AC1、AC-2.5 等），
    # 而不仅是行首，以处理包含多个逗号分隔 AC 的行（例如 swarm 模式）
    local completed_acs
    completed_acs=$(sed -n '/### Completed and Verified/,/^###/p' "$tracker_file" \
        | grep -aoE 'AC-?[0-9]+(\.[0-9]+)?' | sort -u | wc -l | tr -d ' ')
    completed_acs=${completed_acs:-0}

    # 统计已推迟任务
    local deferred_tasks
    deferred_tasks=$(_count_table_data_rows '### Explicitly Deferred' '^###')

    # 统计未关闭问题（新架构优先使用阻塞/排队的附带问题；旧架构使用 Open Issues）
    local -a issue_parts
    humanize_split_to_array issue_parts "$(humanize_parse_goal_tracker_issue_counts "$tracker_file")"
    local open_issues="${issue_parts[2]}"

    # 提取终极目标摘要（标题后的第一个内容行）
    local goal_summary
    goal_summary=$(sed -n '/### Ultimate Goal/,/^###/p' "$tracker_file" \
        | grep -v '^###' | grep -v '^$' | grep -v '^\[To be' \
        | head -1 | sed 's/^[[:space:]]*//')
    goal_summary="${goal_summary:-No goal defined}"

    echo "${total_acs}|${completed_acs}|${active_tasks}|${completed_tasks}|${deferred_tasks}|${open_issues}|${goal_summary}"
}

# 检测特殊的 git 仓库状态
# 返回: state_name（以下之一: normal, detached, rebase, merge, shallow, permission_error）
humanize_detect_git_state() {
    local git_dir

    # 检查我们是否在 git 仓库中并且可以访问它
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || {
        # 检查是权限问题还是不在仓库中
        if [[ -d ".git" ]] && ! [[ -r ".git" ]]; then
            echo "permission_error"
        else
            echo "not_a_repo"
        fi
        return
    }

    # 检查 git 目录的权限错误
    if ! [[ -r "$git_dir" ]]; then
        echo "permission_error"
        return
    fi

    # 检查是否正在进行变基
    if [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]]; then
        echo "rebase"
        return
    fi

    # 检查是否正在进行合并
    if [[ -f "$git_dir/MERGE_HEAD" ]]; then
        echo "merge"
        return
    fi

    # 检查是否为浅克隆
    if [[ -f "$git_dir/shallow" ]]; then
        echo "shallow"
        return
    fi

    # 检查是否为分离 HEAD 状态
    local head_ref
    head_ref=$(git symbolic-ref HEAD 2>/dev/null) || {
        echo "detached"
        return
    }

    echo "normal"
}

# 解析 git 状态并返回摘要值
# 返回: modified|added|deleted|untracked|insertions|deletions
humanize_parse_git_status() {
    # 检查我们是否在 git 仓库中
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo "0|0|0|0|0|0|not a git repo"
        return
    fi

    # 获取 porcelain 状态（快速、机器可读）
    local git_status_output=$(git status --porcelain 2>/dev/null)

    # 从状态输出中统计文件状态
    local modified=0 added=0 deleted=0 untracked=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local xy="${line:0:2}"
        case "$xy" in
            "??") ((untracked++)) ;;
            "A "* | " A"* | "AM"*) ((added++)) ;;
            "D "* | " D"*) ((deleted++)) ;;
            "M "* | " M"* | "MM"*) ((modified++)) ;;
            "R "* | " R"*) ((modified++)) ;;  # 重命名计为已修改
            *)
                # 处理其他情况（已暂存 + 未暂存的组合）
                [[ "${xy:0:1}" == "M" || "${xy:1:1}" == "M" ]] && ((modified++))
                [[ "${xy:0:1}" == "A" ]] && ((added++))
                [[ "${xy:0:1}" == "D" || "${xy:1:1}" == "D" ]] && ((deleted++))
                ;;
        esac
    done <<< "$git_status_output"

    # 获取行变更（插入/删除）- 已暂存 + 未暂存的差异
    local diffstat=$(git diff --shortstat HEAD 2>/dev/null || git diff --shortstat 2>/dev/null)
    local insertions=0 deletions=0

    if [[ -n "$diffstat" ]]; then
        # 解析: " 3 files changed, 45 insertions(+), 12 deletions(-)"
        insertions=$(echo "$diffstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
        deletions=$(echo "$diffstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
    fi
    insertions=${insertions:-0}
    deletions=${deletions:-0}

    echo "${modified}|${added}|${deleted}|${untracked}|${insertions}|${deletions}"
}

# ========================================
# 监控函数
# ========================================

# 监控来自 .humanize/rlcr 的最新 Codex 运行日志
# 当出现更新的日志时自动切换
# 在顶部显示固定的状态栏，展示会话信息
_humanize_monitor_codex() {
    # 在 zsh 中启用 0 索引数组以兼容 bash
    # 这会影响此函数内的所有 _split_to_array 调用
    [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions ksharrays

    local loop_dir=".humanize/rlcr"
    local current_file=""
    local current_session_dir=""
    local check_interval=2  # 检查新文件的间隔秒数
    local status_bar_height=11  # 状态栏的行数（包括循环状态行）

    # 检查 .humanize/rlcr 是否存在
    if [[ ! -d "$loop_dir" ]]; then
        echo "Error: $loop_dir directory not found in current directory"
        echo "Are you in a project with an active humanize loop?"
        return 1
    fi

    # 使用共享监控辅助函数查找最新会话
    _find_latest_session() {
        monitor_find_latest_session "$loop_dir"
    }

    # 查找特定会话的最新 codex 日志文件的函数
    # 日志文件现在位于 $HOME/.cache/humanize/<sanitized-project-path>/<timestamp>/ 以避免上下文污染
    # 尊重 XDG_CACHE_HOME 以便在受限环境中进行测试
    # 搜索实现阶段日志（codex-run.log）和审查阶段日志（codex-review.log）
    # 用法: _find_latest_codex_log [session_dir]
    #   如果提供了 session_dir，则仅在该会话的缓存目录中搜索
    #   如果未提供，则返回空（现在要求显式会话）
    _find_latest_codex_log() {
        local target_session_dir="$1"
        local latest=""
        local latest_round=-1
        local cache_base="${XDG_CACHE_HOME:-$HOME/.cache}/humanize"

        # 要求显式会话目录以避免显示错误会话的日志
        if [[ -z "$target_session_dir" || ! -d "$target_session_dir" ]]; then
            echo ""
            return
        fi

        # 获取当前项目的绝对路径并进行清理
        # 这与 loop-codex-stop-hook.sh 中的清理方式一致
        local project_root="$(pwd)"
        local sanitized_project=$(echo "$project_root" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
        local project_cache_dir="$cache_base/$sanitized_project"

        local session_name=$(basename "$target_session_dir")

        # 从日志文件名中提取轮次号的辅助函数
        # 处理 codex-run.log 和 codex-review.log 两种模式
        _extract_round_num() {
            local basename="$1"
            local round="${basename#round-}"
            # 移除 -codex-run.log 或 -codex-review.log 后缀
            round="${round%%-codex-run.log}"
            round="${round%%-codex-review.log}"
            echo "$round"
        }

        # 检测日志文件类型的辅助函数
        _is_review_log() {
            [[ "$1" == *-codex-review.log ]]
        }

        # 在此会话的项目特定缓存目录中查找日志文件
        local cache_dir="$project_cache_dir/$session_name"
        if [[ ! -d "$cache_dir" ]]; then
            echo ""
            return
        fi

        # 跟踪每种日志类型的最大轮次号（用于一致性检查）
        local max_run_round=-1
        local min_review_round=-1

        # 搜索实现阶段（codex-run）和审查阶段（codex-review）的日志
        # 使用 find 的 -o（OR）匹配两种模式
        while IFS= read -r log_file; do
            [[ -z "$log_file" ]] && continue
            [[ ! -f "$log_file" ]] && continue

            local log_basename=$(basename "$log_file")
            local round_num=$(_extract_round_num "$log_basename")

            # 按类型跟踪轮次号以进行一致性检查
            if _is_review_log "$log_basename"; then
                if [[ "$min_review_round" -eq -1 ]] || [[ "$round_num" -lt "$min_review_round" ]]; then
                    min_review_round="$round_num"
                fi
            else
                if [[ "$round_num" -gt "$max_run_round" ]]; then
                    max_run_round="$round_num"
                fi
            fi

            if [[ -z "$latest" ]] || [[ "$round_num" -gt "$latest_round" ]]; then
                latest="$log_file"
                latest_round="$round_num"
            fi
        done < <(find "$cache_dir" -maxdepth 1 \( -name 'round-*-codex-run.log' -o -name 'round-*-codex-review.log' \) -type f 2>/dev/null)

        # 防御性检查：codex-run 轮次必须严格小于 codex-review 轮次
        # 如果审查阶段存在，所有审查轮次必须大于所有运行轮次
        if [[ "$max_run_round" -ge 0 ]] && [[ "$min_review_round" -ge 0 ]]; then
            if [[ "$max_run_round" -ge "$min_review_round" ]]; then
                echo "ERROR: Inconsistent log state in session $session_name: codex-run round ($max_run_round) >= codex-review round ($min_review_round)" >&2
                echo ""
                return 1
            fi
        fi

        echo "$latest"
    }

    # 使用共享监控辅助函数查找状态文件
    _find_state_file() {
        monitor_find_state_file "$1"
    }

    # 解析 state.md 并返回值
    _parse_state_md() {
        local state_file="$1"
        if [[ ! -f "$state_file" ]]; then
            echo "N/A|N/A|N/A|N/A|N/A|N/A|N/A|false|false||"
            return
        fi

        local current_round=$(grep -E "^current_round:" "$state_file" 2>/dev/null | sed 's/current_round: *//')
        local max_iterations=$(grep -E "^max_iterations:" "$state_file" 2>/dev/null | sed 's/max_iterations: *//')
        local full_review_round=$(grep -E "^full_review_round:" "$state_file" 2>/dev/null | sed 's/full_review_round: *//')
        local codex_model=$(grep -E "^codex_model:" "$state_file" 2>/dev/null | sed 's/codex_model: *//')
        local codex_effort=$(grep -E "^codex_effort:" "$state_file" 2>/dev/null | sed 's/codex_effort: *//')
        local started_at=$(grep -E "^started_at:" "$state_file" 2>/dev/null | sed 's/started_at: *//')
        local plan_file=$(grep -E "^plan_file:" "$state_file" 2>/dev/null | sed 's/plan_file: *//')
        local ask_codex_question=$(grep -E "^ask_codex_question:" "$state_file" 2>/dev/null | sed 's/ask_codex_question: *//' | tr -d ' ')
        local review_started=$(grep -E "^review_started:" "$state_file" 2>/dev/null | sed 's/review_started: *//' | tr -d ' ')
        local agent_teams=$(grep -E "^agent_teams:" "$state_file" 2>/dev/null | sed 's/agent_teams: *//' | tr -d ' ')
        local push_every_round=$(grep -E "^push_every_round:" "$state_file" 2>/dev/null | sed 's/push_every_round: *//' | tr -d ' ')
        local mainline_stall_count=$(grep -E "^mainline_stall_count:" "$state_file" 2>/dev/null | sed 's/mainline_stall_count: *//' | tr -d ' ')
        local last_mainline_verdict=$(grep -E "^last_mainline_verdict:" "$state_file" 2>/dev/null | sed 's/last_mainline_verdict: *//' | tr -d ' ')
        local drift_status=$(grep -E "^drift_status:" "$state_file" 2>/dev/null | sed 's/drift_status: *//' | tr -d ' ')

        echo "${current_round:-N/A}|${max_iterations:-N/A}|${full_review_round:-N/A}|${codex_model:-N/A}|${codex_effort:-N/A}|${started_at:-N/A}|${plan_file:-N/A}|${ask_codex_question:-false}|${review_started:-false}|${agent_teams:-}|${push_every_round:-}|${mainline_stall_count:-0}|${last_mainline_verdict:-unknown}|${drift_status:-normal}"
    }

    # 调用顶层函数的内部包装器
    # 这些在 _humanize_monitor_codex 内部维护向后兼容性
    _parse_goal_tracker() { humanize_parse_goal_tracker "$@"; }
    _parse_git_status() { humanize_parse_git_status "$@"; }
    _split_to_array() { humanize_split_to_array "$@"; }

    # 在顶部绘制状态栏
    _draw_status_bar() {
        # 注意: ksharrays 在 _humanize_monitor_codex() 级别设置以兼容 zsh

        local session_dir="$1"
        local log_file="$2"
        local loop_status="$3"  # "active"、"completed"、"failed" 等
        local goal_tracker_file="$session_dir/goal-tracker.md"
        local term_width=$(tput cols)

        # 查找并解析状态文件（state.md 或 *-state.md）
        local -a state_file_parts
        _split_to_array state_file_parts "$(_find_state_file "$session_dir")"
        local state_file="${state_file_parts[0]}"
        # 如果提供了 loop_status 则使用传入值，否则使用检测到的状态
        [[ -z "$loop_status" ]] && loop_status="${state_file_parts[1]}"

        # 解析状态文件
        local -a state_parts
        _split_to_array state_parts "$(_parse_state_md "$state_file")"
        local current_round="${state_parts[0]}"
        local max_iterations="${state_parts[1]}"
        local full_review_round="${state_parts[2]}"
        local codex_model="${state_parts[3]}"
        local codex_effort="${state_parts[4]}"
        local started_at="${state_parts[5]}"
        local plan_file="${state_parts[6]}"
        local ask_codex_question="${state_parts[7]:-false}"
        local review_started="${state_parts[8]:-false}"
        local agent_teams="${state_parts[9]:-}"
        local push_every_round="${state_parts[10]:-}"
        local mainline_stall_count="${state_parts[11]:-0}"
        local last_mainline_verdict="${state_parts[12]:-unknown}"
        local drift_status="${state_parts[13]:-normal}"

        # 解析 goal-tracker.md
        local -a goal_parts
        _split_to_array goal_parts "$(_parse_goal_tracker "$goal_tracker_file")"
        local total_acs="${goal_parts[0]}"
        local completed_acs="${goal_parts[1]}"
        local active_tasks="${goal_parts[2]}"
        local completed_tasks="${goal_parts[3]}"
        local deferred_tasks="${goal_parts[4]}"
        local open_issues="${goal_parts[5]}"
        local goal_summary="${goal_parts[6]}"
        local -a issue_parts
        _split_to_array issue_parts "$(humanize_parse_goal_tracker_issue_counts "$goal_tracker_file")"
        local blocking_issues="${issue_parts[0]}"
        local queued_issues="${issue_parts[1]}"

        # 解析 git 状态
        local -a git_parts
        _split_to_array git_parts "$(_parse_git_status)"
        local git_modified="${git_parts[0]}"
        local git_added="${git_parts[1]}"
        local git_deleted="${git_parts[2]}"
        local git_untracked="${git_parts[3]}"
        local git_insertions="${git_parts[4]}"
        local git_deletions="${git_parts[5]}"

        # 格式化 started_at 以供显示（将 UTC 转换为本地时间）
        local start_display="$started_at"
        if [[ "$started_at" != "N/A" ]]; then
            # 将 ISO UTC 格式转换为本地时间
            # 输入: 2026-01-29T18:45:46Z
            # 输出: 2026-01-29 10:45:46（本地时间）
            local utc_time=$(echo "$started_at" | sed 's/T/ /; s/Z//')
            start_display=$(date -d "$utc_time UTC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$started_at")
        fi

        # 截断字符串以供显示（标签列约 10 个字符）
        local max_display_len=$((term_width - 12))
        local plan_display="$plan_file"
        local goal_display="$goal_summary"
        # Bash 兼容的字符串切片
        if [[ ${#plan_file} -gt $max_display_len ]]; then
            local suffix_len=$((max_display_len - 3))
            plan_display="...${plan_file: -$suffix_len}"
        fi
        if [[ ${#goal_summary} -gt $max_display_len ]]; then
            local prefix_len=$((max_display_len - 3))
            goal_display="${goal_summary:0:$prefix_len}..."
        fi

        # 保存光标位置并移动到顶部
        tput sc
        tput cup 0 0

        # ANSI 颜色代码
        local green="\033[1;32m" yellow="\033[1;33m" cyan="\033[1;36m"
        local magenta="\033[1;35m" red="\033[1;31m" reset="\033[0m"
        local bg="\033[44m" bold="\033[1m" dim="\033[2m"
        local blue="\033[1;34m" orange="\033[38;5;208m"
        local clr_eol="\033[K"  # 清除到行尾（比清除整个区域减少闪烁）

        # 移动到顶部并直接绘制（不预先清除以避免闪烁）
        tput cup 0 0
        printf "${bg}${bold}%-${term_width}s${reset}${clr_eol}\n" " Humanize Loop Monitor"
        printf "${cyan}Session Started:${reset} %s${clr_eol}\n" "$start_display"
        # 格式化 full_review_round 显示（如果可用则显示在括号中）
        local full_review_display=""
        if [[ "$full_review_round" != "N/A" && -n "$full_review_round" ]]; then
            full_review_display=" (${full_review_round})"
        fi
        # 如果设置了 push_every_round 则构建其片段
        local push_segment=""
        if [[ -n "$push_every_round" ]]; then
            local push_display="No"
            local push_color="${yellow}"
            if [[ "$push_every_round" == "true" ]]; then
                push_display="Yes"
                push_color="${green}"
            fi
            push_segment=" | Push Every Round: ${push_color}${push_display}${reset}"
        fi
        printf "${green}Round:${reset}    ${bold}%s${reset} / %s%s | ${yellow}Model:${reset} %s (%s)${push_segment}${clr_eol}\n" "$current_round" "$max_iterations" "$full_review_display" "$codex_model" "$codex_effort"

        # 根据状态着色的循环状态行
        # 颜色: Active=黄色, Complete=绿色, Finalize=青色, Stop 状态=红色, 其他=橙色
        local status_line=""
        case "$loop_status" in
            active)
                # 使用颜色显示 build->review 格式的阶段
                # 构建阶段: build=黄色, ->review=暗色（无轮次号）
                # 审查阶段: build(N)->review(M) 如果可用则显示轮次号
                if [[ "$review_started" == "true" ]]; then
                    # 尝试从标记文件中读取 build_finish_round 以显示轮次
                    local build_finish_round=""
                    local marker_file="$session_dir/.review-phase-started"
                    if [[ -f "$marker_file" ]]; then
                        build_finish_round=$(grep -oP '(?<=^build_finish_round=)\d+' "$marker_file" 2>/dev/null || true)
                    fi
                    if [[ -n "$build_finish_round" ]]; then
                        local review_rounds=$((current_round - build_finish_round))
                        status_line="${yellow}Active${reset}(${green}build(${build_finish_round})->${reset}${yellow}review(${review_rounds})${reset})"
                    else
                        status_line="${yellow}Active${reset}(${green}build->${reset}${yellow}review${reset})"
                    fi
                else
                    status_line="${yellow}Active${reset}(${yellow}build${reset}${dim}->review${reset})"
                fi
                ;;
            complete|completed)
                # 成功状态 - 绿色
                status_line="${green}Complete${reset}"
                ;;
            finalize)
                # 完成前的过渡状态 - 青色
                status_line="${cyan}Finalize${reset}"
                ;;
            stop|cancel|cancelled|maxiter|unexpected|failed|error|timeout)
                # 停止/终止状态 - 红色
                local first_char=$(echo "${loop_status:0:1}" | tr '[:lower:]' '[:upper:]')
                local rest="${loop_status:1}"
                status_line="${red}${first_char}${rest}${reset}"
                ;;
            *)
                # 其他（未知等） - 橙色
                local first_char=$(echo "${loop_status:0:1}" | tr '[:lower:]' '[:upper:]')
                local rest="${loop_status:1}"
                status_line="${orange}${first_char}${rest}${reset}"
                ;;
        esac
        # 显示 ask_codex_question 设置（开/关）
        local ask_q_display="Off"
        local ask_q_color="${dim}"
        if [[ "$ask_codex_question" == "true" ]]; then
            ask_q_display="On"
            ask_q_color="${green}"
        fi
        # 如果设置了 agent_teams 则构建团队模式显示
        local team_mode_segment=""
        if [[ -n "$agent_teams" ]]; then
            local team_display="Off"
            local team_color="${yellow}"
            if [[ "$agent_teams" == "true" ]]; then
                team_display="On"
                team_color="${green}"
            fi
            team_mode_segment=" | Team Mode: ${team_color}${team_display}${reset}"
        fi
        local drift_segment=""
        local drift_color="${dim}"
        if [[ "$drift_status" == "replan_required" ]]; then
            drift_color="${red}"
        elif [[ "${mainline_stall_count:-0}" -gt 0 ]]; then
            drift_color="${yellow}"
        fi
        if [[ -n "$drift_status" ]]; then
            drift_segment=" | Drift: ${drift_color}${drift_status}${reset} (${mainline_stall_count}, ${last_mainline_verdict})"
        fi
        printf "${magenta}Status:${reset}   ${status_line} | Codex Ask Question: ${ask_q_color}${ask_q_display}${reset}${team_mode_segment}${drift_segment}${clr_eol}\n"

        # 进度行（根据完成状态着色）
        local ac_color="${green}"
        [[ "$completed_acs" -lt "$total_acs" ]] && ac_color="${yellow}"
        local issue_total_color="${dim}"
        [[ "$queued_issues" -gt 0 ]] && issue_total_color="${yellow}"
        [[ "$blocking_issues" -gt 0 ]] && issue_total_color="${red}"

        # 使用洋红色作为 Progress 和 Git 标签（状态/数据行）
        printf "${magenta}Progress:${reset} ${ac_color}ACs: ${completed_acs}/${total_acs}${reset}  Tasks: ${active_tasks} active, ${completed_tasks} done"
        [[ "$deferred_tasks" -gt 0 ]] && printf "  ${yellow}${deferred_tasks} deferred${reset}"
        if [[ "$open_issues" -gt 0 ]]; then
            printf "  ${issue_total_color}Issues: ${open_issues}${reset}"
            [[ "$blocking_issues" -gt 0 ]] && printf " (${red}%s blocking${reset}" "$blocking_issues"
            [[ "$queued_issues" -gt 0 ]] && printf "%s${yellow}%s queued${reset}" \
                "$([[ "$blocking_issues" -gt 0 ]] && echo ", " || echo "(")" "$queued_issues"
            printf ")"
        fi
        printf "${clr_eol}\n"

        # Git 状态行（与 Progress 相同颜色）
        local git_total=$((git_modified + git_added + git_deleted))
        printf "${magenta}Git:${reset}      "
        if [[ "$git_total" -eq 0 && "$git_untracked" -eq 0 ]]; then
            printf "${dim}clean${reset}"
        else
            [[ "$git_modified" -gt 0 ]] && printf "${yellow}~${git_modified}${reset} "
            [[ "$git_added" -gt 0 ]] && printf "${green}+${git_added}${reset} "
            [[ "$git_deleted" -gt 0 ]] && printf "${red}-${git_deleted}${reset} "
            [[ "$git_untracked" -gt 0 ]] && printf "${dim}?${git_untracked}${reset} "
            printf " ${green}+${git_insertions}${reset}/${red}-${git_deletions}${reset} lines"
        fi
        printf "${clr_eol}\n"

        # 使用青色作为 Goal、Plan、Log 标签（上下文/参考行）
        printf "${cyan}Goal:${reset}     %s${clr_eol}\n" "$goal_display"
        printf "${cyan}Plan:${reset}     %s${clr_eol}\n" "$plan_display"
        printf "${cyan}Log:${reset}      %s${clr_eol}\n" "$log_file"
        printf "%.s─" $(seq 1 $term_width)
        printf "${clr_eol}\n"

        # 恢复光标位置
        tput rc
    }

    # 设置终端分屏视图
    _setup_terminal() {
        # 清屏
        clear
        # 设置滚动区域（为状态栏留出顶部行）
        printf "\033[${status_bar_height};%dr" $(tput lines)
        # 将光标移动到滚动区域
        tput cup $status_bar_height 0
    }

    # 检查终端是否太小而无法显示监控器
    # 返回 0 表示正常，1 表示太小
    _check_terminal_size() {
        local term_height=$(tput lines)
        local min_height=$((status_bar_height + 3))  # 状态栏 + 至少 3 行内容
        if [[ "$term_height" -lt "$min_height" ]]; then
            return 1
        fi
        return 0
    }

    # 显示终端太小的消息
    _display_terminal_too_small() {
        local term_width=$(tput cols)
        local term_height=$(tput lines)
        local min_height=$((status_bar_height + 3))
        local message="This Humanize Monitor requires at least $min_height lines to work"
        local msg_len=${#message}
        local center_row=$((term_height / 2))
        local start_col=$(( (term_width - msg_len) / 2 ))
        [[ "$start_col" -lt 0 ]] && start_col=0

        # 重置滚动区域并清屏
        printf "\033[r"
        clear
        tput cup $center_row $start_col
        printf "%s" "$message"
    }

    # 在终端大小变化时更新滚动区域
    _update_scroll_region() {
        local new_lines=$(tput lines)
        # 更新滚动区域到新的终端高度
        printf "\033[${status_bar_height};%dr" "$new_lines"
        # 清除日志区域以移除任何状态栏残留
        tput cup $status_bar_height 0
        tput ed  # Clear from cursor to end of screen
    }

    # 获取可用于日志显示的行数
    _get_log_area_height() {
        local term_height=$(tput lines)
        echo $((term_height - status_bar_height))
    }

    # 恢复终端到正常状态
    _restore_terminal() {
        # 重置滚动区域到全屏
        printf "\033[r"
        # 移动到底部
        tput cup $(tput lines) 0
    }

    # 在日志区域显示居中消息（用于等待状态）
    _display_centered_message() {
        local message="$1"
        local term_width=$(tput cols)
        local term_height=$(tput lines)
        local content_height=$((term_height - status_bar_height))
        local center_row=$((status_bar_height + content_height / 2))
        local msg_len=${#message}
        local start_col=$(( (term_width - msg_len) / 2 ))
        [[ "$start_col" -lt 0 ]] && start_col=0

        tput cup $status_bar_height 0
        tput ed  # 清除日志区域
        tput cup $center_row $start_col
        printf "%s" "$message"
    }

    # 跟踪 PID 以便清理
    local tail_pid=""
    local monitor_running=true
    local cleanup_done=false

    # 清理函数 - 由 trap 调用
    # 必须在 bash 和 zsh 中都能正常工作
    _cleanup() {
        # 防止多次清理调用
        [[ "${cleanup_done:-false}" == "true" ]] && return
        cleanup_done=true
        monitor_running=false

        # 重置 trap 以防止重复触发
        # 使用显式信号编号以获得更好的 zsh 兼容性
        trap - INT TERM WINCH 2>/dev/null || true

        # 更可靠地终止后台进程
        if [[ -n "$tail_pid" ]]; then
            # 终止前检查进程是否存在
            if kill -0 "$tail_pid" 2>/dev/null; then
                kill "$tail_pid" 2>/dev/null || true
                # 使用超时安全的 wait
                ( wait "$tail_pid" 2>/dev/null ) &
                wait $! 2>/dev/null || true
            fi
        fi

        _restore_terminal
        echo ""
        echo "Stopped monitoring."
    }

    # 当循环目录被删除时优雅停止
    # 根据 R1.2: 调用 _cleanup() 恢复终端状态
    _graceful_stop() {
        local reason="$1"
        # 防止多次清理调用 (checked again in _cleanup but check here too)
        [[ "${cleanup_done:-false}" == "true" ]] && return

        # 调用 _cleanup 执行实际的清理工作（按计划要求）
        _cleanup

        # 清理后打印特定的优雅停止消息
        echo "Monitoring stopped: $reason"
        echo "The RLCR loop may have been cancelled or the directory was deleted."
    }

    # 跟踪是否发生了大小变化（供主循环检测）
    # 重要: SIGWINCH 处理器只能设置标志，不能调用输出转义序列的函数
    # 否则可能与 _draw_status_bar 竞争并损坏数学表达式
    local resize_needed=false

    # 设置信号处理器（bash/zsh 兼容）
    # 使用不带引号的函数名以兼容 zsh
    # 在 zsh 中，使用 POSIX_TRAPS 选项时函数中的 trap 默认是局部的
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # zsh: 使用 TRAPINT 和 TRAPTERM 以获得更好的处理
        TRAPINT() { _cleanup; return 130; }
        TRAPTERM() { _cleanup; return 143; }
        TRAPWINCH() { resize_needed=true; }
    else
        # bash: 使用标准 trap
        trap '_cleanup' INT TERM
        trap 'resize_needed=true' WINCH
    fi

    # 查找初始会话和日志文件（仅在当前会话内搜索）
    current_session_dir=$(_find_latest_session)
    current_file=$(_find_latest_codex_log "$current_session_dir")

    # 检查是否有有效的会话目录
    if [[ -z "$current_session_dir" ]]; then
        echo "No session directories found in $loop_dir"
        echo "Start an RLCR loop first with /humanize:start-rlcr-loop"
        return 1
    fi

    # 从状态文件获取循环状态
    local -a state_file_info
    _split_to_array state_file_info "$(_find_state_file "$current_session_dir")"
    local current_state_file="${state_file_info[0]}"
    local current_loop_status="${state_file_info[1]}"

    # 检查初始终端大小
    if ! _check_terminal_size; then
        _display_terminal_too_small
        # 等待调整到更大的尺寸
        while ! _check_terminal_size; do
            sleep 0.5
            [[ "$resize_needed" == "true" ]] && resize_needed=false
        done
    fi

    # 设置终端
    _setup_terminal

    # 使用共享监控辅助函数获取文件大小
    _get_file_size() {
        monitor_get_file_size "$1"
    }

    # 跟踪上次读取位置以进行增量读取
    local last_size=0
    local file_size=0
    local last_no_log_status=""  # 跟踪上次渲染的无日志状态以进行刷新

    # 主监控循环
    while [[ "$monitor_running" == "true" ]]; do
        # 检查循环目录是否仍然存在（如果被删除则优雅退出）
        if [[ ! -d "$loop_dir" ]]; then
            _graceful_stop ".humanize/rlcr directory no longer exists"
            return 0
        fi

        # 更新循环状态
        _split_to_array state_file_info "$(_find_state_file "$current_session_dir")"
        current_state_file="${state_file_info[0]}"
        current_loop_status="${state_file_info[1]}"

        # 在安全点处理终端大小变化（绘制之前）
        if [[ "$resize_needed" == "true" ]]; then
            resize_needed=false
            # 检查终端是否太小
            if ! _check_terminal_size; then
                _display_terminal_too_small
                # 等待调整到更大的尺寸
                while [[ "$monitor_running" == "true" ]] && ! _check_terminal_size; do
                    sleep 0.5
                    [[ "$resize_needed" == "true" ]] && resize_needed=false
                done
                [[ "$monitor_running" != "true" ]] && break
                # 终端现在足够大，重新初始化
                _setup_terminal
            else
                _update_scroll_region
            fi
            # 调整大小后重新显示最近的日志内容（填充日志区域）
            if [[ -n "$current_file" && -f "$current_file" ]]; then
                local log_lines=$(_get_log_area_height)
                tail -n "$log_lines" "$current_file" 2>/dev/null
            fi
        fi

        # 绘制状态栏（在耗时操作前检查标志）
        [[ "$monitor_running" != "true" ]] && break
        _draw_status_bar "$current_session_dir" "${current_file:-N/A}" "$current_loop_status"
        [[ "$monitor_running" != "true" ]] && break

        # 将光标移动到滚动区域
        tput cup $status_bar_height 0

        # 处理当前会话没有日志文件的情况
        if [[ -z "$current_file" ]]; then
            # 跟踪终端尺寸以检测大小变化（SIGWINCH 的回退方案）
            local centered_last_cols=$(tput cols)
            local centered_last_rows=$(tput lines)

            # 如果状态已更改或尚未显示，则渲染居中的无日志消息
            if [[ "$last_no_log_status" != "$current_loop_status" ]]; then
                if [[ "$current_loop_status" == "active" ]]; then
                    _display_centered_message "No Codex run or review started, please wait for the first run/review"
                else
                    _display_centered_message "No log file available for this session (status: $current_loop_status)"
                fi
                last_no_log_status="$current_loop_status"
            fi

            # 轮询新的日志文件（仅在当前会话内）
            while [[ "$monitor_running" == "true" ]]; do
                sleep 0.5
                [[ "$monitor_running" != "true" ]] && break

                # 检查循环目录是否仍然存在（如果被删除则优雅退出）
                if [[ ! -d "$loop_dir" ]]; then
                    _graceful_stop ".humanize/rlcr directory no longer exists"
                    return 0
                fi

                # 通过 SIGWINCH 标志和实际尺寸变化检测终端大小变化
                local redraw_centered_msg=false
                local cur_cols=$(tput cols)
                local cur_rows=$(tput lines)
                if [[ "$resize_needed" == "true" ]] || \
                   [[ "$cur_cols" != "$centered_last_cols" ]] || \
                   [[ "$cur_rows" != "$centered_last_rows" ]]; then
                    resize_needed=false
                    redraw_centered_msg=true
                    centered_last_cols="$cur_cols"
                    centered_last_rows="$cur_rows"
                    # 检查终端是否太小
                    if ! _check_terminal_size; then
                        _display_terminal_too_small
                        # 等待调整到更大的尺寸
                        while [[ "$monitor_running" == "true" ]] && ! _check_terminal_size; do
                            sleep 0.5
                            [[ "$resize_needed" == "true" ]] && resize_needed=false
                        done
                        [[ "$monitor_running" != "true" ]] && break
                        # 终端现在足够大，重新初始化
                        _setup_terminal
                        centered_last_cols=$(tput cols)
                        centered_last_rows=$(tput lines)
                    else
                        _update_scroll_region
                    fi
                fi

                # 更新循环状态并重绘状态栏
                _split_to_array state_file_info "$(_find_state_file "$current_session_dir")"
                current_loop_status="${state_file_info[1]}"
                _draw_status_bar "$current_session_dir" "N/A" "$current_loop_status"
                [[ "$monitor_running" != "true" ]] && break

                # 如果循环状态已更改或终端大小已变化，则重新渲染无日志消息
                if [[ "$last_no_log_status" != "$current_loop_status" ]] || [[ "$redraw_centered_msg" == "true" ]]; then
                    if [[ "$current_loop_status" == "active" ]]; then
                        _display_centered_message "No Codex run or review started, please wait for the first run/review"
                    else
                        _display_centered_message "No log file available for this session (status: $current_loop_status)"
                    fi
                    last_no_log_status="$current_loop_status"
                fi

                # 仅在当前会话内检查新的日志文件
                local latest_session=$(_find_latest_session)
                [[ "$monitor_running" != "true" ]] && break

                # 处理会话目录删除
                if [[ ! -d "$current_session_dir" ]]; then
                    if [[ -n "$latest_session" ]]; then
                        # 当前会话已删除但存在另一个会话 - 切换到它
                        current_session_dir="$latest_session"
                        current_file=$(_find_latest_codex_log "$current_session_dir")
                        last_no_log_status=""  # Reset to re-render status for new session
                        tput cup $status_bar_height 0
                        tput ed
                        printf "\n==> Session directory deleted, switching to: %s\n" "$(basename "$latest_session")"
                        if [[ -n "$current_file" ]]; then
                            printf "==> Log: %s\n\n" "$current_file"
                            last_size=0
                            break
                        else
                            _display_centered_message "No Codex run or review started, please wait for the first run/review"
                        fi
                        continue
                    else
                        # 没有可用的会话 - 等待新的会话
                        last_no_log_status=""  # Reset to re-render status
                        _display_centered_message "Session directory deleted, waiting for new sessions..."
                        current_session_dir=""
                        current_file=""
                        continue
                    fi
                fi

                # 当存在更新的会话时立即更新会话目录（即使没有日志）
                if [[ -n "$latest_session" && "$latest_session" != "$current_session_dir" ]]; then
                    current_session_dir="$latest_session"
                    last_no_log_status=""  # Reset to re-render status for new session
                fi

                # 仅在当前会话内检查日志文件
                local latest=$(_find_latest_codex_log "$current_session_dir")
                [[ "$monitor_running" != "true" ]] && break

                if [[ -n "$latest" ]]; then
                    current_file="$latest"
                    last_no_log_status=""  # Reset for next no-log scenario
                    tput cup $status_bar_height 0
                    tput ed
                    printf "\n==> Log file found: %s\n\n" "$current_file"
                    last_size=0
                    break
                fi
            done
            continue
        fi

        # 获取初始文件大小
        last_size=$(_get_file_size "$current_file")

        # 显示现有内容（填充日志区域）
        [[ "$monitor_running" != "true" ]] && break
        local log_lines=$(_get_log_area_height)
        tail -n "$log_lines" "$current_file" 2>/dev/null

        # 跟踪终端尺寸以检测大小变化（SIGWINCH 的回退方案）
        local follow_last_cols=$(tput cols)
        local follow_last_rows=$(tput lines)

        # 增量监控循环
        while [[ "$monitor_running" == "true" ]]; do
            sleep 0.5  # 更频繁地检查以获得更平滑的输出
            [[ "$monitor_running" != "true" ]] && break

            # 检查循环目录是否仍然存在（如果被删除则优雅退出）
            if [[ ! -d "$loop_dir" ]]; then
                _graceful_stop ".humanize/rlcr directory no longer exists"
                return 0
            fi

            # 通过 SIGWINCH 标志和实际尺寸变化检测终端大小变化
            local cur_cols=$(tput cols)
            local cur_rows=$(tput lines)
            if [[ "$resize_needed" == "true" ]] || \
               [[ "$cur_cols" != "$follow_last_cols" ]] || \
               [[ "$cur_rows" != "$follow_last_rows" ]]; then
                resize_needed=false
                follow_last_cols="$cur_cols"
                follow_last_rows="$cur_rows"
                # 检查终端是否太小
                if ! _check_terminal_size; then
                    _display_terminal_too_small
                    # 等待调整到更大的尺寸
                    while [[ "$monitor_running" == "true" ]] && ! _check_terminal_size; do
                        sleep 0.5
                        [[ "$resize_needed" == "true" ]] && resize_needed=false
                    done
                    [[ "$monitor_running" != "true" ]] && break
                    # 终端现在足够大，重新初始化
                    _setup_terminal
                    follow_last_cols=$(tput cols)
                    follow_last_rows=$(tput lines)
                else
                    _update_scroll_region
                fi
                # 调整大小后重新显示最近的日志内容（填充日志区域）
                if [[ -n "$current_file" && -f "$current_file" ]]; then
                    local log_lines=$(_get_log_area_height)
                    tail -n "$log_lines" "$current_file" 2>/dev/null
                fi
            fi

            # 更新循环状态
            _split_to_array state_file_info "$(_find_state_file "$current_session_dir")"
            current_loop_status="${state_file_info[1]}"

            # 更新状态栏（在耗时操作前检查标志）
            [[ "$monitor_running" != "true" ]] && break
            _draw_status_bar "$current_session_dir" "$current_file" "$current_loop_status"
            [[ "$monitor_running" != "true" ]] && break

            # 检查当前文件中是否有新内容
            file_size=$(_get_file_size "$current_file")
            if [[ "$file_size" -gt "$last_size" ]]; then
                # 读取并显示新内容
                [[ "$monitor_running" != "true" ]] && break
                tail -c +$((last_size + 1)) "$current_file" 2>/dev/null
                last_size="$file_size"
            elif [[ "$last_size" -gt 0 ]] && [[ "$file_size" -lt "$last_size" ]]; then
                # 文件被截断或轮转（R1.3: 检测大小意外变为 0）
                # 仅在文件之前有内容时触发（last_size > 0）
                # 这防止将新的空文件视为被截断
                tput cup $status_bar_height 0
                tput ed
                printf "\n==> Log file truncated/rotated, searching for new log...\n"
                current_file=""
                last_size=0
                last_no_log_status=""
                break
            fi
            [[ "$monitor_running" != "true" ]] && break

            # 首先检查是否有更新的会话目录
            local latest_session=$(_find_latest_session)
            [[ "$monitor_running" != "true" ]] && break

            # 处理当前会话目录或日志文件删除
            if [[ ! -d "$current_session_dir" ]] || [[ ! -f "$current_file" ]]; then
                # 在重新分配变量之前捕获删除状态
                local session_was_deleted=false
                [[ ! -d "$current_session_dir" ]] && session_was_deleted=true

                if [[ -n "$latest_session" ]]; then
                    # 会话或日志已删除但存在另一个会话 - 切换到它
                    current_session_dir="$latest_session"
                    current_file=$(_find_latest_codex_log "$current_session_dir")
                    tput cup $status_bar_height 0
                    tput ed
                    if [[ "$session_was_deleted" == "true" ]]; then
                        printf "\n==> Session directory deleted, switching to: %s\n" "$(basename "$latest_session")"
                    else
                        printf "\n==> Log file deleted, switching to: %s\n" "$(basename "$latest_session")"
                    fi
                    if [[ -n "$current_file" ]]; then
                        printf "==> Log: %s\n\n" "$current_file"
                    else
                        _display_centered_message "No Codex run or review started, please wait for the first run/review"
                        last_no_log_status=""  # Reset to ensure no-log branch re-renders
                    fi
                    last_size=0
                    break
                else
                    # 没有可用的会话 - 等待新的会话（外层循环将处理）
                    current_session_dir=""
                    current_file=""
                    last_no_log_status=""  # Reset to re-render status
                    _display_centered_message "Session/log deleted, waiting for new sessions..."
                    break
                fi
            fi

            # 检查是否存在更新的会话（即使没有日志文件）
            if [[ -n "$latest_session" && "$latest_session" != "$current_session_dir" ]]; then
                # 发现新会话 - 切换到它
                current_session_dir="$latest_session"
                local new_session_log=$(_find_latest_codex_log "$current_session_dir")

                # 清除滚动区域并通知
                tput cup $status_bar_height 0
                tput ed
                printf "\n==> Switching to newer session: %s\n" "$(basename "$latest_session")"

                if [[ -n "$new_session_log" ]]; then
                    # 新会话有日志文件
                    current_file="$new_session_log"
                    printf "==> Log: %s\n\n" "$current_file"
                else
                    # 新会话还没有日志文件 - 让外层循环处理
                    current_file=""
                    last_no_log_status=""  # Reset to ensure no-log branch re-renders
                    _display_centered_message "No Codex run or review started, please wait for the first run/review"
                fi

                # 为新会话重置
                last_size=0
                break
            fi

            # 检查当前会话内是否有更新的日志文件
            local latest=$(_find_latest_codex_log "$current_session_dir")
            [[ "$monitor_running" != "true" ]] && break

            if [[ "$latest" != "$current_file" && -n "$latest" ]]; then
                # 同一会话，但有新的日志文件（例如新的轮次）
                current_file="$latest"

                # 清除滚动区域并通知
                tput cup $status_bar_height 0
                tput ed
                printf "\n==> Switching to newer log: %s\n\n" "$current_file"

                # 为新文件重置
                last_size=0
                break
            fi
        done
    done

    # 重置 trap 处理器（zsh 和 bash）
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # zsh: 取消定义 TRAP* 函数
        unfunction TRAPINT TRAPTERM TRAPWINCH 2>/dev/null || true
    else
        trap - INT TERM WINCH
    fi
}


# 启动一个项目的 Web 仪表板。默认在前台运行
# （与其他 `humanize monitor` 子命令的用户体验一致）；
# `--daemon` 委托给现有的基于 tmux 的启动器。
#
# 透传标志（转发到 viz/server/app.py）：
#   --project <path>      仪表板的项目根目录（默认: cwd）
#   --port <int>          绑定端口（默认: 自动, 18000-18099）
#   --host <addr>         绑定地址（默认: 127.0.0.1；远程认证
#                         强制执行将在后续轮次的 T11 中实现）
#   --auth-token <token>  远程模式认证的 Bearer 令牌（已解析并
#                         转发；完整强制执行将在 T11 中实现）
#   --daemon              通过 viz-start.sh 作为后台 tmux 服务运行
_humanize_monitor_web() {
    local project_dir
    project_dir="$(pwd)"
    local host="127.0.0.1"
    local port=""
    local auth_token=""
    local daemon=false

    local trust_proxy=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project) project_dir="$2"; shift 2 ;;
            --host)    host="$2"; shift 2 ;;
            --port)    port="$2"; shift 2 ;;
            --auth-token) auth_token="$2"; shift 2 ;;
            --trust-proxy) trust_proxy=true; shift ;;
            --daemon)  daemon=true; shift ;;
            -h|--help)
                echo "Usage: humanize monitor web [--project <path>] [--host <addr>] [--port <int>] [--auth-token <tok>] [--trust-proxy] [--daemon]"
                return 0
                ;;
            *)
                echo "Error: unknown flag for 'monitor web': $1" >&2
                return 1
                ;;
        esac
    done

    project_dir="$(cd "$project_dir" 2>/dev/null && pwd)" || {
        echo "Error: project directory not found: $project_dir" >&2
        return 1
    }
    if [[ ! -d "$project_dir/.humanize" ]]; then
        echo "Error: $project_dir/.humanize/ does not exist" >&2
        echo "  This command must run inside a project initialized by humanize." >&2
        return 1
    fi

    local viz_root="$HUMANIZE_SCRIPT_DIR/../viz"
    local app_entry="$viz_root/server/app.py"
    local static_dir="$viz_root/static"
    local venv_dir="$project_dir/.humanize/viz-venv"
    local requirements="$viz_root/server/requirements.txt"

    if [[ "$daemon" == "true" ]]; then
        # 守护进程模式：复用基于 tmux 的启动器（现在按项目命名，
        # 根据 T9）。转发每个标志，以便远程绑定 + 令牌配置
        # 到达底层的 app.py 调用。
        local viz_start="$viz_root/scripts/viz-start.sh"
        if [[ ! -x "$viz_start" ]]; then
            echo "Error: viz-start.sh not found at $viz_start" >&2
            return 1
        fi
        local -a daemon_args=(--project "$project_dir" --host "$host")
        [[ -n "$port" ]] && daemon_args+=(--port "$port")
        [[ -n "$auth_token" ]] && daemon_args+=(--auth-token "$auth_token")
        [[ "$trust_proxy" == "true" ]] && daemon_args+=(--trust-proxy)
        bash "$viz_start" "${daemon_args[@]}"
        return $?
    fi

    # 前台模式（根据 DEC-1 默认）。
    if [[ ! -d "$venv_dir" ]]; then
        echo "Creating Python virtual environment for the dashboard..."
        python3 -m venv "$venv_dir" || {
            echo "Error: failed to create venv at $venv_dir" >&2
            return 1
        }
        echo "Installing dependencies..."
        "$venv_dir/bin/pip" install --quiet -r "$requirements" || {
            echo "Error: failed to install requirements" >&2
            return 1
        }
        touch "$venv_dir/.requirements_installed"
    elif [[ "$requirements" -nt "$venv_dir/.requirements_installed" ]]; then
        echo "Updating dependencies..."
        if ! "$venv_dir/bin/pip" install --quiet -r "$requirements"; then
            # 保持 .requirements_installed 不变，以便下次
            # 启动时重新检测过期标记并重试升级，
            # 而不是在缺少包的情况下静默启动。
            # 返回非零退出码以便调用者看到。
            echo "Error: pip install failed during dependency refresh" >&2
            return 1
        fi
        touch "$venv_dir/.requirements_installed"
    fi

    if [[ -z "$port" ]]; then
        # 探测请求的绑定主机，以便端口选择与
        # app.run(host=BIND_HOST, port=$port) 实际尝试绑定的一致。
        # 回环别名和通配符也在 localhost 上监听，因此
        # localhost 是它们的有效代理；但特定的非回环地址
        # 不在 localhost 上监听，因此探测 localhost 会错过
        # 外部接口上的 EADDRINUSE 冲突，Flask 会在启动时崩溃。
        # 镜像了 viz/scripts/viz-start.sh:find_port 中的第 14 轮修复。
        local probe_host
        case "$host" in
            127.0.0.1|::1|localhost|0.0.0.0|::)
                probe_host="localhost"
                ;;
            *)
                probe_host="$host"
                ;;
        esac
        for candidate in $(seq 18000 18099); do
            if ! (echo >/dev/tcp/$probe_host/$candidate) 2>/dev/null; then
                port="$candidate"
                break
            fi
        done
        if [[ -z "$port" ]]; then
            echo "Error: no available port in range 18000-18099" >&2
            return 1
        fi
    fi

    if [[ "$host" != "127.0.0.1" && "$host" != "localhost" && -z "$auth_token" ]]; then
        echo "Warning: binding $host without --auth-token (full remote auth enforcement is T11)" >&2
    fi

    local visible_host="$host"
    [[ "$host" == "127.0.0.1" || "$host" == "::1" ]] && visible_host="localhost"
    local url="http://${visible_host}:${port}"
    echo "Starting humanize monitor web at $url (project: $project_dir)"
    echo "Press Ctrl+C to stop."

    local -a fg_args=(
        --host "$host"
        --port "$port"
        --project "$project_dir"
        --static "$static_dir"
    )
    [[ -n "$auth_token" ]] && fg_args+=(--auth-token "$auth_token")
    [[ "$trust_proxy" == "true" ]] && fg_args+=(--trust-proxy)

    # 不要使用 exec: `humanize` 是一个导入到用户交互式 shell 中的函数
    # （参见 README 中的 scripts/humanize.sh 用法）。
    # `exec` 会用 Python 替换该 shell 进程，因此按下 Ctrl+C
    # （或任何服务器退出）会杀死整个交互式会话。
    # 将命令作为子进程运行可以让函数在服务器退出时正常返回，
    # 并保持 shell 提示符活跃。
    "$venv_dir/bin/python" "$app_entry" "${fg_args[@]}"
}


# 主 humanize 函数
humanize() {
    local cmd="$1"
    shift

    case "$cmd" in
        monitor)
            local target="$1"
            shift 2>/dev/null || true
            case "$target" in
                rlcr)
                    _humanize_monitor_codex "$@"
                    ;;
                skill)
                    _humanize_monitor_skill "$@"
                    ;;
                codex)
                    _humanize_monitor_skill --tool-filter codex "$@"
                    ;;
                gemini)
                    _humanize_monitor_skill --tool-filter gemini "$@"
                    ;;
                web)
                    _humanize_monitor_web "$@"
                    ;;
                *)
                    echo "Usage: humanize monitor <rlcr|skill|codex|gemini|web>"
                    echo ""
                    echo "Subcommands:"
                    echo "  rlcr    Monitor the latest RLCR loop log from .humanize/rlcr"
                    echo "  skill   Monitor all skill invocations (codex + gemini)"
                    echo "  codex   Monitor ask-codex skill invocations only"
                    echo "  gemini  Monitor ask-gemini skill invocations only"
                    echo "  web     Launch the browser dashboard for one project"
                    echo ""
                    echo "Features (terminal monitors):"
                    echo "  - Fixed status bar showing session info, round progress, model config"
                    echo "  - Goal tracker summary: Ultimate Goal, AC progress, task status"
                    echo "  - Real-time log output in scrollable area below"
                    echo "  - Automatically switches to newer logs when they appear"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "Usage: humanize <command> [args]"
            echo ""
            echo "Commands:"
            echo "  monitor rlcr    Monitor the latest RLCR loop log"
            echo "  monitor skill   Monitor all skill invocations (codex + gemini)"
            echo "  monitor codex   Monitor ask-codex skill invocations only"
            echo "  monitor gemini  Monitor ask-gemini skill invocations only"
            echo "  monitor web     Launch the browser dashboard for one project"
            return 1
            ;;
    esac
}

# 导入技能监控器（提供 _humanize_monitor_skill）
if [[ -f "$HUMANIZE_SCRIPT_DIR/lib/monitor-skill.sh" ]]; then
    source "$HUMANIZE_SCRIPT_DIR/lib/monitor-skill.sh"
fi
