---
id: local-learned-pattern-dma-pair-stride-gather
title: 固定大小记录的双元素 Stride DMA Gather
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/dma/pair-stride-gather.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/dma/pair-stride-gather.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- dma
- pair
- stride
- gather
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: 固定大小记录的双元素 Stride DMA Gather

## 状态

verified_by_stage

## 类型

optimization

## 问题

T1 的 `rt_dma_*` 没有任意地址列表一次提交的 gather 描述符。算子若按 `indices[]` 从 HBM 读取固定大小记录，并为每条记录单独发起 `rt_dma_iget`，会产生大量小 DMA issue，增加描述符和前端开销。

这里的“记录”是通用概念，可以是 tensor row、embedding vector、cache block、MoE token/expert slice、稀疏矩阵行或固定大小结构体，不限定为 attention KV 数据。

## 检索关键词与触发信号

- 机制关键词：`DMA gather`、`indexed load`、`index_select`、`pair stride`、`many small DMA`、`packed destination`、`fixed-size record`。
- 算子关键词：`embedding lookup`、`table lookup`、`sparse row`、`cache block`、`paged cache`、`MoE token gather`、`expert row gather`、`KV gather`。
- 代码信号：循环内地址形如 `source_base + indices[i] * record_bytes`，目标地址形如 `packed_dst + i * record_bytes`。
- 性能信号：一个 tile 发起较多小 `rt_dma_iget`，DMA issue 或 reply 数量可能成为瓶颈。

## 适用场景

- HBM 源数据由多个固定大小的 `record_bytes` 记录组成。
- LDM 目标槽位按原 index 顺序紧凑连续排列。
- 相邻两个 index 均有效，且第二个严格大于第一个。
- 不允许改变记录顺序，但允许对相邻两个目标槽位做局部 DMA 合并。
- `record_bytes`、`len` 和计算出的 `stride` 满足标准 DMA 的 4B 对齐要求。
- 异步请求使用累计 reply counter，在消费整个 LDM tile 前统一等待。
- 目标平台没有可直接表达任意地址列表的 DMA list-gather API。

## 不适用场景

- 源记录不是固定大小，或 LDM 目标不是紧凑连续布局。
- 相邻 index 递减、相等、无效或只剩一个 tail 记录；这些位置必须走 fallback。
- 必须交换记录顺序才能制造正 stride。
- 单 tile 只有少量 DMA，额外判断成本可能无法摊薄。
- 记录过小、stride 过大或地址分布特殊，尚未证明 stride DMA 优于两次普通 DMA。
- 目标平台已有经过验证的专用 list-gather API。

## 核心思路

把两个递增有效的 HBM 固定大小记录映射成一次双 block `rt_dma_iget_stride`，其余情况回退到单记录 DMA 或无效槽位处理。

## 实现规则

- 设 HBM 记录总数为 `record_count`，每条记录大小为 `record_bytes`。
- 对当前位置 `i` 读取 `idx = indices[i]`，再检查 `next_idx = indices[i + 1]`。
- 只有 `0 <= idx < record_count` 且 `idx < next_idx < record_count` 时合并。
- DMA 参数使用：`len = 2 * record_bytes`、`bsize = record_bytes`、`stride = (next_idx - idx - 1) * record_bytes`。
- 合并请求只给共享 reply 目标增加一次期望计数，并把循环位置前进 2 个记录。
- 不可合并时发起一次普通 `rt_dma_iget`，循环位置前进 1 个记录。
- 无效 index 保持原目标槽位的既定语义，例如清零、填充默认值或标记 mask；不参与 DMA，也不增加 reply 计数。
- wait 点、ping/pong 槽和 producer/consumer ownership 保持不变。

## 关键参数与资源预算

- 本 pattern 不新增 LDM buffer、workspace 或 reply 变量。
- 收益取决于单 tile 记录数、可合并 pair 比例、`record_bytes` 和 DMA issue 成本。
- 已验证实例中 `record_bytes = 512 * sizeof(half) = 1024B`，双元素请求有效数据为 2KB。
- 已验证实例的 32-record 随机排列 tile 中，贪心 pair 判断通常把请求数从 32 降到约 21 至 24。
- 其他记录大小和地址分布只能作为候选，必须通过目标 shape benchmark 决定是否保留。

## 架构与数据流

