# GEMM 算子优化方法全面调研

**日期**: 2026-07-06  
**目标**: 系统性调研 SDAA 平台上 GEMM 算子的所有可能优化方法  
**原则**: 先调研，后优化。不急于开始实现，确保充分理解所有优化手段。

---

## 一、GEMM 算子特征分析

### 1.1 计算特征

```
Case: M=8192, N=8192, K=7680
数据类型: FP16 输入 → FP32 累加 → FP32 输出
计算量: 2 × 8192 × 8192 × 7680 = 1.03 TFLOPS
数据量: A(120MB) + B(120MB) + C(256MB) = 496 MB
理论计算密度: 1.03 TFLOPS / 496 MB = 2076 FLOP/byte
```

**结论**: 高度计算密集型，理论上可以通过优化达到计算绑定。

### 1.2 数据访问模式

```
A[M, K]: 每行被读取 N 次 (8192 次)
B[K, N]: 每列被读取 M 次 (8192 次)
C[M, N]: 每元素被写入 1 次

总 global memory 访问:
- A: 8192 × 7680 × 2B × 8192 = 1.03 TB (重复读取)
- B: 7680 × 8192 × 2B × 8192 = 1.03 TB (重复读取)
- C: 8192 × 8192 × 4B = 256 MB (写入一次)
```

**瓶颈**: 直接访问 global memory 会导致巨大的带宽浪费，必须通过 tiling + LDM 缓存提高数据复用。

### 1.3 并行维度

```
M 维度: 8192 行，可分配给 32 个 SPE，每 SPE 256 行
N 维度: 8192 列，可在 SPE 内并行处理
K 维度: 7680，需要分 tile (K_TILE=32，共 240 个 tile)
```

**并行策略**: M 维度跨 SPE 并行，N 维度在 SPE 内并行，K 维度分 tile 串行累加。

---

## 二、优化方法分类与详解

### 2.1 数据局部性优化

#### P1: LDM/SPM 缓存 (必须)

**原理**: 
- Global memory 带宽: ~40 GB/s
- SPM 带宽: ~62 GB/s (SPM→SPM), ~41 GB/s (Global→SPM)
- 将 tile 加载到 SPM，重复使用，减少 global memory 访问

**实现要点**:
```cpp
// 分配 SPM buffer
half *spm_a = (half *)malloc(BLOCK_M * BLOCK_K * sizeof(half));
half *spm_b = (half *)malloc(BLOCK_K * BLOCK_N * sizeof(half));

// 加载 tile 到 SPM
memcpy(spm_a, A + offset_a, BLOCK_M * BLOCK_K * sizeof(half));
memcpy(spm_b, B + offset_b, BLOCK_K * BLOCK_N * sizeof(half));

// 在 SPM 上计算
for (int kk = 0; kk < BLOCK_K; ++kk) {
    for (int i = 0; i < BLOCK_M; ++i) {
        for (int j = 0; j < BLOCK_N; ++j) {
            acc[i][j] += (float)spm_a[i][kk] * (float)spm_b[kk][j];
        }
    }
}
```

**Tile 大小选择**:
- 受 SPM 容量限制 (每 SPE ~512KB)
- 需要平衡 compute/memory 比率
- 推荐: BLOCK_M=64-128, BLOCK_N=32-64, BLOCK_K=32

**预期收益**: 10-50x (减少 global memory 访问)

**参考**: `technique-sdaa-dma-api`, `hw-sdaa-memory-model`

---

#### P2: Tile 大小优化 (重要)

**原理**:
- 大 tile 提高 compute/memory 比率
- 但增加 SPM 压力和寄存器压力
- 需要 roofline 分析确定最优 tile

**Tile 大小约束**:
- SPM 容量: BLOCK_M × BLOCK_K × 2B + BLOCK_K × BLOCK_N × 2B + BLOCK_M × BLOCK_N × 4B ≤ 512KB
- ACE 约束: BLOCK_K=32 (硬件原生), BLOCK_N=32, BLOCK_M=1..128
- 对齐约束: 地址 4B 对齐，size 4B 倍数

