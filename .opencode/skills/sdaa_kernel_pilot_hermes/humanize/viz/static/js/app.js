/* 主 SPA — 路由、WebSocket、令牌传播、页面渲染 */

let ws = null, wsRetryDelay = 1000
const WS_MAX_RETRY = 30000
let _sortCol = 'session_id', _sortAsc = false
const _liveLogPanes = new Map() // sessionId -> { eventSource, element, basename } 映射

// ─── 认证令牌传播（T11-frontend） ───
//
// 每次页面加载时解析一次。优先级顺序：
//   1. 文档 URL 中的 ?token=<tok>（一次性使用，消费后从
//      可见 URL 中移除，但保留在 sessionStorage 中，以便
//      刷新页面时无需重新输入）。
//   2. URL hash 中的 #token=<tok>（同上；支持偏好使用 hash
//      形式以在共享屏幕上增强安全性的客户端）。
//   3. sessionStorage 中缓存的上次访问令牌。
//   4. 静态 index.html 中预置的 <meta name="humanize-viz-token"
//      content="...">（不常见；适用于 kiosk 部署场景）。
//
// 在 localhost 部署中服务器完全跳过认证，因此缺少令牌是正常的，
// api() 将不会附加认证头。
function _resolveAuthToken() {
    let token = ''
    try {
        const url = new URL(location.href)
        const queryToken = url.searchParams.get('token')
        if (queryToken) {
            token = queryToken
            url.searchParams.delete('token')
            history.replaceState(null, '', url.toString())
        }
    } catch (_) {}

    if (!token && location.hash.includes('token=')) {
        const m = location.hash.match(/(?:^|[#&])token=([^&]+)/)
        if (m) {
            token = decodeURIComponent(m[1])
            const newHash = location.hash.replace(/(^|[#&])token=[^&]+&?/, '$1').replace(/&$/, '')
            history.replaceState(null, '', location.pathname + location.search + newHash)
        }
    }

    if (!token) {
        token = sessionStorage.getItem('humanize-viz-token') || ''
    }

    if (!token) {
        const meta = document.querySelector('meta[name="humanize-viz-token"]')
        if (meta) token = meta.getAttribute('content') || ''
    }

    if (token) {
        sessionStorage.setItem('humanize-viz-token', token)
    }
    return token
}

const _authToken = _resolveAuthToken()

function _withToken(url) {
    if (!_authToken) return url
    const sep = url.includes('?') ? '&' : '?'
    return `${url}${sep}token=${encodeURIComponent(_authToken)}`
}

// ─── WebSocket（仅限 localhost 粗粒度事件；远程模式在服务器端
// 按 DEC-4 拒绝） ───
//
// 通过是否存在已解析的认证令牌来检测远程模式：
// localhost 部署不会设置令牌（服务器不强制认证），
// 因此令牌的存在意味着仪表盘正在与拒绝 WS 的非回环服务器通信。
// 在这种情况下，首页会回退到按固定间隔轮询 /api/sessions，
// 以在 UI 中显示 WAITING -> 实时转换和 EOF 转换。
const _isRemoteMode = !!_authToken

function connectWebSocket() {
    if (_isRemoteMode) {
        // 远程模式下不存在粗粒度会话列表通道（按 DEC-4）；
        // 首页路由轮询循环负责处理刷新。
        return
    }
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'
    const wsUrl = _withToken(`${proto}//${location.host}/ws`)
    ws = new WebSocket(wsUrl)
    ws.onopen = () => { wsRetryDelay = 1000 }
    ws.onmessage = (e) => {
        try {
            const msg = JSON.parse(e.data)
            const route = parseRoute()
            // 按事件类型进行有针对性的子树刷新 — 避免之前每次文件
            // 写入时全页重建导致的闪烁。仅修改受影响的 DOM 子树；
            // 实时日志 <pre>（SSE）和页面骨架不会在此重建。
            if (route.page === 'home') {
                _scheduleHomeRefresh()
            } else if (route.page === 'session' && route.id === msg.session_id) {
                _scheduleSessionPartialRefresh(route.id, msg.type)
            }
        } catch (_) {}
    }
    ws.onclose = () => {
        setTimeout(() => {
            wsRetryDelay = Math.min(wsRetryDelay * 2, WS_MAX_RETRY)
            connectWebSocket()
        }, wsRetryDelay)
    }
}

// ─── 有针对性的 WS 推送刷新 ───
//
// 与轮询或在每次 watcher 广播时重新渲染整个页面不同，
// WS onmessage 路径按事件类型分派到最小的变更子树：
//   - 首页：仅重建活跃/已完成的卡片列表。
//   - 会话详情：按需重新运行 renderPipeline / renderSessionSidebar /
//     renderGoalBar，不触碰 #session-log-container 或其 EventSource。
//
// 每个面板约 500ms 的尾部去抖合并突发事件
// （state.md + goal-tracker.md + round-N-summary.md 通常在同一秒内到达），
// 使读者看到一次更新而非三次。
const _PARTIAL_DEBOUNCE_MS = 500

let _homeRefreshHandle = null
function _scheduleHomeRefresh() {
    if (_homeRefreshHandle != null) return
    _homeRefreshHandle = setTimeout(() => {
        _homeRefreshHandle = null
        if (parseRoute().page === 'home') _refreshHomeCards()
    }, _PARTIAL_DEBOUNCE_MS)
}

let _sessionRefreshHandle = null
let _pendingSessionRefreshKinds = new Set()
function _scheduleSessionPartialRefresh(sessionId, eventType) {
    // 合并需要执行的更新类型，使得混合 round_added + session_updated
    // 的突发情况只触发一次刷新，同时更新两个子树。
    if (eventType) _pendingSessionRefreshKinds.add(eventType)
    if (_sessionRefreshHandle != null) return
    _sessionRefreshHandle = setTimeout(async () => {
        _sessionRefreshHandle = null
        const kinds = _pendingSessionRefreshKinds
        _pendingSessionRefreshKinds = new Set()
        const route = parseRoute()
        if (route.page !== 'session' || route.id !== sessionId) return
        await _refreshSessionPartial(sessionId, kinds)
    }, _PARTIAL_DEBOUNCE_MS)
}

// 基于差异的首页会话区域刷新。只有渲染内容实际发生变化的卡片
// 会被替换 outerHTML；未变化的卡片完全不动，因此不会出现
// 重新渲染、重新动画或可观察到的"闪烁"。当会话在活跃和已完成
// 之间转换时，按需创建或拆除区域骨架（标签 + 列表容器），
// 但只影响相关区域 — 另一区域中的现有卡片不会移动。
async function _refreshHomeCards() {
    const wrap = document.getElementById('home-sessions')
    if (!wrap) return
    const sessions = await api('/api/sessions').catch(() => null)
    if (sessions == null) return
    if (parseRoute().page !== 'home') return

    // 任一方向的空状态转换都会回退到完整重建
    // （罕见：最多在第一个会话到达或最后一个会话被移除时触发一次）。
    // 在运行中的循环期间不会触发。
    const currentlyEmpty = wrap.querySelector('.empty') != null
    if (sessions.length === 0) {
        if (!currentlyEmpty) wrap.innerHTML = _buildHomeSessionsHtml(sessions)
        return
    }
    if (currentlyEmpty) {
        wrap.innerHTML = _buildHomeSessionsHtml(sessions)
        return
    }

    const active = sessions.filter(s => ['active', 'analyzing', 'finalizing'].includes(s.status))
    const finished = sessions.filter(s => !['active', 'analyzing', 'finalizing'].includes(s.status))

    _applyHomeSection(wrap, 'active', active, t('home.active'), 'session-grid', activeSessionPane)
    _applyHomeSection(wrap, 'completed', finished, t('home.completed'), 'session-grid', sessionCard)
}

// 确保一个区域（标签 + 列表容器）与给定的会话列表匹配。
// 卡片通过 data-session-id 进行差异更新：
//   - 保持不变（相同 HTML）-> 不动
//   - 内容已更改            -> 替换该卡片的 outerHTML
//   - 列表中出现新会话      -> 追加
//   - 会话从列表中移除      -> 删除
// 区域标签 + 列表容器在列表变为非空时延迟创建，
// 在列表回到空时移除。
function _applyHomeSection(wrap, sectionKey, list, label, containerClass, cardFn) {
    const listSel = `[data-home-section="${sectionKey}"]`
    let container = wrap.querySelector(listSel)
    const labelSel = `[data-home-section-label="${sectionKey}"]`
    let labelEl = wrap.querySelector(labelSel)

    if (list.length === 0) {
        if (labelEl) labelEl.remove()
        if (container) container.remove()
        return
    }

    if (!container) {
        // 创建标签 + 容器并按正确顺序放置。
        // 活跃区域在前；已完成区域在后。
        const labelHtml = `<div class="eyebrow-rule${sectionKey === 'completed' ? ' completed' : ''}" data-home-section-label="${sectionKey}">${label}</div>`
        const containerHtml = `<div class="${containerClass}" data-home-section="${sectionKey}"></div>`
        if (sectionKey === 'active') {
            wrap.insertAdjacentHTML('afterbegin', labelHtml + containerHtml)
        } else {
            wrap.insertAdjacentHTML('beforeend', labelHtml + containerHtml)
        }
        container = wrap.querySelector(listSel)
    }

    // 按会话 id 索引现有卡片。
    const existing = new Map()
    for (const el of container.querySelectorAll('.session-card[data-session-id]')) {
        existing.set(el.dataset.sessionId, el)
    }

    const seen = new Set()
    let cursor = null
    for (const s of list) {
        seen.add(s.id)
        const html = cardFn(s).trim()
        const el = existing.get(s.id)
        if (el) {
            // 比较渲染后的 HTML；如果相同则跳过。
            if (el.outerHTML.trim() !== html) {
                const tmp = document.createElement('div')
                tmp.innerHTML = html
                el.replaceWith(tmp.firstElementChild)
            }
            cursor = container.querySelector(`.session-card[data-session-id="${CSS.escape(s.id)}"]`)
        } else {
            // 在当前位置追加新卡片。
            const tmp = document.createElement('div')
            tmp.innerHTML = html
            const node = tmp.firstElementChild
            node.classList.add('js-card-new')
            if (cursor && cursor.nextSibling) {
                container.insertBefore(node, cursor.nextSibling)
            } else {
                container.appendChild(node)
            }
            cursor = node
        }
    }

    // 移除不再属于此区域的会话对应的卡片。
    for (const [id, el] of existing) {
        if (!seen.has(id)) el.remove()
    }
}

// 有针对性的会话详情刷新。仅重新运行事件类型集合所暗示的子树，
// 其余 DOM（特别是实时日志 <pre> 及其 EventSource）保持不变。
async function _refreshSessionPartial(sessionId, kinds) {
    const session = await api(`/api/sessions/${sessionId}`)
    if (!session) return
    // 路由变更竞态保护：上面的 fetch 是异步的，因此在响应回来时
    // 用户可能已导航到另一个会话或路由。检查 DOM 骨架和当前路由
    // 可防止我们将过时数据写入错误的页面。
    const route = parseRoute()
    if (route.page !== 'session' || route.id !== sessionId) return
    const layout = document.querySelector(`.detail-layout[data-session-id="${CSS.escape(sessionId)}"]`)
    if (!layout) return
    // Pipeline 更新对每种会话范围的事件类型都会运行，
    // 包括 session_updated：review-result.md 的写入会翻转
    // 现有节点的裁决结果，需要重新绘制该节点的点/徽章。
    // 增量更新器对裁决结果和活跃标志未改变的轮次是空操作，
    // 因此无条件运行的成本很低。
    const wantPipeline = kinds.has('round_added') || kinds.has('session_updated') || kinds.has('session_finished')
    const wantSidebar  = kinds.has('round_added') || kinds.has('session_updated') || kinds.has('session_finished')
    const wantGoalBar  = kinds.has('round_added') || kinds.has('session_updated') || kinds.has('session_finished')
    window._currentSession = session
    if (wantPipeline) {
        const root = document.getElementById('pipeline-root')
        if (root) {
            // 增量更新保留用户的缩放/平移状态，仅添加/修改
            // 发生变化的特定节点。首次进入时仍使用完整的
            // renderPipeline，因为它还需要设置视口和拖拽监听器；
            // 此有针对性的路径假设这些已经存在。
            if (typeof window._updatePipelineIncremental === 'function') {
                window._updatePipelineIncremental(root, session)
            } else {
                renderPipeline(root, session)
            }
        }
    }
    if (wantSidebar) renderSessionSidebar(session)
    if (wantGoalBar) renderGoalBar(session)
    // 保持布局模式同步（例如会话完成 -> 隐藏日志行），
    // 并让 _ensureSessionLogPane 在新轮次开始时幂等地
    // 推进到更新的缓存日志文件名。
    _applyDetailLayoutMode(session)
    _ensureSessionLogPane(session)
    const cancelBtn = document.getElementById('ops-cancel')
    const CANCELLABLE = ['active', 'analyzing', 'finalizing']
    if (cancelBtn) cancelBtn.style.display = CANCELLABLE.includes(session.status) ? '' : 'none'
}

// 远程模式元数据轮询。在 localhost 模式下 WebSocket 承载
// watcher 事件，因此无需在其之上进行轮询。在远程模式下，
// WS 在服务器端被拒绝（DEC-4），因此如果没有回退机制，
// 卡片计数器、Pipeline 节点和方法论状态都会冻结在页面加载时的状态。
// 此轮询使用与 WS 路径相同的有针对性刷新辅助函数
// （_refreshHomeCards / _refreshSessionPartial），因此它不会
// 重建页面 — 只更新相同的就地子树，不触碰 SSE 日志面板。
const _REMOTE_POLL_INTERVAL_MS = 10000
let _remotePollHandle = null
let _remotePollRoute = null

function _startRemotePolling() {
    if (!_isRemoteMode) return
    if (_remotePollHandle != null) return
    _remotePollHandle = setInterval(() => {
        const route = parseRoute()
        _remotePollRoute = route
        if (route.page === 'home') {
            _refreshHomeCards()
        } else if (route.page === 'session') {
            // 注入一个合成的 "session_updated" 类型，使刷新
            // 运行 pipeline + 侧边栏 + 目标栏 + 日志面板
            // — 与 WS 路径在追赶时的行为一致。
            _scheduleSessionPartialRefresh(route.id, 'session_updated')
        }
    }, _REMOTE_POLL_INTERVAL_MS)
}

// 保留用于 renderCurrentRoute / toggleTheme 中的清理路径。
// localhost 模式不轮询，因此这些对常见路径是空操作；
// 远程模式通过 _stopRemotePolling 在路由变更时停止。
function _stopHomePolling() {}
function _stopSessionPolling() {}
function _stopRemotePolling() {
    if (_remotePollHandle != null) {
        clearInterval(_remotePollHandle)
        _remotePollHandle = null
    }
}

// ─── 路由 ───
function parseRoute() {
    const h = location.hash || '#/'
    if (h === '#/' || h === '#') return { page: 'home' }
    let m = h.match(/^#\/session\/([^/]+)\/analysis$/)
    if (m) return { page: 'analysis', id: m[1] }
    m = h.match(/^#\/session\/([^/]+)$/)
    if (m) return { page: 'session', id: m[1] }
    if (h === '#/analytics') return { page: 'analytics' }
    return { page: 'home' }
}

function navigate(hash) { location.hash = hash }

window.renderCurrentRoute = function() {
    const route = parseRoute()
    const main = document.getElementById('main-content')
    main.innerHTML = ''
    updateTopbar(route)
    // 路由变更时始终拆除实时 EventSource 连接。
    // 新路由的渲染会在需要时挂载新的面板
    // （会话详情页面对活跃会话就是如此）。如果没有这一步，
    // 来自之前会话页面的残留 SSE 流会持续在后台访问服务器。
    _teardownAllLivePanes()
    if (route.page !== 'home') _stopHomePolling()
    // 离开会话/分析路由时停止所有活跃的会话轮询循环，
    // 以避免持续重新渲染用户已离开的页面。会话轮询辅助函数
    // 也会在其目标 id 不再匹配路由时自动停止，但在此处停止
    // 可以更干净地处理路由类型变更的情况。
    if (route.page !== 'session' && route.page !== 'analysis') {
        _stopSessionPolling()
    }
    switch (route.page) {
        case 'home': renderHome(); break
        case 'session': renderSession(route.id); break
        case 'analysis': renderAnalysis(route.id); break
        case 'analytics': renderAnalytics(); break
        default: renderHome()
    }
}

window.addEventListener('hashchange', window.renderCurrentRoute)

// ─── 顶部栏 ───
function updateTopbar(route) {
    const left = document.getElementById('topbar-left')
    const titleEl = document.getElementById('topbar-title')
    const themeBtn = document.getElementById('theme-btn')
    const analyticsLink = document.getElementById('analytics-link')
    const opsContainer = document.getElementById('ops-dropdown-container')

    // 左侧区域：始终显示 logo（可点击回到首页），子页面上还显示返回按钮
    if (route.page === 'home') {
        left.innerHTML = `
            <a class="topbar-logo" href="#/" style="text-decoration:none">
                <span class="logo-mark">⬡</span>
                <span class="logo-text">${t('app.title')}</span>
            </a>`
        titleEl.textContent = ''
    } else {
        left.innerHTML = `
            <a class="topbar-back" href="#/">${t('nav.back')}</a>
            <a class="topbar-logo" href="#/" style="text-decoration:none">
                <span class="logo-mark">⬡</span>
                <span class="logo-text">${t('app.title')}</span>
            </a>`
        titleEl.textContent = route.id || ''
    }

    // 右侧区域
    if (analyticsLink) analyticsLink.textContent = t('nav.analytics')
    if (themeBtn) themeBtn.textContent = document.documentElement.getAttribute('data-theme') === 'dark' ? '☀' : '☾'

    // 操作下拉菜单 — 仅在会话/分析页面显示
    if (opsContainer) {
        opsContainer.style.display = (route.page === 'session' || route.page === 'analysis') ? '' : 'none'
    }

    // 填充操作菜单标签
    const labels = { 'ops-plan': 'ops.view_plan', 'ops-analysis': 'ops.analysis', 'ops-preview-issue': 'ops.preview_issue', 'ops-export-md': 'ops.export_md', 'ops-export-pdf': 'ops.export_pdf', 'ops-cancel': 'ops.cancel' }
    for (const [id, key] of Object.entries(labels)) {
        const el = document.getElementById(id)
        if (el) el.textContent = t(key)
    }
}

// ─── 主题 ───
function initTheme() {
    const saved = localStorage.getItem('humanize-viz-theme')
    const theme = (saved === 'dark' || saved === 'light') ? saved : 'dark'
    document.documentElement.setAttribute('data-theme', theme)
    if (saved !== theme) localStorage.setItem('humanize-viz-theme', theme)
}

function toggleTheme() {
    const cur = document.documentElement.getAttribute('data-theme')
    const next = cur === 'dark' ? 'light' : 'dark'
    document.documentElement.setAttribute('data-theme', next)
    localStorage.setItem('humanize-viz-theme', next)
    // 主题变量通过基于 [data-theme] 的 CSS 自定义属性声明，
    // 因此切换属性足以让所有通过 CSS 变量设置样式的路由更新绘制
    // （首页卡片、会话详情的 pipeline + 侧边栏 + 日志面板）。
    // 不需要重建 DOM — pipeline 缩放/平移、打开的弹出面板（如有）、
    // 实时日志 <pre> + EventSource 以及日志面板的折叠状态
    // 都能在切换中保留。
    const btn = document.getElementById('theme-btn')
    if (btn) btn.textContent = next === 'dark' ? '☀' : '☾'
    // 分析页面是唯一的例外：图表通过 getComputedStyle 读取
    // CSS 变量并在渲染时将颜色固化到 SVG 中，因此屏幕上的图表
    // 不会在属性翻转时重新绘制。仅重新渲染该路由；其他路由保持不变。
    if (parseRoute().page === 'analytics') {
        renderAnalytics()
    }
}

// ─── API ───
async function api(url) {
    const opts = {}
    if (_authToken) {
        opts.headers = { 'Authorization': `Bearer ${_authToken}` }
    }
    const r = await fetch(url, opts)
    return r.ok ? r.json() : null
}

// 导出以便 actions.js 的 fetch 也能感知令牌。
// 与 api() 的主要区别是返回原始 Response，
// 调用者可以检查状态码和错误体。
window.authedFetch = function(url, init) {
    init = init || {}
    init.headers = Object.assign({}, init.headers || {})
    if (_authToken && !init.headers.Authorization) {
        init.headers.Authorization = `Bearer ${_authToken}`
    }
    return fetch(url, init)
}

function fmtDuration(m) {
    if (m == null) return '—'
    if (m < 60) return `${m} ${t('unit.min')}`
    return `${Math.floor(m/60)}h ${Math.round(m%60)}m`
}

function _esc(str) {
    const d = document.createElement('div')
    d.textContent = str || ''
    return d.innerHTML
}

// ─── 首页 ───
async function renderHome() {
    const main = document.getElementById('main-content')

    // 拆除上一次渲染中的实时日志面板，避免在导航间泄漏 EventSource 连接。
    _teardownAllLivePanes()

    // 并行加载项目、会话和跨会话分析条带。分析是尽力而为的：
    // 如果端点失败，我们仍然渲染页面的其余部分，只丢弃条带。
    const [projects, sessions, analytics] = await Promise.all([
        api('/api/projects').catch(() => []),
        api('/api/sessions').catch(() => []),
        api('/api/analytics').catch(() => null),
    ])

    // 项目头部（只读）。旧的项目切换器和"+ 添加"界面在
    // 第 5 轮（T10-frontend）中被移除；仪表盘现在通过 CLI
    // 固定为启动时的单个项目。
    const currentProject = (projects || [])[0] || {}
    const projectHeader = `
        <div class="project-bar">
            <div class="project-current">
                <span class="project-current-label">Project</span>
                <span class="project-current-path">${_esc(currentProject.name || '—')}</span>
                <span class="project-current-full" title="${_esc(currentProject.path || '')}">${_esc(currentProject.path || '')}</span>
            </div>
            <div style="font-size:0.72rem;color:var(--text-3)">
                CLI-fixed: run \`humanize monitor web --project &lt;path&gt;\` per project
            </div>
        </div>`

    const analyticsStrip = _renderHomeAnalyticsStrip(analytics)

    // 会话区域位于一个稳定的包装器内，以便 WS 推送刷新
    // 可以替换其 innerHTML 而不影响 .project-bar。
    // 这移除了 Codex 标记为全页重建的"当区域尚不存在时
    // 回退到 renderHome()"分支。
    const sessionsBody = _buildHomeSessionsHtml(sessions)
    main.innerHTML = `<div class="home">${projectHeader}${analyticsStrip}<div id="home-sessions">${sessionsBody}</div></div>`
}

// 跨会话分析条带：四个统计卡片（总会话数、平均轮次、完成率、
// 以及最近 14 天的每日轮次趋势图）。镜像参考工具的首页头部块。
// 尽力而为：当 /api/analytics 为空时静默丢弃。
function _renderHomeAnalyticsStrip(analytics) {
    if (!analytics || !analytics.overview) return ''
    const o = analytics.overview
    if ((o.total_sessions || 0) === 0) return ''
    const rpd = Array.isArray(o.rounds_per_day) ? o.rounds_per_day : []
    const windowDays = o.rounds_per_day_window || rpd.length || 14
    const sparkSvg = _renderSparkline(rpd)
    return `
        <div class="eyebrow-rule" style="margin-bottom:var(--space-3)">${t('analytics.title')}</div>
        <div class="analytics-grid" style="margin-bottom:var(--space-8)">
            <div class="stat"><div class="stat-num">${_esc(String(o.total_sessions))}</div><div class="stat-label">${t('analytics.total')}</div></div>
            <div class="stat"><div class="stat-num">${_esc(String(o.average_rounds))}</div><div class="stat-label">${t('analytics.avg_rounds')}</div></div>
            <div class="stat"><div class="stat-num">${_esc(String(o.completion_rate))}%</div><div class="stat-label">${t('analytics.completion')}</div></div>
            <div class="stat stat-chart">
                <div class="stat-label">${t('home.rounds_per_day')} (last ${windowDays}d)</div>
                ${sparkSvg}
            </div>
        </div>`
}

// 紧凑的内联 SVG 趋势图。绘制填充区域 + 折线 + 尾部圆点。
// 零数据输入渲染一个空但有效的 SVG，保持布局稳定。
function _renderSparkline(values) {
    const W = 180, H = 42, PAD = 2
    const n = values.length
    if (n === 0) return `<svg class="spark" viewBox="0 0 ${W} ${H}"></svg>`
    const peak = Math.max(1, ...values.map(v => Number(v) || 0))
    const step = n > 1 ? (W - PAD * 2) / (n - 1) : 0
    const pts = values.map((v, i) => {
        const x = PAD + i * step
        const y = H - PAD - ((Number(v) || 0) / peak) * (H - PAD * 2)
        return { x, y }
    })
    const poly = pts.map(p => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ')
    const areaPts = [
        `${PAD},${H - PAD}`,
        ...pts.map(p => `${p.x.toFixed(1)},${p.y.toFixed(1)}`),
        `${PAD + (n - 1) * step},${H - PAD}`,
    ].join(' ')
    const last = pts[pts.length - 1]
    return `
        <svg class="spark" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
            <polygon class="spark-fill" points="${areaPts}"></polygon>
            <polyline class="spark-line" points="${poly}"></polyline>
            <circle class="spark-dot" cx="${last.x.toFixed(1)}" cy="${last.y.toFixed(1)}" r="2.2"></circle>
        </svg>`
}

// 构建放入 #home-sessions 内部的 HTML 主体。涵盖所有三种情况：
// 空、仅活跃、仅已完成、两者都有。由初始 renderHome()
// 和增量 _refreshHomeCards() 共享。
//
// 区域标签 + 列表容器元素携带与 _applyHomeSection 查询相同的
// `data-home-section` / `data-home-section-label` 属性。
// 没有这些属性，第一次 WS 刷新将找不到初始渲染的容器，
// 会创建第二个容器，导致单个运行循环在屏幕上显示两个活跃区域
// — 即重复卡片的 bug。
function _buildHomeSessionsHtml(sessions) {
    if (!sessions || sessions.length === 0) {
        return `<div class="empty"><div class="empty-icon">⬡</div><div class="empty-msg">${t('home.empty')}</div><div class="empty-hint">${t('home.empty.hint')}</div></div>`
    }
    const active = sessions.filter(s => ['active','analyzing','finalizing'].includes(s.status))
    const finished = sessions.filter(s => !['active','analyzing','finalizing'].includes(s.status))
    let html = ''
    // 参考工具将每行卡片包装在带有大写 "eyebrow-rule" 标签的
    // <section> 和 .session-grid 容器中（自动适应列，慷慨的最小宽度）。
    // 活跃和已完成现在使用相同的外观 — 卡片内的状态徽章 + 脉冲点
    // 承载"运行中"信号。内联差异更新器（_applyHomeSection）在
    // 区域首次具象化时直接在 #home-sessions 下创建标签 + 容器对；
    // 保持初始渲染的形状相同（无 <section> 包装）避免了初始渲染
    // 和 WS 驱动的延迟创建之间的布局偏移。
    if (active.length) {
        html += `<div class="eyebrow-rule" data-home-section-label="active">${t('home.active')}</div>`
        html += `<div class="session-grid" data-home-section="active">${active.map(activeSessionPane).join('')}</div>`
    }
    if (finished.length) {
        html += `<div class="eyebrow-rule completed" data-home-section-label="completed">${t('home.completed')}</div>`
        html += `<div class="session-grid" data-home-section="completed">${finished.map(sessionCard).join('')}</div>`
    }
    return html
}

function _latestActiveLog(session) {
    // session.cache_logs 是 viz/server/parser.py:cache_logs_for_session
    // 发出的确定性列表 — 按 (round, tool, role) 升序排序。
    // 通过选择最高轮次的 codex-run 日志来复现 CLI 的
    // `humanize monitor rlcr` Log: 行，回退到其他 tool/role 组合。
    // 如果不这样做，简单的 cache_logs[-1] 可能会落在同一轮次的
    // `gemini-review` 或 `codex-review` 上，这是错误的文件 —
    // 用户期望的是主要的实现/审查流，而不是次要的。
    const logs = session.cache_logs || []
    if (logs.length === 0) return null
    let maxRound = -1
    for (const l of logs) if (l.round > maxRound) maxRound = l.round
    const preference = [
        ['codex', 'run'],
        ['codex', 'review'],
        ['gemini', 'run'],
        ['gemini', 'review'],
    ]
    for (const [tool, role] of preference) {
        const match = logs.find(l => l.round === maxRound && l.tool === tool && l.role === role)
        if (match) return match
    }
    // 最高轮次没有 codex/gemini 匹配 — 显示我们拥有的任何内容，
    // 使面板不为空（防御性措施；真实会话总是至少携带上述之一）。
    return logs.filter(l => l.round === maxRound).pop() || logs[logs.length - 1]
}

// 首页上的活跃面板：只是普通的 sessionCard —
// 实时监控日志流位于会话详情页面（pipeline 画布下方），不在这里。
function activeSessionPane(s) {
    return sessionCard(s)
}

// ─── 实时日志面板（T6） ───
//
// 每个活跃会话都有自己的 EventSource 与
// /api/sessions/<sid>/logs/<basename> 通信。多个面板在首页上共存；
// 导航离开时全部拆除，避免泄漏打开的连接。
function _mountLiveLogPane(sessionId, logEntry) {
    const pane = document.getElementById(`live-log-pane-${sessionId}`)
    const status = document.getElementById(`live-log-status-${sessionId}`)
    if (!pane) return

    const url = _withToken(`/api/sessions/${encodeURIComponent(sessionId)}/logs/${encodeURIComponent(logEntry.basename)}`)
    const es = new EventSource(url)

    const _utf8Decoder = new TextDecoder('utf-8', { fatal: false })
    let bytesSeen = 0
    function appendBytes(b64, { flush = false } = {}) {
        try {
            // atob 返回 Latin-1 字节字符串；转换为真正的字节数组
            // 并以 UTF-8 解码，使非 ASCII 日志输出（CJK 文本、
            // 表情符号、智能引号）正确渲染而不是乱码。
            //
            // `{ stream: true }` 保持解码器的内部缓冲区在调用间存活，
            // 使得在 64 KiB SSE 块边界处分割的多字节 UTF-8 序列
            // 在下一个事件中重新组装，而不是作为 U+FFFD 替换字符
            // 发出。当流已知完成时（resync reason=truncated/rotated/
            // recreated/overflow, eof），调用者传入 `flush: true`，
            // 使解码器的尾部缓冲区被最终化，不会意外地被添加到
            // 下一个快照前面。
            const binStr = atob(b64)
            const bytes = new Uint8Array(binStr.length)
            for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i)
            const text = _utf8Decoder.decode(bytes, { stream: !flush })
            pane.textContent += text
            bytesSeen += bytes.length
            // 限制面板大小，避免长会话时内存失控。
            const MAX_PANE_BYTES = 256 * 1024
            if (pane.textContent.length > MAX_PANE_BYTES) {
                pane.textContent = '... (truncated, showing tail)\n' +
                    pane.textContent.slice(-MAX_PANE_BYTES + 64)
            }
            pane.scrollTop = pane.scrollHeight
        } catch (_) {}
    }

    function setStatus(text, kind) {
        if (!status) return
        status.textContent = text
        status.className = 'live-log-status' + (kind ? ` live-log-status-${kind}` : '')
    }

    es.addEventListener('snapshot', (e) => {
        try {
            const data = JSON.parse(e.data)
            if (data.offset === 0) pane.textContent = ''
            appendBytes(data.bytes_b64)
            setStatus(`live (${bytesSeen}B)`, 'ok')
        } catch (_) {}
    })

    es.addEventListener('append', (e) => {
        try {
            const data = JSON.parse(e.data)
            appendBytes(data.bytes_b64)
            setStatus(`live (${bytesSeen}B)`, 'ok')
        } catch (_) {}
    })

    es.addEventListener('resync', (e) => {
        try {
            const data = JSON.parse(e.data)
            setStatus(`resync: ${data.reason}`, 'warn')
            if (data.reason === 'truncated' || data.reason === 'rotated' ||
                data.reason === 'recreated' || data.reason === 'overflow') {
                // 流从这里开始不连续：最终化解码器，使上一个文件的
                // 任何尾部缓冲字节不会混入后续的新内容中。
                try { _utf8Decoder.decode(new Uint8Array(0)) } catch (_) {}
                pane.textContent = ''
                bytesSeen = 0
            }
        } catch (_) {}
    })

    es.addEventListener('eof', () => {
        setStatus('eof', 'eof')
        es.close()
        _liveLogPanes.delete(sessionId)
        // 刷新解码器，使尾部不完整的多字节序列（如有）
        // 以 U+FFFD 渲染而不是被静默丢弃。
        try { _utf8Decoder.decode(new Uint8Array(0)) } catch (_) {}
        // 会话刚刚转换到终端状态。侧边栏/pipeline 是快照，
        // 用户导航离开再回来或重新加载时会显示新状态；
        // 此处故意不触发自动刷新（避免会话完成时整页闪烁）。
    })

    es.onerror = () => {
        setStatus('disconnected (will retry)', 'warn')
        // EventSource 自动以指数退避重连；此处不做任何操作。
        // 真正断开时浏览器发送 Last-Event-Id，
        // 服务器会重放错过的事件。
    }

    _liveLogPanes.set(sessionId, { eventSource: es, element: pane, basename: logEntry.basename })
}

function _teardownAllLivePanes() {
    for (const [, entry] of _liveLogPanes) {
        try { entry.eventSource.close() } catch (_) {}
    }
    _liveLogPanes.clear()
}

function sessionCard(s) {
    const plan = s.plan_file ? s.plan_file.split('/').pop() : '—'
    const started = s.started_at ? new Date(s.started_at).toLocaleString() : '—'
    const acPct = s.ac_total > 0 ? Math.round(s.ac_done / s.ac_total * 100) : 0
    const verdict = s.last_verdict || 'unknown'
    const statusLabel = t('status.' + s.status) || s.status
    const isActive = ['active', 'analyzing', 'finalizing'].includes(s.status)
    const idShort = (s.id || '').slice(0, 19)
    const duration = fmtDuration(s.duration_minutes)

    // 参考工具外观：精简头部（轮次 + id + 运行时带脉冲点的状态徽章）
    // → 2×2 等宽元数据网格 → AC 进度条 → 带时间戳和任务计数的等宽底部条。
    return `
        <div class="session-card" data-session-id="${_esc(s.id)}" onclick="navigate('#/session/${s.id}')">
            <div class="session-head">
                <div class="session-head-left">
                    <span class="session-round">${t('card.round')} ${s.current_round}/${s.max_iterations}</span>
                    <span class="session-id" title="${_esc(s.id)}">${_esc(idShort)}</span>
                </div>
                <span class="badge badge-${s.status}">
                    ${isActive ? '<span class="badge-dot"></span>' : ''}${_esc(statusLabel)}
                </span>
            </div>
            <div class="session-meta">
                <div><div class="k">${t('card.plan')}</div><div class="v" title="${_esc(plan)}">${esc(plan)}</div></div>
                <div><div class="k">${t('card.branch')}</div><div class="v" title="${_esc(s.start_branch || '')}">${esc(s.start_branch || '—')}</div></div>
                <div><div class="k">${t('card.verdict')}</div><div class="v verdict-${_esc(verdict)}">${_esc(verdict)}</div></div>
                <div><div class="k">${t('card.ac')}</div><div class="v">${s.ac_done}/${s.ac_total}</div></div>
            </div>
            <div class="session-ac" title="Acceptance criteria: ${s.ac_done}/${s.ac_total} (${acPct}%)">
                <div class="ac-bar"><div class="ac-bar-fill" style="width:${acPct}%"></div></div>
            </div>
            <div class="session-foot">
                <span>${_esc(started)} · ${_esc(duration)}</span>
                <span>${t('detail.tasks')}: ${s.tasks_done}/${s.tasks_total}</span>
            </div>
        </div>`
}

// ─── 会话详情 ───
async function renderSession(sessionId) {
    const main = document.getElementById('main-content')
    const session = await api(`/api/sessions/${sessionId}`)
    if (!session) {
        main.innerHTML = `<div class="page"><div class="empty"><div class="empty-msg">${t('detail.not_found')}</div></div></div>`
        return
    }

    // 自动刷新已禁用：页面底部的 SSE 实时日志面板将字节流式传输
    // 到自己的 <pre> 中，无需任何页面重新渲染，这是唯一真正需要
    // 实时的界面。Pipeline / 侧边栏 / 目标栏是快照；
    // 用户需要导航离开再回来或重新加载页面来刷新它们。

    // 仅在首次进入时构建详情布局骨架。对同一会话 id 的后续
    // 重新渲染复用现有 DOM，以免销毁底部的实时日志面板。
    let layout = main.querySelector(`.detail-layout[data-session-id="${CSS.escape(sessionId)}"]`)
    if (!layout) {
        _teardownAllLivePanes()
        main.innerHTML = `
            <div class="detail-layout" data-session-id="${_esc(sessionId)}">
                <div class="graph-area">
                    <div class="pipeline-container" id="pipeline-root"></div>
                </div>
                <div class="session-sidebar" id="session-sidebar"></div>
                <div class="session-log" id="session-log-container"></div>
                <div class="goal-bar" id="goal-bar"></div>
            </div>`
        layout = main.querySelector('.detail-layout')
    }
    _applyDetailLayoutMode(session)

    renderPipeline(document.getElementById('pipeline-root'), session)
    renderSessionSidebar(session)
    renderGoalBar(session)
    _ensureSessionLogPane(session)
    window._currentSession = session

    const cancelBtn = document.getElementById('ops-cancel')
    // 镜像后端的 _CANCELLABLE_STATUSES（第 8 轮）：取消辅助函数
    // 支持 active、analyzing 和 finalizing 会话，因此 UI 必须在
    // 这三个阶段都显示按钮。第 10 轮之前在 'active' 之外隐藏按钮，
    // 导致卡住的 analyze/finalize 会话无法从 UI 取消。
    const CANCELLABLE_STATUSES = ['active', 'analyzing', 'finalizing']
    if (cancelBtn) cancelBtn.style.display = CANCELLABLE_STATUSES.includes(session.status) ? '' : 'none'
}

// WS 推送和 5 秒轮询循环使用的增量重新渲染。重新获取会话，
// 重新填充 pipeline + 侧边栏 + 目标栏，底部的实时日志面板
// （及其 EventSource）保持不变，使流式日志不会重置。
// 当布局骨架不匹配时（例如路由变更后的首次进入），
// 回退到完整的 renderSession()。
async function _refreshSession(sessionId) {
    const main = document.getElementById('main-content')
    const layout = main && main.querySelector(`.detail-layout[data-session-id="${CSS.escape(sessionId)}"]`)
    if (!layout) {
        renderSession(sessionId)
        return
    }
    const session = await api(`/api/sessions/${sessionId}`)
    if (!session) return
    _applyDetailLayoutMode(session)
    renderPipeline(document.getElementById('pipeline-root'), session)
    renderSessionSidebar(session)
    renderGoalBar(session)
    _ensureSessionLogPane(session)
    window._currentSession = session
    const cancelBtn = document.getElementById('ops-cancel')
    const CANCELLABLE = ['active', 'analyzing', 'finalizing']
    if (cancelBtn) cancelBtn.style.display = CANCELLABLE.includes(session.status) ? '' : 'none'
}

// 切换详情布局的 "has-log" 修饰符，使网格仅为活跃会话
// 增长第三行用于实时日志面板。已完成/已取消的会话保持
// 原始的两行布局（图表 + 目标栏），与之前的外观一致。
function _applyDetailLayoutMode(session) {
    const layout = document.querySelector('.detail-layout')
    if (!layout) return
    const hasLive = ['active', 'analyzing', 'finalizing'].includes(session.status)
                  && Array.isArray(session.cache_logs) && session.cache_logs.length > 0
    layout.classList.toggle('has-log', !!hasLive)
}

// 在 #session-log-container 内创建实时日志面板，每次会话进入
// 恰好创建一次。如果会话不活跃或尚无缓存日志，则清空容器
// 并拆除任何现有面板。使用相同的 (sessionId, basename) 对
// 重复调用时是幂等的 — 现有的 EventSource 继续流式传输到
// 同一个 <pre>。
function _ensureSessionLogPane(session) {
    const container = document.getElementById('session-log-container')
    if (!container) return
    const active = ['active', 'analyzing', 'finalizing'].includes(session.status)
    const latest = _latestActiveLog(session)
    if (!active || !latest) {
        // 不需要实时日志；拆除任何先前的面板。
        const prev = _liveLogPanes.get(session.id)
        if (prev) {
            try { prev.eventSource.close() } catch (_) {}
            _liveLogPanes.delete(session.id)
        }
        container.innerHTML = ''
        return
    }
    const prev = _liveLogPanes.get(session.id)
    if (prev && prev.basename === latest.basename && container.contains(prev.element)) {
        // 相同的日志文件已在流式传输；无需操作。
        return
    }
    // 尚无面板，或最新的缓存日志滚动到了更新的轮次 —
    // 仅重建此子树（容器），保持详情布局的其余部分不变。
    // 在 basename 切换时保留切换状态（折叠/正常/展开），
    // 使展开日志的用户不会在每次新轮次开始时被弹回默认高度。
    const layout = document.querySelector('.detail-layout.has-log')
    const priorState = !layout
        ? 'normal'
        : layout.classList.contains('log-collapsed') ? 'collapsed'
        : layout.classList.contains('log-expanded')  ? 'expanded'
        : 'normal'
    if (prev) {
        try { prev.eventSource.close() } catch (_) {}
        _liveLogPanes.delete(session.id)
    }
    container.innerHTML = `
        <div class="live-log-header">
            <span class="live-log-badge">LIVE</span>
            <span class="live-log-name" title="${_esc(latest.path || '')}">${_esc(latest.basename)}</span>
            <span class="live-log-status" id="live-log-status-${_esc(session.id)}">connecting…</span>
            <span class="live-log-toggle">
                <button class="live-log-btn js-log-expand"   type="button" title="Expand to fill canvas"       onclick="toggleSessionLog('expanded')">▴</button>
                <button class="live-log-btn js-log-normal"   type="button" title="Restore default height"     onclick="toggleSessionLog('normal')">▭</button>
                <button class="live-log-btn js-log-collapse" type="button" title="Collapse (header only)"     onclick="toggleSessionLog('collapsed')">▾</button>
            </span>
        </div>
        <pre class="live-log-pane" id="live-log-pane-${_esc(session.id)}"></pre>`
    _mountLiveLogPane(session.id, latest)
    // 重新应用之前的切换状态，使活跃按钮亮起，
    // 网格行保持用户选择的高度。
    window.toggleSessionLog(priorState)
}

// 会话详情日志面板的三态折叠/展开控制。'normal' 是默认的
// 260px 行，'collapsed' 收缩到仅头部（使 pipeline 画布获得更多
// 垂直空间），'expanded' 增长日志以覆盖大部分画布，用于阅读
// 长时间的突发输出。状态作为 CSS 类存在于 .detail-layout 上，
// 使 grid-template-rows 的切换在一个地方完成。
window.toggleSessionLog = function(state) {
    const layout = document.querySelector('.detail-layout.has-log')
    if (!layout) return
    layout.classList.remove('log-collapsed', 'log-normal', 'log-expanded')
    if (state === 'collapsed') layout.classList.add('log-collapsed')
    else if (state === 'expanded') layout.classList.add('log-expanded')
    // 'normal' = 无修饰类。在切换按钮上反映新状态
    // （隐藏与当前状态匹配的按钮）。
    const buttons = layout.querySelectorAll('.live-log-btn')
    buttons.forEach(b => { b.classList.remove('is-active') })
    const cls = state === 'collapsed' ? '.js-log-collapse'
              : state === 'expanded'  ? '.js-log-expand'
              : '.js-log-normal'
    const activeBtn = layout.querySelector(cls)
    if (activeBtn) activeBtn.classList.add('is-active')
}

// 由 pipeline.js 中的 openFlyout/closeFlyout 使用：当用户打开
// 节点详情时，自动折叠日志，使模态框（和底层的 pipeline 画布）
// 有更多空间。之前的状态被记住，在弹出面板关闭时恢复。
let _savedLogState = null
window.autoCollapseSessionLog = function() {
    const layout = document.querySelector('.detail-layout.has-log')
    if (!layout) return
    _savedLogState = layout.classList.contains('log-collapsed') ? 'collapsed'
                   : layout.classList.contains('log-expanded')  ? 'expanded'
                   : 'normal'
    window.toggleSessionLog('collapsed')
}
window.restoreSessionLog = function() {
    if (_savedLogState == null) return
    const prev = _savedLogState
    _savedLogState = null
    window.toggleSessionLog(prev)
}

function renderSessionSidebar(s) {
    const sidebar = document.getElementById('session-sidebar')
    if (!sidebar) return

    const acTotal = s.ac_total || 0
    const acDone = s.ac_done || 0
    const acPct = acTotal > 0 ? Math.round(acDone / acTotal * 100) : 0

    const vCounts = { advanced: 0, stalled: 0, regressed: 0 }
    let reviewedRounds = 0
    for (const r of (s.rounds || [])) {
        if (r.review_result && selectLang(r.review_result)) {
            const v = r.verdict
            if (v in vCounts) vCounts[v]++
            reviewedRounds++
        }
    }

    const verdictBars = Object.entries(vCounts).map(([v, count]) => {
        const pct = reviewedRounds > 0 ? Math.round(count / reviewedRounds * 100) : 0
        return `<div class="sidebar-verdict-row">
            <span style="width:70px;color:var(--verdict-${v})">${v}</span>
            <div class="sidebar-verdict-bar"><div class="sidebar-verdict-fill" style="width:${pct}%;background:var(--verdict-${v})"></div></div>
            <span style="width:28px;text-align:right;color:var(--text-2);font-family:var(--font-mono);font-size:0.75rem">${count}</span>
        </div>`
    }).join('')

    const acs = s.goal_tracker?.acceptance_criteria || []
    const acListHtml = acs.map(ac => {
        const icon = ac.status === 'completed' ? '✓' : ac.status === 'in_progress' ? '◉' : '○'
        const color = ac.status === 'completed' ? 'var(--verdict-advanced)' : ac.status === 'in_progress' ? 'var(--verdict-active)' : 'var(--text-3)'
        return `<div class="sidebar-ac-item">
            <span class="sidebar-ac-icon" style="color:${color}">${icon}</span>
            <span class="sidebar-ac-text">${_esc(ac.id)}: ${_esc(ac.description?.slice(0, 60) || '')}</span>
        </div>`
    }).join('')

    const plan = s.plan_file ? s.plan_file.split('/').pop() : '—'
    const started = s.started_at ? new Date(s.started_at).toLocaleString() : '—'

    sidebar.innerHTML = `
        <div class="sidebar-section">
            <div class="sidebar-title">Overview</div>
            <div class="sidebar-stat-grid">
                <div class="sidebar-stat"><div class="sidebar-stat-num">${s.current_round}</div><div class="sidebar-stat-label">Rounds</div></div>
                <div class="sidebar-stat"><div class="sidebar-stat-num">${acPct}%</div><div class="sidebar-stat-label">${t('card.ac')}</div></div>
                <div class="sidebar-stat"><div class="sidebar-stat-num">${s.tasks_done || 0}</div><div class="sidebar-stat-label">Done</div></div>
                <div class="sidebar-stat"><div class="sidebar-stat-num">${s.tasks_total || 0}</div><div class="sidebar-stat-label">Total</div></div>
            </div>
        </div>
        <div class="sidebar-section">
            <div class="sidebar-title">${t('card.verdict')} Distribution</div>
            <div class="sidebar-verdict-list">${verdictBars}</div>
        </div>
        <div class="sidebar-section">
            <div class="sidebar-title">Session Info</div>
            <div class="sidebar-meta">
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">Status</span><span class="badge badge-${s.status}">${t('status.' + s.status)}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">${t('card.plan')}</span><span class="sidebar-meta-val">${_esc(plan)}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">${t('card.branch')}</span><span class="sidebar-meta-val">${_esc(s.start_branch || '—')}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">${t('card.started')}</span><span class="sidebar-meta-val" style="font-size:0.72rem">${started}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">${t('card.duration')}</span><span class="sidebar-meta-val">${fmtDuration(s.duration_minutes)}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">Max Iter</span><span class="sidebar-meta-val">${s.max_iterations}</span></div>
                <div class="sidebar-meta-row"><span class="sidebar-meta-key">Codex</span><span class="sidebar-meta-val">${_esc(s.codex_model || '—')}</span></div>
            </div>
        </div>
        ${acs.length > 0 ? `
        <div class="sidebar-section">
            <div class="sidebar-title">${t('card.ac')} Checklist</div>
            <div class="sidebar-ac-list">${acListHtml}</div>
            <div class="progress-bar" style="margin-top:var(--space-3)"><div class="progress-fill" style="width:${acPct}%"></div></div>
            <div style="font-size:0.72rem;color:var(--text-3);margin-top:var(--space-1);text-align:right">${acDone}/${acTotal}</div>
        </div>` : ''}

        <div class="sidebar-section">
            <div class="sidebar-title">Upstream Feedback</div>
            <div style="font-size:0.8rem;color:var(--text-2);margin-bottom:var(--space-3)">
                Submit a sanitized methodology report to <strong style="color:var(--text-1)">PolyArch/humanize</strong> to help improve the RLCR process.
            </div>
            <div id="sidebar-gh-actions">
                <button class="btn" style="width:100%;justify-content:center;margin-bottom:var(--space-2)" onclick="sidebarGenerateAndPreview('${s.id}')">
                    <span style="opacity:0.7">👁</span> Preview Issue
                </button>
                <button class="btn btn-primary" style="width:100%;justify-content:center" onclick="sidebarGenerateAndSend('${s.id}')">
                    <span style="opacity:0.8">↗</span> Submit to GitHub
                </button>
            </div>
            <div id="sidebar-gh-result" style="margin-top:var(--space-3)"></div>
        </div>`
}

function renderGoalBar(session) {
    const bar = document.getElementById('goal-bar')
    if (!bar || !session.goal_tracker) return
    const acs = session.goal_tracker.acceptance_criteria || []
    bar.innerHTML = acs.map(ac => {
        const cls = ac.status === 'completed' ? 'done' : ac.status === 'in_progress' ? 'wip' : ''
        const icon = ac.status === 'completed' ? '✓' : ac.status === 'in_progress' ? '◉' : '○'
        return `<span class="ac-pill ${cls}">${icon} ${ac.id}</span>`
    }).join('')
}

// ─── 分析 ───
async function renderAnalysis(sessionId) {
    const main = document.getElementById('main-content')
    const session = await api(`/api/sessions/${sessionId}`)
    if (!session) {
        main.innerHTML = `<div class="page"><div class="empty"><div class="empty-msg">${t('detail.not_found')}</div></div></div>`
        return
    }

    // 按用户请求禁用自动刷新；重新加载页面以获取新生成的方法论报告。

    const report = selectLang(session.methodology_report)
    const hasReport = !!report

    let sanitizedHtml = `<div class="empty"><div class="empty-msg">${t('analysis.no_report')}</div></div>`
    if (hasReport) {
        const sanitized = await api(`/api/sessions/${sessionId}/sanitized-issue`)
        if (sanitized) {
            const w = sanitized.warnings || {}
            const hasW = sanitized.requires_review || Object.keys(w).length > 0
            const warnBanner = hasW ? `<div class="warning-banner">${t('analysis.review_warning')}<br>${Object.entries(w).map(([c,n]) => `<span>• ${esc(c)}: ${n}</span>`).join(' ')}</div>` : ''
            const btns = hasW ? '' : `<div style="display:flex;gap:var(--space-3);margin-top:var(--space-4)"><button class="btn btn-primary" onclick="previewGitHubIssue('${sessionId}')">${t('analysis.preview')}</button><button class="btn" onclick="sendGitHubIssue('${sessionId}')">${t('analysis.send')}</button></div>`
            sanitizedHtml = `${warnBanner}<div class="md">${safeMd(sanitized.body)}</div><div class="gh-section"><div style="font-size:0.85rem;color:var(--text-2);margin-bottom:var(--space-3)"><strong>${t('analysis.gh_repo')}:</strong> PolyArch/humanize</div>${btns}<div id="gh-result"></div></div>`
        }
    }

    main.innerHTML = `
        <div class="page">
            <div class="tabs">
                <div class="tab active" data-tab="report">${t('analysis.report_tab')}</div>
                <div class="tab" data-tab="summary">${t('analysis.summary_tab')}</div>
            </div>
            <div class="tab-content" id="tab-report" style="display:block">
                ${hasReport ? `<div class="md">${safeMd(report)}</div>` : `<div class="empty"><div class="empty-msg">${t('analysis.no_report')}</div></div>`}
            </div>
            <div class="tab-content" id="tab-summary" style="display:none">${sanitizedHtml}</div>
        </div>`

    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.tab').forEach(el => el.classList.remove('active'))
            document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none')
            tab.classList.add('active')
            document.getElementById('tab-' + tab.dataset.tab).style.display = 'block'
        })
    })
    window._currentSession = session
}

// ─── 分析统计 ───
async function renderAnalytics() {
    const main = document.getElementById('main-content')
    const data = await api('/api/analytics')
    if (!data) {
        main.innerHTML = `<div class="page"><div class="empty"><div class="empty-msg">${t('analytics.no_data')}</div></div></div>`
        return
    }

    const o = data.overview

    main.innerHTML = `
        <div class="page">
            <h2 style="margin-bottom:var(--space-6)">${t('analytics.title')}</h2>
            <div class="stats-row">
                <div class="stat-card"><div class="stat-number">${o.total_sessions}</div><div class="stat-label">${t('analytics.total')}</div></div>
                <div class="stat-card"><div class="stat-number">${o.average_rounds}</div><div class="stat-label">${t('analytics.avg_rounds')}</div></div>
                <div class="stat-card"><div class="stat-number">${o.completion_rate}%</div><div class="stat-label">${t('analytics.completion')}</div></div>
                <div class="stat-card"><div class="stat-number">${o.total_bitlessons}</div><div class="stat-label">${t('analytics.bitlessons')}</div></div>
            </div>

            <div id="timeline-root"></div>

            <h3 style="margin-bottom:var(--space-4)">${t('analytics.comparison')}</h3>
            <div id="cmp-root"></div>
        </div>`

    // Chart.js 面板（每会话轮次、持续时间、裁决分布、P-issues、
    // 首次完成、BitLesson 增长）按用户请求被移除 — 四个摘要卡片 +
    // 时间线 + 会话比较表覆盖了分析需求，无需额外的图表栈。
    buildCmpTable(data.session_stats)

    // 异步加载时间线（需要完整会话数据，可能较慢）
    if (data.session_stats && data.session_stats.length > 0) {
        loadTimeline(data.session_stats)
    }
}

async function loadTimeline(sessionStats) {
    const root = document.getElementById('timeline-root')
    if (!root) return

    try {
        const sessions = await Promise.all(
            sessionStats.map(s => api(`/api/sessions/${s.session_id}`).catch(() => null))
        )
        const valid = sessions.filter(Boolean)
        if (valid.length === 0) return

        const rows = valid.map(s => {
            const dots = (s.rounds || []).map(r => {
                const v = r.verdict || 'unknown'
                return `<span class="tl-dot" style="background:var(--verdict-${v})" title="R${r.number}: ${v}"></span>`
            }).join('')
            return `<div class="tl-row">
                <a class="tl-label" onclick="navigate('#/session/${s.id}')">${s.id.slice(5, 16).replace('_', ' ')}</a>
                <div class="tl-dots">${dots}</div>
                <span class="badge badge-${s.status}" style="font-size:0.6rem">${t('status.' + s.status)}</span>
            </div>`
        }).join('')

        root.innerHTML = `
            <div class="section-label">Round Verdict Timeline</div>
            <div class="chart-panel" style="margin-bottom:var(--space-8)">
                <div class="tl-container">${rows}</div>
                <div class="tl-legend">
                    <span><span class="tl-dot" style="background:var(--verdict-advanced)"></span> advanced</span>
                    <span><span class="tl-dot" style="background:var(--verdict-stalled)"></span> stalled</span>
                    <span><span class="tl-dot" style="background:var(--verdict-regressed)"></span> regressed</span>
                    <span><span class="tl-dot" style="background:var(--verdict-complete)"></span> complete</span>
                    <span><span class="tl-dot" style="background:var(--verdict-unknown)"></span> unknown</span>
                </div>
            </div>`
    } catch (e) {
        console.error('[analytics] timeline failed:', e)
    }
}

function buildCmpTable(stats) {
    const root = document.getElementById('cmp-root')
    if (!root || !stats || !stats.length) return

    const sorted = [...stats].sort((a, b) => {
        let va, vb
        switch (_sortCol) {
            case 'rounds': va = a.rounds; vb = b.rounds; break
            case 'duration': va = a.avg_duration_minutes || 0; vb = b.avg_duration_minutes || 0; break
            case 'verdict': va = (a.verdict_breakdown||{}).advanced||0; vb = (b.verdict_breakdown||{}).advanced||0; break
            case 'rework': va = a.rework_count; vb = b.rework_count; break
            case 'ac': va = a.ac_completion_rate; vb = b.ac_completion_rate; break
            default: va = a.session_id; vb = b.session_id
        }
        return _sortAsc ? (va < vb ? -1 : va > vb ? 1 : 0) : (va > vb ? -1 : va < vb ? 1 : 0)
    })

    const arr = c => _sortCol === c ? (_sortAsc ? ' ▲' : ' ▼') : ''
    const cols = [
        ['session_id', 'Session'],
        [null, 'Status'],
        ['rounds', 'Rounds'],
        ['duration', 'Duration'],
        ['verdict', 'Verdict (A/S/R)'],
        ['rework', 'Rework'],
        ['ac', 'AC %'],
    ]

    let html = `<table class="cmp-table"><thead><tr>${cols.map(([k, label]) =>
        k ? `<th onclick="sortCmp('${k}')">${label}${arr(k)}</th>` : `<th>${label}</th>`
    ).join('')}</tr></thead><tbody>`

    for (const s of sorted) {
        const vb = s.verdict_breakdown || {}
        // 在拼接到 innerHTML 模板之前转义每个攻击者可达的值。
        // /api/analytics 上的后端过滤器已经拒绝 `[A-Za-z0-9_.-]+`
        // 之外的会话 id，因此这里的转义实际上是纵深防御：
        // 即使未来的生产者忘记应用过滤器，也能安全渲染，
        // 而不会突破内联 onclick / 单元格 HTML
        // （这正是 Codex 第 23 轮标记的回归）。`s.status` 是
        // 可信的（来自 parser.py 的枚举），但也通过 _esc 管道处理以保持一致。
        const idEsc = _esc(s.session_id)
        html += `<tr>
            <td><a class="cmp-nav" data-session-id="${idEsc}" style="cursor:pointer">${idEsc}</a></td>
            <td><span class="badge badge-${_esc(s.status)}">${_esc(t('status.' + s.status))}</span></td>
            <td>${_esc(String(s.rounds))}</td>
            <td>${s.avg_duration_minutes != null ? _esc(String(s.avg_duration_minutes)) + ' min' : '—'}</td>
            <td>${_esc(String(vb.advanced||0))}/${_esc(String(vb.stalled||0))}/${_esc(String(vb.regressed||0))}</td>
            <td>${_esc(String(s.rework_count))}</td>
            <td>${_esc(String(s.ac_completion_rate))}%</td>
        </tr>`
    }
    html += '</tbody></table>'
    root.innerHTML = html
    // 通过 data-attribute + 委托监听器绑定导航，使会话 id 永远不会
    // 流经内联 JS 字符串字面量。即使未来的后端回归让包含引号/脚本
    // 字符的会话 id 通过，该值也只接触 dataset（DOM 级别字符串，
    // 永远不会被重新解析为 JS）和 window 导航，两者都不会执行标记。
    root.querySelectorAll('a.cmp-nav').forEach(a => {
        a.addEventListener('click', () => navigate('#/session/' + a.dataset.sessionId))
    })
    window._cmpStats = stats
}

function sortCmp(col) {
    if (_sortCol === col) _sortAsc = !_sortAsc
    else { _sortCol = col; _sortAsc = true }
    if (window._cmpStats) buildCmpTable(window._cmpStats)
}

// ─── 初始化 ───
document.addEventListener('DOMContentLoaded', () => {
    initTheme()
    connectWebSocket()
    // 在远程模式下 WS 在服务器端被禁用，因此启动一个慢速轮询循环
    // 驱动相同的有针对性刷新路径。在 localhost 模式下这是空操作，
    // 因为 _startRemotePolling 受 _isRemoteMode 限制。
    _startRemotePolling()
    window.renderCurrentRoute()
})
