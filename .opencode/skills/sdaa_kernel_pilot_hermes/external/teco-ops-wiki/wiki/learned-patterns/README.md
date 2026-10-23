---
id: learned-patterns-index
title: Learned Patterns
type: learned-pattern-index
architectures:
- sdaa
tags:
- learned-pattern
- sdaa
- optimization
- validation
confidence: reference
source_repository: http://10.10.30.109/gongry/teco-ops-agent.git
source_ref: gupeng/test/skill-gen-stability
source_commit: 58949b8e2df40a24a693b0b3732582737bff8ab7
source_path: ops/sdaa-op-learning-validation/references/learned-patterns/README.md
captured_at: '2026-08-03'
---

# Learned Patterns

这里存放验证通过或人工审核过的算子实现经验。它不是 API 手册，也不是源码摘抄。

## 分类

```text
dma/          HBM-LDM 访存模式：packed load、stride load/store、C writeback、workspace read/write
rma/          核间通信模式：row/col ring、relay、reduce-scatter、reply/wait
ace/          ACE GEMM 主循环、north/west layout、writeback buffer
simd/         SIMD reduce、epilogue、cast/activation、P0/P1 交错
ldm/          LDM buffer 规划、ownership、bank pressure、ping/pong/triple buffer
workspace/   split-K partial C、packed workspace layout
pipeline/    fill/steady/drain、stage overlap、wait/sync placement
gemm/         GEMM 领域组合模式：M/N/K 分块分核、split-K、固定 A 扫 N、完整数据流
pitfalls/     跨 pattern 的常见坑和排查规则
```

`gemm/` 是领域组合层，不重复 `dma/rma/ace` 的接口细节；它引用机制层 pattern，说明这些机制如何组合成 GEMM 方案。

## 文件要求

每个 pattern 文件必须包含：

- Status
- Problem
- Applies When
- Do Not Use When
- Core Idea
- Implementation Rules
- Pseudocode
- Common Pitfalls
- Validation
- Source Evidence
- Related Patterns

模板见：

```text
ops/sdaa-op-learning-validation/references/experience-template.md
```

## 状态门禁

- 新总结默认 `draft_from_source`。
- 人工审核后可标 `human_reviewed`。
- 通过 stage 验证后可标 `verified_by_stage`。
- 多次复用稳定后可标 `promoted`。
- 被后续验证否定时标 `deprecated`。

禁止把 `draft_from_source` 经验当作默认实现规则。

## 长期库写入门禁

`learned-patterns/` 是长期可消费知识库，不存放未验证候选。候选、source notes 和人工假设只能写入：

```text
swdnn_test_ops/op_learning/<topic>/learned_patterns.md
```

成功 pattern 的硬条件：

- `Status` 只能是 `verified_by_stage` 或 `promoted`。
- 必须在 `Source Evidence` 或 `Validation` 中引用一个存在的
  `swdnn_test_ops/op_learning/**/stage_results/*.json`。
- 该 JSON 必须满足：
  - `status == "pass"`。
  - L3 `success_rate == 1.0`。
  - 有 `check_delivery.py` / `delivery_status: pass` 证据。
  - 有 benchmark / `perf_before` / `perf_after` 证据。
  - 性能必须提升：`perf_after.time_ms` / cycles 小于 `perf_before`，或 TFLOPS 大于 `perf_before`。

失败或回退经验只能放在 `pitfalls/`，状态使用 `verified_by_failed_stage` 或 `deprecated`，并引用失败/回退的
`stage_results/*.json`。正确但性能无提升的实现不能作为成功 pattern 进入长期库，只能沉淀为 pitfall 或留在过程记录。

提交或停止前运行：

```bash
python3 ops/sdaa-op-learning-validation/scripts/validate_learned_patterns.py
```
