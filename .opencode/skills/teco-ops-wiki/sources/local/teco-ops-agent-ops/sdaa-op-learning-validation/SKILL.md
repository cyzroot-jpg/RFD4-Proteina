---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-skill-8bd04545
title: "teco-ops-agent ops: sdaa-op-learning-validation/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/SKILL.md
relative_source_path: sdaa-op-learning-validation/SKILL.md
captured_at: 2026-08-04
---

---
name: sdaa-op-learning-validation
description: SDAA 算子实现模式学习、人工引导优化与阶段验证技能。用于把用户在会话中给出的优化假设、参考代码、允许/禁止改动和验证 shape 落盘为 learning_task/attempt；从已有算子只读抽取 DMA/RMA/SIMD/ACE、LDM、workspace、双缓冲、流水和 wait/sync pattern；按可归因假设执行单机制、前置能力、组合或消融验证，并把稳定经验沉淀到 learned-patterns。触发：学习已有算子、人工给优化方向、单点或组合优化验证、pattern 抽取、失败坑总结、优化经验沉淀、生成验证算子、不要复制旧算子。
---

# SDAA 算子学习与验证

第一阶段目标不是自动发现最优方案，而是：**人通过会话给出可验证假设，agent 把假设落盘、按参考代码抽取 pattern、控制变量验证正确性/性能、回填失败坑和可复用经验**。

不要把已有算子复制成交付物。源码样本只能作为只读证据和 pattern 来源。

## 必读顺序

0. 先读 `../sdaa-performance-best-practices/SKILL.md`，用它判断本次问题属于机制层、领域层、API 查询、设计建模还是实现验证。
   若 UserPromptSubmit Preflight 列出算子族路由 README，必须先按继承顺序读领域索引，再读取列出的机制 pattern。
1. 先读 `references/learning-workflow.md`。
2. 用户在会话里给优化方向时，必须读 `references/human-guided-workflow.md` 和 `references/attempt-loop.md`。
3. 抽取实现模式时读 `references/pattern-extraction-checklist.md`。
4. 选择验证任务时读 `references/validation-tasks.md`。
5. 写入长期经验前读 `references/knowledge-lifecycle.md`、`references/experience-template.md` 与 `references/learned-patterns/README.md`。
6. 若用户只给样本和目标 shape，先用 `scripts/init_learning_task.py` 生成
   `<demo_root>/op_learning/<topic>/learning_task.md`，给人审核后再执行。
7. 确认当前 backend（默认 `swdnn_test_ops`），详见 [backends/](references/backends/README.md)。
8. 需要查 API 或硬件事实时，通过 `sdaa-performance-best-practices` 检索 learned-patterns，或使用：
   - `sdaa-docs-search`
   - `sdaa-op-design`
   - `sdaa-op-template`

## 工作模式

进入任务后先选择一种模式，不要把三种流程混在一起：

- `consume`：查询长期 pattern，判断适用性并写入设计采用/拒绝理由；不要求创建 learning task。
- `optimize_existing`：在已有算子和已通过 baseline 上做 isolated、enabler、combination 或 ablation attempt；允许原地修改目标算子。
- `transfer_new_op`：从只读样本抽取迁移规则，并用新验证 op 证明迁移能力；必须走 `requirement -> design -> scaffold -> implement -> verify -> deliver`。

## 强约束

- 学习任务必须先有 `learning_task.md`；用户在会话中给出的优化方向、参考代码、允许/禁止改动、验证 shape 和验收标准必须先归档到任务或 attempt 记录，再执行。
- 每轮 attempt 只能验证一个主要假设，不等于只能修改一处代码。默认优先 isolated；只有组件存在明确依赖、单独实现无意义或已有单点证据时，才允许 combination。
- combination 必须记录 `components / dependencies / baseline_stage / comparison_matrix / ablation_plan`，禁止混入与该假设无关的 layout、tile、分核、数学公式或流水修改。
- 每轮 attempt 必须记录 `attempt_type / hypothesis / goal / reference / allowed_changes / forbidden_changes / verification / result / failure_root_cause / learned_rules`。
- 只读学习已有 `swdnn_test_ops/src/*` 或第三方 demo；禁止 copy 旧算子目录或大段函数作为新算子交付物。
- 学习过程报告先落到 `<demo_root>/op_learning/<topic>/learned_patterns.md`，用于绑定本次验证样本、失败日志和 op 产物。
- 通过验证后的稳定知识必须提升到本 skill：`ops/sdaa-op-learning-validation/references/learned-patterns/<topic>.md`。
- `transfer_new_op` 的验证输出必须是新 op；`optimize_existing` 不强制新建 op，但必须从已通过 baseline 开始并可回退。
- 双缓冲或组合流水的整体分析必须覆盖实际参与的 DMA、RMA、SIMD、ACE 资源；单机制 pattern 只需声明未覆盖部分和组合前置条件。
- Pipeline 必须写清 producer/consumer、buffer ownership、reply/wait 点、fill/steady/drain。
- 如果生成 ACE 代码，`rt_ace_writeback` 的 `Precisionflag` 直接传 `0/1`，禁止生成 `ACE_PREC`。
- 需要确认既有实现的适用 shape 或实际性能时，通过 learned-patterns 检索已有经验。

