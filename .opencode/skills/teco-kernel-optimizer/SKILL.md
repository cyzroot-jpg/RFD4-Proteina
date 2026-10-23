---
name: teco-kernel-optimizer
description: Iteratively optimize a SDAA kernel using benchmark-driven reasoning. Use this skill whenever the user asks to optimize, speed up, or improve the performance of a teco-ops `.scpp` kernel (SDAA), especially when they mention "iterative optimization", "kernel tuning", or ask Claude to "make this kernel faster". The skill drives a multi-iteration benchmark-driven optimization loop: pick methods by priority scan → generate K branch candidates → validate + benchmark → select champion → ablation attribution → update global state. Each iteration's artifacts are persisted under a timestamped run folder, and a final summary is emitted. Correctness and performance are measured by the teco-ops native prototxt demo.
---

# ⚠️ CRITICAL: 先调研，后优化

**在开始任何优化之前，必须先阅读 `LESSONS_LEARNED.md`！**

这个文件记录了一个重要的教训：**没有充分调研就开始优化是本末倒置**。

核心原则：
- **用户的目标是"最优算子"，不是"完成任务"**
- **先调研 → 再设计 → 后执行**
- **不要急于结束，可能需要 10+ 轮迭代**
- **调研应该占总时间的 30-50%，不要急于开始实现**

## 调研阶段必须完成的工作

### 1. 多次查询 teco-ops-wiki（至少 5 次不同角度）

**不要仅查询一次！** 应该从多个角度反复查询 ** 以下仅作为查询示例：

```bash
# 第 1 次：查询算子类型的优化方法
python3 teco-ops-wiki/scripts/query.py "<算子> performance optimization" --compact

# 第 2 次：查询具体技术（如异步 DMA、pipeline）
python3 teco-ops-wiki/scripts/query.py "async DMA pipeline overlap" --compact

# 第 3 次：查询硬件特性（如 ACE、矩阵加速）
python3 teco-ops-wiki/scripts/query.py "ACE matrix engine compute" --compact

# 第 4 次：查询通信优化（如 RMA、Broadcast）
python3 teco-ops-wiki/scripts/query.py "RMA broadcast communication" --compact

# 第 5 次：查询指令调度（如 P0/P1 双发射）
python3 teco-ops-wiki/scripts/query.py "P0 P1 dual issue scheduling" --compact

# 根据算子特点，可能还需要查询：
# - 内存模型和带宽
# - 数值精度优化
# - 特定硬件约束
```

**每次查询后**：
- 阅读所有相关页面（至少 top 5 结果）
- 提取关键信息（API、约束、最佳实践）
- 记录到调研文档中

### 2. 分析生产实现（至少 2 个）

**必须查看** `teco-ops-wiki/artifacts/repos/` 下的生产代码：
检索目标：第1步骤中检索到的相关页面的具体优化实现，特别是待优化方向的代码实现
- **PICT_smoke** 
- **teco-al** 
- **teco-ops** 

**分析重点**：
- Tile 大小配置（M1, N1, K1, M2, N2, K2）
- LDM 内存布局（每个 buffer 的大小和对齐）
- 流水线设计（双缓冲、三缓冲、状态机）
- ACE 配置（north/west 加载、writeback）
- RMA/DMA 使用模式
- SPE 网格划分（ROWS × COLS）

**提取最佳实践**：
- 实际使用的 tile 大小
- LDM 容量分配策略
- 关键优化技术的使用频率

### 3. 创建完整调研文档

**归档位置要求（必须遵守）**：

- 不要把任务级报告、调研记录、生产实现分析、优化进度或最终总结直接写到仓库根目录。
- `OPTIMIZATION_RESEARCH.md`、`PRODUCTION_ANALYSIS.md`、`GEMM_OPTIMIZATION_PROGRESS.md`、`GEMM_OPTIMIZATION_SUMMARY.md`、`FINAL_OUTPUT.md` 这类文件必须放到本次 `run_YYYYMMDD_HHMMSS/` 目录内，或归档到 `experiences/<op>/<YYYY-MM-DD>/`。
- 仓库根目录只保留稳定入口文件和项目结构文件，例如 `README.md`、`LICENSE`、`install_skills.sh`、`skills/`、`experiences/`、`teco-ops-wiki/`。
- 如果需要让用户从根目录发现某次经验，只在 `README.md` 或 `experiences/` 下的索引文件中添加链接，不复制报告到根目录。

