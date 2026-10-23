#!/usr/bin/env bash
#
# monitor-skill.sh - humanize 的技能监控器
#
# 提供 _humanize_monitor_skill 函数，用于监控来自
# .humanize/skill 目录的技能调用（ask-codex、ask-gemini）。
#
# 此文件由 humanize.sh 导入，依赖于:
# - monitor-common.sh (monitor_get_yaml_value, monitor_format_timestamp 等)
# - humanize.sh (humanize_split_to_array)

# 监控来自 .humanize/skill 的技能调用
# 显示带有聚合统计和最新调用详情的固定状态栏，
# 下方可滚动区域显示实时输出。
#
# 接受 --tool-filter <codex|gemini> 以仅显示来自特定工具的调用。
# 不使用过滤器时，显示所有调用。
_humanize_monitor_skill() {
    # 在 zsh 中启用 0 索引数组以兼容 bash
    # no_monitor 抑制后台作业通知（[1] PID）
    [[ -n "${ZSH_VERSION:-}" ]] && setopt localoptions ksharrays no_monitor

    local skill_dir=".humanize/skill"
    local current_skill_dir=""
    local current_file=""
    local check_interval=2
    local status_bar_height=9
    local once_mode=false
    local tool_filter=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once) once_mode=true; shift ;;
            --tool-filter)
                tool_filter="${2:-}"
                shift 2
                ;;
            *) shift ;;
        esac
    done

    # 检查 .humanize/skill 是否存在
    if [[ ! -d "$skill_dir" ]]; then
        echo "Error: $skill_dir directory not found in current directory"
        echo "Run /humanize:ask-codex or /humanize:ask-gemini first to create skill invocations"
        return 1
    fi

    # 确定给定调用目录的工具。
    # 首先读取 metadata.md（已完成），回退到 input.md（运行中）。
    # 返回: codex、gemini 或 unknown
    _skill_get_tool() {
        local dir="$1"
        if [[ -f "$dir/metadata.md" ]]; then
            local t=$(monitor_get_yaml_value "tool" "$dir/metadata.md")
            [[ -n "$t" ]] && { echo "$t"; return; }
        fi
        if [[ -f "$dir/input.md" ]]; then
            local t=$(grep -E '^- Tool:' "$dir/input.md" 2>/dev/null | sed 's/- Tool: //')
            [[ -n "$t" ]] && { echo "$t"; return; }
        fi
        echo "unknown"
    }

    # 检查目录是否通过当前工具过滤器。
    # 返回 0（通过）或 1（跳过）。
    _skill_passes_filter() {
        [[ -z "$tool_filter" ]] && return 0
        local t=$(_skill_get_tool "$1")
        [[ "$t" == "$tool_filter" ]] && return 0
        # 没有工具标签的旧版调用被视为 codex
        [[ "$t" == "unknown" && "$tool_filter" == "codex" ]] && return 0
        return 1
    }

    # 列出所有有效的技能调用目录，按最新排序
    # 技能目录使用 YYYY-MM-DD_HH-MM-SS 或 YYYY-MM-DD_HH-MM-SS-PID-RANDOM 命名
    _skill_list_dirs_sorted() {
        local dirs=()
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            [[ ! -d "$d" ]] && continue
            local name=$(basename "$d")
            [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2} ]] || continue
            _skill_passes_filter "$d" || continue
            dirs+=("$d")
        done < <(find "$skill_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        printf '%s\n' "${dirs[@]}" | sort -r
    }

    # 查找最新的技能调用目录（按名称中的时间戳）
    _skill_find_latest_dir() {
        _skill_list_dirs_sorted | head -1
    }

    # 查找最佳的调用以进行监控：最新的具有可观看内容的调用。
    # 如果没有任何内容，则回退到绝对最新的调用。
    # 返回: dir|file（管道分隔的对）
    _skill_find_best_invocation() {
        local best_dir="" best_file=""
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            local f=$(_skill_find_monitored_file "$d")
            if [[ -n "$f" && -s "$f" ]]; then
                best_dir="$d"; best_file="$f"
                break
            fi
        done < <(_skill_list_dirs_sorted)

        # 即使没有内容也回退到绝对最新的调用
        if [[ -z "$best_dir" ]]; then
            best_dir=$(_skill_find_latest_dir)
            [[ -n "$best_dir" ]] && best_file=$(_skill_find_monitored_file "$best_dir")
        fi
        echo "${best_dir}|${best_file}"
    }

    # 按状态统计调用次数
    # 返回: total|success|error|timeout|empty|running
    _skill_count_stats() {
        local total=0 success=0 err=0 tmo=0 empty=0 running=0
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            [[ ! -d "$d" ]] && continue
            local name=$(basename "$d")
            [[ ! "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2} ]] && continue
            _skill_passes_filter "$d" || continue
            ((total++))
            if [[ -f "$d/metadata.md" ]]; then
                local st=$(monitor_get_yaml_value "status" "$d/metadata.md")
                case "$st" in
                    success) ((success++)) ;;
                    error) ((err++)) ;;
                    timeout) ((tmo++)) ;;
                    empty_response) ((empty++)) ;;
                esac
            else
                ((running++))
            fi
        done < <(find "$skill_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        echo "$total|$success|$err|$tmo|$empty|$running"
    }

    # 从 input.md 中提取问题文本
    _skill_get_question() {
        local dir="$1"
        [[ ! -f "$dir/input.md" ]] && echo "N/A" && return
        local q=$(sed -n '/^## Question$/,/^## /p' "$dir/input.md" \
            | grep -v '^##' | grep -v '^$' | head -1 | sed 's/^[[:space:]]*//')
        echo "${q:-N/A}"
    }

    # 查找技能调用的全局缓存目录（仅用于显示）
    # 如果存在则返回 ~/.cache/humanize/... 路径，否则返回空。
    _skill_find_cache_dir() {
        local unique_id=$(basename "$1")
        local project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        local sanitized=$(echo "$project_root" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
        local cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
        local cache_dir="$cache_base/humanize/$sanitized/skill-$unique_id"
        [[ -d "$cache_dir" ]] && echo "$cache_dir" || echo ""
    }

    # 查找技能调用的最佳监控文件
    # 搜索全局缓存（~/.cache/humanize/）、本地缓存（$dir/cache/）
    # 和项目本地文件（.humanize/skill/）以获取最佳内容。
    # 支持 codex（codex-run.*）和 gemini（gemini-run.*）缓存文件。
    _skill_find_monitored_file() {
        local dir="$1"
        local gcache=$(_skill_find_cache_dir "$dir")
        local lcache="$dir/cache"
        local is_running=false
        [[ ! -f "$dir/metadata.md" ]] && is_running=true

        # 确定哪个工具产生了此调用，用于缓存文件命名
        local inv_tool=$(_skill_get_tool "$dir")
        local run_prefix="codex-run"
        [[ "$inv_tool" == "gemini" ]] && run_prefix="gemini-run"

        # 辅助函数：检查缓存目录中的最佳文件
        # 参数: cache_dir, prefer_log（运行中为 true，已完成为 false）
        _check_cache_files() {
            local c="$1" prefer_log="$2"
            [[ ! -d "$c" ]] && return
            if [[ "$prefer_log" == "true" ]]; then
                [[ -f "$c/${run_prefix}.log" && -s "$c/${run_prefix}.log" ]] && { echo "$c/${run_prefix}.log"; return; }
                [[ -f "$c/${run_prefix}.out" && -s "$c/${run_prefix}.out" ]] && { echo "$c/${run_prefix}.out"; return; }
                [[ -f "$c/${run_prefix}.log" ]] && { echo "$c/${run_prefix}.log"; return; }
                # 回退: 尝试其他前缀以处理旧版/混合调用
                [[ -f "$c/codex-run.log" && -s "$c/codex-run.log" ]] && { echo "$c/codex-run.log"; return; }
                [[ -f "$c/gemini-run.log" && -s "$c/gemini-run.log" ]] && { echo "$c/gemini-run.log"; return; }
            else
                [[ -f "$c/${run_prefix}.out" && -s "$c/${run_prefix}.out" ]] && { echo "$c/${run_prefix}.out"; return; }
                [[ -f "$c/${run_prefix}.log" && -s "$c/${run_prefix}.log" ]] && { echo "$c/${run_prefix}.log"; return; }
                # 回退
                [[ -f "$c/codex-run.out" && -s "$c/codex-run.out" ]] && { echo "$c/codex-run.out"; return; }
                [[ -f "$c/gemini-run.out" && -s "$c/gemini-run.out" ]] && { echo "$c/gemini-run.out"; return; }
            fi
        }

        if [[ "$is_running" == "true" ]]; then
            # 运行中: 优先使用缓存日志（stderr 有实时进度）
            local f
            f=$(_check_cache_files "$gcache" true); [[ -n "$f" ]] && { echo "$f"; return; }
            f=$(_check_cache_files "$lcache" true); [[ -n "$f" ]] && { echo "$f"; return; }
            [[ -f "$dir/input.md" ]] && { echo "$dir/input.md"; return; }
        else
            # 已完成: 优先使用有内容的 output.md，然后是缓存文件
            [[ -f "$dir/output.md" && -s "$dir/output.md" ]] && { echo "$dir/output.md"; return; }
            local f
            f=$(_check_cache_files "$gcache" false); [[ -n "$f" ]] && { echo "$f"; return; }
            f=$(_check_cache_files "$lcache" false); [[ -n "$f" ]] && { echo "$f"; return; }
            [[ -f "$dir/output.md" ]] && { echo "$dir/output.md"; return; }
        fi
        echo ""
    }

    # 根据过滤器构建监控器标题
    _skill_monitor_title() {
        case "$tool_filter" in
            codex)  echo " Humanize Skill Monitor [codex]" ;;
            gemini) echo " Humanize Skill Monitor [gemini]" ;;
            *)      echo " Humanize Skill Monitor" ;;
        esac
    }

    # 在顶部绘制状态栏
    _skill_draw_status_bar() {
        local latest_dir="$1"
        local monitored_file="$2"
        local term_width=$(tput cols)

        # ANSI 颜色
        local green="\033[1;32m" yellow="\033[1;33m" cyan="\033[1;36m"
        local magenta="\033[1;35m" red="\033[1;31m" reset="\033[0m"
        local bg="\033[44m" bold="\033[1m" dim="\033[2m"
        local clr_eol="\033[K"

        # 聚合统计
        local -a stats
        humanize_split_to_array stats "$(_skill_count_stats)"
        local total="${stats[0]}" success="${stats[1]}" err="${stats[2]}"
        local tmo="${stats[3]}" empty="${stats[4]}" running="${stats[5]}"

        # 解析最新调用的元数据
        local inv_status="running" model="N/A" effort="N/A" duration="N/A" started_at="N/A"
        local inv_tool="unknown"
        if [[ -n "$latest_dir" && -f "$latest_dir/metadata.md" ]]; then
            inv_status=$(monitor_get_yaml_value "status" "$latest_dir/metadata.md")
            model=$(monitor_get_yaml_value "model" "$latest_dir/metadata.md")
            effort=$(monitor_get_yaml_value "effort" "$latest_dir/metadata.md")
            duration=$(monitor_get_yaml_value "duration" "$latest_dir/metadata.md")
            started_at=$(monitor_get_yaml_value "started_at" "$latest_dir/metadata.md")
            inv_tool=$(monitor_get_yaml_value "tool" "$latest_dir/metadata.md")
        elif [[ -n "$latest_dir" && -f "$latest_dir/input.md" ]]; then
            model=$(grep -E '^- Model:' "$latest_dir/input.md" 2>/dev/null | sed 's/- Model: //')
            effort=$(grep -E '^- Effort:' "$latest_dir/input.md" 2>/dev/null | sed 's/- Effort: //')
            inv_tool=$(grep -E '^- Tool:' "$latest_dir/input.md" 2>/dev/null | sed 's/- Tool: //')
        fi
        inv_status="${inv_status:-unknown}"; model="${model:-N/A}"; effort="${effort:-N/A}"
        inv_tool="${inv_tool:-unknown}"

        # 状态颜色
        local status_color="$dim"
        case "$inv_status" in
            success) status_color="$green" ;;
            error|timeout) status_color="$red" ;;
            empty_response) status_color="$yellow" ;;
            running) status_color="$yellow" ;;
        esac

        # 问题（已截断）
        local question="N/A"
        [[ -n "$latest_dir" ]] && question=$(_skill_get_question "$latest_dir")
        local max_q_len=$((term_width - 14))
        [[ ${#question} -gt $max_q_len ]] && question="${question:0:$((max_q_len - 3))}..."

        # 格式化时间戳
        local start_display=$(monitor_format_timestamp "$started_at")

        # 解析缓存目录以供显示
        local cache_dir=""
        [[ -n "$latest_dir" ]] && cache_dir=$(_skill_find_cache_dir "$latest_dir")

        # 截断路径以供显示
        local max_path_len=$((term_width - 14))

        local file_display="${monitored_file:-none}"
        if [[ ${#file_display} -gt $max_path_len ]]; then
            local suffix_len=$((max_path_len - 3))
            file_display="...${file_display: -$suffix_len}"
        fi

        local cache_display="${cache_dir:-not found}"
        if [[ ${#cache_display} -gt $max_path_len ]]; then
            local csuffix_len=$((max_path_len - 3))
            cache_display="...${cache_display: -$csuffix_len}"
        fi

        # 模型显示: gemini 不显示 effort; codex 显示 (effort)
        local model_display="$model"
        if [[ "$inv_tool" == "gemini" ]] || [[ "$effort" == "N/A" ]]; then
            model_display="$model"
        else
            model_display="$model ($effort)"
        fi

        tput sc
        tput cup 0 0

        # 第 1 行: 标题
        printf "${bg}${bold}%-${term_width}s${reset}${clr_eol}\n" "$(_skill_monitor_title)"
        # 第 2 行: 聚合统计
        printf "${cyan}Total:${reset}    ${bold}${total}${reset} invocations"
        [[ "$success" -gt 0 ]] && printf " | ${green}${success} success${reset}"
        [[ "$err" -gt 0 ]] && printf " | ${red}${err} error${reset}"
        [[ "$tmo" -gt 0 ]] && printf " | ${red}${tmo} timeout${reset}"
        [[ "$empty" -gt 0 ]] && printf " | ${yellow}${empty} empty${reset}"
        [[ "$running" -gt 0 ]] && printf " | ${yellow}${running} running${reset}"
        printf "${clr_eol}\n"
        # 第 3 行: 聚焦调用状态 + 工具 + 模型 + 持续时间
        printf "${magenta}Focused:${reset}  ${status_color}%s${reset} | ${dim}[%s]${reset} ${yellow}Model:${reset} %s | ${cyan}Duration:${reset} %s${clr_eol}\n" "$inv_status" "$inv_tool" "$model_display" "${duration:-N/A}"
        # 第 4 行: 开始时间
        printf "${cyan}Started:${reset}  %s${clr_eol}\n" "$start_display"
        # 第 5 行: 问题
        printf "${cyan}Question:${reset} %s${clr_eol}\n" "$question"
        # 第 6 行: 缓存目录
        printf "${dim}Cache:${reset}    %s${clr_eol}\n" "$cache_display"
        # 第 7 行: 监控文件
        printf "${dim}Watching:${reset} %s${clr_eol}\n" "$file_display"
        # 第 8 行: 分隔符
        printf "%.s-" $(seq 1 $term_width)
        printf "${clr_eol}\n"

        tput rc
    }

    # --once 模式: 打印摘要并退出
    if [[ "$once_mode" == "true" ]]; then
        local latest=$(_skill_find_latest_dir)
        if [[ -z "$latest" ]]; then
            local filter_msg=""
            [[ -n "$tool_filter" ]] && filter_msg=" (filter: $tool_filter)"
            echo "No skill invocations found in $skill_dir$filter_msg"
            return 1
        fi

        # 查找具有内容的最佳调用
        local best_result=$(_skill_find_best_invocation)
        local best_dir="${best_result%%|*}"
        local best_file="${best_result#*|}"
        # 使用 best_dir 进行显示（它有内容）；回退到最新的
        local focus_dir="${best_dir:-$latest}"

        local -a stats
        humanize_split_to_array stats "$(_skill_count_stats)"
        local inv_status="running" model="N/A" effort="N/A" duration="N/A" started_at="N/A"
        local inv_tool="unknown"
        if [[ -f "$focus_dir/metadata.md" ]]; then
            inv_status=$(monitor_get_yaml_value "status" "$focus_dir/metadata.md")
            model=$(monitor_get_yaml_value "model" "$focus_dir/metadata.md")
            effort=$(monitor_get_yaml_value "effort" "$focus_dir/metadata.md")
            duration=$(monitor_get_yaml_value "duration" "$focus_dir/metadata.md")
            started_at=$(monitor_get_yaml_value "started_at" "$focus_dir/metadata.md")
            inv_tool=$(monitor_get_yaml_value "tool" "$focus_dir/metadata.md")
        fi
        inv_tool="${inv_tool:-unknown}"
        local question=$(_skill_get_question "$focus_dir")
        local cache_dir=$(_skill_find_cache_dir "$focus_dir")

        local title=$(_skill_monitor_title)
        echo "=========================================="
        echo "$title"
        echo "=========================================="
        echo ""
        echo "Total Invocations: ${stats[0]}"
        echo "  Success: ${stats[1]}  Error: ${stats[2]}  Timeout: ${stats[3]}  Empty: ${stats[4]}  Running: ${stats[5]}"
        echo ""
        echo "Focused: $(basename "$focus_dir")"
        echo "  Tool:     ${inv_tool}"
        echo "  Status:   ${inv_status:-unknown}"
        echo "  Model:    ${model:-N/A} (${effort:-N/A})"
        echo "  Duration: ${duration:-N/A}"
        echo "  Started:  ${started_at:-N/A}"
        echo "  Question: $question"
        echo "  Cache:    ${cache_dir:-not found}"
        echo "  Watching: ${best_file:-none}"
        echo ""
        echo "=========================================="
        echo " Watched Output"
        echo "=========================================="
        echo ""
        if [[ -n "$best_file" && -s "$best_file" ]]; then
            cat "$best_file"
        elif [[ "$inv_status" == "running" ]]; then
            echo "(Still running...)"
        else
            echo "(No output available)"
        fi
        echo ""
        echo "=========================================="
        echo " Recent Invocations"
        echo "=========================================="
        echo ""
        local count=0
        while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            local name=$(basename "$d")
            local st="running" dur="" t="?"
            if [[ -f "$d/metadata.md" ]]; then
                st=$(monitor_get_yaml_value "status" "$d/metadata.md")
                dur=$(monitor_get_yaml_value "duration" "$d/metadata.md")
                t=$(monitor_get_yaml_value "tool" "$d/metadata.md")
            fi
            t="${t:-?}"
            local q=$(_skill_get_question "$d")
            [[ ${#q} -gt 50 ]] && q="${q:0:47}..."
            printf "  %-38s %-7s %-14s %-6s %s\n" "$name" "[$t]" "$st" "$dur" "$q"
            ((count++))
            [[ $count -ge 10 ]] && break
        done < <(_skill_list_dirs_sorted)
        echo ""
        echo "=========================================="
        return 0
    fi

    # 交互模式: 实时终端监控器
    tput smcup  # Save screen
    tput civis  # Hide cursor
    clear
    tput csr $status_bar_height $(($(tput lines) - 1))

    local monitor_running=true
    local cleanup_done=false
    local TAIL_PID=""

    # 干净地停止 tail 后台进程
    # 使用 disown 从 zsh 作业表中移除，防止 "[N] terminated" 消息
    _skill_stop_tail() {
        if [[ -n "${TAIL_PID:-}" ]]; then
            disown "$TAIL_PID" 2>/dev/null || true
            kill "$TAIL_PID" 2>/dev/null || true
            wait "$TAIL_PID" 2>/dev/null || true
            TAIL_PID=""
        fi
    }

    _skill_cleanup() {
        [[ "${cleanup_done:-false}" == "true" ]] && return
        cleanup_done=true
        monitor_running=false
        trap - INT TERM EXIT 2>/dev/null || true
        _skill_stop_tail
        # Reset scroll region before restoring screen
        printf '\033[r' 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        tput rmcup 2>/dev/null || true
        echo ""
        echo "Monitor stopped."
    }

    # 信号处理器（bash/zsh 兼容）
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        TRAPINT() { _skill_cleanup; return 130; }
        TRAPTERM() { _skill_cleanup; return 143; }
        trap '_skill_cleanup' EXIT
    else
        trap '_skill_cleanup' EXIT INT TERM
    fi

    # 主监控循环
    while [[ "$monitor_running" == "true" ]]; do
        # 检查技能目录是否仍然存在
        if [[ ! -d "$skill_dir" ]]; then
            _skill_cleanup
            echo "Skill directory deleted."
            return 0
        fi

        # 查找具有可观看内容的最佳调用
        local best_result=$(_skill_find_best_invocation)
        local focus_dir="${best_result%%|*}"
        local monitored_file="${best_result#*|}"

        if [[ -z "$focus_dir" ]]; then
            tput cup $status_bar_height 0
            echo "Waiting for skill invocations..."
            sleep "$check_interval"
            continue
        fi

        # 检测聚焦的调用是否已更改
        if [[ "$focus_dir" != "$current_skill_dir" ]]; then
            current_skill_dir="$focus_dir"
            current_file=""
            _skill_stop_tail
        fi

        # 绘制状态栏
        _skill_draw_status_bar "$focus_dir" "$monitored_file"

        # 如果监控的文件已更改则切换到新文件
        if [[ "$monitored_file" != "$current_file" ]] && [[ -n "$monitored_file" ]]; then
            current_file="$monitored_file"
            _skill_stop_tail
            tput cup $status_bar_height 0
            tput ed
            tail -n +1 -f "$current_file" 2>/dev/null &
            TAIL_PID=$!
        fi

        if [[ -z "$current_file" ]]; then
            tput cup $status_bar_height 0
            echo "Waiting for skill output..."
        fi

        sleep "$check_interval"
    done

    # 重置 trap 处理器
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        unfunction TRAPINT TRAPTERM 2>/dev/null || true
    else
        trap - INT TERM EXIT
    fi
}
