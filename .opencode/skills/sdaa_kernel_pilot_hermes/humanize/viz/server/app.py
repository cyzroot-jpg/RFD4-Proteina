"""Humanize Viz — Flask 应用。

提供 SPA 前端、会话数据的 REST API 以及
实时文件变更通知的 WebSocket 服务。
"""

import os
import re
import sys
import json
import time
import argparse
import subprocess
import threading
from flask import Flask, Response, jsonify, request, send_from_directory, abort
from flask_sock import Sock
from werkzeug.utils import safe_join

# 将服务器目录添加到路径
sys.path.insert(0, os.path.dirname(__file__))
from parser import list_sessions, parse_session, read_plan_file, is_valid_session
from analyzer import compute_analytics
from exporter import export_session_markdown
from watcher import SessionWatcher, CacheLogWatcher
import rlcr_sources
import log_streamer

app = Flask(__name__, static_folder=None)
sock = Sock(app)

# 全局状态
PROJECT_DIR = '.'
STATIC_DIR = '.'
BIND_HOST = '127.0.0.1'
AUTH_TOKEN = ''
# 由 main() 在提供 `--trust-proxy`（或 HUMANIZE_VIZ_TRUST_PROXY=1）
# 时设置。确认服务器前面有 TLS 终止反向代理，使 CSRF 主机/端口
# 匹配器可以正确处理 `X-Forwarded-Proto` 以进行基于协议的端口解析。
# 本地主机绑定的开发模式始终保持为 False，以防止攻击者提供的
# `X-Forwarded-Proto` 头欺骗直连仪表板认为其为 HTTPS。
TRUST_PROXY = False
_session_cache = {}
_cache_lock = threading.Lock()
_ws_clients = set()
_ws_lock = threading.Lock()
_watcher = None


def _is_localhost_bind():
    """当服务器绑定到回环接口时返回 True。"""
    return BIND_HOST in ('127.0.0.1', '::1', 'localhost')


def _request_token():
    """从传入的 Flask 请求中提取 bearer 令牌。

    同时支持标准的 ``Authorization: Bearer <tok>`` 头（SPA 的
    ``fetch`` 调用使用）和 ``?token=<tok>`` 查询参数（SSE
    ``EventSource`` 客户端使用，因为浏览器无法在 EventSource
    上设置任意头）。
    """
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header[len('Bearer '):].strip()
        if token:
            return token
    return request.args.get('token', '').strip()


def _request_authorized():
    """当前请求是否有权访问受保护的端点。

    纵深防御的默认拒绝策略：``main()`` 拒绝在没有令牌的情况下
    启动非回环绑定，但任何跳过 ``main()`` 的代码路径（模块导入加
    上自定义 ``app.run`` 包装器、未来的测试框架、替代入口点）
    都会让每个请求通过。将非回环绑定上的空 AUTH_TOKEN 视为
    "未配置凭据，拒绝"而不是"未配置凭据，允许"。
    """
    if _is_localhost_bind():
        return True
    if not AUTH_TOKEN:
        return False
    return _request_token() == AUTH_TOKEN


def _get_rlcr_dir():
    return os.path.join(PROJECT_DIR, '.humanize', 'rlcr')


# 会话 ID 会流入前端的内联 onclick 模板字面量：
#   onclick="navigate('#/session/${s.id}')"
#   onclick="opsPreviewIssue('${s.id}')"
# 因此任何包含 JS 字符串元字符（引号、反引号、反斜杠、
# 尖括号、换行符等）的 ID 都会让恶意磁盘状态突破周围
# 的字符串并注入脚本。setup-rlcr-loop.sh 生成匹配
# `YYYY-MM-DD_HH-MM-SS` 的 ID，但一些测试固件和旧版
# 恢复使用更简单的 slug，如 `2026-04-17_CL`。接受安全
# 字符的完整超集（ASCII 字母、数字、下划线、连字符、
# 句点——附加规则拒绝 `..`、前导点和路径分隔符）以便
# 这些仍然有效，同时预先拒绝该集合之外的每个字符。
_SESSION_ID_RE = re.compile(r'^[A-Za-z0-9_.\-]+$')


def _is_safe_session_id(session_id):
    """当 ``session_id`` 仅使用安全字母表时返回 True。

    拒绝包含路径分隔符、父目录遍历标记、前导点或可能
    在前端内联 onclick 处理程序中转义 JS 字符串字面量的
    字符的任何内容。
    """
    if not session_id or len(session_id) > 128:
        return False
    if session_id in ('.', '..') or session_id.startswith('.'):
        return False
    if '/' in session_id or '\\' in session_id:
        return False
    return bool(_SESSION_ID_RE.match(session_id))


def _get_session_dir(session_id):
    """将 session_id 解析为其磁盘目录，或返回 None。

    纵深防御路径验证：每个会话范围的路由（detail、plan、report、
    generate-report、cancel、SSE 日志流）都将用户控制的 session_id
    传递到此处。没有这些检查，像 `/api/sessions/..` 这样的请求
    会解析为 `.humanize/..` = 项目的 `.humanize/` 父目录，而
    `.humanize/rlcr` 下的任何杂散目录（例如 `cache/` 目录）
    都会绕过 404 契约并让下游解析器读取任意文件。

    拒绝：
      - 不匹配规范 ``YYYY-MM-DD_HH-MM-SS`` 格式的 session_id
        （涵盖路径分隔符、`..`、点文件以及可能从前端内联 onclick
        处理程序中的 JS 字符串字面量转义的任何内容）
      - 在 realpath 规范化后解析到 RLCR 目录之外的候选项
        （防御符号链接逃逸）
      - 存在但实际不是 RLCR 会话的目录
        （parser.is_valid_session 需要 state.md 或终端
        *-state.md 文件）
    """
    if not _is_safe_session_id(session_id):
        return None
    rlcr_dir = _get_rlcr_dir()
    candidate = os.path.join(rlcr_dir, session_id)
    if not os.path.isdir(candidate):
        return None
    # 解析两边以与符号链接进行比较。候选项在规范化后
    # 必须仍然位于 rlcr 目录下。
    try:
        rlcr_real = os.path.realpath(rlcr_dir)
        cand_real = os.path.realpath(candidate)
    except (OSError, ValueError):
        return None
    rlcr_prefix = rlcr_real.rstrip(os.sep) + os.sep
    if not cand_real.startswith(rlcr_prefix):
        return None
    if not is_valid_session(candidate):
        return None
    return candidate


def _get_session(session_id, force_refresh=False):
    """获取会话数据（带缓存）。"""
    with _cache_lock:
        if not force_refresh and session_id in _session_cache:
            return _session_cache[session_id]

    session_dir = _get_session_dir(session_id)
    if not session_dir:
        return None

    session = parse_session(session_dir)
    with _cache_lock:
        _session_cache[session_id] = session
    return session


def _invalidate_cache(session_id=None):
    """使会话或所有会话的缓存失效。"""
    with _cache_lock:
        if session_id:
            _session_cache.pop(session_id, None)
        else:
            _session_cache.clear()


def broadcast_message(message):
    """向所有已连接的 WebSocket 客户端发送消息。"""
    dead = set()
    with _ws_lock:
        clients = set(_ws_clients)

    for ws in clients:
        try:
            ws.send(message)
        except Exception:
            dead.add(ws)

    if dead:
        with _ws_lock:
            # 通过 difference_update 而不是 `-=` 就地修改。
            # `_ws_clients -= dead` 会重新绑定名称，这使得 Python
            # 在整个 broadcast_message 中将 `_ws_clients` 视为
            # 函数局部变量，并在之前的 `set(_ws_clients)` 读取时
            # 抛出 UnboundLocalError。
            _ws_clients.difference_update(dead)

    # 使受影响会话的缓存失效
    try:
        data = json.loads(message)
        _invalidate_cache(data.get('session_id'))
    except (json.JSONDecodeError, AttributeError):
        pass


# --- 认证中间件 (T11) ---

# 即使在远程模式下也无需令牌即可访问的端点。
# 静态 SPA 外壳和健康检查探针必须保持开放，以便浏览器
# 可以获取 index.html 并报告存活性；其他所有内容
# （会话数据、SSE 流、变更器）都受到门控。
_AUTH_OPEN_PREFIXES = ('/api/health',)


def _is_open_path(path):
    if path == '/' or not path.startswith('/api/'):
        # SPA 回退提供的静态资源路径。
        return True
    for prefix in _AUTH_OPEN_PREFIXES:
        if path.startswith(prefix):
            return True
    return False


