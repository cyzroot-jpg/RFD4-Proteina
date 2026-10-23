---
id: source-teco-ops-agent-ops-sdaa-op-design-references-source-docs-teco-hardware-execution-model-3a395d19
title: "teco-ops-agent ops: sdaa-op-design/references/source-docs/teco_hardware_execution_model.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/source-docs/teco_hardware_execution_model.md
relative_source_path: sdaa-op-design/references/source-docs/teco_hardware_execution_model.md
captured_at: 2026-08-04
---

# TECO 硬件执行模型分析口径

本文档记录性能分析需要用到的硬件执行模型术语。第一版只作为分析口径，不作为确定瓶颈证据。

## 核心概念

- DMA get / put
- LDM buffer
- SIMD load / store / vector compute
- reply / wait
- double buffering
- aligned / unaligned DMA
- `_PEN` / `slave_core_num`
- DMA 与 compute overlap
- pipeline 空泡

## 证据分级

| 级别 | 含义 |
|---|---|
| `confirmed` | 有 profiler、counter 或明确运行证据 |
| `likely` | 源码结构和性能字段共同支持 |
| `possible` | 只有源码结构或单一字段支持 |
| `unknown` | 证据不足 |

## 约束

仅凭源码中的 `wait` 不能断定存在 pipeline 空泡；必须结合 profiler 或 cycle trace。
