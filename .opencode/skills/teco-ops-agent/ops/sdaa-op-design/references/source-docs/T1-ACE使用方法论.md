# T1-ACE使用方法论

本文基于 [teco-T1.md](teco-T1.md) 的 ACE 硬件描述、架构图 [drawing-26](images/teco-T1/drawing-26.png)、[drawing-27](images/teco-T1/drawing-27.png)、[drawing-28](images/teco-T1/drawing-28.png)，以及 [ACE.xlsx](ACE.xlsx) 中的 microbenchmark 数据整理。

目标是回答三个问题：

1. 什么情况下应该用 ACE，而不是只用 EBOX/SIMD。
2. ACE 的 tile、数据布局、LDM/DMA 配合应如何选择。
3. 如何根据实测数据判断性能瓶颈，并做可靠调参。

## 1. ACE 硬件模型

ACE 是 T1 上面向矩阵乘法/脉动阵列计算的专用矩阵计算单元。文档和图示中出现的核心部件包括：

| 部件 | 含义 | 优化关注点 |
| --- | --- | --- |
| SAC | 加速控制器 | 控制北向/西向加载、累加、卸载和 IO 访问 |
| MXMU | 矩阵乘法单元 | ACE 的主计算阵列 |
| ACMB | 累加器缓冲 | 有两个缓冲区，可做计算/写回双缓冲 |
| SAA_IO | 结果写回路径 | C 写回和 LDM 访问会形成瓶颈 |
| 北向数据加载 | 通常可理解为 B/权重方向输入 | 需要复用，降低等效带宽需求 |
| 西向数据加载 | 通常可理解为 A/激活方向输入 | `rt_ace_load_west` 会同步触发乘加 |

关键硬件事实：

- 调用 `rt_ace_load_west` 时会同步进行乘加计算，不需要额外发计算指令。
- ACE 频率为 1.25GHz。
- 西向每 cycle 可获取 64B，理论西向输入带宽约 `1.25GHz * 64B = 80GB/s`。
- 北向理论需求也可到 80GB/s，但由于北向数据可复用，实际等效需求会随 m 变化。
- ACMB 有两个 `128 * 32 * 2B = 8KB` 缓冲区，可一个参与计算、另一个写回 LDM。
- `rt_ace_writeback` 可把空闲 ACMB 的结果写回 LDM，用于隐藏写回延迟。
- 图示中提示 ACE 内部精度为 fp32，但写回 fp16 时会截断，非规格化 fp16 场景可能有明显精度损失。

工程抽象：

```text
LDM north buffer + LDM west buffer
        -> ACE north/west load
        -> MXMU multiply-add
        -> ACMB0/ACMB1 ping-pong accumulation
        -> SAA_IO writeback to LDM
        -> DMA put / SIMD postprocess
```

## 2. ACE 适用场景

ACE 适合下列计算：

- GEMM、BMM、卷积 lowering 后的矩阵乘。
- Attention 中大块 QK、PV 或其它 `M x K` 乘 `K x 32` 类 tile。
- reduction 维度 K 足够大、输出列宽贴近 ACE 结果 tile 的场景。
- 能把输入搬入 LDM 并在 ACE 内复用的场景。

ACE 不适合或要谨慎使用的场景：

- m 很小且无法 batch/fuse，多数计算阵列空闲。
- k 很小，提交/加载/写回开销无法摊薄。
- 输出 C 写回占主导的小 K tile。
- 数据布局极不规则，需要大量 gather/scatter 或 RMA 才能喂给 ACE。
- 精度要求不能接受 fp16 写回截断，且没有额外补偿方案。

## 3. 实测数据口径

`ACE.xlsx` 包含 6 个 sheet：

| Sheet | 含义 |
| --- | --- |
| `TFLOPS` | 基准 ACE TFLOPS 结果 |
| `Cycle` | 对应 cycle |
| `IO_AB` | A/B 输入相关 IO 指标 |
| `IO_C` | C 输出/写回相关 IO 指标 |
| `write half` | half 写回路径下的 TFLOPS 结果 |
| `下发_delay` | 指令/任务下发相关 delay |

表格覆盖：

- `m = 1..128`
- `k = 32..1024`，步长 32

注意：xlsx 没有额外元数据解释每个 IO 指标的单位。本文只把 `IO_AB`、`IO_C` 用作趋势诊断信号，不把它们当成绝对硬件带宽上限。