- HBM 固定大小记录是 producer，紧凑 LDM 槽位是 consumer buffer。
- 合并只改变 DMA 描述符数量，不改变 LDM 数据顺序和后续消费者看到的 layout。
- DMA completion 仍由对应 buffer 槽的累计 reply counter 统一等待。
- 后续 ACE、SIMD、reduce 或其他计算阶段无需感知某个槽位来自单记录 DMA 还是双元素 stride DMA。

## 从朴素实现到优化实现

- 朴素实现：每个有效 index 发起一次 `rt_dma_iget`。
- 优化实现：优先把递增相邻 pair 合并成一次 `rt_dma_iget_stride`，不能合并时保持原路径。
- 实际减少的是 DMA issue 和 reply 事件数量，不改变索引语义、目标槽位顺序和数学计算。

## 选型决策

- 先确认代码存在“indexed fixed-size record → packed LDM”的地址模式，再把本 pattern 作为候选。
- 若一个 tile 通常有 16 至 32 个或更多独立小 DMA，优先评估 pair batching。
- 若可合并 pair 很少，或记录大小明显偏离已验证的 1KB，应先做请求数统计和 benchmark。
- 若 indices 存在长等步长 run，可另开 attempt 验证多元素 stride batching；不要直接从双元素结果推广。
- 当前状态为 `verified_by_stage`，可以用于同类单点优化尝试，但不能跳过目标算子的正确性和性能验证。

## 伪代码

```cpp
while (i < slot_count) {
    int idx = indices[i];
    if (!is_valid(idx, record_count)) {
        fill_invalid_slot(i);
        i += 1;
        continue;
    }

    if (i + 1 < slot_count) {
        int next_idx = indices[i + 1];
        if (next_idx > idx && next_idx < record_count) {
            int stride = (next_idx - idx - 1) * record_bytes;
            issue_stride_dma(packed_dst + i * record_bytes,
                             source_base + idx * record_bytes,
                             2 * record_bytes, record_bytes, stride, reply);
            expected_reply += 1;
            i += 2;
            continue;
        }
    }

    issue_dma(packed_dst + i * record_bytes,
              source_base + idx * record_bytes,
              record_bytes, reply);
    expected_reply += 1;
    i += 1;
}
```

## 常见坑

- 把 `stride` 写成相邻记录起点距离；`rt_dma_iget_stride` 的参数是每个 `bsize` 后额外跳过的字节数，因此必须减去 `record_bytes`。
- 合并后仍把 reply 期望值增加 2，会导致 wait 永不满足。
- 为递减 pair 使用未验证的负 stride，或交换两个记录顺序，会改变数据语义或扩大正确性风险。
- 无效 index 被跳过后没有填充对应 LDM 槽位，导致消费者读取旧数据。
- 只验证全 valid 小 shape，遗漏 invalid、tail、多 tile 和 reply counter 复用。
- 把一次 attention KV 验证结果直接推广到所有 record 大小和 index 分布。

## 自检清单

- 是否明确识别出固定大小记录、indexed source 和 packed destination 三个条件。
- 合并与 fallback 路径是否保持同一目标槽位顺序。
- reply 期望计数是否按 DMA 请求数而不是记录数增加。
- invalid、tail、递减和相等 index 是否都有安全 fallback。
- baseline 与优化版本是否经过恢复、重编译和同条件串行复测。
- benchmark 是否覆盖真实 record 大小、index 分布和目标 tile 数。

## 验证

- 首次验证 op/stage：`flash_mla_sparse`，`v1_pair_stride_dma`。
- 验证实例：固定大小 KV record 从 HBM indexed gather 到紧凑 LDM；该实例只作为机制证据，不限定 pattern 的算子族。
- 正确性：smoke 2/2、tile sweep 3/3、20% invalid-index 1/1、8192 all-head 3/3 均通过精度门禁。
- 性能数据显示有明显的正向提升。
- evidence: dma-v1-pair-stride-gather

## 来源沿革

- revision 未记录，首次验证实现。
- 原始过程记录已蒸馏到 evidence `dma-v1-pair-stride-gather`，复用本 pattern 不依赖原始 `op_learning`。

## 相关模式

- `dma/gather-validity-flag-reuse`
- `pipeline/ace-writeback-simd-update-overlap`
- `simd/online-softmax-tile-microkernel`
- `dma/`
