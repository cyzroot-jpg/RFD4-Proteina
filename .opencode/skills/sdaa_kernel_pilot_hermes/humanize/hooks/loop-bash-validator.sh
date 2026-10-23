#!/usr/bin/env bash
#
# PreToolUse 钩子：验证 RLCR 循环中的 Bash 命令
#
# 阻止通过 shell 命令绕过 Write/Edit 钩子的尝试：
# - cat/echo/printf > file.md（重定向）
# - tee file.md
# - sed -i file.md（原地编辑）
# - 通过 Bash 修改 goal-tracker.md
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

if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Bash 工具需要 command 参数；缺失说明事件载荷异常，无可校验内容，放行不报错
if ! require_tool_input_field "$HOOK_INPUT" "command" 2>/dev/null; then
    exit 0
fi

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')
COMMAND_LOWER=$(to_lower "$COMMAND")

# ========================================
# 查找活跃循环（多个检查需要）
# ========================================

PROJECT_ROOT="$(resolve_project_root)" || exit 0

# 从钩子输入中提取 session_id 用于会话感知的循环过滤
HOOK_SESSION_ID=$(extract_session_id "$HOOK_INPUT")

# 检查活跃的 RLCR 循环（按 session_id 过滤）
LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"
ACTIVE_LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR" "$HOOK_SESSION_ID")

# ========================================
# 方法论分析阶段 Bash 限制
# ========================================
# 在方法论分析期间，阻止修改文件的 bash 命令。
# 仅允许只读操作和 cancel-rlcr-loop.sh。
# 这防止了 Codex 签署后对源代码的修改。
#
# 已接受的限制：
# - 只读 bash 命令（cat、grep、find 等）不会被阻止。阻止它们会破坏基本的
#   Claude 操作。分析提示词指导 Claude 仅从 methodology-analysis-report.md
#   中派生面向用户的内容。
# - 生成的代理（不同的 session_id）不受钩子限制；它们的清理由分析提示词强制执行。
#   这是钩子架构的固有限制，无法区分生成的代理和无关会话。
#
# 仅使用会话匹配的循环。不要回退到未过滤的搜索，
# 因为这会错误地限制在同一仓库中打开的无关会话。
_MA_BASH_DIR="$ACTIVE_LOOP_DIR"

if [[ -n "$_MA_BASH_DIR" ]] && [[ -f "$_MA_BASH_DIR/methodology-analysis-state.md" ]]; then
    # 仅允许 cancel-rlcr-loop.sh 作为前导命令（不是作为 cp/mv 等另一个命令的参数）。
    # 可选的路径前缀必须是不含嵌入空格的单个令牌，否则像
    # `bash cancel-rlcr-loop.sh` 或 `tee cancel-rlcr-loop.sh` 这样的命令会匹配。
    # 脚本名称后面必须跟空格或行尾，这样尾随令牌就无法隐藏额外的参数。
    #
    # 同时拒绝任何可以在取消调用之后注入或重定向工作的 shell 元字符：
    # 管道/序列/后台运算符、命令替换（$(...) 或反引号）、重定向（<、>）
    # 和多行负载。之前较窄的检查只拒绝了 ; | &，
    # 让像 `cancel-rlcr-loop.sh $(touch /tmp/pwn)` 或换行分隔的第二个命令
    # 这样的负载绕过此早期退出，在下游阻止器运行之前到达任意文件修改。
    _ma_has_shell_meta=false
    case "$COMMAND_LOWER" in
        *';'*|*'|'*|*'&'*|*'`'*|*'>'*|*'<'*|*'$('*|*$'\n'*)
            _ma_has_shell_meta=true
            ;;
    esac
    if [[ "$_ma_has_shell_meta" != "true" ]] && \
       echo "$COMMAND_LOWER" | grep -qE '^[[:space:]]*"?([^[:space:]"]+/)?cancel-rlcr-loop\.sh"?([[:space:]]|$)'; then
        exit 0
    fi
    # 阻止修改工作树的 git 命令
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])git[[:space:]]+(commit|add|reset|checkout|merge|rebase|cherry-pick|am|apply|stash|push|restore|clean|rm|mv|switch|pull|clone|submodule|worktree)'; then
        echo "# Bash Blocked During Methodology Analysis

