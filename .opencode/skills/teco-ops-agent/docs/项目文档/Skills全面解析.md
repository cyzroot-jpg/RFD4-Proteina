# TECO Ops Agent Skills 全面解析

> 版本：0.1.0 · 更新：2026-07 · 仓库：`teco-ops-agent`
>
> 当前默认算子工作树已迁移为 `teco_ops` backend（默认路径 `../../teco-ops`）。
> 新算子默认按 teco-ops interface + UAL 布局落地，并使用
> `ops/kernel-bench/scripts/teco_ops_test.py` 调用 teco-ops C++ 测试框架完成正确性和性能验收。
> 文中 `swdnn_test_ops` / `torch_verify.py` / `check_delivery.py` 内容仅作为历史兼容路径参考。

本文档对 `ops/` 目录下全部 **9 个 skill** 进行系统解析，涵盖功能定位、触发条件、使用场景、输入输出、核心约束及 skill 间协作关系。

---

## 1. Skill 分类总览

| 分类 | Skill | 一句话定位 |
|------|-------|-----------|
| **环境与架构** | `sdaa-env-check` | 环境门禁：SDK/编译器/设备驱动状态检查 |
| **API 与检索** | `sdaa-docs-search` | 本地优先的全文 API/文档检索 |
| **算子开发主链路** | `sdaa-op-requirement` | **强制**需求采集：一问一答产出 requirement.json |
| | `sdaa-op-design` | 算子设计 v3：分块/分核/双缓冲/LDM/流水 |
| | `sdaa-op-template` | 脚手架 + L3 精度验收 + 落地门禁 |
| | `kernel-bench` | Kernel device 端耗时测量（rt_time_cycle） |
| **学习与优化** | `sdaa-performance-best-practices` | 性能优化总路由：机制层+领域层经验检索 |
| | `sdaa-op-learning-validation` | 可归因 attempt 验证 + evidence snapshot + 长期知识沉淀 |
| **仓库维护** | `record-repo-change` | 简要记录仓库功能问题修复和功能支持 |

---

## 2. 环境与架构基础

### 2.1 `sdaa-env-check` — 环境门禁

| 维度 | 内容 |
|------|------|
| **功能** | 检查 SDAA/TECO 算子开发环境是否就绪 |
| **触发关键词** | 「环境检查」「SDAA环境」「teco-smi」「tecocc」「setvars」「设备查询」「SDPTI」「空闲设备」 |
| **使用场景** | ① 任何算子开发的第一步（门禁）；② 新环境安装后验证；③ 编译/运行失败时排查环境问题 |
| **何时可跳过** | **不可跳过** — AGENTS.md 明确要求「优先运行 sdaa-env-check」 |

**核心命令**：

```bash
# 完整环境检查（推荐）
bash ops/sdaa-env-check/scripts/check_env.sh --json -o /tmp/env_check.json

# 设备信息结构化查询
python3 ops/sdaa-env-check/scripts/device_info.py --json

# 选空闲设备（gid:auto）
python3 ops/sdaa-env-check/scripts/device_info.py --idle
```

**检查项详情**：

| 检查项 | 说明 | 必需 |
|--------|------|:---:|
| `/opt/tecoai/setvars.sh` | TECO SDK 环境入口脚本 | 是 |
| `tecocc` | SDAA 设备编译器 | 是 |
| `cmake` | 工程构建工具 | 是 |
| `sdaa_runtime.h` | SDAA Runtime 头文件 | 是 |
| `teco-smi` | 设备管理 CLI | 是 |
| `SDPTI_SDK_ROOT` | 性能采集 SDK | 否 |
| `python3` | 脚本与编排器（建议 ≥3.10） | 是 |

**输出契约（--json）**：

```json
{
  "status": "pass|warn|fail",
  "errors": 0,
  "warnings": 0,
  "checks": [
    {"name": "setvars", "result": "pass", "detail": "..."}
  ],
  "device": { }
}
```

