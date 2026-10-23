#!/usr/bin/env bash
# 在每个项目独立的 tmux 会话中启动 Humanize Viz 仪表盘服务器。
#
# 此脚本由 `humanize monitor web` 的 `--daemon` 路径调用，
# 也可以直接运行。旧式位置参数 `<project>` 形式保留以保持
# 向后兼容；新的调用者应使用命名标志。
#
# 用法：
#   viz-start.sh <project_dir>                                        # 旧式
#   viz-start.sh --project <path> [--host <addr>] [--port <int>] \
#                                 [--auth-token <token>]              # 当前

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIZ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIREMENTS="$VIZ_ROOT/server/requirements.txt"
APP_ENTRY="$VIZ_ROOT/server/app.py"
STATIC_DIR="$VIZ_ROOT/static"

# 加载基于项目的 tmux 会话命名辅助脚本，使 start/stop/status
# 都从项目路径派生出相同的名称。
source "$SCRIPT_DIR/viz-session-name.sh"

# 解析参数。接受旧式位置参数 <project> 以保持向后兼容。
PROJECT_DIR="."
HOST="127.0.0.1"
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
        -h|--help)
            sed -n '2,/^set -euo/p' "$0" | head -n -1
            exit 0
            ;;
        --)
            shift
            ;;
        *)
            # 第一个非标志的位置参数为项目目录（旧式形式）。
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

HUMANIZE_DIR="$PROJECT_DIR/.humanize"
VENV_DIR="$HUMANIZE_DIR/viz-venv"
PORT_FILE="$HUMANIZE_DIR/viz.port"
URL_FILE="$HUMANIZE_DIR/viz.url"

# 基于项目的 tmux 会话名称（T9）：每个项目拥有独立的会话槽位，
# 启动一个项目的守护进程永远不会杀掉另一个项目正在运行的服务器。
# 旧的全局 "humanize-viz" 名称已被移除。
TMUX_SESSION="$(viz_tmux_session_name "$PROJECT_DIR")"

if [[ ! -d "$HUMANIZE_DIR" ]]; then
    echo "Error: No .humanize/ directory found in $PROJECT_DIR" >&2
    echo "This command must be run in a project with humanize initialized." >&2
    exit 1
fi

# 在执行任何其他工作之前，拒绝没有令牌的远程绑定。
if [[ "$HOST" != "127.0.0.1" && "$HOST" != "::1" && "$HOST" != "localhost" ]]; then
    if [[ -z "$AUTH_TOKEN" && -z "${HUMANIZE_VIZ_TOKEN:-}" ]]; then
        echo "Error: --host $HOST requires --auth-token (or HUMANIZE_VIZ_TOKEN)" >&2
        exit 2
    fi
fi

# 如果该项目已有正在运行的服务器，则复用它。我们探测之前
# viz-start.sh 记录的可见 URL（位于 viz.url 中），
# 当仅有端口文件存在时回退到 localhost（旧版部署）。
# 探测配置的绑定地址很重要，因为 `--host 192.168.1.10`
# 不会在 localhost 上监听，所以 localhost 探测会将健康的服务器
# 误判为已停止。
if [[ -f "$PORT_FILE" ]]; then
    existing_port=$(cat "$PORT_FILE")
    if [[ -f "$URL_FILE" ]]; then
        existing_url=$(cat "$URL_FILE")
    else
        existing_url="http://localhost:$existing_port"
    fi
    if curl -s --max-time 2 "$existing_url/api/health" >/dev/null 2>&1; then
        echo "Viz server already running for this project at $existing_url"
        exit 0
    fi
    rm -f "$PORT_FILE" "$URL_FILE"
fi

# 如果该项目的 tmux 会话已存在但服务器已停止，则清理它。
# `=$TMUX_SESSION` 强制精确匹配，确保不会误操作
# 名称恰好共享前缀的无关会话（或通用的 "humanize-viz" 回退名称）。
if tmux has-session -t "=$TMUX_SESSION" 2>/dev/null; then
    echo "Cleaning up stale tmux session for this project: $TMUX_SESSION"
    tmux kill-session -t "=$TMUX_SESSION" 2>/dev/null || true
fi

# 如果虚拟环境不存在则创建。
if [[ ! -d "$VENV_DIR" ]]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "Installing dependencies..."
    "$VENV_DIR/bin/pip" install --quiet -r "$REQUIREMENTS"
    echo "Dependencies installed."
elif [[ "$REQUIREMENTS" -nt "$VENV_DIR/.requirements_installed" ]]; then
    echo "Updating dependencies..."
    if ! "$VENV_DIR/bin/pip" install --quiet -r "$REQUIREMENTS"; then
        # 保留标记文件不变，以便下次启动时重试升级，
        # 而不是在缺少包的情况下静默启动。
        echo "Error: pip install failed during dependency refresh" >&2
        exit 1
    fi
    touch "$VENV_DIR/.requirements_installed"
fi
touch "$VENV_DIR/.requirements_installed"

