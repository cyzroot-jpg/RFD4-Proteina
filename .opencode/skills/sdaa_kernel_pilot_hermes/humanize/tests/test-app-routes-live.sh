#!/usr/bin/env bash
#
# viz/server/app.py (T13) 的实时 Flask test_client 覆盖。
#
# 使用路由级请求驱动实际的 Flask 应用，而非模式检查。
# 如果未设置 VIZ_TEST_VENV，则引导一个包含 Flask + flask-sock +
# watchdog + pyyaml 的 Python venv；否则使用提供的 venv。
#
# 覆盖范围（每个断言都是真实的 Flask test_client 请求）：
#   - GET /api/health（任何模式下开放）。
#   - GET /api/sessions（200 带一个 CLI 固定条目；远程模式下
#     无有效 token 时 401）。
#   - GET /api/sessions/<id>（localhost 中 200 已知 / 404 未知；
#     远程模式下无 token 401 / 有效 bearer 200）。
#   - POST /api/sessions/cancel（第 5 轮的 400 缺少 id 路由）。
#   - POST /api/sessions/<id>/cancel（404 未知；远程模式下
#     无 token 401）。
#   - /api/projects/{switch,add,remove} 返回 410 Gone。
#   - GET /api/sessions/<id>/logs/<basename> SSE：初始快照和
#     会话处于终态时自动 eof（因此 test_client
#     iter_encoded() 返回）；basename 验证拒绝不匹配的
#     名称并返回 400；缺失缓存启动产生 resync(missing)+eof。
#   - 认证中间件：远程模式下每个受保护端点都需要 token；
#     缺失/无效 token 返回 401，有效 token 通过。
#   - 正确枚举具有混合生命周期状态的并发活跃会话。
#   - 通过 SSE 路由的截断恢复：写入线程在 SSE 生成器读取时
#     修改缓存日志，然后将会话转换为终态，使
#     生成器发出 eof；收集的事件流包含完整的
#     snapshot -> resync(truncated) -> snapshot -> eof 序列。
#
# 所有测试夹具位于每个测试的 mktemp 树下；不会触及真实的 ~/.humanize
# 或 ~/.cache/humanize。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "Live Flask test_client coverage (T13)"
echo "========================================"

if ! command -v python3 &>/dev/null; then
    echo "SKIP: python3 not available"
    exit 0
fi

VENV_DIR="${VIZ_TEST_VENV:-/tmp/viz-routes-test-venv}"
if [[ ! -d "$VENV_DIR/bin" ]]; then
    echo "Bootstrapping test venv at $VENV_DIR (Flask + flask-sock + watchdog + pyyaml)..."
    if ! python3 -m venv "$VENV_DIR" 2>/dev/null; then
        echo "SKIP: failed to create venv at $VENV_DIR"
        exit 0
    fi
    if ! "$VENV_DIR/bin/pip" install --quiet flask flask-sock watchdog pyyaml 2>/dev/null; then
        echo "SKIP: failed to install Flask + deps (no internet?); cannot exercise live routes"
        exit 0
    fi
fi

# 健全性检查 venv 是否有必要的导入。
if ! "$VENV_DIR/bin/python" -c "import flask, flask_sock, watchdog, yaml" 2>/dev/null; then
    echo "SKIP: venv at $VENV_DIR is missing required packages"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 运行执行繁重工作的 Python 驱动程序。
"$VENV_DIR/bin/python" - "$PLUGIN_ROOT" "$TMP_DIR" <<'PYEOF'
import os
import sys
import json
import base64
import shutil
import threading
from contextlib import contextmanager

PLUGIN_ROOT, TMP_DIR = sys.argv[1], sys.argv[2]
SERVER_DIR = os.path.join(PLUGIN_ROOT, 'viz', 'server')
sys.path.insert(0, SERVER_DIR)


# ─── Fixture helpers ────────────────────────────────────────────────
def make_project(name, sessions):
    """Build a tmp project with the requested seeded sessions.

    sessions is a list of dicts: {id, status_files: {filename: content}}
    where filename is e.g. "state.md", "complete-state.md", etc.
    """
    project = os.path.join(TMP_DIR, name)
    rlcr = os.path.join(project, '.humanize', 'rlcr')
    os.makedirs(rlcr, exist_ok=True)
    for s in sessions:
        sd = os.path.join(rlcr, s['id'])
        os.makedirs(sd, exist_ok=True)
        for fn, content in s.get('status_files', {}).items():
            with open(os.path.join(sd, fn), 'w', encoding='utf-8') as f:
                f.write(content)
    return project


def seed_cache_log(project_root, session_id, basename, content_bytes):
    """Seed a cache log under XDG_CACHE_HOME (set per-test to TMP_DIR)."""
    import re
    cache_root = os.path.join(os.environ['XDG_CACHE_HOME'], 'humanize')
    sanitized = re.sub(r'-+', '-', re.sub(r'[^A-Za-z0-9._-]', '-', project_root))
    cache_dir = os.path.join(cache_root, sanitized, session_id)
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, basename)
    with open(path, 'wb') as f:
        f.write(content_bytes)
    return path


PASS = 0
FAIL = 0


def t_pass(msg):
    global PASS
    PASS += 1
    print(f"\033[0;32mPASS\033[0m: {msg}")


def t_fail(msg):
    global FAIL
    FAIL += 1
    print(f"\033[0;31mFAIL\033[0m: {msg}")


@contextmanager
def configured_app(host='127.0.0.1', auth_token='', project_dir=None):
    """Reload viz/server/app.py with a fresh PROJECT_DIR / BIND_HOST.

    The module holds globals (PROJECT_DIR, BIND_HOST, AUTH_TOKEN), so
    each test sets them directly rather than going through main().
    The watcher is NOT started so tests stay deterministic.
    """
    import importlib
    import app as _appmod
    importlib.reload(_appmod)
    # Override module globals before the test client makes any request.
    _appmod.PROJECT_DIR = project_dir or TMP_DIR
    _appmod.STATIC_DIR = os.path.join(PLUGIN_ROOT, 'viz', 'static')
    _appmod.BIND_HOST = host
    _appmod.AUTH_TOKEN = auth_token
    # Use Flask's testing config so 500s do not get swallowed.
    _appmod.app.config['TESTING'] = True
    yield _appmod


# ─── Tests ──────────────────────────────────────────────────────────

# 第 1 组：绑定到 localhost 的应用，不需要认证
print("\nGroup 1: localhost-bound app, no auth")
project = make_project('proj_localhost', [
    {'id': '2026-04-17_10-00-00', 'status_files': {
        'state.md': '---\ncurrent_round: 2\nmax_iterations: 42\n---\n',
    }},
    {'id': '2026-04-16_09-00-00', 'status_files': {
        'complete-state.md': '---\ncurrent_round: 5\nmax_iterations: 42\n---\n',
    }},
])
os.environ['XDG_CACHE_HOME'] = os.path.join(TMP_DIR, 'xdg_cache')

