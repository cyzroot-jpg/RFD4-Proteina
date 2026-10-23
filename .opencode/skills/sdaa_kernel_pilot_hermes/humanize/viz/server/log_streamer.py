"""仪表板的每会话、每文件日志流逻辑。

实现冻结在 ``docs/streaming-protocol.md`` 中的
snapshot+append+resync+eof 事件序列。该模块是纯逻辑：
它不拥有轮询循环或 HTTP 传输。调用者驱动 ``poll()`` 并将
返回的事件字典转换为 SSE 帧或任何其他传输。

事件形状（匹配契约）：

    {"type": "snapshot", "path": <basename>, "offset": <int>, "bytes_b64": <str>, "eof": <bool>}
    {"type": "append",   "path": <basename>, "offset": <int>, "bytes_b64": <str>}
    {"type": "resync",   "path": <basename>, "reason": "truncated|rotated|recreated|missing|overflow"}
    {"type": "eof",      "path": <basename>}

流式传输器为每个流分配严格递增的 ``id``，并为 ``Last-Event-Id``
重连保留最后 256 个事件（按契约）。较大的快照按 64 KiB 分块。
"""

from __future__ import annotations

import base64
import os
import threading
import time
from collections import deque
from typing import Deque, Dict, List, Optional, Tuple

SNAPSHOT_CHUNK_BYTES = 64 * 1024
EVENT_RETENTION = 256
# ``LogStreamRegistry`` 条目的空闲 TTL，这些条目在未发出 EOF 的
# 情况下达到 refcount=0。在没有活跃消费者的这么多秒后，即使
# 会话仍然活跃，流也会被驱逐；后续重连会获得一个新的 LogStream
# （流式契约的窗口外 ``resync(overflow)`` 路径可以干净地处理）。
# 保持足够长以覆盖页面刷新和短暂的标签切换，足够短以便短暂
# 打开的会话不会在整个进程生命周期中持有其保留双端队列。
IDLE_STREAM_TTL_SECONDS = 300.0

EVENT_SNAPSHOT = "snapshot"
EVENT_APPEND = "append"
EVENT_RESYNC = "resync"
EVENT_EOF = "eof"

RESYNC_TRUNCATED = "truncated"
RESYNC_ROTATED = "rotated"
RESYNC_RECREATED = "recreated"
RESYNC_MISSING = "missing"
RESYNC_OVERFLOW = "overflow"


def _b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def _stat_id(path: str) -> Optional[Tuple[int, int]]:
    """返回 ``path`` 的 ``(st_dev, st_ino)``，如果不存在则返回 ``None``。"""
    try:
        st = os.stat(path)
    except (OSError, FileNotFoundError):
        return None
    return (st.st_dev, st.st_ino)


def _file_size(path: str) -> Optional[int]:
    try:
        return os.path.getsize(path)
    except (OSError, FileNotFoundError):
        return None


