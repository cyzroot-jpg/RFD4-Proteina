---
id: source-teco-ops-agent-ops-sdaa-op-design-references-completeness-checklist-2f6cf5c9
title: "teco-ops-agent ops: sdaa-op-design/references/completeness-checklist.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/completeness-checklist.md
relative_source_path: sdaa-op-design/references/completeness-checklist.md
captured_at: 2026-08-04
---

# 设计文档完整性门禁（强流程，v3）

## 总原则

strict 校验要同时满足两类条件：

1. 字段完整
2. 物理一致

第二条是 v3 的新增重点。章节填满但不满足一代芯片约束，也必须视为无效设计。

## 顶层

- `title`
- `status`：`review` 或 `approved`
- `workflow.current_focus=complete`
- `workflow.history` 至少 1 条

## operator_definition

- `summary`
- `computation_type`
- `operator_family`
- `formula`
- `logic_steps[]`
- `io_tensors[]`
- `kernel_apis[]`
- `independent_axes[]`
- `reduction_axes[]`
- `reuse_axes[]`

## parameters

- `shape_mode`
- `shape_keys[]`
- `shapes.smoke`
- `shapes.default`
- `dtype_io`
- `dtype_acc`

按 `shape_mode` 额外要求：

- `locked`：`locked_shapes`
- `ranged`：`shape_ranges`
- `ideal_search`：`ideal_shape_goal`

## throughput_model

- `model_type=layered_t1`
- `spe_clock_hz`：当前实机口径使用 2.36GHz
- `peak_flops_per_spe`
- `hbm_bandwidth_gbps`，并在分阶段模型中区分 DMA GET 256GB/s 与 DMA PUT 331GB/s
- `arithmetic_intensity`
- `theoretical_peak_tflops`
- `upper_bound_tflops`
- `hardware_caps`
- `traffic_model`
- `stage_time_model_us`
- `constraint_discounts[]`
- `bottleneck_type != unknown`
- `bottleneck_analysis`
- `achievable_throughput_note`
- `target_efficiency`

## tiling_strategy

- `tile_axis`
- `tile_elems`
- `dma_bytes_per_tile`
- `alignment_bytes`
- `hierarchy[]`
- `selected_tile`
- `search_space`
- `constraints[]`
- `feasible_region_summary`
- `rationale`

对 GEMM/Linear：

- `selected_tile` 必须至少含 `M1/N1/K1/M2/N2/K2`
- `N2` 和 `K2` 必须满足 T1 粒度约束

## core_partition_strategy

- `slave_core_num`
- `grid_shape`
- `partition_axis`
- `strategy`
- `pattern`
- `split_dimensions[]`
- `communication_pattern[]`
- `reduction_pattern`
- `loader_assignment[]`
- `rationale`

物理一致性：

- `grid_shape.rows * grid_shape.cols == slave_core_num`

## double_buffer_strategy

- `enabled`
- `buffered_tensors[]`
- `buffer_depth`
- `overlap_dma_compute`
- `stage_buffers[]`
- `enable_condition`
- `blocked_by[]`
- `rationale`

物理一致性：

- 若 `enabled=true`，必须有 `stage_buffers`

## ldm_planning

- `budget_bytes_per_spe`
- `usable_budget_bytes`
- `buffers[]`
- `total_bytes`
- `fits_budget`
- `bank_allocation[]`
- `pressure_summary`
- `reuse_notes`
- `allocation_notes`

物理一致性：

- `total_bytes <= usable_budget_bytes <= budget_bytes_per_spe`
- `usable_budget_bytes` 按约 235KB 设计，不能贴满 256KB 物理容量
- `bank_allocation[]` 必须分别说明两个 128KB bank 的容量和压力

## pipeline_layout

- `dataflow_description`
- `passes[]`
- `sync_points[]`
- `steady_state_stages[]`
- `overlap_pairs[]`
- `wait_points[]`
- `fill_drain_notes`

物理一致性：

- 若双缓冲开启，必须解释 `overlap_pairs`

## hardware_checklist

设计阶段还必须满足 [hardware-checklist.md](hardware-checklist.md)：

- DMA 是否按 128B PPU 包、stride/连续模式、8 个 DMA 引擎和 outstanding <= 11 建模
- LDM 是否同时核算总容量和 bank 压力
- ACE tile 是否满足 32 粒度、west <= 128 行、writeback 精度要求
- SIMD 是否满足 64B 对齐、P0/P1 交错、展开和尾部处理
- RMA/DMA 方向是否无明显路径冲突
- 同步和双缓冲是否真的能形成稳态 overlap

## scaffold + golden

- `scaffold.family`
- `scaffold.smoke`
- `scaffold.patch_runsh`
- `scaffold.upgrade_common`
- `golden.framework`
- `golden.atol`
- `golden.rtol`

## 特别提醒

strict 通过不等于性能正确，但 strict 不通过时，设计一定还不具备下游价值。
