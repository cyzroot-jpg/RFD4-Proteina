---
id: source-teco-ops-agent-ops-sdaa-op-design-references-implementation-notes-gemm-fp16-pvc-fp32-32x-theoretical-perf-20fe8b30
title: "teco-ops-agent ops: sdaa-op-design/references/implementation-notes/gemm_fp16_pvc_fp32_32x_theoretical_perf.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/implementation-notes/gemm_fp16_pvc_fp32_32x_theoretical_perf.md
relative_source_path: sdaa-op-design/references/implementation-notes/gemm_fp16_pvc_fp32_32x_theoretical_perf.md
captured_at: 2026-08-04
---

# GEMM FP16->FP32 32X 理论性能建模与分析

本文分析当前目录中的 `gemm_fp16_PVC_MTile_NTile_KTile_new_fp32_32X.hpp` 与
`gemm_fp16_pvc_fp32_32x_demo.swcu`，并采用如下前提：

```text
C[M, N] = A[M, K] * B[K, N]
A/B: fp16, 已经完成最优 layout
C/accum: fp32
demo shape: M=2048, N=2048, K=7680
tile: MTile=1024, NTile=256, KTile=1536
ACE frequency: 2.36GHz / 2 = 1.18GHz
layoutA/layoutB: 不计入性能模型
```

参考资料：

- `../source-docs/指令拍数和流水线派发.md`
- `../source-docs/sdaa-hardware-architecture.md`
- `../source-docs/teco_hardware_execution_model.md`

## 1. Tiling 与计算闭合

当前 compute kernel 的关键参数：

```text
ROWS=4
COLS=8
CORE_NUMBER=32
ACE_N=32
ACE_K=32
M1_TILE=1024
N1_TILE=256
K1_TILE=1536
M2_TILE=M1_TILE/COLS=128
K2_TILE=K1_TILE/ROWS=384
N2_TILE=ACE_N=32
```

demo shape 的总计算量：

```text
FLOPs = 2 * M * N * K
      = 2 * 2048 * 2048 * 7680
      = 64,424,509,440 FLOPs
      = 64.425 GFLOPs
```

tile 数量：

```text
M tile loops = 2048 / 1024 = 2
N tile loops = 2048 / 256  = 8
K tile loops = 7680 / 1536 = 5
GEMM tiles   = 2 * 8 * 5 = 80
```

`launch()` 里还按 `COLS=8` 做 `rma_loop`：

```text
all_loops = MTileLoops * KTileLoops * NTileLoops * COLS
          = 2 * 5 * 8 * 8
          = 640
```

每个 `all_loop` 中：

```text
cur_k2 = K1_TILE / ROWS = 1536 / 4 = 384
ACE_LOOPS = cur_k2 / ACE_K = 384 / 32 = 12
```

单条完整 ACE 描述符对应：

```text
shape = M2_TILE x ACE_N x ACE_K = 128 x 32 x 32
FLOPs_ace_desc = 2 * 128 * 32 * 32 = 262,144 FLOPs
```

每个从核完整问题上的 ACE 描述符数：

```text
ACE descriptors per core = 640 * 12 = 7680
```

32 核合计：

```text
32 * 7680 * 262,144 = 64,424,509,440 FLOPs
```

与 GEMM 总 FLOPs 完全一致，说明该 demo shape 在当前 tiling 下没有尾块计算浪费。

## 2. ACE 理论算力

资料中说明 ACE 为半频工作；本次按用户给定频率：

```text
F_ace = 2.36GHz / 2 = 1.18GHz
```

ACE 脉动阵列可按 `128 x 32` 输出阵列、`K=32` 深度建模。一条完整 `128x32x32` 描述符的理想计算周期为约 `128` 个 ACE cycle：

```text
C_desc_ideal = 128 cycles
P_core = 262,144 FLOPs * 1.18e9 / 128
       = 2.41664 TFLOPS/core

P_32core = 32 * P_core
         = 77.33248 TFLOPS
```

demo shape 的 ACE 理想计算下界：

```text
T_ace_ideal = 64.4245 GFLOPs / 77.33248 TFLOPS
            = 0.833 ms
```

资料中的 ACE.xlsx 经验数据表明，在 `K=384` 工作点约为峰值的 `89%`。当前 kernel 的每个从核每轮正是 `cur_k2=384`，因此更现实的 ACE-only 上界可估为：