## 4. 实测性能规律

### 4.0 数据一致性与性能模型

对 `TFLOPS` 和 `Cycle` 两个 sheet 做交叉校验，可以得到：

```text
TFLOPS * Cycle / (m * k) ~= 4.83328
```

该值在抽样点 `m=1,k=32`、`m=64,k=512`、`m=128,k=1024` 上基本恒定，说明 `TFLOPS` 与 `Cycle` 使用了同一套 operation count 口径，数据内部一致。

工程上可把 ACE 单 tile 时间拆成：

```text
T_tile = max(
    T_mxmu_compute,
    T_west_load,
    T_north_load_reuse_adjusted,
    T_acmb_writeback_exposed,
    T_dma_stage_exposed,
    T_issue_delay_exposed
)
```

如果没有正确双缓冲，时间会退化为更接近串行相加：

```text
T_tile ~= T_dma_stage + T_issue_delay + T_compute + T_writeback
```

因此 ACE 优化不是单纯追求 MXMU 峰值，而是要让：

- north/west 输入能持续供应。
- ACMB 写回被下一轮计算隐藏。
- DMA staging 被当前计算隐藏。
- 下发 delay 被足够大的 m/k 摊薄。
- LDM Bank 不让 ACE、SIMD、DMA/RMA 在同一热点上互相阻塞。

### 4.1 峰值区间

`TFLOPS` sheet 中的峰值约为：

```text
max TFLOPS = 77.31
位置：m = 127, k = 1024
```

但从调参角度看，`m=128, k=512` 已经达到约 77.30 TFLOPS，继续把 k 增大到 768/1024 只有极小收益。

关键点：

| m/k | 32 | 64 | 128 | 256 | 512 | 768 | 1024 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0.74 | 0.80 | 0.79 | 0.80 | 0.80 | 0.80 | 0.80 |
| 2 | 1.42 | 1.58 | 1.59 | 1.59 | 1.59 | 1.59 | 1.59 |
| 4 | 2.56 | 3.19 | 3.18 | 3.19 | 3.19 | 3.19 | 3.19 |
| 8 | 4.38 | 5.97 | 6.35 | 6.37 | 6.37 | 6.37 | 6.37 |
| 16 | 6.70 | 10.01 | 12.59 | 12.69 | 12.72 | 12.73 | 12.74 |
| 32 | 9.19 | 14.77 | 21.14 | 25.02 | 25.28 | 25.36 | 25.39 |
| 64 | 11.23 | 19.52 | 31.11 | 44.22 | 50.20 | 50.47 | 50.61 |
| 96 | 12.19 | 21.99 | 36.74 | 55.69 | 73.25 | 75.22 | 75.54 |
| 128 | 12.67 | 23.37 | 40.55 | 64.35 | 77.30 | 77.31 | 77.31 |

结论：

- m 小时，性能几乎按 m 线性增长，说明 ACE 阵列行方向利用率不足。
- m 到 96 以后，k 足够大时已经接近满载。
- m=128 是最稳妥的满载 tile。
- k=512 是普通写回路径下接近峰值的甜点；k>512 主要增加 delay，对 TFLOPS 提升很小。

### 4.2 k 的作用

当 m=128 时：

| k | TFLOPS |
| --- | --- |
| 32 | 12.67 |
| 64 | 23.37 |
| 128 | 40.55 |
| 256 | 64.35 |
| 512 | 77.30 |
| 768 | 77.31 |
| 1024 | 77.31 |

解释：

- k 小时，ACE 的下发、加载、写回、同步等固定开销占比高。
- k 增大后，乘加工作量增加，固定开销被摊薄。
- k 到 512 左右后，计算阵列已接近峰值，继续增大 k 不再显著提升 TFLOPS。

推荐：

- 追求峰值吞吐：优先测试 `k = 512`。
- 输出写回较轻或使用 half 写回：可测试 `k = 256`。
- 低延迟场景：可选 `k = 128/256`，但必须接受 TFLOPS 低于峰值。

### 4.3 m 的作用

当 k=1024 时：

| m | TFLOPS |
| --- | --- |
| 1 | 0.80 |
| 2 | 1.59 |
| 4 | 3.19 |
| 8 | 6.37 |
| 16 | 12.74 |
| 32 | 25.39 |
| 64 | 50.61 |
| 96 | 75.54 |
| 128 | 77.31 |

