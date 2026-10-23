---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-learned-patterns-pitfalls-ab-double-buffer-k2-regression-4ad1f698
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/learned-patterns/pitfalls/ab-double-buffer-k2-regression.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/learned-patterns/pitfalls/ab-double-buffer-k2-regression.md
relative_source_path: sdaa-op-learning-validation/references/learned-patterns/pitfalls/ab-double-buffer-k2-regression.md
captured_at: 2026-08-04
---

# Pattern: pitfalls/A-B 双缓冲导致 K2 变小而退化

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

A/B DMA 双缓冲即使正确，也可能因为 LDM 压力增大而被迫减小 `K2`，最终变慢。对 split-K GEMM 来说，较小的 `K2` 会增加 K macro iteration 次数，从而放大 C RMA reduce 和 HBM C read/modify/write 流量。

## 适用场景

- GEMM 使用 ACE，A/B tile 驻留 LDM。
- 当前数据流已经需要 C tile storage、C RMA receive buffer 和 C accumulation buffer。
- 加完整 A/B ping-pong 会迫使 `K2` 降低。
- 跨 K 累加仍通过最终 HBM C，而不是 workspace 或更深 pipeline。

## 不适用场景

- LDM 可以在加入 A/B ping-pong 后保持相同 `K2`。
- 实现已经把 split-K partial C 移到 workspace，C 侧 loop count 不再是瓶颈。
- 目标 shape 有足够多 K tile 可形成 steady overlap，且不会增加 C 侧工作。
- benchmark 已证明 double-buffered 版本在具体 shape 上更快。

## 核心思路

如果 A/B 双缓冲会迫使 `K2` 下降并增加 C reduce/accumulation 频率，不要把它当成默认 GEMM 优化。

## 实现规则

- 实现 A/B ping-pong 前，先计算 LDM 预算：
  - `2 * A[M2,K2]`
  - `2 * B[K2,N2]`
  - ACE writeback C
  - C RMA receive buffers
  - local C accumulation buffer
  - runtime stack 和 reply words
- 如果预算迫使 `K2 < current_best_K2`，保留前先 benchmark 小 K2 版本。
- 正确性只是必要条件，不是保留条件；最终实现应保留实测最快 stage。
- 如果 benchmark 退化，回退 kernel，并把 attempt 作为 pitfall 记录。
- 只有在通过 B sharing、workspace partial-C 或完整 pipeline 降低 C 侧压力后，才重新评估 A/B double buffering。

## 伪代码

```cpp
candidate_k2 = largest_k2_that_fits_with_ab_pingpong();
if (candidate_k2 < current_best_k2) {
    run_l3(candidate_k2);
    run_benchmark(candidate_k2);
    if (candidate_time >= current_best_time) {
        revert_to_current_best();
        record_regression(candidate_k2);
    }
}
```

## 常见坑

- 因为 L3 pass 就保留正确但更慢的 kernel。
- 只比较 DMA latency，忽略较小 `K2` 带来的额外 C RMA/reduce loops。
- 把 A/B ping-pong 与 B ring、workspace 或 C reduce redesign 放在同一 attempt，掩盖真实原因。
- 实现已回退，却在设计文档里仍声明 double buffering 是 active strategy。

## 验证

- 失败 stage：`gemmex`，`v9_ab_double_buffer_k2_search`。
- Shape：`M=2048,N=2048,K=8192`，`A/B=fp16`，`C=fp32`，NN。
- Baseline：`K2=512`，single-buffer，`128946366 cycles / 54.638 ms`。
- Attempt 1：`K2=256`，A/B double-buffered，L3 pass，`144760038 cycles / 61.339 ms`。
- Attempt 2：`K2=416`，A/B double-buffered，L3 pass，`132078772 cycles / 55.966 ms`。
- 结果：两个版本均退化；实现回退到已验证最优的 `K2=512` single-buffer stage。
- evidence: pitfall-v9-ab-double-buffer-k2-regression

## 来源沿革

- 原始失败 stage 已蒸馏到 evidence `pitfall-v9-ab-double-buffer-k2-regression`。
- 对照正向 evidence：`pipeline-v6-ab-dma-double-buffer`。

## 相关模式

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `gemm/2d-splitk-c-rma-reduce`
- 后续候选：workspace partial-C，需要单独 attempt 验证通过。
- 后续候选：完整 fill / steady / drain pipeline，需要 B ring 和 workspace ownership 都验证后再做。
