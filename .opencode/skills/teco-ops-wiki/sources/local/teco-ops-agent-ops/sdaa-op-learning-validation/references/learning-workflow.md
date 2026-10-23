---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-learning-workflow-8b90867b
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/learning-workflow.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/learning-workflow.md
relative_source_path: sdaa-op-learning-validation/references/learning-workflow.md
captured_at: 2026-08-04
---

# 学习验证工作流

本 workflow 支持三种入口：

1. **消费已有知识（consume）**：检索 pattern，判断适用性并写入设计采用/拒绝理由，不进入 attempt。
2. **优化现有算子（optimize_existing）**：在已通过 baseline 上执行 isolated、enabler、combination 或 ablation attempt。
3. **迁移到新算子（transfer_new_op）**：从样本系统抽取 pattern，并生成新 op 验证迁移能力。

人工引导入口优先级更高。只要用户给出“这轮验证 X / 参考 Y / 不要改 Z”这类指令，就必须先按
`human-guided-workflow.md` 把会话内容落盘为 task/attempt，再执行。

## -1. 人工引导优化入口

用户在会话给出的信息可以不完整，但 agent 必须整理成结构化 attempt，写入：

```text
<demo_root>/op_learning/<topic>/learning_task.md
<demo_root>/op_learning/<topic>/stage_results/<stage>.json
```

如果还没有 `<topic>`，按本轮主题命名，例如：

```text
rma/row-ring-b-panel
rma/c-reduce-scatter
workspace/split-k-partial-c
ace/fp16-fp32-mainloop
pipeline/fill-steady-drain
gemm/fp16-fp32-32x-dataflow
```

每轮 attempt 必须写清：

- `attempt_type`：`isolated | enabler | combination | ablation`。
- `hypothesis`：本轮只验证一个可归因假设。
- `goal`：本轮完成什么验证。
- `reference`：用户指定或 agent 确认的只读代码位置。
- `target_op`：当前要修改或验证的算子。
- `allowed_changes`：本轮允许动哪些文件/逻辑。
- `forbidden_changes`：本轮禁止顺手改的内容。
- `verify_shapes`：本轮验收 shape。
- `acceptance`：正确性、交付、性能或回归要求。

执行规则：

- 默认用 isolated 控制变量。比如只验证 B row-ring，就不能顺手加入无关 C reduce、workspace 或完整 pipeline。
- 若多个组件存在明确依赖、单独实现无意义或已有单点证据，可以建立 combination；必须记录 components、dependencies、comparison matrix 和 ablation plan。
- 若只是多个独立想法，应拆成多个 attempt，不要扩大当前假设。
- 如果会话约束和本地设计文档冲突，先向用户说明冲突；不要静默覆盖人工约束。
- 失败后先归因和回填，再修复。不要只提交修复结果。
- 成功后只把本轮验证过的规则提升为 `verified_by_stage`，不要把未验证猜测提升为长期知识。

## 0. 初始化任务

优先用脚本生成任务输入，避免每次人工从零写关注点：

```bash
python3 ops/sdaa-op-learning-validation/scripts/init_learning_task.py \
  --mode transfer_new_op \
  --topic <family>/<pattern> \
  --sample <sample-a> \
  --sample <sample-b> \
  --op-kind <op-kind> \
  --profile auto \
  --focus "<本次额外关注点>" \
  --dtype "A/B=fp16,C=fp32" \
  --target-shape M,N,K \
  --target-op <new_validation_op>
```

输出：

```text
<demo_root>/op_learning/<family>/<pattern>/learning_task.md
```

`--profile auto` 会按 `op-kind`、topic 和样本路径生成不同关注点；当前内置
`gemm` 和 `generic`。

非 GEMM shape 使用任意 key-value，例如：

```bash
--target-shape q_seq=8192,q_head=16,kv_seq=8192,topk=512,head_dim=512
```

人先审核 `learning_task.md` 中的样本、target-first preflight、关注点分级和 coverage matrix。
smoke/mid shape 不能在 target 分支确认前定稿。
关注点先拆清，再按需要决定 demo shape 数量；同一阶段可以有多个 shape。

## 0. 初始化任务

阶段验证 OK 后，使用结构化结果自动提升设计事实。这个动作只更新当前 op 的设计，不等于把 pattern 提升到长期知识库：

```bash
python3 ops/sdaa-op-learning-validation/scripts/promote_design_facts.py \
  --op <op> \
  --topic <family>/<pattern> \
  --stage-result <demo_root>/op_learning/<family>/<pattern>/stage_results/<stage>.json
```

`stage_result.json` 最小格式：

```json
{
  "schema_version": 1,
  "backend": "swdnn_test_ops",
  "topic": "gemm/pvc-smallk-fp16-fp32",
  "stage": "target",
  "target_op": "gemmex",
  "attempt_type": "enabler",
  "hypothesis": "runtime probe can confirm the target tile and workspace path",
  "status": "pass",
  "allowed_changes": ["target-only runtime probe"],
  "forbidden_changes": ["tile selection", "kernel dataflow"],
  "verified_shapes": ["M=2048,N=2048,K=7680"],
  "correctness": {"success_rate": 1.0},
  "delivery": {"delivery_status": "pass"},
  "failures": [],
  "learned_rules": ["target tile and workspace path are runtime-confirmed"],
  "result_classification": "neutral_enabler",
  "summary": "target runtime probe confirmed tile and workspace path",
  "evidence": [
    {
      "kind": "runtime_probe",
      "path": "swdnn_test_ops/op_learning/gemm/pvc-smallk-fp16-fp32/logs/target_probe.log"
    }
  ],
  "verified_facts": [
    {
      "path": "tiling_strategy.actual_tile_for_target",
      "value": {"M1": 512, "N1": 128, "K1": 2560, "M2": 128, "N2": 32, "K2": 320},
      "evidence": "target_probe.log"
    }
  ]
}
```