**关键约束**：
- Codex 沙箱内 `teco-smi` 可能误报 `SDAADriver is not loaded`，精度验收**必须**在宿主机执行
- 编排器选卡约定：`gid: auto` → 优先空闲 index，无空闲回退全部可见

---

## 3. API 与文档检索

### 3.1 `sdaa-docs-search` — 本地+在线文档检索

| 维度 | 内容 |
|------|------|
| **功能** | 本地优先的 API 与文档全文检索，本地未命中时回退到在线 MCP |
| **触发关键词** | 「文档检索」「API 查询」「rt_dma」「rt_rma」「batch_」「tecolibrt」「tecokernel」「本地搜索」「docs-search」 |
| **使用场景** | ① 不确定 API 签名/用法时快速查找；② 设计阶段查阅约束和参数；③ 实现 kernel 时需要确认 API 细节 |

**检索优先级**：

```
1. ops/sdaa-docs-search/references/
2. thirdParty 头文件（API 签名）
3. ops/sdaa-performance-best-practices/references/
         ↓ 本地未命中
4. Codex MCP docs-center（在线手册）
```

**核心命令**：

```bash
# 构建/更新本地索引
python3 ops/sdaa-docs-search/scripts/build_index.py

# 检索（JSON 输出供 agent 消费）
python3 ops/sdaa-docs-search/scripts/search_docs.py --query "rt_dma_get" --json --top 5
```

**索引范围**：本仓库 `ops/**/references/*.md`、工作区 `sdaa-kernel-poilot/knowledge/*.md`、`swdnn_test_ops/thirdParty/*/include/**/*.h`、`/opt/tecoai/include`

**重要边界约束**：
- **禁止**用本 skill 在 `swdnn_test_ops/src/` 搜索「类似算子」作为新算子交付物
- 算子交付必须走 `sdaa-op-design` + `scaffold_op --from-design`

---

## 4. 算子开发核心流程（强制链路）

### 4.1 `sdaa-op-requirement` — 需求采集（强制第一步）

| 维度 | 内容 |
|------|------|
| **功能** | 通过 `AskUserQuestion` 逐字段采集用户需求，产出结构化 `requirement.json` |
| **触发关键词** | 「需求采集」「需求收集」「算子需求」「requirement」「新算子」 |
| **使用场景** | **任何新算子开发的第一步**（即使算子功能明确如 gemm） |
| **可跳过？** | **不可 — AGENTS.md 标注为「强制步骤」** |

**采集内容（5 轮逐字段提问）**：

| 轮次 | 采集字段 | 示例 |
|:---:|------|------|
| 1 | op 名、computation_type、功能描述、数学公式 | `gemm`、`matmul`、`C = A × B` |
| 2 | shape_keys、各维度含义 | `["M","N","K"]`、`M=rows of A/C` |
| 3 | smoke shape、default shape | `M=64,N=32,K=128` / `M=512,N=256,K=8192` |
| 4 | dtype_io、dtype_acc、golden atol/rtol | `float16`、`float32`、`atol=0.5, rtol=0.02` |
| 5 | 各 IO 张量的 name/dtype/shape/描述 | `A: float16 [M,K]` |

**执行方式**（agent 环境下 stdin 交互不可用）：
1. Agent 用 `AskUserQuestion` 逐字段采集
2. 写入临时 JSON → `collect_requirement.py --from-json` 验证写入

**产出**：`swdnn_test_ops/op_requirements/<op>/requirement.json`

**下发消费**：`sdaa-op-design` 的 `init_design.py --from-requirement` 读取

---

### 4.2 `sdaa-op-design` — 算子设计（v3 schema）

| 维度 | 内容 |
|------|------|
| **功能** | 在一代芯片约束下产出完整算子设计文档：shape 模式、分层吞吐模型、分块/分核/双缓冲/LDM bank/流水策略 |
| **触发关键词** | 新算子开发的设计阶段；已有算子优化前重新设计 |
| **使用场景** | ① locked-shape 最优方案搜索；② ranged-shape 稳定方案与切换点；③ ideal_search 理论上界探索 |

**三种 shape 模式**：

