---
id: learned-pattern-b-row-ring-panel-sharing
title: 'Pattern: gemm/b-row-ring-panel-sharing'
type: learned-pattern
architectures:
- sdaa
tags:
- learned-pattern
- b-row-ring-panel-sharing
- gemm
- rma
- row-ring
- panel-sharing
techniques:
- b-row-ring
- panel-sharing
kernel_types:
- gemm
confidence: verified_by_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/gemm/b-row-ring-panel-sharing.md
captured_at: '2026-08-03'
---

# Pattern: gemm/b-row-ring-panel-sharing

## Status

verified_by_stage

## Problem

After A reuse, each SPE still loads a separate `B[K2,N2]` panel from HBM for every output `N2` tile. In a `ROWS x COLS` GEMM split, the `COLS` peers in the same row can share the B macro panel so that each SPE only loads one initial B panel for an `N1=COLS*N2` macro tile and receives the remaining panels through row-local RMA.

## Applies When

- NN GEMM or GEMM-like kernels where B is indexed by `(K,N)` and ACE north consumes `B[K2,N2]`.
- A 32-SPE group is mapped as `ROWS x COLS`, with `cid` covering the M split and `rid` covering the K split.
- The current N macro tile contains exactly `COLS` full `N2` panels.
- LDM can hold one current B panel and one receive B panel in addition to A, C writeback, and C reduce buffers.
- Row-local RMA is available and can be synchronized independently from column-local C reduce.

## Do Not Use When

- The N macro tail has fewer than `COLS` full panels, unless a separate tail-safe ring protocol is implemented and validated.
- LDM pressure forces reuse of the current B buffer before ACE has consumed it.
- B is already packed or broadcast through a different workspace/pipeline stage that changes ownership.
- The attempt also changes workspace partial-C, C reduce ownership, A layout, or full fill/steady/drain pipeline; those must be separate stages.

## Core Idea

For each full `N1` macro tile, each `cid` loads one local B panel, computes with it, forwards it to `cid-1`, receives the next panel from `cid+1`, and repeats until all `COLS` B panels have been consumed.

## Implementation Rules

- Keep the existing `rid/cid` grid. In the validated stage, `ROWS=4`, `COLS=8`, `M2=96`, `N2=32`, and `K2=512`.
- Enter the row-ring path only when the active N macro tile has `active_cols == COLS`.
- Initially load `B[k_start:k_start+K2, n_macro_start + cid*N2]` into the current B buffer.
- At ring step `rma_loop`, compute the logical output panel as `n_col = (cid + rma_loop) % COLS`.
- ACE consumes the current B buffer for that logical `n_col`.
- If another ring step remains, row-sync, reset row RMA replies, `rt_rma_iput` the current B panel to `rid*COLS + prev_col(cid)`, wait for remote and local completion, row-sync again, then swap current and receive B buffers.
- Keep C reduce on the existing column-local path. Do not reuse its column sync or reply ownership for B row-ring.
- Keep cross-K1 accumulation semantics unchanged. If previous K macro tiles have already written C, read previous C before reducing and storing the new partial.

## Pseudocode

```cpp
for (int n1 = 0; n1 < n1_blocks; ++n1) {
    if (active_cols(n1) != COLS) {
        fallback_per_n2_b_dma();
        continue;
    }

    curr_b = b0;
    recv_b = b1;
    dma_get_b(curr_b, k_start, n1_start + cid * N2);
    wait_b();

    for (int step = 0; step < COLS; ++step) {
        int n_col = (cid + step) % COLS;
        ace_gemm(a_tile, curr_b, c_tile);
        reduce_and_store_c(c_tile, n1_start + n_col * N2);

        if (step + 1 < COLS) {
            row_sync();
            reset_row_rma_replies();
            rma_put(curr_b, rid * COLS + prev_col(cid), recv_b);
            wait_row_rma();
            row_sync();
            swap(curr_b, recv_b);
        }
    }
}
```

## Common Pitfalls

- Advancing `n_col` as `cid - rma_loop` or using the receiver id instead of the logical output panel. The validated mapping is `(cid + rma_loop) % COLS`.
- Sending B into the same buffer ACE is still consuming. Use distinct current and receive buffers and swap only after row RMA completion.
- Resetting `__rt_local_rply` / `__rt_remote_rply` without a row synchronization boundary, which can race with peer row-ring traffic.
- Mixing B row-ring with C reduce, workspace, or full pipeline changes in one attempt. That makes correctness and performance attribution unclear.
- Applying the full-COLS ring to N tails. Use the non-ring fallback until a tail-safe variant is separately verified.

## Validation

- Validation op/stage: `gemmex`, `v11_b_row_ring`.
- Shape: `M=2048,N=2048,K=8192`, `A/B=fp16`, `C=fp32`, NN.
- Correctness: `torch_verify.py` L3 passed, `success_rate=1.0`, `faults=0`, `max_abs_err=4.550814628601074e-05`.
- Delivery: `check_delivery.py --op gemmex --no-benchmark --json` passed, including RMA safety.
- Benchmark: improved from v10 A reuse `66898770 cycles / 28.347 ms` to `47525809 cycles / 20.138 ms`, about `3.412 TFLOPS`.

## Source Evidence

- Process report: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/learned_patterns.md`.
- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v11_b_row_ring.json`.
- Reference sample: `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp`, `dma_get_matB`, `rma_put_matB`, `rma_wait_matB`, and `ace_cal`.

## Related Patterns

- `gemm/a-reuse-across-n`
- `gemm/2d-splitk-c-rma-reduce`
- Future candidate: workspace partial-C after a dedicated single-point attempt passes.
- Future candidate: full fill / steady / drain pipeline after B ring and workspace ownership are both validated.