_MUTATING_METHODS = frozenset({'POST', 'PUT', 'PATCH', 'DELETE'})

_LOOPBACK_HOSTS = frozenset({'localhost', '127.0.0.1', '::1'})


def _default_port_for_scheme(scheme):
    return 443 if scheme == 'https' else 80


def _effective_request_scheme():
    """返回浏览器实际使用的线路级协议。

    在 TLS 终止反向代理后面（`--trust-proxy` 部署模式），
    Flask 将后端通道请求视为纯 HTTP — `request.scheme` 为
    `http`，因此下面的默认端口查找会缩减为 80，即使浏览器
    通过 443 与代理通信。这种不匹配将每个浏览器的
    `https://host` Origin 在 `_origin_matches_request()` 处
    变为 403，因为计算的请求端口（80）与 Origin 端口（443）
    不同，这反过来阻止了标准 HTTPS 代理部署中的
    cancel / generate-report / GitHub-issue 提交。

    当 `TRUST_PROXY` 为 True 时，遵从 `X-Forwarded-Proto`
    （由每个合理的反向代理填充）进行协议解析，以便默认端口
    计算与浏览器视图一致。除显式 `https` 以外的任何内容
    回退到 Flask 自己的 `request.scheme`，因此 HTTP 代理
    部署继续工作。当 `TRUST_PROXY` 为 False 时，我们完全
    忽略该头——否则直连本地主机仪表板上的攻击者可以通过
    精心构造的头来翻转我们的协议视图。
    """
    if TRUST_PROXY:
        forwarded = (request.headers.get('X-Forwarded-Proto') or '').strip().lower()
        # 某些代理在存在多跳时用逗号分隔；第一个条目是客户端命中的。
        if forwarded:
            forwarded = forwarded.split(',', 1)[0].strip()
        if forwarded == 'https':
            return 'https'
        if forwarded == 'http':
            return 'http'
    return request.scheme


def _parse_request_host_port():
    """返回当前请求 Host 头的 ``(host, port)``。

    ``request.host`` 是浏览器实际用于访问仪表板的值
    （例如 ``server.example.com:18000``），在通配符部署
    （如 ``--host 0.0.0.0``）中可能与配置的 ``BIND_HOST``
    不同。同源检查必须与此值进行比较，而不是与绑定进行
    比较，以便远程浏览器实际上可以发出跨主机写入。

    HTTP Host 头中的 IPv6 主机按 RFC 7230 用方括号括起来
    （回环绑定的 ``[::1]:18000``），但 ``urlparse(Origin)
    .hostname`` 返回无括号的形式（``::1``）。在主机/端口
    拆分后去掉方括号，以便比较匹配。
    """
    scheme = _effective_request_scheme()
    raw = (request.host or '').lower()
    if not raw:
        return ('', _default_port_for_scheme(scheme))
    if ':' in raw and not raw.endswith(']'):
        host, port_str = raw.rsplit(':', 1)
        try:
            port = int(port_str)
        except ValueError:
            port = _default_port_for_scheme(scheme)
    else:
        host = raw
        port = _default_port_for_scheme(scheme)
    if host.startswith('[') and host.endswith(']'):
        host = host[1:-1]
    return (host, port)


def _origin_matches_request(origin_value):
    """当 ``origin_value`` 指向浏览器实际用于此请求的相同 host:port 时为 True。

    与请求自身的 ``Host`` 头（而不是配置的 ``BIND_HOST``）
    进行比较是让 ``--host 0.0.0.0`` 远程部署工作的原因：
    绑定是通配符，但浏览器发送机器的真实主机名，因此字面
    绑定比较会将每个跨主机 POST 视为跨域而拒绝。回环别名
    （localhost/127.0.0.1/::1）被视为等效，因此用户不会
    被固定到他们碰巧输入的别名。
    """
    if not origin_value:
        return False
    try:
        from urllib.parse import urlparse
        parsed = urlparse(origin_value)
    except Exception:
        return False
    if parsed.scheme not in ('http', 'https'):
        return False
    origin_host = (parsed.hostname or '').lower()
    if not origin_host:
        return False
    # ``urlparse`` 对格式错误的 Origin 值（如 ``http://host:bad``
    # 或 ``http://host:999999``）也能成功；端口仅在访问 ``.port``
    # 时被验证，这会引发 ValueError。将此类值视为不匹配，以便
    # ``_enforce_csrf_protection`` 返回受控的 403，而不是让异常
    # 冒泡为 500。
    try:
        origin_port = parsed.port or _default_port_for_scheme(parsed.scheme)
    except ValueError:
        return False

    request_host, request_port = _parse_request_host_port()
    if origin_port != request_port:
        return False
    if origin_host in _LOOPBACK_HOSTS and request_host in _LOOPBACK_HOSTS:
        return True
    return origin_host == request_host


def _enforce_csrf_protection():
    """无论绑定/认证姿态如何，拒绝跨域写入。

    远程模式部署仍然受到认证中间件（令牌检查）的进一步
    门控；CSRF 在此基础上分层，因此被盗的令牌也不能从
    任意来源被利用。本地主机绑定是 Codex 最初标记的缺口：
    没有这一层，同一浏览器中打开的任何网页都可以向
    127.0.0.1:<port> 变更端点发送 POST 请求。
    """
    if request.method not in _MUTATING_METHODS:
        return None
    if _is_open_path(request.path):
        return None
    origin = request.headers.get('Origin', '').strip()
    referer = request.headers.get('Referer', '').strip()
    if origin:
        if _origin_matches_request(origin):
            return None
        return jsonify({'error': 'cross-origin write rejected'}), 403
    if referer:
        if _origin_matches_request(referer):
            return None
        return jsonify({'error': 'cross-origin write rejected'}), 403
    # 没有 Origin 也没有 Referer 头：浏览器在跨站表单/fetch POST
    # 上总是设置至少其中一个，因此缺失几乎肯定意味着请求来自
    # 同源脚本（抑制了两者）、服务器到服务器工具（如 curl）
    # 或我们自己的 Flask test_client。允许它；认证层仍然通过
    # 令牌门控远程请求。
    return None


@app.before_request
def _enforce_auth_and_csrf():
    """组合认证 + CSRF 门控。

    顺序很重要：CSRF 层先运行，因此即使请求碰巧携带了
    有效令牌，跨域写入也会被拒绝（纵深防御）。然后认证
    层在远程模式下为每个受保护的端点强制执行 bearer 令牌。
    """
    csrf_response = _enforce_csrf_protection()
    if csrf_response is not None:
        return csrf_response
    if _is_localhost_bind():
        return None
    if _is_open_path(request.path):
        return None
    if _request_authorized():
        return None
    return jsonify({'error': 'unauthorized'}), 401


# --- 静态文件服务 ---

@app.route('/')
def index():
    return send_from_directory(STATIC_DIR, 'index.html')


@app.route('/<path:path>')
def static_files(path):
    if path.startswith('api/'):
        abort(404)
    # 在探测文件系统之前拒绝遍历/绝对路径。
    # 之前的实现对任何客户端提供的 ``path`` 执行
    # ``os.path.isfile(os.path.join(STATIC_DIR, path))``，
    # 这将有意开放的端点变成了未经认证的文件系统存在性
    # 预言机：包含 ``..`` 段的请求在目标存在时进入
    # ``send_from_directory`` 分支（404），但在不存在时
    # 回退到 SPA 回退（200）。Werkzeug 的 ``safe_join``
    # 对任何会逃逸 STATIC_DIR 的路径返回 ``None``，
    # 因此在这种情况下我们完全跳过探测，直接转到 SPA
    # 回退——无论遍历目标是否存在，响应都是相同的。
    safe_path = safe_join(STATIC_DIR, path)
    if safe_path is not None and os.path.isfile(safe_path):
        return send_from_directory(STATIC_DIR, path)
    # SPA 回退
    return send_from_directory(STATIC_DIR, 'index.html')


# --- 健康检查 ---

@app.route('/api/health')
def health():
    return jsonify({'status': 'ok'})


# --- 项目列表（只读；按 DEC-3 的 CLI 固定单项目模型）---
#
# T10 后端清理：旧版服务器全局项目切换器（允许任何客户端
# 为所有已连接客户端修改 PROJECT_DIR 并持久化到
# ~/.humanize/viz-projects.json）已被移除，改为每个项目一个
# 服务器。项目选择现在在启动时通过
# `humanize monitor web --project <path>` 由 CLI 固定。
# 只读 /api/projects 端点在第 5 轮 UI 重构期间保留以保持
# 前端兼容性；它仅返回服务器启动时使用的项目，且从不
# 修改项目文件。