Git write commands are not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止文件操作命令（touch、mv、cp、rm、mkdir、ln、patch 等）
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])(tee|install|touch|mv|cp|rm|dd|truncate|chmod|chown|mkdir|rmdir|ln|mktemp|patch)[[:space:]]'; then
        echo "# Bash Blocked During Methodology Analysis

File modification commands are not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止原地文件编辑工具
    if echo "$COMMAND_LOWER" | grep -qE 'sed[[:space:]]+-i|awk[[:space:]]+-i[[:space:]]+inplace|perl[[:space:]]+-[^[:space:]]*i'; then
        echo "# Bash Blocked During Methodology Analysis

In-place file editing is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止可能写入文件的常见解释器（纵深防御）
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])(python[23]?|ruby|node|perl|php)[[:space:]]'; then
        echo "# Bash Blocked During Methodology Analysis

Running interpreters is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止 shell 脚本入口点（bash script.sh、sh script.sh、source、.）
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])(/usr/bin/env[[:space:]]+)?(bash|sh|zsh|/bin/bash|/bin/sh|/bin/zsh)[[:space:]]'; then
        echo "# Bash Blocked During Methodology Analysis

Running shell scripts is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止执行任意命令的构建工具
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])(make|cmake|ninja|gradle|mvn|ant|cargo|go[[:space:]]+run|go[[:space:]]+generate|npm[[:space:]]+run|yarn[[:space:]]+run|npx|pnpm)[[:space:]]'; then
        echo "# Bash Blocked During Methodology Analysis

Build tools are not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止 source/dot 命令（source script.sh、. script.sh）
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])(source|\.)[ 	]+[^[:space:]]'; then
        echo "# Bash Blocked During Methodology Analysis

Sourcing scripts is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止直接脚本执行（./script.sh、../script.sh、/path/to/script）
    if echo "$COMMAND_LOWER" | grep -qE '(^|[[:space:];|&])\.{0,2}/[^[:space:]>|&;]*\.(sh|bash|py|rb|pl|js)'; then
        echo "# Bash Blocked During Methodology Analysis

Direct script execution is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
    # 阻止输出重定向到文件（捕获 cat > file、echo > file 等）
    # 剥离安全的重定向（/dev/ 路径、fd 复制）然后检查剩余的 >
    _ma_stripped=$(echo "$COMMAND_LOWER" | sed 's|[0-9]*>[>]*[[:space:]]*/dev/[^[:space:]]*||g; s|[0-9]*>&[0-9]*||g')
    if echo "$_ma_stripped" | grep -qE '[>]'; then
        echo "# Bash Blocked During Methodology Analysis

File redirection is not allowed during the methodology analysis phase." >&2
        exit 2
    fi
fi

# 如果没有活跃的 RLCR 循环，允许所有命令
if [[ -z "$ACTIVE_LOOP_DIR" ]]; then
    exit 0
fi

# ========================================
# 阻止钩子脚本的直接执行
# ========================================
# 防止 Claude 手动运行 stop hook 或 stop gate 脚本。
# 这些脚本应仅由钩子系统调用，而不是通过 Bash。

