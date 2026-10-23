---
id: local-learned-pattern-sparse-attention-fixed-tile-topk-tail-masking
title: 固定 Tile 的 TopK 尾块双重屏蔽
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/sparse-attention/fixed-tile-topk-tail-masking.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/sparse-attention/fixed-tile-topk-tail-masking.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- sparse-attention
- attention
- fixed
- tile
- topk
- tail
- masking
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: 固定 Tile 的 TopK 尾块双重屏蔽

## 状态

verified_by_stage

## 类型

optimization

## 问题

Sparse attention常用固定N行的ACE tile处理TopK indices。当`topk`不是tile行数的整数倍时，
最后一个tile包含padding行。若仍按完整tile读取indices会越界；若只把padding KV行清零，QK会为
这些行生成零logit，padding位置仍会进入softmax分母，导致输出权重错误。

## 检索关键词与触发信号

- 算子族：sparse attention、sparse MLA、indexed KV、KV gather。
- shape信号：`topk % N_BLOCK != 0`、最后一个KV tile不足、indices length非tile整数倍。
- 代码信号：gather循环固定执行`N_BLOCK`次，score softmax也固定消费完整tile。
- 语义信号：padding数据清零，但score没有显式mask。

## 适用场景

- KV由TopK indices离散gather，计算路径仍使用固定行数的QK/SV tile。
- 最后一个tile可通过`valid_rows = min(N_BLOCK, topk - tile_start)`确定有效范围。
- online或offline softmax能够在消费前把padding score写为`-INFINITY`。
- padding KV行可以安全初始化为零，避免ACE读取未定义LDM内容。

## 不适用场景

- 硬件或primitive原生支持真实尾块行数，且不会读取padding lane。
- padding位置具有业务语义，不能统一视为无效token。
- score使用整数或不支持无穷值的表示，需要改用该实现定义的最小可表示mask值。
- indices本身已经物理padding到完整tile并保证每个padding index具有明确的mask契约。

## 核心思路

尾块必须同时约束数据访问和概率语义：indices读取与KV gather只处理`valid_rows`，其余KV行清零；
QK完成后再把padding score设为`-INFINITY`，确保softmax概率严格为零。

## 实现规则

- 每个tile先计算`valid_rows = clamp(topk - tile_start, 0, N_BLOCK)`。
- indices、相邻pair/stride合并判断和validity扫描都只能访问`0..valid_rows-1`。
- `valid_rows..N_BLOCK-1`的KV LDM行必须显式清零，不能依赖旧buffer内容。
- 无效index和padding行都要在softmax前映射为`-INFINITY` score。
- padding score mask必须覆盖所有query head，不能只处理第一个head。
- SV仍可按完整固定tile执行；padding位置的softmax权重为零，因此不会污染输出。
- 完整tile路径应使用同一参数化循环，避免保留两套大体积热实现造成代码布局回退。

## 关键参数与资源预算

- 不新增LDM或workspace；只增加尾块边界计算、padding清零和score mask。
- 完整tile时`valid_rows == N_BLOCK`，额外工作应退化为简单边界判断。
- 已验证tile为N32，`topk=144`的最后一个tile有16个有效行。

## 架构与数据流

```text
indices tile
    │
    ├─ [0, valid_rows) gather真实KV
    └─ [valid_rows, N_BLOCK) KV清零
                    │
                 QK ACE
                    │
    invalid index与padding score -> -INFINITY
                    │
              softmax -> SV ACE
```

数据清零保证固定tile计算不读未定义值；score mask保证padding概率为零。两者缺一不可。

## 从朴素实现到安全实现

- 朴素实现对最后tile固定读取`N_BLOCK`个indices，存在越界访问。
- 不完整修复只清零padding KV，仍让零logit参与softmax。
- 安全实现用`valid_rows`限制所有indices读取，清零padding KV，并在softmax前mask padding score。

## 选型决策

- 发现`topk % N_BLOCK != 0`时，应先建立本尾块契约，再做性能优化。
- 若tail比例很高，可另开动态tile或更小tile的性能attempt；不能为减少padding计算而省略mask。
- host应对白名单shape做完整支持域校验；device在host契约内只选择已验证specialization，避免维护
  第二份易漂移的topk/head/dim白名单。若存在绕过host的直接device入口，必须单独保留等价门禁。

## 伪代码

```cpp
int tile_start = tile * N_BLOCK;
int valid_rows = min(N_BLOCK, max(0, topk - tile_start));

for (int row = 0; row < valid_rows; ++row) {
    gather_kv(indices[tile_start + row], kv_tile[row]);
}
for (int row = valid_rows; row < N_BLOCK; ++row) {
    clear(kv_tile[row]);
}

run_qk_fixed_tile();
for (int row = valid_rows; row < N_BLOCK; ++row) {
    score[row] = -INFINITY;
}
run_softmax_and_sv();
```

## 常见坑

- pair-stride gather仍读取`indices[tile_start + row + 1]`，越过`valid_rows`。
- 只清零KV，忘记零logit会给softmax分母贡献`exp(0)`。
- 只mask无效index，没有mask物理padding行。
- padding清零发生在异步DMA之后且ownership不明确，被下一次DMA覆盖。
- 只验证新tail shape，未用完整tile shape检查边界分支是否带来性能回退。

## 自检清单

- 所有indices读取是否受`valid_rows`约束？
- pair/stride合并是否也受尾块边界约束？
- padding KV是否在ACE消费前完成清零？
- padding score是否对所有head设为`-INFINITY`？
- 完整tile控制组是否精度通过且无稳定回退？
- 是否只有一个权威支持域校验点，且所有device launch都经过该门禁？

## 验证

- 验证算子/stage：`flash_mla_sparse`，`v13_deepseekv4_flash_real_shapes`。
- shape：FP16、N32、`topk=128/144/640`、`q_head=16/8/4`、`kv_head=1`、
  `qk_dim=v_dim=512`；prefill `q_seq=kv_seq=2048`，decode `q_seq=1,kv_seq=2048`。
- 正确性：18/18 PASS；最大Diff1/最大Diff2为0.000767/0.000836。
- 控制组：prefill 128/640相对旧路径分别提升13.14%～31.01%，无性能回退。
- 新能力：prefill 144尾块精度通过；旧实现因indices越界风险未执行baseline。
- evidence: sparse-attention-v13-fixed-tile-topk-tail

## 来源沿革

- `flash_mla_sparse`固定N32 sparse KV gather与online-softmax尾块验证。
- 原始stage已蒸馏到evidence `sparse-attention-v13-fixed-tile-topk-tail`。

## 相关模式

- `sparse-attention/README.md`
- `dma/pair-stride-gather.md`
- `dma/gather-validity-flag-reuse.md`
- `simd/valid-row-bounded-transpose.md`
- `pipeline/online-softmax-partial-state-tree-merge.md`