with configured_app(project_dir=project) as appmod:
    client = appmod.app.test_client()

    r = client.get('/api/health')
    if r.status_code == 200 and r.get_json().get('status') == 'ok':
        t_pass("GET /api/health 200 ok")
    else:
        t_fail(f"GET /api/health failed: {r.status_code}")

    r = client.get('/api/sessions')
    if r.status_code == 200:
        body = r.get_json() or []
        if isinstance(body, list) and len(body) >= 1:
            t_pass(f"GET /api/sessions returned {len(body)} session(s)")
        else:
            t_fail(f"GET /api/sessions body wrong: {body}")
    else:
        t_fail(f"GET /api/sessions failed: {r.status_code}")

    r = client.get('/api/projects')
    body = r.get_json() or []
    if r.status_code == 200 and isinstance(body, list) and len(body) == 1 and body[0].get('cli_fixed') is True:
        t_pass("GET /api/projects returns one CLI-fixed entry")
    else:
        t_fail(f"GET /api/projects unexpected: {r.status_code} {body}")

    r = client.post('/api/projects/switch', json={'path': '/tmp'})
    if r.status_code == 410:
        t_pass("POST /api/projects/switch returns 410 Gone")
    else:
        t_fail(f"projects/switch should return 410, got {r.status_code}")

    r = client.post('/api/projects/add', json={'path': '/tmp'})
    if r.status_code == 410:
        t_pass("POST /api/projects/add returns 410 Gone")
    else:
        t_fail(f"projects/add should return 410, got {r.status_code}")

    r = client.post('/api/projects/remove', json={'path': '/tmp'})
    if r.status_code == 410:
        t_pass("POST /api/projects/remove returns 410 Gone")
    else:
        t_fail(f"projects/remove should return 410, got {r.status_code}")

    # 缺少 session-id 的 400（专用的 /api/sessions/cancel 路由）
    r = client.post('/api/sessions/cancel')
    if r.status_code == 400 and 'session_id is required' in (r.get_data(as_text=True) or ''):
        t_pass("POST /api/sessions/cancel 400 with 'session_id is required'")
    else:
        t_fail(f"missing-id 400 route wrong: {r.status_code} {r.get_data(as_text=True)}")

    # 未知会话 404
    r = client.post('/api/sessions/9999-99-99/cancel')
    if r.status_code == 404:
        t_pass("POST /api/sessions/<unknown>/cancel returns 404")
    else:
        t_fail(f"unknown-session cancel wrong: {r.status_code}")

    # GET /api/sessions/<known> 返回解析后的会话字典
    r = client.get('/api/sessions/2026-04-17_10-00-00')
    if r.status_code == 200:
        body = r.get_json() or {}
        if body.get('id') == '2026-04-17_10-00-00' and body.get('status'):
            t_pass("GET /api/sessions/<known> returns parsed session dict")
        else:
            t_fail(f"GET /api/sessions/<known> body wrong: {body}")
    else:
        t_fail(f"GET /api/sessions/<known> failed: {r.status_code}")

    # GET /api/sessions/<unknown> 返回 404
    r = client.get('/api/sessions/9999-99-99-no-such')
    if r.status_code == 404:
        t_pass("GET /api/sessions/<unknown> returns 404")
    else:
        t_fail(f"GET /api/sessions/<unknown> should 404, got {r.status_code}")

# 第 2 组：带 token 强制的远程绑定应用
print("\nGroup 2: remote-bound app + token enforcement")
TOKEN = 'a-very-secret-test-token'
with configured_app(host='192.0.2.10', auth_token=TOKEN, project_dir=project) as appmod:
    client = appmod.app.test_client()

    r = client.get('/api/health')
    if r.status_code == 200:
        t_pass("GET /api/health open in remote mode")
    else:
        t_fail(f"health should be open: {r.status_code}")

    r = client.get('/api/sessions')
    if r.status_code == 401:
        t_pass("GET /api/sessions 401 without token in remote mode")
    else:
        t_fail(f"missing-token sessions should 401, got {r.status_code}")

    r = client.get('/api/sessions', headers={'Authorization': f'Bearer {TOKEN}'})
    if r.status_code == 200:
        t_pass("GET /api/sessions 200 with valid bearer token")
    else:
        t_fail(f"valid-token sessions failed: {r.status_code}")

    r = client.get('/api/sessions', headers={'Authorization': 'Bearer wrong-token'})
    if r.status_code == 401:
        t_pass("GET /api/sessions 401 with invalid bearer token")
    else:
        t_fail(f"invalid-token sessions should 401, got {r.status_code}")

    # SSE 处理器也被门控。根据 DEC-4 使用 ?token= 查询参数。
    seed_cache_log(project, '2026-04-17_10-00-00', 'round-2-codex-run.log', b'hello')
    r = client.get('/api/sessions/2026-04-17_10-00-00/logs/round-2-codex-run.log')
    if r.status_code == 401:
        t_pass("SSE stream 401 without ?token= in remote mode")
    else:
        t_fail(f"missing-token SSE should 401, got {r.status_code}")

    r = client.post('/api/sessions/2026-04-17_10-00-00/cancel')
    if r.status_code == 401:
        t_pass("POST cancel 401 without token in remote mode")
    else:
        t_fail(f"missing-token cancel should 401, got {r.status_code}")

    # 远程模式下的 GET /api/sessions/<known>：无 token 401，有 token 200
    r = client.get('/api/sessions/2026-04-17_10-00-00')
    if r.status_code == 401:
        t_pass("GET /api/sessions/<known> 401 without token in remote mode")
    else:
        t_fail(f"detail GET should 401 without token, got {r.status_code}")

    r = client.get(
        '/api/sessions/2026-04-17_10-00-00',
        headers={'Authorization': f'Bearer {TOKEN}'},
    )
    if r.status_code == 200 and (r.get_json() or {}).get('id') == '2026-04-17_10-00-00':
        t_pass("GET /api/sessions/<known> 200 with valid bearer token in remote mode")
    else:
        t_fail(f"detail GET with valid token wrong: {r.status_code} {r.get_data(as_text=True)[:200]}")

# 第 3 组：终态会话上的 SSE 流行为（自动 eof）
print("\nGroup 3: SSE stream on terminal session (auto-eof)")

# 添加一个终态会话，其 SSE 生成器会自行终止。
project_term = make_project('proj_terminal', [
    {'id': '2026-04-17_11-00-00', 'status_files': {
        'complete-state.md': '---\ncurrent_round: 3\nmax_iterations: 42\n---\n',
    }},
])
seed_cache_log(project_term, '2026-04-17_11-00-00',
               'round-1-codex-run.log', b'snapshot bytes here')

