"""将 RLCR 会话数据导出为 Markdown 报告。"""


def _resolve_content(value, lang='en'):
    """从双语 {zh, en} 字典或纯字符串中提取字符串内容。"""
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return value.get(lang) or value.get('en') or value.get('zh')
    return str(value)


def export_session_markdown(session, lang='en'):
    """为会话生成结构化的 Markdown 报告。"""
    lines = []
    sid = session['id']
    lines.append(f"# RLCR Session Report — {sid}\n")

    # 概览表
    lines.append("## Overview\n")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Status | {session['status'].capitalize()} |")
    # ``current_round`` 是从 0 开始的索引——一个只完成了第 0 轮的
    # 会话报告 ``current_round=0``，同时 ``rounds`` 中有一个条目。
    # 使用解析后的轮次列表长度，以便导出的 Markdown 反映真实的
    # 已完成轮次计数，而不是对每个会话少报一轮。
    lines.append(f"| Rounds | {len(session.get('rounds') or [])} |")
    lines.append(f"| Plan | {session.get('plan_file', 'N/A')} |")
    lines.append(f"| Branch | {session.get('start_branch', 'N/A')} |")
    lines.append(f"| Started | {session.get('started_at', 'N/A')} |")
    lines.append(f"| Codex Model | {session.get('codex_model', 'N/A')} |")
    lines.append(f"| Last Verdict | {session.get('last_verdict', 'N/A')} |")

    ac_total = session.get('ac_total', 0)
    ac_done = session.get('ac_done', 0)
    if ac_total > 0:
        lines.append(f"| AC Completion | {ac_done}/{ac_total} ({round(ac_done/ac_total*100)}%) |")
    lines.append("")

    # 轮次历史
    if session.get('rounds'):
        lines.append("## Round History\n")
        for r in session['rounds']:
            rn = r['number']
            lines.append(f"### Round {rn}\n")
            lines.append(f"**Phase**: {r.get('phase', 'N/A')}")
            lines.append(f"**Verdict**: {r.get('verdict', 'N/A')}")
            if r.get('duration_minutes'):
                lines.append(f"**Duration**: {r['duration_minutes']} min")
            if r.get('bitlesson_delta') and r['bitlesson_delta'] != 'none':
                lines.append(f"**BitLesson**: {r['bitlesson_delta']}")
            lines.append("")

            summary_text = _resolve_content(r.get('summary'), lang)
            if summary_text:
                lines.append("#### Summary\n")
                lines.append(summary_text)
                lines.append("")

            review_text = _resolve_content(r.get('review_result'), lang)
            if review_text:
                lines.append("#### Codex Review\n")
                lines.append(review_text)
                lines.append("")

    # 目标跟踪器
    gt = session.get('goal_tracker')
    if gt:
        lines.append("## Goal Tracker\n")
        lines.append(f"**Ultimate Goal**: {gt.get('ultimate_goal', 'N/A')}\n")

        if gt.get('acceptance_criteria'):
            lines.append("### Acceptance Criteria\n")
            for ac in gt['acceptance_criteria']:
                status_icon = {'completed': '\u2713', 'in_progress': '\u25C9', 'pending': '\u25CB'}.get(ac['status'], '?')
                lines.append(f"- {status_icon} **{ac['id']}**: {ac['description']}")
            lines.append("")

    # 方法论分析
    report_text = _resolve_content(session.get('methodology_report'), lang)
    if report_text:
        lines.append("## Methodology Analysis\n")
        lines.append(report_text)
        lines.append("")

    return '\n'.join(lines)
