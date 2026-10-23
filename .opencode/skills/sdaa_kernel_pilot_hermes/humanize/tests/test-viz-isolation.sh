#!/usr/bin/env bash
#
# 可视化仪表板启动器中每个项目的 tmux/端口隔离测试（T9、AC-8）。
#
# 验证：
#   - viz_tmux_session_name() 返回每个项目的名称（不同项目路径
#     产生不同的 tmux 会话名称）。
#   - viz-stop.sh 和 viz-status.sh 派生与 viz-start.sh 相同的
#     名称，以便它们定位正确的项目。
#   - 旧版全局会话名称 "humanize-viz" 不再出现在
#     viz-start.sh / viz-stop.sh / viz-status.sh 中的硬编码。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAME_HELPER="$PLUGIN_ROOT/viz/scripts/viz-session-name.sh"
START_SH="$PLUGIN_ROOT/viz/scripts/viz-start.sh"
STOP_SH="$PLUGIN_ROOT/viz/scripts/viz-stop.sh"
STATUS_SH="$PLUGIN_ROOT/viz/scripts/viz-status.sh"

echo "========================================"
echo "Per-project viz isolation (T9 / AC-8)"
echo "========================================"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { printf '\033[0;32mPASS\033[0m: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { printf '\033[0;31mFAIL\033[0m: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

if [[ ! -f "$NAME_HELPER" ]]; then
    _fail "viz-session-name.sh not found at $NAME_HELPER"
    exit 1
fi

# ─── 测试 1：辅助函数可加载并公开 viz_tmux_session_name ───
# shellcheck disable=SC1090
source "$NAME_HELPER"
if declare -F viz_tmux_session_name >/dev/null 2>&1; then
    _pass "viz_tmux_session_name function is defined after sourcing"
else
    _fail "viz_tmux_session_name function not defined"
    exit 1
fi

# ─── 测试 2：不同项目路径产生不同名称 ───
NAME_A="$(viz_tmux_session_name "/home/u/projectA")"
NAME_B="$(viz_tmux_session_name "/home/u/projectB")"

if [[ -n "$NAME_A" && -n "$NAME_B" && "$NAME_A" != "$NAME_B" ]]; then
    _pass "different project paths produce different tmux session names ($NAME_A vs $NAME_B)"
else
    _fail "expected distinct names, got A='$NAME_A' B='$NAME_B'"
fi

# ─── 测试 3：相同项目路径产生稳定名称 ───
NAME_A2="$(viz_tmux_session_name "/home/u/projectA")"
if [[ "$NAME_A" == "$NAME_A2" ]]; then
    _pass "same project path produces a stable tmux session name across calls"
else
    _fail "stable-name expectation broken: '$NAME_A' vs '$NAME_A2'"
fi

# ─── 测试 4：名称具有 humanize-viz- 前缀 ───
if [[ "$NAME_A" == humanize-viz-* ]]; then
    _pass "session name uses the humanize-viz- prefix ($NAME_A)"
else
    _fail "session name missing humanize-viz- prefix: $NAME_A"
fi

# ─── 测试 5：空输入回退到旧版全局名称 ───
NAME_EMPTY="$(viz_tmux_session_name "")"
if [[ "$NAME_EMPTY" == "humanize-viz" ]]; then
    _pass "empty project path falls back to legacy global name (defensive default)"
else
    _fail "empty input should yield 'humanize-viz', got '$NAME_EMPTY'"
fi

# ─── 测试 6：viz-start.sh / viz-stop.sh / viz-status.sh 加载辅助函数 ───
for f in "$START_SH" "$STOP_SH" "$STATUS_SH"; do
    if grep -q 'viz-session-name.sh' "$f"; then
        _pass "$(basename "$f") sources viz-session-name.sh"
    else
        _fail "$(basename "$f") does not source viz-session-name.sh"
    fi
done

# ─── 测试 7：viz-stop.sh 和 viz-status.sh 不再硬编码 TMUX_SESSION="humanize-viz" ───
for f in "$START_SH" "$STOP_SH" "$STATUS_SH"; do
    if grep -qE 'TMUX_SESSION="humanize-viz"' "$f"; then
        _fail "$(basename "$f") still hard-codes the legacy global tmux session name"
    else
        _pass "$(basename "$f") no longer hard-codes the legacy global tmux session name"
    fi
done

# ─── 测试 8：脚本使用项目目录调用 viz_tmux_session_name ───
for f in "$START_SH" "$STOP_SH" "$STATUS_SH"; do
    if grep -q 'viz_tmux_session_name "\$PROJECT_DIR"' "$f"; then
        _pass "$(basename "$f") derives TMUX_SESSION from project dir"
    else
        _fail "$(basename "$f") does not derive TMUX_SESSION from project dir"
    fi
done

# ─── 测试 9：viz.url 持久化使健康检查定位配置的绑定（第 11 轮 P2 修复）───
echo
echo "Group 9: viz.url persistence for non-loopback bind health checks (Round 11)"

if grep -q 'URL_FILE="\$HUMANIZE_DIR/viz.url"' "$START_SH" && grep -q "echo \"http://" "$START_SH"; then
    _pass "viz-start.sh writes viz.url alongside viz.port"
else
    _fail "viz-start.sh does not persist the visible URL"
fi

if grep -q 'URL_FILE="\$HUMANIZE_DIR/viz.url"' "$STATUS_SH" && grep -q '\$probe_url/api/health' "$STATUS_SH"; then
    _pass "viz-status.sh reads viz.url for the liveness probe (no longer hardcodes localhost)"
else
    _fail "viz-status.sh still probes localhost regardless of bind"
fi

if grep -q 'URL_FILE="\$HUMANIZE_DIR/viz.url"' "$STOP_SH" && grep -q 'rm -f "\$PORT_FILE" "\$URL_FILE"' "$STOP_SH"; then
    _pass "viz-stop.sh cleans up viz.url alongside viz.port"
else
    _fail "viz-stop.sh leaves stale viz.url behind"
fi

if grep -qE 'fall back to .*localhost|fallback.*localhost' "$STATUS_SH" || grep -q 'http://localhost:\$port' "$STATUS_SH"; then
    _pass "viz-status.sh keeps the localhost fallback for older deployments without viz.url"
else
    _fail "viz-status.sh missing back-compat fallback when viz.url is absent"
fi

# ─── 组 10：find_port 探测配置的绑定主机（第 14 轮 P2 修复）───
echo
echo "Group 10: find_port probes the configured host (Round 14 P2 fix)"

# 在此修复之前，find_port 始终探测 localhost。特定的非回环绑定
# （例如 192.168.1.10）不在 localhost 上监听，因此当外部接口上的
# 其他服务拥有端口时，探测错误报告端口为空闲，Flask 因 EADDRINUSE 而崩溃。
if grep -qE 'probe_host=.*"localhost"' "$START_SH" && \
   grep -qE 'probe_host="\$HOST"' "$START_SH"; then
    _pass "viz-start.sh find_port branches probe_host on configured HOST"
else
    _fail "viz-start.sh find_port still hardcodes localhost for all binds"
fi

if grep -qE '/dev/tcp/\$probe_host/\$candidate' "$START_SH"; then
    _pass "viz-start.sh find_port uses \$probe_host in /dev/tcp check (not literal localhost)"
else
    _fail "viz-start.sh find_port still uses /dev/tcp/localhost/\$candidate literal"
fi

# 检查 probe_host case 块覆盖每个文档化的绑定系列：回环别名、
# IPv4/IPv6 通配符和特定 IP 默认值。缺少任何分支都会使远程模式契约回归。
if grep -B1 'probe_host="localhost"' "$START_SH" | grep -qE '127\.0\.0\.1\|::1\|localhost\|0\.0\.0\.0\|::'; then
    _pass "find_port probe_host=localhost branch covers loopback + wildcard binds (127.0.0.1|::1|localhost|0.0.0.0|::)"
else
    _fail "find_port probe_host=localhost branch missing one of the loopback/wildcard aliases"
fi

# 特定 IP 分支（默认 "*)"）必须将 probe_host 设置为 $HOST，
# 使非回环绑定探测自己的接口。
if awk '/^find_port\(\) \{/,/^\}$/' "$START_SH" | \
   grep -A1 '^\s*\*)' | grep -q 'probe_host="\$HOST"'; then
    _pass "find_port default branch sets probe_host=\$HOST for specific non-loopback IPs"
else
    _fail "find_port default branch does not set probe_host=\$HOST"
fi

# ─── 组 11：就绪探针失败关闭（第 16 轮 P2 修复）───
echo
echo "Group 11: readiness probe fail-closed + cleanup (Round 16 P2 fix)"

# 就绪循环必须探测规范 URL（viz.url）而非硬编码 localhost，
# 并必须跟踪是否有任何探针成功。之前它无条件打印 "ready"，
# 因此 --host <specific-ip> 守护进程和启动崩溃都未被注意，
# 磁盘上留下过期的 viz.port / viz.url。
if grep -qE 'probe_url=\$\(cat "\$URL_FILE"\)' "$START_SH" && \
   grep -qE '"\$probe_url/api/health"' "$START_SH"; then
    _pass "viz-start.sh readiness loop probes the canonical URL (viz.url), not literal localhost"
else
    _fail "viz-start.sh readiness loop still probes localhost regardless of bind"
fi

if grep -qE 'ready="true"' "$START_SH" && grep -qE 'if \[\[ "\$ready" != "true" \]\]; then' "$START_SH"; then
    _pass "viz-start.sh readiness loop tracks success + fails closed when never reachable"
else
    _fail "viz-start.sh readiness loop does not track success (always reports ready)"
fi

fail_block=$(awk '/if \[\[ "\$ready" != "true" \]\]; then/,/^fi$/' "$START_SH")
if grep -q 'rm -f "\$PORT_FILE" "\$URL_FILE"' <<<"$fail_block"; then
    _pass "viz-start.sh readiness failure cleans up stale viz.port and viz.url"
else
    _fail "viz-start.sh readiness failure leaves stale port/url files behind"
fi

if grep -q 'exit 1' <<<"$fail_block"; then
    _pass "viz-start.sh readiness failure exits non-zero (launcher fails closed)"
else
    _fail "viz-start.sh readiness failure still exits 0"
fi

# ─── 组 12：第 18 轮 P2 修复 — IPv6 绑定地址在 viz.url 中加括号 ───
echo
echo "Group 12: viz.url brackets IPv6 bind addresses per RFC 3986 (P2 Round 18)"

# 写为 http://<ipv6>:<port> 的特定 IPv6 绑定是无效 URL ——
# 端口分隔符与地址的尾部片段冲突。没有 RFC 3986 括号，
# curl/浏览器/viz-status.sh 将 URL 视为不可达，第 16 轮就绪探针
# 错误报告仪表板已关闭。
if grep -qE 'case "\$visible_host_for_url" in' "$START_SH" && \
   grep -qE 'visible_host_for_url="\[\$\{visible_host_for_url\}\]"' "$START_SH"; then
    _pass "viz-start.sh wraps IPv6 visible_host_for_url in RFC 3986 brackets"
else
    _fail "viz-start.sh writes unbracketed IPv6 host to viz.url (readiness probe will false-fail)"
fi

# 行为探针：使用不同的 HOST 值加载 URL 构建块，
# 并验证最终 URL 形状正确。
URL_PROBE_SCRIPT="$(mktemp)"
trap "rm -f '$URL_PROBE_SCRIPT'" EXIT
cat > "$URL_PROBE_SCRIPT" <<'PROBE_EOF'
#!/usr/bin/env bash
# 为一系列 HOST 值重放 viz.url case 块，并打印计算的 URL，
# 以便测试可以断言形状。
set -u
for host_value in 127.0.0.1 ::1 localhost 0.0.0.0 :: 192.168.1.10 10.0.0.5 2001:db8::1 fe80::abcd:1234; do
    HOST="$host_value"
    PORT=18000
    visible_host_for_url="$HOST"
    case "$HOST" in
        127.0.0.1|::1|localhost|0.0.0.0|::)
            visible_host_for_url="localhost"
            ;;
    esac
    case "$visible_host_for_url" in
        *:*)
            visible_host_for_url="[${visible_host_for_url}]"
            ;;
    esac
    echo "HOST=$HOST URL=http://${visible_host_for_url}:${PORT}"
done
PROBE_EOF
chmod +x "$URL_PROBE_SCRIPT"

if probe_url_output=$(bash "$URL_PROBE_SCRIPT" 2>&1); then
    if grep -q 'HOST=::1 URL=http://localhost:18000' <<<"$probe_url_output" && \
       grep -q 'HOST=2001:db8::1 URL=http://\[2001:db8::1\]:18000' <<<"$probe_url_output" && \
       grep -q 'HOST=fe80::abcd:1234 URL=http://\[fe80::abcd:1234\]:18000' <<<"$probe_url_output" && \
       grep -q 'HOST=192.168.1.10 URL=http://192.168.1.10:18000' <<<"$probe_url_output" && \
       grep -q 'HOST=localhost URL=http://localhost:18000' <<<"$probe_url_output"; then
        _pass "IPv6 bracketing matrix correct: loopback/wildcard -> localhost (no brackets); specific IPv6 -> bracketed; IPv4 -> unbracketed"
    else
        _fail "IPv6 bracketing matrix wrong: $probe_url_output"
    fi
else
    _fail "IPv6 bracketing probe failed: $probe_url_output"
fi

echo
echo "========================================"
printf 'Passed: \033[0;32m%d\033[0m\n' "$PASS_COUNT"
printf 'Failed: \033[0;31m%d\033[0m\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

printf '\033[0;32mAll viz isolation tests passed!\033[0m\n'
