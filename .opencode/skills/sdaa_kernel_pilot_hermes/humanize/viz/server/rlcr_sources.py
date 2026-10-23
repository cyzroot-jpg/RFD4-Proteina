"""仪表板的 RLCR 专用会话和缓存日发现。

此模块是将 ``.humanize/rlcr/<session>/`` 下的 RLCR 会话目录
映射到 ``${XDG_CACHE_HOME:-$HOME/.cache}/humanize/<sanitized-project>/<session>/``
下的每会话缓存目录以及该缓存目录中的实时轮次日志文件的
唯一 Python 事实来源。

设计约束：
- RLCR 专用。技能调用缓存规则（由 ``scripts/lib/monitor-skill.sh``
  处理）故意不在此处合并。
- 纯 Python 且在导入时无副作用。
- 当底层目录缺失时函数返回空容器（从不引发），因此调用者
  可以在启动竞态期间安全轮询，此时
  ``.humanize/rlcr/<session>/`` 存在但缓存日志尚未写入。
- 项目路径的清理匹配 ``scripts/humanize.sh`` 中的规则
  （将 ``[A-Za-z0-9._-]`` 之外的任何字符替换为 ``-``，
  然后折叠连续的 ``-``）。随附的奇偶测试针对真实项目路径
  验证此规则。
"""

from __future__ import annotations

import os
import re
from typing import Iterable, List, Tuple

ACTIVE_STATE_FILE = "state.md"
TERMINAL_STATE_SUFFIX = "-state.md"

ACTIVE_STATE_FILES = frozenset({
    ACTIVE_STATE_FILE,
    "methodology-analysis-state.md",
    "finalize-state.md",
})
"""其存在意味着 RLCR 循环仍在进行的文件。

镜像 ``scripts/lib/monitor-common.sh`` 中的优先级规则
（``monitor_find_state_file`` 函数优先于 methodology-analysis-state.md
而非 state.md）以及 ``viz/server/parser.py`` 中的状态映射
（`detect_session_status` 将 methodology-analysis-state.md 映射到
``analyzing``，将 finalize-state.md 映射到 ``finalizing``）。

任何其他 ``*-state.md`` 文件（complete-state.md、cancel-state.md、
stop-state.md、maxiter-state.md、unexpected-state.md、error-state.md、
timeout-state.md、approve-state.md、...）标记终端停止原因并将
会话推入历史。
"""

_LOG_FILENAME_RE = re.compile(
    r"^round-(\d+)-(codex|gemini)-(run|review)\.log$"
)

_SANITIZE_NON_SAFE_RE = re.compile(r"[^A-Za-z0-9._-]")
_SANITIZE_COLLAPSE_RE = re.compile(r"-+")


def sanitize_project_path(project_root: str) -> str:
    """将绝对项目路径清理为单个目录名。

    镜像 ``scripts/humanize.sh`` 中的规则（在
    ``_find_latest_codex_log`` 中的 ``sanitized_project=...``
    赋值附近）：

        echo "$project_root" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g'

    ``tests/test-rlcr-sources.sh`` 中的奇偶测试针对实时 shell
    管道对几个代表性路径交叉检查此规则。
    """
    replaced = _SANITIZE_NON_SAFE_RE.sub("-", project_root)
    return _SANITIZE_COLLAPSE_RE.sub("-", replaced)


def cache_root() -> str:
    """返回用于 RLCR 每会话日志目录的缓存根目录。

    解析为 ``${XDG_CACHE_HOME:-$HOME/.cache}/humanize``，
    与 ``scripts/humanize.sh`` 完全相同。函数不验证目录是否存在；
    调用者应将缺失的根目录视为空发现结果，而不是错误。
    """
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(
        os.path.expanduser("~"), ".cache"
    )
    return os.path.join(base, "humanize")


def cache_dir_for_session(project_root: str, session_id: str) -> str:
    """返回绝对的每会话缓存目录路径。

    路径由清理后的项目根目录和会话 ID（``.humanize/rlcr/``
    下会话目录的基本名）构建。不要求目录存在；函数仅构造路径。
    """
    sanitized = sanitize_project_path(project_root or "")
    return os.path.join(cache_root(), sanitized, session_id or "")