```text
P_ace_k384 ~= 77.33248 * 0.89
           ~= 68.826 TFLOPS

T_ace_k384 ~= 64.4245 GFLOPs / 68.826 TFLOPS
            ~= 0.936 ms
```

如果直接把资料中 `m=96,K=384` 的 `67.1TFLOPS @ 1.25GHz` 按 `1.18/1.25` 缩放：

```text
P_scaled = 67.1 * 1.18 / 1.25
         = 63.34 TFLOPS

T_scaled = 64.4245 GFLOPs / 63.34 TFLOPS
         = 1.017 ms
```

因此在不考虑 HBM、RMA、SIMD reduce、同步等待的情况下，当前 shape 的 ACE compute-only 理论区间大致是：

```text
0.83 ms ideal
0.94 ms K=384 efficiency model
1.02 ms ACE.xlsx scaled model
```

## 3. ACE 西向/北向/输出带宽

按一条完整 ACE 描述符计算：

```text
West(A) bytes per desc  = 128 * 32 * sizeof(fp16) = 8,192 B
North(B) bytes per desc = 32 * 32 * sizeof(fp16)  = 2,048 B
Output bytes per block  = 128 * 32 * sizeof(fp32) = 16,384 B
```

单条描述符理想耗时：

```text
T_desc = 128 / 1.18GHz = 108.47 ns
```

所以单从核 ACE 输入口需求为：

```text
West bandwidth  = 8,192 B / 108.47 ns = 75.52 GB/s
North bandwidth = 2,048 B / 108.47 ns = 18.88 GB/s
```

这与资料中的口径一致：`West=80GB/s @ 1.25GHz` 缩放到 `1.18GHz` 后为：

```text
80 * 1.18 / 1.25 = 75.52 GB/s
```

`West=128` 时 North 等效约 `20GB/s @ 1.25GHz`，缩放后：

```text
20 * 1.18 / 1.25 = 18.88 GB/s
```

当前 kernel 每个 `rma_loop` 连续做 `12` 条 ACE 描述符后写回一次 `128x32 fp32` 输出，因此按计算区间摊销的输出带宽为：

```text
Output avg bandwidth = 16,384 B / (12 * 108.47 ns)
                     = 12.59 GB/s per core
```

如果按资料中的写回口需求 `27GB/s @ 1.25GHz` 直接缩放，则活跃写回口需求约：

```text
27 * 1.18 / 1.25 = 25.49 GB/s
```

两者口径不同：`12.59GB/s` 是按 `K=384` 计算窗口摊销后的平均输出流量，`25.49GB/s` 是写回动作活跃时的端口需求估计。

完整 demo 中每个从核的 ACE/LDM 流量：

```text
West per core  = 7680 * 8192 B  = 62.915 MB
North per core = 7680 * 2048 B  = 15.729 MB
Output per core = 640 * 16384 B = 10.486 MB
```

32 核聚合：

```text
West total  = 2.013 GB
North total = 0.503 GB
Output total = 0.336 GB
```

这些是 ACE 与各从核本地 LDM 之间的流量，不等价于 HBM 流量。

## 4. Compute-only HBM 流量

本节不包含 layoutA/layoutB 的读写，只分析 A/B 已经在最优布局下的 compute 阶段。

当前 compute 仍需要从 HBM/workspace 读取 layoutA/layoutB，并读写 partial C workspace。对 demo shape：

```text
A bytes = M * K * sizeof(fp16) = 31.457 MB
B bytes = K * N * sizeof(fp16) = 31.457 MB
C bytes = M * N * sizeof(fp32) = 16.777 MB
K tile loops = 5
M tile loops = 2
```

从源码访问模式看：

- layoutA：每个 `M,K` tile 读一次，合计约 `31.457 MB`。
- layoutB：每个 `M` tile 会扫一遍完整 B，`M tile loops=2`，合计约 `62.915 MB`。
- partial C：前 4 个 KTile 写 workspace，后 4 个 KTile 读旧 partial，合计 `8 * C bytes = 134.218 MB`。
- final C：最后写出一次，`16.777 MB`。

compute-only 可见 HBM/workspace 流量：

```text
traffic_compute ~= A + 2*B + 8*C + C
                ~= 245.367 MB
```

算术强度：

