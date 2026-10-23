---
id: local-learned-pattern-sparse-attention-readme
title: Sparse Attention / Sparse MLA Pattern 路由索引
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/sparse-attention/README.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/sparse-attention/README.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- sparse-attention
- attention
confidence: source-reported
captured_at: '2026-08-04'
---

# Sparse Attention / Sparse MLA Pattern 路由索引

本文件在 `attention/README.md` 的共有机制上追加 sparse attention 专属检查。Operator/Kernel
Preflight 识别到 sparse attention、sparse MLA、`flash_mla_sparse`、indexed KV 或 KV gather 时，
会同时加载 attention 与 sparse-attention 两级路由。

## 开发前检查顺序

| 代码或 shape 信号 | 优先读取 | 需要判断的问题 |
|---|---|---|
| 固定大小 KV record 按 indices 离散 gather | `dma/pair-stride-gather.md` | 相邻递增 index 能否合并为双元素 stride DMA |
| gather 已检查 index，consumer 又重复扫描 | `dma/gather-validity-flag-reuse.md` | validity flag 能否与 KV ping/pong buffer 同 ownership |
| 希望预取下一 query 的 indices/metadata | `pitfalls/small-side-input-prefetch-contention.md` | side input wait 是否真实暴露，是否会与主 KV gather 争用 DMA |
| decode 沿 topk/KV tile split-K | `pipeline/online-softmax-partial-state-tree-merge.md` | partial max/sum/O 合并与空核中性状态是否正确 |
| 希望把下一 QK 提到当前 SV 前 | `pitfalls/next-qk-before-current-sv.md` | QK/SV 是否共享 ACE，lookahead 是否抢占当前关键消费者 |
| score 行存在 head padding | `simd/valid-row-bounded-transpose.md` | 是否只删除无效转置，而不误改 QK ACE tile |
| `topk`不是固定KV tile的整数倍 | `sparse-attention/fixed-tile-topk-tail-masking.md` | indices边界、KV清零和score mask是否同时完整 |

## 领域边界

- sparse 专属信号包括 topk indices、离散 KV gather、invalid index、KV tile split 和跨核 partial state。
- online softmax、score transpose、ACE writeback overlap 等共有机制仍引用 attention/机制层正文。
- 不复制机制 pattern；同一 evidence 只由唯一正文消费。

## Preflight 自动触发信号

`sparse attention`、`sparse_attention`、`sparse-attention`、`sparse MLA`、
`flash_mla_sparse`、`sparse indices`、`indexed KV`、`KV gather`。
