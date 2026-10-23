---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-learned-patterns-simd-xplutw-exp-8x-unroll-softmax-ea4728bd
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/learned-patterns/simd/xplutw-exp-8x-unroll-softmax.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/learned-patterns/simd/xplutw-exp-8x-unroll-softmax.md
relative_source_path: sdaa-op-learning-validation/references/learned-patterns/simd/xplutw-exp-8x-unroll-softmax.md
captured_at: 2026-08-04
---

# Pattern: xplutw 查表 exp + 8× SIMD unroll softmax

## 状态

verified_by_stage

## 类型

optimization

## 问题

fp32 softmax 在中等 row 长度（1024–16384）下，`simd_exp` 硬件 intrinsic 的吞吐不足以喂满 DMA 带宽。同时 Kahan 补偿累加引入依赖链，进一步限制 SIMD pipeline 利用率。需要一种更高吞吐的 exp 实现和更宽的 SIMD unroll 策略，使 compute 不再是 softmax 的瓶颈。

## 适用场景

- fp32 softmax，row 长度为 1024 的倍数（1024、2048、4096、8192、16384）。
- 每行数据可以完整驻留 LDM（row_len × 4B ≤ 64KB）。
- LDM 可腾出 ~10KB 给 exp 查表（9984B）。
- 32 SPE 并行处理多行，每 SPE 串行处理分配到的行。
- 精度要求：exp 输入经 `x - max` 归一化后落在 `[-row_len, 0]`，查表在此范围内误差 <1e-5。

## 不适用场景

- LDM 紧张（<15KB 余量），无法容纳 9984B exp table。
- row 长度极小（<128），SIMD setup 成本无法摊薄。
- exp 输入范围超出 table 覆盖（如未做 `x - max` 归一化，值域 >88）。
- 需要与 `simd_exp` 完全一致的精度（查表有 ~1e-5 近似误差）。

## 核心思路

用 `vexp_prec_table`（xplutw SIMD 查表指令）替代 `simd_exp` 硬件 intrinsic，配合 8×floatv16 独立累加器 unroll，将 exp 吞吐提升约 2 倍。整体采用 5-pass 结构（max → sub → exp → sum → normalize），每 pass 独立遍历 LDM buffer，利用 8 路独立向量寄存器解除依赖链。

## 关键参数与资源预算

| 参数 | 值 | 说明 |
|------|-----|------|
| exp table 大小 | 9984B | 2496 × uint32，从 `__device__` 常量 memcpy 到 LDM |
| LDM 占用 | row_bytes × 2 + 9984B | 双缓冲 DMA + exp table |
| SIMD unroll | 8×floatv16 | 每次迭代处理 128 个 float（512B） |
| CHUNK | 128 | VEC_ELEMS(16) × UNROLL(8) |
| SPE 数 | 32 | 每 SPE 分配 `ceil(total_rows/32)` 行 |

## 架构与数据流

```
HBM → [DMA iget] → LDM buf (row_bytes)
                        ↓
              Pass 1: simd_find_max_8x  → row_max (scalar)
                        ↓
              Pass 2: simd_sub_max_8x   → buf[i] -= row_max (in-place)
                        ↓
              Pass 3: simd_exp_table_8x → buf[i] = exp(buf[i]) (in-place, 查表)
                        ↓
              Pass 4: simd_sum_8x       → sum_val (scalar, tree reduce)
                        ↓
              Pass 5: simd_normalize_8x → buf[i] *= 1/sum (in-place)
                        ↓
LDM buf → [DMA iput] → HBM output
```

跨行双缓冲：当前行计算时，预取下一行 DMA iget；当前行 DMA iput 与下一行计算 overlap。

## 从朴素实现到优化实现

### 朴素实现（External v5 / cand-05）

- 3-pass in-place：max → exp+sum（合并）→ normalize
- `simd_exp` 硬件 intrinsic，1×floatv16 per iteration，`#pragma unroll 4`
- Kahan 补偿累加求 sum：`v_bias += v_tmp - v_sum - v`，引入跨迭代依赖
- 2-tile DMA（每行拆 2×32KB），tile 内无 DMA 重叠
- 16 SPE 活跃（1 SPE/行），16 SPE 空闲
- **实测 2,732,689 cycles @ (4096, 1024) fp32**

### 优化实现（Repo v5）

