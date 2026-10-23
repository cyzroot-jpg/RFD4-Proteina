---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-attempt-loop-d8f20757
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/attempt-loop.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/attempt-loop.md
relative_source_path: sdaa-op-learning-validation/references/attempt-loop.md
captured_at: 2026-08-04
---

# Attempt Loop

本文件定义单轮优化尝试的记录和闭环。目标是让失败可归因、经验可复用。

## 单轮原则

每个 attempt 只验证一个主要假设。一个假设可以是单机制，也可以是由强依赖组件组成的组合策略。

支持四种类型：

- `isolated`：单机制控制变量实验。
- `enabler`：验证正确性、资源或 ownership 前置能力；单独不要求性能提升。
- `combination`：验证多个强依赖组件的交互收益。
- `ablation`：从成功组合中移除一个组件，确认该组件的贡献。

默认先做 isolated：

```text
baseline -> +B row-ring
baseline -> +C reduce-scatter
baseline -> +split-K workspace
baseline -> +B double buffer
```

以下情况允许 combination：

- 组件之间存在 producer/consumer、buffer ownership、资源释放或 wait 窗口依赖。
- 单独实现没有完整语义，或只能作为 enabler。
- 已有 isolated 结果表明单点无收益，但瓶颈模型预测组合可以产生 overlap 或减少额外工作。

combination 仍禁止混入与假设无关的 tile、分核、layout、数学公式或 API 替换。组合成功后至少做一次关键 ablation；无法做时必须说明原因。

## stage_results 格式

保存到：

```text
<demo_root>/op_learning/<topic>/stage_results/<stage>.json
```

最小字段：

```json
{
  "schema_version": 1,
  "backend": "swdnn_test_ops",
  "topic": "rma/row-ring-b-panel",
  "stage": "v3_b_row_ring",
  "target_op": "gemmex",
  "attempt_type": "isolated",
  "hypothesis": "B row-ring reduces repeated HBM B loads",
  "goal": "validate B row-ring only",
  "status": "pass",
  "components": ["B row-ring"],
  "dependencies": [],
  "baseline_stage": "v2_baseline",
  "allowed_changes": ["B DMA/RMA", "ldm_matB ping/pong"],
  "forbidden_changes": ["C reduce", "workspace", "pipeline"],
  "verified_shapes": ["1024,256,1536"],
  "commands": [],
  "correctness": {"success_rate": 1.0},
  "delivery": {"delivery_status": "pass"},
  "perf_before": {"time_ms": 1.23},
  "perf_after": {"time_ms": 0.98},
  "failures": [],
  "failure_root_cause": "",
  "fix": "",
  "learned_rules": [
    "Wait the previous RMA buffer after toggling db_curr_rma_matB."
  ],
  "result_classification": "positive_alone",
  "promotion": {
    "status": "verified_by_stage",
    "target_pattern": "ops/sdaa-op-learning-validation/references/learned-patterns/rma/row-ring-b-panel.md"
  }
}
```

combination 还必须包含：

```json
{
  "attempt_type": "combination",
  "components": ["workspace partial-C", "C ping-pong", "delayed wait"],
  "dependencies": [
    "C ping-pong separates producer and consumer ownership",
    "delayed wait creates the overlap window"
  ],
  "baseline_stage": "v15",
  "comparison_matrix": [
    {"variant": "baseline", "stage": "v15"},
    {"variant": "workspace_only", "stage": "v16"},
    {"variant": "full_combination", "stage": "v17"}
  ],
  "ablation_plan": ["remove delayed wait from the full combination"]
}
```

写入后运行结构校验：

```bash
python3 ops/sdaa-op-learning-validation/scripts/validate_stage_result.py \
  <demo_root>/op_learning/<topic>/stage_results/<stage>.json --json
```

## 结果分类

不要把“单点没有收益”一律写成失败。使用下面的归类：

- `positive_alone`：单独有稳定收益。
- `neutral_enabler`：单独无收益，但提供组合所需前置能力。
- `negative_alone`：单独退化。
- `positive_in_bundle`：只在组合中有收益。
- `incompatible`：与当前数据流或资源约束不兼容。

`neutral_enabler` 不能作为独立 optimization pattern 提升，但可以成为 composite pattern 的必要组件。

## 失败分类

失败必须归到至少一类：

- `compile`：类型、头文件、宏、模板或链接问题。
- `api_contract`：rt_dma/rt_rma/rt_ace 参数、对齐、reply 使用错误。
- `layout`：HBM/LDM/workspace 地址或布局错误。
- `ownership`：ping/pong/triple buffer 所有权、覆盖、读写阶段错误。
- `sync_wait`：wait 对象、wait 时机、row/col sync 错误。
- `math`：归约、累加、alpha/beta、尾块处理错误。
- `performance`：正确但性能下降或 wait 暴露。
- `scope`：本轮误改了 forbidden changes。

## 成功门禁

attempt 成功至少满足：

- 本轮验证 shape 正确。
- 没有破坏已通过的 baseline shape。
- 如果涉及交付路径，`check_delivery` 通过。
- learned rule 已写入 `learned_patterns.md`。
- 若提升长期经验，pattern 文件包含验证证据。

组合 attempt 还必须满足：

- comparison matrix 的各 variant 使用同一 shape、dtype、频率和计时口径。
- 至少记录 baseline 与完整组合；有意义的单点或消融版本也应记录。
- 性能收益不能只归因于组合名称，必须写明 interaction、关键路径和资源变化。
