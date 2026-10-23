# Pattern: gemm/A tile 跨 N 复用

## 状态

verified_by_stage

## 类型

optimization

## 问题

在 NN GEMM 中，本地 `A[M2,K2]` tile 与输出的 `N2` tile 无关。如果每个 `N2` panel 都重新加载同一份 A，会产生重复 HBM 流量；在 B ring、workspace、完整 pipeline 尚未实现时，这个重复加载可能成为主要耗时。

## 适用场景

- NN GEMM 或 GEMM-like kernel，A 按 `(M,K)` 索引，B/C 沿 N 轴 sweep。
- 每个 SPE 在当前 `(M1,K1)` macro 位置拥有稳定的本地 `M2/K2` slice。
- LDM 可以在遍历多个 `N2` panel 时常驻 `A[M2,K2]`。
- A 常驻不与 C reduce buffer、ACE writeback buffer 或 B staging 冲突。

## 不适用场景

- 算法每个 N panel 都会改变 A，例如 fused op 会按 N tile mutate 或 repack A。
- LDM 压力要求在 N sweep 完成前驱逐 A。
- A 通过单独的 RMA/ring 协议在 SPE 间共享；那是另一个 pattern。
- 已证明目标瓶颈在别处，并且重排 loop 会破坏现有 pipeline overlap。

## 核心思路

使用 `M1 -> K1(load A once) -> N2(load B, ACE, reduce/write C)` 的 loop 顺序，替代 `M1 -> N2 -> K1(load A every N2)`。

## 实现规则

- 在当前 SPE 计算出 `m_start`、`m_size`、`k_start`、`k_size` 后，只加载一次 `A[M2,K2]`。
- `a_tile` ownership 保持在同一 SPE，本地复用 A 不需要 RMA ring。
- 每个 `N2` tile 只加载对应的 `B[K2,N2]`，然后用常驻的 `a_tile` 发 ACE。
- C 累加语义仍绑定 K macro index。如果前面的 K macro tile 已写过 C，reduce/store 新 partial 前必须读 previous C。
- A 复用和 A layout 分开看。row-major stride DMA 也可以复用；只有当 A load bandwidth 或 DMA efficiency 成为瓶颈时才需要 packed A layout。

## 伪代码

```cpp
for (int m1 = 0; m1 < m1_blocks; ++m1) {
    for (int k1 = 0; k1 < k1_blocks; ++k1) {
        dma_get_a_once(a_tile, m1, k1, rid, cid);
        wait_a();
        for (int n2 = 0; n2 < n2_blocks; ++n2) {
            dma_get_b(b_tile, k1, n2, rid);
            wait_b();
            ace_gemm(a_tile, b_tile, c_tile);
            reduce_and_store_c(c_tile, m1, n2, k1, rid, cid);
        }
    }
}
```

## 常见坑

- 混淆 A 复用和 A layout。复用改变 tile 生命周期和 loop 顺序；layout 改变 HBM/LDM 数据组织。
- 误以为必须做 RMA ring。每个 SPE 复用自己的本地 A tile 时不需要。
- 同一 attempt 里顺手修改 B ring、workspace、double buffering 或 C reduce，导致性能归因不清。
- 移动 K loop 后没有保留 `k_macro_block > 0` 的 previous-C read 条件。

## 验证

- 验证 op/stage：`gemmex`，`v10_a_reuse_across_n`。
- Shape：`M=2048,N=2048,K=8192`，`A/B=fp16`，`C=fp32`，NN。
- 正确性：`torch_verify.py` L3 通过，`success_rate=1.0`，`faults=0`。
- 交付：`check_delivery.py --op gemmex --no-benchmark --json` 通过。
- 性能：从 `128946366 cycles / 54.638 ms` 提升到 `66898770 cycles / 28.347 ms`，约 `2.424 TFLOPS`。
- evidence: gemm-v10-a-reuse-across-n

## 来源沿革

- 参考 GEMM 实现中的 `dma_get_matA` 模式。
- 原始 stage 已蒸馏到 evidence `gemm-v10-a-reuse-across-n`。

## 相关模式

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `rma/` B ring 和 C reduce patterns，待提升后引用。
