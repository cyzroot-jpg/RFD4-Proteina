"""RLCR 会话目录的文件系统监视器。

使用 watchdog 监视 .humanize/rlcr/ 并在会话文件更改时推送
WebSocket 事件。事件被防抖（500ms）以避免在快速连续写入时
产生垃圾信息。
"""

import os
import re
import json
import time
import threading
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

import rlcr_sources


def _noop_session_created(session_id):
    """RLCREventHandler.on_session_created 的默认处理程序。

    测试和替代框架可以放入 watchdog 钩子而无需连接缓存目录
    观察者。SessionWatcher.start 将此替换为真正的回调。
    """
    del session_id  # 未使用


class RLCREventHandler(FileSystemEventHandler):
    """将文件更改映射到 WebSocket 事件类型。"""

    def __init__(self, rlcr_dir, broadcast_fn):
        super().__init__()
        self.rlcr_dir = rlcr_dir
        self.broadcast = broadcast_fn
        self._pending = {}
        self._lock = threading.Lock()
        self._timer = None
        self.debounce_ms = 500
        # 由 SessionWatcher 设置，以便新会话的缓存目录在其
        # 状态目录出现时立即被监视，并在终端状态标记落地时
        # 拆除相应的观察者。默认为空操作可调用对象，以便
        # 替代框架/测试可以直接调用 RLCREventHandler 而无需
        # 连接这些。
        self.on_session_created = _noop_session_created
        self.on_session_finished = _noop_session_created

    def on_any_event(self, event):
        src = str(event.src_path)

        if event.is_directory and event.event_type == 'created':
            rel = os.path.relpath(src, self.rlcr_dir)
            if '/' not in rel and '\\' not in rel:
                self._schedule_event('session_created', rel)
                try:
                    self.on_session_created(rel)
                except Exception:
                    # 不要因回调失败而使观察者线程崩溃。
                    pass
            return

        if event.is_directory:
            return

        rel = os.path.relpath(src, self.rlcr_dir)
        parts = rel.replace('\\', '/').split('/')

        if len(parts) < 2:
            return

        session_id = parts[0]
        filename = parts[1]

        if filename == 'state.md':
            self._schedule_event('session_updated', session_id)
        elif filename == 'goal-tracker.md':
            self._schedule_event('session_updated', session_id)
        elif re.match(r'round-\d+-summary\.md$', filename):
            self._schedule_event('round_added', session_id)
        elif re.match(r'round-\d+-review-result\.md$', filename):
            self._schedule_event('session_updated', session_id)
        elif filename.endswith('-state.md') and filename != 'state.md':
            self._schedule_event('session_finished', session_id)
            # 告诉 SessionWatcher 拆除每会话缓存目录观察者，
            # 以便在 RLCR 循环停止写入日志后我们不会继续持有
            # inotify 槽位。
            try:
                self.on_session_finished(session_id)
            except Exception:
                pass

    def _schedule_event(self, event_type, session_id):
        """防抖事件：累积 500ms 后再广播。"""
        # 确保此会话存在缓存目录观察者。启动路径已经尝试过
        # 一次；在此重复处理状态目录在 RLCR 缓存目录之前
        # 出现的竞态，缓存目录实现后的未来事件最终会成功。
        # 当观察者已在运行时是幂等的。
        try:
            self.on_session_created(session_id)
        except Exception:
            pass
        key = f"{event_type}:{session_id}"
        with self._lock:
            self._pending[key] = {
                'type': event_type,
                'session_id': session_id,
                'time': time.time(),
            }
        self._reset_timer()

    def _reset_timer(self):
        if self._timer:
            self._timer.cancel()
        self._timer = threading.Timer(self.debounce_ms / 1000.0, self._flush)
        self._timer.daemon = True
        self._timer.start()

    def _flush(self):
        with self._lock:
            events = list(self._pending.values())
            self._pending.clear()

        for event in events:
            self.broadcast(json.dumps({
                'type': event['type'],
                'session_id': event['session_id'],
            }))


