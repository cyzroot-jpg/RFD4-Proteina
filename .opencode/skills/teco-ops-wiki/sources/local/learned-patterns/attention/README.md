---
id: local-learned-pattern-attention-readme
title: Attention / MLA Pattern 路由索引
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/attention/README.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/attention/README.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- attention
confidence: source-reported
captured_at: '2026-08-04'
---

# Attention / MLA Pattern 路由索引

本文件是算子族检索入口，不保存重复的 pattern 正文。长期规则仍按 SIMD、DMA、pipeline、RMA、
LDM 等机制归档；Operator/Kernel Preflight 识别到 attention、MLA、QK、SV、`q_per_kv` 等信号时，
会自动读取本索引并把下列机制 pattern 加入必读候选。

## 开发前检查顺序

| 代码或 shape 信号 | 优先读取 | 需要判断的问题 |
|---|---|---|
| QK 输出按固定行数 padding，下游只消费有效 head | `simd/valid-row-bounded-transpose.md` | 能否只转置有效行，同时保持 ACE writeback layout 不变 |
| tile 内维护 running max/sum，后续 ACE 消费 half P | `simd/online-softmax-tile-microkernel.md` | tree reduce、条件 rescale、P-half pack 是否适用 |
| ACE writeback 后存在独立 SIMD 或下一阶段工作 | `pipeline/ace-writeback-simd-update-overlap.md` | wait 能否移动到第一消费点，buffer ownership 是否闭合 |
| decode 沿 KV/topk split-K | `pipeline/online-softmax-partial-state-tree-merge.md` | partial max/sum/O 是否共同合并，active participant和最终归一化是否正确 |
| prefill/decode共享大模板或废弃helper | `pipeline/hot-specialization-codepath-isolation.md` | 是否应隔离热specialization并用严格A/B验证代码布局收益 |
| 希望把partial O拆成多笔RMA | `pitfalls/chunked-rma-merge-request-overhead.md` | producer是否分块ready，描述符/reply开销是否超过重叠收益 |
| 长 prefill 中每个 SPE 连续处理大量独立 query | `pipeline/cross-query-persistent-attention.md` | 能否让LDM/表常驻，并把Q预取和输出wait跨query延迟 |
| 希望persistent覆盖单round或非整组query tail | `pitfalls/persistent-query-small-round-overhead.md` | round数是否足以摊薄双buffer与drain固定开销 |

## 领域边界

- 本索引覆盖 dense attention、Flash Attention、MLA 与 sparse attention 共有的 QK/softmax/SV 机制。
- 只有依赖 topk、离散 index、KV gather 或稀疏 tile 的规则才进入 `sparse-attention/README.md`。
- 领域索引只负责发现和组合顺序，不改变机制 pattern 的状态、证据或唯一正文位置。

## Preflight 自动触发信号

`attention`、`flash_attention`、`flash attention`、`MLA`、`QK`、`SV`、`q_per_kv`、
`q_head`、`score transpose`、`head padding`。
