---
id: source-teco-ops-agent-ops-sdaa-op-design-references-ldm-planning-7f4fae81
title: "teco-ops-agent ops: sdaa-op-design/references/ldm-planning.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/ldm-planning.md
relative_source_path: sdaa-op-design/references/ldm-planning.md
captured_at: 2026-08-04
---

# LDM 使用规划（§6 P0）

## 目标

LDM 规划在 v3 里不再只是 `sum(buffers.bytes)`。

必须同时回答：

1. 放得下吗？
2. 两个 bank 怎么分？
3. 哪条通路压哪个 bank？
4. 生命周期能否复用？

## 两级预算

- `budget_bytes_per_spe`：物理总量，通常 256KB
- `usable_budget_bytes`：设计可用预算，默认按更保守口径

设计必须以 `usable_budget_bytes` 为准，不允许只看物理总量。

## buffers 表

```json
{
  "name": "a_dma_ping",
  "dtype": "half",
  "elems": 49152,
  "bytes": 98304,
  "purpose": "A tile DMA buffer"
}
```

## bank_allocation

推荐显式记录：

```json
[
  {"bank": "left", "buffers": ["A_local", "A_rma"], "traffic": "west + rma"},
  {"bank": "right", "buffers": ["B_local", "C_local"], "traffic": "north + writeback + dma"}
]
```

## pressure_summary

需要说明：

- bank0 压力来自哪些通路
- bank1 压力来自哪些通路
- 是否接近单 bank 上界

## reuse_notes

需要说明哪些 buffer：

- 跨 pass 复用
- 跨 tile 复用
- 可由 ping/pong 共址

## fits_budget 的真实含义

```text
fits_budget = (total_bytes <= usable_budget_bytes)
```

仅仅 `total_bytes <= 256KB` 不够。

## 常见错误

- 只统计 buffer 大小，不统计双缓冲倍数
- 忽略 RMA staging buffer
- 忽略 ACE 写回 buffer
- 忽略 bank 冲突，只看总量
