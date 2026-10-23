---
id: learned-pattern-2d-splitk-c-rma-reduce
title: 'Pattern: gemm/2d-splitk-c-rma-reduce'
type: learned-pattern
architectures:
- sdaa
tags:
- learned-pattern
- 2d-splitk-c-rma-reduce
- gemm
- split-k
- rma
- reduction
- 2d-partition
techniques:
- 2d-split-k
- c-rma-reduce
kernel_types:
- gemm
confidence: verified_by_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/gemm/2d-splitk-c-rma-reduce.md
captured_at: '2026-08-03'
---

# Pattern: gemm/2d-splitk-c-rma-reduce

## Status

verified_by_stage

## Problem

For fp16/fp32 NN GEMM on a 32-SPE group, an M-only partition can underuse the available cores or leave ACE west tiles too small. Splitting a macro tile across both M and K improves core occupancy and ACE west utilization, but splitting K creates multiple partial C tiles that must be reduced before writing the final C result.

## Applies When

- NN GEMM or GEMM-like kernels where `C[M,N] = A[M,K] * B[K,N]`.
- `A/B` are fp16 or bf16 and C accumulation/output is fp32.
- The target can use a 32-SPE group as a `ROWS x COLS` logical grid.
- `ROWS` splits K inside a macro tile and `COLS` splits M.
- C partials from different `rid` rows can be exchanged within the same `cid` column.

## Do Not Use When

- K is not large enough to benefit from split-K.
- C partial exchange cost dominates ACE compute for the target shape.
- The implementation has no safe RMA reply/wait path for cross-row C exchange.
- A workspace partial-C path or fused epilogue changes the reduction ownership; use a workspace-specific pattern instead.

## Core Idea

Map 32 SPEs as `4 x 8`: split K across four rows, split M across eight columns, then use column-local RMA to gather four partial C quarters before writing each owned C quarter.

## Implementation Rules

- Derive `rid = tid / COLS` and `cid = tid % COLS`.
- Give each SPE a local `A[M2,K2]`, `B[K2,N2]`, and partial `C[M2,N2]`.
- Use `N2=32` for ACE north width and keep `K2` a multiple of 32.
- For the validated target, `ROWS=4`, `COLS=8`, `M2=96`, `N2=32`, and `K2=512`.
- After ACE writeback, split `C[M2,N2]` into `ROWS` M quarters.
- Each row owns one quarter and receives the other three quarters from peer rows in the same column.
- Reduce the four quarters locally, then write only the owned quarter to final C or to the next accumulation location.
- Use `__rt_local_rply` and `__rt_remote_rply` for async RMA reply words in `.swcu` kernels.
- If cross-K1 macro tiles still accumulate through HBM C, preserve the previous-C read/modify/write condition for `k_macro_block > 0`.

## Pseudocode

```cpp
rid = tid / COLS;
cid = tid % COLS;

load_a_for_row_and_col(rid, cid);
load_b_for_row(rid);
ace_gemm(a_tile, b_tile, partial_c);

for (int peer = 0; peer < ROWS; ++peer) {
    if (peer != rid) {
        rma_send_c_quarter(peer, cid, partial_c_quarter_for(peer));
    }
}

wait_for_c_quarters();
reduce_four_row_partials(owned_c_quarter);
store_owned_c_quarter();
```

## Common Pitfalls

- Treating C RMA reduce as optional. Once K is split across rows, each row has only a partial sum.
- Using ordinary local `volatile int` reply words for remote RMA completion. The delivery gate expects `__rt_local_rply` / `__rt_remote_rply`.
- Promoting the tecoal workspace or full pipeline together with the split-K attempt. They are separate optimization points.
- Increasing `M2` without checking LDM capacity for C RMA receive buffers and accumulation buffers.

## Validation

- Validation op/stage: `gemmex`, `v8_2d_splitk_rma_reduce`.
- Shape: `M=2048,N=2048,K=8192`, `A/B=fp16`, `C=fp32`, NN.
- Correctness: `torch_verify.py` L3 passed, `success_rate=1.0`, `faults=0`, `max_abs_err=4.550814628601074e-05`.
- Delivery: `check_delivery.py --op gemmex --no-benchmark --json` passed, including RMA safety.
- Benchmark: improved from `166463136 cycles / 70.535 ms` to `128946366 cycles / 54.638 ms`, about `1.258 TFLOPS`.

## Source Evidence

- Process report: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/learned_patterns.md`.
- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v8_2d_splitk_rma_reduce.json`.
- Reference sample: `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp`.
- Cross-check sample: `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_bf16_32x_perf.hpp`.

## Related Patterns

- `gemm/a-reuse-across-n`
- Future candidate: B row-ring / B panel sharing after `v11_b_row_ring` passes L3, delivery, and benchmark.
- Future candidate: workspace partial-C after a dedicated single-point attempt passes.
- Future candidate: full fill / steady / drain pipeline after ownership of B ring and workspace is validated.