- 5-pass 分离：max → sub → exp → sum → normalize，每 pass 独立遍历
- `vexp_prec_table` xplutw 查表，8×floatv16 独立寄存器，无依赖链
- 8 路独立累加器 tree reduce 求 sum/max，无 Kahan 开销
- 32 SPE 全活跃，跨行双缓冲 DMA
- exp table 常驻 LDM（9984B），启动时 memcpy 一次
- **实测 1,356,327 cycles @ (4096, 1024) fp32**

### 关键差异

| 维度 | 朴素（External v5） | 优化（Repo v5） |
|------|---------------------|-----------------|
| exp 实现 | `simd_exp` intrinsic | `vexp_prec_table` xplutw 查表 |
| SIMD unroll | 4×（1×floatv16/iter） | 8×（8×floatv16/iter） |
| sum 累加 | Kahan 补偿（依赖链） | 8 路独立累加 + tree reduce |
| pass 结构 | 3-pass（exp+sum 合并） | 5-pass（完全分离） |
| SPE 利用率 | 16/32 | 32/32 |
| 性能 | 2,732,689 cycles | 1,356,327 cycles |
| **加速比** | — | **2.01×** |

## 实现规则

### exp 查表（`vexp_prec_table`）

```cpp
// exp table 定义（9984B = 2496 × uint32）
static const __device__ unsigned int global_exp_table[] = { /* 2496 entries */ };

// kernel 启动时拷贝到 LDM
float *exp_table = (float *)rt_ldm_malloc(9984);
memcpy(exp_table, global_exp_table, 9984);

// 8× SIMD unroll 调用
for (int i = 0; i < n; i += 128) {
    floatv16 v0..v7;
    simd_load(v0, data + i); ... simd_load(v7, data + i + 7*16);
    v0 = vexp_prec_table(v0, exp_table); ... v7 = vexp_prec_table(v7, exp_table);
    simd_store(v0, data + i); ... simd_store(v7, data + i + 7*16);
}
```

### 8× SIMD tree max

```cpp
static __device__ inline float simd_find_max_8x(const float *data, int n) {
    floatv16 v_max0..v_max7 = simd_stretch(-FLT_MAX);
    for (int i = 0; i < n; i += 128) {
        simd_load(v0..v7, data + i + k*16);
        v_max0 = simd_max(v_max0, v0); ... v_max7 = simd_max(v_max7, v7);
    }
    // tree reduce: 8→4→2→1
    v_max0 = simd_max(v_max0, v_max1); v_max2 = simd_max(v_max2, v_max3);
    v_max4 = simd_max(v_max4, v_max5); v_max6 = simd_max(v_max6, v_max7);
    v_max0 = simd_max(v_max0, v_max2); v_max4 = simd_max(v_max4, v_max6);
    v_max0 = simd_max(v_max0, v_max4);
    // horizontal max of 16 lanes
    float buf[16] __attribute__((aligned(64)));
    simd_store(v_max0, buf);
    float m = buf[0];
    for (int k = 1; k < 16; ++k) if (buf[k] > m) m = buf[k];
    return m;
}
```

### 8× SIMD tree sum

```cpp
static __device__ inline float simd_sum_8x(const float *data, int n) {
    floatv16 v_sum0..v_sum7 = {0};
    for (int i = 0; i < n; i += 128) {
        simd_load(v0..v7, data + i + k*16);
        v_sum0 += v0; ... v_sum7 += v7;
    }
    // tree reduce: 8→4→2→1
    v_sum0 += v_sum1; v_sum2 += v_sum3; v_sum4 += v_sum5; v_sum6 += v_sum7;
    v_sum0 += v_sum2; v_sum4 += v_sum6;
    v_sum0 += v_sum4;
    float buf[16] __attribute__((aligned(64)));
    simd_store(v_sum0, buf);
    float s = 0;
    for (int k = 0; k < 16; ++k) s += buf[k];
    return s;
}
```

### 跨行双缓冲 DMA