@app.route('/api/projects')
def api_projects():
    rlcr_dir = os.path.join(PROJECT_DIR, '.humanize', 'rlcr')
    session_count = 0
    if os.path.isdir(rlcr_dir):
        session_count = len([
            d for d in os.listdir(rlcr_dir)
            if os.path.isdir(os.path.join(rlcr_dir, d))
        ])
    return jsonify([
        {
            'path': PROJECT_DIR,
            'name': os.path.basename(PROJECT_DIR),
            'sessions': session_count,
            'active': True,
            'cli_fixed': True,
        }
    ])


_CANCELLABLE_STATUSES = frozenset({'active', 'analyzing', 'finalizing'})


_REMOVED_PROJECT_ENDPOINT_BODY = {
    'error': 'project switching is no longer supported; run `humanize monitor web --project <path>` per project',
    'replacement': 'humanize monitor web --project <path>',
}


@app.route('/api/projects/switch', methods=['POST'])
@app.route('/api/projects/add', methods=['POST'])
@app.route('/api/projects/remove', methods=['POST'])
def api_projects_removed():
    return jsonify(_REMOVED_PROJECT_ENDPOINT_BODY), 410


# --- REST API ---

@app.route('/api/sessions')
def api_sessions():
    sessions = list_sessions(PROJECT_DIR)
    # 返回摘要级数据（不含完整轮次内容）。cache_logs 被包含在内，
    # 因为首页多会话实时窗格功能需要它来选择日志文件名并打开
    # SSE 流；没有它，每个活跃卡片都会降级为 WAITING 状态，
    # 无论缓存日志是否实际存在。
    #
    # 在发送之前过滤掉任何名称不匹配规范会话 ID 形状的
    # 磁盘目录。这是 Codex 标记的内联 onclick XSS 向量的
    # 第二道防线——手工创建的名称如
    # `2026-04-18_00-34-17'); alert(1); //` 的会话目录
    # 不应该到达前端，那里 `onclick="navigate('#/session/${s.id}')"`
    # 会突破 JS 字符串。
    summaries = []
    for s in sessions:
        if not _is_safe_session_id(s.get('id', '')):
            continue
        summaries.append({
            'id': s['id'],
            'status': s['status'],
            'current_round': s['current_round'],
            'max_iterations': s['max_iterations'],
            'full_review_round': s.get('full_review_round'),
            'plan_file': s['plan_file'],
            'start_branch': s['start_branch'],
            'started_at': s['started_at'],
            'last_verdict': s['last_verdict'],
            'drift_status': s['drift_status'],
            # 额外的状态字段，使首页活跃卡片可以逐行匹配
            # `humanize monitor rlcr` 状态栏，而无需强制客户端
            # 访问 /api/sessions/<id>。
            'codex_model': s.get('codex_model', ''),
            'codex_effort': s.get('codex_effort', ''),
            'ask_codex_question': s.get('ask_codex_question', False),
            'review_started': s.get('review_started', False),
            'agent_teams': s.get('agent_teams', False),
            'push_every_round': s.get('push_every_round', False),
            'mainline_stall_count': s.get('mainline_stall_count', 0),
            'last_mainline_verdict': s.get('last_mainline_verdict', 'unknown'),
            'build_finish_round': s.get('build_finish_round'),
            'skip_impl': s.get('skip_impl', False),
            'tasks_done': s['tasks_done'],
            'tasks_total': s['tasks_total'],
            'tasks_active': s.get('tasks_active', 0),
            'tasks_deferred': s.get('tasks_deferred', 0),
            'ac_done': s['ac_done'],
            'ac_total': s['ac_total'],
            'ultimate_goal': s.get('ultimate_goal', ''),
            'duration_minutes': s.get('duration_minutes'),
            'cache_logs': s.get('cache_logs') or [],
            'active_log_path': s.get('active_log_path', ''),
            'git_status': s.get('git_status'),
        })
    return jsonify(summaries)


@app.route('/api/sessions/<session_id>')
def api_session_detail(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)
    return jsonify(session)


@app.route('/api/sessions/<session_id>/plan')
def api_session_plan(session_id):
    session_dir = _get_session_dir(session_id)
    if not session_dir:
        abort(404)
    plan = read_plan_file(session_dir, PROJECT_DIR)
    if plan is None:
        abort(404)
    return jsonify({'content': plan})


@app.route('/api/sessions/<session_id>/report')
def api_session_report(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)
    report = session.get('methodology_report')
    # parse_session 始终通过 _to_bilingual 填充 methodology_report，
    # 当报告文件不存在时返回 {'zh': None, 'en': None}。之前的
    # `if not report:` 从未触发，因为该字典是真值，所以路由
    # 返回 200 和空负载，客户端无法区分"报告缺失"和"报告
    # 加载成功但为空"。在返回 200 之前要求 zh / en 至少一个
    # 携带内容。
    if not isinstance(report, dict) or not (report.get('zh') or report.get('en')):
        abort(404)
    return jsonify({'content': report})


@app.route('/api/analytics')
def api_analytics():
    # 在将磁盘会话输入分析器之前，过滤掉任何目录名称不匹配
    # 规范形状的会话。分析页面的比较表将 ``session_id`` 渲染到
    # 内联 ``onclick="navigate('#/session/${id}')`` 模板和单元格
    # HTML 中；没有这个过滤器，包含引号/JS 元字符的精心构造的
    # 目录名会到达浏览器，并可能突破属性或注入脚本，这正是
    # ``/api/sessions`` 已经防御的向量。在此匹配相同的过滤器
    # 保持两个表面一致。
    sessions = [
        s for s in list_sessions(PROJECT_DIR)
        if _is_safe_session_id(s.get('id', ''))
    ]
    analytics = compute_analytics(sessions)
    return jsonify(analytics)


def _report_is_stale(session_dir, report_path):
    """当磁盘上的方法论报告早于 ``session_dir`` 下的任何轮次
    摘要/审查结果时为 True。

    缓存的报告是针对会话的早期快照生成的；在其 mtime 之后
    落地的任何新摘要或审查文件都会使其失效。报告之后的活动：
      - 写入了新轮次的摘要（循环继续进行）
      - 现有轮次的审查结果发生了变化（判决翻转）
    无论哪种方式，在 /generate-report 上返回过时的缓存文本
    都会向 Codex/用户提供一个已经继续前进的会话的分析。

    当报告缺失或为空（调用者将从头生成）时，或当报告存在
    且至少与每个源文件一样新时返回 False。
    """
    try:
        report_mtime = os.path.getmtime(report_path)
    except OSError:
        return False
    import glob as _glob
    sources = _glob.glob(os.path.join(session_dir, 'round-*-summary.md'))
    sources += _glob.glob(os.path.join(session_dir, 'round-*-review-result.md'))
    for src in sources:
        try:
            if os.path.getmtime(src) > report_mtime:
                return True
        except OSError:
            continue
    return False