| 模式 | 说明 |
|------|------|
| `locked` | 用户给定 shape，找该 shape 最优候选 |
| `ranged` | 用户给定 shape 区间，找稳定方案和切换点 |
| `ideal_search` | 用户不给 shape，探索理想 shape 和理论上界 |

**设计流程**：

```
operator_definition（轴/依赖/复用）
    → parameters（locked/ranged/ideal_search）
    → throughput_model（layered_t1 分层吞吐模型）
    → tiling_strategy（可行域搜索与候选）
    → core_partition_strategy（网格/通信/规约）
    → double_buffer_strategy（overlap 条件）
    → ldm_planning（usable budget + bank 分配）
    → pipeline_layout（fill/steady/drain）
    → validate_design.py strict 校验
    → render design.md
```

**强流程门禁**：

| 阶段 | 命令 | 允许空置 |
|------|------|:---:|
| 初始化草稿 | `init_design.py --from-requirement` | ✓ |
| 结构校验 | `validate_design.py --draft` | ✓ |
| 完成设计 | `validate_design.py`（strict） | ✗ |
| 渲染 MD | `validate_design.py --render-md` | ✗ |

**设计前置（强制）**：
- 必须先读取 `sdaa-performance-best-practices` 路由入口
- 检索 `learned-patterns`，优先采用 `verified_by_stage`/`promoted` pattern
- 设计文档中的 `double_buffer_strategy`、`ldm_planning`、`pipeline_layout` 应体现适用 pattern
- 若不采用命中的 pattern，需在设计中写清不适用原因

**v3 strict 校验不只看「字段是否填写」，还检查基础物理一致性**：
- matmul 的 shape keys 是否为 `M/N/K`
- grid rows×cols 是否等于 `slave_core_num`
- LDM 总量是否超过 usable budget
- GEMM 的 `N2/K2` 是否满足 T1 粒度
- 双缓冲开启时是否真的定义了 overlap
- T1 硬件一致性检查：DMA stride、LDM bank、ACE/SIMD、RMA 路径和同步门禁

**关键约束**：
- `--auto-design` 已禁用；初始化后需人工补齐所有字段
- 设计通过 ≠ 实现完成；本 skill 的重点是把设计阶段做实

---

### 4.3 `sdaa-op-template` — 脚手架 + 精度验收 + 落地门禁

| 维度 | 内容 |
|------|------|
| **功能** | 单文件 `.swcu` 模式全链路：脚手架生成 → kernel 实现 → PyTorch golden L3 精度 → 落地汇总 |
| **触发关键词** | 「脚手架」「torch_verify」「精度验收」「算子落地」「禁止复用旧算子」 |
| **使用场景** | ① 设计通过后生成 kernel 骨架；② 实现 device kernel；③ 精度验收（L0/L3）；④ 最终交付检查 |

**任务完成定义（5 步全部通过才算完成）**：

| 阶段 | 工具 | 通过标志 |
|------|------|---------|
| 设计 | `validate_design.py` | `valid: true` |
| 脚手架 | `scaffold_op.py --from-design` | `src/<op>/<op>.swcu` 生成 |
| 实现 | 编辑 `.swcu` | 无 `TODO`，无 `<op_name>` 占位 |
| L3 精度 | `torch_verify.py` | `success_rate: 1.0` |
| 落地汇总 | `check_delivery.py` | `delivery_status: pass` |

**单文件 SWCU 结构**（由 `op_template.swcu` 定义）：

```
1. Device Kernel 全局常量
2. Device Kernel SIMD 函数（__device__）
3. Device Kernel global 函数（__global__，LDM/DMA/ACE 编排）
4. Host Test Driver（torch I/O）
```

**核心命令**：

```bash
# 脚手架生成
python3 ops/sdaa-op-template/scripts/scaffold_op.py \
  --op my_op --from-design --patch-runsh --force

# L3 精度验收（单命令完成编译+运行+校验）
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op my_op --demo-root ./swdnn_test_ops --build-dir build_my_op \
  --scope-cmake --restore-cmake --json

# 落地门禁
python3 ops/sdaa-op-template/scripts/check_delivery.py --op my_op --json
```

