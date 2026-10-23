# Pattern: A/B DMA 双缓冲用于 ACE GEMM

## 状态

verified_by_stage

## 类型

optimization

## 问题

ACE GEMM 主循环如果在每个 K tile 上按 `DMA A/B -> wait -> ACE compute` 串行执行，会把 HBM/LDM staging 暴露在热路径上。只要 LDM 容量允许，A/B 输入应使用 ping-pong 双缓冲，让下一 K tile 的 DMA 与当前 K tile 的 ACE 计算重叠。

## 适用场景

- 算子是 ACE GEMM 或 Linear，形态类似 `C[M,N] = A[M,K] * B[K,N]`。
- A/B 输入来自 HBM，经 `rt_dma_iget` 或 `rt_dma_iget_stride` 进入 LDM 后被 ACE north/west 消费。
- K 方向有多个 tile，存在 current 与 next 的 steady-state 重叠机会。
- LDM 可容纳 `2 * A_tile + 2 * B_tile + C_tile`，并给栈、reply、运行时保留余量。
- next DMA 写入的 ping/pong buffer 不会被当前 ACE 读取。

## 不适用场景

- `2 * A_tile + 2 * B_tile + C_tile` 超过可用 LDM 预算。
- K 方向只有一个 tile，双缓冲只有 fill/drain 开销，没有 steady-state overlap。
- 当前实现已经需要 RMA、workspace、C reduce 或 C double buffering，但 buffer ownership 尚未定义清楚。
- DMA 与 ACE 争用同一 LDM bank 导致性能回退，且没有可行的 bank 重排。

## 核心思路

先预取 K tile 0；每轮 wait 当前 ping/pong buffer 可消费，马上发起下一 K tile DMA 到另一个 buffer，然后让 ACE 消费当前 buffer。

## 实现规则

- 为 A 和 B 分别分配两个 LDM buffer，例如 `a_tile_0/a_tile_1`、`b_tile_0/b_tile_1`。
- 为 A 和 B 分别维护两个 `volatile int` reply slot。
- 首轮循环前发起 K tile 0 的 A/B DMA。
- 每轮 K 循环：
  - `curr = k_block & 1`
  - `wait(a_reply[curr])`、`wait(b_reply[curr])`
  - 如果存在 next K tile，先将 `reply[next] = 0`，再发起 next DMA 到 `next = curr ^ 1`
  - ACE 只读取 `curr` buffer
- wait 点应卡消费者，而不是紧跟生产者。不要在发起 next DMA 后立刻 wait next。
- 复用 reply slot 前必须清零。
- 设计文档需要同步更新 `double_buffer_strategy`、`ldm_planning`、`pipeline_layout`，写清 producer/consumer、buffer ownership 和 wait points。

## 伪代码

```cpp
volatile int a_reply[2] = {0, 0};
volatile int b_reply[2] = {0, 0};

issue_dma_a(a_buf[0], k_tile_0, &a_reply[0]);
issue_dma_b(b_buf[0], k_tile_0, &b_reply[0]);

for (int kt = 0; kt < k_tiles; ++kt) {
    int curr = kt & 1;
    int next = curr ^ 1;

    rt_dma_wait_value((void *)&a_reply[curr], 1);
    rt_dma_wait_value((void *)&b_reply[curr], 1);

    if (kt + 1 < k_tiles) {
        a_reply[next] = 0;
        b_reply[next] = 0;
        issue_dma_a(a_buf[next], k_tile_next, &a_reply[next]);
        issue_dma_b(b_buf[next], k_tile_next, &b_reply[next]);
    }

    issue_ace_gemm_tile(a_buf[curr], b_buf[curr], kt == k_tiles - 1);
}
```

## 常见坑

- **Wait 太早**：发起 next DMA 后立刻 wait，会退化成串行 DMA/ACE。
- **Reply 未重置**：复用 reply slot 前不清零，`rt_dma_wait_value` 可能看到旧完成值。
- **Buffer 被覆盖**：next DMA 写入当前 ACE 仍在读取的 buffer，通常表现为 L3 精度失败。
- **只做 DMA ping-pong，不更新设计**：设计文档仍写 single buffer，后续 check 或维护者会误判 pipeline。
- **期待 A/B ping-pong 单独带来大收益**：如果更大瓶颈是跨 N tile 重复读取 A，A/B 双缓冲只能隐藏单 tile 内部分 DMA。

## 验证

- 验证 stage：`v6_ab_double_buffer`
- 目标 op：`gemmex`
- Shape：`M=2048,N=2048,K=8192`
- dtype/layout：`A/B=float16`，`C=float32`，NN row-major
- 正确性：L3 `success_rate=1.0`，`faults=0`
- 交付：`check_delivery.py --op gemmex --no-benchmark --json` 报告 `delivery_status=pass`
- 性能：`171934346 cycles -> 166463136 cycles`，约 `72.854 ms -> 70.535 ms`
- evidence: pipeline-v6-ab-dma-double-buffer

## 来源沿革

- swdnn_test_ops，`src/gemmex/gemmex.swcu`：验证目标实现。
- 原始 stage 已蒸馏到 evidence `pipeline-v6-ab-dma-double-buffer`。

## 相关模式

- `dma/stride-load-store`
- `ldm/ping-pong-buffer-ownership`
- `ace/fp16-fp32-mainloop`
- `gemm/a-reuse-across-n`