@app.route('/api/sessions/<session_id>/generate-report', methods=['POST'])
def api_generate_report(session_id):
    """通过调用本地 Claude CLI 生成方法论分析报告。

    ``?force=1`` 查询参数绕过"报告已存在"的快捷方式并始终
    重新运行 Claude。没有它时，当缓存的报告早于任何轮次
    摘要或审查结果文件时，路由仍会重新运行——旧的
    "存在 => 完成"路径让用户在自上次预览以来已推进的
    会话上看到过时的分析。
    """
    session_dir = _get_session_dir(session_id)
    if not session_dir:
        abort(404)

    report_path = os.path.join(session_dir, 'methodology-analysis-report.md')
    force_regen = request.args.get('force', '').strip() in ('1', 'true', 'yes')

    # 仅当缓存报告存在、非空且仍然比每个贡献于分析的源文件
    # 更新时才提供缓存报告。否则，过时的缓存会在活跃会话的
    # 新轮次中无限期存在。
    if (not force_regen
            and os.path.exists(report_path)
            and os.path.getsize(report_path) > 0
            and not _report_is_stale(session_dir, report_path)):
        with open(report_path, 'r', encoding='utf-8') as f:
            return jsonify({'status': 'exists', 'content': f.read()})

    # 收集轮次摘要和审查结果（按轮次号数字排序）
    import glob as _glob
    import re as _re_local

    def _sort_round_files(files):
        def _round_num(path):
            m = _re_local.search(r'round-(\d+)-', os.path.basename(path))
            return int(m.group(1)) if m else 0
        return sorted(files, key=_round_num)

    summaries = []
    for sf in _sort_round_files(_glob.glob(os.path.join(session_dir, 'round-*-summary.md'))):
        try:
            with open(sf, 'r', encoding='utf-8') as f:
                summaries.append(f'--- {os.path.basename(sf)} ---\n{f.read()}')
        except (PermissionError, OSError):
            pass

    reviews = []
    for rf in _sort_round_files(_glob.glob(os.path.join(session_dir, 'round-*-review-result.md'))):
        try:
            with open(rf, 'r', encoding='utf-8') as f:
                reviews.append(f'--- {os.path.basename(rf)} ---\n{f.read()}')
        except (PermissionError, OSError):
            pass

    if not summaries and not reviews:
        return jsonify({'error': 'No round data to analyze'}), 400

    # 构建分析提示
    prompt = f"""Analyze the following RLCR development records from a PURE METHODOLOGY perspective.

CRITICAL SANITIZATION RULES — your output MUST NOT contain:
- File paths, directory paths, or module paths
- Function names, variable names, class names, or method names
- Branch names, commit hashes, or git identifiers
- Business domain terms, product names, or feature names
- Code snippets or code fragments of any kind
- Raw error messages or stack traces
- Project-specific URLs or endpoints
- Any information that could identify the specific project

Focus areas:
- Iteration efficiency: Were rounds productive or repetitive?
- Feedback loop quality: Did reviewer feedback lead to improvements?
- Stagnation patterns: Were there signs of going in circles?
- Review effectiveness: Did reviews catch real issues or create false positives?
- Plan-to-execution alignment: Did execution follow the plan or drift?
- Round count vs. progress ratio: Was the number of rounds proportional to progress?
- Communication clarity: Were summaries and reviews clear and actionable?

Output format: Write a structured markdown report following this exact structure:

## Context
<Brief session stats: round count, exit reason, AC completion — no project names>

## Observations
<Numbered list of methodology observations — generic language only>

## Suggested Improvements
| # | Suggestion | Mechanism |
|---|-----------|-----------|
<Table rows with concrete improvement suggestions>

## Quantitative Summary
| Metric | Value |
|--------|-------|
<Key metrics table>

--- ROUND SUMMARIES ---
{chr(10).join(summaries[-10:])}

--- REVIEW RESULTS ---
{chr(10).join(reviews[-10:])}
"""
    # `_sort_round_files` 按升序轮次顺序返回条目
    # （第 0 轮、第 1 轮、...），因此 [-10:] 选择最新的 10 轮。
    # 方法论信号——停滞、漂移、最终化——在长会话的后期阶段
    # 浮现；取 [:10] 会丢弃对于超过十轮的会话最重要的轮次。
    # 轮次 <=10 的会话不受影响。

    # 以管道模式调用 Claude CLI
    try:
        result = subprocess.run(
            ['claude', '-p', '--model', 'sonnet', '--output-format', 'text'],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=PROJECT_DIR,
        )

        if result.returncode != 0:
            return jsonify({
                'error': f'Claude CLI failed (exit {result.returncode})',
                'stderr': result.stderr[-500:] if result.stderr else '',
            }), 500

        report_content = result.stdout.strip()
        if not report_content:
            return jsonify({'error': 'Claude returned empty response'}), 500

        # 保存报告
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(report_content)

        # 使会话缓存失效以便报告被拾取
        _invalidate_cache(session_id)

        return jsonify({'status': 'generated', 'content': report_content})

    except FileNotFoundError:
        return jsonify({'error': 'Claude CLI not found. Install Claude Code to generate reports.'}), 500
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Claude CLI timed out (120s). Try again or reduce session size.'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500


def _find_cancel_script():
    """从插件布局或环境变量解析 cancel-rlcr-loop.sh。"""
    # 首先检查环境变量覆盖
    env_script = os.environ.get('HUMANIZE_CANCEL_SCRIPT', '')
    if env_script and os.path.isfile(env_script):
        return env_script

    # 同一人形插件仓库中的兄弟路径 (viz/server/../../scripts/)
    server_dir = os.path.dirname(os.path.abspath(__file__))
    sibling = os.path.normpath(os.path.join(server_dir, '..', '..', 'scripts', 'cancel-rlcr-loop.sh'))
    if os.path.isfile(sibling):
        return sibling

    # 搜索标准插件缓存位置
    search_paths = [
        os.path.expanduser('~/.claude/plugins/cache/PolyArch/humanize'),
        os.path.expanduser('~/.claude/plugins/marketplaces/humania'),
    ]
    for base in search_paths:
        if not os.path.isdir(base):
            continue
        for entry in sorted(os.listdir(base), reverse=True):
            candidate = os.path.join(base, entry, 'scripts', 'cancel-rlcr-loop.sh')
            if os.path.isfile(candidate):
                return candidate
        candidate = os.path.join(base, 'scripts', 'cancel-rlcr-loop.sh')
        if os.path.isfile(candidate):
            return candidate

    return None


def _find_session_cancel_script():
    """从插件安装中定位会话范围的取消辅助程序。

    与 ``_find_cancel_script`` 相同的查找语义：环境变量覆盖优先，
    然后是兄弟仓库路径（此文件的祖父目录加 ``scripts/``），
    然后是标准插件缓存位置。没有兄弟路径和更广泛的缓存路径
    检查，路由在任何未设置 ``CLAUDE_PLUGIN_ROOT`` 的部署中
    都会 500，这是从另一个终端通过 ``humanize monitor web``
    启动仪表板时的常见情况。
    """
    env_script = os.environ.get('HUMANIZE_CANCEL_SESSION_SCRIPT', '')
    if env_script and os.path.isfile(env_script):
        return env_script

    server_dir = os.path.dirname(os.path.abspath(__file__))
    sibling = os.path.normpath(
        os.path.join(server_dir, '..', '..', 'scripts', 'cancel-rlcr-session.sh')
    )
    if os.path.isfile(sibling):
        return sibling

    search_paths = [
        os.environ.get('CLAUDE_PLUGIN_ROOT', ''),
        os.path.expanduser('~/.claude/plugins/cache/PolyArch/humanize'),
        os.path.expanduser('~/.claude/plugins/marketplaces/humania'),
    ]
    for base in search_paths:
        if not base or not os.path.isdir(base):
            continue
        for entry in sorted(os.listdir(base), reverse=True):
            candidate = os.path.join(base, entry, 'scripts', 'cancel-rlcr-session.sh')
            if os.path.isfile(candidate):
                return candidate
        candidate = os.path.join(base, 'scripts', 'cancel-rlcr-session.sh')
        if os.path.isfile(candidate):
            return candidate
    return None


@app.route('/api/sessions/cancel', methods=['POST'])
def api_cancel_session_missing_id():
    """从标准 C-7 的缺失会话 ID 契约的可达 400。

    Flask 路由要求主取消路由中的 ``<session_id>`` 段完全匹配，
    因此没有它的请求会在任何处理程序运行之前返回 404。
    这个显式的无 ID 路由公开了记录的 400 契约，并让客户端
    （和测试）区分"你忘记了 ID"和"ID 不存在"。
    """
    return jsonify({
        'error': 'session_id is required',
        'usage': 'POST /api/sessions/<session_id>/cancel',
    }), 400


@app.route('/api/sessions/<session_id>/cancel', methods=['POST'])
def api_cancel_session(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)
    status = session.get('status')
    if status not in _CANCELLABLE_STATUSES:
        return jsonify({
            'error': 'Session is not in a cancellable state',
            'status': status,
        }), 400

    cancel_script = _find_session_cancel_script()
    if not cancel_script:
        return jsonify({
            'error': 'Session-scoped cancel helper not found. Ensure humanize plugin is installed.',
            'expected_script': 'scripts/cancel-rlcr-session.sh',
        }), 500

    # 当会话处于最终化阶段时，辅助程序需要 --force 以避免静默
    # 取消；没有 --force 它会以代码 2 退出。转发它以便仪表板
    # 取消适用于辅助程序支持的每个阶段（active / analyzing / finalizing）。
    #
    # `--project` 必须显式传递，以便辅助程序不会回退到
    # ``CLAUDE_PROJECT_DIR``（仪表板进程可能从启动它的 shell
    # 继承，指向完全不同的工作区）。
    helper_args = [cancel_script, '--project', PROJECT_DIR, '--session-id', session_id]
    if status == 'finalizing':
        helper_args.append('--force')

    try:
        subprocess.run(helper_args, cwd=PROJECT_DIR, timeout=30, check=True)
        _invalidate_cache(session_id)
        return jsonify({'status': 'cancelled', 'session_id': session_id})
    except subprocess.SubprocessError as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/sessions/<session_id>/export', methods=['POST'])