```text
AI_compute = 64.4245 GFLOPs / 245.367 MB
           = 262.56 FLOPs/byte
```

若采用资料中 HBM 实测聚合带宽 `130.8GB/s`：

```text
P_hbm_roof = 262.56 FLOPs/B * 130.8 GB/s
           = 34.34 TFLOPS

T_hbm_min = 245.367 MB / 130.8 GB/s
          = 1.876 ms
```

这个 HBM roof 低于 `K=384` 的 ACE-only 上界 `68.8TFLOPS`。因此：

- 如果 compute 阶段有效 HBM 带宽接近 `130.8GB/s`，主瓶颈会偏 HBM/workspace 流量。
- 如果实际设备/访问模式能达到更高带宽，或 HBM 读写被流水重叠隐藏，瓶颈才会转向 ACE/RMA/SIMD/sync。

使 HBM roof 与 ACE `K=384` 上界打平所需带宽：

```text
B_required = 68.826 TFLOPS / 262.56 FLOPs/B
           = 262.1 GB/s
```

使 HBM roof 与 scaled ACE 上界 `63.34TFLOPS` 打平所需带宽：

```text
B_required = 63.34 TFLOPS / 262.56 FLOPs/B
           = 241.2 GB/s
```

## 5. Pipeline 与等待项

计算主循环尝试重叠：

```text
dma_get_matB(next)
dma_get_matC(previous partial)
dma_put_matC(older partial/final)
rma_put_matB
ACE compute
rma_put_matC
SIMD reduce
```

资料中的执行模型强调：DMA/RMA、主存访问、远程 LDM、同步、ACE 都属于静态拍数不可直接确定的部分，必须结合 profiler、cycle 计数或 reply wait 统计确认。因此源码中出现 `wait` 只能说明存在潜在等待点，不能单独证明瓶颈。

对当前 kernel，比较明确的风险点是：

1. 每个 `all_loop` 只有 `12` 条 ACE 描述符，虽然满足资料中“`K=384` 是典型工作点”，但相比 `K>=576` 饱和平台仍有差距。
2. `ace_cal` 被拆成 `4,2,2,2,remaining` 的分段，用于穿插 `simd_reduce_matC`，若 RMA/SIMD/同步任一侧延迟偏高，会吃掉 ACE 连续派发窗口。
3. `dma_put_matC` 与 `RMA PUT` 都可能占 Mesh 上行方向；资料指出 DMA PUT + RMA PUT 同向会冲突。
4. ACE 与 SIMD 是不同硬件单元，但都可能通过 MBOX/LDM bank 访问本地 LDM；若 bank 分布不理想，会降低重叠效率。
5. `rt_synchronized_row/col` 在热循环内出现，可能形成固定开销，需要 cycle trace 验证。

## 6. LDM 容量与本地带宽压力

当前 LDM 分配接近 235KB 上限：

```text
ldm_matA = 128 * 384 * 2           = 96 KB
ldm_matB double + rma = 3*32*384*2 = 72 KB
ldm_C dma/rma = 6*(32*128/4)*4     = 24 KB
ldm_write double = 2*32*128*4      = 32 KB
total ~= 224 KB
```

这解释了为什么 `K2_TILE=384` 是比较自然的工作点：继续增大 `KTile` 或 `M2_TILE` 很快会撞到 LDM 容量和 bank 竞争限制。

按单核理想 ACE 计算窗口，LDM 侧 ACE 流量需求约为：

```text
West  input: 75.52 GB/s
North input: 18.88 GB/s
Output avg: 12.59 GB/s
```

合计约 `106.99GB/s per core` 的 ACE-LDM 平均流量。资料中 LDM/SIMD 读带宽极限为 `160GB/s` 量级，但 ACE、DMA、RMA、SIMD 会共享或竞争 MBOX/LDM bank，所以实际能否维持该流量取决于 bank 放置与流水重叠。

## 7. GEMM 优化设计顺序

GEMM 这类高复用矩阵乘算子，优化设计应先围绕 ACE 饱和展开，再用 LDM、DMA/HBM、RMA、SIMD reduce 和同步开销逐级校验。推荐顺序如下。