class _CacheLogBroadcastHandler(FileSystemEventHandler):
    """当新的 round-*.log 文件出现时发出 ``round_added`` 广播。

    上面的 RLCREventHandler 只能看到 ``.humanize/rlcr/`` 内部
    的写入——即 state.md、goal-tracker.md 和轮次摘要/审查
    markdown 文件。它永远不会注意到全新的 ``round-N-codex-run.log``
    在每会话缓存目录（``~/.cache/humanize/<project>/<session>/``）
    中实现，这是仪表板实时日志窗格流式传输的实际文件。
    没有此处理程序，前端会固定在上一轮的日志上，直到下一次
    state.md 写入，这可能滞后于新轮次很多分钟。
    """

    _LOG_NAME_RE = re.compile(
        r"^round-\d+-(?:codex|gemini)-(?:run|review)\.log$"
    )

    def __init__(self, session_id, broadcast_fn):
        super().__init__()
        self.session_id = session_id
        self.broadcast = broadcast_fn
        self._seen = set()
        self._lock = threading.Lock()

    def on_created(self, event):
        if event.is_directory:
            return
        name = os.path.basename(str(event.src_path))
        if not self._LOG_NAME_RE.match(name):
            return
        with self._lock:
            if name in self._seen:
                return
            self._seen.add(name)
        try:
            self.broadcast(json.dumps({
                'type': 'round_added',
                'session_id': self.session_id,
            }))
        except Exception:
            # 永远不要因广播失败而使 watchdog 观察者线程崩溃——
            # 前端会在下一次 state.md / summary.md 写入时赶上。
            pass


class SessionWatcher:
    """管理 RLCR 目录的 watchdog 观察者。

    并行维护两个观察者：
      - 一个在 ``.humanize/rlcr/`` 上的观察者，用于会话级状态
        文件（state.md、goal-tracker.md、轮次摘要和审查结果、
        终端状态文件）。
      - 每个活跃会话的缓存目录一个观察者
        （``~/.cache/humanize/<project>/<session>/``）。
        这些观察者在新的 round-*.log 文件创建时广播
        ``round_added``，以便仪表板可以将实时日志窗格切换到
        新轮次而无需等待下一次 state.md 写入。
    """

    def __init__(self, project_dir, broadcast_fn):
        self.project_dir = project_dir
        self.rlcr_dir = os.path.join(project_dir, '.humanize', 'rlcr')
        self.broadcast = broadcast_fn
        self.observer = None
        self._cache_observers = {}
        self._cache_lock = threading.Lock()

    # 会话仅在 state.md 存在且旁边没有任何终端 *-state.md 标记
    # 时才是"活跃的"（因此值得监视新的缓存日志文件）。任何
    # 其他排列（state.md 缺失，或存在 cancel-state.md /
    # complete-state.md / stop-state.md / maxiter-state.md /
    # unexpected-state.md / finalize-state.md /
    # methodology-analysis-state.md 之一）意味着 RLCR 循环
    # 不再为该会话写入缓存日志。
    _TERMINAL_STATE_SUFFIXES = (
        'cancel-state.md',
        'complete-state.md',
        'stop-state.md',
        'maxiter-state.md',
        'unexpected-state.md',
        'finalize-state.md',
        'methodology-analysis-state.md',
    )

    def _session_is_active(self, session_id):
        session_dir = os.path.join(self.rlcr_dir, session_id)
        if not os.path.isdir(session_dir):
            return False
        if not os.path.isfile(os.path.join(session_dir, 'state.md')):
            return False
        # `finalize-state.md` 和 `methodology-analysis-state.md`
        # 代表瞬态的会话结束阶段，技术上缓存日志仍然可以落地，
        # 但 RLCR 循环在几秒内完成写入；出于监视器分配的目的
        # 将它们视为终端——`_schedule_event()` 中的惰性重试会在
        # 转换后实际出现缓存日志文件时带回观察者。
        for suffix in self._TERMINAL_STATE_SUFFIXES:
            if os.path.isfile(os.path.join(session_dir, suffix)):
                return False
        return True

    def start(self):
        if not os.path.isdir(self.rlcr_dir):
            os.makedirs(self.rlcr_dir, exist_ok=True)

        handler = RLCREventHandler(self.rlcr_dir, self.broadcast)
        # 钩住会话创建事件，以便在新会话目录出现时立即启动
        # 缓存日志观察者；也钩住会话结束事件，以便在终端状态
        # 标记落地时拆除观察者。
        handler.on_session_created = self._start_cache_observer
        handler.on_session_finished = self._stop_cache_observer
        self.observer = Observer()
        self.observer.schedule(handler, self.rlcr_dir, recursive=True)
        self.observer.daemon = True
        self.observer.start()

        # 仅为当前在磁盘上活跃的会话启动缓存观察者。积累了
        # 数十个已完成会话的项目过去在启动时为每个会话启动
        # 一个观察者，这在繁忙主机上很快耗尽 inotify / watchdog
        # 槽位并使广播路径失效。已完成的会话不会写入新的
        # round-*.log 文件，因此根本不需要监视器。
        try:
            for entry in os.listdir(self.rlcr_dir):
                if not os.path.isdir(os.path.join(self.rlcr_dir, entry)):
                    continue
                if self._session_is_active(entry):
                    self._start_cache_observer(entry)
        except OSError:
            pass

    def _start_cache_observer(self, session_id):
        """尽最大努力：为 ``session_id`` 附加缓存目录观察者。

        当缓存目录尚不存在时静默跳过（启动竞态——RLCR 循环
        仅在第一轮触发后才创建它）。在会话的第一个
        ``round_added`` 事件时启动新观察者，因此启动时不存在
        的情况自然被 ``_schedule_event`` 的后续重试覆盖。
        """
        with self._cache_lock:
            if session_id in self._cache_observers:
                return
        # 防御性措施：防止为在此回调飞行期间已转换到终端状态
        # 的会话重新启动观察者（当广播事件跨越循环结束边界时
        # 很常见）。
        if not self._session_is_active(session_id):
            return
        cache_dir = rlcr_sources.cache_dir_for_session(self.project_dir, session_id)
        if not cache_dir or not os.path.isdir(cache_dir):
            return
        handler = _CacheLogBroadcastHandler(session_id, self.broadcast)
        obs = Observer()
        try:
            obs.schedule(handler, cache_dir, recursive=False)
            obs.daemon = True
            obs.start()
        except Exception:
            return
        with self._cache_lock:
            # 在锁下重新检查：另一个线程可能与我们竞争。
            if session_id in self._cache_observers:
                try:
                    obs.stop()
                except Exception:
                    pass
                return
            self._cache_observers[session_id] = obs

    def _stop_cache_observer(self, session_id):
        """为已完成的会话拆除缓存目录观察者。

        在终端状态标记出现时从 ``RLCREventHandler`` 调用。
        对从未有过观察者的会话也可以安全调用——锁保护的
        映射查找在这种情况下是空操作。
        """
        with self._cache_lock:
            obs = self._cache_observers.pop(session_id, None)
        if obs is None:
            return
        try:
            obs.stop()
            obs.join(timeout=2)
        except Exception:
            pass

    def stop(self):
        if self.observer:
            self.observer.stop()
            self.observer.join(timeout=5)
        with self._cache_lock:
            observers = list(self._cache_observers.values())
            self._cache_observers.clear()
        for obs in observers:
            try:
                obs.stop()
                obs.join(timeout=2)
            except Exception:
                pass


