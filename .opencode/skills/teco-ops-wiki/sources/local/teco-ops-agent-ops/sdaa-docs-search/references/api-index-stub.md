---
id: source-teco-ops-agent-ops-sdaa-docs-search-references-api-index-stub-170d4b3d
title: "teco-ops-agent ops: sdaa-docs-search/references/api-index-stub.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-docs-search
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-docs-search/references/api-index-stub.md
relative_source_path: sdaa-docs-search/references/api-index-stub.md
captured_at: 2026-08-04
---

# API 索引 Stub

> 完整 API 详情通过 `sdaa-docs-search` 检索或查阅在线文档。本文件供快速参考。

## TecoLIBRT（运行时）

| 符号 | 分类 | 一句话 |
|------|------|--------|
| `rt_dma_get` | DMA | HBM→LDM 阻塞搬运 |
| `rt_dma_put` | DMA | LDM→HBM 阻塞写回 |
| `rt_dma_iget` | DMA | HBM→LDM 异步搬运 |
| `rt_dma_iput` | DMA | LDM→HBM 异步写回 |
| `rt_dma_*_stride` | DMA | 跨步 / 周期划分访存 |
| `rt_dma_wait_value` | 同步 | 等待 DMA reply 完成 |
| `rt_rma_iput` | RMA | 点对点异步写远端 LDM |
| `rt_rma_iget` | RMA | 点对点异步读远端 LDM |
| `rt_rma_col_reduce` | RMA | 列方向规约 |
| `rt_ldm_malloc` | 内存 | LDM 分配（默认 low→high） |
| `rt_ldm_free` | 内存 | LDM 释放 |

## TecoKERNEL（计算原语）

| 符号 | 分类 | 一句话 |
|------|------|--------|
| `batch_Smul_a` | Binary | 向量标量乘 |
| `batch_*` | Reduce/Binary | 见 tecokernel include |

## 在线文档入口

- TecoLIBRT：`http://docs.tecorigin.net/release/tecolibrt/`
- TecoKERNEL：`http://docs.tecorigin.net/release/tecokernel/`（待确认路径）