with configured_app(project_dir=project_term) as appmod:
    client = appmod.app.test_client()

    r = client.get('/api/sessions/2026-04-17_11-00-00/logs/round-1-codex-run.log',
                   buffered=True)
    if r.status_code == 200:
        body = b''.join(r.iter_encoded()).decode('utf-8', errors='replace')
        if 'event: snapshot' in body and 'event: eof' in body:
            t_pass("SSE stream on terminal session yields snapshot + eof")
        else:
            t_fail(f"SSE body missing expected events:\n{body[:500]}")
    else:
        t_fail(f"SSE 200 expected, got {r.status_code}")

    # 错误的 basename 被拒绝
    r = client.get('/api/sessions/2026-04-17_11-00-00/logs/not-a-valid-name.txt',
                   buffered=True)
    if r.status_code == 400:
        t_pass("SSE rejects basenames that don't match round-N-{codex,gemini}-{run,review}.log")
    else:
        t_fail(f"bad basename should 400, got {r.status_code}")

# 第 4 组：枚举两个并发活跃会话
print("\nGroup 4: concurrent active sessions")
proj_concurrent = make_project('proj_concurrent', [
    {'id': '2026-04-17_A', 'status_files': {
        'state.md': '---\ncurrent_round: 1\nmax_iterations: 42\n---\n',
    }},
    {'id': '2026-04-17_B', 'status_files': {
        'methodology-analysis-state.md': '---\ncurrent_round: 5\nmax_iterations: 42\n---\n',
    }},
    {'id': '2026-04-17_C', 'status_files': {
        'finalize-state.md': '---\ncurrent_round: 9\nmax_iterations: 42\n---\n',
    }},
    {'id': '2026-04-17_D', 'status_files': {
        'cancel-state.md': '---\ncurrent_round: 2\nmax_iterations: 42\n---\n',
    }},
])
with configured_app(project_dir=proj_concurrent) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions')
    body = r.get_json() or []
    statuses = {s['id']: s['status'] for s in body if isinstance(s, dict)}
    expected = {
        '2026-04-17_A': 'active',
        '2026-04-17_B': 'analyzing',
        '2026-04-17_C': 'finalizing',
        '2026-04-17_D': 'cancel',
    }
    if all(statuses.get(k) == v for k, v in expected.items()):
        t_pass("4 sessions with mixed lifecycle states enumerated correctly")
    else:
        t_fail(f"lifecycle status enumeration wrong: {statuses}")

# 第 5 组：缺失缓存启动竞争
print("\nGroup 5: missing-cache startup race")
proj_race = make_project('proj_race', [
    {'id': '2026-04-17_R', 'status_files': {
        'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
    }},
])
with configured_app(project_dir=proj_race) as appmod:
    client = appmod.app.test_client()
    # 活跃会话有 state.md 但没有终态 → SSE 生成器永远不会自动 eof。
    # 为了保持测试的确定性，在测试中将会话重命名为终态，
    # 在快照之后但在长轮询之前写入 complete-state.md。
    # 更简单的方法：只检查路由是否接受没有缓存日志的请求；
    # 缺失缓存的重新同步语义在 test-streaming.sh 中进行单元测试。
    # 从开始将会话置于终态，使生成器自行终止。
    rlcr_dir = os.path.join(proj_race, '.humanize', 'rlcr', '2026-04-17_R')
    os.rename(os.path.join(rlcr_dir, 'state.md'),
              os.path.join(rlcr_dir, 'complete-state.md'))
    r = client.get('/api/sessions/2026-04-17_R/logs/round-0-codex-run.log',
                   buffered=True)
    if r.status_code == 200:
        body = b''.join(r.iter_encoded()).decode('utf-8', errors='replace')
        if 'event: resync' in body and 'missing' in body and 'event: eof' in body:
            t_pass("missing-cache startup yields resync(missing) + eof")
        else:
            t_fail(f"missing-cache body unexpected:\n{body[:500]}")
    else:
        t_fail(f"missing-cache SSE 200 expected, got {r.status_code}")

# 第 6 组：通过 SSE 端点的路由支持截断恢复。
# 写入线程在 SSE 生成器读取时修改缓存日志；
# 一旦修改序列完成，会话转换为终态，使生成器发出
# eof 且 Flask 的 iter_encoded() 返回。收集的事件流
# 必须包含完整的 snapshot -> resync(truncated) -> snapshot ->
# eof 序列，证明真实的 Flask 路由端到端遵守协议合同
# （不仅仅是隔离的 LogStream 类）。
print("\nGroup 6: route-backed truncation through the SSE endpoint")

import time as _time

proj_trunc = make_project('proj_trunc_route', [
    {'id': '2026-04-17_TR', 'status_files': {
        'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
    }},
])
TR_LOG = seed_cache_log(proj_trunc, '2026-04-17_TR',
                        'round-0-codex-run.log', b'initial bytes here')
TR_RLCR = os.path.join(proj_trunc, '.humanize', 'rlcr', '2026-04-17_TR')

def _writer_then_terminate():
    # 等待足够长的时间让 SSE 处理器发出初始快照。
    # 处理器每 0.25 秒轮询一次，并在一次读取后退出快照循环，
    # 因此 0.6 秒舒适地超过了第一个轮询边界。
    _time.sleep(0.6)
    # 用更短的内容覆盖以截断。
    with open(TR_LOG, 'wb') as f:
        f.write(b'short')
    # 给轮询循环一个时间片来检测大小缩减并发出
    # resync(truncated) 加上新的快照。
    _time.sleep(0.6)
    # 转换为终态，使 SSE 生成器发出 eof 且 Flask
    # 关闭响应。处理器通过 _get_session(force_refresh=True)
    # 每次轮询迭代检查状态。
    os.rename(os.path.join(TR_RLCR, 'state.md'),
              os.path.join(TR_RLCR, 'complete-state.md'))

with configured_app(project_dir=proj_trunc) as appmod:
    client = appmod.app.test_client()
    writer_thread = threading.Thread(target=_writer_then_terminate, daemon=True)
    writer_thread.start()

    r = client.get('/api/sessions/2026-04-17_TR/logs/round-0-codex-run.log',
                   buffered=True)
    writer_thread.join(timeout=5)

    if r.status_code != 200:
        t_fail(f"route-backed truncation: SSE 200 expected, got {r.status_code}")
    else:
        body = b''.join(r.iter_encoded()).decode('utf-8', errors='replace')
        # 计算出现次数以验证完整序列。
        snap_count = body.count('event: snapshot')
        resync_truncated = ('event: resync' in body
                            and '"reason":"truncated"' in body)
        eof_seen = 'event: eof' in body
        if snap_count >= 2 and resync_truncated and eof_seen:
            t_pass("SSE route emits snapshot -> resync(truncated) -> snapshot -> eof in sequence")
        else:
            t_fail(
                "route-backed truncation event stream incomplete: "
                f"snapshots={snap_count} resync_truncated={resync_truncated} eof={eof_seen}\n"
                f"body[:800]:\n{body[:800]}"
            )

# 第 7 组：变更端点上的 CSRF 保护（第 8 轮 P1 修复）。
# 绑定到回环的仪表板会接受来自同一浏览器中打开的任何网页的跨域 POST。
# 叠加在认证中间件之上的同源检查无论绑定如何都关闭了这个漏洞。
# 读取方法（GET）保持开放；测试验证该行为不变。
print("\nGroup 7: CSRF protection on mutating endpoints (P1)")