**候选 tile 配置**:

| 配置 | BLOCK_M | BLOCK_N | BLOCK_K | SPM 使用 | Compute/Memory | 适用场景 |
|------|---------|---------|---------|----------|---------------|---------|
| Small | 32 | 32 | 32 | 8KB | 低 | 快速验证 |
| Medium | 64 | 32 | 32 | 12KB | 中 | 平衡 |
| Large | 128 | 32 | 32 | 24KB | 高 | 计算绑定 |
| Wide | 64 | 64 | 32 | 20KB | 中 | 高复用 |

**参考**: `kernel-sdaa-gemm`, `technique-sdaa-matmul-api`

---

### 2.2 计算加速优化

#### P3: ACE 矩阵加速引擎 (核心)

**原理**:
- ACE 是专用矩阵乘法硬件
- 运行在 1.25 GHz (SPE 频率的一半)
- 两个累加器缓冲区 (每个 128×32×2B = 8KB)
- 支持双缓冲：一个计算，一个 writeback

**硬件参数**:
- West feeding 带宽: 80 GB/s (1.25 GHz × 64B/cycle)
- North feeding 带宽: 20 GB/s (当与 west 重叠时)
- K=32, N=32 是硬件原生尺寸
- m 范围: 1..128

**API 使用**:
```cpp
// 阻塞接口
matmul(MatmulHalfToFloat, output, input, weight, m, k, n);

// 非阻塞接口 (推荐)
MatmulHandle handle;
matmul_init(handle, MatmulHalfToFloat);
matmul_load_weight(handle, spm_b, MatmulK32, MatmulN32, stride_n);
matmul_compute(handle, spm_a, m, MatmulK32, stride_k);
matmul_store(handle, spm_c, m, MatmulN32);
matmul_wait(handle);
```

**约束**:
- SPM buffer 需要 64B 对齐
- K 必须是 32 的倍数
- N 必须是 32 的倍数
- m 范围 1..128

**预期收益**: 10-100x (相比标量计算)

**瓶颈分析**:
- Feeding 瓶颈: DMA 无法喂饱 ACE
- Writeback 瓶颈: ACE 结果写回 SPM 慢
- Dispatch delay: ACE 启动延迟
- Compute 瓶颈: ACE 计算能力不足 (罕见)

**参考**: `hw-ace`, `technique-sdaa-matmul-api`, `technique-ace-double-buffering`, `pattern-ace-feeding-writeback`

---

#### P4: SIMD 向量化 (备选)

**原理**:
- 使用 SIMD 指令处理多个数据元素
- FP16: 一次处理 8 个元素 (128-bit 向量)
- FP32: 一次处理 4 个元素 (128-bit 向量)

**实现要点**:
```cpp
// 向量加载
half8 b_vec = *((half8 *)(spm_b + kk * BLOCK_N + j));

// 标量累加 (FP16→FP32 转换)
float sum = 0.0f;
sum += (float)a_val * (float)b_vec.x0;
sum += (float)a_val * (float)b_vec.x1;
// ... x2-x7

// 或使用 FMA
sum = vfma(a_val, (float)b_vec.x0, sum);
```

**优化模式**:
- Widen-compute-narrow: FP16 加载 → FP32 计算 → FP16 存储
- 对齐主体 + 尾部处理
- 4× unroll
- FMA 替代 mul+add

**预期收益**: 2-8x (相比标量)

**适用场景**:
- ACE API 不可用或有 bug
- 小 tile 或特殊形状
- 作为 ACE 的 fallback

**参考**: `technique-sdaa-simd-vectorization`, `technique-simd-optimization-patterns`, `technique-simd-floating-point-ops`

---

### 2.3 延迟隐藏优化

#### P5: 异步 DMA + 双缓冲 (关键)

**原理**:
- 同步 DMA: compute 等待 DMA 完成
- 异步 DMA: DMA 和 compute 可以重叠
- 双缓冲: 2 套 buffer 交替使用，pipeline 深度=2