在开始实现前，必须创建以下文档：

**a. 优化方法全面调研** (`run_YYYYMMDD_HHMMSS/OPTIMIZATION_RESEARCH.md` 或 `experiences/<op>/<YYYY-MM-DD>/OPTIMIZATION_RESEARCH.md`)
- 列出所有可能的优化技术（至少 10 种）
- 每种技术的原理、实现要点、约束、预期收益
- 优先级排序（必须/推荐/可选）
- 优化组合策略

**b. 生产实现分析** (`run_YYYYMMDD_HHMMSS/PRODUCTION_ANALYSIS.md` 或 `experiences/<op>/<YYYY-MM-DD>/PRODUCTION_ANALYSIS.md`)
- 分析的生产代码列表
- 提取的关键参数和设计模式
- Tile 大小选择指南
- 性能瓶颈诊断方法

**c. 迭代分析** (`iterv{i}/analysis.md`)
- 本次迭代选择的方法及理由
- 分支变体的配置差异
- 预期性能对比
- 硬件约束检查

### 4. 调研深度检查清单

**在开始实现前，必须确认**：

- [ ] 已多次查询 teco-ops-wiki（至少 5 次不同角度的查询）
- [ ] 已阅读所有相关的 wiki 页面（hardware, techniques, patterns）
- [ ] 已分析至少 2 个生产实现（sdcops, tecoal, tecocustom）
- [ ] 已提取生产实现的关键参数（tile 大小、LDM 布局、流水线设计）
- [ ] 已创建完整的调研文档（优化方法、生产分析、选择指南）
- [ ] 已设计至少 4 个优化分支（不同的 tile 配置、技术组合）
- [ ] 已验证所有硬件约束（ACE、DMA、LDM 容量）
- [ ] 已向用户展示调研结果并获得确认

**如果任何一项未完成，不得开始实现！**

## 必读内容（在开始优化之前）

1. teco-ops-wiki 的所有硬件页面（`wiki/hardware/*.md`）
2. teco-ops-wiki 的所有 API 页面（`wiki/techniques/*.md`）
3. 生产实现代码（tecocustom、sdcops、tecoal）
4. 异步 API（`memcpy_async`、P0/P1 双发射、ACE 等）

详见 `LESSONS_LEARNED.md`。

---

# SDAA Kernel Iterative Optimizer (v2 — Benchmark-Driven)

## What this skill does

Given:
- a **teco-ops working tree** with build system, `teco/`, `test/`, and source files containing the baseline `.scpp` kernel to optimize,
- an **op selector** (`--op <op_name>` or `--target <rel_path.scpp>`) naming which teco-ops kernel to optimize,
- an optional `--case <zoo/teco/.../test_case/case_0.prototxt>` when the default test case path is not correct,
- optional iteration count `N` (default **3**) and `branches` (default **4**),

the skill runs a **benchmark-driven, branch-and-select iterative optimization loop** and produces a timestamped directory of per-iteration artifacts plus a final summary.

> Dims are defined by the teco-ops prototxt case under `test/zoo/teco/<op>/test_case/`. To change problem size, edit or select a different prototxt case.

## Key point

1. **Branch-and-Select**: each iteration generates K candidate kernels (hyperparameter/implementation variants), benchmarks all, selects champion. 
2. **Ablation attribution**: after selecting champion, each method is individually ablated to determine its actual contribution.

## CRITICAL: Must try different optimizations in each iteration

**Every iteration MUST attempt genuinely different optimization strategies. Using the baseline kernel unchanged as all branches is NOT allowed.**

**Why:** The purpose of iterative optimization is to explore the optimization space. Copying the baseline as all branches defeats this purpose and wastes iteration opportunities.

**What this means:**
- Each iteration should generate K **truly different** optimization variants
- Even if modifications might fail (break correctness or degrade performance), you MUST try
- Learn from failures: analyze why a modification failed, then try a different approach in the next iteration
- If all branches in an iteration fail, record the failure reasons in analysis.md and try a completely different direction in the next iteration
- Do NOT give up and use baseline as a "control" — always attempt something new