class LogStream:
    """一个 (session, filename) 对的一个流式通道。

    流使用缓存日志文件的基本名（例如 ``round-3-codex-run.log``）
    和父缓存目录的绝对路径创建。基本名是每个发出的事件中
    ``path`` 字段中出现的内容，因此客户端只看到相对名称。

    生命周期：

    - ``snapshot()`` — 发出零个或多个覆盖磁盘上已有字节的
      ``snapshot`` 事件。在重连期间可以多次调用；第二次调用
      在从偏移 0 重放之前重置内部计数器。
    - ``poll()`` — 观察文件一次；如果出现新字节则发出
      ``append``，如果文件缩小或其 inode 更改则发出 ``resync``
      后跟新鲜快照，如果文件消失则发出原因 ``missing`` 的
      ``resync``，或者在没有变化时不发出事件。
    - ``mark_eof()`` — 调用者发出写入器已关闭的信号（会话
      达到终端状态）；发出单个 ``eof`` 事件，后续的 ``poll()``
      调用为空操作。

    事件以单调递增的每流 id 返回。``replay`` 通过返回比提供的
    id 更新的所有保留事件来服务 ``Last-Event-Id`` 重连；如果 id
    超出保留窗口，它返回 ``resync(overflow)`` 加上调用者应该
    通过 ``snapshot()`` 运行的新鲜快照路径。
    """

    def __init__(self, cache_dir: str, basename: str):
        self.cache_dir = cache_dir
        self.basename = basename
        self.path = os.path.join(cache_dir, basename)
        self._next_id = 1
        self._offset = 0
        self._stat = _stat_id(self.path)
        self._eof_emitted = False
        self._retained: Deque[Dict] = deque(maxlen=EVENT_RETENTION)
        self._missing_emitted = False
        # 由任何 ``resync`` 路径（truncated/rotated/recreated）在
        # 后续的 ``_snapshot_locked`` 看到瞬时空文件时设置——
        # 这是 CI 上的常见竞态，当文件系统监视器在写入器的
        # ``open('wb')``（截断为 0）和其后续 ``write`` 之间
        # 触发时。当此标志被设置时，观察到内容的下一次轮询
        # 将字节视为新鲜快照，而不是将它们追加到预重同步流中，
        # 因此即使文件在重同步后开始为空，协议的 resync→snapshot
        # 排序也被保留。
        self._resync_pending = False
        # 所有公共变更器（snapshot、poll、mark_eof、replay）
        # 获取此锁，以便并发 SSE 处理程序可以共享同一实例
        # 而不会损坏 offset/retained 状态。RLock 使得调用其他
        # 公共方法的内部辅助程序（例如重置 ``_offset`` 的
        # replay overflow 路径）不会死锁。
        self.lock = threading.RLock()

    def latest_event_id(self) -> int:
        """返回保留的最高事件 id，如果没有则返回 0。"""
        with self.lock:
            return self._retained[-1]["id"] if self._retained else 0

    @property
    def eof_emitted(self) -> bool:
        """``_eof_emitted`` 标志的公共视图。

        注册表的释放路径查询此标志以决定没有活跃客户端的流
        是否可以被驱逐——一旦 EOF 已交付，没有人会收到保留的
        事件，因此保留缓冲区（最多 256 个 base64 负载）可以
        安全释放。
        """
        with self.lock:
            return self._eof_emitted

    def _emit(self, event: Dict) -> Dict:
        event_with_id = {"id": self._next_id, **event}
        self._next_id += 1
        self._retained.append(event_with_id)
        return event_with_id

    def snapshot(self) -> List[Dict]:
        """为磁盘上已有的一切发出快照事件。"""
        with self.lock:
            return self._snapshot_locked()

    def _snapshot_locked(self) -> List[Dict]:
        if self._eof_emitted:
            return []
        events: List[Dict] = []
        size = _file_size(self.path)
        if size is None:
            self._offset = 0
            self._stat = None
            return events

        self._stat = _stat_id(self.path)
        self._missing_emitted = False
        if size == 0:
            self._offset = 0
            return events

        try:
            f = open(self.path, "rb")
        except OSError:
            return events
        try:
            offset = 0
            while offset < size:
                chunk = f.read(SNAPSHOT_CHUNK_BYTES)
                if not chunk:
                    break
                events.append(self._emit({
                    "type": EVENT_SNAPSHOT,
                    "path": self.basename,
                    "offset": offset,
                    "bytes_b64": _b64(chunk),
                    "eof": False,
                }))
                offset += len(chunk)
            self._offset = offset
        finally:
            f.close()
        return events

    def poll(self) -> List[Dict]:
        """观察文件一次并发出发生的任何事件。"""
        with self.lock:
            return self._poll_locked()

    def _poll_locked(self) -> List[Dict]:
        if self._eof_emitted:
            return []
        events: List[Dict] = []
        size = _file_size(self.path)
        stat = _stat_id(self.path)

        if size is None:
            if not self._missing_emitted:
                events.append(self._emit({
                    "type": EVENT_RESYNC,
                    "path": self.basename,
                    "reason": RESYNC_MISSING,
                }))
                self._missing_emitted = True
            self._offset = 0
            self._stat = None
            return events

        if self._missing_emitted:
            # 文件回来了；视为重新创建。
            events.append(self._emit({
                "type": EVENT_RESYNC,
                "path": self.basename,
                "reason": RESYNC_RECREATED,
            }))
            self._missing_emitted = False
            self._offset = 0
            self._stat = stat
            snap = self._snapshot_locked()
            events.extend(snap)
            # 如果文件在重同步后瞬时为空（监视器在写入中途触发），
            # 将快照交付推迟到下一次轮询，以便重同步后跟的是真正的
            # 快照事件，而不是内容最终落地时的追加。
            self._resync_pending = not snap
            return events

        if stat is not None and self._stat is not None and stat != self._stat:
            events.append(self._emit({
                "type": EVENT_RESYNC,
                "path": self.basename,
                "reason": RESYNC_ROTATED,
            }))
            self._offset = 0
            self._stat = stat
            snap = self._snapshot_locked()
            events.extend(snap)
            self._resync_pending = not snap
            return events

        if size < self._offset:
            events.append(self._emit({
                "type": EVENT_RESYNC,
                "path": self.basename,
                "reason": RESYNC_TRUNCATED,
            }))
            self._offset = 0
            self._stat = stat
            snap = self._snapshot_locked()
            events.extend(snap)
            self._resync_pending = not snap
            return events

        if size > self._offset:
            if self._resync_pending:
                # 后重同步内容，无法在之前的轮询上进行快照
                # （当时文件为 0 字节）。现在将其作为快照发出，
                # 以便客户端仍然遵守契约的 resync→snapshot 序列。
                snap = self._snapshot_locked()
                events.extend(snap)
                if self._offset >= size:
                    self._resync_pending = False
                self._stat = stat
                return events
            new_bytes = size - self._offset
            try:
                f = open(self.path, "rb")
            except OSError:
                return events
            try:
                f.seek(self._offset)
                # 分块追加，使任何单个事件保持有界。
                start = self._offset
                remaining = new_bytes
                while remaining > 0:
                    chunk = f.read(min(SNAPSHOT_CHUNK_BYTES, remaining))
                    if not chunk:
                        break
                    events.append(self._emit({
                        "type": EVENT_APPEND,
                        "path": self.basename,
                        "offset": start,
                        "bytes_b64": _b64(chunk),
                    }))
                    start += len(chunk)
                    remaining -= len(chunk)
                self._offset = start
            finally:
                f.close()
            self._stat = stat

        return events

    def mark_eof(self) -> List[Dict]:
        """发出单个 ``eof`` 事件；后续轮询为空操作。"""
        with self.lock:
            if self._eof_emitted:
                return []
            self._eof_emitted = True
            return [self._emit({"type": EVENT_EOF, "path": self.basename})]

    def replay(self, last_event_id: int) -> Tuple[List[Dict], bool]:
        """返回比 ``last_event_id`` 更新的保留事件。

        返回 ``(events, in_window)``。当 ``in_window`` 为 False 时，
        调用者在消费任何事件后必须再次调用 ``snapshot()``；
        辅助程序已经发出了 ``resync(overflow)``。
        """
        with self.lock:
            if not self._retained:
                return [], True
            oldest = self._retained[0]["id"]
            if last_event_id < oldest - 1:
                overflow = self._emit({
                    "type": EVENT_RESYNC,
                    "path": self.basename,
                    "reason": RESYNC_OVERFLOW,
                })
                self._offset = 0
                return [overflow], False
            events = [e for e in self._retained if e["id"] > last_event_id]
            return events, True


