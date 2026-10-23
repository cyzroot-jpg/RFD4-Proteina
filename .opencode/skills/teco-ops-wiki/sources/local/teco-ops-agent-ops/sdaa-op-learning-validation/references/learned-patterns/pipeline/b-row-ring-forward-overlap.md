---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-learned-patterns-pipeline-b-row-ring-forward-overlap-548f4178
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/learned-patterns/pipeline/b-row-ring-forward-overlap.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/learned-patterns/pipeline/b-row-ring-forward-overlap.md
relative_source_path: sdaa-op-learning-validation/references/learned-patterns/pipeline/b-row-ring-forward-overlap.md
captured_at: 2026-08-04
---

# Pattern: B Row-Ring 提前转发重叠

## 状态

verified_by_stage

## 类型

optimization

## 问题

在 GEMM row-ring B-panel 数据流中，如果等所有 C 后处理结束后才转发当前 B panel，下一轮 ACE tile 启动前会暴露 RMA latency。只要 ACE 已经消费完当前 B tile，就可以提前发起 B 转发，把 RMA 等待放到后续独立工作之后。

## 适用场景

- GEMM 使用 row-local B panel sharing，row 内有 `COLS` 个 SPE。
- ACE 已经消费了当前 `B[K2,N2]` tile，之后才发起该 B panel 的 forwarding RMA。
- 实现已经有两个 B tile buffer：`curr_b_tile` 和 `next_b_tile`。
- C 后处理使用独立数据 buffer，并且后续代码重置共享 RMA reply word 前，B RMA 已经完成。

## 不适用场景

- 下一份 B 目标 buffer 仍可能被 ACE 或另一个 RMA 消费。
- C reduce 或其他阶段会在 B RMA wait 前复用同一批 reply word。
- B RMA issue 和 B RMA wait 之间没有独立工作。
- N tail panel 无法完整参与 row-ring，除非单独实现 tail protocol。

## 核心思路

在 ACE 消费完当前 B tile 后立即 issue row-ring B forwarding RMA；ACE writeback 和部分 C 前置工作之后，再 wait B RMA，随后进入 C reduce。

## 实现规则

- 保持 B ownership 简单：`curr_b_tile` 是当前被 ACE 消费并转发到上一列的 tile；`next_b_tile` 是下一 ring step 的接收 buffer。
- 重置 row-ring RMA reply word 和 issue `rt_rma_iput` 前，需要 row synchronization boundary。
- B RMA wait 完成前，不要进入会重置同一批 RMA reply word 的代码。
- 只有观察到 local 和 remote B RMA 都完成后，才能交换 `curr_b_tile` 和 `next_b_tile`。
- 如果现有实现已经有两个 B buffer，这个 pattern 不需要额外 LDM。

## 伪代码

```cpp
issue_ace_gemm_tile(a_tile, curr_b_tile, m_size, k_size, true);

if (has_next_b_panel) {
    rt_synchronized_row();
    reset_row_rma_replies();
    rt_synchronized_row();
    rt_rma_iput(curr_b_tile, local_reply, bytes, prev_col_tid,
                next_b_tile, remote_reply);
}

rt_ace_writeback(c_tile, m_size, ace_reply, 1);
wait_ace_reply(ace_reply, 1);

if (has_next_b_panel) {
    wait_row_rma_replies();
    rt_synchronized_row();
    swap(curr_b_tile, next_b_tile);
}

reduce_and_store_c_tile();
```

## 常见坑

- B RMA 使用 `__rt_local_rply` / `__rt_remote_rply` 后，在 B RMA wait 前进入 C reduce。C reduce 可能重置这些 reply word，导致 hang 或同步错误。
- ACE 尚未消费 `curr_b_tile` 就发起 B RMA。source buffer 可能在当前计算 accept 前被覆盖或转发。
- 没证明现有两个 buffer 的 issue/wait 重排不足，就先加第三个 B buffer，增加 LDM 压力。

## 验证

- 验证 stage：`v15_b_double_buffer_pipeline`
- Op：`gemmex`
- Shape：`M=2048,N=2048,K=8192,A/B=fp16,C=fp32`
- L3：`success_rate=1.0`
- 交付：`check_delivery.py --no-benchmark` pass
- 性能：before `12641276 cycles / 5.356 ms`，after `12197423 cycles / 5.168 ms`，repeat `12253337 cycles / 5.192 ms`
- evidence: pipeline-v15-b-row-ring-forward-overlap

## 来源沿革

- 参考 GEMM 实现中的 `rma_put_matB/rma_wait_matB` 模式。
- swdnn_test_ops，`src/gemmex/gemmex.swcu`：v15 验证了最小重排。
- 原始 stage 已蒸馏到 evidence `pipeline-v15-b-row-ring-forward-overlap`。

## 相关模式

- `gemm/b-row-ring-panel-sharing`
- `rma/`
- `pipeline/`
