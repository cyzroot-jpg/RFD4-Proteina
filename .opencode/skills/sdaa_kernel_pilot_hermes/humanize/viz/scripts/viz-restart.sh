#!/usr/bin/env bash
# 重启 Humanize Viz 仪表盘服务器。
#
# 用法：
#   viz-restart.sh <project_dir>                  # 旧式位置参数
#   viz-restart.sh --project <path> \
#                  [--host <addr>] [--port <int>] \
#                  [--auth-token <tok>] [--trust-proxy]
#
# 底层 viz-start.sh 接受的所有标志都会原样转发。
# 简单的 `viz-restart.sh --project <path>` 仍然有效，
# 会使用 viz-start.sh 的默认值（回环绑定、无认证）重新启动；
# 如果调用者启动守护进程时使用了自定义 --host / --port /
# --auth-token / --trust-proxy，则必须在此处重复指定这些标志，
# 否则重启后的守护进程会静默回退到默认值，
# 之前的访问 URL / 令牌将失效。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析 viz-start.sh 能识别的所有标志，使重启真正等价于
# 使用相同配置执行停止+启动。旧的实现只捕获 --project，
# 静默丢弃 --host / --port / --auth-token / --trust-proxy，
# 导致非回环守护进程在重启时悄悄回退到 localhost。
PROJECT_DIR="."
HOST=""
PORT=""
AUTH_TOKEN=""
TRUST_PROXY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --host)    HOST="$2"; shift 2 ;;
        --port)    PORT="$2"; shift 2 ;;
        --auth-token) AUTH_TOKEN="$2"; shift 2 ;;
        --trust-proxy) TRUST_PROXY=true; shift ;;
        --) shift ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# 以确定性顺序重建 viz-start 的参数列表，
# 使重启后的守护进程看到与调用者传入的完全相同的配置。
START_ARGS=(--project "$PROJECT_DIR")
[[ -n "$HOST" ]]    && START_ARGS+=(--host "$HOST")
[[ -n "$PORT" ]]    && START_ARGS+=(--port "$PORT")
[[ -n "$AUTH_TOKEN" ]] && START_ARGS+=(--auth-token "$AUTH_TOKEN")
[[ "$TRUST_PROXY" == "true" ]] && START_ARGS+=(--trust-proxy)

bash "$SCRIPT_DIR/viz-stop.sh" --project "$PROJECT_DIR" 2>/dev/null || true
sleep 1
exec bash "$SCRIPT_DIR/viz-start.sh" "${START_ARGS[@]}"
