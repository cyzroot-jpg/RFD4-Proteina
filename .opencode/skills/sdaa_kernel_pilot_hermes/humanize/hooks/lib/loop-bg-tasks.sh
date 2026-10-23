#!/usr/bin/env bash
#
# RLCR stop hook 的后台任务辅助函数。
#
# 拥有检查 Claude Code 转录本以决定钩子是否应短路的所有逻辑
# （主会话仍在等待异步 Agent/Bash 调度），加上 stop hook 在
# 正常门控逻辑之前运行的四个守卫块：
#
#   1. 调用者歧义标记守卫
#   2. 跨会话驻留循环守卫
#   3. 提前退出：待处理的后台任务
#   4. 同会话过期标记清理
#
# 依赖于首先源码引入的 loop-common.sh（FIELD_SESSION_ID、resolve_active_state_file）。
#

# 源码守卫。
[[ -n "${_LOOP_BG_TASKS_LOADED:-}" ]] && return 0 2>/dev/null || true
_LOOP_BG_TASKS_LOADED=1

# 将路径中的前导 "~" 或 "~/" 扩展为 "$HOME"，不使用 eval。
# 仅扩展裸 "~" 和 "~/..." 形式；"~user/..." 和所有其他输入
# （绝对路径、相对路径、空字符串）按原样返回。
#
# 用法：expand_leading_tilde "$path"
#   将规范化后的路径打印到 stdout。
expand_leading_tilde() {
    local path="$1"
    case "$path" in
        '~')   printf '%s' "${HOME:-}" ;;
        '~/'*) printf '%s/%s' "${HOME:-}" "${path#'~/'}" ;;
        *)     printf '%s' "$path" ;;
    esac
}

# 从钩子 JSON 输入中提取 transcript_path 并扩展任何前导波浪号。
# 用法：extract_transcript_path "$json_input"
# 将 transcript_path 输出到 stdout，如果不可用则输出空字符串。
extract_transcript_path() {
    local input="$1"
    local raw
    raw=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
    expand_leading_tilde "$raw"
}