解释：

- m 小时，性能约为 `0.797 * m` TFLOPS，说明每增加一行可近似增加固定计算能力。
- m=96 已经达到峰值附近。
- m=128 的收益主要是稳定满载和更好摊薄写回/下发。

推荐：

- 标准 tile 优先按 `m=128` 设计。
- 如果边界 m 不足，尽量合并 batch/head/block，让一个 ACE 调用看到更大的有效 m。
- 如果不能合并，小 m 场景应考虑 SIMD 或轻量路径，避免为很小 m 启动 ACE。

### 4.4 half 写回路径

`write half` sheet 显示，在小 k 或中等 k 下，half 写回可显著改善性能。

典型对比：

| m | k | 基准 TFLOPS | write half TFLOPS | 提升 |
| --- | --- | --- | --- | --- |
| 16 | 32 | 6.70 | 8.83 | 31.8% |
| 32 | 32 | 9.19 | 13.51 | 47.0% |
| 64 | 128 | 31.11 | 42.73 | 37.3% |
| 96 | 256 | 55.69 | 70.67 | 26.9% |
| 128 | 256 | 64.35 | 77.29 | 20.1% |
| 128 | 512 | 77.30 | 77.31 | 0.02% |
| 128 | 1024 | 77.31 | 77.32 | 0.01% |

结论：

- 当 k 小，C 写回/输出路径开销占比较高，half 写回能明显改善。
- 当 k>=512 且 m 足够大，计算已满载，half 写回几乎不再提升 TFLOPS。
- 如果算法允许 half 输出，`m=128,k=256,write half` 已可接近峰值。

### 4.5 下发 delay

`下发_delay` 的典型规律：

| k | delay 典型值 |
| --- | --- |
| 32 | 32 |
| 64 | 43 |
| 96 | 54 |
| 128 | 65 |
| 160 | 76 |
| 192 | 87 |
| 224 | 98 |
| 256 | 173 |
| 512 | 1540 到 1912 |
| 768 | 3092 到 3960 |
| 1024 | 4644 到 6008 |

结论：

- k<=224 时 delay 基本按小步长线性增长。
- k=256 出现一次明显阶跃。
- k>=512 后 delay 很大，但因为计算量也大，吞吐仍然能满。
- 若目标是低延迟而不是峰值 TFLOPS，应避免盲目使用 k=1024。

## 5. Tile 选择方法

### 5.1 默认推荐

| 目标 | 推荐 tile | 理由 |
| --- | --- | --- |
| 峰值吞吐 | `m=128, k=512` | 普通路径已接近 77.3 TFLOPS |
| 稳定满载 | `m=96..128, k>=512` | m>=96 时阵列利用率高 |
| half 输出 | `m=128, k=256` | write half 已接近峰值 |
| 低延迟 | `m=64..128, k=128/256` | delay 较低，但 TFLOPS 会下降 |
| 小 m 边界 | 合并 batch/head/block 到 m>=64，最好 m>=96 | 小 m ACE 利用率差 |

### 5.2 m 维策略

m 维决定 ACE 阵列行方向利用率。原则：

1. 主 tile 使用 m=128。
2. 边界 m>=96 时直接走 ACE。
3. 边界 64<=m<96 时可走 ACE，但要接受 65% 左右峰值。
4. 边界 m<64 时优先尝试合并多个独立问题。
5. 无法合并且 k 不大时，评估 SIMD 是否更合适。

### 5.3 k 维策略

k 维决定固定开销摊薄程度。原则：

1. 普通写回以 k=512 作为首选测试点。
2. half 写回以 k=256 和 k=512 作为首选测试点。
3. k<128 仅适合低延迟或小问题，通常难以发挥 ACE。
4. k>512 只有在减少上层循环、减少重复下发或数据复用更好时才值得。
5. k 很大时要关注下发 delay 和 LDM buffer 占用，不能只看 TFLOPS。

## 6. 数据布局与 LDM 组织

### 6.1 北向/西向数据

从图示和文字看：

- 西向数据是主要流式输入，带宽上限约 80GB/s。
- 北向数据可在多行输出中复用，等效带宽需求随 m 增大而下降。
- `rt_ace_load_west` 是关键触发点：加载西向数据的同时发生乘加。