def _classify_session(session_dir: str) -> str:
    """返回 ``"active"``、``"historical"``、``"unknown"`` 之一。

    活跃阶段通过 ``ACTIVE_STATE_FILES`` 中任何文件的存在来检测
    （state.md、methodology-analysis-state.md、finalize-state.md）。
    这匹配 ``scripts/lib/monitor-common.sh:monitor_find_state_file``
    中的优先级和 ``viz/server/parser.py:detect_session_status``
    中的状态映射，其中 methodology-analysis 和 finalize 是循环的
    运行阶段，而不是停止原因。

    历史会话至少有一个 ``*-state.md`` 文件但没有活跃的那些
    （终端停止原因如 complete-state.md、cancel-state.md 等）。
    完全没有状态文件的会话（写入中途、部分脚手架）报告为
    ``unknown``。
    """
    if not os.path.isdir(session_dir):
        return "unknown"
    try:
        names = os.listdir(session_dir)
    except OSError:
        return "unknown"

    has_terminal = False
    for name in names:
        if name in ACTIVE_STATE_FILES and os.path.isfile(
            os.path.join(session_dir, name)
        ):
            return "active"
        if name.endswith(TERMINAL_STATE_SUFFIX) and name not in ACTIVE_STATE_FILES:
            has_terminal = True
    return "historical" if has_terminal else "unknown"


SessionEntry = Tuple[str, str, str]
"""(session_id, session_dir, classification)。"""


def enumerate_sessions(rlcr_dir: str) -> List[SessionEntry]:
    """列出 ``rlcr_dir`` 下的每个会话目录。

    返回按会话 ID 排序的确定性列表（使用类似 ISO 的时间戳
    命名约定，因此字典序排序产生时间顺序）。静默跳过名称
    不符合的会话（不是目录的任何内容）。仪表板依赖此枚举
    来拒绝终端监视器使用的单会话自动切换行为。
    """
    if not rlcr_dir or not os.path.isdir(rlcr_dir):
        return []

    entries: List[SessionEntry] = []
    try:
        names = sorted(os.listdir(rlcr_dir))
    except OSError:
        return []

    for name in names:
        full = os.path.join(rlcr_dir, name)
        if not os.path.isdir(full):
            continue
        entries.append((name, full, _classify_session(full)))
    return entries


def partition_sessions(
    entries: Iterable[SessionEntry],
) -> Tuple[List[SessionEntry], List[SessionEntry], List[SessionEntry]]:
    """将枚举输出拆分为 ``(active, historical, unknown)``。

    每个返回的列表保留输入顺序。仪表板分别渲染活跃和历史
    列表；保留未知条目，以便 UI 可以显示部分会话而不崩溃。
    """
    active: List[SessionEntry] = []
    historical: List[SessionEntry] = []
    unknown: List[SessionEntry] = []
    for entry in entries:
        if entry[2] == "active":
            active.append(entry)
        elif entry[2] == "historical":
            historical.append(entry)
        else:
            unknown.append(entry)
    return active, historical, unknown


LogPath = Tuple[int, str, str, str]
"""(round, tool, role, absolute_path)，其中 tool 在 {codex, gemini} 中，role 在 {run, review} 中。"""


def live_log_paths(cache_dir: str) -> List[LogPath]:
    """返回每会话缓存目录中的所有轮次日志文件。

    文件名与严格模式 ``round-N-{codex|gemini}-{run|review}.log``
    匹配。结果按 ``(round, tool, role)`` 排序，以便消费者获得
    确定性顺序。缺失或不可读的缓存目录返回空列表而不是引发，
    这让调用者可以在启动竞态期间轮询。
    """
    if not cache_dir or not os.path.isdir(cache_dir):
        return []

    matches: List[LogPath] = []
    try:
        names = os.listdir(cache_dir)
    except OSError:
        return []

    for name in names:
        m = _LOG_FILENAME_RE.match(name)
        if not m:
            continue
        round_num = int(m.group(1))
        tool = m.group(2)
        role = m.group(3)
        matches.append((round_num, tool, role, os.path.join(cache_dir, name)))

    matches.sort(key=lambda t: (t[0], t[1], t[2]))
    return matches


__all__ = [
    "ACTIVE_STATE_FILE",
    "ACTIVE_STATE_FILES",
    "TERMINAL_STATE_SUFFIX",
    "SessionEntry",
    "LogPath",
    "sanitize_project_path",
    "cache_root",
    "cache_dir_for_session",
    "enumerate_sessions",
    "partition_sessions",
    "live_log_paths",
]
