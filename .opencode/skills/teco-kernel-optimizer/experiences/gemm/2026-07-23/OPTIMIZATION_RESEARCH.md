# GEMM 优化方法全面调研

## 算子规格

- **输入**: A [M=8192, K=7680] FP16, row-major; B [K=7680, N=8192] FP16, row-major
- **输出**: C [M=8192, N=8192] FP32, row-major
- **计算**: C = A × B (FP16 输入, FP32 累加)
- **SPE 网格**: 4×8 = 32 SPEs

## 性能上限分析

### 理论计算峰值
- ACE 矩阵引擎频率: 1.25 GHz (SPE 频率 2.5 GHz 的一半)
- 每个 ACE 每周期: 32×32 FP16 矩阵乘 = 2048 FLOPS/cycle
- 32 SPEs 总峰值: 32 × 2048 × 1.25 GHz = **81.92 TFLOPS**

### 理论带宽上限
- HBM 带宽: ~1.2 TB/s (典型值)
- 数据总量: A (120 MB) + B (120 MB) + C (256 MB) = 496 MB
- 理论最小时间: 496 MB / 1.2 TB/s = **0.41 ms**

### 实际性能目标
- 计算受限时间: (8192 × 8192 × 7680 × 2) / 81.92 TFLOPS = **12.58 ms**
- 带宽受限时间: **0.41 ms**
- **结论**: 计算受限算子, 优化重点是最大化 ACE 利用率和计算-通信重叠

---

## 优化方法清单 (按优先级排序)

### P1: 核心优化 (必须实现)

#### 1. ACE 矩阵引擎优化
**原理**: ACE 是专用矩阵乘加速单元, 比 SIMD 向量指令快 10-100x
**实现要点**:
- 使用 `matmul()` 或 `matmul_init/load_weight/compute/store` 分层 API
- K 维度必须以 32 为步长 (ACE_K=32, ACE_N=32)
- 使用 `matmul_set_flushing_output(handle, false)` 实现 K 维度累加不写回
- 最后一次 K 迭代设置 `flushing_output=true` 写回结果

**预期收益**: 10-50x 加速 (相比 SIMD 实现)
**约束**: N2 必须 ≤ 32, 超过需要数据重排

#### 2. 异步 DMA 与 Double Buffering
**原理**: DMA 搬运与 ACE 计算并行执行
**实现要点**:
- 使用 `memcpy_async()` 替代同步 `memcpy()`
- 分配双缓冲: `ldm_A[0/1]`, `ldm_B[0/1]`
- 状态机: `dma_buf` (当前 DMA 加载的 buffer), `comp_buf` (当前计算的 buffer)
- 流程:
  ```
  Iteration 0: DMA load buffer 0, wait, compute buffer 0
  Iteration 1: DMA load buffer 1, compute buffer 0, swap, wait, compute buffer 1
  Iteration 2+: DMA load buffer N, compute buffer N-1, swap, wait, compute buffer N
  ```

**预期收益**: 30-50% 加速 (隐藏 DMA 延迟)
**约束**: 需要 2x LDM 空间, 注意 DMA 队列深度 (≤11 outstanding requests)

#### 3. 两级 Tiling (SPA + SPE)
**原理**: 减少 Global 内存访问次数, 最大化数据复用
**实现要点**:
- SPA 层: 每次循环计算 M1×N1 的 C 子块 (如 256×256)
- SPE 层: 每个 SPE 计算 M2×N2 的子块 (如 64×32)
- K 维度分块: K1=256, 每次 DMA 加载 K1 层

**Tile 配置建议**:
```
M1 = 256, N1 = 256, K1 = 256  (外层 tile)
M2 = 64,  N2 = 32,  K2 = 32   (SPE 层 tile, ACE 原生大小)
ROWS = 4, COLS = 8             (SPE 网格)
```

**LDM 容量检查**:
- ldm_A: M2 × K1 = 64 × 256 = 16384 elements × 2B = 32 KB × 2 (double buffer) = 64 KB
- ldm_B: K1 × N2 = 256 × 32 = 8192 elements × 2B = 16 KB × 2 = 32 KB
- ldm_C: M2 × N2 = 64 × 32 = 2048 elements × 4B = 8 KB
- **总计**: 104 KB / SPE (LDM 通常 128-256 KB, 可行)

**预期收益**: 减少 Global 访问 M1×N1 / (M2×N2) = 256×256 / (64×32) = 32x

---

### P2: 高级优化 (推荐实现)

#### 4. 数据广播 (Broadcast)
**原理**: 同行/列 SPE 共享相同 A/B 数据, 避免重复 Global 读取
**实现要点**:
- 使用 `rt_dma_ibcast()` 或 `rt_dma_row_ibcast()` / `rt_dma_col_ibcast()`
- A 矩阵: 同一行的 SPE 共享 A 数据 → 行广播
- B 矩阵: 同一列的 SPE 共享 B 数据 → 列广播