推荐布局：

- 西向数据按 ACE 消费顺序连续存放，减少 LDM 地址跳变。
- 北向数据按行优先组织，便于加载器和复用。
- A/B 数据在 DMA 进入 LDM 前就完成适配，避免在 ACE 热路径中做复杂重排。

### 6.2 LDM Bank 分配

LDM 分为两个 Bank。ACE、SIMD、DMA、RMA 同时访问同一 Bank 时会竞争端口。

推荐分配：

| 数据 | 推荐 |
| --- | --- |
| north buffer | Bank0 |
| west buffer | Bank1 |
| ACMB writeback 目标 | 与当前 ACE 读取热点错开 |
| SIMD postprocess buffer | 避免与 ACE 当前读写同 Bank |
| DMA next tile buffer | 与当前计算 buffer 分离 |

一个常见 ping-pong 结构：

```text
LDM Bank0:
  north_buffer[0]
  west_buffer[1]
  c_writeback_buffer[0]

LDM Bank1:
  north_buffer[1]
  west_buffer[0]
  c_writeback_buffer[1]
```

具体布局要根据实际 LDM 地址映射验证，但原则是：ACE 当前读、ACE 写回、DMA 下一 tile 写入、SIMD 后处理不要集中到同一个 Bank。

### 6.3 DMA staging

ACE 的计算峰值只有在 A/B 能稳定送入 LDM 时才有意义。DMA 侧仍应遵守 T1 的通用访存原则：

- HBM 到 LDM 的 DMA 使用 128B 对齐、128B 整数倍。
- 32 个从核以核组视角共同覆盖连续 HBM 地址。
- 单从核传统 DMA tile 优先 8KB 到 16KB。
- DMA outstanding 读写合计最好不超过 11。
- DMA get 返回不要和 RMA 下网/ACE 写回集中打到同一 LDM Bank。

ACE 计算阶段应尽量隐藏 DMA：

```text
DMA get tile[n+1] -> LDM buffer[next]
ACE compute tile[n] -> ACMB[current]
ACE writeback tile[n-1] -> LDM C buffer[prev]
DMA put / SIMD postprocess tile[n-2]
```

## 7. ACMB 双缓冲方法

ACMB 有两个累加器缓冲区，正确使用双缓冲是 ACE 性能稳定的关键。

基本模式：

```text
ACMB0: 当前 tile 计算累加
ACMB1: 上一个 tile writeback

下一轮切换：
ACMB1: 当前 tile 计算累加
ACMB0: 上一个 tile writeback
```

调度原则：

- 不要等所有计算结束后再集中 writeback。
- `rt_ace_writeback` 应尽量与下一轮 ACE 计算或 DMA staging 重叠。
- 切换 ACMB 前确认上一轮 writeback 不会覆盖当前还要使用的 LDM C buffer。
- 如果 writeback 仍暴露在热路径上，优先尝试 half 写回或增大 k 到 512 摊薄开销。

## 8. 精度与写回

图示中明确提示：

- ACE 内部精度为 fp32。
- 每次乘加后会更新结果。
- fp32 写回 fp16 时，会截断为不支持非规格化数的 fp16。
- 这可能造成明显精度损失，尤其是输出结果接近 fp16 非规格化范围、或后续还要继续累加的场景。

工程建议：

- 对训练、归一化、softmax 前后、累加误差敏感的场景，必须单独验证 ACE 写回误差。
- 如果输出必须 fp16，优先做端到端误差评估，而不是只看单算子误差。
- 如果上层还要继续累加，尽量避免过早把中间结果截断到 fp16。
- 如果使用 write half 路径换性能，需要把性能收益和精度损失一起记录。

## 9. 使用流程

### 9.1 设计流程

1. 确认算子能表达为 `M x K` 乘 `K x 32` 或类似 ACE 友好的 tile。
2. 主 tile 先选择 `m=128,k=512`。
3. 如果输出 half 可接受，同时测试 `m=128,k=256,write half`。
4. 为 A/B/C 分配 LDM 双缓冲，并错开 LDM Bank。
5. 用 DMA 预取下一 tile，ACE 计算当前 tile，ACMB 写回上一 tile。
6. 边界 m 小时，先尝试合并 batch/head/block；无法合并再降级或走 SIMD。
7. 用 microbenchmark 或 profiler 验证 cycle、下发 delay、writeback 暴露时间。