# 如果未指定端口则自动选择。基于项目的端口文件意味着
# 并行项目不会冲突。
#
# 探测主机必须与 Flask 的 app.run() 实际尝试绑定的地址一致。
# 回环别名和通配符绑定（0.0.0.0, ::）可以安全地通过 localhost
# 探测，因为通配符也会在回环接口上监听，所以 localhost 探测
# 能捕获那里的冲突。但特定的非回环绑定（如 192.168.1.10）
# 不会在 localhost 上监听，因此仅使用 localhost 探测会将端口
# 报告为空闲，即使另一个服务在外部接口上占用了它——然后
# app.run 会因 EADDRINUSE 而失败。直接探测配置的主机
# 使远程模式启动更加可靠。
find_port() {
    local probe_host
    case "$HOST" in
        127.0.0.1|::1|localhost|0.0.0.0|::)
            probe_host="localhost"
            ;;
        *)
            probe_host="$HOST"
            ;;
    esac
    for candidate in $(seq 18000 18099); do
        if ! (echo >/dev/tcp/$probe_host/$candidate) 2>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done
    echo "Error: No available port in range 18000-18099" >&2
    return 1
}

if [[ -z "$PORT" ]]; then
    PORT=$(find_port)
fi
echo "$PORT" > "$PORT_FILE"

# 持久化可见 URL，以便 viz-status.sh / viz-stop.sh 和上面的
# 过期端口路径能探测到正确的主机。回环绑定通过 localhost
# 暴露仪表盘；非回环绑定通过配置的主机暴露
# （即浏览器实际访问的地址）。
visible_host_for_url="$HOST"
case "$HOST" in
    127.0.0.1|::1|localhost|0.0.0.0|::)
        # 所有回环别名和通配符绑定都可以从本机通过 localhost 访问，
        # 因此使用 localhost 进行存活检查。通配符绑定也在回环接口上
        # 监听，所以这是正确的（同时避免了需要知道探测哪个外部接口）。
        visible_host_for_url="localhost"
        ;;
esac
# RFC 3986 要求 IPv6 地址在 URL 中用方括号包裹，
# 以避免端口分隔符的歧义。如果不这样做，curl、浏览器和
# viz-status.sh 都会将 `http://<ipv6>:<port>` 视为无效 URL，
# 因为地址末尾的 `:<N>` 片段会与端口分隔符冲突。
# 回环/通配符绑定已在上面折叠为 "localhost"（无冒号），
# 因此此操作仅包裹特定的 IPv6 地址，对 IPv4/localhost 无影响。
case "$visible_host_for_url" in
    *:*)
        visible_host_for_url="[${visible_host_for_url}]"
        ;;
esac
echo "http://${visible_host_for_url}:${PORT}" > "$URL_FILE"

# 构建 python 命令，转发所有标志。
PY_ARGS=(
    "$VENV_DIR/bin/python" "$APP_ENTRY"
    --host "$HOST"
    --port "$PORT"
    --project "$PROJECT_DIR"
    --static "$STATIC_DIR"
)
if [[ -n "$AUTH_TOKEN" ]]; then
    PY_ARGS+=(--auth-token "$AUTH_TOKEN")
fi
if [[ "$TRUST_PROXY" == "true" ]]; then
    PY_ARGS+=(--trust-proxy)
fi

# 在项目的独立 tmux 会话中启动。
tmux new-session -d -s "$TMUX_SESSION" "${PY_ARGS[@]}"

visible_host="$HOST"
[[ "$HOST" == "127.0.0.1" || "$HOST" == "::1" ]] && visible_host="localhost"
echo "Viz server starting on http://${visible_host}:${PORT}"

# 对我们刚写入 viz.url 的规范 URL 进行就绪探测。
# 此处探测 "localhost" 对 --host <具体IP> 的守护进程会产生误判
# （健康的服务器永远不会在 localhost 上响应这些绑定），
# 启动时死亡的进程也会在不被察觉的情况下通过检查，
# 留下过期的 viz.port / viz.url 和误导性的 "就绪" 提示。
# 追踪是否有探测成功，以便在服务器始终不可达时让启动器失败退出。
probe_url=$(cat "$URL_FILE")
ready="false"
for _ in $(seq 1 10); do
    if curl -s --max-time 1 "$probe_url/api/health" >/dev/null 2>&1; then
        ready="true"
        break
    fi
    sleep 0.5
done

if [[ "$ready" != "true" ]]; then
    echo "Error: viz dashboard did not become reachable at $probe_url within 5s." >&2
    echo "Inspect the tmux session for startup errors: tmux attach -t $TMUX_SESSION" >&2
    rm -f "$PORT_FILE" "$URL_FILE"
    exit 1
fi

# 仅在绑定到本机时打开浏览器。
if [[ "$HOST" == "127.0.0.1" || "$HOST" == "::1" || "$HOST" == "localhost" ]]; then
    if command -v xdg-open &>/dev/null; then
        xdg-open "http://localhost:$PORT" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "http://localhost:$PORT" 2>/dev/null &
    elif command -v wslview &>/dev/null; then
        wslview "http://localhost:$PORT" 2>/dev/null &
    else
        echo "Open http://localhost:$PORT in your browser."
    fi
fi

echo "Viz dashboard is ready at http://${visible_host}:${PORT}"
echo "Tmux session for this project: $TMUX_SESSION"
echo "Run 'viz-stop.sh --project $PROJECT_DIR' to stop the dashboard."