## 完成定义

一次学习验证完成必须满足当前模式的完成定义：

- `transfer_new_op` 的 `learned_patterns.md` 说明至少 2 个只读样本、抽取出的可迁移模式和不迁移的代码细节；`optimize_existing` 可只使用一个明确参考或不使用源码参考。
- 若学习结论依赖既有实现性能，报告必须记录 shape、kernel 名、耗时/TFLOPS。
- `transfer_new_op` 的新 op 不与学习样本同名，且不是复制旧实现。
- 正确性通过：按 backend profile 的验证标准（swdnn_test_ops: `torch_verify.py` L3 `success_rate == 1.0`）。详见 [backends/](references/backends/README.md)。
- 交付/流水线通过：按 backend profile 的交付检查（swdnn_test_ops: `check_delivery.py --json` `delivery_status == pass`）。
- 若失败，回填失败原因、定位阶段、修复方式和新增坑到过程报告；不要只修代码。
- 若通过，把可复用规则从过程报告蒸馏到 `ops/sdaa-op-learning-validation/references/learned-patterns/` 或对应领域 skill，并使用仓库内 evidence snapshot；禁止长期 pattern 依赖作者机器绝对路径。

## 任务初始化

```bash
python3 ops/sdaa-op-learning-validation/scripts/init_learning_task.py \
  --mode transfer_new_op \
  --topic gemm/pvc-smallk-fp16-fp32 \
  --sample /path/to/sample.hpp \
  --sample /path/to/sample.swcu \
  --op-kind gemmex \
  --profile auto \
  --focus "确认目标 shape 是否必须 splitK/workspace" \
  --dtype "A/B=fp16,C=fp32" \
  --target-shape 2048,2048,7680 \
  --target-op gemmex_nn_fp16_fp32_pvc \
  --backend swdnn_test_ops

# 优化已有算子可用：
#   --mode optimize_existing --sample <optional-reference> --target-op <existing-op>
```

生成器会按 `--op-kind`、`--topic` 和样本路径推断关注点 profile；GEMM/GEMMEX 会生成
GEMM/ACE 专用关注点，其他类型先走 generic。遇到特殊样本，用 `--profile` 固定 profile，
用多次 `--focus` 追加本次特有问题。

生成后先人工审核 `learning_task.md`，重点看：

- 若启用参考实现 preflight，是否确认 target shape 真实命中的 kernel/dispatch 分支。
- 是否遵守 target-first 顺序：先只跑 target，再读目标实现，最后反推 smoke/mid shape。
- smoke/mid shape 是否是在 target 实现关注点拆解后才设计出来。
- smoke 是否只被用于最小正确性链路，避免误判完整分块、分核或性能策略已覆盖。

审核通过后，再进入只读学习、可选参考 baseline、smoke/mid/target 验证。

## 会话驱动 attempt 输入模板

用户通过会话给优化方向时，先整理成下面结构并落盘：

```yaml
stage: v3_b_row_ring
attempt_type: isolated
hypothesis: B row-ring 能减少每个 N panel 的重复 HBM B load
goal: 只验证 B row-ring 假设
reference:
  - /path/to/sample.hpp::rma_put_matB
target_op: gemmex
allowed_changes:
  - B 的 DMA/RMA 数据流
  - ldm_matB ping/pong 和 ldm_matB_rma
forbidden_changes:
  - C reduce
  - workspace
  - pipeline
verify_shapes:
  - 1024,256,1536
acceptance:
  - torch_verify 通过
  - 不破坏已有通过 shape
  - 若 benchmark 可用，记录优化前后 cycles/TFLOPS
```

组合假设额外记录：

```yaml
attempt_type: combination
hypothesis: workspace C ping-pong 只有和 delayed wait 组合后才能覆盖 ACE writeback latency
components:
  - workspace partial-C
  - C ping-pong
  - delayed workspace wait
dependencies:
  - C ping-pong 提供独立 producer/consumer buffer
  - delayed wait 提供真实 overlap 窗口
baseline_stage: v15
comparison_matrix:
  - baseline
  - workspace_only
  - pingpong_only
  - workspace_pingpong_overlap
ablation_plan:
  - 从完整组合移除 delayed wait，确认 overlap 贡献
```

每轮结束写入：

```text
<demo_root>/op_learning/<topic>/stage_results/<stage>.json
```

并同步更新 `learned_patterns.md` 的 Failures / Learned Rules。
