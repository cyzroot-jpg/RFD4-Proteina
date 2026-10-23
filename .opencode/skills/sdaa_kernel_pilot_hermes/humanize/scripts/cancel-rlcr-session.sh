#!/usr/bin/env bash
#
# Humanize Viz 仪表板的会话级取消助手。
#
# 通过 ID 取消单个 RLCR 会话，同一项目中的其他活跃会话不受影响。
# 镜像了 scripts/cancel-rlcr-loop.sh 中的取消机制（创建 .cancel-requested
# 信号文件，将活跃状态文件重命名为 cancel-state.md），但作用范围限定为
# 指定的会话目录，而非项目中最近的活跃会话。
#
# 用法:
#   cancel-rlcr-session.sh --session-id <SID> [--project <path>] [--force]
#   cancel-rlcr-session.sh <SID>                                       # 旧版用法
#
# 退出码:
#   0 - 成功取消
#   1 - 无此会话，或会话目录中无活跃状态文件
#   2 - 检测到终结阶段，需要 --force
#   3 - 其他错误（缺少参数、目录不可读）

set -euo pipefail

SESSION_ID=""
PROJECT_ROOT=""
FORCE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-id) SESSION_ID="$2"; shift 2 ;;
        --project)    PROJECT_ROOT="$2"; shift 2 ;;
        --force)      FORCE="true"; shift ;;
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | head -n -1
            exit 0
            ;;
        --) shift ;;
        *)
            # 旧版位置参数：第一个非标志参数是会话 ID。
            if [[ -z "$SESSION_ID" ]]; then
                SESSION_ID="$1"
            else
                echo "Error: unexpected positional argument: $1" >&2
                exit 3
            fi
            shift
            ;;
    esac
done

if [[ -z "$SESSION_ID" ]]; then
    echo "Error: --session-id is required" >&2
    echo "Usage: cancel-rlcr-session.sh --session-id <SID> [--project <path>] [--force]" >&2
    exit 3
fi

# 拒绝可能逃逸出项目级 rlcr 目录的会话 ID。
# 有效的 ID 由 ``setup-rlcr-loop.sh`` 从
# ``date +"%Y-%m-%d_%H-%M-%S"`` 生成（数字、破折号、下划线）。
# 允许相同的格式加上少量安全的额外字符（字母数字、点号作为
# 非遍历分隔符），并显式拒绝路径分隔符、前导点号和任何
# 父目录标记，以防止 ``../foo`` 或 ``/etc/passwd`` 等值
# 重命名会话树之外的状态文件。
if [[ "$SESSION_ID" == *"/"* || "$SESSION_ID" == *"\\"* ]]; then
    echo "Error: invalid --session-id (contains path separator): $SESSION_ID" >&2
    exit 3
fi
if [[ "$SESSION_ID" == "." || "$SESSION_ID" == ".." || "$SESSION_ID" == ..* || "$SESSION_ID" == .* ]]; then
    echo "Error: invalid --session-id (leading dot or parent token): $SESSION_ID" >&2
    exit 3
fi
if [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: invalid --session-id (allowed: alphanumerics, dot, underscore, dash): $SESSION_ID" >&2
    exit 3
fi

if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd)" || {
    echo "Error: project directory not found: $PROJECT_ROOT" >&2
    exit 3
}

SESSION_DIR="$PROJECT_ROOT/.humanize/rlcr/$SESSION_ID"

if [[ ! -d "$SESSION_DIR" ]]; then
    echo "NO_SESSION"
    echo "No such session: $SESSION_ID under $PROJECT_ROOT/.humanize/rlcr/" >&2
    exit 1
fi

STATE_FILE="$SESSION_DIR/state.md"
FINALIZE_STATE_FILE="$SESSION_DIR/finalize-state.md"
METHODOLOGY_ANALYSIS_STATE_FILE="$SESSION_DIR/methodology-analysis-state.md"
CANCEL_SIGNAL="$SESSION_DIR/.cancel-requested"

if [[ -f "$STATE_FILE" ]]; then
    LOOP_STATE="NORMAL_LOOP"
    ACTIVE_STATE_FILE="$STATE_FILE"
elif [[ -f "$METHODOLOGY_ANALYSIS_STATE_FILE" ]]; then
    LOOP_STATE="METHODOLOGY_ANALYSIS_PHASE"
    ACTIVE_STATE_FILE="$METHODOLOGY_ANALYSIS_STATE_FILE"
elif [[ -f "$FINALIZE_STATE_FILE" ]]; then
    LOOP_STATE="FINALIZE_PHASE"
    ACTIVE_STATE_FILE="$FINALIZE_STATE_FILE"
else
    echo "NO_ACTIVE_LOOP"
    echo "Session $SESSION_ID has no active state file." >&2
    exit 1
fi

if [[ "$LOOP_STATE" == "FINALIZE_PHASE" && "$FORCE" != "true" ]]; then
    echo "FINALIZE_NEEDS_CONFIRM"
    echo "session: $SESSION_ID is in Finalize Phase. Re-run with --force to cancel anyway." >&2
    exit 2
fi

touch "$CANCEL_SIGNAL"
mv "$ACTIVE_STATE_FILE" "$SESSION_DIR/cancel-state.md"

echo "CANCELLED $SESSION_ID"
echo "Cancelled session $SESSION_ID; other active sessions in $PROJECT_ROOT are untouched."
exit 0
