---
id: local-learned-pattern-gemm-2d-splitk-c-rma-reduce
title: gemm/2D split-K + C RMA reduce
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/gemm/2d-splitk-c-rma-reduce.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/gemm/2d-splitk-c-rma-reduce.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- gemm
- gemmex
- matmul
- 2d
- splitk
- c
- rma
- reduce
- composite
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: composite
---

# Pattern: gemm/2D split-K + C RMA reduce

## 状态

verified_by_stage

## 类型

composite

## 问题

在 32 SPE 组上做 fp16/fp32 NN GEMM 时，如果只按 M 维分核，可能用不满核，或者 ACE west 的 M tile 太小。把一个 macro tile 同时拆到 M 和 K 两个维度，可以提升核占用和 ACE west 利用率；但 K 维被拆开后，每个 row 会产生 partial C，最终写回前必须先做 C reduce。

## 适用场景

- NN GEMM 或 GEMM-like kernel，语义是 `C[M,N] = A[M,K] * B[K,N]`。
- `A/B` 是 fp16 或 bf16，C 累加/输出是 fp32。
- 目标实现可以把 32 SPE 组映射成 `ROWS x COLS` 逻辑网格。
- `ROWS` 在 macro tile 内切 K，`COLS` 切 M。
- 同一 `cid` 列内，不同 `rid` row 的 C partial 可以互相交换。

## 不适用场景

- K 不够大，split-K 收益不足。
- 目标 shape 上 C partial 交换成本超过 ACE 计算收益。
- 实现里没有安全的跨 row C exchange RMA reply/wait 路径。
- 使用 workspace partial-C 或 fused epilogue 改变了 C reduce ownership；这类情况应使用 workspace 专用 pattern。

## 核心思路

把 32 SPE 映射成 `4 x 8`：4 个 row 切 K，8 个 col 切 M；ACE 写回后，在同一列内用 RMA gather 四份 partial C quarter，本地 reduce 后只写自己负责的 C quarter。

## 实现规则

- 计算 `rid = tid / COLS` 和 `cid = tid % COLS`。
- 每个 SPE 拥有本地 `A[M2,K2]`、`B[K2,N2]` 和 partial `C[M2,N2]`。
- `N2=32`，匹配 ACE north 宽度；`K2` 保持 32 的倍数。
- 本次验证目标使用 `ROWS=4`、`COLS=8`、`M2=96`、`N2=32`、`K2=512`。
- ACE writeback 后，把 `C[M2,N2]` 按 M 维切成 `ROWS` 个 quarter。
- 每个 row 负责一个 quarter，并接收同列其他三个 row 发来的 quarter。
- 本地 reduce 四份 quarter 后，只把自己负责的 quarter 写到最终 C 或下一轮累加位置。
- `.swcu` kernel 中异步 RMA reply 使用 `__rt_local_rply` 和 `__rt_remote_rply`。
- 如果跨 K1 macro tile 仍通过 HBM C 累加，必须保留 `k_macro_block > 0` 时读取 previous-C 再写回的语义。

## 组合依赖与归因

- Components：2D M/K 分核、partial C RMA exchange、本地 SIMD reduce-scatter。
- Dependency：只要 K 被跨 row 拆分，C reduce 就是数学正确性的必要组件；“split-K without reduce”不是可运行消融。
- Comparison matrix：baseline 为 M-only 分核；完整组合为 `4 x 8` 2D split-K + C RMA reduce。
- Ablation：C reduce 不可移除；后续应分别固定 2D grid，对 RMA exchange 和 SIMD reduce 实现做等价替换比较。

## 伪代码

```cpp
rid = tid / COLS;
cid = tid % COLS;

load_a_for_row_and_col(rid, cid);
load_b_for_row(rid);
ace_gemm(a_tile, b_tile, partial_c);

for (int peer = 0; peer < ROWS; ++peer) {
    if (peer != rid) {
        rma_send_c_quarter(peer, cid, partial_c_quarter_for(peer));
    }
}

wait_for_c_quarters();
reduce_four_row_partials(owned_c_quarter);
store_owned_c_quarter();
```

## 常见坑

- 认为 C RMA reduce 可有可无。只要 K 被按 row 拆分，每个 row 拿到的就只是 partial sum。
- 用普通局部 `volatile int` 当 remote RMA completion reply。交付检查要求使用 `__rt_local_rply` / `__rt_remote_rply`。
- 在 split-K attempt 里顺手引入 workspace 或完整 pipeline。这些是独立优化点。
- 增大 `M2` 前没有重新核算 C RMA receive buffer 和 accumulation buffer 的 LDM 容量。

## 验证

- 验证 op/stage：`gemmex`，`v8_2d_splitk_rma_reduce`。
- Shape：`M=2048,N=2048,K=8192`，`A/B=fp16`，`C=fp32`，NN。
- 正确性：`torch_verify.py` L3 通过，`success_rate=1.0`，`faults=0`，`max_abs_err=4.550814628601074e-05`。
- 交付：`check_delivery.py --op gemmex --no-benchmark --json` 通过，包含 RMA safety 检查。
- 性能：从 `166463136 cycles / 70.535 ms` 提升到 `128946366 cycles / 54.638 ms`，约 `1.258 TFLOPS`。
- evidence: gemm-v8-2d-splitk-c-rma-reduce

## 来源沿革

- 参考 GEMM 实现中的 fp16/fp32 和 bf16 2D split-K C RMA reduce 模式。
- 原始 stage 已蒸馏到 evidence `gemm-v8-2d-splitk-c-rma-reduce`。

## 相关模式

- `gemm/a-reuse-across-n`
- 后续候选：B row-ring / B panel sharing，前提是 `v11_b_row_ring` 已通过 L3、delivery 和 benchmark。
- 后续候选：workspace partial-C，需要单独 attempt 验证通过。
- 后续候选：完整 fill / steady / drain pipeline，前提是 B ring 和 workspace ownership 都已验证。