**分层验收**：

| 层 | 工具 | 说明 |
|----|------|------|
| L0 | `torch_verify.py --build-only` | 编译通过 |
| L1/L2 | `verify_sanity.h` | all-zero/finite 检查 |
| L3 | `torch_verify.py` | PyTorch golden 精度对比 |
| 门禁 | `check_delivery.py` | 全链路是否完成 |

**SIMD 双发射优化（强制规则）**：

| 规则 | 说明 |
|------|------|
| 展开 ≥8x | 每迭代处理 ≥8 个 `floatv16`（128 floats），覆盖流水线深度 |
| Load 交错 | `load(av_0)` → `load(pv_0)` → `load(av_1)` → … |
| 软件流水 | Prologue（填满运算流水线）→ Steady（`op[N]` ∥ `store[N-延迟]` 双发）→ Epilogue（排空） |
| 禁止同行 add+store | 同下标有 RAW 依赖，即使写同一行也不能双发 |

**关键禁止项**：
- 禁止只完成设计即结束任务
- 禁止用已有算子替代用户请求的 `<op>`
- 禁止复制旧算子目录冒充新算子
- 只允许只读参考 `op_template.swcu` 和已有 demo 的 API 模式

---

### 4.4 `kernel-bench` — Kernel 耗时测试

| 维度 | 内容 |
|------|------|
| **功能** | 通过 `rt_time_cycle()` 接口测量 kernel 在 device 端的执行周期，换算微秒和 TFLOPS |
| **触发关键词** | 「测耗时」「测性能」「benchmark」「kernel 执行时间」「cycle 数」 |
| **前置条件** | L3 精度验收已通过（`success_rate: 1.0`）；`.swcu` 文件存在且无编译错误 |
| **使用场景** | 精度通过后评估 kernel 性能，比较优化前后效果 |

**执行**：

```bash
python3 ops/kernel-bench/scripts/bench_kernel.py --op <op> --demo-root ./swdnn_test_ops
```

**工作原理**：
1. 备份原始 `.swcu` 文件
2. 在 `__global__` 函数中插入 `rt_time_cycle()` 计时点
3. 每个 SPE 记录自己的执行周期到 `cycle_buf[tid]`
4. Host 端取所有 SPE 的最大值（并行执行）
5. 按 SPE 主频换算为微秒
6. 恢复原始 `.swcu` 文件

**输出示例**：

```
[BENCH] op=gemmex
[BENCH] spe_clock=2360 MHz
[BENCH] max_cycles=12345678
[BENCH] time_us=5231.22
```

**范围边界**：
- **包含**：device 端 kernel 执行周期、等效 TFLOPS 计算
- **不含**：Host 端时间、DMA 分项耗时、ACE 分项耗时
- 细粒度分项统计见 `bandwidth-test` skill

---

## 5. 学习、优化与知识沉淀

### 5.1 `sdaa-performance-best-practices` — 性能优化总路由

| 维度 | 内容 |
|------|------|
| **功能** | 性能优化知识的**路由层**，不重复维护 API 手册或 pattern 正文，只负责把问题路由到正确的 skill 或经验 |
| **触发关键词** | 任何性能优化需求、实现阶段检索、设计阶段前置检索 |
| **使用场景** | ① `sdaa-op-design` 设计前必读；② `sdaa-op-template` 实现前必读；③ `sdaa-op-learning-validation` 学习前必读；④ 用户说「继续优化」时 |

**查询流程**：

```
1. 识别问题类型（机制优化/算子族优化/API 用法/架构建模/实现验证）
2. 检索长期经验库：
   rg -n "<op_family>|<mechanism>|<api>|<dtype>|<shape>" \
     ops/sdaa-op-learning-validation/references/learned-patterns
3. 优先采用 verified_by_stage 和 promoted，谨慎使用 draft_from_source
4. 长期库无命中 → 按路由表读对应 skill/reference
5. 实施优化 → 走 sdaa-op-learning-validation 的 attempt 流程
```