BLOCKED_HOOK_SCRIPTS="(loop-codex-stop-hook\.sh|rlcr-stop-gate\.sh)"
HOOK_ASSIGNMENT_PREFIX="[[:alpha:]_][[:alnum:]_]*=[^[:space:];&|]+"
HOOK_COMMAND_PREFIX="command([[:space:]]+(-[^[:space:];&|]+|--))*"
HOOK_ENV_PREFIX="env([[:space:]]+(-[^[:space:];&|]+|--|${HOOK_ASSIGNMENT_PREFIX}))*"
HOOK_UTILITY_ARG="[^[:space:];&|]+"
HOOK_TIMEOUT_OPTION="(-[^[:space:];&|]+([[:space:]]+${HOOK_UTILITY_ARG})?|--([^[:space:];&|]+(=${HOOK_UTILITY_ARG}|[[:space:]]+${HOOK_UTILITY_ARG})?)?)"
HOOK_NICE_OPTION="(-n([[:space:]]+${HOOK_UTILITY_ARG})?|--adjustment(=${HOOK_UTILITY_ARG}|[[:space:]]+${HOOK_UTILITY_ARG})|-[^[:space:];&|]+|--[^[:space:];&|]+)"
HOOK_TRACE_OPTION="(-[^[:space:];&|]+([[:space:]]+${HOOK_UTILITY_ARG})?|--([^[:space:];&|]+(=${HOOK_UTILITY_ARG}|[[:space:]]+${HOOK_UTILITY_ARG})?)?)"
HOOK_TIMEOUT_PREFIX="timeout([[:space:]]+(${HOOK_TIMEOUT_OPTION}))*([[:space:]]+--)?[[:space:]]+${HOOK_UTILITY_ARG}"
HOOK_NICE_PREFIX="nice([[:space:]]+(${HOOK_NICE_OPTION}))*([[:space:]]+--)?"
HOOK_NOHUP_PREFIX="nohup"
HOOK_TRACE_PREFIX="(strace|ltrace)([[:space:]]+(${HOOK_TRACE_OPTION}))*([[:space:]]+--)?"
HOOK_UTILITY_PREFIX="(${HOOK_TIMEOUT_PREFIX}|${HOOK_NICE_PREFIX}|${HOOK_NOHUP_PREFIX}|${HOOK_TRACE_PREFIX})"
HOOK_WRAPPER_PREFIX_PATTERN="((${HOOK_ASSIGNMENT_PREFIX}|${HOOK_COMMAND_PREFIX}|${HOOK_ENV_PREFIX}|${HOOK_UTILITY_PREFIX})[[:space:]]+)*"
HOOK_LAUNCH_PATTERN="(([^[:space:]]*/)?|(bash|sh|zsh|source|\.)[[:space:]].*)$BLOCKED_HOOK_SCRIPTS"
if echo "$COMMAND_LOWER" | grep -qE "(^|[;&|])[[:space:]]*${HOOK_WRAPPER_PREFIX_PATTERN}${HOOK_LAUNCH_PATTERN}"; then
    stop_hook_direct_execution_blocked_message >&2
    exit 2
fi

# ========================================
# RLCR 循环特定检查
# ========================================
# 以下检查仅在 RLCR 循环活跃时适用

if [[ -n "$ACTIVE_LOOP_DIR" ]]; then
    # 检测是否处于 Finalize 阶段（finalize-state.md 存在）
    STATE_FILE=$(resolve_active_state_file "$ACTIVE_LOOP_DIR")

    # 使用严格验证解析状态文件（格式错误时关闭失败）
    if ! parse_state_file_strict "$STATE_FILE" 2>/dev/null; then
        echo "Error: Malformed state file, blocking operation for safety" >&2
        exit 1
    fi
    CURRENT_ROUND="$STATE_CURRENT_ROUND"

    # ========================================
    # 当 push_every_round 为 false 时阻止 Git Push
    # ========================================
    # 默认行为：提交保留在本地，无需推送到远程

    # 注意：上面已调用 parse_state_file，STATE_* 变量可用
    PUSH_EVERY_ROUND="$STATE_PUSH_EVERY_ROUND"

    if [[ "$PUSH_EVERY_ROUND" != "true" ]]; then
        # 检查命令是否是 git push 命令
        if [[ "$COMMAND_LOWER" =~ ^[[:space:]]*git[[:space:]]+push ]]; then
            FALLBACK="# Git Push Blocked

