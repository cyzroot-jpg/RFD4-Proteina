/* UI 标签 — 仅英文 */

const _LABELS = {
    'app.title': 'Humanize Viz',
    'nav.analytics': 'Analytics',
    'nav.back': '← Back',
    'home.active': 'Active',
    'home.completed': 'Completed',
    'home.empty': 'No RLCR sessions found',
    'home.empty.hint': 'Start an RLCR loop in your project and sessions will appear here.',
    'home.rounds_per_day': 'Rounds / day',
    'card.round': 'Round',
    'card.plan': 'Plan',
    'card.branch': 'Branch',
    'card.verdict': 'Verdict',
    'card.ac': 'AC',
    'card.started': 'Started',
    'card.duration': 'Duration',
    'detail.summary': 'Summary',
    'detail.review': 'Codex Review',
    'detail.phase': 'Phase',
    'detail.tasks': 'Tasks',
    'detail.bitlesson': 'BitLesson',
    'detail.no_summary': 'Summary not yet available',
    'detail.no_review': 'Review not yet available',
    'detail.not_found': 'Session not found',
    'detail.click_node': 'Click a node to expand round details',
    'ops.view_plan': 'View Plan',
    'ops.analysis': 'Methodology Analysis',
    'ops.preview_issue': 'Preview Issue',
    'ops.export_md': 'Export Markdown',
    'ops.export_pdf': 'Export PDF',
    'ops.cancel': 'Cancel Loop',
    'cancel.title': 'Confirm Cancel',
    'cancel.message': 'Cancel the current RLCR loop? This cannot be undone.',
    'cancel.confirm': 'Confirm',
    'cancel.dismiss': 'Close',
    'cancel.failed': 'Cancel failed',
    'analysis.report_tab': 'Methodology Report',
    'analysis.summary_tab': 'Sanitized Summary',
    'analysis.no_report': 'Analysis report not yet available',
    'analysis.gh_repo': 'Target repo',
    'analysis.preview': 'Preview Issue',
    'analysis.send': 'Send to GitHub',
    'analysis.copy': 'Copy Content',
    'analysis.sent': 'Sent',
    'analysis.sending': 'Sending...',
    'analysis.failed': 'Failed',
    'analysis.issue_title': 'Title',
    'analysis.issue_body': 'Body',
    'analysis.review_warning': '⚠ Sanitization check found issues. Review the methodology report manually and remove project-specific content before sending.',
    'analytics.title': 'Cross-Session Analytics',
    'analytics.total': 'Total Sessions',
    'analytics.avg_rounds': 'Avg Rounds',
    'analytics.completion': 'Completion Rate',
    'analytics.bitlessons': 'Total BitLessons',
    'analytics.comparison': 'Session Comparison',
    'analytics.no_data': 'No analytics data',
    'analytics.col_session': 'Session',
    'analytics.col_status': 'Status',
    'analytics.rework': 'Rework',
    'status.active': 'Active',
    'status.complete': 'Complete',
    'status.cancel': 'Cancelled',
    'status.stop': 'Stopped',
    'status.maxiter': 'Max Iter',
    'status.unknown': 'Unknown',
    'status.analyzing': 'Analyzing',
    'status.finalizing': 'Finalizing',
    'phase.implementation': 'Impl',
    'phase.code_review': 'Review',
    'phase.finalize': 'Final',
    'node.setup': 'Setup',
    'unit.min': 'min',
}

function t(key) {
    return _LABELS[key] || key
}

// 从 {zh, en} 对象中选择内容语言 — 优先英文
function selectLang(content) {
    if (!content) return null
    if (typeof content === 'string') return content
    if (typeof content === 'object') {
        return content['en'] || content['zh'] || null
    }
    return null
}

// 安全 Markdown 渲染 — 先解析再消毒以防止 XSS。
// 当 DOMPurify CDN 依赖未加载时（离线、被防火墙阻止、
// 或 CSP 禁止 unpkg.com），回退到纯文本转义。
// 之前的实现在这种情况下返回原始的 marked.parse() 输出，
// 这会重新打开消毒器本应关闭的 XSS 攻击面 — 计划文件、
// 轮次摘要、审查结果、方法论报告和预览 Issue 模态框
// 都通过此辅助函数将 markdown 注入 DOM。
function safeMd(text) {
    if (!text) return ''
    if (typeof DOMPurify === 'undefined' || typeof marked === 'undefined') {
        // 回退到转义的纯文本，使缺失的 CDN 依赖成为可见的
        // 降级（等宽文本）而不是无声的 XSS 隐患。镜像了
        // app.js / pipeline.js 中每个属性级别转义使用的 _esc() 往返。
        const d = document.createElement('div')
        d.textContent = String(text)
        return `<pre style="white-space:pre-wrap;word-break:break-word;margin:0">${d.innerHTML}</pre>`
    }
    const html = marked.parse(text)
    return DOMPurify.sanitize(html)
}