**机制层路由**：

| 问题类型 | 路由目标 |
|---------|---------|
| DMA/RMA/LDM/ACE/SIMD/batch/reduce API | `sdaa-docs-search` |
| T1 架构/带宽/ACE tile/LDM bank/双发射 | `sdaa-performance-best-practices` → `learned-patterns/` |
| 算子设计/分块/分核/双缓冲/流水 | `sdaa-op-design` |
| 代码优化验证/经验沉淀 | `sdaa-op-learning-validation` |

**领域层路由**：

| 算子族 | 典型关注点 |
|--------|-----------|
| GEMM/MatMul/GEMMEX | `learned-patterns/gemm/README.md` → ACE tile、A/B 搬运、C reduce、workspace、RMA ring、双缓冲 |
| Attention/MLA | `learned-patterns/attention/README.md` → QK/SV ACE、online softmax、updateO、有效行转置、流水 |
| Sparse Attention/Sparse MLA | `learned-patterns/sparse-attention/README.md`，继承 Attention → topk/indices gather、invalid、partial state merge |
| Softmax/Reduction/Norm | 状态常驻、分段 online softmax、规约树、SIMD 双发射 |
| Elementwise/Epilogue | 融合计算、减少 LDM 读写、tail、P0/P1 交错 |

**Preflight 算子族扩展**：

- UserPromptSubmit hook 读取 `learned-patterns/domain-routes.json`，不在 Python 中硬编码 GEMM、Attention 等领域名。
- 任意 route 与“优化、实现、开发、修改”等代码动作词同时命中时自动触发；纯概念查询和纯精度/性能测试不触发 kernel work preflight。
- “测试 matmul””benchmark gemm”应走 `kernel-bench`；只有同时明确要求优化或修改实现时才读取实现 pattern 和 code-style。
- 新增算子族采用人工登记、自动消费：创建 `<family>/README.md`，在 `domain-routes.json` 填写 triggers/index/patterns/inherits，并同步更新性能入口路由表。
- 领域与机制 pattern 的适用关系需要人工判断，不自动按目录或关键词批量生成，避免引入 shape、dtype、数据流不兼容的经验。

---

### 5.2 `sdaa-op-learning-validation` — 学习验证与经验沉淀

| 维度 | 内容 |
|------|------|
| **功能** | 支持 consume / optimize_existing / transfer_new_op 三种模式；按 isolated、enabler、combination、ablation attempt 验证假设，并用 portable evidence 沉淀长期经验 |
| **触发关键词** | 「学习已有算子」「人工给优化方向」「单点或组合优化验证」「pattern 抽取」「失败坑总结」「优化经验沉淀」「生成验证算子」 |
| **使用场景** | ① 从已有算子学习实现模式；② 用户给优化方向需要验证；③ 沉淀可复用经验到长期知识库 |

**必读顺序**：

0. 先读 `sdaa-performance-best-practices/SKILL.md` 做路由
1. `learning-workflow.md` — 理解整体学习流程
2. `human-guided-workflow.md` + `attempt-loop.md` — 人工引导的可归因 attempt
3. `pattern-extraction-checklist.md` — 抽取实现模式
4. `validation-tasks.md` — 选择验证任务
5. `knowledge-lifecycle.md` + `experience-template.md` + `learned-patterns/README.md` — evidence 与长期知识晋级
6. `backends/README.md` — 确认 backend（默认 `teco_ops`）

**强约束**：

- 学习任务必须先有 `learning_task.md`，用户给出的优化方向必须先归档再执行
- 每轮 attempt 只验证一个可归因假设；默认 isolated，强依赖组件可用 combination，但必须写 comparison matrix 和 ablation plan
- 每轮 attempt 必须记录：`attempt_type / hypothesis / goal / reference / allowed_changes / forbidden_changes / verification / result / failure_root_cause / learned_rules`
- 通过验证后先生成规范化 stage_result 和仓库内 evidence snapshot，再让长期 pattern 引用 evidence ID
- `transfer_new_op` 必须输出新 op 并走 requirement→design→scaffold→implement→verify→deliver；`optimize_existing` 从已通过 baseline 原地迭代