**示例**:
```cpp
// SPE (rid, cid) 加载 A[m1:m1+M2, k1:k1+K1]
// 同一行 (rid 相同) 的 8 个 SPE 共享这块 A 数据
// 只需要一个 SPE 读取, 然后行广播给其他 7 个 SPE
if (cid == 0) {
    rt_dma_row_ibcast(ldm_A[dma_buf], A + ..., size, reply);
}
rt_dma_row_wait();  // 等待广播完成
```

**预期收益**: 减少 Global 读取 (COLS-1)/COLS = 87.5% (对 A), 类似对 B
**约束**: 需要额外的同步开销, 对小 tile 可能不划算

#### 5. 数据重排 (Permute)
**原理**: ACE 要求 N2 ≤ 32, 如果 N1 > 32 需要重排 B 矩阵
**实现要点**:
- B 矩阵原始布局: [K, N] row-major
- ACE 要求: [K, 32] 分块加载
- 重排: 将 B 的每 32 列作为一个块, 连续存储

**示例**:
```cpp
// 原始 B: B[k][n], 访问 B[k][n1:n1+32]
// 重排后: B_permuted[k/32][n/32][32][32]
// 访问: B_permuted[k/32][n1/32][k%32][n1%32]
```

**预期收益**: 支持更大的 N1 tile, 提高数据复用
**约束**: 重排本身有开销, 需要权衡

#### 6. K 维度累加优化
**原理**: 减少 C 矩阵写回次数
**实现要点**:
- K1 循环内部: `matmul_set_flushing_output(false)` 只累加不写回
- K1 循环结束: `matmul_set_flushing_output(true)` 写回最终结果
- 避免中间结果的 LDM → Global 搬运

**预期收益**: 减少写回次数 K/ACE_K 倍

---

### P3: 微调优化 (可选实现)

#### 7. LDM 对齐与访问模式优化
**原理**: 对齐的内存访问提高带宽利用率
**实现要点**:
- DMA 地址必须 4B 对齐 (最好 64B 对齐)
- SIMD 访问必须 16B 对齐 (最好 64B 对齐)
- 使用 `__attribute__((aligned(64)))` 或手动 padding

**预期收益**: 5-10% 带宽提升

#### 8. 循环展开与指令调度
**原理**: 减少循环开销, 提高指令级并行
**实现要点**:
- 使用 `#pragma unroll` 展开小循环
- 手动安排 DMA/ACE/SIMD 指令交错执行

**预期收益**: 5-15% 加速

#### 9. SPE 网格调优
**原理**: 不同的 ROWS×COLS 配置影响数据复用率
**实现要点**:
- 尝试 4×8, 8×4, 2×16 等配置
- 根据 M/N 比例选择: M > N → 更多行; M < N → 更多列

**预期收益**: 10-20% 加速 (取决于 shape)

#### 10. 混合精度优化
**原理**: FP16 输入 → FP32 累加 → FP16 输出 (如果允许)
**实现要点**:
- 使用 `MatmulHalfToFloat` 或 `MatmulHalfToHalf`
- 如果输出可以是 FP16, 减少写回带宽

**预期收益**: 减少 50% 输出带宽

---

## 优化组合策略

### 阶段 1: Baseline + ACE (迭代 1-2)
- 实现基础 ACE 矩阵乘
- 验证正确性
- 建立性能基准

### 阶段 2: Double Buffering (迭代 3-4)
- 添加异步 DMA
- 实现双缓冲流水线
- 隐藏 DMA 延迟

### 阶段 3: Tiling 优化 (迭代 5-6)
- 调整 M1/N1/K1 tile 大小
- 优化 LDM 容量分配
- 平衡计算密度与带宽

### 阶段 4: 高级优化 (迭代 7-10)
- 尝试数据广播
- 尝试数据重排
- SPE 网格调优
- 指令调度优化

---

## 关键约束检查清单

- [ ] ACE_K = 32, ACE_N = 32 (硬件约束)
- [ ] K 必须是 ACE_K 的倍数, 否则需要 padding
- [ ] N2 ≤ 32, 否则需要数据重排
- [ ] DMA 地址 4B 对齐
- [ ] LDM 容量 ≤ 128-256 KB / SPE
- [ ] DMA 队列深度 ≤ 11 outstanding requests
- [ ] `memcpy_async` 必须配合 `memcpy_wait` 使用
- [ ] `matmul_set_flushing_output` 在最后一次 K 迭代必须为 true

---

## 参考资源

- `kernel-teco-al-gemm`: Teco-AL 完整优化路线 (分块+广播+重排+双缓冲)
- `doc-tecolibrt-user-manual-v1-2-0-p02`: ACE matmul API 文档
- `doc-tecolibrt-user-manual-v1-2-0-p06`: DMA broadcast API 文档
- `teco-al/SDAAC_examples/matmul/matmul_async_128_64_32.scpp`: 异步矩阵乘示例
- `teco-al/custom_ops/gemm/gemm.scpp`: 生产级 GEMM 实现
