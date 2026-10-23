# 流式协议契约

## 状态
于 2026 年 4 月 17 日冻结。任何变更都需要在下方追加一个新的带日期的修订部分。

## 范围
本契约管理为单个服务器项目从 `XDG_CACHE_HOME` 或 `HOME/.cache/humanize/SANITIZED/SID/round-N-{codex,gemini}-{run,review}.log` 发现的 RLCR 轮次日志文件的实时流式传输，其中 `SANITIZED` 遵循 `viz/server/rlcr_sources.py` 中实现的规则。会话身份和活跃性从 `.humanize/rlcr/SID/` 元数据派生，但本契约不定义前置状态文件、目标跟踪器文件、轮次摘要或审查结果文件的轮询、解析或 REST 获取。

## 通道模型
流按会话和文件划分。流由 `GET /api/sessions/SID/logs/FNAME` 标识，其中 `SID` 是 RLCR 会话 ID，`FNAME` 是精确的日志文件基本名称，如 `round-3-codex-run.log`。每个 URL 映射到一个会话内一个文件生成的一个逻辑字节流。多个会话可以同时处于活动状态，客户端可以并行打开多个此类通道。

## 事件格式
实时日志传输使用 Server-Sent Events。每个 SSE 帧必须包含 `event: TYPE`、`id: N`，以及一行恰好包含一个 JSON 对象的 `data:` 行。`TYPE` 必须等于 JSON 的 `type` 字段。`id` 必须是流内严格递增的十进制字符串。`path` 必须是通道的规范 `FNAME`，而非绝对文件系统路径。原始文件字节必须使用标准 RFC 4648 base64 编码为 `bytes_b64`，且不带换行符。载荷类型如下：`snapshot` = `{ "type": "snapshot", "path": "...", "offset": 0, "bytes_b64": "...", "eof": false }`；`append` = `{ "type": "append", "path": "...", "offset": N, "bytes_b64": "..." }`；`resync` = `{ "type": "resync", "path": "...", "reason": "truncated|rotated|recreated|missing|overflow" }`；`eof` = `{ "type": "eof", "path": "..." }`。`offset` 是 `bytes_b64` 所表示的起始字节偏移量。

## 截断和轮转重同步
服务器必须跟踪每个流最后发出的字节偏移量，并且在 POSIX 系统上还必须跟踪当前打开文件的 `(st_dev, st_ino)`。如果观察到的大小缩小到最后已知偏移量以下，或 `(st_dev, st_ino)` 发生变化，或文件消失，服务器必须发出 `resync`，并且必须在当前文件生成可读时立即从偏移量 `0` 重新启动通道并发送新的 `snapshot`。

## Snapshot 与 Append 语义
后加入的客户端必须先接收 `snapshot`。此后，仅流动 `append` 事件，直到触发重同步条件。初始 snapshot 必须按每个事件最大 `64 KiB` 原始字节进行分块；因此大文件会生成多个有序的 `snapshot` 事件，其 `offset` 值递增直到当前 EOF。`snapshot.eof=true` 仅可在文件在 snapshot 时刻已经终止时使用。

## 传输映射
当服务器主机不是 `127.0.0.1` 时，实时日志必须仅通过 HTTPS 上的 SSE 传输，客户端必须在流 URL 上使用 `?token=BEARER` 进行身份验证。在此模式下，WebSocket 端点必须被禁用或不可达。当服务器主机等于 `127.0.0.1` 时，SSE 仍是实时日志传输方式；`flask_sock` WebSocket 可以提供粗粒度的会话级通知（如 `session-list-changed`），但不得传输逐文件的 append 数据。

## 重连行为
断开连接时，客户端应重新连接到相同的流 URL 并发送 `Last-Event-Id`。服务器必须为每个流保留最近 `256` 个事件，并在可用时重放所有比该 ID 更新的事件。如果请求的 ID 比保留的历史记录更旧或对当前文件生成无效，服务器必须通过发出 `resync` 然后从偏移量 `0` 发送新的 `snapshot` 来恢复。

## 延迟预算
在单个项目的标称负载下，最多 `5` 个并发活动会话，且每个流的 append 速率不超过 `100 KB/s` 时，中位 append 到渲染延迟必须 `<= 2.0s`。尾部 `p95` 延迟必须 `<= 5.0s`。CI 中中位断言失败必须导致构建失败。

## 背压
如果客户端无法跟上，服务器可以丢弃该流最旧的待处理或已保留的 `append` 事件，但必须发出一个原因为 `overflow` 的最终 `resync`，然后提供新的 `snapshot`。禁止静默数据丢失。

## 范围之外
本契约不定义 `POST /api/sessions/SID/cancel` 的取消控制通道、项目切换、守护进程生命周期、令牌签发或验证、粗粒度会话列表事件，或任何非日志的 REST 载荷。这些接口需要各自的规范。

## 示例事件流
```text
event: snapshot
id: 101
data: {"type":"snapshot","path":"round-3-codex-run.log","offset":0,"bytes_b64":"U3RhcnQK","eof":false}

event: append
id: 102
data: {"type":"append","path":"round-3-codex-run.log","offset":6,"bytes_b64":"TW9yZQo="}

event: append
id: 103
data: {"type":"append","path":"round-3-codex-run.log","offset":11,"bytes_b64":"RGF0YQo="}

event: resync
id: 104
data: {"type":"resync","path":"round-3-codex-run.log","reason":"rotated"}

event: snapshot
id: 105
data: {"type":"snapshot","path":"round-3-codex-run.log","offset":0,"bytes_b64":"TmV3IGZpbGUK","eof":false}
```
