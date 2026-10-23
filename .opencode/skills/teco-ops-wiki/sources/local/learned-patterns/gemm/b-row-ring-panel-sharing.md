---
id: local-learned-pattern-gemm-b-row-ring-panel-sharing
title: gemm/B row-ring panel sharing
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/gemm/b-row-ring-panel-sharing.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/gemm/b-row-ring-panel-sharing.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- gemm
- gemmex
- matmul
- b
- row
- ring
- panel
- sharing
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: gemm/B row-ring panel sharing

## 状态

verified_by_stage

## 类型

optimization

## 问题

A 复用后，每个 SPE 仍会为每个输出 `N2` tile 从 HBM 加载一份独立的 `B[K2,N2]` panel。在 `ROWS x COLS` GEMM 分核中，同一 row 内的 `COLS` 个 SPE 可以共享 B macro panel：每个 SPE 只从 HBM 加载一个初始 B panel，剩余 panel 通过 row-local RMA 传递获得。

## 适用场景

- NN GEMM 或 GEMM-like kernel，B 按 `(K,N)` 索引，ACE north 消费 `B[K2,N2]`。
- 32 SPE 组映射成 `ROWS x COLS`，`cid` 覆盖 M split，`rid` 覆盖 K split。
- 当前 N macro tile 恰好包含 `COLS` 个完整 `N2` panel。
- LDM 除了 A、C writeback、C reduce buffer 之外，还能容纳当前 B panel 和接收 B panel。
- row-local RMA 可用，并且能和 column-local C reduce 分开同步。

## 不适用场景

- N macro tail 少于 `COLS` 个完整 panel，除非单独实现并验证 tail-safe ring 协议。
- LDM 压力导致当前 B buffer 在 ACE 消费完成前就必须复用。
- B 已通过其他 workspace/pipeline stage packed 或 broadcast，ownership 已不同。
- 同一 attempt 还修改 workspace partial-C、C reduce ownership、A layout 或完整 fill/steady/drain pipeline；这些必须拆成独立 stage。

## 核心思路

对每个完整 `N1=COLS*N2` macro tile，每个 `cid` 先加载一个本地 B panel，计算后把它发给 `cid-1`，同时从 `cid+1` 接收下一份 panel，重复直到消费完所有 `COLS` 个 B panel。

## 实现规则

- 保持现有 `rid/cid` 网格。本次验证使用 `ROWS=4`、`COLS=8`、`M2=96`、`N2=32`、`K2=512`。
- 只有当 active N macro tile 满足 `active_cols == COLS` 时才进入 row-ring 路径。
- 初始加载 `B[k_start:k_start+K2, n_macro_start + cid*N2]` 到当前 B buffer。
- 在 ring step `rma_loop`，逻辑输出 panel 为 `n_col = (cid + rma_loop) % COLS`。
- ACE 使用当前 B buffer 计算该逻辑 `n_col`。
- 如果还有下一轮 ring step：row sync，重置 row RMA replies，`rt_rma_iput` 当前 B panel 到 `rid*COLS + prev_col(cid)`，等待 remote/local completion，再 row sync，最后交换 current/receive B buffer。
- C reduce 继续走原 column-local 路径。不要把 B row-ring 的 sync 或 reply ownership 与 C reduce 混用。
- 跨 K1 累加语义保持不变。如果前面的 K macro tile 已写过 C，reduce/store 新 partial 前必须读取 previous C。

## 伪代码

```cpp
for (int n1 = 0; n1 < n1_blocks; ++n1) {
    if (active_cols(n1) != COLS) {
        fallback_per_n2_b_dma();
        continue;
    }

    curr_b = b0;
    recv_b = b1;
    dma_get_b(curr_b, k_start, n1_start + cid * N2);
    wait_b();

    for (int step = 0; step < COLS; ++step) {
        int n_col = (cid + step) % COLS;
        ace_gemm(a_tile, curr_b, c_tile);
        reduce_and_store_c(c_tile, n1_start + n_col * N2);

        if (step + 1 < COLS) {
            row_sync();
            reset_row_rma_replies();
            rma_put(curr_b, rid * COLS + prev_col(cid), recv_b);
            wait_row_rma();
            row_sync();
            swap(curr_b, recv_b);
        }
    }
}
```

## 常见坑

- 把 `n_col` 写成 `cid - rma_loop`，或者使用 receiver id 作为逻辑输出 panel。已验证映射是 `(cid + rma_loop) % COLS`。
- 把 B 发到 ACE 仍在消费的同一个 buffer。必须区分 current 和 receive buffer，并且只在 row RMA 完成后交换。
- 重置 `__rt_local_rply` / `__rt_remote_rply` 前没有 row synchronization boundary，容易与 peer row-ring traffic 竞争。
- 在同一 attempt 混入 B row-ring、C reduce、workspace 或完整 pipeline 修改，导致正确性和性能归因不清。
- 把 full-COLS ring 用到 N tail。tail-safe 版本单独验证前，tail 应走非 ring fallback。

## 验证

- 验证 op/stage：`gemmex`，`v11_b_row_ring`。
- Shape：`M=2048,N=2048,K=8192`，`A/B=fp16`，`C=fp32`，NN。
- 正确性：`torch_verify.py` L3 通过，`success_rate=1.0`，`faults=0`，`max_abs_err=4.550814628601074e-05`。
- 交付：`check_delivery.py --op gemmex --no-benchmark --json` 通过，包含 RMA safety 检查。
- 性能：从 v10 A reuse 的 `66898770 cycles / 28.347 ms` 提升到 `47525809 cycles / 20.138 ms`，约 `3.412 TFLOPS`。
- evidence: gemm-v11-b-row-ring

## 来源沿革

- 参考 GEMM 实现中的 `dma_get_matB/rma_put_matB/rma_wait_matB/ace_cal` 模式。
- 原始 stage 已蒸馏到 evidence `gemm-v11-b-row-ring`。

## 相关模式

- `gemm/a-reuse-across-n`
- `gemm/2d-splitk-c-rma-reduce`
- 后续候选：workspace partial-C，需要单独 attempt 验证通过。
- 后续候选：完整 fill / steady / drain pipeline，需要 B ring 和 workspace ownership 都验证后再做。