**任务初始化**：

```bash
python3 ops/sdaa-op-learning-validation/scripts/init_learning_task.py \
  --mode transfer_new_op \
  --topic gemm/pvc-smallk-fp16-fp32 \
  --sample /path/to/sample.hpp \
  --sample /path/to/sample.swcu \
  --op-kind gemmex \
  --focus "确认目标 shape 是否必须 splitK/workspace" \
  --dtype "A/B=fp16,C=fp32" \
  --target-shape 2048,2048,7680 \
  --target-op gemmex_nn_fp16_fp32_pvc \
  --backend teco_ops
```

**完成定义**：

- `transfer_new_op` 的 `learned_patterns.md` 说明 ≥2 个只读样本和可迁移模式；新 op 不与样本同名且不是复制旧实现
- `optimize_existing` 从已通过 baseline 开始，保留回退点，并按 backend 复测正确性、流水线和性能
- 规范化 stage_result 通过 `validate_stage_result.py`
- 长期 pattern 引用仓库内 evidence ID，并通过 `validate_learned_patterns.py`
- 若失败 → 回填失败原因/定位阶段/修复方式/新增坑
- 若通过 → 先用 `snapshot_pattern_evidence.py` 生成最小证据，再蒸馏规则到 `learned-patterns/` 或对应领域 skill

---

### 5.3 `record-repo-change` — 仓库问题与功能记录

用于记录 `teco-ops-agent` 自身的 hook、CLI、脚本、配置、安装和 skill 流程问题，以及新增的仓库级功能支持。修复或功能验证完成后生成一条 6–10 行的 Markdown，只保留类型、核心问题或需求、核心方案、验证和关键文件。

不记录算子 kernel、精度和性能问题，也不记录纯排版或无行为变化的重构。记录按月追加到 `docs/问题记录/YYYY-MM.md`；确需展开的核心方案放在 `docs/问题记录/核心方案/`，由月度记录引用。

```bash
python3 ops/record-repo-change/scripts/record_change.py \
  --type bugfix --title "问题标题" \
  --problem "核心问题" --solution "核心方案" \
  --verification "验证结果"
```

---

## 7. Skill 协作全景图

### 7.1 新算子开发主链路

```
用户提出新算子需求
        │
        ▼
┌──────────────────────┐
│ ① sdaa-env-check     │  环境门禁（最先执行，不可跳过）
│   check_env.sh       │
└──────┬───────────────┘
        │
        ▼
┌──────────────────────┐
│ ② sdaa-op-requirement│  强制需求采集（AskUserQuestion 逐轮）
│   → requirement.json │
└──────┬───────────────┘
        │
        ▼
┌──────────────────────────────┐
│ ③ sdaa-performance-          │  性能路由入口（设计前必读）
│    best-practices            │
│   + learned-patterns 检索    │
└──────┬───────────────────────┘
        │
        ▼
┌──────────────────────┐
│ ④ sdaa-op-design     │  算子设计 v3
│   init_design.py     │  ┌─────────────────────────┐
│   → validate_design   │  │ 检索/查阅：             │
│   → render-md        │  │ · sdaa-docs-search      │
└──────┬───────────────┘  │ · learned-patterns      │
        │                  └─────────────────────────┘
┌──────────────────────┐
│ ⑤ sdaa-op-template   │  脚手架 + 实现 + 精度验收
│   scaffold_op.py     │
│   → 实现 .swcu       │
│   → torch_verify.py  │  ← L3 精度（success_rate: 1.0）
│   → check_delivery   │  ← 落地门禁（delivery_status: pass）
└──────┬───────────────┘
        │
        ├── 通过 ──→ ⑥ kernel-bench（可选，测 device 端耗时）
        │
        └── 失败 ──→ ⑦ sdaa-op-learning-validation
                         │  单点排查 → 失败回填
                         │  通过 → 提升到 learned-patterns
                         └── 回到⑤ 重新实现/验证
```