def api_export_session(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)
    markdown = export_session_markdown(session)
    return jsonify({'content': markdown, 'filename': f'rlcr-report-{session_id}.md'})


import re as _re


_FORBIDDEN_CATEGORIES = [
    ('path_token', _re.compile(r'[/\\]\w+\.\w{1,4}\b')),
    ('path_token', _re.compile(r'\b\w+/\w+/\w+')),
    ('qualified_name', _re.compile(r'\b\w+::\w+')),
    ('qualified_name', _re.compile(r'\b\w+\.\w+\.\w+\(')),
    ('git_hash', _re.compile(r'\b[a-f0-9]{7,40}\b')),
    ('branch_name', _re.compile(r'\b(?:feat|fix|hotfix|release|bugfix)/\w+')),
    ('branch_name', _re.compile(r'\bmain|master|develop\b')),
    ('code_definition', _re.compile(r'\bdef \w+|function \w+|class \w+')),
    # 仅匹配代码形式的导入。之前的 `\b(?:import|require|from)
    # \s+\w+` 模式匹配了普通英语散文，如 "drifted from the
    # original plan structure"，这标记了内置的 `plan_execution`
    # 方法论观察并导致 /api/sessions/<id>/github-issue 以误报
    # 警告拒绝已清理的负载。将每个变体锚定到仅出现在代码中的
    # 上下文：
    #   - Python `import x` / `import x.y` 在行首
    #   - Python `from x.y import z` 在行首
    #   - JS/Node `require("…")` 调用语法
    ('import_statement', _re.compile(r'^\s*import\s+[\w.]+', _re.MULTILINE)),
    ('import_statement', _re.compile(r'^\s*from\s+[\w.]+\s+import\b', _re.MULTILINE)),
    ('import_statement', _re.compile(r'\brequire\s*\(')),
    ('code_fence', _re.compile(r'```')),
    ('identifier', _re.compile(r'\b\w+_\w+_\w+\b')),
    ('identifier', _re.compile(r'\b[a-z]+[A-Z]\w+\b')),
    ('stack_trace', _re.compile(r'\bTraceback \(most recent')),
    ('stack_trace', _re.compile(r'\bFile ".+", line \d+')),
    ('error_pattern', _re.compile(r'\b(?:Error|Exception|Panic|SIGSEGV|SIGABRT)\b')),
    ('stack_trace', _re.compile(r'at \w+\.\w+\(.*:\d+:\d+\)')),
    ('external_url', _re.compile(r'https?://(?!github\.com/humania)')),
    ('local_endpoint', _re.compile(r'\b(?:localhost|127\.0\.0\.1):\d+')),
]


def _scan_for_forbidden_tokens(text):
    """返回文本中找到的禁止模式的 {category: count} 字典。
    从不返回匹配的字符串本身以防止泄漏。"""
    violations = {}
    for category, pattern in _FORBIDDEN_CATEGORIES:
        matches = pattern.findall(text)
        if matches:
            violations[category] = violations.get(category, 0) + len(matches)
    return violations


def _is_english_only(text):
    """检查文本是否主要为 ASCII/英文（>95% ASCII 字符）。"""
    if not text:
        return True
    ascii_count = sum(1 for c in text if ord(c) < 128)
    return (ascii_count / len(text)) > 0.95


# 受限的方法论分类法——观察被分类到这些通用类别中。
# 只有类别标签和通用措辞被输出到问题中；没有报告散文通过。
_METHODOLOGY_CATEGORIES = {
    'iteration_efficiency': 'Iteration efficiency pattern observed: rounds showed uneven productivity distribution.',
    'feedback_loop': 'Feedback loop quality issue: reviewer-implementer communication could be improved.',
    'stagnation': 'Stagnation pattern detected: consecutive rounds showed limited forward progress.',
    'review_effectiveness': 'Review effectiveness concern: review feedback did not consistently drive improvements.',
    'plan_execution': 'Plan-execution alignment gap: implementation drifted from the original plan structure.',
    'verification_gap': 'Verification scope issue: implementer verification did not match reviewer expectations.',
    'phase_transition': 'phase-boundary transition pattern: the boundary between implementation and review work was unclear.',
    'scope_management': 'Scope management observation: work expanded or contracted relative to plan boundaries.',
    'general': 'General methodology observation noted.',
}

_CATEGORY_KEYWORDS = {
    'iteration_efficiency': ['efficiency', 'productive', 'unproductive', 'round count', 'per-round output', 'diminish'],
    'feedback_loop': ['feedback', 'communication', 'reviewer', 'implementer', 'round-trip'],
    'stagnation': ['stagnation', 'stall', 'circle', 'repeat', 'no progress', 'same issue'],
    'review_effectiveness': ['false positive', 'review quality', 'missed issue', 'review catch'],
    'plan_execution': ['plan drift', 'alignment', 'deviat', 'scope change', 'off-plan'],
    'verification_gap': ['verification', 'insufficient test', 'too narrow', 'missed check', 'universal quantifier'],
    'phase_transition': ['phase transition', 'review phase', 'implementation phase', 'polishing', 'two-phase'],
    'scope_management': ['scope', 'over-engineer', 'under-deliver', 'bloat', 'defer'],
}


def _classify_observation(text):
    """将报告观察分类到方法论类别中。"""
    lower = text.lower()
    best_cat = 'general'
    best_score = 0
    for cat, keywords in _CATEGORY_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in lower)
        if score > best_score:
            best_score = score
            best_cat = cat
    return best_cat


