---
id: source-teco-ops-agent-ops-sdaa-op-requirement-skill-8baa38c6
title: "teco-ops-agent ops: sdaa-op-requirement/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-requirement
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-requirement/SKILL.md
relative_source_path: sdaa-op-requirement/SKILL.md
captured_at: 2026-08-04
---

---
name: sdaa-op-requirement
description: 交互式算子需求采集技能（强制步骤）。通过 AskUserQuestion 一问一答收集算子名称、shape（用户自定义 key）、shape 含义、功能描述、输入/输出数据类型、计算公式，产出结构化 requirement.json。**任何新算子开发都必须先完成此步骤**，即使算子功能明确（如 gemm）。触发：需求采集、需求收集、算子需求、requirement、op requirement、新算子。
---

# SDAA 算子需求采集（强制步骤）

**这是算子开发流程的强制需求采集步骤，不可跳过。**

> 需求采集只负责把用户需求结构化为 `requirement.json`。
> 新算子开发开始时 hook 可能会提示 learned-patterns 候选经验，但本 skill 不要求在采集前消费这些经验；
> learned-patterns 的强消费发生在后续 `sdaa-op-design` 设计阶段。

## 流程

```
用户描述算子需求
    ↓
Agent 用 AskUserQuestion 逐轮采集需求（不可跳过、不可批量填充）
    ↓
Agent 将用户答案写入临时 JSON → collect_requirement.py --from-json 验证并写入
    ↓
requirement.json（默认 `<demo_root>/op_requirements/<op>/`，`<demo_root>` 为 `../../teco-ops`）
    ↓
init_design.py --from-requirement → design.json
    ↓
设计阶段消费 learned-patterns
    ↓
teco-ops interface + UAL 落地 → kernel → teco_ops_test 正确性和性能验收
```

## 执行方式

**不要直接运行 `collect_requirement.py --op <op>`（它的 stdin 交互在 agent 环境下不可用）。**

正确做法：

1. 使用 `AskUserQuestion` 逐字段采集用户需求
2. 将用户答案写入临时 JSON 文件（如 `/tmp/<op>_requirement.json`）
3. 运行验证：
   ```bash
   python3 ops/sdaa-op-requirement/scripts/collect_requirement.py \
     --from-json /tmp/<op>_requirement.json --json
   ```

## 规则

1. **每个字段都必须由用户确认**：Agent 可提供默认建议，但必须等用户确认
2. **即使算子功能明确也不能跳过**：如 gemm，shape/精度/公式仍需用户确认
3. **禁止批量填充**：不能用"全部默认"跳过采集，必须逐字段提问
4. **禁止跳过此步骤直接进入设计阶段**

## 采集内容

| 字段 | 说明 | 示例 |
|------|------|------|
| `op` | snake_case 算子名 | `gemm` |
| `computation_type` | elementwise/reduction/normalization/matmul/custom | `matmul` |
| `shape_keys` | 用户自定义维度名 | `["M", "N", "K"]` |
| `shape_meanings` | 每个维度的含义 | `{"M": "rows of A/C"}` |
| `shapes` | smoke/default 两组值 | `{"M":512,"N":256,"K":8192}` |
| `dtype_io` / `dtype_acc` | 输入/累加精度 | `float16` / `float32` |
| `description` | 功能描述 | `矩阵乘法 C = A × B` |
| `formula` | 数学公式 | `C[i][j] = sum_k(A[i][k] * B[k][j])` |
| `io_tensors` | 输入输出张量列表 | `[{name, dtype, shape, desc}]` |
| `golden` | 精度基准 | `{framework, atol, rtol}` |

## AskUserQuestion 采集顺序

按以下顺序逐轮提问（每轮最多 4 个问题）：

**第 1 轮 — 基础信息**：
- op 名（确认 snake_case）
- computation_type（elementwise / reduction / normalization / matmul / custom）
- 功能描述
- 数学公式

**第 2 轮 — Shape 定义**：
- shape_keys（逗号分隔，如 `M,N,K`）
- 每个 key 的含义

**第 3 轮 — Shape 数值**：
- smoke 测试 shape（小规模快速验证）
- 默认 shape（生产规模）

**第 4 轮 — 精度与容差**：
- dtype_io（输入/输出精度）
- dtype_acc（累加器精度）
- golden atol / rtol

**第 5 轮 — IO 张量**（如有多个张量）：
- 每个张量的 name、dtype、shape（用 shape_keys 表示）、描述

## 临时 JSON 格式

```json
{
  "schema_version": "1.0",
  "op": "gemm",
  "computation_type": "matmul",
  "description": "Matrix multiply C = A * B",
  "formula": "C[i][j] = sum_k(A[i][k] * B[k][j])",
  "shape_keys": ["M", "N", "K"],
  "shape_meanings": {"M": "rows of A/C", "N": "cols of B/C", "K": "inner dim"},
  "shapes": {
    "smoke": {"M": 64, "N": 32, "K": 128},
    "default": {"M": 512, "N": 256, "K": 8192}
  },
  "dtype_io": "float16",
  "dtype_acc": "float32",
  "io_tensors": [
    {"name": "A", "dtype": "float16", "shape": ["M", "K"], "desc": "Left input matrix"},
    {"name": "B", "dtype": "float16", "shape": ["K", "N"], "desc": "Right input matrix"},
    {"name": "C", "dtype": "float16", "shape": ["M", "N"], "desc": "Output matrix"}
  ],
  "golden": {"framework": "pytorch", "atol": 0.5, "rtol": 0.02}
}
```

## 存储

```
<demo_root>/op_requirements/<op>/    # 默认 ../../teco-ops/op_requirements/<op>/
  requirement.json    # 结构化需求文档
```

## 与其他 skill 的关系

| 下游 | 用法 |
|------|------|
| `sdaa-op-design` | `init_design.py --from-requirement` 读取 requirement.json |
| `sdaa-op-template` | 按 design.json 指导 teco-ops interface + UAL 落地 |
