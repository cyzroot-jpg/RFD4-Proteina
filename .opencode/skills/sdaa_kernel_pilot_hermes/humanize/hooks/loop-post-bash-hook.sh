#!/usr/bin/env bash
#
# RLCR 循环的 PostToolUse Bash 钩子
#
# 在设置后立即将 Claude Code session_id 记录到 state.md 中。
# 此钩子在设置脚本的 Bash 命令完成后立即触发。
#
# 机制：
# 1. 设置脚本创建 .humanize/.pending-session-id，包含：
#    第 1 行：state.md 的路径
#    第 2 行：设置脚本的完整解析路径（命令签名）
# 2. 此钩子在每个 Bash PostToolUse 事件上检查信号文件
# 3. 边界感知匹配：验证 Bash 命令是设置脚本路径的有效调用
#    （路径后跟字符串结尾或空格），防止子字符串和连接形式的误报
# 4. 从钩子 JSON 输入中提取 session_id
# 5. 使用安全的 awk 替换将 session_id 值修补到 state.md 中
# 6. 移除信号文件（一次性机制）
#
# 这确保在任何团队成员可以创建之前记录 session_id，
# 因此只有团队领导者（主会话）受 RLCR 循环钩子的影响。
#

set -euo pipefail
# 本钩子只负责一次性记录 session_id，不是门控钩子。所有显式路径都 exit 0；
# 任何隐式失败（set -e 触发，例如临时文件不可写、jq 异常）应静默放行而不是
# 以无 stderr 的非零退出刷错（信号文件保留，后续轮次仍可重试）。
trap 'exit 0' ERR

# 从 stdin 读取钩子 JSON 输入（清洗无效 UTF-8 字节，防止钩子链报错）。
# iconv 必须容错：偶发 exec 失败（退出码 126）时，未加保护的命令替换会在
# set -e + pipefail 下中止钩子（无 stderr）。用 || true 吞掉失败，仅在非空时替换。
HOOK_INPUT=$(cat)
if command -v iconv >/dev/null 2>&1; then
    _ci=$(printf '%s' "$HOOK_INPUT" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true)
    if [[ -n "$_ci" ]]; then HOOK_INPUT="$_ci"; fi
    unset _ci
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/project-root.sh"

HOOK_COMMAND=""
HOOK_CWD=""
if command -v jq >/dev/null 2>&1; then
    HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
    HOOK_CWD=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi

# 验证 Bash 命令是真正的设置脚本调用（不是任意文本）
# 命令签名是 setup-rlcr-loop.sh 的完整解析路径。
# 我们要求命令以此路径开头（带引号或不带引号），
# 防止像 'echo setup-rlcr-loop.sh' 这样的误报消耗信号。
matches_setup_command_signature() {
    local hook_command="$1"
    local command_signature="$2"

    # 较旧的信号文件不包含命令签名。为这些文件保留先前的行为。
    if [[ -z "$command_signature" ]]; then
        return 0
    fi

    if [[ -z "$hook_command" ]]; then
        return 1
    fi

    # 规范化连续斜杠（例如 "PolyArch//scripts" -> "PolyArch/scripts"）。
    # CLAUDE_PLUGIN_ROOT 可能有尾部斜杠，在命令模板中与 "/scripts/..." 连接时
    # 会产生双斜杠。设置脚本通过 cd+pwd 规范化自己的路径（移除双斜杠），
    # 但 tool_input.command 保留原始字符串。如果不规范化，
    # 下面的字符串比较总是失败，session_id 永远不会被写入。
    # 参见：https://github.com/PolyArch/humanize/issues/67
    hook_command=$(printf '%s' "$hook_command" | tr -s '/')
    command_signature=$(printf '%s' "$command_signature" | tr -s '/')

    # 边界感知匹配：命令必须是有效的设置调用形式。
    # 要求脚本路径后跟字符串结尾或任何 POSIX 空白（[[:space:]]），
    # 防止连接形式。
    # 接受："/full/path/setup-rlcr-loop.sh" args  （带引号，空格分隔）
    #        "/full/path/setup-rlcr-loop.sh"\targs  （带引号，制表符分隔）
    #        "/full/path/setup-rlcr-loop.sh"        （带引号，无参数）
    #        /full/path/setup-rlcr-loop.sh args     （不带引号，空格分隔）
    #        /full/path/setup-rlcr-loop.sh\targs    （不带引号，制表符分隔）
    #        /full/path/setup-rlcr-loop.sh           （不带引号，无参数）
    # 拒绝："/full/path/setup-rlcr-loop.sh"foo     （引号后无边界）
    #        echo /full/path/setup-rlcr-loop.sh      （不以路径开头）
    if [[ "$hook_command" == "\"${command_signature}\"" ]] || [[ "$hook_command" == "\"${command_signature}\""[[:space:]]* ]]; then
        return 0
    fi
    if [[ "$hook_command" == "${command_signature}" ]] || [[ "$hook_command" == "${command_signature}"[[:space:]]* ]]; then
        return 0
    fi

    return 1
}