### 9.2 推荐伪代码

```c
// 伪代码，只表达调度关系
for (tile = 0; tile < num_tiles; ++tile) {
    dma_get_async(north[next], global_B[tile + 1]);
    dma_get_async(west[next],  global_A[tile + 1]);

    // 当前 tile: north 已就绪，west load 触发 MAC
    ace_load_north(north[curr]);
    for (kk = 0; kk < k; kk += k_step) {
        rt_ace_load_west(west[curr] + kk, flags);
    }

    // 写回上一轮空闲 ACMB
    rt_ace_writeback(c_buffer[prev], acmb_prev);

    // 可选 SIMD 后处理 / DMA put
    postprocess_or_dma_put(c_buffer[older]);

    swap(curr, next);
    swap(acmb_curr, acmb_prev);
}
```

关键不是 API 名字，而是阶段关系：

```text
DMA 预取下一块
ACE 计算当前块
ACMB 写回上一块
SIMD/DMA put 处理更早一块
```

## 10. 性能诊断

### 10.1 TFLOPS 低

优先排查：

- m 是否小于 64，导致阵列行方向利用不足。
- k 是否小于 256，固定开销未摊薄。
- 是否没有使用 ACMB 双缓冲，writeback 暴露在热路径。
- A/B 是否在 LDM 中重排过多，ACE 等数据。
- DMA 是否没有 128B 对齐或核组视角不连续。
- LDM Bank 是否冲突，ACE/SIMD/DMA 同 Bank 竞争。

### 10.2 小 k 性能差

这是预期现象。解决方向：

- 增大 k 到 256 或 512。
- 多个小 k 问题合并成大 tile。
- 使用 half 写回降低 C 路径压力。
- 如果无法合并且 m/k 都小，考虑 SIMD 路径。

### 10.3 writeback 成为瓶颈

信号：

- `IO_C` 指标在小 k 时很高。
- `write half` 相比基准有明显提升。
- cycle 中 writeback/wait 不能被下一轮计算隐藏。

处理：

- 开启或测试 half 写回。
- 增大 k 摊薄 C 写回。
- 确保 ACMB0/ACMB1 正确 ping-pong。
- C 写回 LDM buffer 与 ACE 输入 buffer 错 Bank。

### 10.4 下发 delay 高

信号：

- k>=512 时 `下发_delay` 很大。
- 单 tile latency 不满足要求，虽然 TFLOPS 高。

处理：

- 对延迟敏感场景测试 k=256。
- 减少不必要的 ACE 调用次数，合并小 tile。
- 让 delay 与 DMA/计算/writeback 重叠。
- 不要为了极小 TFLOPS 提升盲目从 k=512 增到 k=1024。

## 11. 推荐参数表

| 场景 | m | k | 写回 | 预期 |
| --- | --- | --- | --- | --- |
| 标准 GEMM 主体 | 128 | 512 | 默认 | 接近 77.3 TFLOPS |
| 标准 GEMM 主体，half 输出可接受 | 128 | 256 | write half | 接近峰值，低于 k=512 的 delay |
| 中等 m | 96 | 512 | 默认 | 约 73 TFLOPS 以上 |
| 小 m 边界 | 64 | 512 | 默认 | 约 50 TFLOPS，建议合并 |
| 低延迟 | 64..128 | 128/256 | 视精度 | 吞吐下降但 delay 较低 |
| 精度敏感 | 96..128 | 512 | 谨慎 half 写回 | 先验证误差 |

## 12. 方法论总结

ACE 的高性能来自三个条件同时成立：

```text
m 足够大，让矩阵阵列行方向满载；
k 足够大，摊薄下发、加载、写回固定开销；
ACMB/LDM/DMA 正确双缓冲，让输入、计算和写回重叠。
```

实测数据给出的最重要结论是：

- 普通路径优先用 `m=128,k=512`。
- half 写回可把 `m=128,k=256` 推到接近峰值。
- m<64 或 k<128 通常不适合追求 ACE 峰值。
- k>512 对峰值帮助很小，但会显著增加下发 delay。
- 使用 ACE 时必须同时设计 LDM Bank、DMA staging 和 ACMB ping-pong，否则矩阵单元本身再快也会被 IO 和写回拖住。