# 将 RLCR 循环目录 basename 转换为适合过滤转录本事件的
# 词法可比较的 ISO-8601 UTC 时间戳。
#
# `setup-rlcr-loop.sh` 在系统的本地挂钟中创建名为 `YYYY-MM-DD_HH-MM-SS`
# 的循环目录（它调用 `date +%Y-%m-%d_%H-%M-%S` 而不带 `-u`）。
# Claude 转录本事件携带实际的 UTC 时间戳，如 `2026-04-16T13:19:26.819Z`。
# 为了正确比较它们，此辅助函数通过两步将本地挂钟解析转换回真实的 UTC 时刻：
# 解析本地 -> 纪元秒 -> UTC 格式。
#
# `.000Z` 后缀保持亚秒级转录本时间戳在同一秒内通过词法字符串排序比较更大。
#
# 用法：derive_loop_start_iso_ts "$loop_dir"
#   打印 ISO-8601 UTC 时间戳，当 basename 不匹配预期格式或
#   本地 `date` 二进制文件无法解析时打印空字符串。
derive_loop_start_iso_ts() {
    local loop_dir="$1"
    local base
    base=$(basename "$loop_dir" 2>/dev/null || echo "")
    if [[ ! "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2})$ ]]; then
        return
    fi
    local local_datetime
    local_datetime="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}:${BASH_REMATCH[3]}:${BASH_REMATCH[4]}"

    # 本地挂钟 -> 纪元秒。先试 GNU `date -d`，
    # 再试 BSD/macOS `date -j -f ...`。两者都遵守调用者的 TZ 进行解释，
    # 匹配 setup-rlcr-loop.sh 在循环目录创建时的行为。
    local epoch
    epoch=$(date -d "$local_datetime" +%s 2>/dev/null) || epoch=""
    if [[ -z "$epoch" ]]; then
        epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$local_datetime" +%s 2>/dev/null) || epoch=""
    fi
    if [[ -z "$epoch" ]]; then
        return
    fi

    # 纪元 -> UTC ISO-8601。先试 GNU 再试 BSD。
    local utc_iso
    utc_iso=$(date -u -d "@$epoch" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null) || utc_iso=""
    if [[ -z "$utc_iso" ]]; then
        utc_iso=$(date -u -r "$epoch" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null) || utc_iso=""
    fi
    printf '%s' "$utc_iso"
}

# 从转录本路径派生 Claude Code 任务输出目录。
#
# Claude Code 在以下位置写入后台任务输出文件：
#   /tmp/claude-<uid>/<project-slug>/<session-id>/tasks/<task-id>.output
#
# 项目 slug 和会话 id 编码在转录本路径中：
#   <claude-home>/projects/<slug>/<session-id>.jsonl
#
# 用法：derive_tasks_dir_from_transcript "$transcript_path"
#   打印任务目录路径，当派生失败时不打印任何内容。
derive_tasks_dir_from_transcript() {
    local transcript_path="$1"
    [[ -z "$transcript_path" ]] && return
    local slug sid uid
    slug=$(basename "$(dirname "$transcript_path")" 2>/dev/null)
    sid=$(basename "$transcript_path" .jsonl 2>/dev/null)
    uid=$(id -u 2>/dev/null) || return
    if [[ -z "$slug" ]] || [[ "$slug" == "." ]] || [[ -z "$sid" ]] || [[ -z "$uid" ]]; then
        return
    fi
    printf '/tmp/claude-%s/%s/%s/tasks' "$uid" "$slug" "$sid"
}

# 如果 task_id 标识的后台任务似乎存活则返回 0
# （输出文件不存在，或 lsof 报告 >= 1 个持有者），
# 如果确认死亡则返回 1（输出文件存在且 lsof 报告 0 个持有者）。
#
# 失败开放：当输出文件不存在时、当 lsof 二进制文件不可用时、
# 或当 lsof 因"无持有者"以外的任何原因退出非零时返回 0（存活）。
#
# 设置 LSOF_BIN 以覆盖 lsof 二进制路径（在测试中使用）。
#
# 用法：is_bg_task_alive "$task_id" "$tasks_dir"
is_bg_task_alive() {
    local task_id="$1" tasks_dir="$2"
    local lsof_bin="${LSOF_BIN:-lsof}"
    local output_file="$tasks_dir/$task_id.output"
    # 输出文件不存在 -> 失败开放（视为仍在运行）。
    [[ -f "$output_file" ]] || return 0
    # lsof 不可用 -> 失败开放。
    command -v "$lsof_bin" >/dev/null 2>&1 || return 0
    # 当 >= 1 个进程打开文件时 lsof 退出 0，否则退出 1。
    "$lsof_bin" "$output_file" >/dev/null 2>&1
}

# 过滤换行分隔的任务 ID 列表，仅保留通过 is_bg_task_alive 的那些。
# 每行打印一个存活的 ID。
#
# 用法：prune_dead_bg_task_ids "$pending_ids" "$tasks_dir"
prune_dead_bg_task_ids() {
    local pending_ids="$1" tasks_dir="$2"
    local task_id
    while IFS= read -r task_id; do
        [[ -z "$task_id" ]] && continue
        is_bg_task_alive "$task_id" "$tasks_dir" && printf '%s\n' "$task_id"
    done <<< "$pending_ids"
}

# 枚举已启动但尚未在 Claude Code transcript.jsonl 中标记为完成的后台任务 id。
#
# 启动事件（在 tool_result "user" 消息中检查）：
#   - 后台子代理：toolUseResult.isAsync == true
#     -> id 是 toolUseResult.agentId
#   - 后台 shell：toolUseResult.backgroundTaskId 非空
#     -> id 是 toolUseResult.backgroundTaskId
#
# 完成事件从两种 Claude Code 转录本形式中识别：
#
#   1. 结构化 SDK 记录
#      （参见 docs/typescript.md 中的 SDKTaskNotificationMessage）：
#      `type == "system"`，`subtype == "task_notification"`，
#      `task_id` 是完成的 id。任何 `status` 值
#      （completed、failed、stopped 等）都被视为终端状态。
#
#   2. 旧版队列操作 enqueue，其 `content` 嵌入了带有
#      `<task-id>...</task-id>` 的 `<task-notification>` XML 块；
#      为旧版 Claude Code 版本产生的转录本保留。
#
# pending := launched \ completed
#
# 可选的第二个参数 `since_ts`（ISO-8601 字符串，例如
# `derive_loop_start_iso_ts` 返回的值）：当提供时，只有顶层
# `.timestamp` 字段 >= `since_ts` 的启动事件才算作候选启动。
# 没有 `.timestamp` 的事件被包含（保持夹具转录本和旧记录格式工作）。
# 这防止循环前的会话范围后台工作固定没有自己待处理工作的 RLCR 循环。
#
# 用法：list_pending_background_task_ids "$transcript_path" [since_ts]
#   - 在 stdout 上每行输出一个 id（可能为空）。
#   - 当转录本可读时返回 0（包括没有待处理任务时）。
#     当转录本路径为空、不是常规文件或 jq 不可用时返回 1，
#     因此调用者必须将非零视为"未知 -> 不要短路"。
list_pending_background_task_ids() {
    local transcript_path="$1"
    local since_ts="${2:-}"

    # 规范化前导波浪号，以便直接调用者（测试、临时脚本）
    # 即使 transcript_path 未通过 extract_transcript_path 路由也能正确工作。
    transcript_path=$(expand_leading_tilde "$transcript_path")

    if [[ -z "$transcript_path" ]] || [[ ! -f "$transcript_path" ]]; then
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    local launched completed
    launched=$(jq -r --arg since_ts "$since_ts" '
        select(.toolUseResult != null)
        | select(
            ($since_ts == ""
             or ((.timestamp // "") == "")
             or ((.timestamp // "") >= $since_ts))
          )
        | select(
            (.toolUseResult.isAsync == true and (.toolUseResult.agentId // "") != "")
            or ((.toolUseResult.backgroundTaskId // "") != "")
          )
        | (.toolUseResult.agentId // .toolUseResult.backgroundTaskId)
    ' "$transcript_path" 2>/dev/null | sort -u) || return 1

    # 两种完成格式的并集。任一来源单独就足以将已启动的 id 标记为终端状态。
    #
    # 旧版分支上的 `grep -oE || true` 守卫防止 `set -o pipefail`
    # 在转录本中没有旧版队列操作记录时毒化组合管道
    # （grep 带 `-o` 在无匹配时退出 1，否则会清除上面收集的任何
    # SDK task_notification 结果）。
    completed=$(
        {
            jq -r '
                select(.type == "system" and .subtype == "task_notification")
                | (.task_id // empty)
            ' "$transcript_path" 2>/dev/null
            jq -r '
                select(.type == "queue-operation" and .operation == "enqueue")
                | (.content // "" | tostring)
                | select(contains("<task-notification>"))
            ' "$transcript_path" 2>/dev/null \
                | { grep -oE '<task-id>[^<]+</task-id>' || true; } \
                | sed -E 's|</?task-id>||g'
        } | sort -u | sed '/^$/d'
    ) || completed=""

    # 收集没有匹配完成通知的已启动 id。
    local pending
    pending=$(comm -23 \
        <(printf '%s\n' "$launched" | sed '/^$/d') \
        <(printf '%s\n' "$completed" | sed '/^$/d'))

    # 应用存活探针：丢弃输出文件存在但没有打开文件描述符的孤立任务 ID
    # （在没有完成事件的情况下被杀死）。
    if [[ -n "$pending" ]]; then
        local tasks_dir
        tasks_dir=$(derive_tasks_dir_from_transcript "$transcript_path")
        if [[ -n "$tasks_dir" ]]; then
            pending=$(prune_dead_bg_task_ids "$pending" "$tasks_dir")
        fi
    fi

    printf '%s\n' "$pending" | sed '/^$/d'
}

# 当转录本显示至少一个待处理的后台任务时返回 0。
# 当未检测到待处理任务时返回 1（包括关闭失败的情况，
# 如缺失转录本、非文件路径或 jq 不可用）。
#
# 用法：has_pending_background_tasks "$transcript_path" [since_ts]
has_pending_background_tasks() {
    local transcript_path="$1"
    local since_ts="${2:-}"
    local pending
    pending=$(list_pending_background_task_ids "$transcript_path" "$since_ts" 2>/dev/null) || return 1
    [[ -n "$pending" ]]
}

# 将待处理后台任务的计数打印到 stdout。对任何错误情况打印 0，
# 以便调用者仍能安全地格式化消息。
#
# 用法：count_pending_background_tasks "$transcript_path" [since_ts]
count_pending_background_tasks() {
    local transcript_path="$1"
    local since_ts="${2:-}"
    local pending
    pending=$(list_pending_background_task_ids "$transcript_path" "$since_ts" 2>/dev/null) || {
        echo 0
        return 0
    }
    if [[ -z "$pending" ]]; then
        echo 0
    else
        printf '%s\n' "$pending" | sed '/^$/d' | wc -l | tr -d ' '
    fi
}

# stop hook 的单入口点：按顺序运行四个守卫块
# （调用者歧义、跨会话驻留、待处理后台任务短路、同会话过期标记清理）。
# 当守卫决定短路 stop hook 时，它在 stdout 上发出适当的 JSON 并直接
# `exit 0`；调用者（源码引入钩子脚本）永远不会返回。
# 当没有守卫触发时，此函数返回 0，stop hook 继续其正常门控逻辑。
#
# 依赖于 loop-common.sh 中的 FIELD_SESSION_ID 和 resolve_active_state_file。
#
# 用法：handle_bg_task_short_circuit "$LOOP_DIR" "$HOOK_INPUT" "$HOOK_SESSION_ID"
handle_bg_task_short_circuit() {
    local loop_dir="$1" hook_input="$2" hook_session_id="$3"

    # 下面守卫块使用的共享状态。
    # 循环开始边界：从循环目录 basename 派生（`YYYY-MM-DD_HH-MM-SS`）。
    # 空表示派生失败；辅助函数将空的 since_ts 视为无边界。
    local loop_start_ts transcript_path
    loop_start_ts=$(derive_loop_start_iso_ts "$loop_dir")
    transcript_path=$(extract_transcript_path "$hook_input")

    # ----------------------------------------
    # 调用者歧义标记守卫
    # ----------------------------------------
    # 如果 bg-pending.marker 存在但此钩子调用没有 session_id
    # （典型的 scripts/rlcr-stop-gate.sh 未使用 --session-id 调用，
    # 或任何其他不转发 session_id 的调用者），我们无法判断此调用者
    # 是否拥有驻留的循环。采取任一分支（下面的外部会话守卫或更下面的
    # 同会话清理）在两种可能的现实中的一种是错误的。
    # 静默退出 0：真正的 Claude 钩子将携带 session_id 到达，
    # 并从权威上下文驱动驻留/清理。
    if [[ -f "$loop_dir/bg-pending.marker" ]] && [[ -z "$hook_session_id" ]]; then
        exit 0
    fi

    # ----------------------------------------
    # 跨会话驻留循环守卫
    # ----------------------------------------
    # 如果 find_active_loop 通过标记回传将此目录交出，则循环被
    # 等待后台任务的不同会话驻留。当前会话无权检查或推进该循环 -
    # 其转录本看不到任何外部后台活动 - 因此唯一安全的响应是
    # 带着不同的 systemMessage 退出 0，并保持每个磁盘产物
    # （状态文件、存储的 session_id、标记）不变。
    #
    # session-id 比较的两侧必须非空才能触发此分支：
    # 空的 hook_session_id 已通过上面的调用者歧义守卫退出，
    # 空的存储 session_id 保持 find_active_loop 的向后兼容"匹配任何"语义。
    if [[ -f "$loop_dir/bg-pending.marker" ]]; then
        local guard_state_file guard_stored_sid
        guard_state_file=$(resolve_active_state_file "$loop_dir")
        if [[ -n "$guard_state_file" ]]; then
            guard_stored_sid=$(awk -v key="${FIELD_SESSION_ID}" 'BEGIN{f=0} /^---$/{f++; next} f==1 && $0 ~ "^"key":"{sub("^"key":[[:space:]]*",""); print; exit}' "$guard_state_file" 2>/dev/null | tr -d ' ') || true
            if [[ -n "$guard_stored_sid" ]] \
               && [[ -n "$hook_session_id" ]] \
               && [[ "$guard_stored_sid" != "$hook_session_id" ]]; then
                jq -n \
                    '{systemMessage: "RLCR loop in this repo is parked by another Claude session waiting for background work. Stop allowed; your session leaves the loop untouched. If that session ended, run /humanize:cancel-rlcr-loop to clean up."}'
                exit 0
            fi
        fi
    fi

    # ----------------------------------------
    # 提前退出：待处理的后台任务
    # ----------------------------------------
    # 当主 Claude Code 会话已派发后台工作（run_in_background=true 的 Agent，
    # 或 run_in_background=true 的 Bash）且其完成通知尚未到达时，
    # 自然的"停止"就是"我正在等待后台任务"。
    # 在该状态下运行 git/摘要/BitLesson/Codex 门控会浪费 Codex 令牌并产生低信号审查。
    #
    # 允许停止（exit 0）并发出用户可见的 systemMessage，
    # 以便没有人将暂停误认为循环完成。磁盘上的循环状态保持不变 -
    # 下一次自然停止（后台工作完成后）将重新进入此钩子，
    # 没有待处理任务并运行正常流程。
    #
    # loop_start_ts 将转录本扫描限制为在此循环期间实际发生的启动；
    # 较早的会话范围后台活动不能固定循环。
    #
    # 此检查必须在任何其他门控（阶段检测、状态解析、分支/计划/git 清洁/
    # 摘要/最大迭代检查、Codex 审查）之前运行。
    local pending_bg_ids
    pending_bg_ids=$(list_pending_background_task_ids "$transcript_path" "$loop_start_ts" 2>/dev/null) || true
    if [[ -n "$pending_bg_ids" ]]; then
        local pending_bg_count
        pending_bg_count=$(printf '%s\n' "$pending_bg_ids" | sed '/^$/d' | wc -l | tr -d ' ')
        # 将循环标记为驻留；允许同一会话稍后恢复，
        # 并使上面的跨会话守卫在用户在后台任务完成之前
        # 在此仓库中打开不同的 Claude 会话时可达。
        : > "$loop_dir/bg-pending.marker" 2>/dev/null || true
        jq -n --arg count "$pending_bg_count" \
            '{systemMessage: ("RLCR loop active. " + $count + " background task(s) still running - stop allowed naturally; loop has NOT terminated and will resume on completion.")}'
        exit 0
    fi

    # ----------------------------------------
    # 同会话过期标记清理
    # ----------------------------------------
    # 上面的跨会话守卫已为每个外部会话退出，
    # 因此在标记存在的情况下到达这里意味着当前会话驻留了循环，
    # 现在带着显示没有待处理后台事件的转录本回来了。
    # 在正常流程接管之前移除过期标记。
    #
    # 两部分守卫确保我们永远不会在没有证据的情况下丢弃驻留状态信号：
    #   (a) list_pending_background_task_ids 返回退出 0 -- 转录本存在、
    #       可读且解析成功。辅助函数对缺失文件、空路径、jq 解析失败
    #       和截断是关闭失败的，因此即使转录本"文件"存在，
    #       非零退出也会在此阻止清理。
    #   (b) 其输出为空 -- 证明"无待处理"是权威验证的，
    #       而不是从失败推断的。
    # 检查使用单个新调用，以便我们捕获退出码和空性而无需双重运行 jq。
    if [[ -f "$loop_dir/bg-pending.marker" ]]; then
        local pending_bg_check
        if pending_bg_check=$(list_pending_background_task_ids "$transcript_path" "$loop_start_ts" 2>/dev/null) \
           && [[ -z "$pending_bg_check" ]]; then
            rm -f "$loop_dir/bg-pending.marker" 2>/dev/null || true
        fi
    fi
}
