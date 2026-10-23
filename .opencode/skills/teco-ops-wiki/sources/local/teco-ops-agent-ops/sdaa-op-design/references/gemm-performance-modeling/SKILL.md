---
id: source-teco-ops-agent-ops-sdaa-op-design-references-gemm-performance-modeling-skill-47debbd9
title: "teco-ops-agent ops: sdaa-op-design/references/gemm-performance-modeling/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/gemm-performance-modeling/SKILL.md
relative_source_path: sdaa-op-design/references/gemm-performance-modeling/SKILL.md
captured_at: 2026-08-04
---

---
name: gemm-performance-modeling
description: Use when analyzing or documenting theoretical performance for GEMM-like matrix multiply kernels on SDAA/TECO ACE, especially FP16/BF16/FP32 input-output combinations, variable M/N/K, tile choices, ACE frequency, DMA/HBM roofline, LDM capacity, pipeline, and core partitioning. Produces a parameterized compute, bandwidth, roofline, and optimization-order analysis.
metadata:
  short-description: GEMM theoretical performance model
---

# GEMM Performance Modeling

Use this skill when the user asks for GEMM theoretical performance modeling, ACE compute estimates, roofline analysis, bandwidth evaluation, tiling guidance, or optimization methodology for SDAA/TECO GEMM kernels.

## Inputs to collect

Required:

- `M`, `N`, `K`
- input dtype of A/B, such as `fp16`, `bf16`, `fp32`, `int8`
- accumulation/output dtype, such as `fp32`, `fp16`

Recommended:

- tile sizes: `M1`, `N1`, `K1`
- ACE/core topology: `ROWS`, `COLS`, `cores`
- ACE micro tile: `ACE_N`, `ACE_K`
- ACE frequency in GHz; for half frequency use `full_freq/2`
- LDM usable maximum per core, in bytes, when the user provides it or the code under analysis explicitly defines it
- whether layoutA/layoutB cost is included
- HBM/DMA bandwidth assumptions: conservative measured, DMA_GET aggregate, HBM effective, or user-provided
- kernel dataflow details: B reuse across M tiles, partial-C workspace policy, split-K behavior

If values are missing, use these defaults only when they match the code under analysis:

```text
M1=1024, N1=256, K1=1536
ROWS=4, COLS=8, cores=32
ACE_N=32, ACE_K=32
ACE frequency=1.18GHz
layout included=false
```

## Fast path script

Prefer the bundled script for deterministic arithmetic:

```bash
python3 skills/gemm-performance-modeling/scripts/gemm_perf_model.py \
  --m 2048 --n 2048 --k 7680 \
  --input-dtype fp16 --output-dtype fp32 --accum-dtype fp32 \
  --m1 1024 --n1 256 --k1 1536 \
  --rows 4 --cols 8 --cores 32 \
  --ace-n 32 --ace-k 32 \
  --ace-ghz 1.18 \
  --hbm-gbps 256 \
  --layout exclude
```

Run the command from the repository root or pass the absolute script path.

Pass `--ldm-bytes` only when the usable LDM maximum is known or intentionally assumed, for example:

```bash
python3 skills/gemm-performance-modeling/scripts/gemm_perf_model.py ... --ldm-bytes 256kib
```

## Analysis workflow

1. Identify GEMM semantics.
   - Confirm layout and transpose flags.
   - Use `FLOPs = 2*M*N*K` for dense GEMM.
   - Use dtype sizes for traffic, not hardcoded fp16/fp32 assumptions.

2. Model tiling and ACE compute.
   - Derive `M2=M1/COLS`, `K2=K1/ROWS`, `N2=ACE_N`.
   - Derive loop counts with ceil division.
   - For a full ACE descriptor, compute `FLOPs_desc = 2*M2*ACE_N*ACE_K`.
   - For ideal ACE cycles, use `C_desc ~= M2` unless hardware docs or profiler indicate otherwise.
   - Compute ideal peak:

```text
P_core = FLOPs_desc * F_ace / C_desc
P_total = cores * P_core
```

3. Apply empirical ACE efficiency if relevant.
   - For this 32X pattern with `K2=384`, use `~0.89` of ideal as a practical ACE-only upper bound unless better microbench data is provided.
   - If using ACE.xlsx style data from another shape, scale by frequency only if the microbench is comparable.

4. Model ACE-LDM port bandwidth.
   - West bytes per descriptor: `M2 * ACE_K * sizeof(input_dtype)`.
   - North bytes per descriptor: `ACE_K * ACE_N * sizeof(input_dtype)`.
   - Output bytes per writeback block: `M2 * ACE_N * sizeof(output_dtype)`.
   - Average output bandwidth should be amortized by the number of ACE descriptors accumulated before writeback.

5. Model LDM capacity.
   - Always report the modeled LDM usage.
   - Report the usable LDM maximum per core only when it is supplied by the user or explicitly present in the code under analysis.
   - Do not hardcode `235*1024` as a universal limit; some kernels can intentionally use more.
   - For code paths that define a local limit such as `ldm_max_size = 235 * 1024`, report it as that path's code-defined limit, not as a hardware maximum.
   - Match the current 32X static check:

```text
ldm_use =
  M2*K2*sizeof(input_dtype)
  + 3*N2*K2*sizeof(input_dtype)
  + 6*(N2*M2/ROWS)*sizeof(output_dtype)
  + 2*N2*M2*sizeof(output_dtype)
```

   - Report `ldm_use`. If `ldm_max` is provided, also report `ldm_margin = ldm_max - ldm_use`.
   - If the kernel has dynamic layout/rebine buffers, report their LDM maximum separately when code provides one.
   - Treat LDM overflow as a hard feasibility constraint only when the usable maximum is known.

6. Model compute-only HBM/workspace traffic.
   - If layout is excluded, do not count raw A/B layout reads/writes.
   - Count layoutA/layoutB reads during compute.
   - Count B rereads according to M tile reuse.
   - Count partial C workspace reads/writes according to split-K/KTile loops.
   - Count final C write.
   - For the current 32X no-tail pattern:

```text
traffic_compute ~= A + MTileLoops*B + 2*(KTileLoops-1)*C + C
```

7. Compute roofline.

```text
AI = FLOPs / traffic_bytes
P_hbm = AI * bandwidth
P_roof = min(P_ace, P_hbm)
```

Use multiple bandwidth tiers when available:

```text
conservative measured: 130.8 GB/s
DMA_GET aggregate: 256 GB/s
HBM effective estimate: 328 GB/s
HBM theoretical: 409.6 GB/s
```

8. Add optimization design order.
   - First target ACE saturation and continuous `load_west` issue.
   - Check LDM capacity against the usable maximum, then bank/MBOX pressure.
   - Check ACE West/North/output bandwidth.
   - Then check HBM/DMA roof.
   - Design DMA/RMA/SIMD/ACE pipeline.
   - Finally decide core partitioning and data reuse strategy.

## Reporting guidance

Clearly separate:

- code-confirmed facts
- assumptions
- theoretical ideal
- empirical/microbench-adjusted upper bound
- LDM modeled usage, and usable maximum plus remaining margin when a maximum is provided
- bandwidth roof
- evidence needed to confirm bottlenecks

Do not claim DMA/RMA/sync wait bottlenecks from source alone. Per the hardware execution model, static wait sites are only potential bottlenecks until profiler, cycle counters, or reply-wait statistics confirm them.
