/* Pipeline — 蛇形路径节点布局，带 SVG 连接器 + 缩放/平移 + 弹出详情 */

const PL = {
    COLS: 4,
    NODE_W: 230,
    NODE_H: 68,
    GAP_X: 52,
    GAP_Y: 48,
    TURN_H: 56,
    PADDING: 40,
}

let _scale = 1, _tx = 0, _ty = 0
let _dragging = false, _dragStartX = 0, _dragStartY = 0, _dragTx = 0, _dragTy = 0

// 窗口级别的拖拽监听器在页面生命周期内只安装一次。
// renderPipeline() 在每次 SSE 驱动的会话刷新时被调用，
// 因此每次渲染都注册窗口监听器会泄漏不断增长的处理器数量，
// 并在 N 次重新渲染后将每个拖拽事件处理 N 次。
// 每个视口的 mousedown 监听器保持每渲染一次
// （视口 DOM 节点在每次渲染时都会被替换），
// 但窗口级别的 mousemove/mouseup 对是持久的。
// onDragMove/onDragEnd 在 _dragging 为 false 时是安全的空操作，
// 因此只安装一次是正确的。
let _dragListenersInstalled = false
function _ensureDragListeners() {
    if (_dragListenersInstalled) return
    window.addEventListener('mousemove', onDragMove)
    window.addEventListener('mouseup', onDragEnd)
    _dragListenersInstalled = true
}

function renderPipeline(container, session) {
    if (!container || !session) return
    const rounds = session.rounds || []
    if (rounds.length === 0) {
        container.innerHTML = `<div class="empty"><div class="empty-icon">○</div><div class="empty-msg">${t('home.empty')}</div></div>`
        return
    }

    const isActive = session.status === 'active'
    // 总节点数：轮次 + 活跃会话的 1 个幽灵节点
    const totalNodes = isActive ? rounds.length + 1 : rounds.length
    const positions = computePositions(totalNodes)
    const totalW = PL.PADDING * 2 + PL.COLS * PL.NODE_W + (PL.COLS - 1) * PL.GAP_X
    const rows = Math.ceil(totalNodes / PL.COLS)
    const totalH = PL.PADDING * 2 + rows * PL.NODE_H + (rows - 1) * (PL.GAP_Y + PL.TURN_H)

    let svgPaths = ''
    for (let i = 0; i < totalNodes - 1; i++) {
        const isLastEdge = isActive && i === rounds.length - 1
        svgPaths += buildConnector(positions[i], positions[i + 1], isLastEdge)
    }

    let nodesHtml = ''
    rounds.forEach((r, idx) => {
        nodesHtml += renderNodeCard(r, session, positions[idx])
    })

    // 活跃会话的幽灵"进行中"节点
    if (isActive) {
        const ghostPos = positions[rounds.length]
        nodesHtml += renderGhostNode(session, ghostPos)
    }

    _scale = 1; _tx = 0; _ty = 0

    container.innerHTML = `
        <div class="canvas-frame">
            <div class="pl-viewport" id="pl-viewport">
                <div class="pl-controls">
                    <button class="pl-ctrl-btn" onclick="plZoom(0.15)" title="Zoom in">+</button>
                    <button class="pl-ctrl-btn" onclick="plZoom(-0.15)" title="Zoom out">−</button>
                    <button class="pl-ctrl-btn" onclick="plFit()" title="Fit">⊡</button>
                </div>
                <div class="pl-canvas" id="pl-canvas" style="width:${totalW}px;height:${totalH}px">
                    <svg class="pl-svg" width="${totalW}" height="${totalH}" viewBox="0 0 ${totalW} ${totalH}">
                        ${svgPaths}
                    </svg>
                    ${nodesHtml}
                </div>
            </div>
        </div>
        <div class="flyout-overlay" id="flyout-overlay" onclick="if(event.target===this)closeFlyout()">
            <div class="flyout-panel" id="flyout-panel"></div>
        </div>`

    const vp = document.getElementById('pl-viewport')
    vp.addEventListener('wheel', onWheel, { passive: false })
    vp.addEventListener('mousedown', onDragStart)
    _ensureDragListeners()

    setTimeout(() => plFit(), 50)
}

