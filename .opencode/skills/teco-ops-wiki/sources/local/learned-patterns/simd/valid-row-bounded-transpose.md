---
id: local-learned-pattern-simd-valid-row-bounded-transpose
title: 有效行边界约束的转置
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/simd/valid-row-bounded-transpose.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/simd/valid-row-bounded-transpose.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- simd
- valid
- row
- bounded
- transpose
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: 有效行边界约束的转置

## 状态

verified_by_stage

## 类型

optimization

## 问题

QK ACE 为满足 tile 形状可能写出固定 32 行 score，但实际 `q_per_kv` 只有 16、8 或 4。
若后续转置仍处理全部 32 行，就会为永远不会被 softmax 消费的 padding head 支付 SIMD 转置和
LDM 读写成本。

## 检索关键词与触发信号

- 算子族：`attention`、`sparse attention`、`sparse_attention`、MLA、Flash Attention。
- 数据流：QK、score transpose、softmax、SV、head padding、row padding。
- shape 信号：`q_per_kv`、`q_head`、`valid_head`、有效行数小于 ACE writeback 行数。
- 代码信号：转置循环按固定 padding 上界执行，但下游只消费前 `valid_rows` 行。
- 本 pattern 正文按 SIMD/LDM 局部变换机制归档；attention 与 sparse-attention 领域索引负责自动发现。

## 适用场景

- QK 输出行数按硬件 tile padding 到固定上界，实际有效 head 数更小。
- score 转置按独立 16×16 或类似小块执行，可以用有效行数限制 block 数。
- softmax 和后续 SV 只消费 `0..q_per_kv-1` 的有效行。
- 已验证实例中 `q_per_kv<=16`，QK 输出上界为 32 行，score tile 宽度为 32。

## 不适用场景

- padding 行承载 mask、统计或其他后续语义，不能直接跳过。
- 转置 primitive 只能处理完整固定矩阵，缩小边界会改变输出 layout。
- 为保留 full/partial 两套热实现而显著扩大代码体积；已验证相邻尝试曾因双实现布局回退。
- 有效行数接近 padding 上界，分支和边界计算无法摊薄。

## 核心思路

保持 producer tile 与输出 layout 不变，只把转置循环上界收紧到下游实际消费的有效行 block。

## 实现规则

- 从运行时或编译期 `q_per_kv` 计算有效 16-row block 数。
- 只跳过完全位于有效 head 范围之外的转置块；包含 tail head 的块仍按既定 tail 语义处理。
- 不改变 QK ACE orientation、writeback 大小、score buffer 分配或 softmax 行 stride。
- partial 转置后的有效 score 地址必须与 full 转置版本完全一致。
- 避免在同一热函数中同时保留两套大体积内联实现；优先让循环边界参数化。

## 关键参数与资源预算

- 本模式不新增 LDM、workspace 或 reply。
- 收益来自减少 score transpose 的 SIMD 指令与 LDM 访问。
- 已验证实例从固定 32 行缩到最多 16 行；q_head=16 的 8192主指标从 32.905 ms 降到
  32.437 ms，q_head=8/4 也保持正向但收益更小。

## 架构与数据流

```text
QK ACE writeback: padded score rows
          │
          ├─ full transpose: valid rows + unused rows
          └─ bounded transpose: only rows consumed by softmax
                                      │
                               online softmax -> SV
```

本模式只删除无效中间变换，不改变 QK producer 和 softmax consumer 的有效数据契约。

## 从朴素实现到优化实现

- 朴素实现按 ACE padding 上界转置全部 score 行。
- 优化实现按 `q_per_kv` 限制转置 block，只生成后续 consumer 会读取的行。
- 不减少 QK ACE 计算本身；若 padding QK 是主瓶颈，还需要另开 tile/orientation attempt。

## 选型决策

- 当有效行数不超过 padding 上界一半时，优先评估本模式。
- 先确认 consumer 不读 padding 行，再修改转置边界。
- 若缩小转置同时需要保留双份实现，应先评估代码体积和指令布局，避免微小省工被热路径膨胀抵消。
- 若目标是减少 ACE padding 计算，应单独验证 ACE tile，不与本模式混写。

## 伪代码

```cpp
int valid_blocks = ceil_div(q_per_kv, TRANSPOSE_ROWS);
for (int block = 0; block < valid_blocks; ++block) {
    transpose_score_block(score_src, score_dst, block);
}
```

## 常见坑

- 把有效 head 数和 QK tile 行数混为一谈，错误改变 ACE writeback layout。
- tail block 中只初始化部分 lane，剩余 lane 被后续向量 load 读取。
- full 与 partial 两套大函数同时内联，导致 q_head=16 热路径反而回退。
- 只测 q_head=4，未覆盖边界最大的 q_head=16。

## 自检清单

- softmax 是否只消费有效 head 行？
- partial 转置的有效行地址是否与 baseline 一致？
- tail block 和 padding lane 是否有定义明确的语义？
- QK ACE、buffer size、stride 与 reply 是否完全未改？
- 是否覆盖 q_head=16/8/4 和长序列性能？

## 验证

- 验证 op/stage：`flash_mla_sparse_fused_slice`，`v5_partial_valid_head_score_transpose`。
- shape：prefill `q_seq=8192/65536`，`q_head=16/8/4`，`topk=512`，
  `qk_dim=v_dim=512`。
- 正确性：smoke 与 8192全头精度通过。
- 性能：8192 q_head=16/8/4 从 32.905/26.081/24.686 ms 降到
  32.437/25.849/24.627 ms；65536从263.010/209.683/199.586 ms 降到
  259.472/208.425/199.219 ms。
- evidence: simd-v5-partial-valid-head-score-transpose

## 来源沿革

- revision 未记录，`transpose_kq`实现。
- 原始 stage 已蒸馏到 evidence `simd-v5-partial-valid-head-score-transpose`。

## 相关模式

- `simd/online-softmax-tile-microkernel`
- `pipeline/ace-writeback-simd-update-overlap`
- `attention/README.md`
- `sparse-attention/README.md`
- `ace/`
- `ldm/`