def _build_sanitized_issue(session):
    """按照 issue #62 格式构建清理后的 GitHub issue 负载。

    使用受限的方法论分类法——没有报告散文通过。
    返回包含 'title'、'body' 和 'warnings' 键的字典，
    如果没有报告则返回 None。
    警告仅包含类别名称和计数，从不包含匹配的字符串。
    """
    report_obj = session.get('methodology_report', {})
    # 优先使用英文报告；回退到中文
    report = (report_obj or {}).get('en') or (report_obj or {}).get('zh') or ''
    if not report:
        return None

    # 源诊断（仅供参考——不要门控出站）
    source_diagnostics = {}
    if not _is_english_only(report):
        source_diagnostics['non_english'] = 1

    # 从报告结构中提取原始观察和建议
    raw_observations = []
    raw_suggestions = []
    current_section = None

    for line in report.split('\n'):
        stripped = line.strip()
        if stripped.lower().startswith('## observation') or stripped.lower().startswith('## finding'):
            current_section = 'observations'
            continue
        elif stripped.lower().startswith('## suggest'):
            current_section = 'suggestions'
            continue
        elif stripped.startswith('## '):
            current_section = stripped[3:].strip().lower()
            continue

        if current_section == 'observations' and stripped.startswith(('- ', '* ', '1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.')):
            raw_observations.append(stripped.lstrip('-* 0123456789.').strip())
        elif current_section == 'suggestions' and stripped.startswith('|') and not stripped.startswith('|---') and not stripped.startswith('| #'):
            cols = [c.strip() for c in stripped.split('|')[1:-1]]
            if len(cols) >= 2:
                raw_suggestions.append(cols)

    if not raw_observations:
        for line in report.split('\n'):
            stripped = line.strip()
            if stripped and not stripped.startswith('#') and not stripped.startswith('|') and not stripped.startswith('---'):
                raw_observations.append(stripped)

    # 将源级发现记录为诊断（不阻塞）
    for obs in raw_observations:
        violations = _scan_for_forbidden_tokens(obs)
        for cat, count in violations.items():
            source_diagnostics[cat] = source_diagnostics.get(cat, 0) + count

    # 将观察分类到方法论类别中（没有散文通过）
    category_counts = {}
    for obs in raw_observations:
        category = _classify_observation(obs)
        category_counts[category] = category_counts.get(category, 0) + 1

    # 将建议分类到方法论类别中（没有原始文本通过）
    suggestion_categories = {}
    for cols in raw_suggestions:
        combined = ' '.join(cols)
        cat = _classify_observation(combined)
        suggestion_categories[cat] = suggestion_categories.get(cat, 0) + 1

    # 从主要类别构建标题（无报告文本）
    dominant_cat = max(category_counts, key=category_counts.get) if category_counts else 'general'
    title = f"RLCR: {dominant_cat.replace('_', ' ').capitalize()} pattern identified"

    # 仅使用分类法派生的措辞构建 issue #62 正文
    s = session
    # ``current_round`` 是从 0 开始的索引，而不是轮次*计数*。
    # 逐字使用它会对只完成了第 0 轮的会话打印 ``0-round``，
    # 并且对每个其他会话少报一轮。解析器构建的 ``rounds`` 列表
    # 是权威计数——其长度匹配 ``max_disk_round + 1``。
    round_total = len(s.get('rounds') or [])
    body_lines = [
        '## Context\n',
        f'A {round_total}-round RLCR session ended with status: {s["status"]}.',
    ]
    if s.get('ac_total', 0) > 0:
        body_lines.append(f'Acceptance criteria: {s["ac_done"]}/{s["ac_total"]} verified.')
    body_lines.append('')

    body_lines.append('## Observations\n')
    for i, (cat, count) in enumerate(sorted(category_counts.items(), key=lambda x: -x[1]), 1):
        generic_text = _METHODOLOGY_CATEGORIES.get(cat, _METHODOLOGY_CATEGORIES['general'])
        body_lines.append(f'{i}. **{cat.replace("_", " ").capitalize()}** ({count}x): {generic_text}')

    body_lines.append('')
    body_lines.append('## Suggested Improvements\n')
    body_lines.append('| # | Suggestion | Mechanism |')
    body_lines.append('|---|-----------|-----------|')
    if suggestion_categories:
        for i, (cat, count) in enumerate(sorted(suggestion_categories.items(), key=lambda x: -x[1]), 1):
            generic_suggestion = f'Improve {cat.replace("_", " ")} practices'
            mechanism = f'Apply targeted {cat.replace("_", " ")} methodology adjustments ({count} suggestion(s) in this area)'
            body_lines.append(f'| {i} | {generic_suggestion} | {mechanism} |')
    else:
        body_lines.append('| - | No specific suggestions identified | - |')

    body_lines.append('')
    body_lines.append('## Quantitative Summary\n')
    body_lines.append('| Metric | Value |')
    body_lines.append('|--------|-------|')
    # 复用上面为 Context 部分计算的 ``round_total`` 计数——
    # ``s["current_round"]`` 是从 0 开始的索引，因此这里的
    # 原始读取会在下游问题读者依赖的定量摘要表中少报每个
    # 会话（单轮会话为 0，N 轮会话为 N-1）。
    body_lines.append(f'| Total rounds | {round_total} |')
    body_lines.append(f'| Exit reason | {s["status"].capitalize()} |')
    if s.get('ac_total', 0) > 0:
        rate = round(s['ac_done'] / s['ac_total'] * 100) if s['ac_total'] > 0 else 0
        body_lines.append(f'| AC count | {s["ac_total"]} |')
        body_lines.append(f'| Completion rate | {rate}% |')
    body_lines.append(f'| Observation categories | {len(category_counts)} |')
    body_lines.append(f'| Total observations | {sum(category_counts.values())} |')

    body = '\n'.join(body_lines)

    # 出站验证：只有最终生成的标题/正文决定负载是否可以安全
    # 发送。源报告的发现仅供参考，不出站路径不门控。
    outbound_warnings = {}

    final_violations = _scan_for_forbidden_tokens(body)
    for cat, count in final_violations.items():
        outbound_warnings[cat] = outbound_warnings.get(cat, 0) + count

    title_violations = _scan_for_forbidden_tokens(title)
    for cat, count in title_violations.items():
        outbound_warnings[cat] = outbound_warnings.get(cat, 0) + count

    if not _is_english_only(body):
        outbound_warnings['non_english'] = 1

    return {
        'title': title,
        'body': body,
        'warnings': outbound_warnings,
        'source_diagnostics': source_diagnostics,
    }


@app.route('/api/sessions/<session_id>/sanitized-issue')
def api_sanitized_issue(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)
    payload = _build_sanitized_issue(session)
    if not payload:
        abort(404)

    # 出站门控：仅在最终生成的负载有警告时才阻止
    if payload.get('warnings'):
        return jsonify({
            'title': payload['title'],
            'body': '[REDACTED — outbound payload failed validation.]',
            'warnings': payload['warnings'],
            'source_diagnostics': payload.get('source_diagnostics', {}),
            'requires_review': True,
        })

    # 清洁负载——将源诊断作为信息包含
    result = {
        'title': payload['title'],
        'body': payload['body'],
        'warnings': {},
        'source_diagnostics': payload.get('source_diagnostics', {}),
    }
    return jsonify(result)


@app.route('/api/sessions/<session_id>/github-issue', methods=['POST'])
def api_github_issue(session_id):
    session = _get_session(session_id)
    if not session:
        abort(404)

    payload = _build_sanitized_issue(session)
    if not payload:
        return jsonify({'error': 'No methodology report available'}), 400

    # 当存在清理警告时阻止提交并编辑正文
    if payload.get('warnings'):
        return jsonify({
            'error': 'Sanitization check failed. Review the methodology report manually and remove project-specific content before sending.',
            'warnings': payload['warnings'],
            'manual': False,
        }), 400

    title = payload['title']
    body = payload['body']

    # 检查 gh 是否可用
    try:
        subprocess.run(['gh', '--version'], capture_output=True, timeout=5, check=True)
    except (subprocess.SubprocessError, FileNotFoundError):
        return jsonify({
            'error': 'gh CLI not available',
            'title': title,
            'body': body,
            'manual': True,
        }), 400

    try:
        result = subprocess.run(
            ['gh', 'issue', 'create', '--repo', 'PolyArch/humanize',
             '--title', title, '--body', body],
            capture_output=True, text=True, timeout=30, check=True, cwd=PROJECT_DIR,
        )
        url = result.stdout.strip()
        return jsonify({'status': 'created', 'url': url})
    except subprocess.SubprocessError as e:
        return jsonify({
            'error': str(e),
            'title': title,
            'body': body,
            'manual': True,
        }), 500


# --- 每会话 SSE 日志流（按 docs/streaming-protocol.md）---

_LOG_BASENAME_RE = re.compile(
    r"^round-\d+-(?:codex|gemini)-(?:run|review)\.log$"
)

# SSE 生成器内的轮询节奏。结合 64 KiB 快照块大小，
# 这为契约的中位延迟预算提供了充足的余量（正常负载下中位 << 2.0s）。
_SSE_POLL_INTERVAL_SECONDS = 0.25
_SSE_HEARTBEAT_INTERVAL_SECONDS = 15.0

# LogStream 实例的进程生命周期注册表。注册表实现位于
# log_streamer.py 中，以便无需 Flask 导入路径即可测试；
# 参见那里的文档字符串了解正确性原理（Codex 第 2 轮审查
# 发现了一个重连 bug，其中每请求的 LogStream 构造丢失了
# 保留的历史）。
_log_stream_registry = log_streamer.LogStreamRegistry()
# 每缓存目录日志监视器的引用计数注册表。每个活跃的 SSE
# 生成器在入口调用 _acquire_cache_watcher，在其 finally 块中
# 调用匹配的 _release_cache_watcher，因此在最后一个客户端
# 断开连接时观察者（及其 inotify 句柄）被拆除。修复前的
# 实现只启动监视器而从不停止它们，因此长时间运行的仪表板
# 进程为用户浏览过的每个唯一缓存目录泄漏一个监视器线程。
_cache_watchers = {}
_cache_watcher_refcounts = {}
_cache_watchers_lock = threading.Lock()


def _sse_frame(event):
    """将一个事件字典渲染为契约中的 SSE 线路格式。"""
    payload = {k: v for k, v in event.items() if k != 'id'}
    return (
        f"event: {event['type']}\n"
        f"id: {event['id']}\n"
        f"data: {json.dumps(payload, separators=(',', ':'))}\n\n"
    )


def _is_terminal_status(status):
    return status not in (None, '', 'active', 'analyzing', 'finalizing', 'unknown')