**实现要点**:
```cpp
// 双缓冲
half *spm_a[2], *spm_b[2];
float *spm_c[2];

// Pipeline
int active_buf = 0;
// 初始加载
memcpy(spm_a[0], A + offset_0, size);
memcpy(spm_b[0], B + offset_0, size);

for (int bk = 0; bk < K / BLOCK_K; ++bk) {
    int idle_buf = 1 - active_buf;
    int next_offset = (bk + 1) * BLOCK_K;
    
    // 异步加载下一个 tile
    if (bk < K / BLOCK_K - 1) {
        memcpy_async(spm_a[idle_buf], A + next_offset, size, 
                     0, {0,0}, MemcpyGlobalToSpm, dma_handle);
        memcpy_async(spm_b[idle_buf], B + next_offset, size,
                     0, {0,0}, MemcpyGlobalToSpm, dma_handle);
    }
    
    // 计算当前 tile
    matmul_compute(handle, spm_a[active_buf], ...);
    
    // 等待 DMA 完成
    if (bk < K / BLOCK_K - 1) {
        memcpy_wait(dma_handle);
    }
    
    active_buf = idle_buf;
}
```

**约束**:
- 异步 DMA 仅支持 Global↔SPM
- 地址 4B 对齐，size 4B 倍数
- DMA 队列深度 ≤11 (避免第 12 个请求的高延迟)

**预期收益**: 1.5-2x (隐藏 DMA 延迟)

**参考**: `technique-sdaa-dma-api`, `technique-ace-double-buffering`, `technique-dma-queue-budgeting`

---

#### P6: Triple Buffering (进阶)

**原理**:
- 三套 buffer，pipeline 深度=3
- 进一步隐藏 DMA 延迟

**实现要点**:
```cpp
half *spm_a[3], *spm_b[3];
float *spm_c[3];

// Pipeline 状态机更复杂
// 需要管理 3 个 buffer 的状态
```

**约束**:
- SPM 容量增加 50%
- 状态机复杂度增加
- 需要更多寄存器

**预期收益**: 1.2-1.5x (相比双缓冲)

**适用场景**:
- DMA 延迟远大于 compute 时间
- SPM 容量充足

---

#### P7: P0/P1 指令调度 (高级)

**原理**:
- T1 支持超标量双发射
- P0: 计算指令 (SIMD, ACE)
- P1: 访存/控制/DMA/RMA/ACE/sync
- 将独立 P1 工作靠近 P0 计算

**实现要点**:
```cpp
// 错误: 长 wait 区域
dma_issue(...);
wait();
compute(...);

// 正确: P0/P1 重叠
dma_issue(...);  // P1
compute(...);    // P0 (与 DMA 重叠)
wait();          // P1
```

**启发式规则**:
1. 将 DMA/RMA issue 提前到消费数据的计算之前
2. 在 DMA issue 和 wait 之间放入依赖允许的 P0 向量计算
3. 将 MEMB 和 sync 移出 inner loop
4. 不要过度关注低频操作 (如 sqrt)

**预期收益**: 1.2-1.5x (隐藏指令级延迟)

**参考**: `technique-p0-p1-overlap`, `hw-pipe0-pipe1`, `hw-spe-superscalar-dual-issue`

---

### 2.4 通信优化

#### P8: RMA/Broadcast 共享 B tile (重要)

**原理**:
- 问题: 每个 SPE 独立 DMA 加载 B tile，重复读取 global memory
- 方案: 一个 SPE 加载 B tile 到 SPM，其他 SPE 通过 RMA/Broadcast 获取
- 减少 global memory 读取 M/NUM_SPE 倍 (32x)

**RMA vs Broadcast 选择**:

| 特性 | RMA | Broadcast |
|------|-----|-----------|
| 模式 | 点对点 (pull/push) | 一对多 |
| 适用场景 | 少量 SPE 共享 | 多 SPE 共享 |
| 性能 | 高延迟，高带宽 | 低延迟，带宽受限 |
| 实现 | 复杂 (需要 ThreadGroup) | 简单 |

