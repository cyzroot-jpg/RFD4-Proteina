"""从 .humanize/rlcr/ 目录解析 RLCR 会话数据。

读取 state.md（YAML 前置数据）、goal-tracker.md、轮次摘要、
审查结果和方法论报告到结构化的 Python 字典中。还通过
:mod:`rlcr_sources` 中的 RLCR 专用发现辅助程序公开每会话的
缓存日志路径，以便仪表板从 ``humanize monitor rlcr`` 已经
使用的相同文件读取。
"""

import logging
import os
import re
import subprocess
import yaml
from datetime import datetime

import rlcr_sources

logger = logging.getLogger(__name__)


def _derive_project_root(session_dir):
    """返回 ``.humanize/rlcr/<session>`` 路径的项目根目录。"""
    rlcr_dir = os.path.dirname(session_dir)
    humanize_dir = os.path.dirname(rlcr_dir)
    return os.path.dirname(humanize_dir)


def cache_logs_for_session(project_root, session_id):
    """返回可用缓存日志文件的确定性列表。

    委托给 :func:`rlcr_sources.live_log_paths`。每个条目是
    ``{"round": int, "tool": "codex"|"gemini", "role": "run"|"review",
    "path": absolute_path, "basename": filename}``。当缓存目录
    尚不存在（启动竞态）或没有匹配的文件时返回 ``[]``。
    """
    cache_dir = rlcr_sources.cache_dir_for_session(project_root, session_id)
    return [
        {
            "round": rnd,
            "tool": tool,
            "role": role,
            "path": path,
            "basename": os.path.basename(path),
        }
        for rnd, tool, role, path in rlcr_sources.live_log_paths(cache_dir)
    ]