# RLCR 循环产生的终端状态标记文件名。只有真正的终端标记
# 属于此处：SSE 生成器在其中任何一个出现时立即关闭流，
# 仪表板仍将 ``methodology-analysis-state.md`` /
# ``finalize-state.md`` 视为运行中（``analyzing`` /
# ``finalizing`` 状态，仍可取消，仍输出实时日志字节）。
# 将这些标记包含在此列表中曾导致实时日志窗格在会话进入
# 最终化或分析时立即 EOF，因此最终化阶段/方法论报告输出
# 永远不会到达浏览器。该列表必须与上面的 ``_is_terminal_status``
# 保持同步。
_TERMINAL_STATE_FILES = (
    'complete-state.md',
    'cancel-state.md',
    'stop-state.md',
    'maxiter-state.md',
    'unexpected-state.md',
)


def _session_is_terminal_cheap(session_id):
    """SSE EOF 检查的快速路径。

    250 毫秒的 SSE 轮询循环过去每个 tick 都调用
    ``_get_session(session_id, force_refresh=True)``，
    这会重新运行完整的 parse_session 管道（重新扫描每个轮次
    文件、解析目标跟踪器、重新读取方法论报告，并为 git-status
    摘要调用 ``git`` 一两次）。在有许多轮次和多个活跃 SSE
    客户端的长会话上，这很快成为瓶颈。

    终止状态可以很容易地从磁盘标记检测：每当 state.md 以外的
    任何 *-state.md 文件存在时，循环已停止写入日志。直接检查
    这一点，以便热循环不会拖拽完整的解析器。假阴性只是将 EOF
    推迟一个轮询周期；它们不会损坏流，因为文件系统监视器
    仍然驱动每个追加操作。
    """
    session_dir = _get_session_dir(session_id)
    if not session_dir:
        # 目录消失或被重命名——视为终端，以便 SSE 生成器干净地关闭。
        return True
    for name in _TERMINAL_STATE_FILES:
        if os.path.isfile(os.path.join(session_dir, name)):
            return True
    return False


def _acquire_cache_watcher(cache_dir):
    """为一个活跃的 SSE 流保留缓存监视器。

    每个缓存目录最多启动一个 CacheLogWatcher，并增加每目录
    的引用计数，以便同一会话上的并发 SSE 客户端共享观察者。
    与 :func:`_release_cache_watcher` 配对，后者在最后一个
    客户端释放时停止监视器。监视器的回调内联运行匹配的
    LogStream 的轮询，因此文件系统事件除了 SSE 处理程序自己的
    250 毫秒轮询循环外还驱动流。启动时尽最大努力：如果缓存
    目录尚不存在，监视器不会启动，SSE 处理程序继续通过其
    轮询循环驱动一切。
    """
    with _cache_watchers_lock:
        _cache_watcher_refcounts[cache_dir] = (
            _cache_watcher_refcounts.get(cache_dir, 0) + 1
        )
        if cache_dir in _cache_watchers:
            return

        def callback(filepath):
            basename = os.path.basename(filepath)
            for stream in _log_stream_registry.streams_in_cache_dir(cache_dir, basename):
                try:
                    stream.poll()
                except Exception:
                    # 监视器回调不得使观察者线程崩溃。
                    pass

        watcher = CacheLogWatcher(cache_dir, callback)
        if watcher.start():
            _cache_watchers[cache_dir] = watcher


def _release_cache_watcher(cache_dir):
    """释放一个保留；在最终释放时停止监视器。

    从 SSE 生成器的 ``finally`` 块调用，以便在最后一个客户端
    断开连接时（正常 EOF、连接关闭或服务器关闭）拆除观察者。
    没有这种配对，观察者线程和 inotify 句柄会比用户浏览过的
    每个会话存活更长时间，这会在长时间运行的仪表板进程中
    耗尽 ``fs.inotify.max_user_watches``。
    """
    with _cache_watchers_lock:
        remaining = _cache_watcher_refcounts.get(cache_dir, 0) - 1
        if remaining <= 0:
            _cache_watcher_refcounts.pop(cache_dir, None)
            watcher = _cache_watchers.pop(cache_dir, None)
        else:
            _cache_watcher_refcounts[cache_dir] = remaining
            watcher = None
    if watcher is not None:
        try:
            watcher.stop()
        except Exception:
            # 尽最大努力清理：失败的观察者停止不得使触发
            # 释放的请求崩溃。
            pass


def _acquire_log_stream(session_id, basename):
    """获取 ``(session_id, basename)`` 的共享 LogStream。

    增加注册表引用计数，以便调用者拥有一个释放。
    调用者（SSE 路由）必须将其与 :func:`_release_log_stream`
    和 :func:`_acquire_cache_watcher` / :func:`_release_cache_watcher`
    配对在生成器主体周围，以便流 + 监视器的生命周期跟踪
    活跃的 SSE 消费者而不是进程生命周期。没有释放，注册表
    会为用户浏览过的每个会话保留 256 事件双端队列（通常是
    大的 base64 负载）。
    """
    cache_dir = rlcr_sources.cache_dir_for_session(PROJECT_DIR, session_id)
    stream = _log_stream_registry.acquire(cache_dir, session_id, basename)
    return stream


def _release_log_stream(session_id, basename):
    """释放一个 :func:`_acquire_log_stream` 保留。"""
    _log_stream_registry.release(session_id, basename)


@app.route('/api/sessions/<session_id>/logs/<basename>')
def stream_session_log(session_id, basename):
    """按流式协议的每会话、每文件 SSE 流。

    实现冻结在 docs/streaming-protocol.md 中的
    snapshot+append+resync+eof 事件序列，包括具有记录的
    256 事件保留的 Last-Event-Id 重连。远程模式认证由
    @app.before_request 中间件强制执行：在远程模式下，请求
    必须携带有效的 bearer 令牌（fetch 风格调用的
    `Authorization: Bearer` 头，SSE EventSource 客户端按
    DEC-4 的 `?token=` 查询参数）；缺失或无效的令牌返回 401。
    本地主机绑定的部署跳过认证检查。
    """
    if not _LOG_BASENAME_RE.match(basename):
        abort(400)
    session_dir = _get_session_dir(session_id)
    if session_dir is None:
        abort(404)

    stream = _acquire_log_stream(session_id, basename)
    # 预先解析缓存目录一次，以便生成器的监视器获取/释放对
    # 引用相同的键。注册表辅助程序内部派生它；在此重新派生
    # 以便缓存监视器引用计数键与流注册表的匹配。
    cache_dir = rlcr_sources.cache_dir_for_session(PROJECT_DIR, session_id)

    last_event_id = 0
    raw_id = request.headers.get('Last-Event-Id')
    if raw_id:
        try:
            last_event_id = int(raw_id)
        except ValueError:
            last_event_id = 0

    def generate():
        # 为此流的生命周期保留每缓存目录监视器。下面 finally
        # 块中的配对释放是让长时间运行的仪表板实例在客户端
        # 断开连接后停止泄漏 inotify 句柄（用户浏览的每个
        # 不同会话一个）的原因。在路由入口获取的日志流引用
        # 计数也在此处释放，以便在最后一个客户端看到 EOF 后
        # 可以释放其保留双端队列。
        _acquire_cache_watcher(cache_dir)
        try:
            client_last_id = last_event_id

            # 初始事件交付：如果客户端有 Last-Event-Id 则重放，
            # 否则新鲜快照。路由永远不会落入会将文件正文作为
            # 从偏移 0 的 `append` 发出的轮询。
            if client_last_id > 0:
                replayed, in_window = stream.replay(client_last_id)
                for event in replayed:
                    yield _sse_frame(event)
                    client_last_id = event['id']
                if not in_window:
                    for event in stream.snapshot():
                        yield _sse_frame(event)
                        client_last_id = event['id']
            else:
                for event in stream.snapshot():
                    yield _sse_frame(event)
                    client_last_id = event['id']

            # 稳态循环。驱动 poll()（如果缓存监视器或其他并发
            # 处理程序已经轮询过，可能是空操作），然后转发任何
            # 比此客户端已发送的更新的保留事件。使用双端队列
            # 作为事实来源意味着同一流上的多个并发 SSE 客户端
            # 都接收每个事件而不会在 _offset 上竞争。
            last_heartbeat = time.time()
            while True:
                stream.poll()
                catchup, in_window = stream.replay(client_last_id)
                for event in catchup:
                    yield _sse_frame(event)
                    client_last_id = event['id']
                if not in_window:
                    for event in stream.snapshot():
                        yield _sse_frame(event)
                        client_last_id = event['id']

                # 廉价的磁盘探测，而不是在每个 SSE tick 上进行
                # 完整的 parse_session。避免为了决定是否发出 EOF
                # 而重新扫描轮次文件、目标跟踪器和 `git status`
                # 子进程。
                if _session_is_terminal_cheap(session_id):
                    for event in stream.mark_eof():
                        yield _sse_frame(event)
                        client_last_id = event['id']
                    return

                now = time.time()
                if now - last_heartbeat >= _SSE_HEARTBEAT_INTERVAL_SECONDS and not catchup:
                    yield ": keepalive\n\n"
                    last_heartbeat = now
                time.sleep(_SSE_POLL_INTERVAL_SECONDS)
        finally:
            # 在正常 EOF 返回、GeneratorExit（客户端断开连接）
            # 或任何传播的异常时运行，因此引用计数始终平衡
            # 之前的获取。日志流释放在其最终客户端断开连接
            # 且 EOF 已经交付后驱逐流的保留双端队列；没有当前
            # 客户端的活跃会话保持驻留，以便重连获得流式契约
            # 要求的重放窗口。
            _release_cache_watcher(cache_dir)
            _release_log_stream(session_id, basename)

    response = Response(generate(), mimetype='text/event-stream')
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'
    return response


