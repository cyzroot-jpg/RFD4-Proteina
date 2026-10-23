#!/usr/bin/env bash
# 停止某个项目的 Humanize Viz 仪表盘服务器。
#
# 基于项目的 tmux 会话名称（T9）确保停止一个项目的仪表盘
# 不会影响另一个项目正在运行的服务器。
#
# 用法：
#   viz-stop.sh <project_dir>           # 旧式位置参数
#   viz-stop.sh --project <path>        # 当前命名标志

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/viz-session-name.sh"

PROJECT_DIR="."
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --) shift ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

HUMANIZE_DIR="$PROJECT_DIR/.humanize"
PORT_FILE="$HUMANIZE_DIR/viz.port"
URL_FILE="$HUMANIZE_DIR/viz.url"
TMUX_SESSION="$(viz_tmux_session_name "$PROJECT_DIR")"

# `=$TMUX_SESSION` 强制精确匹配，确保前缀冲突（或通用的
# "humanize-viz" 回退名称）不会导致无关会话被误杀。
if tmux has-session -t "=$TMUX_SESSION" 2>/dev/null; then
    tmux kill-session -t "=$TMUX_SESSION"
    rm -f "$PORT_FILE" "$URL_FILE"
    echo "Viz server stopped for project: $PROJECT_DIR"
else
    rm -f "$PORT_FILE" "$URL_FILE"
    echo "Viz server is not running for project: $PROJECT_DIR"
fi
