#!/usr/bin/env bash
# 为 viz 仪表盘守护进程提供基于项目的 tmux 会话名称派生。
#
# 被 viz-start.sh、viz-stop.sh 和 viz-status.sh 使用，确保三者
# 从同一项目路径解析出相同的 tmux 会话名称。取代了旧的全局
# "humanize-viz" 名称，该旧名称会导致一个项目的守护进程
# 杀掉另一个项目正在运行的服务器。
#
# 请 source 此文件（不要直接执行）并调用 viz_tmux_session_name。

# 返回 "humanize-viz-<8位十六进制>"，派生自项目绝对路径的稳定哈希。
# tmux 会话名称不能包含 "." 或 ":"，
# 因此基于内容的十六进制短标识是最安全的跨平台选择。
viz_tmux_session_name() {
    local project_dir="$1"
    if [[ -z "$project_dir" ]]; then
        echo "humanize-viz"
        return
    fi
    # 解析为绝对路径，使不同的调用方式（./ 与绝对路径）
    # 命中同一会话。
    if [[ -d "$project_dir" ]]; then
        project_dir="$(cd "$project_dir" 2>/dev/null && pwd)"
    fi
    local hash=""
    if command -v sha1sum >/dev/null 2>&1; then
        hash=$(printf '%s' "$project_dir" | sha1sum | cut -c1-8)
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(printf '%s' "$project_dir" | shasum | cut -c1-8)
    elif command -v openssl >/dev/null 2>&1; then
        hash=$(printf '%s' "$project_dir" | openssl dgst -sha1 | awk '{print $NF}' | cut -c1-8)
    else
        # 最后的回退方案：对路径本身进行清理（与
        # scripts/humanize.sh 和 viz/server/rlcr_sources.py 中的规则一致）。
        hash=$(printf '%s' "$project_dir" | sed 's/[^A-Za-z0-9._-]/-/g' | sed 's/--*/-/g' | tr '[:upper:]' '[:lower:]')
        # 截断以避免生成的 tmux 名称过长。
        hash="${hash: -16}"
    fi
    echo "humanize-viz-${hash}"
}