Commits should stay local during the RLCR loop.
Use --push-every-round flag when starting the loop if you need to push each round."
            load_and_render_safe "$TEMPLATE_DIR" "block/git-push.md" "$FALLBACK" >&2
            exit 2
        fi
    fi
fi

# ========================================
# 阻止针对 .humanize 的 Git Add 命令
# ========================================
# 防止强制将 .humanize 文件添加到版本控制
# 注意：.humanize 在 .gitignore 中，但 git add -f 会绕过它

if git_adds_humanize "$COMMAND_LOWER"; then
    git_add_humanize_blocked_message >&2
    exit 2
fi

# ========================================
# RLCR 状态和文件保护
# ========================================
# 以下检查仅在 RLCR 循环活跃时适用

if [[ -n "$ACTIVE_LOOP_DIR" ]]; then

# ========================================
# 阻止状态文件修改（所有轮次）
# ========================================
# 状态文件由循环系统管理，不是 Claude
# 这包括 state.md 和 finalize-state.md
# 注意：首先检查 finalize-state.md，因为 state\.md 模式也会匹配 finalize-state.md
# 例外：当取消信号文件存在时，允许 mv 到 cancel-state.md
#
# 注意：我们检查两个模式用于 mv/cp：
# 1. command_modifies_file 检查目标是否包含 state.md
# 2. 下面的额外检查捕获源是否包含 state.md（例如 mv state.md /tmp/foo）

if command_modifies_file "$COMMAND_LOWER" "methodology-analysis-state\.md"; then
    # 检查取消信号文件 - 允许授权的取消操作
    if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
        exit 0
    fi
    methodology_analysis_state_file_blocked_message >&2
    exit 2
fi

if command_modifies_file "$COMMAND_LOWER" "finalize-state\.md"; then
    # 检查取消信号文件 - 允许授权的取消操作
    if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
        exit 0
    fi
    finalize_state_file_blocked_message >&2
    exit 2
fi

# 检查 1：目标包含 state.md（覆盖写入、重定向、mv/cp 到 state.md）
if command_modifies_file "$COMMAND_LOWER" "state\.md"; then
    # 检查取消信号文件 - 允许授权的取消操作
    if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
        exit 0
    fi
    state_file_blocked_message >&2
    exit 2
fi

# 检查 2：mv/cp 的源包含 state.md（覆盖从 state.md 到任何目标的 mv/cp）
# 这捕获绕过尝试，如：mv state.md /tmp/foo.txt
# 模式处理：
# - 源路径前的选项，如 -f、--
# - 前导空格和带选项的命令前缀（sudo -u root、env VAR=val、command --）
# - 引用的相对路径，如：mv -- "state.md" /tmp/foo
# - 通过 ;、&&、||、|、|&、& 的命令链接（每个段独立检查）
# - Shell 包装器：sh -c、bash -c、/bin/sh -c、/bin/bash -c
# 要求 state.md 是一个正确的文件名（前面有空格、/ 或引号）
# 注意：sudo/command 模式匹配零个或多个参数（每个：空格 + 可选减号 + 非空格字符）

# 按 shell 运算符拆分命令并检查每个段
# 这捕获链式命令，如：true; mv state.md /tmp/foo
MV_CP_SOURCE_PATTERN="^[[:space:]]*(sudo([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(env[[:space:]]+[^;&|]*[[:space:]]+)?(command([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(mv|cp)[[:space:]].*[[:space:]/\"']state\.md"
MV_CP_FINALIZE_SOURCE_PATTERN="^[[:space:]]*(sudo([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(env[[:space:]]+[^;&|]*[[:space:]]+)?(command([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(mv|cp)[[:space:]].*[[:space:]/\"']finalize-state\.md"
MV_CP_METHODOLOGY_SOURCE_PATTERN="^[[:space:]]*(sudo([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(env[[:space:]]+[^;&|]*[[:space:]]+)?(command([[:space:]]+-?[^[:space:];&|]+)*[[:space:]]+)?(mv|cp)[[:space:]].*[[:space:]/\"']methodology-analysis-state\.md"

