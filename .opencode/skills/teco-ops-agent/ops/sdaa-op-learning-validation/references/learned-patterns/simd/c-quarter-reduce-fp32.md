# Pattern: simd/C quarter fp32 reduce

## 状态

verified_by_stage

## 类型

optimization

## 问题

split-K 的 C RMA exchange 之后，每个 SPE 需要把本地 C quarter 与收到的三个 peer quarter 做 reduce。如果用 fp32 标量循环处理这些 LDM 数据，会把天然可向量化的热路径串行化。

## 适用场景

- C partial 已经以 fp32 buffer 形式驻留在 LDM。
- 操作是 elementwise 加法：本地 C、收到的 C quarter，以及可选的 previous accumulated C。
- 热路径长度是 16 个 fp32 元素的倍数，或者保留 scalar tail fallback。
- 实现能证明或合理依赖热路径 LDM 分配是 aligned 的。

## 不适用场景

- 同一 attempt 里 reduce 路径还改变 ownership、layout、workspace accumulation 或 peer mapping。
- buffer 可能未对齐，并且没有 `simd_loadu` fallback 或 scalar path。
- 元素数太少，SIMD setup/unroll 成本无法摊薄。
- reduce 与复杂标量分支或不可向量化数学逻辑融合在一起。

## 核心思路

从本地 C 和 RMA C buffer 中用 `floatv16` 加载数据，在寄存器中做向量加法，再写回 accumulation/output LDM buffer。unroll 因子按实测选择，不按固定规则拍脑袋。

## 实现规则

- 使用 raw SIMD intrinsic 时包含 `<simd.h>`。
- `len` 使用元素数，不要使用字节数。
- aligned LDM 热路径使用 `simd_load` / `simd_store`。
- 除非所有支持 shape 都能证明 `len % 16 == 0`，否则保留 scalar tail fallback。
- 本次验证目标里 `chunk_elems=24*32=768`，热路径能被 16 整除。
- 在已验证目标上，4x `floatv16` unroll 比 8x 更快；如果寄存器压力或指令调度退化，不要盲目扩到 8x。
- 选择 loop 形态时参考 SIMD 手册的 P0/P1 模型。`simd_load` / `simd_store` 占 P1，fp32 vector add 占 P0；目标是在不耗尽 vector register 的前提下，用足够独立向量覆盖 load-use delay。
- 注意 vector register 压力。已验证 4x loop 大约有 8 个显式 live `floatv16`（`acc0..3` 和 `tmp0..3`），测试过的 8x loop 大约有 16 个；T1 有 32 个架构向量寄存器，编译器临时变量也需要余量。
- SIMD reduce 要和 C RMA ownership、B row-ring、workspace partial-C、A layout、完整 pipeline attempt 分开验证。

## 调度说明

- 相关手册事实：
  - P0 处理 vector compute，P1 处理 LDM load/store；只有交错独立 P0/P1 指令时，双发射才有效。
  - 本地 vector load 至少 5 cycles，vector store 至少 4 cycles，fp32 vector add 是 5 cycles。
  - 手册观察到的高效 `floatv16` 展开是 4x，不代表所有场景都应该 8x。
- 保留的 4x loop 中，每 64 个元素使用四个独立 accumulator。这能提供足够独立工作隔开 load/use，并给编译器空间把 P1 load/store 排到 P0 add 周围。
- 8x trial 增加了 load-use 距离，但显式 vector register 压力也接近翻倍。本目标上实测更慢，因此额外 unroll 不值得。

## 伪代码

```cpp
for (int i = 0; i <= len - 64; i += 64) {
    floatv16 acc0, acc1, acc2, acc3;
    simd_load(acc0, local_c + i);
    simd_load(acc1, local_c + i + 16);
    simd_load(acc2, local_c + i + 32);
    simd_load(acc3, local_c + i + 48);

    add_vector(acc0, rma0 + i, rma1 + i, rma2 + i, prev_c + i);
    add_vector(acc1, rma0 + i + 16, rma1 + i + 16, rma2 + i + 16, prev_c + i + 16);
    add_vector(acc2, rma0 + i + 32, rma1 + i + 32, rma2 + i + 32, prev_c + i + 32);
    add_vector(acc3, rma0 + i + 48, rma1 + i + 48, rma2 + i + 48, prev_c + i + 48);

    simd_store(acc0, out + i);
    simd_store(acc1, out + i + 16);
    simd_store(acc2, out + i + 32);
    simd_store(acc3, out + i + 48);
}
scalar_tail();
```

## 常见坑

- 把模板里关于 8x unroll 的提示当成硬性能规则。本次验证目标上 8x 正确但比 4x 慢。
- 忽略 vector register 压力。更大 unroll 可以隐藏 latency，直到引发 spill、调度变差或寄存器分配自由度下降。
- 在 alignment 无保证的 buffer 上使用 aligned `simd_load`。
- 向量化本地 reduce 时，顺手改变 C RMA exchange 或 workspace accumulation。
- 在所有支持 shape 都证明 16 元素整除前，删除 scalar tail fallback。

## 验证

- 验证 op/stage：`gemmex`，`v12_simd_c_quarter_reduce`。
- Shape：`M=2048,N=2048,K=8192`，`A/B=fp16`，`C=fp32`，NN。
- 正确性：`torch_verify.py` L3 通过，`success_rate=1.0`，`faults=0`。
- 交付：`check_delivery.py --op gemmex --no-benchmark --json` 通过；非强制 SIMD unroll warning 已记录并实测。
- 性能：从 v11 B row-ring 的 `47525809 cycles / 20.138 ms` 提升到 4x SIMD reduce 的 `28421791 cycles / 12.043 ms`，约 `5.704 TFLOPS`。
- 8x trial：`28979145 cycles / 12.279 ms`，慢于 4x，因此保留 4x 版本。
- evidence: simd-v12-c-quarter-reduce-fp32

## 来源沿革

- 参考 GEMM 实现中的 `simd_reduce_matC` 模式。
- 原始 stage 已蒸馏到 evidence `simd-v12-c-quarter-reduce-fp32`。
- SIMD 手册：`docs/共享知识库/SIMD使用手册-zh.md`。

## 相关模式

- `gemm/2d-splitk-c-rma-reduce`
- `gemm/b-row-ring-panel-sharing`
- `gemm/a-reuse-across-n`
