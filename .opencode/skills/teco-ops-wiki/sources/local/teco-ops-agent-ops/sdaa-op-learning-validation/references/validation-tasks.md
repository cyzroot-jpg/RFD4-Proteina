---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-validation-tasks-65718a49
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/validation-tasks.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/validation-tasks.md
relative_source_path: sdaa-op-learning-validation/references/validation-tasks.md
captured_at: 2026-08-04
---

# 验证任务

从简单到复杂逐步验证，不要一开始上复杂 attention。

每个验证任务只证明一个主要假设。默认先用 isolated task 验证机制；当 RMA ring、workspace、双缓冲或
pipeline 之间存在明确依赖时，可以建立 combination task，但必须有 comparison matrix 和关键 ablation。

## Stage Naming

建议按当前算子版本记录：

```text
v0_reference_or_baseline
v1_ace_single_tile
v2_dma_layout
v3_b_row_ring
v4_c_reduce_scatter
v5_splitk_workspace
v6_double_buffer
v7_pipeline
```

每个 stage 都要有独立 `stage_results/<stage>.json`，记录本轮改动、验证结果、失败坑和可提升规则。

## Level 1: ACE GEMM 正确性

建议 op：`gemm_nn_fp16_fp32_smoke`

目标：

- 验证 fp16 输入、fp32 输出。
- 验证 `rt_ace_load_north`、`rt_ace_load_west`、`rt_ace_writeback` 基本调用。
- 验证 `Ysize` 行数和 fp32 C LDM 预算。
- 验证 B 的 stride DMA 紧凑化。

建议 shape：

```text
smoke:   M=64,  N=32,  K=64
default: M=128, N=64,  K=128
```

验收：

- L3 精度通过。
- `.swcu` 不包含 `ACE_PREC`。
- `check_delivery.py` 通过。

## Level 2: ACE + SIMD epilogue

建议 op：`linear_bias_relu_fp16_fp32_smoke`

目标：

- ACE 产出 fp32 C。
- SIMD 对 C 做 bias add / relu / cast 或 scale。
- 分析 SIMD 是否能与下一 tile ACE 或 DMA/RMA staging 重叠。

建议先做串行正确性，再做 overlap。

## Level 3: DMA/RMA 复合 staging

建议 op：小型 split-K 或 ring 交换 demo。

目标：

- 验证 RMA 点对点 reply 规则。
- 验证 RMA 与 DMA 错峰。
- 验证 partial reduce 的 SIMD 或 RMA 合并路径。

只有 Level 1/2 稳定后再做。

## Level 4: B row-ring panel

目标：

- 验证同一 `rid` 行内 `cid` 方向的 B panel ring。
- 每个 SPE 初始只有一个 `B[K2,N2]` panel。
- `COLS` 轮后每个 SPE 能按顺序消费完整 `N1=COLS*N2`。

验收：

- 单独 dump/校验每轮看到的 panel id 或用小 GEMM 验证 N panel 正确。
- 不引入 C reduce、workspace 或完整 pipeline。

## Level 5: C reduce-scatter

目标：

- 验证 split-K 后 partial C 的 RMA + SIMD reduce。
- 明确 full reduce 还是 reduce-scatter。
- 验证每个 SPE 最终只负责 `CSub = M2*N2/reduce_group` 时的地址映射。

验收：

- 单 tile K split 正确。
- shape 覆盖至少 2 个 K 分片。
- 不同时修改 B ring 或 workspace。

## Level 6: split-K workspace

目标：

- 验证多 K panel 的 partial C 写 workspace、下一 K panel 读回累加、最后写最终 C。
- 明确 workspace 是普通 row-major 还是 packed layout。

验收：

- `K > K1` 的 shape 正确。
- 首个 K panel、中间 K panel、最后 K panel 路径都被覆盖。

## Level 7: double buffer and pipeline

目标：

- 在正确性稳定后加 B/C/ACE writeback 双缓冲或三缓冲。
- 明确 fill/steady/drain、producer/consumer、buffer ownership 和 wait/sync 点。

验收：

- 正确性不回退。
- 若 benchmark 可用，记录优化前后 cycles/TFLOPS。
- 如果性能下降，记录原因并保留是否回退的决策。

若双缓冲单独无收益，但它是更大流水的 enabler，继续测试组合前必须记录：

- 单点为何无收益或退化。
- 它为组合提供的 buffer ownership 或 overlap 条件。
- 完整组合相对 baseline 的收益。
- 移除该 enabler 后组合是否退化。
