---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-learned-patterns-pitfalls-small-side-input-prefetch-contention-dfef799c
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/learned-patterns/pitfalls/small-side-input-prefetch-contention.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/learned-patterns/pitfalls/small-side-input-prefetch-contention.md
relative_source_path: sdaa-op-learning-validation/references/learned-patterns/pitfalls/small-side-input-prefetch-contention.md
captured_at: 2026-08-04
---

# Pattern: 小型 side input 预取与主 gather 争用 DMA

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

流水中存在阻塞的少量 side input 搬运时，直接增加 LDM 双缓冲并把下一轮 `rt_dma_iget` 前移，
不一定能缩短关键路径。若 steady state 已包含大量细粒度 gather，请求队列和 DMA 带宽争用可能
大于被隐藏的阻塞搬运耗时。

## 适用场景

- 每轮先读取 indices、metadata、offset 或 mask 等小型 side input。
- 主计算阶段还会持续发射多笔 HBM 到 LDM 的 gather DMA。
- 候选方案希望让下一轮 side input DMA 与当前轮主计算重叠。
- side input 的 producer/consumer ownership 可以用 ping/pong 和 reply 正确表达。

## 不适用场景

- 性能计数已证明 side input wait 是主要暴露等待。
- side input 与主数据搬运使用独立 DMA 资源或独立队列。
- 主计算阶段几乎不发 DMA，请求前移不会造成争用。
- 目标 shape 的同口径 benchmark 已证明双缓冲稳定受益。

## 核心思路

阻塞 API 不等于关键路径瓶颈。先量化 wait 暴露，再决定是否把 side input 搬运移入 steady state；
流水模型必须同时计算被删除的 wait 和新增的 DMA 争用。

## 实现规则

- 先保留单 buffer，测量 side input 的独立 DMA 周期或 wait 占比。
- 双缓冲 attempt 只改 side input buffer、reply 和 wait，不同时修改主 gather 或计算 tile。
- 若入口预取回退，可做一次死亡点 tail prefetch 消融，判断是否只是主 gather 窗口争用。
- 明确 ping/pong ownership：DMA 完成前 buffer 属于 producer，当前轮全部消费者结束后才能复用。
- 对照至少包含 baseline、双缓冲候选和恢复 baseline。
- 分 head、tile 数或主 gather 请求数观察回退是否随 steady-state DMA 压力增大。
- 若大 shape 回退而小 shape 仅噪声级改善，默认恢复阻塞 fill-stage 搬运。

## 关键参数与资源预算

- 已验证 side input：每 query `512 x int32 = 2 KiB` indices。
- 双缓冲额外增加 2 KiB LDM 和一组 reply/请求状态。
- 主循环每 query 有 16 个 `N_BLOCK=32` 稀疏 KV tile，每个 tile 会发射多笔 gather DMA。
- 容量满足只证明方案可运行，不证明 DMA 队列存在可用 overlap 窗口。

## 架构与数据流

基线：

```text
blocking indices[q] -> 16轮 KV gather + QK/softmax/SV
```

退化候选：

```text
indices[q+1] iget ──────────────┐
16轮 KV gather[q] + compute[q]  │
        共享 DMA 队列和带宽 <───┘
```

## 从朴素实现到优化实现

- 候选实现删除每轮入口的阻塞 indices load，将 wait 延迟到下一轮首次消费点。
- 实测精度正确，但 head16/head8 显著回退，说明搬运前移没有形成净 overlap。
- 把请求进一步移动到最后一次 indices 消费之后，回退幅度几乎不变；因此前段 gather 争用
  不是唯一因素，跨 query 异步请求的建立、完成和与 Q/output DMA 的排序也必须计入。
- 恢复实现把 2 KiB side input 留在 fill stage，避免污染主 gather 的 steady state。

## 选型决策

- 只有 side input wait 在 timeline 中明显暴露时，才优先尝试双缓冲。
- steady state 已经由细粒度 gather 主导时，优先减少 gather 请求数或提高合并度。
- 单个低并行 shape 的微小收益不能覆盖其他主 shape 的稳定回退。
- 若未来 DMA 队列、调度策略或 gather 粒度变化，需要重新验证。

## 伪代码

```cpp
for (query : queries) {
    dma_get(indices, query_indices, indices_bytes);
    run_sparse_gather_compute(indices);
}
```

不要在没有 wait 证据时默认改成：

```cpp
wait(indices_reply[tag]);
issue_indices_iget(next_tag);
run_sparse_gather_compute(indices[tag]);
```

## 常见坑

- 看到 `rt_dma_get` 就认为改成 `rt_dma_iget` 必然更快。
- 只核算 LDM 容量，不核算未完成请求数、描述符开销和 DMA 带宽竞争。
- wait 延迟后只检查时间线位置，没有比较主 gather 本身是否变慢。
- 只看一个轻载 shape 的亚百分比收益，忽略重载 shape 的显著回退。

## 自检清单

- side input wait 在 baseline 中是否真实暴露？
- steady state 同时有多少主 gather DMA 请求？
- 双缓冲是否增加未完成请求峰值？
- 是否完成 target 全部主 shape 的同时间点对照？
- 回退后是否恢复并重新编译复测 baseline？

## 验证

- 目标算子：`flash_mla_sparse` N32 跨 query prefill。
- 失败 stage：`v6_prefill_n32_indices_double_buffer`。
- Shape：`q_seq=kv_seq=65536`，`topk=512`，`qk_dim=v_dim=512`，`q_head=16/8/4`。
- 基线：`231.564/183.701/175.972 ms`。
- 双 indices：`255.474/192.451/175.114 ms`，head16/head8 回退 `10.33%/4.76%`，
  head4 单次改善 `0.49%`。
- 单 buffer tail prefetch 消融：`255.429/192.319/174.902 ms`，head16/head8仍回退
  `10.33%/4.71%`，与入口预取基本一致。
- 精度 3/3 通过；恢复态为 `231.514/183.675/175.952 ms`，回到基线。
- evidence: pipeline-v6-small-side-input-prefetch-contention
- evidence: pipeline-v7-tail-side-input-prefetch-contention

## 来源沿革

- 原始失败 stage 已蒸馏到 evidence `pipeline-v6-small-side-input-prefetch-contention`。
- tail prefetch 消融已蒸馏到 evidence `pipeline-v7-tail-side-input-prefetch-contention`。
- 结论只推广为 DMA 流水选型反例，不推广该算子的 shape 常量或代码结构。

## 相关模式

- `pipeline/cross-query-persistent-attention`
- `dma/pair-stride-gather`
- `pitfalls/next-qk-before-current-sv`
