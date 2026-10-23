---
id: source-teco-ops-agent-ops-sdaa-op-template-references-rma-safety-rules-01b80746
title: "teco-ops-agent ops: sdaa-op-template/references/rma-safety-rules.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/rma-safety-rules.md
relative_source_path: sdaa-op-template/references/rma-safety-rules.md
captured_at: 2026-08-04
---

# RMA 安全用法与交付门禁

本文面向 `swdnn_test_ops/src/<op>/<op>.swcu` 的算子实现。只要 kernel 中使用
`rt_rma_iput` / `rt_rma_iget`，必须先满足这里的规则，再进入 L3 验证。

## 1. Reply 变量

异步 RMA 有本地 reply 和远端 reply。远端 reply 会被另一个 SPE 的 RMA 硬件写入，
所以它必须位于所有 SPE 都一致的 LDM 偏移。不要使用栈变量或普通局部变量作为
RMA reply。

正确做法：

```cpp
__rt_local_rply = 0;
__rt_remote_rply = 0;
rt_rma_iput(
    src,
    (void *)&__rt_local_rply,
    bytes,
    dst_tid,
    dst,
    (void *)&__rt_remote_rply);
rt_rma_wait_value(&__rt_remote_rply, 1);
while (__rt_local_rply < 1) {
}
```

禁止做法：

```cpp
volatile int local_reply = 0;
volatile int remote_reply = 0;
rt_rma_iput(src, &local_reply, bytes, dst_tid, dst, &remote_reply);
```

原因：普通局部变量可能被编译器放在不同 SPE 的不同 LDM 偏移，远端写 reply 时会写错
位置，表现为 `rt_rma_wait_value` 或手动轮询永久等待。

## 2. Reply 生命周期

- 每批异步 RMA 发起前，先把对应 reply 清零。
- 等待远端完成用 `rt_rma_wait_value(&__rt_remote_rply, expected_count)`。
- 等待本地发送完成用 `while (__rt_local_rply < expected_count) {}` 或等价等待。
- 同一个 reply 变量不要混用 DMA 和 RMA。
- 同一批发多个 RMA 时，`expected_count` 必须等于实际发起次数。

## 3. 远端写入缓冲

同一批未等待完成的多个 `rt_rma_iput` 不能写入同一块接收缓冲，否则后到的数据会覆盖先到
的数据，或者接收端读到未定义的混合结果。

正确做法：为每一路 RMA 分配独立区域。

```cpp
const int block_elems = elem_count / 4;
float *rma_buf = (float *)rt_ldm_malloc(3 * block_elems * sizeof(float));

rt_rma_iput(src_0, (void *)&__rt_local_rply, bytes, tid_0,
            rma_buf, (void *)&__rt_remote_rply);
rt_rma_iput(src_1, (void *)&__rt_local_rply, bytes, tid_1,
            rma_buf + block_elems, (void *)&__rt_remote_rply);
rt_rma_iput(src_2, (void *)&__rt_local_rply, bytes, tid_2,
            rma_buf + 2 * block_elems, (void *)&__rt_remote_rply);
rt_rma_wait_value(&__rt_remote_rply, 3);
```

禁止做法：

```cpp
rt_rma_iput(src_0, (void *)&__rt_local_rply, bytes, tid_0,
            rma_buf, (void *)&__rt_remote_rply);
rt_rma_iput(src_1, (void *)&__rt_local_rply, bytes, tid_1,
            rma_buf, (void *)&__rt_remote_rply);
```

## 4. 与 partial workspace 的关系

RMA reduce 后如果还要跨 K/N/M 分块累加 partial C，workspace 索引必须覆盖所有会并行或
循环复用的维度。GEMM 类算子至少要区分：

```text
(m_tile, n_tile, n_chunk, k_chunk or tid)
```

不要只按 `m_tile` 或 `k_chunk` 存 partial C；这样多 N chunk 或多 K chunk 时会互相覆盖。

## 5. check_delivery 静态门禁

`check_delivery.py` 会对 `.swcu` 做基础静态检查：

- 不使用异步 RMA：直接通过 RMA safety step。
- 使用 `rt_rma_iput` / `rt_rma_iget`：源码必须包含 `__rt_local_rply` 和
  `__rt_remote_rply`。
- 异步 RMA 调用的 reply 参数不能是普通局部 `volatile int` 变量。
- 同一段源码里如果连续多次 `rt_rma_iput` 后才等待，接收目的地址必须能区分不同区域。

静态门禁只覆盖高风险错误，不能替代 L3。RMA kernel 仍必须在宿主机非沙箱环境跑
`torch_verify.py`，并以 `success_rate: 1.0` 作为最终精度门禁。