1. 先以 ACE 算力打满为目标设计分块。

   GEMM 的核心收益来自让 `rt_ace_load_west` 连续派发，减少 writeback 和同步对计算窗口的切分。K 方向需要足够长，资料中 `K=384` 已经是较好的工作点，`K>=576` 更接近饱和平台；M 方向要保证 West 利用率，当前 `M2=128` 是高利用率配置；N 方向围绕 `ACE_N=32` 展开，再通过 `COLS=8` 形成 `N1=256`。

2. 用 LDM 容量反推 tile 是否可落地。

   分块不能只看 ACE 峰值。当前 `M2=128,K2=384,N2=32` 时，A/B/C/write buffer 已经约 `224KB`，接近可用上限。继续增大 `KTile` 或 `M2` 会立刻带来 LDM 容量、bank 冲突和 double buffer 空间问题。因此 tile 搜索必须把 LDM 作为硬约束。

3. 计算 ACE 西向、北向、输出带宽需求。

   当前理想窗口下每核 ACE-LDM 平均需求约为 `West 75.52GB/s + North 18.88GB/s + Output 12.59GB/s`。这一步主要检查 LDM/MBOX/bank 是否能支持 ACE 连续工作，而不是检查 HBM。若本地 LDM 侧供数不足，ACE 理论峰值无法兑现。

4. 再计算 HBM/DMA roof。

   对当前 compute-only 模型，算术强度约 `262.56 FLOPs/byte`。若按 `DMA_GET 256GB/s` 估算，HBM roof 约 `67.22TFLOPS`，已经接近 `K=384` 的 ACE 上界；若只能达到 `130.8GB/s`，则 roof 只有 `34.34TFLOPS`。因此访存设计目标不是简单“降低流量”，而是确保有效 DMA/HBM 带宽不低于 ACE 上界所需的约 `241-262GB/s`。

5. 设计 DMA/RMA/SIMD/ACE 流水。

   目标是把 `dma_get_matB(next)`、`dma_get_matC(previous partial)`、`dma_put_matC(older partial/final)`、`rma_put_matB`、ACE compute、`rma_put_matC`、`simd_reduce_matC` 尽量重叠。关键点不是是否存在 double buffer，而是 wait 点和同步点是否切碎 ACE 连续派发窗口。

6. 最后确定分核与数据复用策略。

   当前 `4x8=32` 分核中，`ROWS=4` 切 K，`COLS=8` 组织 M/N 与 RMA 传播。分核策略应服务于两个目标：一是保证每个从核有足够连续 ACE 工作量，二是降低 A/B/C 的重复搬运、RMA 归约和 partial C workspace 成本。

简化成一句话：GEMM 优化应从“如何让 ACE 长时间满载”开始，但每一步都必须用 LDM 容量、ACE-LDM 带宽、DMA/HBM roof、RMA/SIMD/sync 开销校验，否则容易得到计算上好看但实际跑不满的 tile。

## 8. 结论

在 `A/B 已经完美 layout`、`ACE=1.18GHz`、只分析 compute 阶段的假设下：

```text
总计算量: 64.425 GFLOPs
ACE ideal peak: 77.33 TFLOPS
ACE ideal lower bound: 0.833 ms
ACE K=384 efficiency upper bound: 68.83 TFLOPS, 0.936 ms
ACE.xlsx scaled upper bound: 63.34 TFLOPS, 1.017 ms
compute-only HBM traffic: 245.37 MB
compute arithmetic intensity: 262.56 FLOPs/byte
HBM roof @130.8GB/s: 34.34 TFLOPS, 1.876 ms
```

因此当前 shape 的理论性能可以分两种判断：

1. 若 compute 阶段有效 HBM/workspace 带宽约为 `130.8GB/s`，则理论上限约 `34.3TFLOPS`，端到端 compute 时间下界约 `1.88ms`。
2. 若 HBM 流量被更高带宽或流水充分隐藏，则 ACE compute 上限约 `63-69TFLOPS`，时间下界约 `0.94-1.02ms`；理想极限为 `77.3TFLOPS`、`0.83ms`。

要把结论从 theoretical/possible 升级为 likely/confirmed，需要补充：

- compute-only kernel latency；
- HBM effective bandwidth 或 DMA wait 统计；
- ACE north/west counter 或 ACE busy ratio；
- RMA wait、SIMD reduce、`rt_synchronized_row/col` 的 cycle 占比；
- C workspace read/write 是否与 ACE 计算充分 overlap。
