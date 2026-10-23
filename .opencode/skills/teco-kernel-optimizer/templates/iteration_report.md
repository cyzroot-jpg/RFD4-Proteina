# Iteration {{iter}} — Analysis

**Kernel optimized (target .scpp)**: `{{target_kernel}}`
**teco-ops case**: `{{case_path}}`
**Working tree**: `{{tree}}`
**Time before**: {{best_ms_before}} ms
**SDAA device**: {{gpu_name}}

---

## Required Evidence Read Before Planning

_Fill this section before generating any branch kernels._

- **Wiki query file read**: `iterv{{iter}}/wiki_queries.json`
- **State read**: `state.json`
- **Current best source read**: `{{best_file}}`
- **Previous analysis read**: `iterv{{iter_minus_1}}/analysis.md` _(required if iter > 1)_
- **Previous branch results read**: `iterv{{iter_minus_1}}/branch_results.json` _(required if iter > 1)_
- **Previous champion bench read**: `iterv{{iter_minus_1}}/bench.json` _(required if iter > 1)_
- **Previous attribution read**: `iterv{{iter_minus_1}}/attribution.json` _(if present)_
- **Additional wiki pages or manual queries**:
  - `{{page_or_query_1}}` — `{{why_it_changed_or_confirmed_the_plan}}`
  - `{{page_or_query_2}}` — `{{why_it_changed_or_confirmed_the_plan}}`

## Previous Evidence Summary

_Summarize what the previous iteration proved. This section must explain why
this iteration should not simply repeat a static candidate family._

- **Previous champion**: b{{prev_champion_idx}}, {{prev_ms}} ms
- **Previous regressions/failures**:
- **Methods now blocked**:
- **Methods worth extending**:
- **State changes that affect this plan**:

## Diagnosis

_What does the current kernel source look like, and where is the time going?
Read the target `.scpp` (and any sibling headers it includes) and reason from
the code structure: tile shape, pipeline stages, DMA pattern, ACE utilization,
LDM reuse, sync points._

> Example:
> The baseline `gemm_fp16_pvc_fp32_32x_test_kernel` launches a single grid with
> tile 32×128×64, no pipeline staging, and one DMA per K-iteration. LDM is
> <40% utilized and HBM bandwidth is the likely bottleneck. Compute is FP16 on
> ACE — the kernel never reaches peak FLOPs because DMA stalls the pipeline.

## Chosen methods

For each, state: (a) **priority level** from `references/optimization_catalog.md`,
(b) **trigger evidence** (cite the source-code pattern you're reacting to),
(c) the method, (d) the implementation delta vs. current best, (e) expected
benchmark shift.

### {{axis_1}} — `{{method_1_id}}` (Priority: {{P_level_1}})
- **Priority scan**: _List all higher-priority methods that were scanned and why each was skipped_
- **Trigger evidence**: _(cite source-code pattern: e.g. "single DMA per K-iter, no double-buffer")_
- **Method**:
- **Delta vs current best**:
- **Expected benchmark shift**:
- **Risks / coupling**:

### {{axis_2}} — `{{method_2_id}}` (Priority: {{P_level_2}})
- **Priority scan**: _List higher-priority methods scanned + skip reasons_
- **Trigger evidence**:
- **Method**:
- **Delta vs current best**:
- **Expected benchmark shift**:
- **Risks / coupling**:

### {{axis_3}} — `{{method_3_id}}` (Priority: {{P_level_3}})
_(only if 3 methods; omit otherwise)_
- **Priority scan**:
- **Trigger evidence**:
- **Method**:
- **Delta vs current best**:
- **Expected benchmark shift**:
- **Risks / coupling**:

## Orthogonality check

_Verify: (1) no pair is the same optimization under two names, (2) coupled
pairs not both selected, (3) all arch-compatible, (4) methods are mutually
orthogonal (see catalog's Combining Rules)._

## Hardware and API Constraint Check

_Document the constraints checked from wiki/manual evidence before writing
branch kernels._

- **DMA direction and API legality**:
- **Alignment / transfer-size requirements**:
- **SPM/LDM capacity budget**:
- **DMA queue / outstanding request budget**:
- **RMA/DMA contention risk**:
- **ACE applicability or exclusion reason**:
- **Synchronization / wait correctness**:

## Excluded candidates (higher-priority methods that were skipped)

_List every higher-priority method on each axis that was NOT selected, with
the exact reason:_

- `compute.ace_mma_atom` (P1) — skipped: kernel is elementwise, no matmul
- `memory.double_buffer_dma` (P1) — skipped: already in `selected_methods` from iter 1
- `latency.pipe0_pipe1_overlap` (P1) — skipped: kernel has no compute-DMA overlap opportunity

## Branch variants

_Describe the K hyperparameter variants generated for branch-and-select.
Each branch ships a `kernel.scpp` (+ optional sibling `*.hpp` if a header was
modified). Correctness and performance are measured by the teco-ops demo using
the configured prototxt case, `--warm_repeat`, `--perf_repeat`, and Average
Hardware Time. This table must be completed before writing branch kernels._

| Branch | Tile (M×N×K) | Stages | Warps | Other diff |
|--------|-------------|--------|-------|------------|
| b1 | 128×128×32 | 3 | 4 | — |
| b2 | 128×256×32 | 3 | 8 | — |
| b3 | 256×128×32 | 4 | 4 | — |
| b4 | 128×128×64 | 5 | 4 | — |

---

## Result (filled after benchmarking)

- **Champion branch**: b{{champion_idx}}
- **New ms**: {{new_ms}}
- **Speedup vs previous best**: {{speedup_vs_best_before}}
- **Speedup vs reference**: {{speedup_vs_ref}}
- **Validation**: {{validation_status}}
- **Retries needed**: {{retries}}
- **Outcome**: {{outcome}} (improved / regressed / failed_validation)

### Attribution (from ablation)

| Method | Ablated ms | Attribution ms | Contributed? |
|--------|-----------|---------------|--------------|
| {{m1_id}} | {{m1_ablated_ms}} | {{m1_attr_ms}} | {{m1_contributed}} |
| {{m2_id}} | {{m2_ablated_ms}} | {{m2_attr_ms}} | {{m2_contributed}} |
| {{m3_id}} | {{m3_ablated_ms}} | {{m3_attr_ms}} | {{m3_contributed}} |

### Post-hoc vs expected

_Did the benchmark shift match the prediction? If not, why?_

_Did attribution confirm the methods we expected to be effective?_

_This note becomes part of the final retrospective._
