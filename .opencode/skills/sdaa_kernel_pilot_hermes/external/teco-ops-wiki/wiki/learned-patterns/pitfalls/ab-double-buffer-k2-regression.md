---
id: learned-pattern-pitfall-ab-double-buffer-k2-regression
title: 'Pattern: pitfalls/ab-double-buffer-k2-regression'
type: learned-pattern-pitfall
architectures:
- sdaa
tags:
- learned-pattern
- ab-double-buffer-k2-regression
- pitfall
- double-buffering
- k2
- regression
- gemm
techniques:
- dma-double-buffering
kernel_types:
- gemm
confidence: verified_by_failed_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/pitfalls/ab-double-buffer-k2-regression.md
captured_at: '2026-08-03'
---

# Pattern: pitfalls/ab-double-buffer-k2-regression

## Status

verified_by_failed_stage

## Problem

A/B DMA double buffering can be correct and still slower when it increases LDM pressure enough to reduce `K2`. For split-K GEMM, a smaller `K2` increases the number of K macro iterations and can amplify C RMA reduce plus HBM C read/modify/write traffic.

## Applies When

- GEMM uses ACE with A/B tiles in LDM.
- The current dataflow already needs C tile storage, C RMA receive buffers, and a C accumulation buffer.
- Adding full A/B ping-pong requires reducing `K2`.
- Cross-K accumulation still goes through final C in HBM instead of a workspace or a deeper pipeline.

## Do Not Use When

- LDM can keep the same `K2` while adding A/B ping-pong.
- The implementation has already moved split-K partial C to workspace and the C-side loop count is no longer the bottleneck.
- The target has enough K tiles for steady overlap without increasing C-side work.
- Benchmark proves that the double-buffered version wins for the specific shape.

## Core Idea

Do not accept A/B double buffering as a default GEMM optimization if it forces `K2` down and increases C reduction/accumulation frequency.

## Implementation Rules

- Before implementing A/B ping-pong, compute LDM budget for:
  - `2 * A[M2,K2]`
  - `2 * B[K2,N2]`
  - ACE writeback C
  - C RMA receive buffers
  - local C accumulation buffer
  - runtime stack and reply words
- If the budget forces `K2 < current_best_K2`, benchmark the smaller-K2 variant before keeping it.
- Treat correctness as necessary but insufficient; keep the target implementation on the best measured stage.
- If benchmark regresses, revert the kernel and preserve the attempt record as a pitfall.
- Revisit A/B double buffering only after reducing C-side pressure through B sharing, workspace partial-C, or a full pipeline.

## Pseudocode

```cpp
candidate_k2 = largest_k2_that_fits_with_ab_pingpong();
if (candidate_k2 < current_best_k2) {
    run_l3(candidate_k2);
    run_benchmark(candidate_k2);
    if (candidate_time >= current_best_time) {
        revert_to_current_best();
        record_regression(candidate_k2);
    }
}
```

## Common Pitfalls

- Keeping a correct but slower kernel because L3 passed.
- Comparing only DMA latency and ignoring the extra C RMA/reduce loops created by a smaller `K2`.
- Adding A/B ping-pong in the same attempt as B ring, workspace, or C reduce redesign, which hides the true cause of the result.
- Updating design docs to claim double buffering is the active strategy after the implementation was reverted.

## Validation

- Failed stage: `gemmex`, `v9_ab_double_buffer_k2_search`.
- Shape: `M=2048,N=2048,K=8192`, `A/B=fp16`, `C=fp32`, NN.
- Baseline: `K2=512`, single-buffer, `128946366 cycles / 54.638 ms`.
- Attempt 1: `K2=256`, A/B double-buffered, L3 passed, `144760038 cycles / 61.339 ms`.
- Attempt 2: `K2=416`, A/B double-buffered, L3 passed, `132078772 cycles / 55.966 ms`.
- Result: both variants regressed; implementation reverted to the best validated `K2=512` single-buffer stage.

## Source Evidence

- Process report: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/learned_patterns.md`.
- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v9_ab_double_buffer_k2_search.json`.
- Related earlier positive stage: `swdnn_test_ops/op_learning/pipeline/gemmex-ab-double-buffer/stage_results/v6_ab_double_buffer.json`.

## Related Patterns

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `gemm/2d-splitk-c-rma-reduce`
- Future candidate: workspace partial-C after a dedicated single-point attempt passes.
- Future candidate: full fill / steady / drain pipeline after ownership of B ring and workspace is validated.