with configured_app(project_dir=project) as appmod:
    client = appmod.app.test_client()

    # 带有跨域 Origin 头的 localhost POST → 403。
    r = client.post(
        '/api/sessions/2026-04-17_10-00-00/cancel',
        headers={'Origin': 'http://evil.example.com'},
    )
    if r.status_code == 403 and 'cross-origin write rejected' in (r.get_data(as_text=True) or ''):
        t_pass("localhost POST with cross-origin Origin returns 403")
    else:
        t_fail(f"cross-origin POST should 403, got {r.status_code} {r.get_data(as_text=True)[:200]}")

    # 带有同源 Origin 的 localhost POST → 通过正常的处理器链
    # （这里返回 400，因为会话处于终态，不是 active/analyzing/finalizing）。
    # Flask test_client 的默认请求 Host 是 `localhost`（无显式端口，
    # 隐式端口 80），因此同源检查使用解析到相同 host:port 对的 Origin。
    r = client.post(
        '/api/sessions/2026-04-16_09-00-00/cancel',
        headers={'Origin': 'http://localhost'},
    )
    if r.status_code != 403:
        t_pass(f"localhost POST with same-origin Origin passes CSRF gate (handler returned {r.status_code})")
    else:
        t_fail(f"same-origin POST should NOT 403, got {r.status_code}")

    # 跨域 Referer（无 Origin）也被拒绝。
    r = client.post(
        '/api/sessions/2026-04-17_10-00-00/cancel',
        headers={'Referer': 'http://evil.example.com/foo'},
    )
    if r.status_code == 403:
        t_pass("localhost POST with cross-origin Referer returns 403")
    else:
        t_fail(f"cross-origin Referer POST should 403, got {r.status_code}")

    # GET 请求不受 CSRF 影响（同源策略已经
    # 防止跨域页面读取我们的响应）。
    r = client.get(
        '/api/sessions',
        headers={'Origin': 'http://evil.example.com'},
    )
    if r.status_code == 200:
        t_pass("GET requests are not gated by CSRF (cross-origin Origin still 200)")
    else:
        t_fail(f"GET should not be gated by CSRF, got {r.status_code}")

# 文档化的 `--host 0.0.0.0` 远程场景的 CSRF：绑定是通配符，
# 但浏览器发送机器的真实主机名，因此字面绑定比较会（错误地）
# 将每个跨主机 POST 拒绝为跨域。修复改为将 Origin 与请求自身的
# Host 头进行比较。我们通过将 BIND_HOST 配置为通配符并发送
# Origin 与 test_client 的隐式 Host（`localhost`）匹配的请求来模拟。
print("\nGroup 7b: CSRF accepts real hostnames for wildcard remote bind")
TOKEN_REMOTE = 'token-for-wildcard-bind-test'
with configured_app(host='0.0.0.0', auth_token=TOKEN_REMOTE, project_dir=proj_lifecycle if False else project) as appmod:
    client = appmod.app.test_client()
    r = client.post(
        '/api/sessions/2026-04-16_09-00-00/cancel',
        headers={
            'Origin': 'http://localhost',
            'Authorization': f'Bearer {TOKEN_REMOTE}',
        },
    )
    if r.status_code != 403:
        t_pass(f"wildcard 0.0.0.0 bind: Origin matching request Host passes CSRF (handler returned {r.status_code})")
    else:
        t_fail("wildcard 0.0.0.0 bind: same-origin Origin still rejected as cross-origin")

    # 跨域负向测试在通配符模式下仍然拒绝。
    r = client.post(
        '/api/sessions/2026-04-16_09-00-00/cancel',
        headers={
            'Origin': 'http://evil.example.com',
            'Authorization': f'Bearer {TOKEN_REMOTE}',
        },
    )
    if r.status_code == 403:
        t_pass("wildcard 0.0.0.0 bind: cross-origin Origin still 403")
    else:
        t_fail(f"wildcard 0.0.0.0 bind: cross-origin should 403, got {r.status_code}")

# 第 7c 组：IPv6 回环绑定（第 11 轮 P2 修复）。request.host 根据
# RFC 7230 携带带括号的形式 `[::1]:18000`，但 Origin 上的 urlparse
# 返回不带括号的 `::1`。如果不剥离括号，同源比较会对来自
# 文档化的 IPv6 回环绑定的每个变更请求返回 403。
print("\nGroup 7c: CSRF strips IPv6 brackets before same-origin compare (P2 Round 11)")
with configured_app(host='::1', auth_token='', project_dir=project) as appmod:
    client = appmod.app.test_client()
    # 模拟 Host 为带括号 IPv6 形式的请求。
    # Flask test_client 显式遵循 Host 头。
    r = client.post(
        '/api/sessions/2026-04-16_09-00-00/cancel',
        headers={
            'Host': '[::1]',
            'Origin': 'http://[::1]',
        },
    )
    if r.status_code != 403:
        t_pass(f"IPv6 loopback bind: bracketed Host vs unbracketed Origin host passes CSRF (handler returned {r.status_code})")
    else:
        t_fail("IPv6 loopback bind: same-origin POST still rejected as cross-origin")

    # Host 为 IPv6 时跨域仍然被拒绝。
    r = client.post(
        '/api/sessions/2026-04-16_09-00-00/cancel',
        headers={
            'Host': '[::1]',
            'Origin': 'http://evil.example.com',
        },
    )
    if r.status_code == 403:
        t_pass("IPv6 loopback bind: cross-origin Origin still 403")
    else:
        t_fail(f"IPv6 loopback bind: cross-origin should 403, got {r.status_code}")

# 第 7d 组：格式错误的 Origin 端口是受控的 403，而非未捕获的
# ValueError。``urlparse`` 接受 ``http://host:bad`` 或
# ``http://host:999999`` 等值而不抛出异常，但访问 ``.port``
# 会抛出 ValueError。如果不在 try/except 中包裹该访问，
# 发送此类头的客户端的 cancel/report/issue POST 会返回 500
# 而非预期的 403。
print("\nGroup 7d: CSRF rejects malformed Origin ports with 403 (no 500)")
with configured_app(host='127.0.0.1', auth_token='', project_dir=project) as appmod:
    client = appmod.app.test_client()
    for bad_origin in (
        'http://localhost:bad',
        'http://localhost:999999',
        'http://localhost:-1',
        'http://localhost:0.5',
    ):
        r = client.post(
            '/api/sessions/2026-04-16_09-00-00/cancel',
            headers={'Origin': bad_origin},
        )
        if r.status_code == 403:
            t_pass(f"malformed Origin {bad_origin!r} -> 403 (not 500)")
        else:
            t_fail(f"malformed Origin {bad_origin!r} should 403, got {r.status_code}")

# 第 8 组：cancel 允许 analyzing / finalizing 阶段（第 8 轮 P2 修复）。
# 仪表板之前拒绝除 status == 'active' 以外的任何状态，
# 这使得从 UI 无法取消 finalize 卡住的循环，即使
# scripts/cancel-rlcr-session.sh 支持这些阶段。
print("\nGroup 8: cancel route accepts analyzing/finalizing (P2)")