// WS 推送驱动刷新使用的增量 pipeline 更新。
// 为尚未在 DOM 中的轮次追加新节点卡片，
// 就地更新裁决结果/活跃标志已更改的节点，
// 刷新幽灵节点，只修改 SVG 连接器的路径。
// 外层的 #pl-viewport 及其缩放/平移/控件保持不变，
// 使用户的当前视图（缩放、平移）在轮次间保留，
// 而不是每次新轮次到达时都回到适应视图。
function _updatePipelineIncremental(container, session) {
    const canvas = container && container.querySelector('#pl-canvas')
    const svg = canvas && canvas.querySelector('.pl-svg')
    if (!canvas || !svg) {
        // 尚无增量基底（空状态或从未渲染）。回退到完整渲染路径。
        renderPipeline(container, session)
        return
    }
    const rounds = session.rounds || []
    if (rounds.length === 0) {
        renderPipeline(container, session)
        return
    }

    const isActive = session.status === 'active'
    const totalNodes = isActive ? rounds.length + 1 : rounds.length
    const positions = computePositions(totalNodes)
    const totalW = PL.PADDING * 2 + PL.COLS * PL.NODE_W + (PL.COLS - 1) * PL.GAP_X
    const rows = Math.ceil(totalNodes / PL.COLS)
    const totalH = PL.PADDING * 2 + rows * PL.NODE_H + (rows - 1) * (PL.GAP_Y + PL.TURN_H)

    // 1) 更新/追加真实（非幽灵）节点卡片。
    const existing = Array.from(canvas.querySelectorAll('.canvas-tile:not(.is-queued)'))
    existing.sort((a, b) => Number(a.dataset.round) - Number(b.dataset.round))

    // 将现有节点放入轮次号 -> 元素的映射中，以便
    // 在不假设 DOM 顺序的情况下更新或替换它们。
    const byRound = new Map(existing.map(el => [Number(el.dataset.round), el]))

    for (let i = 0; i < rounds.length; i++) {
        const r = rounds[i]
        const pos = positions[i]
        const el = byRound.get(r.number)
        if (!el) {
            // 新轮次 -> 追加。
            const tmp = document.createElement('div')
            tmp.innerHTML = renderNodeCard(r, session, pos).trim()
            canvas.appendChild(tmp.firstChild)
            continue
        }
        const verdict = r.verdict || 'unknown'
        const shouldActive = isActive && r.number === session.current_round
        const verdictChanged = el.dataset.verdict !== verdict
        const activeChanged = el.classList.contains('active-round') !== shouldActive
        if (verdictChanged || activeChanged) {
            // 就地替换单个节点（低成本）以重新渲染裁决点、
            // 活跃指示器和迷你统计。
            const tmp = document.createElement('div')
            tmp.innerHTML = renderNodeCard(r, session, pos).trim()
            el.replaceWith(tmp.firstChild)
        }
        byRound.delete(r.number)
    }
    // byRound 中的任何剩余条目是从载荷中消失的轮次
    // （在正常流程中不应发生；防御性措施）。
    for (const el of byRound.values()) el.remove()

    // 2) 幽灵节点 — 移除旧的，当会话仍然活跃时在新位置添加一个新的。
    const oldGhost = canvas.querySelector('.canvas-tile.is-queued')
    if (oldGhost) oldGhost.remove()
    if (isActive) {
        const ghostPos = positions[rounds.length]
        const tmp = document.createElement('div')
        tmp.innerHTML = renderGhostNode(session, ghostPos).trim()
        canvas.appendChild(tmp.firstChild)
    }

    // 3) 重绘 SVG 连接器。SVG 是画布的单个子元素；
    // 用 innerHTML 替换其 <line>/<path> 子元素不会破坏
    // 周围的画布或用户的缩放状态。
    let svgPaths = ''
    for (let i = 0; i < totalNodes - 1; i++) {
        const isLastEdge = isActive && i === rounds.length - 1
        svgPaths += buildConnector(positions[i], positions[i + 1], isLastEdge)
    }
    svg.innerHTML = svgPaths
    svg.setAttribute('width', String(totalW))
    svg.setAttribute('height', String(totalH))
    svg.setAttribute('viewBox', `0 0 ${totalW} ${totalH}`)

    // 4) 画布大小可能已增长（新行）。
    canvas.style.width = `${totalW}px`
    canvas.style.height = `${totalH}px`
}