# 将 shell 运算符替换为换行符，然后检查每个段
# 顺序很重要：|& 在 | 之前，&& 在单个 & 之前
# 对于 &：用占位符保护重定向（&>>、&>、>&、N>&M），然后按剩余的 & 拆分
# 占位符使用不太可能出现在命令中的控制字符
# 注意：&>> 必须在 &> 之前替换，以避免留下杂散的 >
COMMAND_SEGMENTS=$(echo "$COMMAND_LOWER" | sed '
    s/|&/\n/g
    s/&&/\n/g
    s/&>>/\x03/g
    s/&>/\x01/g
    s/[0-9]*>&[0-9]*/\x02/g
    s/>&/\x02/g
    s/&/\n/g
    s/||/\n/g
    s/|/\n/g
    s/;/\n/g
')
while IFS= read -r SEGMENT; do
    # 跳过空段
    [[ -z "$SEGMENT" ]] && continue

    # 在模式匹配之前剥离前导重定向
    # 这处理以下情况：2>/tmp/x mv、2> /tmp/x mv、>/tmp/x mv、2>&1 mv、&>/tmp/x mv
    # 还处理追加重定向：>> /tmp/x mv、2>> /tmp/x mv、&>> /tmp/x mv
    # 还处理带引号的目标：>> "/tmp/x y" mv、>> '/tmp/x y' mv
    # 还处理 ANSI-C 引用：>> $'/tmp/x y' mv、>> $"/tmp/x y" mv
    # 还处理转义空格目标：>> /tmp/x\ y mv
    # 必须处理：
    # - \x01（来自 &>）后跟可选空格和目标路径（带引号、ANSI-C、转义或不带引号）
    # - \x02（来自 >&、2>&1）没有目标 - 仅剥离占位符
    # - \x03（来自 &>>）后跟可选空格和目标路径（带引号、ANSI-C、转义或不带引号）
    # - 标准重定向 [0-9]*[><]+ 后跟可选空格和目标
    # 顺序：双引号、单引号、ANSI-C $'...'、locale $"..."、转义不带引号、普通不带引号
    # 注意：转义/ANSI-C 模式使用 sed -E 进行扩展正则表达式
    SEGMENT_CLEANED=$(echo "$SEGMENT" | sed '
        :again
        s/^[[:space:]]*\x01[[:space:]]*"[^"]*"[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x01[[:space:]]*'"'"'[^'"'"']*'"'"'[[:space:]]*//
        t again
    ' | sed -E "
        :again
        s/^[[:space:]]*\x01[[:space:]]*\\$'([^'\\\\]|\\\\.)*'[[:space:]]*//
        t again
    " | sed -E '
        :again
        s/^[[:space:]]*\x01[[:space:]]*\$"([^"\\]|\\.)*"[[:space:]]*//
        t again
    ' | sed -E '
        :again
        s/^[[:space:]]*\x01[[:space:]]*([^[:space:]\\]|\\.)+[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x01[[:space:]]*[^[:space:]]*[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x02[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x03[[:space:]]*"[^"]*"[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x03[[:space:]]*'"'"'[^'"'"']*'"'"'[[:space:]]*//
        t again
    ' | sed -E "
        :again
        s/^[[:space:]]*\x03[[:space:]]*\\$'([^'\\\\]|\\\\.)*'[[:space:]]*//
        t again
    " | sed -E '
        :again
        s/^[[:space:]]*\x03[[:space:]]*\$"([^"\\]|\\.)*"[[:space:]]*//
        t again
    ' | sed -E '
        :again
        s/^[[:space:]]*\x03[[:space:]]*([^[:space:]\\]|\\.)+[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*\x03[[:space:]]*[^[:space:]]*[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*[0-9]*[><][><]*[[:space:]]*"[^"]*"[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*[0-9]*[><][><]*[[:space:]]*'"'"'[^'"'"']*'"'"'[[:space:]]*//
        t again
    ' | sed -E "
        :again
        s/^[[:space:]]*[0-9]*[><]+[[:space:]]*\\$'([^'\\\\]|\\\\.)*'[[:space:]]*//
        t again
    " | sed -E '
        :again
        s/^[[:space:]]*[0-9]*[><]+[[:space:]]*\$"([^"\\]|\\.)*"[[:space:]]*//
        t again
    ' | sed -E '
        :again
        s/^[[:space:]]*[0-9]*[><]+[[:space:]]*([^[:space:]\\]|\\.)+[[:space:]]*//
        t again
    ' | sed '
        :again
        s/^[[:space:]]*[0-9]*[><][><]*[[:space:]]*[^[:space:]]*[[:space:]]*//
        t again
    ')

    # 首先检查 methodology-analysis-state.md 作为源（最具体的模式）
    if echo "$SEGMENT_CLEANED" | grep -qE "$MV_CP_METHODOLOGY_SOURCE_PATTERN"; then
        # 检查取消信号文件 - 允许授权的取消操作
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        methodology_analysis_state_file_blocked_message >&2
        exit 2
    fi

    # 检查 finalize-state.md 作为源（比 state.md 更具体）
    if echo "$SEGMENT_CLEANED" | grep -qE "$MV_CP_FINALIZE_SOURCE_PATTERN"; then
        # 检查取消信号文件 - 允许授权的取消操作
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        finalize_state_file_blocked_message >&2
        exit 2
    fi

    if echo "$SEGMENT_CLEANED" | grep -qE "$MV_CP_SOURCE_PATTERN"; then
        # 检查取消信号文件 - 允许授权的取消操作
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        state_file_blocked_message >&2
        exit 2
    fi
