---
id: learned-pattern-pitfall-ace-west-mtile-occupancy
title: 'Pattern: ACE West M Tile Must Preserve Core Occupancy'
type: learned-pattern-pitfall
architectures:
- sdaa
tags:
- learned-pattern
- ace-west-mtile-occupancy
- pitfall
- ace
- west-mtile
- occupancy
- gemm
techniques:
- ace-west-tiling
kernel_types:
- gemm
confidence: verified_by_failed_stage
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/pitfalls/ace-west-mtile-occupancy.md
captured_at: '2026-08-03'
---

# Pattern: ACE West M Tile Must Preserve Core Occupancy

## Status

verified_by_failed_stage

## Problem

Increasing ACE west `M_TILE` toward the hardware maximum of 128 can improve per-SPE ACE row utilization, but it can reduce the number of independent M blocks. In an M-only partitioned kernel, that can leave SPEs idle or create tail imbalance, causing a performance regression even when the tile fits LDM and accuracy passes.

## Applies When

- GEMM/Linear uses ACE west input and partitions work primarily along M.
- Each SPE consumes one or more M blocks independently.
- Candidate tile search increases `M_TILE` based on ACE preference and LDM feasibility.
- `M` is fixed and `ceil(M / M_TILE)` may become smaller than `slave_core_num`.

## Do Not Use When

- The kernel uses a 2D/3D grid, RMA sharing, split-K, or another work distribution that still keeps all SPEs busy.
- M is large enough that larger M tiles still provide at least one balanced block per SPE.
- The optimization target is latency on a small number of SPEs rather than throughput across the full 32-SPE group.

## Core Idea

Tile search must include core occupancy and load balance, not only ACE west utilization and LDM fit.

## Implementation Rules

- For M-only partitioning, compute `m_blocks = ceil(M / M_TILE)`.
- Prefer candidates where `m_blocks >= slave_core_num`.
- Prefer candidates where `M % M_TILE == 0` or tail handling is balanced across SPEs.
- If `M_TILE=128` or another large candidate underutilizes SPEs, do not use it as a single-point change; first redesign the grid/data sharing strategy.
- Record rejected candidates with both LDM feasibility and occupancy reason.

## Pseudocode

```cpp
for (int m_tile : {128, 112, 96, 80, 64}) {
    bool ldm_ok = ldm_bytes(m_tile) <= usable_ldm_bytes;
    int m_blocks = ceil_div(M, m_tile);
    bool occupancy_ok = m_blocks >= slave_core_num;
    bool balance_ok = (M % m_tile) == 0;
    if (ldm_ok && occupancy_ok && balance_ok) {
        return m_tile;
    }
}
```

## Common Pitfalls

- **LDM-only selection**: choosing the largest LDM-feasible M tile while ignoring `m_blocks`.
- **Accuracy-only validation**: L3 passes, but performance regresses due to idle SPEs.
- **SPE0 timing ambiguity**: if benchmark prints SPE0 only, tail assignment to SPE0 can overstate or reveal imbalance depending on mapping.

## Validation

- Failed stage: `swdnn_test_ops/op_learning/ace/gemmex-west-mtile-search/stage_results/v7_west_mtile_80.json`
- Target op: `gemmex`
- Shape: `M=2048,N=2048,K=8192`
- Candidate: `M_TILE=80`
- Accuracy: L3 `success_rate=1.0`
- Performance: `166463136 cycles -> 170102778 cycles`, regression
- Root cause: `ceil(2048/80)=26`, fewer than 32 SPEs, plus tail imbalance

## Source Evidence

- `swdnn_test_ops/op_learning/ace/gemmex-west-mtile-search/learned_patterns.md`
- `swdnn_test_ops/op_learning/ace/gemmex-west-mtile-search/stage_results/v7_west_mtile_80.json`
- `ops/sdaa-arch/references/ace-methodology.md`: ACE west max/recommended M facts.
- `ops/sdaa-arch/references/hardware-operator-rules.md`: LDM and ACE constraints.

## Related Patterns

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `gemm/a-reuse-across-n`