**Examples of what to try:**
- Different tile sizes (M1, N1, K1)
- Different core partitioning (ROWS, COLS)
- Different pipeline schedules (reordering operations)
- Different synchronization patterns
- Different DMA/RMA patterns
- Different LDM allocation strategies

## Inputs the skill expects from the user

Before starting, confirm you have:

1. **Working tree** — a teco-ops directory with `teco/`, `test/`, and root `build.sh`. This is the baseline; the skill never mutates the original tree — it copies it per iteration.
2. **Op selector** — either `--op <op_name>` (used as the teco-ops test build target) or `--target <path/to/kernel.scpp>` (relative path inside the tree) when the op is ambiguous.
3. **Test case** — optional `--case <prototxt>` relative to `test/`; default is `zoo/teco/<op>/test_case/case_0.prototxt`.
4. **Iteration count `N`** (default 3)
5. **`branches`** — how many hyperparameter variants per iteration (default 4)

> `benchmark.py`, `preflight.py`, and all driver scripts are bundled at `scripts/`; they default to the bundled copies automatically.

If any of these are missing, ask the user once — briefly — then proceed.

## teco-ops correctness and performance contract

The skill uses the native teco-ops C++ test framework described in teco-ops `README.md` and `doc/README_OP.md`.

1. Build the operator library from the teco-ops root: `bash build.sh --build teco`.
2. Build the test framework from `test/`: `source env.sh && sh build.sh --arch teco -f <op>`.
3. Run the prototxt case with `./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 --case_path=<case>`.
4. Treat `ALL PASSED` / no failure as correctness and parse `[Average Hardware Time]: <float>` as the kernel metric.

`benchmark.py` implements exactly this flow and exits non-zero if the demo does not produce passing correctness and Average Hardware Time.

## The loop at a glance

```
0. check_env          → env.json (SDAA device, tecocc)
1. init run folder    → run_YYYYMMDD_HHMMSS/
2. copy baseline      → baseline/ + bench once to seed `best`
3. for i in 1..N:
     a. Claude picks methods (priority scan)     → analysis.md (CoT)
     b. Claude writes K branch kernels (same methods, diff hyperparams)
     c. branch_explore.py: compile + bench all K → select champion
     d. if champion FAIL: regenerate (max 3 retries)
     e. ablate.py: single-method rollback bench  → attribution.json
     f. update state with attribution results
4. emit summary.md
```

Steps (c) and (e) are **deterministic** — run via scripts.
Steps (a) and (b) are **where Claude thinks** — follow the reasoning rules in `references/optimization_catalog.md`.

---

## Step 0 — Check local environment

Run the env probe **before** doing anything else:

```bash
python <skill>/scripts/check_env.py --out ./env.json
```

It records: SDAA device name + model, tecocc path + version, SDAA runtime/driver version, torch + triton versions. The skill runs in benchmark-only mode by default — no profiler is required.

## Step 0b — Preflight the tree + target contract

```bash
python <skill>/scripts/preflight.py \
  --baseline ./working_tree \
  --op <op_name>
# or, when --op is ambiguous:
# python <skill>/scripts/preflight.py --baseline ./teco-ops --target teco/ual/kernel/my_op/my_op.scpp --case zoo/teco/my_op/test_case/case_0.prototxt
```

Validates the teco-ops tree structure, resolves the target `.scpp` (known `--op` map or `--target` direct path), and records the prototxt test case. On error, surface to the user. `orchestrate.py setup` runs this automatically.

## Step 1 — Initialize the run folder

```bash
python <skill>/scripts/state.py init \
  --baseline ./working_tree \
  --op <op_name> \
  --iterations 3 \
  --branches 4 \
  --env ./env.json
# or: --target teco/ual/kernel/my_op/my_op.scpp --case zoo/teco/my_op/test_case/case_0.prototxt
```

Creates `./run_YYYYMMDD_HHMMSS/` next to the tree, copies the entire working tree into `run_dir/tree/` (the working copy the loop mutates), and writes `state.json`:

```jsonc
{
  "run_dir": "...",
  "tree": "<run_dir>/tree",                     // working copy of the baseline tree
  "baseline_tree": "<abs path to original>",
  "op": "<op_name>",                             // or null if --target used
  "target_kernel": "teco/ual/kernel/my_op/my_op.scpp",
  "case_path": "zoo/teco/my_op/test_case/case_0.prototxt",
  "best_file": "<target_kernel relpath>",       // relpath inside working tree
  "best_metric_ms": null,
  "env": {...},
  "iterations_total": 3,
  "branches": 4,
  "selected_methods": [],
  "effective_methods": [],
  "ineffective_methods": [],
  "implementation_failed_methods": [],
  "history": [],
  "frontier": []
}
```

`ref_file` and `dims` are gone — correctness + reference timing live inside the test func.

## Step 2 — Seed `best` with a baseline benchmark

```bash
python <skill>/scripts/run_iteration.py seed-baseline \
  --state ./run_*/state.json
```

Runs `benchmark.py --tree <working_tree> --kernel <target.scpp>` on the original baseline to capture initial timing. The result populates `best_metric_ms` and `best_file`.

> **Shortcut**: you can skip `benchmark.py` and obtain the baseline directly with the tree's build/run script if available.

## Step 3 — Iteration loop (repeat for i = 1..N)

### 3a. Select methods (Claude reasons here)

**Read** (in this order):
1. `references/optimization_catalog.md` — priority-ordered catalog
2. `state.json` — `best_file`, `selected_methods`, `effective_methods`, `ineffective_methods`, `implementation_failed_methods`
3. The current `best_file` source code
4. `iterv{i-1}/attribution.json` (if i > 1) — which methods actually helped last round

**Selection rule — PRIORITY SCAN**:

Scan the catalog **from P1 downward**. For each method, check:
1. Is `method.id` already in `selected_methods`? → skip (already tried)
2. Does the target SDAA model meet the method's arch requirement? → skip if not
3. Does the method's **skip condition** apply to the current kernel? → skip (record reason in analysis.md)
4. Does the method's **trigger condition** match the current kernel's structure (analyzed from source)? → skip if not applicable

Select the **first methods that pass all four checks** until you have a coherent orthogonal set (typically 2-3 methods). For each, write Chain-of-Thought grounded in the source code.

**teco-ops-wiki guidance (MANDATORY — NOW ENFORCED BY SCRIPTS)**:

teco-ops-wiki is the skill that captures all SDAA/TECO syntax knowledge. **You MUST systematically query the wiki BEFORE each iteration** — not as a last resort, but as the first step in method selection and code generation.

**IMPORTANT: Wiki query is now automated!**

As of the latest update, the optimization scripts **automatically query teco-ops-wiki** before each iteration:
- `orchestrate.py open-iter` calls `query_wiki.py` and saves results to `iterv{i}/wiki_queries.json`
- `branch_explore.py` also calls `query_wiki.py` if wiki query hasn't been done yet
- The wiki query results are saved to `iterv{i}/wiki_queries.json` and MUST be read before selecting methods

**Required workflow for each iteration (PLAN-FIRST, mandatory)**:

1. **Pre-iteration wiki query (AUTOMATED)**:
   - When you run `orchestrate.py open-iter --iter N`, the script automatically queries the wiki
   - Results are saved to `iterv{N}/wiki_queries.json`
   - **You MUST read this file before selecting methods or generating code**
   - The file contains:
     - Queries for operator-specific optimization techniques
     - Key wiki pages (e.g., `kernel-sdaa-gemm`, `technique-ace-double-buffering`)
     - Hardware constraints and best practices

2. **Read current state and previous evidence BEFORE planning**:
   - Read `state.json` before every iteration.
   - Read the current `best_file` source code before every iteration.
   - If `N > 1`, read `iterv{N-1}/branch_results.json`, `iterv{N-1}/bench.json`, and `iterv{N-1}/analysis.md`.
   - If available, read `iterv{N-1}/attribution.json` and use it to block or prioritize methods.
   - Identify which methods are blocked by `ineffective_methods` or `implementation_failed_methods`.