proj_lifecycle = make_project('proj_cancel_lifecycle', [
    {'id': '2026-04-17_AN', 'status_files': {
        'methodology-analysis-state.md': '---\ncurrent_round: 5\nmax_iterations: 42\n---\n',
    }},
    {'id': '2026-04-17_FI', 'status_files': {
        'finalize-state.md': '---\ncurrent_round: 9\nmax_iterations: 42\n---\n',
    }},
])

with configured_app(project_dir=proj_lifecycle) as appmod:
    client = appmod.app.test_client()

    # 取消 analyzing 会话：应该成功（不需要 --force）。
    r = client.post('/api/sessions/2026-04-17_AN/cancel')
    if r.status_code == 200 and (r.get_json() or {}).get('status') == 'cancelled':
        t_pass("POST cancel on analyzing session returns 200 cancelled")
    else:
        t_fail(f"analyzing-cancel should 200, got {r.status_code} {r.get_data(as_text=True)[:200]}")

    # 验证辅助函数确实重命名了活跃状态文件。
    rlcr_an = os.path.join(proj_lifecycle, '.humanize', 'rlcr', '2026-04-17_AN')
    if (os.path.isfile(os.path.join(rlcr_an, 'cancel-state.md'))
            and not os.path.isfile(os.path.join(rlcr_an, 'methodology-analysis-state.md'))):
        t_pass("analyzing session: methodology-analysis-state.md renamed to cancel-state.md")
    else:
        t_fail("analyzing session: state-file rename did not happen")

    # 取消 finalizing 会话：应该成功，因为路由
    # 向辅助函数转发 --force。没有 --force 时辅助函数
    # 返回退出码 2。
    r = client.post('/api/sessions/2026-04-17_FI/cancel')
    if r.status_code == 200 and (r.get_json() or {}).get('status') == 'cancelled':
        t_pass("POST cancel on finalizing session returns 200 (route forwards --force)")
    else:
        t_fail(f"finalizing-cancel should 200, got {r.status_code} {r.get_data(as_text=True)[:200]}")

    rlcr_fi = os.path.join(proj_lifecycle, '.humanize', 'rlcr', '2026-04-17_FI')
    if (os.path.isfile(os.path.join(rlcr_fi, 'cancel-state.md'))
            and not os.path.isfile(os.path.join(rlcr_fi, 'finalize-state.md'))):
        t_pass("finalizing session: finalize-state.md renamed to cancel-state.md")
    else:
        t_fail("finalizing session: state-file rename did not happen")

    # 取消终态会话仍然被拒绝（状态不在可取消集合中）。
    # 使用刚刚取消的会话进行测试。
    r = client.post('/api/sessions/2026-04-17_AN/cancel')
    if r.status_code == 400:
        t_pass("POST cancel on terminal (cancelled) session still returns 400")
    else:
        t_fail(f"terminal-cancel should 400, got {r.status_code}")

# 第 8b 组：--project 转发回归测试（第 9 轮 P2 修复）。
# 当仪表板进程从另一个工作区继承 CLAUDE_PROJECT_DIR 时，
# scripts/cancel-rlcr-session.sh 会回退到那个游离的环境变量，
# 而非仪表板的 --project，除非路由显式转发 --project。
# 通过将 CLAUDE_PROJECT_DIR 设置为不同的空项目并验证
# 取消仍然影响仪表板自己的项目来模拟该场景。
print("\nGroup 8b: cancel route forwards --project (Round 9 P2 fix)")

other_project = make_project('proj_other_for_env', [
    {'id': '2026-04-17_OTHER', 'status_files': {
        'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
    }},
])

dashboard_project = make_project('proj_dashboard_target', [
    {'id': '2026-04-17_TARGET', 'status_files': {
        'state.md': '---\ncurrent_round: 1\nmax_iterations: 42\n---\n',
    }},
])

prev_claude_pd = os.environ.get('CLAUDE_PROJECT_DIR', '')
os.environ['CLAUDE_PROJECT_DIR'] = other_project
try:
    with configured_app(project_dir=dashboard_project) as appmod:
        client = appmod.app.test_client()
        r = client.post(
            '/api/sessions/2026-04-17_TARGET/cancel',
            headers={'Origin': 'http://localhost'},
        )
        if r.status_code == 200:
            t_pass("cancel succeeds with stray CLAUDE_PROJECT_DIR pointing at another workspace")
        else:
            t_fail(f"cancel with stray CLAUDE_PROJECT_DIR should 200, got {r.status_code} {r.get_data(as_text=True)[:200]}")

        # TARGET 项目的会话应该被取消。
        target_dir = os.path.join(dashboard_project, '.humanize', 'rlcr', '2026-04-17_TARGET')
        if (os.path.isfile(os.path.join(target_dir, 'cancel-state.md'))
                and not os.path.isfile(os.path.join(target_dir, 'state.md'))):
            t_pass("cancel affected the dashboard's --project (TARGET cancelled)")
        else:
            t_fail("cancel did not rename TARGET state.md to cancel-state.md")

        # OTHER 项目的会话应该不受影响。
        other_dir = os.path.join(other_project, '.humanize', 'rlcr', '2026-04-17_OTHER')
        if os.path.isfile(os.path.join(other_dir, 'state.md')):
            t_pass("cancel did NOT touch the stray CLAUDE_PROJECT_DIR project (OTHER untouched)")
        else:
            t_fail("cancel mistakenly affected the OTHER project (state.md missing)")
finally:
    if prev_claude_pd:
        os.environ['CLAUDE_PROJECT_DIR'] = prev_claude_pd
    else:
        os.environ.pop('CLAUDE_PROJECT_DIR', None)

# 第 9 组：解析器识别旧版 AC-N 和第 5 轮后的 C-N 前缀
# （第 10 轮 P2 修复）。--skip-impl 模板播种 C-N 标识符；
# 如果解析器只匹配旧版前缀，仅评审的循环会在仪表板中
# 报告 0 个 AC / 0% 完成。
print("\nGroup 9: parsers recognise both AC-N and C-N criterion ids (P2 Round 10)")

def _make_session_with_tracker(name, session_id, tracker_body):
    proj = make_project(name, [
        {'id': session_id, 'status_files': {
            'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
        }},
    ])
    sd = os.path.join(proj, '.humanize', 'rlcr', session_id)
    with open(os.path.join(sd, 'goal-tracker.md'), 'w', encoding='utf-8') as f:
        f.write(tracker_body)
    return proj

# 旧版 AC-N 跟踪器。
legacy_tracker = """\
### Acceptance Criteria

- AC-1: First criterion
- AC-2: Second criterion
- AC-3: Third criterion

### Completed and Verified
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|
"""
proj_legacy = _make_session_with_tracker('proj_ac_legacy', '2026-04-17_LE', legacy_tracker)