// 为 app.js 的有针对性刷新路径暴露。保持为 window 属性
// （而非模块导出）以匹配项目现有的非模块化脚本加载方式。
window._updatePipelineIncremental = _updatePipelineIncremental

function computePositions(count) {
    const positions = []
    for (let i = 0; i < count; i++) {
        const row = Math.floor(i / PL.COLS)
        const colInRow = i % PL.COLS
        const reversed = row % 2 === 1
        const col = reversed ? (PL.COLS - 1 - colInRow) : colInRow
        positions.push({
            x: PL.PADDING + col * (PL.NODE_W + PL.GAP_X),
            y: PL.PADDING + row * (PL.NODE_H + PL.GAP_Y + PL.TURN_H),
            row, col, reversed
        })
    }
    return positions
}

function buildConnector(a, b, animated) {
    const ay = a.y + PL.NODE_H / 2
    const by = b.y + PL.NODE_H / 2
    const cls = animated ? 'class="pl-edge-active"' : ''
    const color = animated ? 'var(--accent)' : 'var(--border-2)'
    const style = `fill="none" stroke="${color}" stroke-width="2" stroke-dasharray="6 4" ${cls}`

    if (a.row === b.row) {
        const x1 = a.reversed ? a.x : a.x + PL.NODE_W
        const x2 = a.reversed ? b.x + PL.NODE_W : b.x
        return `<line x1="${x1}" y1="${ay}" x2="${x2}" y2="${ay}" ${style}/>`
    }

    const exitX = a.reversed ? a.x : a.x + PL.NODE_W
    const enterX = b.reversed ? b.x + PL.NODE_W : b.x
    const midY = (a.y + PL.NODE_H + b.y) / 2
    const sideX = a.reversed ? Math.min(a.x, b.x) - PL.GAP_X * 0.4 : Math.max(a.x + PL.NODE_W, b.x + PL.NODE_W) + PL.GAP_X * 0.4

    return `<path d="M${exitX},${ay} L${sideX},${ay} L${sideX},${by} L${enterX},${by}" ${style}/>`
}

function renderNodeCard(r, session, pos) {
    const hasSummary = !!selectLang(r.summary)
    const verdict = r.verdict || 'unknown'
    const isActive = session.status === 'active' && r.number === session.current_round
    const phaseLabel = r.number === 0 ? t('node.setup') : (t(`phase.${r.phase}`) || r.phase)

    const stats = []
    if (r.duration_minutes) stats.push(`${r.duration_minutes}${t('unit.min')}`)
    if (r.bitlesson_delta && r.bitlesson_delta !== 'none') stats.push('BL+')
    if (!hasSummary) stats.push('…')

    // 参考工具画布卡片：裁决色左条纹、等宽微统计行、
    // 节点为运行中轮次时可选的扫描条。定位/连接器逻辑
    // 仍由上面的蛇形路径布局驱动。
    const classes = ['canvas-tile']
    classes.push(`verdict-${verdict}`)
    if (isActive) classes.push('is-running')

    const headLeft = `
        <span class="canvas-num">R${r.number}</span>
        <span class="canvas-tile-meta" title="${_esc(phaseLabel)}">${esc(phaseLabel)}</span>
    `
    const headRight = isActive
        ? '<span class="live-dot" title="in-flight"></span>'
        : `<span class="vdot" data-verdict="${_esc(verdict)}" title="${_esc(verdict)}"></span>`

    const statsRow = stats.length
        ? `<div class="canvas-tile-stats">${stats.map(s => `<span>${esc(s)}</span>`).join('<span class="vdot" data-verdict="unknown" style="opacity:0.4"></span>')}</div>`
        : `<div class="canvas-tile-stats" style="color:var(--text-3)">${esc(verdict)}</div>`

    const runningBar = isActive
        ? '<div class="canvas-bar"><div class="canvas-bar-fill"></div></div>'
        : ''

    return `
        <div class="${classes.join(' ')}" data-verdict="${_esc(verdict)}" data-round="${r.number}"
             style="left:${pos.x}px;top:${pos.y}px;width:${PL.NODE_W}px;height:${PL.NODE_H}px"
             onclick="openFlyout(this, ${r.number})">
            ${runningBar}
            <div class="canvas-tile-head">
                <div style="display:flex;align-items:center;gap:6px;min-width:0">${headLeft}</div>
                ${headRight}
            </div>
            ${statsRow}
        </div>`
}