done <<< "$COMMAND_SEGMENTS"

# 检查 3：Shell 包装器绕过（sh -c、bash -c）
# 这捕获绕过尝试，如：sh -c 'mv state.md /tmp/foo'
# 模式：查找带 -c 标志的 sh/bash，且负载中有 state.md 或 finalize-state.md
if echo "$COMMAND_LOWER" | grep -qE "(^|[[:space:]/])(sh|bash)[[:space:]]+-c[[:space:]]"; then
    # 检测到 Shell 包装器 - 检查负载是否包含 mv/cp methodology-analysis-state.md（最具体）
    if echo "$COMMAND_LOWER" | grep -qE "(mv|cp)[[:space:]].*methodology-analysis-state\.md"; then
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        methodology_analysis_state_file_blocked_message >&2
        exit 2
    fi
    # 检测到 Shell 包装器 - 检查负载是否包含 mv/cp finalize-state.md（先检查，更具体）
    if echo "$COMMAND_LOWER" | grep -qE "(mv|cp)[[:space:]].*finalize-state\.md"; then
        # 检查取消信号文件 - 允许授权的取消操作
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        finalize_state_file_blocked_message >&2
        exit 2
    fi
    # 检测到 Shell 包装器 - 检查负载是否包含 mv/cp state.md
    if echo "$COMMAND_LOWER" | grep -qE "(mv|cp)[[:space:]].*state\.md"; then
        # 检查取消信号文件 - 允许授权的取消操作
        if is_cancel_authorized "$ACTIVE_LOOP_DIR" "$COMMAND_LOWER"; then
            exit 0
        fi
        state_file_blocked_message >&2
        exit 2
    fi
fi