**RMA 实现**:
```cpp
// SPE 0 加载 B tile
memcpy(spm_b_0, B + offset, size);

// SPE 1-31 通过 RMA 获取
rma_get(spm_b_local, spm_b_0, size, local_id=1, remote_id=0);
```

**Broadcast 实现**:
```cpp
// SPE 0 广播 B tile
broadcast(spm_b, size, root_spe_id=0);

// 所有 SPE 接收
```

**约束**:
- 仅支持同一 SPA 内 SPE 间 SPM 通信
- 地址 4B 对齐，size 4B 倍数
- 需要同步 (ThreadGroup)

**预期收益**: 1.5-3x (减少 global memory 读取)

**参考**: `technique-sdaa-rma-broadcast-api`, `technique-rma-broadcast-selection`, `pattern-rma-contention`

---

#### P9: DMA 奇偶引擎交错 (高级)

**原理**:
- DMA 引擎有多个 (通常 2 个)
- 奇数 SPE 使用偶数 DMA 引擎，偶数 SPE 使用奇数 DMA 引擎
- 避免 DMA 引擎竞争

**实现要点**:
```cpp
int dma_engine = (spe_id % 2 == 0) ? 1 : 0;
// 使用特定 DMA 引擎的 API
```

**预期收益**: 1.1-1.3x (减少 DMA 竞争)

**参考**: `technique-dma-odd-even-interleave`

---

#### P10: 周期式 DMA 划分 (高级)

**原理**:
- 跨 SPE 的周期性 DMA 访问模式
- 避免 HBM bank conflict
- 优化 HBM channel-bank-row 访问

**实现要点**:
```cpp
// 每个 SPE 访问不同的 HBM channel/bank
int offset = spe_id * PERIODIC_SIZE;
memcpy(spm_a, A + offset, size);
```

**预期收益**: 1.1-1.3x (提高 HBM 带宽利用率)

**参考**: `technique-dma-periodic-partitioning`, `pattern-dma-hbm-underutilization`

---

### 2.5 数值精度优化

#### P11: Kahan 求和 (可选)

**原理**:
- FP32 累加在 K 很大时可能有精度损失
- Kahan 求和减少舍入误差

**实现要点**:
```cpp
float sum = 0.0f;
float c = 0.0f;  // 补偿
for (int kk = 0; kk < K; ++kk) {
    float y = a * b - c;
    float t = sum + y;
    c = (t - sum) - y;
    sum = t;
}
```

**预期收益**: 提高精度，但降低性能 10-20%

**适用场景**:
- K 很大 (>10000)
- 精度要求高 (atol < 1e-2)

**参考**: tecocustom 生产实现

---

#### P12: FP16 Writeback 优化 (可选)

**原理**:
- FP32 → FP16 写回需要特殊处理
- 0x8000 rounding 模式
- VCONH 截断指令

**实现要点**:
```cpp
// 使用 VCONH 指令
half8 result = vconv_float_to_half(float8_result);
```

**预期收益**: 正确的 FP16 输出

**适用场景**: 输出需要 FP16 (当前 case 是 FP32，不需要)

**参考**: `technique-fp16-writeback-vconh`

---

## 三、优化方法优先级排序

### 3.1 必须实现 (基础)

| 优先级 | 方法 | 预期收益 | 复杂度 | 理由 |
|--------|------|---------|--------|------|
| P1 | LDM 缓存 | 10-50x | 低 | 减少 global memory 访问，基础优化 |
| P2 | Tile 大小优化 | 1.2-2x | 低 | 提高 compute/memory 比率 |
| P3 | ACE 加速 | 10-100x | 中 | 专用矩阵硬件，核心加速 |

### 3.2 强烈推荐 (关键)