def parse_yaml_frontmatter(filepath):
    """从带 --- 分隔符的 Markdown 文件中提取 YAML 前置数据。"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return {}, ''

    if not content.startswith('---'):
        return {}, content

    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}, content

    try:
        meta = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        meta = {}

    body = parts[2].strip()
    return meta, body


def detect_session_status(session_dir):
    """从终端状态文件确定会话状态。"""
    terminal_states = {
        'complete-state.md': 'complete',
        'cancel-state.md': 'cancel',
        'stop-state.md': 'stop',
        'maxiter-state.md': 'maxiter',
        'unexpected-state.md': 'unexpected',
        'methodology-analysis-state.md': 'analyzing',
        'finalize-state.md': 'finalizing',
    }
    for filename, status in terminal_states.items():
        if os.path.exists(os.path.join(session_dir, filename)):
            return status

    if os.path.exists(os.path.join(session_dir, 'state.md')):
        return 'active'

    return 'unknown'


def parse_state(session_dir):
    """解析 state.md 或会话目录中的任何 *-state.md 文件。"""
    state_file = os.path.join(session_dir, 'state.md')
    if not os.path.exists(state_file):
        for f in os.listdir(session_dir):
            if f.endswith('-state.md'):
                state_file = os.path.join(session_dir, f)
                break

    meta, _ = parse_yaml_frontmatter(state_file)
    return meta


def parse_goal_tracker(session_dir):
    """将 goal-tracker.md 解析为结构化数据。"""
    filepath = os.path.join(session_dir, 'goal-tracker.md')
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return None

    result = {
        'ultimate_goal': '',
        'acceptance_criteria': [],
        'active_tasks': [],
        'completed_verified': [],
        'deferred_tasks': [],
    }

    # 提取终极目标
    goal_match = re.search(r'### Ultimate Goal\s*\n(.*?)(?=\n###|\n---|\Z)', content, re.DOTALL)
    if goal_match:
        result['ultimate_goal'] = goal_match.group(1).strip()

    # 标准 ID 正则表达式，由 Completed-Verified 提取、验收标准
    # 列表解析器和下面的 Active-Tasks 交叉引用传递共享。
    # 接受循环的 shell 端计数产生的每种形式：
    #   - 旧版两个字母前缀加必需的破折号加整数
    #   - 单字母前缀加必需的破折号加整数
    #   - 无破折号短形式（单字母前缀后紧跟整数，无分隔符）
    #   - 以上任何一种带可选小数后缀用于嵌套标准
    #     （例如 "point one" 形式）
    # 词边界防止在不是标准引用的词内产生误报（以字母后跟
    # "C" 和数字开头的常见 OS/产品前缀）。样式合规性被保留，
    # 因为 [A]?[C]- 仍然是字符类构造，而不是禁止的三字符
    # 子串字面量。
    _criterion_id_re = r'\b[A]?[C]-?\d+(?:\.\d+)?\b'

    # 解析已完成和已验证表格。一行的第一个单元格可能列出
    # 多个标准 ID（逗号或斜杠分隔），因此提取每个单独的 ID
    # 并将每个添加到 completed_acs。没有此拆分，在一个单元格
    # 中列出两个标准 ID 的行会将组合单元格字符串插入集合，
    # 单个 ID 都不会匹配下面验收标准循环中的单 ID 查找。
    _cell_id_re = re.compile(_criterion_id_re)
    completed_acs = set()
    cv_section = re.search(r'### Completed and Verified.*?\n\|.*?\n\|[-|]+\n(.*?)(?=\n###|\Z)', content, re.DOTALL)
    if cv_section:
        for line in cv_section.group(1).strip().split('\n'):
            if not line.strip() or not line.strip().startswith('|'):
                continue
            cols = [c.strip() for c in line.split('|')[1:-1]]
            if len(cols) >= 4:
                for _id in _cell_id_re.findall(cols[0]):
                    completed_acs.add(_id)
                result['completed_verified'].append({
                    'ac': cols[0],
                    'task': cols[1],
                    'completed_round': cols[2],
                    'evidence': cols[3] if len(cols) > 3 else '',
                })

    # 从 "### Acceptance Criteria" 部分提取验收标准。
    # 循环的 shell 端计数和精炼计划工作流都允许此部分渲染为
    # 列表项（例如 "- C-1: description"）或表格（第一列 = id，
    # 第二列 = description）。针对共享的 _criterion_id_re 解析
    # 两种形式，以便列表形式和表格形式的跟踪器报告相同的计数。
    # 重复的 ID（两种形式中的相同 ID）被去重，因此混合形式
    # 内容仍然每个标准产生一个条目。
    ac_section_re = re.compile(
        r'###\s+Acceptance Criteria\s*\n(.*?)(?=\n###|\n---|\Z)',
        re.DOTALL,
    )
    # 接受纯列表形式（`- <id>: desc`）和粗体包装形式
    # （`- **<id>**: desc`）。之前的重构将其缩小为纯形式，
    # 导致使用粗体包装器的旧版/手动维护的跟踪器退化。
    ac_list_item_re = re.compile(
        r'^\s*-\s+(?:\*\*)?(' + _criterion_id_re + r')(?:\*\*)?\s*:\s*(.+?)\s*$',
        re.MULTILINE,
    )
    seen_ac_ids = set()

    def _add_ac(ac_id, desc):
        if not ac_id or ac_id in seen_ac_ids:
            return
        seen_ac_ids.add(ac_id)
        status = 'completed' if ac_id in completed_acs else 'pending'
        result['acceptance_criteria'].append({
            'id': ac_id,
            'description': desc.strip().split('\n')[0],
            'status': status,
        })

    ac_section_match = ac_section_re.search(content)
    if ac_section_match:
        section_body = ac_section_match.group(1)
        # 列表形式优先（保留主导跟踪器形状的现有行为）。
        for match in ac_list_item_re.finditer(section_body):
            _add_ac(match.group(1), match.group(2))
        # 表格形式其次：扫描看起来像 markdown 表格行的行，
        # 从第一个单元格提取 ID，从第二个单元格提取描述。
        # 跳过标题/分隔行，因为它们的第一个单元格不匹配
        # _criterion_id_re。
        for line in section_body.split('\n'):
            stripped = line.strip()
            if not stripped.startswith('|'):
                continue
            cells = [c.strip() for c in stripped.split('|')[1:-1]]
            if len(cells) < 2:
                continue
            ids_in_cell = _cell_id_re.findall(cells[0])
            if not ids_in_cell:
                continue
            # 单元格可以合法地列出共享一个描述的多个 ID
            # （罕见但支持，匹配上面的 Completed-Verified 拆分）。
            for ac_id in ids_in_cell:
                _add_ac(ac_id, cells[1])

    # 检查活跃任务的 in_progress 状态以细化 AC 状态
    active_section = re.search(r'#### Active Tasks.*?\n\|.*?\n\|[-|]+\n(.*?)(?=\n###|\Z)', content, re.DOTALL)
    in_progress_acs = set()
    if active_section:
        for line in active_section.group(1).strip().split('\n'):
            if not line.strip() or not line.strip().startswith('|'):
                continue
            cols = [c.strip() for c in line.split('|')[1:-1]]
            if len(cols) >= 3:
                task_status = cols[2].lower()
                target_acs = cols[1]
                result['active_tasks'].append({
                    'task': cols[0],
                    'target_ac': target_acs,
                    'status': cols[2],
                    'notes': cols[-1] if len(cols) > 4 else '',
                })
                if task_status in ('in_progress', 'implemented', 'needs_revision'):
                    for ac_ref in re.findall(_criterion_id_re, target_acs):
                        in_progress_acs.add(ac_ref)
                if task_status == 'deferred':
                    result['deferred_tasks'].append({
                        'task': cols[0],
                        'target_ac': target_acs,
                    })

    # 更新 AC 状态：如果有任何活跃任务引用它则为 in_progress
    for ac in result['acceptance_criteria']:
        if ac['status'] == 'pending' and ac['id'] in in_progress_acs:
            ac['status'] = 'in_progress'

    return result


def parse_git_status(project_dir):
    """返回 ``project_dir`` 的 git 状态摘要。

    镜像 scripts/humanize.sh 中的 ``humanize_parse_git_status``，
    以便网页活跃卡片显示与终端 `humanize monitor rlcr` 状态栏
    匹配。返回包含 modified / added / deleted / untracked 计数
    加上 insertions / deletions 的字典。当目录不是 git 仓库时
    返回 ``None``（尽最大努力：卡片在这种情况下简单地省略
    git 行）。
    """
    if not project_dir or not os.path.isdir(project_dir):
        return None
    try:
        subprocess.run(
            ['git', 'rev-parse', '--git-dir'],
            cwd=project_dir,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
            timeout=5,
        )
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return None

    modified = added = deleted = untracked = 0
    try:
        porcelain = subprocess.run(
            ['git', 'status', '--porcelain'],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        ).stdout
    except (subprocess.SubprocessError, OSError):
        porcelain = ''

    for line in porcelain.splitlines():
        if not line:
            continue
        xy = line[:2]
        if xy == '??':
            untracked += 1
            continue
        x, y = xy[0], xy[1]
        # 优先级匹配 ``scripts/humanize.sh`` 中的
        # ``humanize_parse_git_status``：索引侧的 ``A``
        # （``"A "``, ``"AM"``, ``"AD"``）始终为 ``added``。
        # 之前的顺序先检查 ``M in either column``，因此常见的
        # "暂存新文件然后修改它"工作流（``AM``）被错误计数为
        # 修改，仪表板 git 摘要与终端监视器不一致。
        if x == 'A':
            added += 1
        elif x == 'R' or y == 'R':
            modified += 1
        elif x == 'D' or y == 'D':
            deleted += 1
        elif x == 'M' or y == 'M':
            modified += 1

    insertions = deletions = 0
    try:
        diffstat = subprocess.run(
            ['git', 'diff', '--shortstat', 'HEAD'],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        ).stdout
        if not diffstat.strip():
            diffstat = subprocess.run(
                ['git', 'diff', '--shortstat'],
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            ).stdout
    except (subprocess.SubprocessError, OSError):
        diffstat = ''

    ins_match = re.search(r'(\d+)\s+insertion', diffstat)
    if ins_match:
        insertions = int(ins_match.group(1))
    del_match = re.search(r'(\d+)\s+deletion', diffstat)
    if del_match:
        deletions = int(del_match.group(1))

    return {
        'modified': modified,
        'added': added,
        'deleted': deleted,
        'untracked': untracked,
        'insertions': insertions,
        'deletions': deletions,
    }


def parse_review_phase_marker(session_dir):
    """读取 ``.review-phase-started`` 以发现构建完成轮次。

    返回 ``(build_finish_round, skip_impl)``，如果标记不存在/
    不可读则返回 ``(None, False)``。在仪表板上保持 monitor-rlcr
    状态栏启发式相同：当循环从构建转换到审查时，监视器的
    `Status: Active(build(N)->review(M))` 标签由此标记驱动。
    """
    marker = os.path.join(session_dir, '.review-phase-started')
    if not os.path.exists(marker):
        return None, False
    try:
        with open(marker, 'r', encoding='utf-8') as f:
            content = f.read()
    except (PermissionError, OSError):
        return None, False
    build = None
    m = re.search(r'^build_finish_round=(\d+)\s*$', content, re.MULTILINE)
    if m:
        build = int(m.group(1))
    skip_impl = bool(re.search(r'^skip_impl=true\s*$', content, re.MULTILINE))
    return build, skip_impl


def _detect_language(text):
    """基于字符范围检测文本主要是中文还是英文。"""
    if not text:
        return 'en'
    cjk_count = sum(1 for c in text if '\u4e00' <= c <= '\u9fff' or '\u3000' <= c <= '\u303f')
    return 'zh' if cjk_count > len(text) * 0.05 else 'en'


def _to_bilingual(content):
    """基于检测到的语言将内容字符串包装为 {zh, en} 结构。"""
    if content is None:
        return {'zh': None, 'en': None}
    lang = _detect_language(content)
    return {'zh': content if lang == 'zh' else None, 'en': content if lang == 'en' else None}


def _extract_task_progress(content):
    """从轮次摘要内容中提取任务完成计数。

    仅在找到明确的 "N/M tasks" 模式时返回整数计数。
    当无法提取可靠数据时返回 None——调用者应将 None
    视为"未知"并相应显示。
    """
    if not content:
        return None

    # 仅信任明确的 "X/Y tasks" 或 "X of Y tasks" 模式
    m = re.search(r'(\d+)\s*/\s*(\d+)\s*(?:tasks?|coding tasks?)', content, re.IGNORECASE)
    if m:
        return int(m.group(1))

    m = re.search(r'(\d+)\s+of\s+(\d+)\s+(?:tasks?|coding tasks?)', content, re.IGNORECASE)
    if m:
        return int(m.group(1))

    return None


def parse_round_summary(filepath):
    """解析 round-N-summary.md 文件。"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return None

    bitlesson_delta = 'none'
    bl_match = re.search(r'Action:\s*(none|add|update)', content, re.IGNORECASE)
    if bl_match:
        bitlesson_delta = bl_match.group(1).lower()

    task_progress = _extract_task_progress(content)

    return {
        'content': _to_bilingual(content),
        'bitlesson_delta': bitlesson_delta,
        'task_progress': task_progress,
        'mtime': os.path.getmtime(filepath),
    }