3. **Write the new iteration plan BEFORE generating kernels**:
   - Write `iterv{N}/analysis.md` before creating `iterv{N}/branches/b*/kernel.scpp`.
   - The plan must state:
     - Which `wiki_queries.json` pages/results were read.
     - What was learned from the previous iteration's branch results and champion timing.
     - Which old directions are blocked, ineffective, or require repair.
     - The new optimization hypothesis for this iteration.
     - The exact 4 branch differences and why each is worth testing.
     - Hardware/API constraints checked (DMA alignment, SPM size, queue pressure, RMA/DMA contention, ACE applicability when relevant).
   - Do not reuse a fixed candidate family without explaining why the previous evidence justifies another sweep.

4. **Manual wiki queries (if needed)**:
   - If you need additional information not in `wiki_queries.json`, you can manually query:
     ```bash
     python3 <teco-ops-wiki>/scripts/query.py "<topic>" --compact
     python3 <teco-ops-wiki>/scripts/get_page.py <page-id>
     ```
   - Document additional queries in `analysis.md`

5. **Use wiki knowledge for method selection**:
   - Read `iterv{i}/wiki_queries.json` FIRST
   - Reference hardware primitives (ACE, DMA, RMA, Broadcast, LDM/SPM)
   - Follow SDAA-native optimization patterns (double buffering, ACE accumulator dual-buffer, RMA/DMA interleaving)
   - Apply alignment rules (16B/64B for SIMD, 4B for DMA, 128B chunks for optimal bandwidth)
   - Respect DMA queue budget (≤11 outstanding requests)

6. **Generate candidates only after the plan is written**:
   - Generate `iterv{N}/branches/b{1..K}/kernel.scpp` after `analysis.md` and `methods.json` exist.
   - Each branch must match a branch entry in `analysis.md`.
   - Each branch must be genuinely different from the others and from recently failed/ineffective branches.

7. **Use wiki examples for code generation**:
   - Follow worked examples from the wiki when generating kernel code
   - Use SDAA hardware terminology (SPA, SPE, SPM/LDM, ACE, pipe0/pipe1, not NVIDIA terms)
   - Apply verified patterns: widen-compute-narrow, aligned bulk + tail, 4× unroll, FMA over mul+add

8. **Run correctness + benchmark, then update the next plan from evidence**:
   - Run `branch_explore.py` only after `analysis.md`, `methods.json`, and all branch kernels exist.
   - Use correctness and `Average Hardware Time` from the native demo as the only acceptance signal.
   - After `state.py update`, use the new `state.json`, `branch_results.json`, `bench.json`, and optional `attribution.json` as the starting evidence for the next iteration.

9. **Avoid correctness errors**:
   - Check that memory accesses follow alignment rules from wiki
   - Verify DMA/RMA patterns don't cause contention (see `pattern-rma-contention`)
   - Ensure tile sizes match hardware constraints (e.g., K tile as multiple of 32 for ACE)
   - Validate that pipeline state machines correctly handle double/triple buffering

**Example queries by operator**:
- GEMM: `kernel-sdaa-gemm`, `technique-ace-double-buffering`, `pattern-rma-contention`
- RMSNorm: query for reduction patterns, LDM pressure
- Flash Attention: query for softmax, tiling, memory reuse

**Evidence tracking**: In `analysis.md`, document:
- That you read `iterv{i}/wiki_queries.json` (REQUIRED)
- That you read `state.json`, the current best source, and previous iteration artifacts (REQUIRED for `i > 1`)
- Which additional wiki pages were queried (if any)
- How wiki knowledge influenced method selection
- How previous benchmark evidence changed the plan
- Specific hardware constraints or patterns applied from wiki

