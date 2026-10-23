# Experience Pattern Template

长期经验文件必须使用下面结构。只记录写算子的方式和经验，不重复 API 手册全文。

章节标题和正文必须使用中文；技术标识、路径、函数名、命令、dtype、shape、status 值可以保留英文或代码原文。

```markdown
# Pattern: <name>

## 状态

verified_by_stage | promoted | needs_revalidation | superseded | deprecated | verified_by_failed_stage

## 类型

correctness_contract | optimization | composite | pitfall

## 问题

这个 pattern 解决什么实现或性能问题。

## 适用场景

- 适用条件。
- shape / dtype / layout / 分核条件。

## 不适用场景

- 不适用条件。
- 已知反例。

## 核心思路

一句话说明数据流或控制流。

## 实现规则

- 分核映射。
- HBM/LDM/workspace 地址公式。
- buffer ownership。
- reply/wait/sync 规则。
- 边界和 tail 处理。

## 关键参数与资源预算

- tile / block / chunk 参数。
- LDM / workspace / stack 占用。
- 对齐、bank、reply 数量、buffer 数量。
- 触发 fallback 或禁用该 pattern 的阈值。

## 架构与数据流

- GM/HBM、LDM、RMA、ACE、SIMD、writeback 的 producer/consumer。
- fill / steady / drain 阶段。
- 哪些阶段可以 overlap，哪些依赖必须串行。

## 从朴素实现到优化实现

- naive 数据流或 wait 点。
- optimized 数据流或 wait 点。
- 实际删除、融合、前移或后移的工作。

## 选型决策

- 优先使用该 pattern 的条件。
- 需要降级、fallback 或换 pattern 的条件。
- 与其他 pattern 的组合顺序。

## 组合依赖与归因

仅 `composite` 必填：

- components 与各自职责。
- dependencies 和不可独立运行的原因。
- baseline / 单点 / 完整组合 comparison matrix。
- 已完成或计划中的关键 ablation。

## 伪代码

```cpp
// 最小伪代码，不贴大段样本源码。
```

## 常见坑

- 失败现象。
- 根因。
- 修复方式。

## 自检清单

- 正确性路径是否覆盖 smoke / target / tail。
- buffer ownership 是否覆盖 producer / consumer / release。
- wait 是否放在第一消费点，而不是生产后立刻等待。
- LDM/workspace 是否重新核算。
- benchmark 是否覆盖目标 shape，且与正确 baseline 串行测量。

## 验证

- 验证 op / stage。
- shape。
- golden / check_delivery / benchmark 结果摘要。
- 仓库内 evidence ID，例如 `evidence: gemm-v10-a-reuse-across-n`。

## 来源沿革

- 可选。使用 `repo + commit + relative_path + symbol`；不要写作者机器绝对路径。
- pattern 必须能够脱离原始源码独立理解和实现。

## 相关模式

- dma/...
- rma/...
- gemm/...
```

## 提升规则

- `draft_from_source` / `human_reviewed`：只存在于 `<demo_root>/op_learning/`，不能进入长期库。
- `verified_by_stage`：可以作为高置信候选，但必须按验证范围判断并在目标算子复测。
- `promoted`：至少有两个独立实现上下文证据，可以作为默认候选被检索和引用。
- `needs_revalidation`：保留规则，但禁止作为默认候选。
- `superseded`：规则仍成立，但默认使用 `superseded_by` 指向的新模式。
- `deprecated`：保留失效原因，禁止继续使用。
- `verified_by_failed_stage`：仅用于 `pitfalls/`。
