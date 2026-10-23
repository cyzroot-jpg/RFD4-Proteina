"""RLCR 循环数据的跨会话分析。

计算跨多个会话的统计信息：效率指标、质量指标、
判决分布和 BitLesson 增长。
"""

import time


def _rounds_per_day(sessions, window_days=14):
    """返回一个长度为 ``window_days`` 的每日完成轮次列表。

    将轮次完成时间戳（轮次摘要的 mtime）按日历天分桶，
    锚定在当前本地午夜，因此尾部条目始终代表"今天"，
    头部条目为 ``window_days - 1`` 天前。供首页分析条带
    使用以驱动紧凑的迷你图。
    """
    if window_days <= 0:
        return []
    now = time.time()
    # 将桶边界锚定在本地午夜，以获得稳定的按天对齐的桶，
    # 不受调用时间影响。
    tm_today = time.localtime(now)
    midnight_today = time.mktime(time.struct_time((
        tm_today.tm_year, tm_today.tm_mon, tm_today.tm_mday,
        0, 0, 0, 0, 0, tm_today.tm_isdst,
    )))
    earliest = midnight_today - (window_days - 1) * 86400

    buckets = [0] * window_days
    for s in sessions:
        for r in s.get('rounds', []):
            ts = r.get('summary_mtime')
            if ts is None or ts < earliest:
                continue
            # 从最早桶的午夜开始的偏移量；向下取整除法
            # 得到匹配的桶索引（对于落在今天午夜或之后的时间戳，
            # 钳制到窗口尾部）。
            idx = int((ts - earliest) // 86400)
            if idx < 0:
                continue
            if idx >= window_days:
                idx = window_days - 1
            buckets[idx] += 1
    return buckets


def compute_analytics(sessions):
    """从已解析会话列表计算跨会话统计信息。"""
    if not sessions:
        return _empty_analytics()

    total = len(sessions)
    completed = sum(1 for s in sessions if s['status'] == 'complete')
    # ``current_round`` 是从 0 开始的*索引*，不是计数——一个
    # 完成了第 0 轮的会话报告 ``current_round=0``，同时
    # ``s['rounds']`` 中有一个条目。使用轮次列表长度（解析器
    # 从 ``range(max_disk_round + 1)`` 构建）以便
    # ``overview.average_rounds`` 和每个会话的 ``rounds`` 字段
    # 反映真实计数。之前的 ``current_round > 0`` 过滤器还
    # 错误地排除了单轮会话，进一步扭曲了平均值；移除该过滤器
    # 并接受任何至少有一个轮次条目的会话。
    rounds_counts = [len(s.get('rounds') or []) for s in sessions]
    rounds_counts = [n for n in rounds_counts if n > 0]
    avg_rounds = round(sum(rounds_counts) / len(rounds_counts), 1) if rounds_counts else 0
    rounds_per_day = _rounds_per_day(sessions, window_days=14)

    # 判决分布——仅统计有实际审查结果的轮次
    verdict_counts = {'advanced': 0, 'stalled': 0, 'regressed': 0, 'complete': 0}
    for s in sessions:
        for r in s['rounds']:
            if r.get('review_result') is None:
                continue
            v = r.get('verdict', 'unknown')
            if v != 'unknown':
                verdict_counts[v] = verdict_counts.get(v, 0) + 1

    # P0-P9 分布
    p_distribution = {}
    for s in sessions:
        for r in s['rounds']:
            for level, count in r.get('p_issues', {}).items():
                p_distribution[level] = p_distribution.get(level, 0) + count

    # 每个会话的图表统计
    session_stats = []
    cumulative_bitlesson = 0
    bitlesson_growth = []

    for s in sessions:
        # 与上面概览相同的从 0 开始索引的修正：使用解析后的
        # 轮次列表，使得只有第 0 轮的会话仍然报告
        # ``rounds=1`` 而不是 0。
        rounds_count = len(s.get('rounds') or [])

        # 平均轮次时长
        durations = [r['duration_minutes'] for r in s['rounds'] if r.get('duration_minutes')]
        avg_duration = round(sum(durations) / len(durations), 1) if durations else None

        # 第一个 COMPLETE 轮次
        first_complete = None
        for r in s['rounds']:
            if r.get('verdict') == 'complete':
                first_complete = r['number']
                break

        # 返工计数（审查阶段开始后的轮次）
        rework = 0
        in_review = False
        for r in s['rounds']:
            if r.get('phase') == 'code_review':
                in_review = True
            if in_review:
                rework += 1

        # 此会话的判决细分
        sv = {'advanced': 0, 'stalled': 0, 'regressed': 0}
        for r in s['rounds']:
            v = r.get('verdict', '')
            if v in sv:
                sv[v] += 1

        # BitLesson 计数
        bl_count = sum(1 for r in s['rounds'] if r.get('bitlesson_delta') in ('add', 'update'))
        cumulative_bitlesson += bl_count

        bitlesson_growth.append({
            'session_id': s['id'],
            'cumulative': cumulative_bitlesson,
            'delta': bl_count,
        })

        session_stats.append({
            'session_id': s['id'],
            'status': s['status'],
            'rounds': rounds_count,
            'avg_duration_minutes': avg_duration,
            'first_complete_round': first_complete,
            'rework_count': rework,
            'ac_completion_rate': round(s['ac_done'] / s['ac_total'] * 100, 1) if s['ac_total'] > 0 else 0,
            'verdict_breakdown': sv,
        })

    # BitLesson 总数（如果可用则从 bitlesson.md 计数，否则估算）
    total_bitlessons = cumulative_bitlesson

    return {
        'overview': {
            'total_sessions': total,
            'completed_sessions': completed,
            'completion_rate': round(completed / total * 100, 1) if total > 0 else 0,
            'average_rounds': avg_rounds,
            'total_bitlessons': total_bitlessons,
            'rounds_per_day': rounds_per_day,
            'rounds_per_day_window': 14,
        },
        'verdict_distribution': verdict_counts,
        'p_distribution': p_distribution,
        'session_stats': session_stats,
        'bitlesson_growth': bitlesson_growth,
    }


def _empty_analytics():
    """返回空的分析结构。"""
    return {
        'overview': {
            'total_sessions': 0,
            'completed_sessions': 0,
            'completion_rate': 0,
            'average_rounds': 0,
            'total_bitlessons': 0,
            'rounds_per_day': [0] * 14,
            'rounds_per_day_window': 14,
        },
        'verdict_distribution': {},
        'p_distribution': {},
        'session_stats': [],
        'bitlesson_growth': [],
    }