def stream_url_path(session_id: str, basename: str) -> str:
    """一个流的规范 SSE URL 路径。"""
    return f"/api/sessions/{session_id}/logs/{basename}"


class LogStreamRegistry:
    """LogStream 实例的进程生命周期注册表。

    以 ``(session_id, basename)`` 为键。并发 SSE 处理程序
    共享同一实例，以便保留的事件历史在客户端重连中存活
    并且契约的 ``Last-Event-Id`` 语义得到遵守。没有此注册表，
    每个请求都会构造一个具有空保留的新 ``LogStream``，重连
    会将文件正文作为从偏移 0 的 ``append`` 发出，而不是
    重放或发出 ``resync(overflow)`` + ``snapshot``。
    """

    def __init__(self, idle_ttl_seconds: float = IDLE_STREAM_TTL_SECONDS):
        self._streams: Dict[Tuple[str, str], LogStream] = {}
        # 每键活跃消费者引用计数。每个 SSE 生成器周围的
        # ``acquire`` / ``release`` 配对，以便在最终客户端
        # 断开连接且 EOF 已交付后，注册表可以丢弃流（及其
        # 保留缓冲区）。没有当前客户端的活跃会话保持流驻留，
        # 以便重连仍然命中流式契约要求的 256 事件重放窗口。
        self._refcounts: Dict[Tuple[str, str], int] = {}
        # 每当流的引用计数在没有 EOF 的情况下达到零时记录的
        # 单调时间戳（活跃会话断开连接）。``release`` 中的
        # 空闲 TTL 扫描使用此来驱逐否则会在用户短暂打开
        # 多个活跃会话且从不重新访问时累积的条目；流式契约的
        # ``resync(overflow)`` 路径处理客户端在驱逐后回来时的
        # 延迟重连情况。
        self._idle_since: Dict[Tuple[str, str], float] = {}
        self._idle_ttl_seconds = idle_ttl_seconds
        self._lock = threading.Lock()

    def get_or_create(self, cache_dir: str, session_id: str, basename: str) -> LogStream:
        """返回注册表拥有的流，如果需要则创建。

        不改变引用计数。测试使用此来检查注册表共享语义；
        SSE 路由改用 ``acquire`` / ``release``，以便在最后一个
        客户端断开连接时流被驱逐。
        """
        key = (session_id, basename)
        with self._lock:
            stream = self._streams.get(key)
            if stream is None:
                stream = LogStream(cache_dir, basename)
                self._streams[key] = stream
            return stream

    def acquire(self, cache_dir: str, session_id: str, basename: str) -> LogStream:
        """获取或创建流并记录一个活跃消费者。

        必须与 :meth:`release` 配对——通常来自 SSE 生成器的
        ``finally`` 块，以便正常 EOF、客户端断开连接和异常
        路径都平衡引用计数。
        """
        key = (session_id, basename)
        with self._lock:
            # 每次新的获取也是丢弃其他空闲 TTL 已过期但没有
            # 后续释放的条目的机会。没有这个，永远不会再次
            # 释放的 refcount=0 流（长期会话上的一次性断开连接）
            # 会在进程生命周期内保持驻留并泄漏其保留双端队列。
            self._sweep_idle_streams_locked()
            stream = self._streams.get(key)
            if stream is None:
                stream = LogStream(cache_dir, basename)
                self._streams[key] = stream
            self._refcounts[key] = self._refcounts.get(key, 0) + 1
            # 重置空闲时钟：新消费者意味着之前的空闲时间戳
            # 不再适用。
            self._idle_since.pop(key, None)
            return stream

    def release(self, session_id: str, basename: str) -> None:
        """减少消费者计数并驱逐空闲流。

        驱逐策略：
        - 引用计数达到零且流已发出 ``eof`` → 立即丢弃；
          未来的客户端不需要保留双端队列。
        - 引用计数达到零但没有 EOF → 为此键启动空闲计时器，
          以便最终扫描（下面）在 ``IDLE_STREAM_TTL_SECONDS``
          过期且没有重连时驱逐它。流在 TTL 窗口内保持驻留，
          以便常见的页面刷新然后重连流程仍然命中契约要求的
          256 事件 ``Last-Event-Id`` 重放窗口。
        - 每次释放还扫描注册表中其他空闲计时器已过期的条目。
          没有此扫描，在会话终止前客户端断开连接的流（且其
          会话后来在没有其他轮询的情况下静默结束）会在整个
          进程生命周期内存活——这正是 Codex 在第 23 轮标记
          的泄漏。
        """
        key = (session_id, basename)
        with self._lock:
            remaining = self._refcounts.get(key, 0) - 1
            if remaining > 0:
                self._refcounts[key] = remaining
                return
            self._refcounts.pop(key, None)
            stream = self._streams.get(key)
            if stream is not None and stream.eof_emitted:
                self._streams.pop(key, None)
                self._idle_since.pop(key, None)
            else:
                # 尚未 EOF：启动空闲计时器，以便下面的扫描
                # （以及每次未来的释放）最终可以在没有人重连时
                # 驱逐此流。
                self._idle_since[key] = time.monotonic()
            self._sweep_idle_streams_locked()

    def _sweep_idle_streams_locked(self) -> None:
        """丢弃空闲 TTL 已过期的 refcount=0 条目。

        从 ``release`` 内部调用，同时持有 ``self._lock``。
        每次释放同时作为机会性扫描，因此即使它们所属的会话
        在浏览器访问期间从未达到终端状态，空闲保留缓冲区
        也不会累积。保持操作在注册表大小上为 O(N)，实际中
        保持较小（每个仪表板实例数十个唯一会话日志）。
        """
        if not self._idle_since:
            return
        now = time.monotonic()
        expired = [
            key for key, ts in self._idle_since.items()
            if now - ts >= self._idle_ttl_seconds
            and self._refcounts.get(key, 0) <= 0
        ]
        for key in expired:
            self._idle_since.pop(key, None)
            self._streams.pop(key, None)

    def get(self, session_id: str, basename: str) -> Optional[LogStream]:
        with self._lock:
            return self._streams.get((session_id, basename))

    def streams_in_cache_dir(self, cache_dir: str, basename: str) -> List[LogStream]:
        """返回观察特定缓存文件的所有流。"""
        with self._lock:
            # 搭载扫描：此方法在每次观察到的写入时从缓存监视器
            # 回调调用，因此利用它使空闲驱逐由持续活动驱动，
            # 而不是仅由下一次 ``release()`` 调用驱动，后者在
            # 低变更率的长期仪表板上可能永远不会发生。
            self._sweep_idle_streams_locked()
            return [
                s for s in self._streams.values()
                if s.cache_dir == cache_dir and s.basename == basename
            ]

    def __contains__(self, key) -> bool:
        with self._lock:
            return key in self._streams

    def __len__(self) -> int:
        with self._lock:
            return len(self._streams)


__all__ = [
    "EVENT_SNAPSHOT",
    "EVENT_APPEND",
    "EVENT_RESYNC",
    "EVENT_EOF",
    "RESYNC_TRUNCATED",
    "RESYNC_ROTATED",
    "RESYNC_RECREATED",
    "RESYNC_MISSING",
    "RESYNC_OVERFLOW",
    "SNAPSHOT_CHUNK_BYTES",
    "EVENT_RETENTION",
    "LogStream",
    "LogStreamRegistry",
    "stream_url_path",
]
