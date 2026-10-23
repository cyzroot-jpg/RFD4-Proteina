# 人工引导优化工作流

用户通过会话给优化方向时，agent 不应直接改代码。先把会话输入整理成可追溯的 learning task / attempt，再执行。

## 输入来源

用户可能只说自然语言，例如：

```text
这轮只加 B row-ring，参考 gemm_xxx.hpp 的 rma_put_matB，不要动 C reduce 和 workspace。
```

agent 必须整理成结构化记录：

```yaml
stage: v3_b_row_ring
topic: rma/row-ring-b-panel
attempt_type: isolated
hypothesis: B row-ring 能减少重复 HBM B load
goal: 只验证 B row-ring 假设
reference:
  - path: /path/to/gemm_xxx.hpp
    symbol: rma_put_matB
target_op: gemmex
allowed_changes:
  - B DMA/RMA 数据流
  - ldm_matB ping/pong
  - ldm_matB_rma staging
forbidden_changes:
  - C reduce
  - workspace
  - pipeline
verify_shapes:
  - M,N,K
acceptance:
  - torch_verify 通过
  - 不破坏已有通过 shape
```

## 执行顺序

1. 确认或创建 `<demo_root>/op_learning/<topic>/learning_task.md`。
2. 在 `learned_patterns.md` 新增本轮 attempt 章节。
3. 只读参考代码，只抽取本轮 pattern。
4. 如果需要具体 op 方案，调用 `sdaa-op-design` 更新对应设计文档。
5. 修改目标 op；一轮只验证一个假设。默认 isolated，满足依赖条件时允许 combination。
6. 运行本轮指定验证。
7. 写 `stage_results/<stage>.json`。
8. 记录结果分类；成功则把规则标记为 `verified_by_stage`，enabler 则记录其组合前置条件。

## 组合假设

当单点没有收益但存在明确协同关系时，可以建立 combination attempt。必须补充：

- `components`：组合包含的机制。
- `dependencies`：为何不能简单视为无关改动。
- `baseline_stage`：组合从哪个已通过版本开始。
- `comparison_matrix`：baseline、可行单点、完整组合的对比。
- `ablation_plan`：成功后如何移除一个关键组件确认贡献。

不能因为“可能协同”就任意打包多个优化；必须先写出 producer/consumer、关键路径或资源依赖。

## 禁止事项

- 禁止因为读到样本里有完整 pipeline，就在 isolated B ring attempt 中顺手实现无关 pipeline。
- 禁止把样本大段函数复制到目标 op。
- 禁止把未验证的源码观察提升为长期经验。
- 禁止只在最终回复里总结经验而不写入过程报告。

## 会话信息不足时

优先做保守假设，但这些情况需要问用户或明确标注风险：

- 本轮允许改动范围不清。
- 用户给的参考代码和目标 op 数据流明显不一致。
- 验证 shape 无法覆盖本轮 pattern。
- 本轮改动依赖另一个尚未完成的 stage。