function renderGhostNode(session, pos) {
    const nextRound = session.current_round + 1
    // 参考工具"排队/等待"卡片：虚线强调边框、暗淡、无点击处理器。
    // 与上面 SVG 层绘制的 pl-edge-active 动画连接器配对。
    return `
        <div class="canvas-tile is-queued"
             style="left:${pos.x}px;top:${pos.y}px;width:${PL.NODE_W}px;height:${PL.NODE_H}px">
            <div class="canvas-tile-head">
                <div style="display:flex;align-items:center;gap:6px">
                    <span class="canvas-num" style="color:var(--text-2)">R${nextRound}</span>
                    <span class="canvas-tile-meta">Next</span>
                </div>
                <span class="spinner" style="width:10px;height:10px"></span>
            </div>
            <div class="canvas-tile-stats" style="color:var(--accent)">Awaiting…</div>
        </div>`
}


// ─── 弹出模态框（从节点展开到中心） ───

function openFlyout(nodeEl, roundNum) {
    if (_dragging) return
    const session = window._currentSession
    if (!session) return
    const round = session.rounds.find(r => r.number === roundNum)
    if (!round) return

    // 弹出面板打开时自动折叠会话详情日志面板，
    // 使读者有更多屏幕空间查看节点的展开详情。
    // closeFlyout() 恢复用户在点击前的任何状态（正常/展开）。
    if (typeof window.autoCollapseSessionLog === 'function') {
        window.autoCollapseSessionLog()
    }

    const overlay = document.getElementById('flyout-overlay')
    const panel = document.getElementById('flyout-panel')
    if (!overlay || !panel) return

    // 获取节点在屏幕上的位置
    const rect = nodeEl.getBoundingClientRect()
    const vpRect = overlay.parentElement.getBoundingClientRect()

    // 设置初始位置以匹配节点
    panel.style.transition = 'none'
    panel.style.left = (rect.left - vpRect.left) + 'px'
    panel.style.top = (rect.top - vpRect.top) + 'px'
    panel.style.width = rect.width + 'px'
    panel.style.height = rect.height + 'px'
    panel.style.opacity = '0.7'
    panel.style.borderRadius = '14px'
    panel.innerHTML = ''

    // 显示遮罩层
    overlay.classList.add('visible')

    // 动画移动到中心
    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            const targetW = Math.min(720, vpRect.width - 80)
            const targetH = Math.min(vpRect.height - 100, 600)
            const targetL = (vpRect.width - targetW) / 2
            const targetT = (vpRect.height - targetH) / 2

            panel.style.transition = 'all 400ms cubic-bezier(0.16, 1, 0.3, 1)'
            panel.style.left = targetL + 'px'
            panel.style.top = targetT + 'px'
            panel.style.width = targetW + 'px'
            panel.style.height = targetH + 'px'
            panel.style.opacity = '1'
            panel.style.borderRadius = '20px'

            // 动画开始后填充内容
            setTimeout(() => {
                panel.innerHTML = buildFlyoutContent(round, session)
            }, 150)
        })
    })
}

function closeFlyout() {
    const overlay = document.getElementById('flyout-overlay')
    const panel = document.getElementById('flyout-panel')
    if (!overlay || !panel) return

    panel.style.transition = 'all 300ms cubic-bezier(0.45, 0, 0.55, 1)'
    panel.style.opacity = '0'
    panel.style.transform = 'scale(0.9)'

    setTimeout(() => {
        overlay.classList.remove('visible')
        panel.style.transform = ''
        panel.innerHTML = ''
    }, 300)

    // 将日志面板恢复到弹出面板自动折叠之前的状态。
    if (typeof window.restoreSessionLog === 'function') {
        window.restoreSessionLog()
    }
}