| 优先级 | 方法 | 预期收益 | 复杂度 | 理由 |
|--------|------|---------|--------|------|
| P5 | 异步 DMA + 双缓冲 | 1.5-2x | 中 | 隐藏 DMA 延迟 |
| P8 | RMA/Broadcast 共享 B | 1.5-3x | 高 | 减少 global memory 读取 32x |
| P7 | P0/P1 指令调度 | 1.2-1.5x | 高 | 隐藏指令级延迟 |

### 3.3 可选 (进阶)

| 优先级 | 方法 | 预期收益 | 复杂度 | 理由 |
|--------|------|---------|--------|------|
| P6 | Triple Buffering | 1.2-1.5x | 高 | 进一步隐藏延迟 |
| P9 | DMA 奇偶交错 | 1.1-1.3x | 中 | 减少 DMA 竞争 |
| P10 | 周期式 DMA 划分 | 1.1-1.3x | 高 | 优化 HBM 访问 |
| P4 | SIMD 向量化 | 2-8x | 中 | ACE 的 fallback |

### 3.4 特殊情况

| 优先级 | 方法 | 预期收益 | 复杂度 | 适用场景 |
|--------|------|---------|--------|---------|
| P11 | Kahan 求和 | 精度提升 | 低 | K 很大，精度要求高 |
| P12 | FP16 Writeback | 正确输出 | 低 | 输出需要 FP16 |

---

## 四、优化组合策略

### 4.1 基础版本 (迭代 1)

**目标**: 建立正确性，验证 LDM + ACE 基础路径

**方法组合**:
- P1: LDM 缓存
- P2: Tile 大小优化 (BLOCK_M=64, BLOCK_N=32, BLOCK_K=32)
- P3: ACE 加速 (基础，同步 DMA)

**预期性能**: 10-20s (50-100x 加速)

**分支变体**:
- b1: BLOCK_M=32 (小 tile)
- b2: BLOCK_M=64 (中 tile)
- b3: BLOCK_M=128 (大 tile)
- b4: BLOCK_N=64 (宽 tile)

---

### 4.2 优化版本 (迭代 2)

**目标**: 隐藏延迟，提高带宽利用率

**方法组合**:
- P1-P3: 基础版本
- P5: 异步 DMA + 双缓冲
- P7: P0/P1 指令调度

**预期性能**: 7-12s (80-150x 加速)

**分支变体**:
- b1: 双缓冲 (pipeline 深度=2)
- b2: Triple buffering (pipeline 深度=3)
- b3: P0/P1 手动调度
- b4: 组合优化

---

### 4.3 高级版本 (迭代 3)

**目标**: 最小化 global memory 访问，接近理论峰值

**方法组合**:
- P1-P3, P5, P7: 优化版本
- P8: RMA/Broadcast 共享 B tile
- P9: DMA 奇偶交错

**预期性能**: 7-10s (100-150x 加速)

**分支变体**:
- b1: RMA 共享 B
- b2: Broadcast 共享 B
- b3: RMA + DMA 奇偶交错
- b4: Broadcast + P0/P1 优化

---

## 五、性能瓶颈诊断

### 5.1 Roofline 模型

```
理论峰值:
- ACE 峰值: ~100 TFLOPS
- DMA 峰值: 40 GB/s
- SPM 峰值: 62 GB/s

实际测量:
- 时间: T ms
- TFLOPS: 1.03 / (T * 1e-3)
- 带宽: 496 MB / (T * 1e-3) / 1e9 GB/s

判断:
- TFLOPS < 50: 计算绑定不足，检查 ACE feeding
- 带宽 < 20 GB/s: 内存绑定，检查 DMA 利用率
- TFLOPS > 80 且带宽 > 30 GB/s: 接近最优
```

### 5.2 瓶颈诊断表