# --- WebSocket ---

@sock.route('/ws')
def websocket(ws):
    # T11 / DEC-4：WebSocket 传输仅限于本地主机。在远程模式
    # （host != 127.0.0.1）下，仪表板必须使用 SSE 进行日志流
    # （通过 HTTPS 带 `?token=` 认证），因此 WebSocket 控制
    # 通道被完全拒绝。浏览器无法在 WebSocket 升级上发送任意
    # 认证头，这是 DEC-4 背后的根本原因。
    if not _is_localhost_bind():
        try:
            ws.close(reason='WebSocket transport disabled in remote mode')
        except Exception:
            pass
        return

    # 跨域 WebSocket 拒绝。应用的 HTTP 端通过
    # `_enforce_csrf_protection` 门控变更路由，但浏览器乐于
    # 让任意页面打开到 ws://localhost:<port>/ws 的 WebSocket，
    # 服务器没有 Origin 检查。通过该连接的 `cancel_session`
    # 消息会在零认证提示下杀死活跃循环。复用相同的请求主机
    # 匹配器，以便本地主机仪表板自己的 Origin 继续工作，
    # 而敌对 Origin（同一浏览器中其他项目提供的页面）在
    # 发送任何内容之前被关闭。
    origin = request.headers.get('Origin', '').strip()
    if origin and not _origin_matches_request(origin):
        try:
            ws.close(reason='cross-origin WebSocket rejected')
        except Exception:
            pass
        return

    with _ws_lock:
        _ws_clients.add(ws)
    try:
        while True:
            data = ws.receive(timeout=60)
            if data is None:
                continue
            try:
                msg = json.loads(data)
                if msg.get('type') == 'cancel_session':
                    sid = msg.get('session_id', '')
                    if sid:
                        session = _get_session(sid)
                        if session and session.get('status') in _CANCELLABLE_STATUSES:
                            # 通过会话范围的辅助程序而不是项目全局
                            # 取消进行路由。匹配 REST 路由的 --force
                            # 处理，以便最终化的会话可以被取消。
                            cancel_script = _find_session_cancel_script()
                            if cancel_script:
                                # 镜像 REST 路由：显式传递 --project
                                # 以便辅助程序不会回退到从启动 shell
                                # 继承的杂散 CLAUDE_PROJECT_DIR。
                                helper_args = [
                                    cancel_script,
                                    '--project', PROJECT_DIR,
                                    '--session-id', sid,
                                ]
                                if session.get('status') == 'finalizing':
                                    helper_args.append('--force')
                                # 匹配 REST 取消路由：在使缓存失效
                                # 之前要求零退出代码。非零退出意味着
                                # 辅助程序实际上没有取消会话，因此
                                # 刷新仪表板会掩盖失败。
                                try:
                                    subprocess.run(
                                        helper_args,
                                        cwd=PROJECT_DIR, timeout=30,
                                        check=True,
                                    )
                                except subprocess.SubprocessError:
                                    pass
                                else:
                                    _invalidate_cache(sid)
            except (json.JSONDecodeError, KeyError):
                pass
    except Exception:
        pass
    finally:
        with _ws_lock:
            _ws_clients.discard(ws)


# --- 主程序 ---

def _resolve_auth_token(cli_token):
    """从 CLI 标志或环境变量中选择有效的 bearer 令牌。"""
    if cli_token:
        return cli_token
    return os.environ.get('HUMANIZE_VIZ_TOKEN', '').strip()


def main():
    parser = argparse.ArgumentParser(description='Humanize Viz Dashboard Server')
    parser.add_argument('--host', type=str, default='127.0.0.1',
                        help='Bind address (default: 127.0.0.1)')
    parser.add_argument('--port', type=int, default=18000,
                        help='Bind port (default: 18000)')
    parser.add_argument('--project', type=str, default='.',
                        help='Project root for the dashboard (CLI-fixed per DEC-3)')
    parser.add_argument('--static', type=str, default='.',
                        help='Directory containing the SPA static assets')
    parser.add_argument('--auth-token', type=str, default='',
                        help='Bearer token required for remote-mode access. '
                             'May also be supplied via HUMANIZE_VIZ_TOKEN env var. '
                             'Required when --host is not a loopback address.')
    parser.add_argument('--trust-proxy', action='store_true', default=False,
                        help='Acknowledge that a TLS-terminating reverse proxy '
                             'is in front of this server. Required for '
                             'non-loopback binds because the SSE stream '
                             'transmits the bearer token as a ?token= query '
                             'parameter, which would leak in cleartext over '
                             'plain HTTP. May also be enabled via the '
                             'HUMANIZE_VIZ_TRUST_PROXY=1 env var.')
    args = parser.parse_args()

    global PROJECT_DIR, STATIC_DIR, BIND_HOST, AUTH_TOKEN, TRUST_PROXY, _watcher
    PROJECT_DIR = os.path.abspath(args.project)
    STATIC_DIR = os.path.abspath(args.static)
    BIND_HOST = args.host
    AUTH_TOKEN = _resolve_auth_token(args.auth_token)
    TRUST_PROXY = args.trust_proxy or os.environ.get(
        'HUMANIZE_VIZ_TRUST_PROXY', ''
    ).strip() in ('1', 'true', 'yes')

    if not _is_localhost_bind() and not AUTH_TOKEN:
        print(
            "Error: binding to a non-localhost host requires --auth-token "
            "(or HUMANIZE_VIZ_TOKEN env var). Refusing to start a remote "
            "server without authentication.",
            file=sys.stderr,
        )
        sys.exit(2)

    # 纯 HTTP Flask + ?token= bearer 认证在回环上是安全的
    # （没有任何东西离开主机），但一旦绑定可从外部访问就会
    # 以明文泄漏令牌。在接受非回环绑定之前，要求操作员
    # 明确认可服务器前面有 TLS 终止反向代理。该标志/环境
    # 变量是承重声明：没有它，我们宁愿拒绝启动也不愿分发
    # 不安全的仪表板 URL。TRUST_PROXY 在上面解析，还驱动
    # CSRF 端口匹配器的 X-Forwarded-Proto 处理。
    if not _is_localhost_bind() and not TRUST_PROXY:
        print(
            "Error: binding to a non-localhost host requires a TLS-terminating\n"
            "reverse proxy so the ?token= query parameter is never transmitted\n"
            "in cleartext. Pass --trust-proxy (or HUMANIZE_VIZ_TRUST_PROXY=1)\n"
            "to acknowledge that an HTTPS reverse proxy (nginx / caddy / etc.)\n"
            "is in front of this server.",
            file=sys.stderr,
        )
        sys.exit(2)

    # 启动文件监视器
    _watcher = SessionWatcher(PROJECT_DIR, broadcast_message)
    _watcher.start()

    # 预填充缓存
    list_sessions(PROJECT_DIR)

    visible_host = BIND_HOST if not _is_localhost_bind() else 'localhost'
    print(f"Humanize Viz server starting on http://{visible_host}:{args.port}")
    print(f"Project: {PROJECT_DIR}")
    print(f"Static:  {STATIC_DIR}")
    if AUTH_TOKEN:
        print("Remote mode: token authentication enabled.")
    elif _is_localhost_bind():
        print("Local mode: authentication disabled (loopback bind).")

    app.run(host=BIND_HOST, port=args.port, debug=False)


if __name__ == '__main__':
    main()