提升门禁：

- `status` 必须是 `pass/ok/success` 之一。
- stage_result 必须先通过 `validate_stage_result.py`，且 `backend/topic/target_op` 与命令行一致。
- 每条 `verified_facts[]` 必须有 `path` 和 `evidence`。
- 每条 fact 只能包含 `value`、`append`、`extend`、`merge` 之一。
- 禁止通过 fact 修改 `schema_version`、`op`、`created_at`。
- 脚本会更新 `design.json`，并在 `design.md` 维护自动区块；不会覆盖手写设计正文。
- 脚本会向 `learned_patterns.md` 追加 promoted stage 摘要，便于追溯。

## 1. 选样本

`transfer_new_op` 至少选择两个只读样本；`optimize_existing` 可以只使用一个明确参考，也可以只依据已沉淀 pattern 和当前实现：

- 一个 ACE/GEMM/Linear 类样本：看 ACE north/west、writeback、LDM C 空间、K 循环。
- 一个 DMA/SIMD 或 DMA/RMA 类样本：看双缓冲、reply、wait、RMA 同步和 SIMD epilogue。

优先用 `rg` 定位 API 组合：

```bash
rg -n "rt_ace_load_west|rt_ace_writeback|rt_dma_iget|rt_rma_iput|simd_" swdnn_test_ops/src teco-ops-agent/swdnn_test_ops/src
```

只读参考即可；不要把样本作为交付物。

## 2. 产出过程报告

写到：

```text
<demo_root>/op_learning/<topic>/learned_patterns.md
```

这是一次验证的过程产物，用来记录样本、推理、失败和具体 op 验证结果；不要把它当作长期知识库。

建议结构：

```markdown
# <topic> Learned Patterns

## Samples
- sample A: path, purpose, key APIs
- sample B: path, purpose, key APIs

## Transferable Patterns
- DMA/RMA staging
- ACE main loop and writeback
- SIMD epilogue overlap
- LDM layout and bank pressure
- wait/sync rules

## Non-Transferable Details
- shape-specific constants
- sample-only workspace assumptions
- code that must not be copied

## Validation Plan
- new op name
- target shape/dtype
- expected APIs
- risk list

## Failures and Updates
- compile/runtime/accuracy failures
- rule to add or fix
```

人工引导 attempt 还必须追加：

```markdown
## Attempts

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

combination 还要记录 Components、Dependencies、Comparison matrix 和 Ablation plan。

## 3. 设计或更新目标 op

`transfer_new_op` 用 `sdaa-op-requirement` 采集需求，随后走 `sdaa-op-design`；验证 op 应尽量小，但要覆盖目标模式。
`optimize_existing` 不强制新建 op，但涉及 tile、分核、LDM 或 pipeline 变化时必须同步更新已有设计。

首个验证建议：

- `gemm_nn_fp16_fp32_smoke`
- fp16 输入，fp32 输出
- NN GEMM
- `N_TILE=32`
- `M_TILE<=128`
- K 为 32 的倍数

## 4. 实现与验证

`transfer_new_op` 必须走 `sdaa-op-template`；`optimize_existing` 使用 backend profile 定义的现有算子验证链：

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op <op> --demo-root ./swdnn_test_ops --build-dir build_<op> \
  --scope-cmake --restore-cmake --json

python3 ops/sdaa-op-template/scripts/check_delivery.py --op <op> --json
```

`torch_verify.py` 需要真实 SDAA 编译和运行环境；若沙箱导致设备不可见，按 `sdaa-env-check` 的 Codex 沙箱说明处理。

## 5. 回填

验证失败时不要只修代码。把失败归类：

- API 理解错：补到 learned-patterns 对应机制。
- 硬件/流水模型错：补到 `sdaa-op-design`。
- 生成流程缺门禁：补到 `sdaa-op-template/scripts/check_delivery.py`。
- 学习流程漏项：补到本 skill 的 checklist。
- Pattern 规则缺失：补到 `learned_patterns.md` 的 Common Pitfalls 或对应 draft pattern。
- 人工约束不完整：在下一轮 attempt 中显式补全 allowed/forbidden changes。

验证通过后，把稳定结论提升为 skill 知识：

```text
ops/sdaa-op-learning-validation/references/learned-patterns/<topic>.md
```

提升时只保留可复用规则、适用条件、反例和验证 op 链接；删除本次运行日志、临时路径和大段代码。若结论属于更基础的 API/硬件事实，应补到 learned-patterns 对应机制：

- 设计门禁：`sdaa-op-design`
- 交付检查：`sdaa-op-template`

## 6. 经验状态

长期经验必须标注状态：

- `draft_from_source`：只从源码读出，未验证。
- `human_reviewed`：用户或人工审核认可方向，但还未在本 op 验证。
- `verified_by_stage`：已通过一个明确 backend/op/shape 范围的验证；可以作为高置信候选，但目标算子仍需复测。
- `promoted`：至少经过两个独立算子、版本或实现上下文复用，可作为默认候选。
- `needs_revalidation`：SDK、硬件或接口契约变化，需要重新验证。
- `superseded`：规则仍成立，但已有更优 pattern 替代。
- `deprecated`：后续验证证明规则不成立或不再允许使用。

默认禁止把 `draft_from_source` 直接当作实现规则。实现时可以参考，但必须在 attempt 中声明风险并验证。