```cpp
float *bufs[2] = {buf_0, buf_1};
int db = 0;
rt_dma_iget(bufs[db], input + my_start * row_len, row_bytes, &get_reply);

for (int r = 0; r < my_rows; r++) {
    while (get_reply == 0) {}
    float *cur = bufs[db];
    int next_db = 1 - db;
    if (r + 1 < my_rows) {
        get_reply = 0;
        rt_dma_iget(bufs[next_db], input + (my_start + r + 1) * row_len,
                    row_bytes, &get_reply);
    }
    // 5-pass compute on cur
    put_reply = 0;
    rt_dma_iput(output + (my_start + r) * row_len, cur, row_bytes, &put_reply);
    if (r > 0) { while (put_reply == 0) {} }
    db = next_db;
}
while (put_reply == 0) {}
```

## 伪代码

见「实现规则」章节中的代码示例，包括 exp 查表、8× SIMD tree max、8× SIMD tree sum 和跨行双缓冲 DMA 的完整实现。

## 常见坑

- **exp table 未拷贝到 LDM**：`global_exp_table` 是 `__device__` 常量，不能直接在设备端寻址；必须 `memcpy` 到 `rt_ldm_malloc` 分配的 LDM buffer。
- **row_len 不是 CHUNK(128) 的倍数**：8×unroll 循环要求 `row_len % 128 == 0`；不满足时需加 tail 处理或回退到 4×/1× unroll。
- **Kahan 补偿 vs 独立累加器**：Kahan 补偿在 `simd_exp` 路径下有意义（减少浮点累积误差），但在查表路径下 exp 本身已有 ~1e-5 近似误差，Kahan 补偿的精度收益被 exp 误差淹没，反而增加依赖链。
- **5-pass vs 3-pass 的 LDM 流量**：5-pass 比 3-pass 多 2 次 LDM 遍历（sub 和 normalize 各多一次读写），但计算效率的提升远超 LDM 流量代价。在 row_len ≥ 1024 时，以计算为主。
- **exp table 精度范围**：table 覆盖 `[-90, 88]`；softmax 的 `x - max` 保证输入 ≤ 0，但下界取决于 row 内最大值与最小值之差。极端情况下（如一行全相同值），`x - max = 0`，exp(0) = 1，无问题。

## 自检清单

- `row_len % 128 == 0`？不满足则需 tail 处理。
- LDM 预算：`row_bytes × 2 + 9984 ≤ 256KB`？row_len=16384 时 `64KB × 2 + 10KB = 138KB`，满足。
- exp table 是否从 `__device__` 常量 memcpy 到 LDM？
- 5-pass 每 pass 的 `for` 循环步长是否为 `CHUNK(128)`？
- 跨行双缓冲的 `get_reply` / `put_reply` 是否正确使用 `volatile`？
- 最后一行的 `put_reply` wait 是否在循环外？

## 验证

- 验证 op：softmax（fp32, dim=1）
- shape：`(4096, 1024)` fp32，32 SPEs，T1 @ 2360 MHz
- 正确性：与 PyTorch `torch.softmax(x, dim=1)` 对比，精度通过（查表 exp 误差 <1e-5）
- 性能（4 次运行均值）：

| 实现 | max_cycles | 耗时 (μs) | 有效带宽 (GB/s) |
|------|-----------|-----------|-----------------|
| External v5（simd_exp + 4×unroll + Kahan） | 2,732,689 | 1158 | 27.6 |
| Repo v5（xplutw 查表 + 8×unroll + tree reduce） | 1,356,327 | 575 | 55.6 |
| **加速比** | — | — | **2.01×** |

- evidence: simd-xplutw-exp-8x-unroll-softmax

## 来源沿革

- swdnn_test_ops，`src/softmax/softmax.swcu`，`teco_slave_softmax` kernel。
- exp table 和 `vexp_prec_table` 函数参考 xplutw 查表实现。
- 8x SIMD unroll 策略参考 softmax 算子的高吞吐向量化模式。
- 性能对比 benchmark 在 `softmax_bench.swcu` 中统一实现，同一 shape、同一输入数据、同一 SPE 配置。

## 相关模式

- `simd/vector-exp-table-lookup`：查表法向量 exp 的基础 pattern（`vexp_prec_table_2_fast` 变体）。
- `simd/online-softmax-tile-microkernel`：online softmax 的 SIMD tree reduce 微内核，本 pattern 的 tree max/sum 与其同源。
- `simd/c-quarter-reduce-fp32`：SIMD 向量归约的 unroll 选型方法论。
- `pipeline/ab-dma-double-buffer-ace-gemm`：跨行双缓冲 DMA 模式。