**Hard constraints**:
1. Methods in `ineffective_methods` are **blocked** unless the kernel structure has fundamentally changed since they were tried.
2. Methods in `implementation_failed_methods` require explicit acknowledgment of the prior failure.
3. All methods must be **arch-compatible** and **mutually orthogonal** (see catalog's Combining Rules).
4. **You MUST read `wiki_queries.json` before selecting methods** — this is now enforced by the scripts.
5. **You MUST write `analysis.md` before branch exploration** — `orchestrate.py close-iter` rejects iterations without it.
6. **You MUST derive each new plan from previous evidence** — do not run many rounds from a static pre-generated candidate template.

Save to `iterv{i}/analysis.md` using the template in `templates/iteration_report.md`.

### 3b. Generate K branch kernels (Claude writes code)

Use `sdaa-kernel-candidate-generator` for this code-generation step. The optimizer remains responsible for method selection, branch paths, benchmark execution, champion selection, state updates, and reporting; the generator only writes candidate kernel files that preserve the existing teco-ops interface and validation contract.

Before writing candidates, read:
1. the installed `sdaa-kernel-candidate-generator` skill (`../sdaa-kernel-candidate-generator/SKILL.md` when using this repo layout)
2. `../sdaa-kernel-candidate-generator/references/code-style.md`
3. `../sdaa-kernel-candidate-generator/references/kernel-generation-contract.md`

All K branches share the **same method combination** from step 3a. They differ in **hyperparameters and implementation details**:
- Tile sizes (BLOCK_M, BLOCK_N, BLOCK_K)
- Pipeline stage count (num_stages)
- Warp count (num_warps)
- Implementation variant within a method (e.g., swizzle mode, MMA atom selection)

Write K kernels under `iterv{i}/branches/b{1..K}/kernel.scpp`. If a branch also modifies a sibling header the `.scpp` includes, place it alongside as `iterv{i}/branches/b{1..K}/<header>.hpp` — `benchmark.py --hpp` installs these next to the target.

Each branched `kernel.scpp` must preserve the teco-ops operator interface expected by the selected UAL dispatch path and prototxt test case.

### 3c. Branch explore: compile + benchmark all K

```bash
python <skill>/scripts/branch_explore.py \
  --state ./run_*/state.json \
  --iter $i
```

For each branch, `branch_explore.py` calls `benchmark.py --tree <working_tree> --kernel <branch.scpp> [--hpp ...] --target <target_kernel>` which installs the branch `.scpp` (+ sibling `.hpp`) over the target path in the working tree, rebuilds teco-ops, builds the C++ demo, and runs the configured prototxt case. Selects champion = fastest valid branch. Non-champions saved to `state.frontier`.

### 3d. Repair on validation failure (up to 3 retries per iteration)

If champion fails correctness, use `sdaa-kernel-candidate-generator` in repair mode to rewrite the narrowest failing portion, then re-run 3c.

### 3e. Ablation attribution

```bash
python <skill>/scripts/ablate.py \
  --state ./run_*/state.json \
  --iter $i
```

For each method, expects Claude to have generated an ablated kernel (champion minus that one method) under `iterv{i}/ablations/{method_id}/kernel.scpp`. Benchmarks each via `benchmark.py` against the same working tree. Computes attribution:
```
attribution(m) = ms_without_m - ms_champion
```
Positive attribution = the method contributed positively. Near-zero or negative = the method was not helpful.

Writes `iterv{i}/attribution.json`.

Use `sdaa-kernel-candidate-generator` in ablation mode for these kernels: remove exactly one named method from the champion and avoid retuning unrelated hyperparameters.

### 3f. Update global state

```bash
python <skill>/scripts/state.py update \
  --state ./run_*/state.json \
  --iter $i \
  --kernel iterv{i}/kernel.scpp \
  --bench iterv{i}/bench.json \
  --methods-json iterv{i}/methods.json \
  --attribution iterv{i}/attribution.json
```

Rules:
- `selected_methods += all methods` (always)
- Method enters `effective_methods` **only if**: attribution > noise_threshold
- Method enters `implementation_failed_methods` if: the method's branch failed to compile or broke correctness
- Method enters `ineffective_methods` if: attribution ≤ noise_threshold
- If `new_ms < best_ms` by more than noise_threshold → `best_file` updated (champion `.scpp` becomes the new best)
- Append record to `state.history`

---

## Step 4 — Final summary

```bash
python <skill>/scripts/summarize.py \
  --state ./run_*/state.json \
  --out ./run_*/summary.md
```

Final summaries and handoff reports must stay inside the run directory or be archived under `experiences/<op>/<YYYY-MM-DD>/`. Do not create root-level `FINAL_OUTPUT.md`, `*_SUMMARY.md`, `*_PROGRESS.md`, `OPTIMIZATION_RESEARCH.md`, or `PRODUCTION_ANALYSIS.md` files.

---

## Reasoning references

- **`references/optimization_catalog.md`** — Catalog of optimization methods by axis, with algorithmic methods section.
- **`sdaa-kernel-candidate-generator`** — Narrow kernel candidate generation contract for branch kernels, ablations, and repair attempts. Use this instead of invoking `teco-ops-agent/AGENTS.md` for normal existing-kernel optimization.

## Reference documentation

- **`teco-ops-wiki/`** (CRITICAL — query before each iteration):
  - **What it provides**: All SDAA/TECO hardware primitives, native syntax, optimization patterns, and worked examples
  - **When to use**: BEFORE selecting methods and generating code in EVERY iteration
  - **How to query**:
    ```bash
    # Query by topic
    python3 <teco-ops-wiki>/scripts/query.py "<topic>" --compact

    # Retrieve specific page
    python3 <teco-ops-wiki>/scripts/get_page.py <page-id>

    # Example: GEMM optimization
    python3 <teco-ops-wiki>/scripts/query.py "GEMM FP16 FP32 memory optimization" --compact
    python3 <teco-ops-wiki>/scripts/get_page.py kernel-sdaa-gemm
    python3 <teco-ops-wiki>/scripts/get_page.py technique-ace-double-buffering
    ```
  - **Key pages by operator**:
    - GEMM: `kernel-sdaa-gemm`, `technique-ace-double-buffering`, `pattern-rma-contention`, `technique-dma-queue-budgeting`
    - General: `technique-simd-optimization-patterns`, `hw-sdaa-memory-model`, `hw-ace`
  - **What to extract**:
    - Hardware constraints (alignment, tile sizes, DMA queue depth)
    - Optimization patterns (double buffering, RMA/DMA interleaving, Broadcast)
    - Worked examples (reference implementations, pipeline state machines)
    - Correctness rules (avoiding RMA contention, proper synchronization)
  - **Why critical**: Prevents correctness errors (like iterations 1-2 failures) and guides effective optimization

- **`gemm-performance-modeling/`** (if available in the working tree):
  - Theoretical performance modeling for GEMM kernels on SDAA/TECO ACE
  - Use in step 3a to establish theoretical upper bounds (compute/bandwidth roofline)
  - Complementary to teco-ops-wiki: wiki provides hardware model and native syntax, this skill provides quantitative expectations

---

## Failure modes to watch for

- **Benchmark crashes** → check `bench.json` `"error"` field + `bench.stderr.txt`.
- **teco-ops demo missing Average Hardware Time** → check `bench.stderr.txt`, the prototxt case, and whether `test/build/demo` was built for the selected op.
- **Ambiguous op** → re-run preflight with `--target <rel_path.scpp>` and `--case <prototxt>` to disambiguate.
- **Champion chosen but all methods have near-zero attribution** → the speedup came from hyperparameter change, not methods. Record in analysis.md.
- **Branch explore: all K branches fail validation** → Claude must rewrite with different approach.

---

## Output contract

```
<parent-of-tree>/run_YYYYMMDD_HHMMSS/      (created next to the working tree)
├── env.json
├── state.json
├── tree/                        (working copy — branches install over target .scpp here)
├── baseline/
│   └── bench.json               (seed timing on original baseline)
├── iterv1/
│   ├── kernel.scpp              (champion — installed over tree/<target_kernel> on bench)
│   ├── analysis.md              (methods + CoT)
│   ├── methods.json
│   ├── attribution.json
│   ├── bench.json
│   └── branches/
│       ├── b1/ ... b4/          (all branch candidates: kernel.scpp + optional *.hpp)
├── iterv2/...
├── iterv3/...
└── summary.md
```

Long-lived reports copied out of a run folder must use:

```
experiences/<op>/<YYYY-MM-DD>/
├── OPTIMIZATION_RESEARCH.md
├── PRODUCTION_ANALYSIS.md
├── <OP>_OPTIMIZATION_PROGRESS.md
├── <OP>_OPTIMIZATION_SUMMARY.md
└── FINAL_OUTPUT.md
```

Do not place these task-specific artifacts in the repository root.