class CacheLogEventHandler(FileSystemEventHandler):
    """将缓存日志文件系统事件映射到每文件回调。

    回调签名为 ``callback(filepath: str)``。处理程序对监视的
    缓存目录内任何常规文件的修改、创建或删除触发回调；
    消费者（通常是 :class:`log_streamer.LogStream`）随后负责
    将该信号转换为流式协议契约的 snapshot/append/resync/eof
    事件。
    """

    def __init__(self, cache_dir, callback):
        super().__init__()
        self.cache_dir = cache_dir
        self.callback = callback

    def on_any_event(self, event):
        if event.is_directory:
            return
        try:
            self.callback(str(event.src_path))
        except Exception:
            # 回调不得使观察者线程崩溃。
            pass


class CacheLogWatcher:
    """监视每会话缓存目录的实时日志变更。

    仪表板将此与 :class:`SessionWatcher` 一起使用：
    ``SessionWatcher`` 为本地主机绑定的 WebSocket 客户端
    携带粗粒度的会话元数据事件，而 ``CacheLogWatcher``
    支持每会话 SSE 流的实时日志字节。后者是发出协议契约
    要求的每文件追加事件的唯一路径。
    """

    def __init__(self, cache_dir, callback):
        self.cache_dir = cache_dir
        self.callback = callback
        self.observer = None

    def start(self):
        if not os.path.isdir(self.cache_dir):
            # 启动竞态：缓存目录可能尚不存在。SSE 处理程序
            # 仍然可以惰性轮询，并在目录出现时稍后启动监视器。
            return False
        handler = CacheLogEventHandler(self.cache_dir, self.callback)
        self.observer = Observer()
        self.observer.schedule(handler, self.cache_dir, recursive=False)
        self.observer.daemon = True
        self.observer.start()
        return True

    def stop(self):
        if self.observer:
            self.observer.stop()
            self.observer.join(timeout=5)
            self.observer = None
