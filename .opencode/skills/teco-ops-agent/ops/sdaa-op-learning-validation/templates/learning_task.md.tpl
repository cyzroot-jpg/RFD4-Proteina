# SDAA 学习验证任务：{{ topic }}

## 1. 任务目标

学习主题：
- {{ topic }}

工作模式：`{{ workflow_mode }}`

目标：
- 支持用户会话给出的可验证优化假设：先落盘，再执行。
- 从只读样本中抽取本轮所需的可迁移实现模式。
- 用当前目标算子或新验证算子验证学习结果，禁止通过复制样本代码证明能力。
- 验证通过后，把稳定规则沉淀到 `ops/sdaa-op-learning-validation/references/learned-patterns/`。

## 1.1 会话输入归档

如果本任务来自用户会话中的人工建议，在这里记录原始约束和结构化解释：

```yaml
stage:
attempt_type: isolated | enabler | combination | ablation
hypothesis:
goal:
human_direction:
target_op:
reference:
allowed_changes:
forbidden_changes:
verify_shapes:
acceptance:
```

combination 还必须补充 `components / dependencies / baseline_stage / comparison_matrix / ablation_plan`。

执行前必须确认：本轮只验证一个主要假设，且没有混入无关变化。

## 2. 只读学习样本

{{ samples_section }}

约束：
- 禁止复制旧算子目录。
- 禁止把大段旧函数复制到验证算子。
- 只抽取 API 用法、shape 约束、buffer ownership、同步规则、LDM 布局和流水模式。

## 3. 分阶段关注点

生成 profile：`{{ focus_profile }}`

{{ focus_section }}

## 4. 参考实现分支预检与 shape 校准

{{ preflight_section }}

## 5. 后续 shape 设计

target 分支确认并完成只读分析后，再设计 smoke/mid shape。

原则：
- smoke 只验证最小正确性链路。
- mid 只验证至少一个 target 关注点。
- shape 数量不固定；可按关注点继续拆分多个 demo shape，但每个 shape 都要写清覆盖边界。
- 如果 smoke/mid 跑到完全不同分支，只能作为局部 demo，不能证明目标实现。

{{ followup_shape_section }}

## 6. 可选参考性能基线

{{ baseline_section }}

## 7. 学习过程报告

过程报告写到：

```text
{{ learning_report_path }}
```

必须包含：

{{ report_items }}

## 8. 分阶段验证计划

{{ validation_plan }}

## 9. Attempts

每轮 attempt 追加一节：

```markdown
### <stage>
- Attempt type:
- Hypothesis:
- Goal:
- Human direction:
- Reference:
- Allowed changes:
- Forbidden changes:
- Verification:
- Result:
- Failure root cause:
- Fix:
- Learned rules:
- Promotion status:
```

combination 追加：

```markdown
- Components:
- Dependencies:
- Baseline stage:
- Comparison matrix:
- Ablation plan:
```

对应结构化结果写入：

```text
<demo_root>/op_learning/{{ topic }}/stage_results/<stage>.json
```

> `<demo_root>` 由 `--backend` 决定：swdnn_test_ops 为 `swdnn_test_ops`。
> backend 文档位于
> `ops/sdaa-op-learning-validation/references/backends/README.md`。

## 10. 关注点覆盖矩阵

{{ coverage_matrix }}

## 11. 人工审核点

实现前必须确认：

- learned patterns 是抽象规则，不是复制代码。
- 会话里的人工建议已归档到本文件或 stage result。
- 本轮 attempt type、hypothesis、allowed/forbidden changes 明确，且只服务一个主要假设。
- combination 的依赖关系、对比矩阵和消融计划已写清；不存在把多个无关想法打包的情况。
- shape 约束和 layout contract 已明确。
- 若启用参考实现 preflight，已确认目标 shape 命中的真实 kernel/分支；没有命中时先修正样本或目标 shape。
- smoke/mid 只能在 target 实现分析完成后再设计，不能先于 target preflight 定稿。
- coverage matrix 中每个关注点都有对应验证阶段；若只有 smoke 覆盖，不得声明覆盖完整分块、分核或性能策略。
- 目标 shape 是否必须 SplitK / workspace。
- Stage 1 是否允许跳过 SplitK 和性能优化。
- Target 阶段优先正确性，还是要求性能接近参考 baseline。

## 12. 规则沉淀目标

验证通过后，把稳定规则沉淀到：

```text
{{ promotion_path }}
```

沉淀内容只保留：

- 可复用规则
- 适用条件
- 反例
- 验证 op 链接
- 禁止复制的实现细节
- 验证状态：`verified_by_stage` / `promoted` / `needs_revalidation` / `superseded` / `deprecated`

删除临时日志、本地路径和样本代码正文。
