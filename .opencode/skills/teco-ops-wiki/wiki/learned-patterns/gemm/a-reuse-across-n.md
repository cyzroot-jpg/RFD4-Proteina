---
id: learned-pattern-a-reuse-across-n
title: 'Pattern: gemm/a-reuse-across-n'
type: learned-pattern
architectures:
- sdaa
tags:
- learned-pattern
- a-reuse-across-n
- gemm
- a-reuse
- n-tiling
- dma
techniques:
- a-reuse-across-n
kernel_types:
- gemm
confidence: verified_by_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/gemm/a-reuse-across-n.md
captured_at: '2026-08-03'
---

# Pattern: gemm/a-reuse-across-n

## Status

verified_by_stage

## Problem

In NN GEMM, a local `A[M2,K2]` tile is independent of the output `N2` tile. Loading the same A tile once per `N2` panel duplicates HBM traffic and can dominate runtime when B ring/workspace/pipeline optimizations are not yet implemented.

## Applies When

- NN GEMM or GEMM-like kernels where `A` is indexed by `(M,K)` and `B/C` sweep the `N` axis.
- Each SPE owns a stable local `M2/K2` slice for a `(M1,K1)` macro position.
- LDM can keep `A[M2,K2]` resident while the kernel iterates over multiple `N2` panels.
- Reusing A does not conflict with C reduce buffers, ACE writeback buffers, or B staging.

## Do Not Use When

- The algorithm changes `A` per `N` panel, for example fused ops that mutate or repack A by N tile.
- LDM pressure requires evicting A before the N sweep completes.
- A is shared across SPEs through a separate RMA/ring protocol; that is a different pattern.
- The target bottleneck is already proven to be elsewhere and the loop reorder would hurt pipeline overlap.

## Core Idea

Use loop order `M1 -> K1(load A once) -> N2(load B, ACE, reduce/write C)` instead of `M1 -> N2 -> K1(load A every N2)`.

## Implementation Rules

- Load `A[M2,K2]` once after computing `m_start`, `m_size`, `k_start`, and `k_size` for the current SPE.
- Keep `a_tile` ownership with the same SPE; no RMA ring is required for local A reuse.
- For every `N2` tile, load only the corresponding `B[K2,N2]`, then issue ACE using the resident `a_tile`.
- Keep C accumulation semantics tied to the K macro index. If previous K macro tiles have written C, read previous C before reducing/storing the new partial.
- Keep A layout separate from A reuse. Row-major strided DMA can still be reused; packed A layout is only needed if A load bandwidth or DMA efficiency is the bottleneck.

## Pseudocode

```cpp
for (int m1 = 0; m1 < m1_blocks; ++m1) {
    for (int k1 = 0; k1 < k1_blocks; ++k1) {
        dma_get_a_once(a_tile, m1, k1, rid, cid);
        wait_a();
        for (int n2 = 0; n2 < n2_blocks; ++n2) {
            dma_get_b(b_tile, k1, n2, rid);
            wait_b();
            ace_gemm(a_tile, b_tile, c_tile);
            reduce_and_store_c(c_tile, m1, n2, k1, rid, cid);
        }
    }
}
```

## Common Pitfalls

- Confusing A reuse with A layout. Reuse changes tile lifetime and loop order; layout changes HBM/LDM memory organization.
- Assuming RMA ring is required. It is not required when each SPE reuses its own A tile locally.
- Accidentally changing B ring, workspace, double buffering, or C reduce in the same attempt, which makes performance attribution unclear.
- Moving the K loop without preserving the previous-C read condition for `k_macro_block > 0`.

## Validation

- Validation op/stage: `gemmex`, `v10_a_reuse_across_n`.
- Shape: `M=2048,N=2048,K=8192`, `A/B=fp16`, `C=fp32`, NN.
- Correctness: `torch_verify.py` L3 passed, `success_rate=1.0`, `faults=0`.
- Delivery: `check_delivery.py --op gemmex --no-benchmark --json` passed.
- Benchmark: improved from `128946366 cycles / 54.638 ms` to `66898770 cycles / 28.347 ms`, about `2.424 TFLOPS`.

## Source Evidence

- Process report: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/learned_patterns.md`.
- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v10_a_reuse_across_n.json`.
- Reference sample: `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp`, `dma_get_matA` and main loop condition `nl1 == 0 && rma_loop == 0`.

## Related Patterns

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `rma/` B ring and C reduce patterns, when promoted
