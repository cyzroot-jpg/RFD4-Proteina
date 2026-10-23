#!/usr/bin/env bash
#
# viz/server/log_streamer.py 的行为测试以及流式块（T3+T4+T5）
# 中添加的解析器/监视器扩展。
#
# 覆盖 docs/streaming-protocol.md 中的契约：
#   - 现有文件的快照（以 64 KiB 分块）
#   - 写入新字节后追加
#   - 截断：文件大小缩小到已知偏移量以下
#   - 轮转：相同路径，新 inode
#   - 启动时文件缺失：无事件，无崩溃
#   - 缺失后重新出现：resync(recreated) + 新快照
#   - EOF：后续轮询为空操作
#   - 使用 Last-Event-Id 重放：窗口内返回较新事件；
#     窗口外返回 resync(overflow)
#   - 解析器 cache_logs_for_session 集成 rlcr_sources 发现
#
# 无网络访问；所有夹具位于每个测试的 mktemp 树下。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VIZ_SERVER_DIR="$PLUGIN_ROOT/viz/server"

echo "========================================"
echo "Streaming block (T3+T4+T5)"
echo "========================================"

if ! command -v python3 &>/dev/null; then
    echo "SKIP: python3 not available"
    exit 0
fi

PASS_COUNT=0
FAIL_COUNT=0