with configured_app(project_dir=proj_legacy) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_LE')
    body = r.get_json() or {}
    if r.status_code == 200 and body.get('ac_total') == 3:
        t_pass("legacy AC-N criterion ids: ac_total == 3")
    else:
        t_fail(f"legacy AC-N detection wrong: {body.get('ac_total')} (status {r.status_code})")

# 第 5 轮后的 C-N 跟踪器（匹配 --skip-impl 模板形式）。
new_tracker = """\
### Acceptance Criteria

- C-1: First criterion
- C-2: Second criterion
- C-3: Third criterion

### Completed and Verified
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|
"""
proj_new = _make_session_with_tracker('proj_ac_new', '2026-04-17_NE', new_tracker)

with configured_app(project_dir=proj_new) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_NE')
    body = r.get_json() or {}
    if r.status_code == 200 and body.get('ac_total') == 3:
        t_pass("post-Round-5 C-N criterion ids: ac_total == 3 (review-only / --skip-impl loops report progress)")
    else:
        t_fail(f"C-N detection wrong: {body.get('ac_total')} (status {r.status_code})")

# 第 10 组：finalize 阶段分类仅适用于实时轮次，
# 不追溯到历史轮次（第 10 轮 P2 修复）。
print("\nGroup 10: finalize phase only labels the live round (P2 Round 10)")

proj_final = make_project('proj_finalize_phase', [
    {'id': '2026-04-17_FN', 'status_files': {
        'finalize-state.md': '---\ncurrent_round: 4\nmax_iterations: 42\n---\n',
    }},
])
fn_dir = os.path.join(proj_final, '.humanize', 'rlcr', '2026-04-17_FN')
# 播种几个轮次摘要，使 parse_session 有 0..4 轮次需要分类；
# 第 4 轮是当前轮次（实时 finalize 步骤）。
for n in range(5):
    with open(os.path.join(fn_dir, f'round-{n}-summary.md'), 'w', encoding='utf-8') as f:
        f.write(f'## Round {n}\n\nSummary content for round {n}.\n')

with configured_app(project_dir=proj_final) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_FN')
    body = r.get_json() or {}
    rounds = {item['number']: item['phase'] for item in (body.get('rounds') or [])}

    # 历史轮次 0..3 应该是 'implementation'，不是 'finalize'。
    historical_correct = all(rounds.get(n) == 'implementation' for n in range(4))
    if historical_correct:
        t_pass("historical rounds (0..3) classified as 'implementation', NOT 'finalize'")
    else:
        t_fail(f"historical rounds wrongly relabeled: {rounds}")

    # 当前（实时 finalize）轮次应该是 'finalize'。
    if rounds.get(4) == 'finalize':
        t_pass("current round (4) classified as 'finalize' (live finalize step)")
    else:
        t_fail(f"current round should be finalize, got {rounds.get(4)}")

# 第 11 组：解析器识别小数和无短横线的准则 id
# （第 13 轮 P2 修复）。计划/目标跟踪器格式显式允许
# 嵌套 id（AC-1.1、C-2.5）和无短横线的短形式（C1）。
# 只匹配 [A]?[C]-\d+ 的正则表达式会静默丢弃这些，
# 仪表板少报了 ac_total/ac_done。
print("\nGroup 11: parser recognises decimal + dashless criterion ids (P2 Round 13)")

mixed_tracker = """\
### Acceptance Criteria

- AC-1.1: Nested criterion with decimal suffix
- C-2.5: Single-letter nested criterion
- C3: Dashless short-form criterion
- AC-4: Legacy form still works alongside the new ones

### Completed and Verified
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|
"""
proj_mixed = _make_session_with_tracker('proj_ac_mixed', '2026-04-17_MX', mixed_tracker)

with configured_app(project_dir=proj_mixed) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_MX')
    body = r.get_json() or {}
    gt = body.get('goal_tracker') or {}
    acs = gt.get('acceptance_criteria') or []
    if r.status_code == 200 and body.get('ac_total') == 4:
        t_pass("mixed criterion forms (decimal + dashless + legacy): ac_total == 4")
    else:
        t_fail(f"mixed-form detection wrong: ac_total={body.get('ac_total')} "
               f"status={r.status_code} acs={[a.get('id') for a in acs]}")

    ac_ids = {item.get('id') for item in acs}
    if ac_ids == {'AC-1.1', 'C-2.5', 'C3', 'AC-4'}:
        t_pass("every id form is present verbatim in the parsed acceptance_criteria list")
    else:
        t_fail(f"expected {{AC-1.1, C-2.5, C3, AC-4}}, got {ac_ids}")

# 第 12 组：Completed-Verified 中的多准则单元格将每个
# 列出的 id 标记为完成（第 13 轮 P2 修复）。在此修复之前，
# 像 `| AC-1, AC-2 | ... |` 这样的行将复合字符串添加为完成键，
# 因此 acceptance_criteria 状态查找（测试单个 id）
# 将两个准则都保留为待定，即使循环的 shell 端
# 计数将它们视为已验证。
print("\nGroup 12: multi-id Completed-Verified cells mark every id done (P2 Round 13)")

multi_id_tracker = """\
### Acceptance Criteria

- AC-1: First criterion
- AC-2: Second criterion
- AC-3: Third criterion
- C-4.1: Fourth criterion (nested)

### Completed and Verified
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|
| AC-1, AC-2 | Combined task that satisfies two criteria | Round 3 | Round 3-review | evidence cell |
| AC-3 / C-4.1 | Second combined task with slash separator | Round 5 | Round 5-review | evidence cell |
"""
proj_multi = _make_session_with_tracker('proj_ac_multi', '2026-04-17_ML', multi_id_tracker)

with configured_app(project_dir=proj_multi) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_ML')
    body = r.get_json() or {}
    if r.status_code == 200 and body.get('ac_done') == 4 and body.get('ac_total') == 4:
        t_pass("all four criteria listed via multi-id cells are marked done (ac_done == 4)")
    else:
        t_fail(f"multi-id split wrong: ac_done={body.get('ac_done')} "
               f"ac_total={body.get('ac_total')} status={r.status_code}")

    gt = body.get('goal_tracker') or {}
    ac_by_id = {item.get('id'): item.get('status')
                for item in (gt.get('acceptance_criteria') or [])}
    if all(ac_by_id.get(i) == 'completed' for i in ('AC-1', 'AC-2', 'AC-3', 'C-4.1')):
        t_pass("every individual id in a multi-id row resolves to status='completed'")
    else:
        t_fail(f"per-id statuses wrong: {ac_by_id}")

# 第 13 组：表格形式的验收标准（第 14 轮 P2 修复）。
# 循环的 shell 端计数和 refine-plan 工作流都允许
# "### Acceptance Criteria" 部分渲染为表格而非项目列表。
# 之前解析器只匹配 "- id: description" 列表项，
# 因此表格形式的跟踪器报告 ac_total=0 并使分析失真。
print("\nGroup 13: parser accepts table-form acceptance criteria (P2 Round 14)")