resolve_candidate_root() {
    local candidate_dir="$1"
    local git_root=""

    if [[ -z "$candidate_dir" || ! -d "$candidate_dir" ]]; then
        return 1
    fi

    git_root=$(git -C "$candidate_dir" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$git_root" ]]; then
        canonicalize_path "$git_root"
    else
        canonicalize_path "$candidate_dir"
    fi
}

try_select_signal_file() {
    local candidate_dir="$1"
    local candidate_root=""
    local candidate_signal=""
    local candidate_state=""
    local candidate_signature=""

    candidate_root=$(resolve_candidate_root "$candidate_dir") || return 1
    candidate_signal="$candidate_root/.humanize/.pending-session-id"
    if [[ ! -f "$candidate_signal" ]]; then
        return 1
    fi

    {
        read -r candidate_state || true
        read -r candidate_signature || true
    } < "$candidate_signal"

    if matches_setup_command_signature "$HOOK_COMMAND" "$candidate_signature"; then
        PROJECT_ROOT="$candidate_root"
        SIGNAL_FILE="$candidate_signal"
        return 0
    fi

    return 1
}

# 定位与此钩子事件关联的项目中的待处理信号，
# 而不仅仅是 shell 进程 cwd。这避免了先前 `cd` 目标的过期信号
# 占用或阻止设置命令。
PROJECT_ROOT=""
SIGNAL_FILE=""
try_select_signal_file "$HOOK_CWD" \
    || try_select_signal_file "${CLAUDE_PROJECT_DIR:-}" \
    || try_select_signal_file "$(pwd)" \
    || true

if [[ -z "$SIGNAL_FILE" ]]; then
    # 没有待记录的 session_id - 这是正常情况
    exit 0
fi

# 读取信号文件内容
# 第 1 行：状态文件路径
# 第 2 行：设置脚本的完整解析路径（命令签名）
STATE_FILE_PATH=""
COMMAND_SIGNATURE=""
{
    read -r STATE_FILE_PATH || true
    read -r COMMAND_SIGNATURE || true
} < "$SIGNAL_FILE"

if [[ -z "$STATE_FILE_PATH" ]] || [[ ! -f "$STATE_FILE_PATH" ]]; then
    # 信号文件为空或指向不存在的状态文件 - 清理
    rm -f "$SIGNAL_FILE"
    exit 0
fi

# 在消耗选定的信号之前重新检查。上面的候选选择可能已跳过来自其他根的过期信号，
# 但这是授权门控。
if ! matches_setup_command_signature "$HOOK_COMMAND" "$COMMAND_SIGNATURE"; then
    # 此 Bash 事件不是来自设置脚本 - 不消耗信号
    exit 0
fi

# 从钩子 JSON 输入中提取 session_id
SESSION_ID=""
if command -v jq >/dev/null 2>&1; then
    SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

if [[ -z "$SESSION_ID" ]]; then
    # 钩子输入中没有可用的 session_id - 留下信号文件供下次尝试
    exit 0
fi

# 修补 state.md：用实际值替换空的 session_id
# 仅在 session_id 当前为空时修补（安全检查）
CURRENT_SESSION_ID=$(grep "^session_id:" "$STATE_FILE_PATH" 2>/dev/null | sed 's/session_id: *//' || echo "")

if [[ -z "$CURRENT_SESSION_ID" ]]; then
    # 使用 awk 进行安全替换（处理 SESSION_ID 中的特殊字符：/、& 等）
    TEMP_FILE="${STATE_FILE_PATH}.tmp.$$"
    awk -v new_id="$SESSION_ID" '{
        if ($0 ~ /^session_id:$/) {
            print "session_id: " new_id
        } else {
            print
        }
    }' "$STATE_FILE_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$STATE_FILE_PATH"
fi

# 移除信号文件（一次性：session_id 现已记录）
rm -f "$SIGNAL_FILE"

exit 0