_pass() { printf '\033[0;32mPASS\033[0m: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { printf '\033[0;31mFAIL\033[0m: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CACHE_DIR="$TMP_DIR/cache"
mkdir -p "$CACHE_DIR"

# 辅助函数：运行 python 驱动器并捕获其输出
_run_py() {
    python3 -c "
import sys
sys.path.insert(0, '$VIZ_SERVER_DIR')
$1
"
}

# ─── 测试组 1：启动时文件缺失 ───
echo
echo "Group 1: Missing file at startup"

OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-0-codex-run.log')
events = stream.snapshot()
print('SNAPSHOT_COUNT:', len(events))
events = stream.poll()
for e in events:
    print('POLL:', e['type'], e.get('reason', ''))
")"

if grep -q '^SNAPSHOT_COUNT: 0$' <<<"$OUTPUT"; then
    _pass "snapshot of missing file emits no events"
else
    _fail "expected 0 snapshot events, got: $(grep '^SNAPSHOT_COUNT' <<<"$OUTPUT")"
fi

if grep -q '^POLL: resync missing$' <<<"$OUTPUT"; then
    _pass "first poll of missing file emits resync(missing)"
else
    _fail "expected resync(missing) on first poll, got: $(grep '^POLL:' <<<"$OUTPUT")"
fi

# ─── 测试组 2：现有文件快照 ───
echo
echo "Group 2: Snapshot of existing file"

LOG="$CACHE_DIR/round-1-codex-run.log"
printf 'hello world' > "$LOG"

OUTPUT="$(_run_py "
import base64
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-1-codex-run.log')
events = stream.snapshot()
print('COUNT:', len(events))
for e in events:
    print('TYPE:', e['type'])
    print('OFFSET:', e['offset'])
    print('BYTES:', base64.b64decode(e['bytes_b64']).decode('ascii'))
    print('EOF:', e['eof'])
")"

if grep -q '^COUNT: 1$' <<<"$OUTPUT"; then
    _pass "snapshot emits one event for small file"
else
    _fail "expected 1 snapshot event, got: $(grep '^COUNT' <<<"$OUTPUT")"
fi

if grep -q '^TYPE: snapshot$' <<<"$OUTPUT" && grep -q '^OFFSET: 0$' <<<"$OUTPUT" && grep -q '^BYTES: hello world$' <<<"$OUTPUT" && grep -q '^EOF: False$' <<<"$OUTPUT"; then
    _pass "snapshot payload contains 'hello world' at offset 0 with eof=False"
else
    _fail "snapshot payload wrong: $OUTPUT"
fi

# ─── 测试组 3：写入后追加 ───
echo
echo "Group 3: Append after writes"

OUTPUT="$(_run_py "
import base64
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-1-codex-run.log')
stream.snapshot()
with open('$LOG', 'ab') as f:
    f.write(b' more')
events = stream.poll()
for e in events:
    print('TYPE:', e['type'])
    print('OFFSET:', e['offset'])
    print('BYTES:', base64.b64decode(e['bytes_b64']).decode('ascii'))
")"

if grep -q '^TYPE: append$' <<<"$OUTPUT" && grep -q '^OFFSET: 11$' <<<"$OUTPUT" && grep -q '^BYTES:  more$' <<<"$OUTPUT"; then
    _pass "poll after append emits append event with correct offset and bytes"
else
    _fail "append event wrong: $OUTPUT"
fi

# ─── 测试组 4：截断触发 resync + 新快照 ───
echo
echo "Group 4: Truncation"

OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-1-codex-run.log')
stream.snapshot()
# Truncate file to a smaller size in place
with open('$LOG', 'wb') as f:
    f.write(b'short')
events = stream.poll()
for e in events:
    print('TYPE:', e['type'], e.get('reason', ''), 'OFFSET:', e.get('offset', '-'))
")"

# 期望：resync(truncated)，snapshot
if grep -q '^TYPE: resync truncated' <<<"$OUTPUT" && grep -q '^TYPE: snapshot' <<<"$OUTPUT"; then
    _pass "truncation triggers resync(truncated) followed by fresh snapshot"
else
    _fail "truncation behavior wrong: $OUTPUT"
fi

# ─── 测试组 5：轮转（inode 变更）───
echo
echo "Group 5: Rotation (file recreated with different inode)"

ROTLOG="$CACHE_DIR/round-2-codex-run.log"
printf 'first generation' > "$ROTLOG"

OUTPUT="$(_run_py "
import os
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-2-codex-run.log')
stream.snapshot()
# Rotate: rm + recreate produces a new inode
os.unlink('$ROTLOG')
with open('$ROTLOG', 'wb') as f:
    f.write(b'new generation')
events = stream.poll()
for e in events:
    print('TYPE:', e['type'], e.get('reason', ''))
")"

# 如果轮询发生在 unlink 和 recreate 之间，可能先看到 resync(missing)；
# 在此测试中 recreate 是同步的，因此我们期望 resync(rotated) 后跟快照。
# 只要 resync 发生且快照跟随，允许任一模式。
if grep -q '^TYPE: resync' <<<"$OUTPUT" && grep -q '^TYPE: snapshot' <<<"$OUTPUT"; then
    _pass "rotation triggers resync followed by fresh snapshot"
else
    _fail "rotation behavior wrong: $OUTPUT"
fi

# ─── 测试组 6：缺失后重新出现 ───
echo
echo "Group 6: Missing file reappears"

REAP="$CACHE_DIR/round-3-codex-run.log"
OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-3-codex-run.log')
# Initial poll: file missing, expect resync(missing)
events = stream.poll()
for e in events:
    print('FIRST:', e['type'], e.get('reason', ''))
# Now create the file
with open('$REAP', 'wb') as f:
    f.write(b'hello')
events = stream.poll()
for e in events:
    print('SECOND:', e['type'], e.get('reason', ''))
")"

if grep -q '^FIRST: resync missing$' <<<"$OUTPUT" && \
   grep -q '^SECOND: resync recreated$' <<<"$OUTPUT" && \
   grep -q '^SECOND: snapshot ' <<<"$OUTPUT"; then
    _pass "missing -> reappear triggers resync(recreated) followed by snapshot"
else
    _fail "reappear behavior wrong: $OUTPUT"
fi

# ─── 测试组 7：EOF + 后续轮询 ───
echo
echo "Group 7: EOF marking is sticky"

EOFLOG="$CACHE_DIR/round-4-codex-run.log"
printf 'done' > "$EOFLOG"
OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-4-codex-run.log')
stream.snapshot()
events = stream.mark_eof()
print('EOF:', events[0]['type'])
events = stream.mark_eof()
print('SECOND_EOF_COUNT:', len(events))
events = stream.poll()
print('POLL_AFTER_EOF_COUNT:', len(events))
")"

if grep -q '^EOF: eof$' <<<"$OUTPUT" && \
   grep -q '^SECOND_EOF_COUNT: 0$' <<<"$OUTPUT" && \
   grep -q '^POLL_AFTER_EOF_COUNT: 0$' <<<"$OUTPUT"; then
    _pass "eof event is one-shot; subsequent polls and eof are no-ops"
else
    _fail "eof stickiness wrong: $OUTPUT"
fi

# ─── 测试组 8：使用 Last-Event-Id 重放 ───
echo
echo "Group 8: Replay with Last-Event-Id"

REPLOG="$CACHE_DIR/round-5-codex-run.log"
printf 'aaaaa' > "$REPLOG"

OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-5-codex-run.log')
snap = stream.snapshot()  # id 1
# Append twice
with open('$REPLOG', 'ab') as f:
    f.write(b'BBB')
ap1 = stream.poll()       # id 2
with open('$REPLOG', 'ab') as f:
    f.write(b'CCC')
ap2 = stream.poll()       # id 3
# Client only saw up through id 2; replay starting from id 2
replayed, in_window = stream.replay(2)
print('REPLAY_IN_WINDOW:', in_window)
print('REPLAY_COUNT:', len(replayed))
for e in replayed:
    print('REPLAY_ID:', e['id'], 'TYPE:', e['type'])
# Out-of-window: replay from a tiny id with retention exceeded
# Force overflow by manipulating retention; small fixture so replay an id below the window
# Retention is 256 so we cannot easily exceed it; just verify replay(0) returns ALL retained
all_replay, all_in_window = stream.replay(0)
print('REPLAY_ALL_COUNT:', len(all_replay))
print('REPLAY_ALL_IN_WINDOW:', all_in_window)
")"

if grep -q '^REPLAY_IN_WINDOW: True$' <<<"$OUTPUT" && \
   grep -q '^REPLAY_COUNT: 1$' <<<"$OUTPUT" && \
   grep -q '^REPLAY_ID: 3 TYPE: append$' <<<"$OUTPUT"; then
    _pass "in-window replay returns events newer than Last-Event-Id"
else
    _fail "in-window replay wrong: $OUTPUT"
fi

if grep -q '^REPLAY_ALL_COUNT: 3$' <<<"$OUTPUT" && grep -q '^REPLAY_ALL_IN_WINDOW: True$' <<<"$OUTPUT"; then
    _pass "replay(0) returns all retained events"
else
    _fail "replay(0) result wrong: $OUTPUT"
fi

# 同时验证窗口外：直接调用 replay，id 远小于窗口滑动后的最旧 id
OUTPUT_OW="$(_run_py "
from log_streamer import LogStream, EVENT_RETENTION
import os
log = '$CACHE_DIR/round-6-codex-run.log'
with open(log, 'wb') as f:
    f.write(b'')
stream = LogStream('$CACHE_DIR', 'round-6-codex-run.log')
# Generate enough events to overflow the retention window
for i in range(EVENT_RETENTION + 5):
    with open(log, 'ab') as f:
        f.write(b'x')
    stream.poll()
# Replay from id 1 - should be out of window now (oldest id in window is 6)
replayed, in_window = stream.replay(1)
print('OW_IN_WINDOW:', in_window)
print('OW_TYPE:', replayed[0]['type'], replayed[0].get('reason', ''))
")"

if grep -q '^OW_IN_WINDOW: False$' <<<"$OUTPUT_OW" && grep -q '^OW_TYPE: resync overflow$' <<<"$OUTPUT_OW"; then
    _pass "out-of-window replay emits resync(overflow)"
else
    _fail "out-of-window replay wrong: $OUTPUT_OW"
fi

# ─── 测试组 9：64 KiB 快照分块 ───
echo
echo "Group 9: Snapshot chunking"

BIGLOG="$CACHE_DIR/round-7-codex-run.log"
# 130 KiB 字节 -> 期望 3 个快照块（64,64,2）KiB
python3 -c "open('$BIGLOG','wb').write(b'x' * (130 * 1024))"

OUTPUT="$(_run_py "
from log_streamer import LogStream
stream = LogStream('$CACHE_DIR', 'round-7-codex-run.log')
events = stream.snapshot()
print('CHUNK_COUNT:', len(events))
total = sum(len(__import__('base64').b64decode(e['bytes_b64'])) for e in events)
print('TOTAL_BYTES:', total)
print('OFFSETS:', ','.join(str(e['offset']) for e in events))
")"

if grep -q '^CHUNK_COUNT: 3$' <<<"$OUTPUT" && \
   grep -q '^TOTAL_BYTES: 133120$' <<<"$OUTPUT" && \
   grep -q '^OFFSETS: 0,65536,131072$' <<<"$OUTPUT"; then
    _pass "130 KiB file is chunked into 3 snapshot events at 64 KiB boundaries"
else
    _fail "chunking wrong: $OUTPUT"
fi

# ─── 测试组 10：解析器集成（cache_logs_for_session）───
echo
echo "Group 10: parser.cache_logs_for_session"

PROJECT_ROOT="$TMP_DIR/proj"
SID="2026-04-17_99-99-99"
mkdir -p "$PROJECT_ROOT/.humanize/rlcr/$SID"
: > "$PROJECT_ROOT/.humanize/rlcr/$SID/state.md"

# 需要在 XDG_CACHE_HOME 下的 rlcr_sources 派生路径中播种缓存日志
PROJECT_CACHE_DIR="$TMP_DIR/cache_xdg/humanize/$(printf '%s' "$PROJECT_ROOT" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')/$SID"
mkdir -p "$PROJECT_CACHE_DIR"
: > "$PROJECT_CACHE_DIR/round-0-codex-run.log"
: > "$PROJECT_CACHE_DIR/round-1-codex-run.log"
: > "$PROJECT_CACHE_DIR/round-1-codex-review.log"

OUTPUT="$(XDG_CACHE_HOME="$TMP_DIR/cache_xdg" python3 -c "
import sys
sys.path.insert(0, '$VIZ_SERVER_DIR')
from parser import cache_logs_for_session
logs = cache_logs_for_session('$PROJECT_ROOT', '$SID')
print('LOG_COUNT:', len(logs))
for log in logs:
    print('LOG:', log['round'], log['tool'], log['role'], log['basename'])
")"

if grep -q '^LOG_COUNT: 3$' <<<"$OUTPUT"; then
    _pass "cache_logs_for_session returns 3 logs"
else
    _fail "cache_logs_for_session count wrong: $OUTPUT"
fi

if grep -q '^LOG: 0 codex run round-0-codex-run.log$' <<<"$OUTPUT" && \
   grep -q '^LOG: 1 codex review round-1-codex-review.log$' <<<"$OUTPUT" && \
   grep -q '^LOG: 1 codex run round-1-codex-run.log$' <<<"$OUTPUT"; then
    _pass "cache_logs_for_session returns deterministic ordering with full metadata"
else
    _fail "cache_logs_for_session ordering wrong: $OUTPUT"
fi

# ─── 测试组 11：共享流注册表 + 重连语义 ───
echo
echo "Group 11: LogStreamRegistry + reconnect semantics"

REGLOG="$CACHE_DIR/round-8-codex-run.log"
printf 'initial' > "$REGLOG"

OUTPUT="$(_run_py "
from log_streamer import LogStreamRegistry, LogStream
reg = LogStreamRegistry()
s1 = reg.get_or_create('$CACHE_DIR', 'sid-A', 'round-8-codex-run.log')
s2 = reg.get_or_create('$CACHE_DIR', 'sid-A', 'round-8-codex-run.log')
print('SAME:', s1 is s2)
print('LEN_AFTER_DUP_KEY:', len(reg))
s3 = reg.get_or_create('$CACHE_DIR', 'sid-B', 'round-8-codex-run.log')
print('DIFFERENT:', s1 is not s3)
print('LEN_AFTER_NEW_KEY:', len(reg))
# streams_in_cache_dir 返回两个目标为相同基名的流
streams = reg.streams_in_cache_dir('$CACHE_DIR', 'round-8-codex-run.log')
print('STREAMS_FOR_BASENAME:', len(streams))
")"

if grep -q '^SAME: True$' <<<"$OUTPUT" && \
   grep -q '^LEN_AFTER_DUP_KEY: 1$' <<<"$OUTPUT" && \
   grep -q '^DIFFERENT: True$' <<<"$OUTPUT" && \
   grep -q '^LEN_AFTER_NEW_KEY: 2$' <<<"$OUTPUT" && \
   grep -q '^STREAMS_FOR_BASENAME: 2$' <<<"$OUTPUT"; then
    _pass "registry returns same instance for same key, distinct for different keys"
else
    _fail "registry sharing wrong: $OUTPUT"
fi

# 重连模拟：客户端看到 id=N 为止的事件；使用 Last-Event-Id=N
# 对同一注册流的第二次连接必须只接收比 N 更新的事件，
# 永远不会从偏移 0 收到 `append`。
OUTPUT="$(_run_py "
from log_streamer import LogStreamRegistry
reg = LogStreamRegistry()
stream = reg.get_or_create('$CACHE_DIR', 'sid-A', 'round-8-codex-run.log')
# Simulate first client: snapshot then one append
snap_events = stream.snapshot()
with open('$REGLOG', 'ab') as f:
    f.write(b' APPENDED')
append_events = stream.poll()
# Client last saw the snapshot id
client_last = snap_events[-1]['id']
# Second client reconnects via the registry with Last-Event-Id=client_last
same_stream = reg.get_or_create('$CACHE_DIR', 'sid-A', 'round-8-codex-run.log')
replayed, in_window = same_stream.replay(client_last)
print('IN_WINDOW:', in_window)
print('REPLAY_COUNT:', len(replayed))
print('REPLAY_TYPES:', ','.join(e['type'] for e in replayed))
print('REPLAY_OFFSETS:', ','.join(str(e.get('offset', -1)) for e in replayed))
print('APPEND_STARTS_AFTER_SNAP:', all(e['offset'] >= snap_events[-1].get('offset', 0) + len(b'initial') for e in replayed if e['type'] == 'append'))
")"

if grep -q '^IN_WINDOW: True$' <<<"$OUTPUT" && \
   grep -q '^REPLAY_TYPES: append$' <<<"$OUTPUT" && \
   grep -q '^APPEND_STARTS_AFTER_SNAP: True$' <<<"$OUTPUT"; then
    _pass "reconnect via shared registry replays events newer than Last-Event-Id, no append from offset 0"
else
    _fail "reconnect semantics wrong: $OUTPUT"
fi

# 使用来自不同流的 Last-Event-Id 重连（对此流未知）
# 必须产生 resync(overflow) + 快照路径，而不是从偏移 0 追加。
OUTPUT="$(_run_py "
from log_streamer import LogStreamRegistry, EVENT_RETENTION
reg = LogStreamRegistry()
stream = reg.get_or_create('$CACHE_DIR', 'sid-reconnect-fresh', 'round-8-codex-run.log')
# Exhaust the retention window by producing a large number of events
# so a Last-Event-Id from before the window becomes out-of-window.
import os
for _ in range(EVENT_RETENTION + 2):
    with open('$REGLOG', 'ab') as f:
        f.write(b'X')
    stream.poll()
# Now reconnect with an ancient Last-Event-Id
replayed, in_window = stream.replay(1)
print('IN_WINDOW:', in_window)
print('FIRST_TYPE:', replayed[0]['type'], replayed[0].get('reason', ''))
print('NO_APPEND_OFFSET_ZERO_FIRST:', not (replayed[0]['type'] == 'append' and replayed[0].get('offset') == 0))
")"

if grep -q '^IN_WINDOW: False$' <<<"$OUTPUT" && \
   grep -q '^FIRST_TYPE: resync overflow$' <<<"$OUTPUT" && \
   grep -q '^NO_APPEND_OFFSET_ZERO_FIRST: True$' <<<"$OUTPUT"; then
    _pass "out-of-window reconnect emits resync(overflow), NOT append from offset 0"
else
    _fail "out-of-window reconnect wrong: $OUTPUT"
fi

# ─── 无后续释放的空闲流驱逐 ───
# 回归：引用计数降至零但没有 EOF 的流在没有后续 release()
# 触发时不应永远存活。扫描也必须在其他注册表交互（acquire、
# streams_in_cache_dir）上运行，以便在低流量下回收空闲保留队列。
SWEEPLOG="$CACHE_DIR/round-9-codex-run.log"
: > "$SWEEPLOG"

OUTPUT="$(_run_py "
import time
from log_streamer import LogStreamRegistry
# 使用非零 TTL 并回退记录的空闲时间戳，使下次扫描观察到
# TTL 已过期而无需真实等待。在白盒回归测试中访问私有字典
# 是可接受的：重点是验证哪些调用点执行扫描，而非实时计时。
reg = LogStreamRegistry(idle_ttl_seconds=60.0)
# 流 A：一次性断开，无 EOF，同一键上无后续释放。
reg.acquire('$CACHE_DIR', 'sid-sweep-A', 'round-9-codex-run.log')
reg.release('sid-sweep-A', 'round-9-codex-run.log')
print('A_PRESENT_BEFORE_SWEEP:', ('sid-sweep-A', 'round-9-codex-run.log') in reg)
# 强制 A 的 idle_since 远在过去，使任何后续扫描驱逐它。
reg._idle_since[('sid-sweep-A', 'round-9-codex-run.log')] = time.monotonic() - 1e6
# 不同会话上的新 acquire 必须触发扫描。
reg.acquire('$CACHE_DIR', 'sid-sweep-B', 'round-9-codex-run.log')
print('A_EVICTED_BY_ACQUIRE:', ('sid-sweep-A', 'round-9-codex-run.log') not in reg)
print('B_PRESENT:', ('sid-sweep-B', 'round-9-codex-run.log') in reg)

# 独立注册表：验证 streams_in_cache_dir()（由缓存监视器回调
# 在每次观察到写入时调用）也会驱逐空闲流，即使没有后续 release()。
reg2 = LogStreamRegistry(idle_ttl_seconds=60.0)
reg2.acquire('$CACHE_DIR', 'sid-sweep-C', 'round-9-codex-run.log')
reg2.release('sid-sweep-C', 'round-9-codex-run.log')
reg2._idle_since[('sid-sweep-C', 'round-9-codex-run.log')] = time.monotonic() - 1e6
_ = reg2.streams_in_cache_dir('$CACHE_DIR', 'round-9-codex-run.log')
print('C_EVICTED_BY_STREAMS_LOOKUP:', ('sid-sweep-C', 'round-9-codex-run.log') not in reg2)
")"

if grep -q '^A_PRESENT_BEFORE_SWEEP: True$' <<<"$OUTPUT" && \
   grep -q '^A_EVICTED_BY_ACQUIRE: True$' <<<"$OUTPUT" && \
   grep -q '^B_PRESENT: True$' <<<"$OUTPUT" && \
   grep -q '^C_EVICTED_BY_STREAMS_LOOKUP: True$' <<<"$OUTPUT"; then
    _pass "idle streams are evicted by acquire() and streams_in_cache_dir(), not only by a follow-up release()"
else
    _fail "idle-stream sweep regression: $OUTPUT"
fi

# ─── 总结 ───
echo
echo "========================================"
printf 'Passed: \033[0;32m%d\033[0m\n' "$PASS_COUNT"
printf 'Failed: \033[0;31m%d\033[0m\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

printf '\033[0;32mAll streaming tests passed!\033[0m\n'