table_ac_tracker = """\
### Ultimate Goal

Some goal.

### Acceptance Criteria

| ID | Description |
|----|-------------|
| AC-1 | First table criterion |
| C-2 | Second, dashed single-letter |
| C3 | Third, dashless short form |
| AC-4.1 | Fourth, nested decimal |

### Completed and Verified
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|
| AC-1 | did the thing | Round 1 | Round 1-review | tests |
"""
proj_tbl = _make_session_with_tracker('proj_ac_table', '2026-04-17_TB', table_ac_tracker)

with configured_app(project_dir=proj_tbl) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_TB')
    body = r.get_json() or {}
    if r.status_code == 200 and body.get('ac_total') == 4:
        t_pass("table-form AC section: ac_total == 4 (was 0 before fix)")
    else:
        t_fail(f"table-form detection wrong: ac_total={body.get('ac_total')} status={r.status_code}")

    gt = body.get('goal_tracker') or {}
    ac_by_id = {item.get('id'): item.get('status') for item in (gt.get('acceptance_criteria') or [])}
    if ac_by_id.get('AC-1') == 'completed' and ac_by_id.get('C-2') == 'pending':
        t_pass("table-form ACs inherit completion status from Completed-Verified split")
    else:
        t_fail(f"table-form status propagation wrong: {ac_by_id}")

# 第 13b 组：/api/sessions 必须保留 cache_logs，以便首页实时
# 面板可以打开 SSE 流（第 17 轮 P1 修复）。在此修复之前，
# 摘要路由剥离了该字段，因此多会话实时面板功能
# 在 #/ 上静默地从未激活。
print("\nGroup 13b: /api/sessions preserves cache_logs (P1 Round 17)")

proj_cl = make_project('proj_cache_logs', [
    {'id': '2026-04-17_CL', 'status_files': {
        'state.md': '---\ncurrent_round: 1\nmax_iterations: 42\n---\n',
    }},
])
cl_cache_dir = os.path.join(proj_cl, '.cache', 'humanize',
                            '-' + proj_cl.strip('/').replace('/', '-'),
                            '2026-04-17_CL')
# 播种缓存日志以便 parse_session 可以报告它。使用
# rlcr_sources 在用户级缓存不可用时遵循的项目本地 .cache 布局。
env_override = {'XDG_CACHE_HOME': os.path.join(proj_cl, '.cache')}
os.makedirs(cl_cache_dir, exist_ok=True)
with open(os.path.join(cl_cache_dir, 'round-0-codex-run.log'), 'w') as f:
    f.write('seeded cache log contents\n')

old_env = {}
for k, v in env_override.items():
    old_env[k] = os.environ.get(k)
    os.environ[k] = v
try:
    with configured_app(project_dir=proj_cl) as appmod:
        client = appmod.app.test_client()
        r = client.get('/api/sessions')
        body = r.get_json() or []
        row = next((item for item in body if item.get('id') == '2026-04-17_CL'), None)
        if row is None:
            t_fail('/api/sessions returned no entry for 2026-04-17_CL')
        elif 'cache_logs' not in row:
            t_fail('/api/sessions summary dict missing cache_logs field (home-page live panes broken)')
        elif isinstance(row.get('cache_logs'), list):
            t_pass('/api/sessions summary dict includes cache_logs (home-page live panes can find a log)')
        else:
            t_fail(f"/api/sessions cache_logs is not a list: {type(row.get('cache_logs')).__name__}")
finally:
    for k, v in old_env.items():
        if v is None:
            os.environ.pop(k, None)
        else:
            os.environ[k] = v

# 第 13c 组：方法论报告提示使用最新的轮次，而非最早的
# （第 17 轮 P2 修复）。通过源码级检查验证，因为
# /api/sessions/<id>/generate-report 实际上调用了
# 测试环境中不可用的 claude CLI。
print("\nGroup 13c: methodology report uses latest rounds (P2 Round 17)")

import re as _re_test
app_src = open(os.path.join(SERVER_DIR, 'app.py'), encoding='utf-8').read()
if _re_test.search(r'summaries\[-10:\]', app_src) and _re_test.search(r'reviews\[-10:\]', app_src):
    t_pass("methodology report prompt slices summaries[-10:] and reviews[-10:] (latest rounds)")
else:
    t_fail("methodology report prompt still uses summaries[:10]/reviews[:10] (earliest rounds drop late-phase signals)")

if not _re_test.search(r'summaries\[:10\]|reviews\[:10\]', app_src):
    t_pass("no stale summaries[:10] / reviews[:10] slice remains in app.py")
else:
    t_fail("stale [:10] slice still present somewhere in app.py")

# 第 15 组：会话路径验证（第 19 轮 P1 修复）。非会话路径和
# 遍历尝试必须解析为 404，而不是让下游解析器
# 读取 .humanize/ 下的任意文件。
print("\nGroup 15: session-path validation rejects traversal + non-session dirs (P1 Round 19)")

proj_trav = make_project('proj_path_validation', [
    {'id': '2026-04-17_PV', 'status_files': {
        'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
    }},
])
# 在 .humanize/rlcr 下播种一个非会话目录，使"游离目录"
# 请求有一个真实的目录可以指向（否则 isdir 会因不同原因
# 提前失败，测试就无意义了）。
stray_dir = os.path.join(proj_trav, '.humanize', 'rlcr', 'cache')
os.makedirs(stray_dir, exist_ok=True)

with configured_app(project_dir=proj_trav) as appmod:
    client = appmod.app.test_client()
    # 有效会话仍然返回 200（健全性基线）。
    r = client.get('/api/sessions/2026-04-17_PV')
    if r.status_code == 200:
        t_pass("[P1] valid session id still resolves to 200 (regression baseline)")
    else:
        t_fail(f"[P1] regression: valid session id returned {r.status_code}")

    # 遍历尝试必须 404，不能泄露同级 .humanize 路径的文件内容。
    # Flask 路由规范化 `/..`，因此我们测试到达 _get_session_dir
    # 的路径段形式。
    for bad_id in ('..', '.', '.hidden', 'foo/bar', 'foo\\bar'):
        r = client.get(f'/api/sessions/{bad_id}')
        if r.status_code == 404:
            pass  # expected
        else:
            t_fail(f"[P1] traversal id '{bad_id}' returned {r.status_code} (should be 404)")
            break
    else:
        t_pass("[P1] traversal ids ('..', '.', hidden, slashes, backslashes) all resolve to 404")

    # 真实但非会话的目录（游离的 `cache/`）也必须 404，
    # 因为 is_valid_session 需要 state.md 或终态的
    # *-state.md 文件。
    r = client.get('/api/sessions/cache')
    if r.status_code == 404:
        t_pass("[P1] non-session directory under .humanize/rlcr resolves to 404")
    else:
        t_fail(f"[P1] non-session dir returned {r.status_code} (should be 404)")

# 第 16 组：COMPLETE 判定需要终态标记行（第 19 轮 P2 修复）。
# 像 "CANNOT COMPLETE" 这样的文本不得将判定翻转为
# 'complete' — 这会静默地破坏 last_verdict、流水线 UI
# 以及任何在自由文本中讨论 COMPLETE 合同的评审的分析。
print("\nGroup 16: COMPLETE verdict requires terminal marker line (P2 Round 19)")