# ========================================
# 阻止计划备份修改（所有轮次）
# ========================================
# 计划备份是只读的 - 保护循环期间的计划完整性
# 使用 command_modifies_file 辅助函数进行一致的模式匹配

if command_modifies_file "$COMMAND_LOWER" "\.humanize/rlcr(/[^/]+)?/plan\.md"; then
    FALLBACK="Writing to plan.md backup is not allowed during RLCR loop."
    REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/plan-backup-protected.md" "$FALLBACK")
    echo "$REASON" >&2
    exit 2
fi

# ========================================
# 阻止目标跟踪器修改（所有轮次）
# ========================================
# 轮次 0：提示使用 Write/Edit
# 轮次 > 0：提示将请求放入摘要

if command_modifies_file "$COMMAND_LOWER" "goal-tracker\.md"; then
    GOAL_TRACKER_PATH="$ACTIVE_LOOP_DIR/goal-tracker.md"
    if [[ "$CURRENT_ROUND" -eq 0 ]]; then
        goal_tracker_bash_blocked_message "$GOAL_TRACKER_PATH" >&2
    else
        goal_tracker_blocked_message "$CURRENT_ROUND" "$GOAL_TRACKER_PATH" >&2
    fi
    exit 2
fi

# ========================================
# 阻止提示文件修改（所有轮次）
# ========================================
# 提示文件是只读的 - 它们包含从 Codex 到 Claude 的指令

if command_modifies_file "$COMMAND_LOWER" "round-[0-9]+-prompt\.md"; then
    prompt_write_blocked_message >&2
    exit 2
fi

# ========================================
# 阻止摘要文件修改（所有轮次）
# ========================================
# 摘要文件应使用 Write 或 Edit 工具写入以进行正确验证

if command_modifies_file "$COMMAND_LOWER" "round-[0-9]+-summary\.md"; then
    CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-summary.md"
    summary_bash_blocked_message "$CORRECT_PATH" >&2
    exit 2
fi

# ========================================
# 阻止轮次合同文件修改（所有轮次）
# ========================================
# 轮次合同应使用 Write 或 Edit 工具写入，以便轮次范围
# 与当前循环状态保持一致。

if command_modifies_file "$COMMAND_LOWER" "round-[0-9]+-contract\.md"; then
    CORRECT_PATH="$ACTIVE_LOOP_DIR/round-${CURRENT_ROUND}-contract.md"
    FALLBACK="# Round Contract Bash Write Blocked

Do not use Bash commands to modify round contract files.
Use the Write or Edit tool instead: {{CORRECT_PATH}}"
    load_and_render_safe "$TEMPLATE_DIR" "block/round-contract-bash-write.md" "$FALLBACK" \
        "CORRECT_PATH=$CORRECT_PATH" >&2
    exit 2
fi

# ========================================
# 阻止 Todos 文件修改（所有轮次）
# ========================================

if command_modifies_file "$COMMAND_LOWER" "round-[0-9]+-todos\.md"; then
    # 要求活跃循环目录的完整路径，以防止来自不同根目录的同名绕过。
    # 剥离前导 /private 前缀，以便规范路径（/private/var）在 macOS 上匹配用户路径（/var）。
    ACTIVE_LOOP_DIR_LOWER=$(to_lower "$ACTIVE_LOOP_DIR")
    ACTIVE_LOOP_DIR_LOWER_NORM="${ACTIVE_LOOP_DIR_LOWER#/private}"
    ACTIVE_LOOP_DIR_ESCAPED=$(echo "$ACTIVE_LOOP_DIR_LOWER_NORM" | sed 's/[\\.*^$[(){}+?|]/\\&/g')
    if ! echo "$COMMAND_LOWER" | grep -qE "${ACTIVE_LOOP_DIR_ESCAPED}/round-[12]-todos\.md"; then
        todos_blocked_message "Bash" >&2
        exit 2
    fi
fi

fi  # RLCR 特定检查结束

exit 0