### 7.2 设计阶段的 Skill 依赖链

```
sdaa-op-design（设计者）
    │
    ├── 前置必读 → sdaa-performance-best-practices（总路由）
    │
    ├── API 参考 → sdaa-docs-search（检索入口）
    │
    └── 经验知识 → learned-patterns/
          ├── gemm/（ACE tile、splitK、A reuse、B ring）
          ├── pipeline/（AB DMA 双缓冲、ACE writeback overlap）
          ├── simd/（C quarter reduce、online softmax）
          └── pitfalls/（双缓冲 K2 回退、ACE west mtile occupancy）
```

### 7.4 知识沉淀闭环

```
已有算子(只读) + 人给优化方向
        │
        ▼
sdaa-op-learning-validation
    ├── init_learning_task.py → learning_task.md
    ├── isolated / enabler / combination / ablation attempt
    ├── 验证（torch_verify / pipeline YAML）
    ├── 失败 → 回填到 learned_patterns.md / pitfalls/
    └── 通过 → stage_result → evidence snapshot → 长期知识库
                    │
                    ▼
            learned-patterns/
            （被 sdaa-performance-best-practices 检索）
            （被 sdaa-op-design 设计阶段消费）
            （被 sdaa-op-template 实现阶段消费）
```

---

## 8. 触发条件速查表

| 你说的话 | 触发哪个 Skill |
|---------|:-----------:|
| 「环境检查」「teco-smi」「检查设备」 | `sdaa-env-check` |
| 「rt_dma_get 怎么用」「文档检索」「查 API」 | `sdaa-docs-search` |
| 「需求采集」「算子需求」「新建算子」 | `sdaa-op-requirement` |
| 「设计这个算子」「分块怎么选」「throughput_model」 | `sdaa-op-design` |
| 「脚手架」「torch_verify」「精度验收」「check_delivery」 | `sdaa-op-template` |
| 「测耗时」「benchmark」「cycle 数」 | `kernel-bench` |
| 「性能优化」「继续优化」「有什么经验」 | `sdaa-performance-best-practices` |
| 「学习这个算子」「抽 pattern」「沉淀经验」 | `sdaa-op-learning-validation` |
| 「仓库功能问题」「hook/CLI/脚本修复」「新增功能支持」 | `record-repo-change` |

---

## 9. 关键禁令汇总

| 禁令 | 来源 |
|------|------|
| 禁止跳过环境检查直接声称可编译/可运行 | AGENTS.md |
| 禁止跳过需求采集直接进入设计 | `sdaa-op-requirement` |
| 禁止用 `sdaa-docs-search` 搜索已有算子作为交付物 | `sdaa-docs-search` |
| 禁止在设计阶段就汇报「已完成」 | AGENTS.md |
| 禁止只完成 `design.json`/`design.md` 即结束任务 | `sdaa-op-template` |
| 禁止未跑 `torch_verify.py` 即声称精度通过 | `sdaa-op-template` |
| 禁止用已有算子替代用户请求的新算子 | AGENTS.md、`sdaa-op-template` |
| 禁止实现 kernel 时搜索已有参考实现 | AGENTS.md |
| 禁止未经分析保留朴素 1x 热循环，也禁止把 8x 当固定规则 | `sdaa-op-template` / learned pattern |
| 禁止 RMA 用栈变量做回答字（必须 `__rt_remote_rply`） | `code-style.md` |
| 禁止 ACE writeback 使用 `ACE_PREC` 宏 | `code-style.md` |
| 禁止复制旧算子目录作为新算子交付物 | `sdaa-op-learning-validation` |
| 禁止在同一轮 attempt 中混入与主要假设无关的变化 | `sdaa-op-learning-validation` |
| 禁止批量填充需求采集（必须逐字段提问） | `sdaa-op-requirement` |

---

> 本文档基于 `ops/*/SKILL.md` 及项目级 `AGENTS.md` 整理，与代码实现同步维护。
