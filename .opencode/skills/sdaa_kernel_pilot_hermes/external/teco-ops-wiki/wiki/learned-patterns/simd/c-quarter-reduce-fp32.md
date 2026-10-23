---
id: learned-pattern-c-quarter-reduce-fp32
title: 'Pattern: simd/c-quarter-reduce-fp32'
type: learned-pattern
architectures:
- sdaa
tags:
- learned-pattern
- c-quarter-reduce-fp32
- simd
- fp32
- reduction
- split-k
- gemm
techniques:
- c-quarter-reduce
- simd-reduction
kernel_types:
- gemm
confidence: verified_by_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/simd/c-quarter-reduce-fp32.md
captured_at: '2026-08-03'
---

# Pattern: simd/c-quarter-reduce-fp32

## Status

verified_by_stage

## Problem

After split-K C RMA exchange, each SPE reduces its local C quarter plus three received peer quarters. A scalar fp32 loop over this LDM data serializes a hot path that is naturally vectorizable.

## Applies When

- C partials are already resident in LDM as fp32 buffers.
- The operation is elementwise addition of local C, received C quarters, and optionally previous accumulated C.
- The hot length is a multiple of 16 fp32 elements, or a scalar tail fallback is retained.
- The implementation can prove or reasonably rely on aligned LDM allocation for the hot path.

## Do Not Use When

- The reduce path changes ownership, layout, workspace accumulation, or peer mapping in the same attempt.
- Buffers may be unaligned and no `simd_loadu` fallback or scalar path exists.
- The element count is too small for SIMD setup/unroll to pay off.
- The reduce is fused with nontrivial scalar branches or non-vectorizable math.

## Core Idea

Use `floatv16` loads from local C and RMA C buffers, add vectors in registers, and store the result to the accumulation/output LDM buffer. Pick the unroll factor by measured performance, not by a fixed rule.

## Implementation Rules

- Include `<simd.h>` when using raw SIMD intrinsics.
- Keep `len` in elements, not bytes.
- Use `simd_load` / `simd_store` on the aligned LDM hot path.
- Keep a scalar tail fallback unless all supported shapes prove `len % 16 == 0`.
- For this validated target, `chunk_elems=24*32=768`, so the hot path is divisible by 16.
- A 4x `floatv16` unroll was faster than an 8x unroll on the validated target; do not blindly expand to 8x if register pressure or instruction scheduling regresses.
- Use the SIMD manual's P0/P1 model when choosing the loop shape. `simd_load` / `simd_store` occupy P1, while fp32 vector adds occupy P0; the goal is enough independent vectors to cover load-use delay without exhausting vector registers.
- Account for vector-register pressure. The validated 4x loop has about 8 explicit live `floatv16` values (`acc0..3` and `tmp0..3`), while the tested 8x loop had about 16; T1 has 32 architectural vector registers, and compiler temporaries still need headroom.
- Keep SIMD reduce separate from C RMA ownership, B row-ring, workspace partial-C, A layout, and full pipeline attempts.

## Scheduling Notes

- Relevant manual facts:
  - P0 handles vector compute and P1 handles LDM load/store; dual issue is effective only when independent P0/P1 instructions are interleaved.
  - Local vector load is at least 5 cycles and vector store is at least 4 cycles; fp32 vector add is 5 cycles.
  - The manual's observed efficient `floatv16` expansion is 4x, not universally 8x.
- In the kept 4x loop, each 64-element block uses four independent accumulators. That creates enough independent work to separate load/use and gives the compiler room to schedule P1 loads/stores around P0 adds.
- The 8x trial increases load-use distance but roughly doubles explicit vector-register pressure. On this target it measured slower, so the extra unroll was not worth the allocator and scheduling pressure.

## Pseudocode

```cpp
for (int i = 0; i <= len - 64; i += 64) {
    floatv16 acc0, acc1, acc2, acc3;
    simd_load(acc0, local_c + i);
    simd_load(acc1, local_c + i + 16);
    simd_load(acc2, local_c + i + 32);
    simd_load(acc3, local_c + i + 48);

    add_vector(acc0, rma0 + i, rma1 + i, rma2 + i, prev_c + i);
    add_vector(acc1, rma0 + i + 16, rma1 + i + 16, rma2 + i + 16, prev_c + i + 16);
    add_vector(acc2, rma0 + i + 32, rma1 + i + 32, rma2 + i + 32, prev_c + i + 32);
    add_vector(acc3, rma0 + i + 48, rma1 + i + 48, rma2 + i + 48, prev_c + i + 48);

    simd_store(acc0, out + i);
    simd_store(acc1, out + i + 16);
    simd_store(acc2, out + i + 32);
    simd_store(acc3, out + i + 48);
}
scalar_tail();
```

## Common Pitfalls

- Treating a template warning about 8x unroll as a hard performance truth. On the validated target, 8x was correct but slower than 4x.
- Ignoring vector register pressure. More unroll can improve latency hiding until it causes spills, worse scheduling, or less allocator freedom.
- Using aligned `simd_load` on buffers whose alignment is not guaranteed.
- Accidentally changing C RMA exchange or workspace accumulation while vectorizing the local reduce.
- Removing the scalar tail fallback before all supported shapes prove 16-element divisibility.

## Validation

- Validation op/stage: `gemmex`, `v12_simd_c_quarter_reduce`.
- Shape: `M=2048,N=2048,K=8192`, `A/B=fp16`, `C=fp32`, NN.
- Correctness: `torch_verify.py` L3 passed, `success_rate=1.0`, `faults=0`.
- Delivery: `check_delivery.py --op gemmex --no-benchmark --json` passed; non-hard SIMD unroll warning recorded and measured.
- Benchmark: improved from v11 B row-ring `47525809 cycles / 20.138 ms` to 4x SIMD reduce `28421791 cycles / 12.043 ms`, about `5.704 TFLOPS`.
- 8x trial: `28979145 cycles / 12.279 ms`, slower than 4x, so the 4x variant was kept.

## Source Evidence

- Process report: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/learned_patterns.md`.
- Stage result: `swdnn_test_ops/op_learning/gemm/gemmex-tecoal-2d-splitk/stage_results/v12_simd_c_quarter_reduce.json`.
- Reference sample: `/data/dnn/gupeng/tecoal/ual/slave/gemm/hgemm/NN/gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp`, `simd_reduce_matC`.
- SIMD manual: `docs/共享知识库/SIMD使用手册-zh.md`.
- SIMD guide: `ops/sdaa-kernel-api-best-practices/references/simd-intrinsics-guide.md`.

## Related Patterns

- `gemm/2d-splitk-c-rma-reduce`
- `gemm/b-row-ring-panel-sharing`
- `gemm/a-reuse-across-n`
