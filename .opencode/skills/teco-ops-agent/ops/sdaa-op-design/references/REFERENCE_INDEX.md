# sdaa-op-design Reference Index

This directory keeps the design workflow references local to the
`sdaa-op-design` skill. Existing workflow/schema files remain at the top
level. External source material is copied into subdirectories so the skill can
reason about T1 operator design without depending on `swdnn_test_ops/docs`.

## Core Workflow References

- `workflow.md`: v3 operator-design flow and shape modes.
- `design-schema.md`: `design.json` schema fields.
- `throughput-model.md`: layered T1 stage model.
- `ldm-planning.md`: usable LDM and bank planning.
- `completeness-checklist.md`: strict validation requirements.
- `example-gemm-locked.md`: locked-shape GEMM manual-design initialization example.
- `example-rmsnorm_forward.json`: non-GEMM example design.

## Source Docs

Source materials are copied under `source-docs/` so design-time references stay local to this repository.

High-priority modeling docs:

- `source-docs/sdaa-hardware-architecture.md`: T1 SPA/SPE, HBM, LDM, ACE, DMA/RMA constants.
- `source-docs/算子设计方法论.md`: six-stage operator design flow.
- `source-docs/GEMM带宽平衡方法论.md`: GEMM bandwidth-supply model.
- `source-docs/GEMM设计推演示例.md`: worked GEMM design example.
- `source-docs/T1-ACE使用方法论.md`: ACE microbenchmark interpretation.
- `source-docs/T1-DMA-RMA访存优化方法论.md`: DMA/RMA access rules and bottlenecks.
- `source-docs/分核.md`: implementation skeletons and partition strategies.
- `source-docs/访存与流水线优化.md`: memory and pipeline implementation guidance.
- `../../../docs/共享知识库/SIMD使用手册-zh.md`: SIMD vector types, P0/P1 dual issue, instruction classes, and usage constraints.
- `../../../docs/共享知识库/simd-dual-issue-pattern.md`: required 8x unroll software pipeline pattern for load/op/store loops.
- `source-docs/指令拍数和流水线派发.md`: issue/cycle constraints.

Raw calibration and architecture sources:

- `source-docs/ACE.xlsx`: ACE TFLOPS, cycle, IO, half-write, dispatch-delay tables.
- `source-docs/DMA测试.xlsx`: DMA stride/continuous bandwidth test data.
- `source-docs/DMA基础性能测试数据20220909（硬仿 vs AI芯片）.xlsx`: DMA baseline test data.
- `source-docs/一代芯片硬件结构v0.6.pptx`: T1 hardware architecture slides.
- `source-docs/gemm性能突破——瑞鑫.pptx`: GEMM/SUMMA bottleneck slides.
- `source-docs/summa-gemm-银星.pdf`: SUMMA GEMM reference.
- `source-docs/大模型推理GEMM的访存带宽性能优化.pdf`: LLM inference GEMM bandwidth reference.
- `source-docs/done_申威-AI从核结构手册v0.56（2019-11-08）.pdf`: SPE hardware manual.
- `source-docs/images/teco-T1/`: architecture images referenced by markdown docs.

## Implementation Notes

- `implementation-notes/gemm_fp16_pvc_fp32_32x_theoretical_perf.md`:
  implementation-level GEMM 32X performance accounting. Use it to connect
  abstract design fields to real kernel traffic, workspace, wait points, and
  LDM pressure.

## Modeling Helper

- `gemm-performance-modeling/SKILL.md`: prior GEMM modeling workflow.
- `gemm-performance-modeling/scripts/gemm_perf_model.py`: deterministic GEMM arithmetic helper.
- `gemm-performance-modeling/agents/openai.yaml`: original skill agent metadata.

## Intended Use In sdaa-op-design

1. Use `source-docs/算子设计方法论.md` and `source-docs/GEMM带宽平衡方法论.md`
   to derive candidate families and the objective function.
2. Use `source-docs/ACE.xlsx` and `source-docs/T1-ACE使用方法论.md`
   to calibrate `T_ace`, writeback, and dispatch-delay discounts.
3. Use `source-docs/DMA测试.xlsx` and `source-docs/T1-DMA-RMA访存优化方法论.md`
   to calibrate DMA/RMA bandwidth discounts by packet size, stride, engine
   mapping, and communication pattern.
4. Use `../../../docs/共享知识库/SIMD使用手册-zh.md`, `../../../docs/共享知识库/simd-dual-issue-pattern.md`,
   and `source-docs/指令拍数和流水线派发.md` to estimate `T_simd` and ACE/SIMD
   overlap for epilogue, workspace reduce, cast, pack, and tail paths.
5. Use `implementation-notes/` to keep candidate traffic models honest against
   real kernel workspace and pipeline behavior.
6. Fill `throughput_model`, `tiling_strategy`, `core_partition_strategy`,
   `double_buffer_strategy`, `ldm_planning`, and `pipeline_layout` so strict
   validation can pass with physically meaningful numbers.