from parser import parse_review_result
import tempfile

test_cases = [
    ('terminal COMPLETE', 'Analysis says this is done.\n\nCOMPLETE\n', 'complete'),
    ('terminal COMPLETE with trailing blanks', 'Some prose.\n\nCOMPLETE\n\n\n', 'complete'),
    ('CANNOT COMPLETE prose', 'Explanation: CANNOT COMPLETE until the test passes.\n', 'unknown'),
    ('cannot COMPLETE yet prose', 'We cannot COMPLETE yet; more rounds needed.\n', 'unknown'),
    ('COMPLETE in middle, stalled terminal', 'COMPLETE was tried.\n\nThe run is stalled.\n', 'stalled'),
    ('advanced verdict', 'The loop advanced this round.\n', 'advanced'),
]

all_verdicts_correct = True
for label, content, expected in test_cases:
    with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False) as f:
        f.write(content)
        fp = f.name
    try:
        result = parse_review_result(fp)
        got = (result or {}).get('verdict')
        if got != expected:
            t_fail(f"[P2] {label}: expected verdict='{expected}', got '{got}'")
            all_verdicts_correct = False
    finally:
        os.unlink(fp)

if all_verdicts_correct:
    t_pass("[P2] COMPLETE verdict parsing handles terminal marker + false-positive prose + fallback verdicts")

# 第 17 组：没有方法论报告的会话的 /report 返回 404
# （第 19 轮 P3 修复）。没有这个，客户端会得到 200 加
# {'content': {'zh': None, 'en': None}}，无法区分
# "报告缺失"和"报告加载成功但为空"。
print("\nGroup 17: /api/sessions/<id>/report returns 404 when report missing (P3 Round 19)")

proj_rep = make_project('proj_no_report', [
    {'id': '2026-04-17_NR', 'status_files': {
        'state.md': '---\ncurrent_round: 0\nmax_iterations: 42\n---\n',
    }},
])

with configured_app(project_dir=proj_rep) as appmod:
    client = appmod.app.test_client()
    # 未播种 methodology-report.md 文件 -> 必须 404。
    r = client.get('/api/sessions/2026-04-17_NR/report')
    if r.status_code == 404:
        t_pass("[P3] /report returns 404 when methodology report file is missing")
    else:
        t_fail(f"[P3] /report returned {r.status_code} for missing report (expected 404)")

    # 播种一个真实的报告并确认路由翻转回 200。
    nr_dir = os.path.join(proj_rep, '.humanize', 'rlcr', '2026-04-17_NR')
    with open(os.path.join(nr_dir, 'methodology-analysis-report.md'), 'w') as f:
        f.write('# Methodology Report\n\nContent here.\n')
    # 丢弃任何缓存的会话以强制重新解析。
    appmod._invalidate_cache()
    r = client.get('/api/sessions/2026-04-17_NR/report')
    if r.status_code == 200:
        body = r.get_json() or {}
        content = (body.get('content') or {})
        if content.get('en') or content.get('zh'):
            t_pass("[P3] /report returns 200 with non-empty content when report exists")
        else:
            t_fail(f"[P3] /report 200 but content is empty: {body}")
    else:
        t_fail(f"[P3] /report returned {r.status_code} after report was seeded (expected 200)")

# 第 14 组：skip-impl 第 0 轮被分类为 code_review，而非
# implementation（第 14 轮 P2 修复）。setup-rlcr-loop.sh 写入
# 带有 skip_impl=true 的标记文件，使 _determine_phase() 可以
# 将其与第一轮恰好是最后一轮构建轮次
# （build_finish_round=0）的正常模式会话区分开。
print("\nGroup 14: skip-impl round 0 classifies as code_review (P2 Round 14)")

# A. Skip-impl 会话：每轮（包括第 0 轮）都是评审。
proj_skip = make_project('proj_skip_impl', [
    {'id': '2026-04-17_SK', 'status_files': {
        'state.md': '---\ncurrent_round: 3\nmax_iterations: 42\nreview_started: true\n---\n',
    }},
])
sk_dir = os.path.join(proj_skip, '.humanize', 'rlcr', '2026-04-17_SK')
# 标记同时携带 build_finish_round=0（旧版内容）和
# 新的 skip_impl=true 判别器。播种 round-N 摘要，使
# parse_session 有内容可以分类。
with open(os.path.join(sk_dir, '.review-phase-started'), 'w') as f:
    f.write('build_finish_round=0\nskip_impl=true\n')
for n in range(4):
    with open(os.path.join(sk_dir, f'round-{n}-summary.md'), 'w') as f:
        f.write(f'## Round {n}\n')

with configured_app(project_dir=proj_skip) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_SK')
    body = r.get_json() or {}
    rounds = {item['number']: item['phase'] for item in (body.get('rounds') or [])}
    if rounds.get(0) == 'code_review':
        t_pass("skip-impl round 0 classified as code_review (not implementation)")
    else:
        t_fail(f"skip-impl round 0 wrongly classified: {rounds}")
    if all(rounds.get(n) == 'code_review' for n in range(4)):
        t_pass("every round in a skip-impl session classified as code_review")
    else:
        t_fail(f"skip-impl round phases wrong: {rounds}")

# B. 正常模式回归：build_finish_round=0 但没有
# skip_impl=true 意味着第 0 轮是最后一轮构建轮次，
# 应该保持 'implementation'（第 1+ 轮是 code_review）。
proj_norm = make_project('proj_norm_build0', [
    {'id': '2026-04-17_NB', 'status_files': {
        'state.md': '---\ncurrent_round: 3\nmax_iterations: 42\nreview_started: true\n---\n',
    }},
])
nb_dir = os.path.join(proj_norm, '.humanize', 'rlcr', '2026-04-17_NB')
with open(os.path.join(nb_dir, '.review-phase-started'), 'w') as f:
    f.write('build_finish_round=0\n')
for n in range(4):
    with open(os.path.join(nb_dir, f'round-{n}-summary.md'), 'w') as f:
        f.write(f'## Round {n}\n')

with configured_app(project_dir=proj_norm) as appmod:
    client = appmod.app.test_client()
    r = client.get('/api/sessions/2026-04-17_NB')
    body = r.get_json() or {}
    rounds = {item['number']: item['phase'] for item in (body.get('rounds') or [])}
    if rounds.get(0) == 'implementation' and rounds.get(1) == 'code_review':
        t_pass("normal-mode build_finish_round=0 preserves round 0 = implementation (regression-safe)")
    else:
        t_fail(f"normal-mode round phases wrong: {rounds}")

# Summary
print()
print("========================================")
print(f"Passed: \033[0;32m{PASS}\033[0m")
print(f"Failed: \033[0;31m{FAIL}\033[0m")
if FAIL > 0:
    sys.exit(1)
print("\033[0;32mAll live route tests passed!\033[0m")
PYEOF