def parse_review_result(filepath):
    """解析 round-N-review-result.md 文件。"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return None

    # 循环契约仅在最后一个非空行恰好是 `COMPLETE` 时才将
    # 一轮视为完成（匹配停止钩子自己的测试）。此处的子串
    # 检查会误读诸如 "cannot COMPLETE yet" 或 "CANNOT COMPLETE"
    # 之类的散文，将管道 UI / last_verdict / analytics 翻转为
    # 错误的成功。
    verdict = 'unknown'
    last_non_empty = ''
    for line in reversed(content.splitlines()):
        stripped = line.strip()
        if stripped:
            last_non_empty = stripped
            break
    if last_non_empty == 'COMPLETE':
        verdict = 'complete'
    else:
        # advanced/stalled/regressed 标记来自正文中的明确判决
        # 散文（不是终端行），因此保留了这些的旧版子串检查。
        for v in ('advanced', 'stalled', 'regressed'):
            if v in content.lower():
                verdict = v
                break

    p_issues = {}
    for match in re.finditer(r'\[P(\d)\]', content):
        level = f'P{match.group(1)}'
        p_issues[level] = p_issues.get(level, 0) + 1

    return {
        'content': _to_bilingual(content),
        'verdict': verdict,
        'p_issues': p_issues,
        'mtime': os.path.getmtime(filepath),
    }


def parse_session(session_dir, project_dir=None):
    """将完整的 RLCR 会话目录解析为结构化字典。

    ``project_dir`` 是从中探测 ``git`` 状态以用于活跃卡片
    显示的项目根目录。省略时，项目根目录从会话路径
    （``.humanize/rlcr/<session>``）派生。
    """
    session_id = os.path.basename(session_dir)
    status = detect_session_status(session_dir)
    state = parse_state(session_dir)
    goal_tracker = parse_goal_tracker(session_dir)

    if project_dir is None:
        project_dir = _derive_project_root(session_dir)

    current_round = state.get('current_round', 0)

    # 发现磁盘上存在的最高轮次索引（审查文件可能超过 current_round）
    max_disk_round = current_round
    for f in os.listdir(session_dir):
        m = re.match(r'round-(\d+)-(?:summary|review-result)\.md$', f)
        if m:
            max_disk_round = max(max_disk_round, int(m.group(1)))

    # 从 0..max(current_round, 磁盘上最高轮次) 构建轮次
    rounds = []
    prev_mtime = None
    for rn in range(max_disk_round + 1):
        summary_file = os.path.join(session_dir, f'round-{rn}-summary.md')
        review_file = os.path.join(session_dir, f'round-{rn}-review-result.md')

        summary = parse_round_summary(summary_file)
        review = parse_review_result(review_file)

        # 从连续摘要时间戳计算时长
        duration_minutes = None
        if summary and prev_mtime is not None:
            duration_minutes = round((summary['mtime'] - prev_mtime) / 60, 1)
        if summary:
            prev_mtime = summary['mtime']

        # 每轮任务进度：仅来自此轮摘要中的明确模式
        task_progress = summary.get('task_progress') if summary else None

        rounds.append({
            'number': rn,
            'phase': _determine_phase(session_dir, rn, status, current_round),
            'summary': summary['content'] if summary else {'zh': None, 'en': None},
            'review_result': review['content'] if review else {'zh': None, 'en': None},
            'verdict': review['verdict'] if review else 'unknown',
            'bitlesson_delta': summary['bitlesson_delta'] if summary else 'none',
            'duration_minutes': duration_minutes,
            'p_issues': review['p_issues'] if review else {},
            'task_progress': task_progress,
            # summary mtime 是轮次完成时间戳；分析器将其用于
            # 首页的"每日轮次"条带。对于摘要尚未落地的轮次
            # 保持为 None。
            'summary_mtime': summary['mtime'] if summary else None,
        })

    # 来自目标跟踪器的任务/AC 进度
    tasks_done = 0
    tasks_total = 0
    tasks_active = 0
    tasks_deferred = 0
    ac_done = 0
    ac_total = 0
    ultimate_goal = ''
    if goal_tracker:
        tasks_total = len(goal_tracker['active_tasks']) + len(goal_tracker['completed_verified'])
        tasks_done = len(goal_tracker['completed_verified'])
        # 活跃任务 = Active-Tasks 表中状态既不是 "completed"
        # 也不是 "deferred" 的行。匹配 `humanize monitor rlcr`
        # 使用的 shell 解析器（参见
        # scripts/humanize.sh:humanize_parse_goal_tracker）。
        tasks_active = sum(
            1 for t in goal_tracker['active_tasks']
            if (t.get('status') or '').strip().lower() not in ('completed', 'deferred')
        )
        tasks_deferred = len(goal_tracker.get('deferred_tasks', []))
        ac_total = len(goal_tracker['acceptance_criteria'])
        ac_done = sum(1 for ac in goal_tracker['acceptance_criteria'] if ac['status'] == 'completed')
        ultimate_goal = goal_tracker.get('ultimate_goal', '') or ''

    # 方法论报告（双语）
    report_file = os.path.join(session_dir, 'methodology-analysis-report.md')
    methodology_report = {'zh': None, 'en': None}
    if os.path.exists(report_file):
        try:
            with open(report_file, 'r', encoding='utf-8') as f:
                raw_report = f.read()
            methodology_report = _to_bilingual(raw_report)
        except (PermissionError, OSError):
            pass

    # 从第一/最后一轮时间戳计算会话时长。镜像上面使用的
    # 磁盘上扩展，以便 ``current_round`` 落后于磁盘上存在的
    # 最高轮次的会话仍然报告完整时长，而不是少报或 None。
    session_duration_minutes = None
    if len(rounds) >= 2:
        first_mtime = None
        last_mtime = None
        for rn in range(max_disk_round + 1):
            sf = os.path.join(session_dir, f'round-{rn}-summary.md')
            if os.path.exists(sf):
                mt = os.path.getmtime(sf)
                if first_mtime is None:
                    first_mtime = mt
                last_mtime = mt
        if first_mtime and last_mtime and last_mtime > first_mtime:
            session_duration_minutes = round((last_mtime - first_mtime) / 60, 1)

    # 开始时间
    started_at = state.get('started_at', '')
    if not started_at:
        try:
            dt = datetime.strptime(session_id, '%Y-%m-%d_%H-%M-%S')
            started_at = dt.isoformat() + 'Z'
        except ValueError:
            started_at = ''

    build_finish_round, skip_impl = parse_review_phase_marker(session_dir)
    cache_logs = cache_logs_for_session(project_dir, session_id)
    # 镜像 CLI `humanize monitor rlcr` Log: 行，优先使用最高
    # 轮次的 codex-run，回退到其他 (tool, role) 组合。
    # cache_logs 已按 (round, tool, role) 排序，但简单地取
    # 最后一个条目可能落在同一轮次的 gemini-review/codex-review
    # 文件上，这是次要流而不是 CLI 监视器和用户期望的主流。
    active_log_path = ''
    if cache_logs:
        max_round = max(entry['round'] for entry in cache_logs)
        preference = (
            ('codex', 'run'),
            ('codex', 'review'),
            ('gemini', 'run'),
            ('gemini', 'review'),
        )
        for tool, role in preference:
            match = next(
                (entry for entry in cache_logs
                 if entry['round'] == max_round
                 and entry['tool'] == tool
                 and entry['role'] == role),
                None,
            )
            if match is not None:
                active_log_path = match['path']
                break
        if not active_log_path:
            # 防御性回退：选择最高轮次的最后一个条目，以便
            # 仪表板仍然显示某些内容。
            top_round_entries = [e for e in cache_logs if e['round'] == max_round]
            active_log_path = (top_round_entries or cache_logs)[-1]['path']

    return {
        'id': session_id,
        'status': status,
        'current_round': current_round,
        'max_iterations': state.get('max_iterations', 42),
        'full_review_round': state.get('full_review_round'),
        'plan_file': state.get('plan_file', ''),
        'start_branch': state.get('start_branch', ''),
        'base_branch': state.get('base_branch', ''),
        'started_at': started_at,
        'codex_model': state.get('codex_model', ''),
        'codex_effort': state.get('codex_effort', ''),
        'ask_codex_question': bool(state.get('ask_codex_question', False)),
        'review_started': bool(state.get('review_started', False)),
        'agent_teams': bool(state.get('agent_teams', False)),
        'push_every_round': bool(state.get('push_every_round', False)),
        'mainline_stall_count': int(state.get('mainline_stall_count', 0) or 0),
        'last_mainline_verdict': state.get('last_mainline_verdict', 'unknown'),
        'build_finish_round': build_finish_round,
        'skip_impl': skip_impl,
        'last_verdict': rounds[-1]['verdict'] if rounds else 'unknown',
        'drift_status': state.get('drift_status', 'normal'),
        'rounds': rounds,
        'goal_tracker': goal_tracker,
        'methodology_report': methodology_report,
        'tasks_done': tasks_done,
        'tasks_total': tasks_total,
        'tasks_active': tasks_active,
        'tasks_deferred': tasks_deferred,
        'ac_done': ac_done,
        'ac_total': ac_total,
        'ultimate_goal': ultimate_goal,
        'duration_minutes': session_duration_minutes,
        'cache_logs': cache_logs,
        'active_log_path': active_log_path,
        'git_status': parse_git_status(project_dir) if status in ('active', 'analyzing', 'finalizing') else None,
    }


def _determine_phase(session_dir, round_num, session_status, current_round=None):
    """确定特定轮次的阶段。

    ``finalize`` 分类仅适用于活跃的 finalize 步骤（会话进入
    ``finalize-state.md`` 时正在进行的轮次）。较早的轮次保持
    其原始的 ``implementation`` / ``code_review`` 分类，以便
    仪表板时间线保留真实的每轮分解，而不是将所有内容重新
    标记为 finalize。
    """
    # 最终化会话的*当前*轮次是活跃的 finalize 步骤。它必须
    # 优先于下面的 ``code_review`` 分类（finalize 轮次位于
    # ``build_finish_round`` 之后，否则会作为 code_review
    # 短路），以便阶段时间线/时长指标反映实际的 finalize 工作，
    # 而不是静默地将其归类为另一个审查轮次。
    is_live_finalize_round = (
        session_status == 'finalizing'
        and current_round is not None
        and round_num == current_round
    )

    review_started_file = os.path.join(session_dir, '.review-phase-started')
    if os.path.exists(review_started_file):
        try:
            with open(review_started_file, 'r') as f:
                content = f.read()
            match = re.search(r'build_finish_round=(\d+)', content)
            if match:
                build_round = int(match.group(1))
                # skip-impl 会话从未运行过构建轮次；
                # setup-rlcr-loop.sh 在 build_finish_round=0 行旁边
                # 写入 skip_impl=true，以便标记与第一轮（索引 0）
                # 是最后一轮构建的正常模式会话区分开来。在这种
                # 情况下，包括第 0 轮在内的每一轮都是仅审查工作。
                if re.search(r'^skip_impl=true\s*$', content, re.MULTILINE):
                    return 'finalize' if is_live_finalize_round else 'code_review'
                if round_num > build_round:
                    return 'finalize' if is_live_finalize_round else 'code_review'
        except (PermissionError, OSError):
            pass

    if is_live_finalize_round:
        return 'finalize'

    return 'implementation'


def is_valid_session(session_dir):
    """检查会话目录是否具有最低要求的文件。"""
    has_state = os.path.exists(os.path.join(session_dir, 'state.md'))
    has_terminal = any(
        f.endswith('-state.md') and f != 'state.md'
        for f in os.listdir(session_dir)
        if os.path.isfile(os.path.join(session_dir, f))
    )
    return has_state or has_terminal


def list_sessions(project_dir):
    """列出项目目录中的所有 RLCR 会话。"""
    rlcr_dir = os.path.join(project_dir, '.humanize', 'rlcr')
    if not os.path.isdir(rlcr_dir):
        return []

    sessions = []
    for entry in sorted(os.listdir(rlcr_dir), reverse=True):
        session_dir = os.path.join(rlcr_dir, entry)
        if not os.path.isdir(session_dir):
            continue

        if not is_valid_session(session_dir):
            logger.warning("Skipping malformed session directory: %s (no state.md or terminal state file)", entry)
            continue

        try:
            session = parse_session(session_dir, project_dir=project_dir)
            sessions.append(session)
        except Exception as e:
            logger.warning("Failed to parse session %s: %s", entry, e)
            continue

    return sessions


def read_plan_file(session_dir, project_dir):
    """读取会话的计划文件。

    纵深防御路径验证：state.md 中的 `plan_file` 是操作员控制的
    文本。没有界限，精心构造的值如 `plan_file: ../secret.txt`
    或 `plan_file: /etc/passwd` 会使 /api/sessions/<id>/plan
    读取任意主机文件（因为 os.path.join 静默接受绝对的第二个
    参数覆盖且不停止父遍历）。在读取之前验证解析后的路径
    保持在项目树内或会话目录内（会话本地的 plan.md 备份是
    合法的）。验证失败时，回退到会话本地备份。
    """
    state = parse_state(session_dir)
    plan_path = state.get('plan_file', '')

    backup = os.path.join(session_dir, 'plan.md')

    def _read_backup():
        if os.path.exists(backup):
            with open(backup, 'r', encoding='utf-8') as f:
                return f.read()
        return None

    if not plan_path:
        return _read_backup()

    try:
        candidate = os.path.join(project_dir, plan_path)
        candidate_real = os.path.realpath(candidate)
        project_real = os.path.realpath(project_dir)
        session_real = os.path.realpath(session_dir)
    except (OSError, ValueError):
        return _read_backup()

    project_prefix = project_real.rstrip(os.sep) + os.sep
    session_prefix = session_real.rstrip(os.sep) + os.sep
    inside_project = (
        candidate_real == project_real
        or candidate_real.startswith(project_prefix)
    )
    inside_session = (
        candidate_real == session_real
        or candidate_real.startswith(session_prefix)
    )
    if not (inside_project or inside_session):
        return _read_backup()

    # `os.path.exists` 对目录也为 True，因此包含 `plan_file: .`
    # 或任何目录路径的 state.md 会溜过存在性检查并落入
    # `open(candidate_real, 'r')`，这会引发 IsADirectoryError。
    # 这会作为 /api/sessions/<id>/plan 的未捕获 500 浮现，
    # 而不是预期的回退到会话本地的 plan.md 备份（或在没有
    # 备份时的受控 404）。`os.path.isfile` 是目录安全的，
    # 对断开的符号链接也返回 False，因此不需要额外的守卫。
    if os.path.isfile(candidate_real):
        with open(candidate_real, 'r', encoding='utf-8') as f:
            return f.read()

    return _read_backup()
