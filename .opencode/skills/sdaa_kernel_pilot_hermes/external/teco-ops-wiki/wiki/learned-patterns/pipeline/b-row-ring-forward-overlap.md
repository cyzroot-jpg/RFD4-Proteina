---
id: learned-pattern-b-row-ring-forward-overlap
title: 'Pattern: B Row-Ring Forward Overlap'
type: learned-pattern
architectures:
- sdaa
tags:
- learned-pattern
- b-row-ring-forward-overlap
- pipeline
- rma
- row-ring
- forward-overlap
- gemm
techniques:
- b-row-ring
- rma-forward-overlap
kernel_types:
- gemm
confidence: verified_by_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/pipeline/b-row-ring-forward-overlap.md
captured_at: '2026-08-03'
---

# Pattern: B Row-Ring Forward Overlap

## Status

verified_by_stage

## Problem

In a GEMM row-ring B-panel flow, forwarding the current B panel after all C post-processing leaves RMA latency exposed before the next ACE tile can start.

## Applies When

- GEMM uses row-local B panel sharing across `COLS` SPEs.
- ACE has already consumed the current `B[K2,N2]` tile before the forwarding RMA is issued.
- The implementation already has two B tile buffers for `curr_b_tile` and `next_b_tile`.
- C post-processing uses separate data buffers, and B RMA is completed before any later code resets shared RMA reply words.

## Do Not Use When

- The next B destination buffer may still be consumed by ACE or another RMA.
- C reduce or another stage reuses the same reply words before the B RMA wait.
- There is no independent work between B RMA issue and B RMA wait.
- Tail N panels do not have full row-ring participation unless a separate tail protocol is implemented.

## Core Idea

Issue the row-ring B forwarding RMA immediately after ACE has consumed the current B tile, then wait for it after ACE writeback and before C reduce.

## Implementation Rules

- Keep B ownership simple: `curr_b_tile` is the tile consumed by ACE and forwarded to the previous column; `next_b_tile` is the receive buffer for the next ring step.
- Use a row synchronization boundary before resetting row-ring RMA reply words and issuing `rt_rma_iput`.
- Do not enter code that resets the same RMA reply words until the B RMA wait has completed.
- Swap `curr_b_tile` and `next_b_tile` only after both local and remote B RMA completion are observed.
- This pattern does not require extra LDM if the existing implementation already has two B buffers.

## Pseudocode

```cpp
issue_ace_gemm_tile(a_tile, curr_b_tile, m_size, k_size, true);

if (has_next_b_panel) {
    rt_synchronized_row();
    reset_row_rma_replies();
    rt_synchronized_row();
    rt_rma_iput(curr_b_tile, local_reply, bytes, prev_col_tid,
                next_b_tile, remote_reply);
}

rt_ace_writeback(c_tile, m_size, ace_reply, 1);
wait_ace_reply(ace_reply, 1);

if (has_next_b_panel) {
    wait_row_rma_replies();
    rt_synchronized_row();
    swap(curr_b_tile, next_b_tile);
}

reduce_and_store_c_tile();
```

## Common Pitfalls

- Reusing `__rt_local_rply` / `__rt_remote_rply` for B RMA and then entering C reduce before B RMA wait. C reduce can reset those reply words and cause hangs or incorrect synchronization.
- Issuing B RMA before ACE has consumed `curr_b_tile`. The source buffer can be overwritten or forwarded before the current compute has accepted it.
- Adding a third B buffer before proving that issue/wait reordering with the existing two buffers is insufficient.

## Validation

- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v15_b_double_buffer_pipeline.json`
- Op: `gemmex`
- Shape: `M=2048,N=2048,K=8192,A/B=fp16,C=fp32`
- L3: `success_rate=1.0`
- Delivery: `check_delivery.py --no-benchmark` pass
- Benchmark: before `12641276 cycles / 5.356 ms`, after `12197423 cycles / 5.168 ms`, repeat `12253337 cycles / 5.192 ms`

## Source Evidence

- `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp::rma_put_matB`: B RMA issue is separate from wait.
- `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp::rma_wait_matB`: B RMA wait is delayed until later independent work has run.
- `swdnn_test_ops/src/gemmex/gemmex.swcu`: v15 validates the minimal reorder in the local validation op.

## Related Patterns

- `gemm/b-row-ring-panel-sharing.md`
- `rma/`
- `pipeline/`