function buildFlyoutContent(round, session) {
    const verdict = round.verdict || 'unknown'
    const phaseLabel = round.number === 0 ? t('node.setup') : (t(`phase.${round.phase}`) || round.phase)
    const summary = selectLang(round.summary)
    const review = selectLang(round.review_result)

    const summaryHtml = summary ? safeMd(summary) : `<em style="color:var(--text-3)">${t('detail.no_summary')}</em>`
    const reviewHtml = review ? safeMd(review) : `<em style="color:var(--text-3)">${t('detail.no_review')}</em>`

    let metaItems = `
        <span class="flyout-meta-item"><strong>${t('detail.phase')}:</strong> ${esc(phaseLabel)}</span>
        <span class="flyout-meta-item"><strong>${t('card.verdict')}:</strong> <span class="verdict-${verdict}">${verdict}</span></span>`
    if (round.duration_minutes) metaItems += `<span class="flyout-meta-item"><strong>${t('card.duration')}:</strong> ${round.duration_minutes} ${t('unit.min')}</span>`
    if (round.bitlesson_delta && round.bitlesson_delta !== 'none') metaItems += `<span class="flyout-meta-item"><strong>${t('detail.bitlesson')}:</strong> ${round.bitlesson_delta} 📚</span>`
    if (round.task_progress != null) metaItems += `<span class="flyout-meta-item"><strong>${t('detail.tasks')}:</strong> ${round.task_progress}/${session.tasks_total || '?'}</span>`

    return `
        <div class="flyout-header">
            <div class="flyout-title">
                <span class="flyout-round-badge" style="border-color:var(--verdict-${verdict})">R${round.number}</span>
                <h3>${t('card.round')} ${round.number}</h3>
            </div>
            <button class="flyout-close" onclick="closeFlyout()">✕</button>
        </div>
        <div class="flyout-meta-bar">${metaItems}</div>
        <div class="flyout-body">
            <div class="flyout-section">
                <h4 class="flyout-section-title">${t('detail.summary')}</h4>
                <div class="md">${summaryHtml}</div>
            </div>
            <div class="flyout-section">
                <h4 class="flyout-section-title">${t('detail.review')}</h4>
                <div class="md">${reviewHtml}</div>
            </div>
        </div>`
}

// ─── 缩放 / 平移 ───
function applyTransform() {
    const canvas = document.getElementById('pl-canvas')
    if (canvas) canvas.style.transform = `translate(${_tx}px, ${_ty}px) scale(${_scale})`
}

function plZoom(delta) {
    _scale = Math.max(0.3, Math.min(2.5, _scale + delta))
    applyTransform()
}

function plFit() {
    const vp = document.getElementById('pl-viewport')
    const canvas = document.getElementById('pl-canvas')
    if (!vp || !canvas) return
    const vpW = vp.clientWidth, vpH = vp.clientHeight
    const cW = parseInt(canvas.style.width), cH = parseInt(canvas.style.height)
    _scale = Math.min(vpW / cW, vpH / cH, 1) * 0.92
    _tx = (vpW - cW * _scale) / 2
    _ty = Math.max(8, (vpH - cH * _scale) / 2)
    applyTransform()
}

function onWheel(e) {
    e.preventDefault()
    const delta = e.deltaY > 0 ? -0.08 : 0.08
    const rect = e.currentTarget.getBoundingClientRect()
    const mx = e.clientX - rect.left, my = e.clientY - rect.top
    const oldScale = _scale
    _scale = Math.max(0.3, Math.min(2.5, _scale + delta))
    const ratio = _scale / oldScale
    _tx = mx - ratio * (mx - _tx)
    _ty = my - ratio * (my - _ty)
    applyTransform()
}

function onDragStart(e) {
    if (e.target.closest('.canvas-tile') || e.target.closest('.pl-ctrl-btn')) return
    _dragging = true
    _dragStartX = e.clientX; _dragStartY = e.clientY
    _dragTx = _tx; _dragTy = _ty
    e.currentTarget.style.cursor = 'grabbing'
}

function onDragMove(e) {
    if (!_dragging) return
    _tx = _dragTx + (e.clientX - _dragStartX)
    _ty = _dragTy + (e.clientY - _dragStartY)
    applyTransform()
}

function onDragEnd() {
    if (!_dragging) return
    _dragging = false
    const vp = document.getElementById('pl-viewport')
    if (vp) vp.style.cursor = ''
}

function esc(str) {
    const d = document.createElement('div')
    d.textContent = str || ''
    return d.innerHTML
}