| 症状 | 可能瓶颈 | 诊断方法 | 解决方案 |
|------|---------|---------|---------|
| ACE 利用率低 | Feeding 瓶颈 | 检查 DMA 时间 vs ACE 时间 | 增加 pipeline 深度，异步 DMA |
| ACE 利用率低 | Writeback 瓶颈 | 检查 writeback 时间 | ACE 双缓冲，重叠 writeback |
| DMA 带宽低 | HBM underutilization | 检查 DMA 请求模式 | 周期式 DMA 划分，128B 对齐 |
| DMA 带宽低 | DMA 竞争 | 检查 SPE 间 DMA pattern | DMA 奇偶交错 |
| 整体性能低 | Dispatch delay | 检查 ACE 启动延迟 | 减少 tile 切换频率 |
| 精度问题 | 累加误差 | 检查 K 大小和误差分布 | Kahan 求和，FP64 累加 |

---

## 六、调研总结

### 6.1 关键发现

1. **ACE 是核心加速路径**
   - 10-100x 计算加速
   - 必须使用 K=32, N=32 硬件原生尺寸
   - 双缓冲可以重叠 compute 和 writeback

2. **异步 DMA 是延迟隐藏的关键**
   - 1.5-2x 性能提升
   - 需要双缓冲或三缓冲
   - DMA 队列深度 ≤11

3. **RMA/Broadcast 可以大幅减少 global memory 访问**
   - 减少 32x (NUM_SPE)
   - 需要同 SPA 内 SPE 间通信
   - 实现复杂度较高

4. **P0/P1 指令调度是高级优化**
   - 1.2-1.5x 性能提升
   - 需要将 P1 工作靠近 P0 计算
   - 需要 profiler 或 cycle-log 验证

### 6.2 优化路线图

```
迭代 1: LDM + ACE + 基础 tiling
  ↓ (验证正确性，建立 baseline)
迭代 2: 异步 DMA + 双缓冲 + P0/P1
  ↓ (隐藏延迟，提高带宽利用率)
迭代 3: RMA/Broadcast + DMA 优化
  ↓ (最小化 global memory 访问)
迭代 4: 深度调优 (tile 大小，pipeline 深度，指令调度)
  ↓ (接近理论峰值)
```

### 6.3 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| ACE API bug | 中 | 高 | 准备 SIMD fallback |
| SPM 容量不足 | 低 | 中 | 减小 tile 大小 |
| DMA 对齐问题 | 中 | 中 | 严格检查对齐约束 |
| 精度不达标 | 低 | 高 | Kahan 求和，调整容差 |
| 编译时间过长 | 高 | 中 | 使用小 case 快速验证 |

### 6.4 下一步行动

1. ✅ 完成全面调研 (本文档)
2. ⏳ 开始迭代 1: 实现基础版本 (LDM + ACE)
3. ⏳ Benchmark 并选择冠军
4. ⏳ 迭代 2: 实现异步 DMA + 双缓冲
5. ⏳ 迭代 3: 实现 RMA/Broadcast
6. ⏳ 迭代 4: 深度调优

---

## 七、参考资料

### 7.1 Wiki 页面

- `kernel-sdaa-gemm`: GEMM 优化路线图
- `technique-sdaa-matmul-api`: ACE API
- `technique-ace-double-buffering`: ACE 双缓冲
- `technique-sdaa-dma-api`: DMA API
- `technique-dma-queue-budgeting`: DMA 队列预算
- `technique-sdaa-rma-broadcast-api`: RMA/Broadcast API
- `technique-p0-p1-overlap`: P0/P1 指令调度
- `hw-ace`: ACE 硬件模型
- `hw-dma`: DMA 引擎模型
- `hw-pipe0-pipe1`: P0/P1 发射模型

### 7.2 生产实现

- `sdcops/src/slave_kernel/gemm_pvc.scpp`
- `tecoal/blas/ops/gemm_batch`
- `tecoal/blas/ops/gemm_bias_activation`
- `tecocustom/dnn-custom-op-*`

### 7.3 文档

- SDAA C 编程指南 v3.1.0
- 性能优化手册 SDAA C 篇 v2.0.2
- PCX 编程指南 v1.1.0
- SDAA T1 SIMD 向量指令参考手册

---

**调研完成**: 2026-07-06  
**状态**: 准备开始迭代 1  
**信心度**: 高 (基于充分的调研和 wiki 知识)
