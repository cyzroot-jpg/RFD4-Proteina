#!/usr/bin/env bash
# 检查某个项目的 Humanize Viz 仪表盘服务器状态。
#
# 基于项目的 tmux 会话名称（T9）确保检查一个项目的仪表盘
# 不会影响另一个项目正在运行的服务器。
#
# 用法：
#   viz-status.sh <project_dir>           # 旧式位置参数
#   viz-status.sh --project <path>        # 当前命名标志

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

if [[ -f "$PORT_FILE" ]]; then
    port=$(cat "$PORT_FILE")
    # 探测 viz-start.sh 记录的 URL（它知道配置的绑定地址），
    # 当仅有旧式端口文件存在时回退到 localhost。这正是
    # `--host 192.168.1.10` 部署能正常工作的原因——没有它，
    # localhost 探测会将健康的服务器误判为已停止并销毁会话。
    if [[ -f "$URL_FILE" ]]; then
        probe_url=$(cat "$URL_FILE")
    else
        probe_url="http://localhost:$port"
    fi
    if curl -s --max-time 2 "$probe_url/api/health" >/dev/null 2>&1; then
        echo "Viz server running for project $PROJECT_DIR at $probe_url"
        exit 0
    fi
    # 仅针对该项目的过期端口文件。
    echo "Viz server is not running for project: $PROJECT_DIR (stale port file, cleaning up)."
    rm -f "$PORT_FILE" "$URL_FILE"
    # 使用 tmux 的 `=name` 精确匹配形式，确保通用的 "humanize-viz"
    # 会话名称不会意外匹配更长的基于项目的名称（反之亦然）。
    # 由 viz_tmux_session_name 派生的项目特定名称已携带 8 位
    # 十六进制后缀；精确匹配语法使意图明确且健壮。
    if tmux has-session -t "=$TMUX_SESSION" 2>/dev/null; then
        tmux kill-session -t "=$TMUX_SESSION" 2>/dev/null || true
    fi
    exit 1
fi

echo "Viz server is not running for project: $PROJECT_DIR"
exit 1
