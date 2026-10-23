# 生产实现分析

## 分析的生产实现

### 1. Teco-AL GEMM (`teco-al/custom_ops/gemm/gemm.scpp`)
**特点**: 生产级 GEMM 实现, 支持 batch GEMM
**关键参数**:
- M = 128, N = 32, K = 256
- K_BLK = 32 (ACE 原生 K 步长)
- B = 32 (batch size, 分配给 32 SPEs)

**优化技术**:
1. **异步 DMA**: `memcpy_async()` + `memcpy_wait()`
2. **ACE 分层 API**:
   - `matmul_init(handle, MatmulShortToInt)` 初始化
   - `matmul_load_weight(handle, ptr, MatmulK32, MatmulN32)` 加载权重
   - `matmul_compute(handle, ptr, M, MatmulK32, stride)` 计算
   - `matmul_store(handle, ptr, M, MatmulN32)` 写回
3. **K 维度分块**: K=256, 分 4 块 (每块 K_BLK=32)
4. **Double Buffering**: 每次循环处理 2 个 K 块, 交替加载和计算
5. **累加控制**: `matmul_set_flushing_output(handle, false)` 中间迭代, `true` 最后一次

**关键代码模式**:
```cpp
for (int j = 0; j < chunks; j++) {
    // 等待上一轮加载完成
    matmul_wait_loading_input(handle);
    matmul_wait_loading_weight(handle);
    
    // 第一块: 累加不写回
    matmul_set_flushing_output(handle, false);
    matmul_load_weight(handle, weight + offset1, MatmulK32, MatmulN32);
    matmul_compute(handle, input + offset1, M, MatmulK32, stride);
    
    // 第二块: 最后一次写回
    matmul_set_flushing_output(handle, (j == chunks - 1));
    matmul_load_weight(handle, weight + offset2, MatmulK32, MatmulN32);
    matmul_compute(handle, input + offset2, M, MatmulK32, stride);
}
matmul_store(handle, output, M, MatmulN32);
matmul_wait(handle);
```

**启示**:
- K 维度必须分块, 每块 K_BLK=32 (ACE 约束)
- Double buffering 的关键是交错加载和计算
- `flushing_output` 控制累加器是否写回, 避免中间结果写回

---

### 2. Teco-AL 异步矩阵乘示例 (`matmul_async_128_64_32.scpp`)
**特点**: 演示异步矩阵乘的完整流程
**关键参数**:
- M = 128, N = 32, K = 64
- 单个 SPE 执行 (threadIdx == 0)

**优化技术**:
1. **完全异步 DMA**:
   ```cpp
   memcpy_async(input, dataA, size, MemcpyGlobalToSpm);
   memcpy_async(weight, dataB, size, MemcpyGlobalToSpm);
   memcpy_wait();  // 等待所有异步 DMA 完成
   ```
2. **权重加载与输入加载分离**:
   - 先加载权重: `matmul_load_weight(handle, weight, MatmulK32, MatmulN32)`
   - 等待权重加载: `matmul_wait_loading_weight(handle)`
   - 再加载输入并计算: `matmul_compute(handle, input, M, MatmulK32, stride)`
3. **跨步加载 (Stride)**:
   - `stride = K / MatmulK32 - 1`
   - 用于加载不连续的输入块
4. **分两次计算 K=64**:
   - 第一次: K=0..31, `flushing_output=false`
   - 第二次: K=32..63, `flushing_output=true`

**启示**:
- `memcpy_async` 可以同时发起多个, 用 `memcpy_wait()` 统一等待
- 权重和输入可以分开加载, 提高流水线效率
- 跨步加载用于处理非连续内存布局

---

### 3. Teco-AL GEMM 文档 (`kernel-teco-al-gemm`)
**特点**: 完整的优化路线说明
**三个关键设计**:

#### a. 数据分块 (Tiling)
- **SPA 层**: bM × bN 子块 (如 256×256)
- **SPE 层**: localbM × localbN (如 64×32)
- **K 层**: bK (如 256)

#### b. 数据广播 (Broadcast)
- **问题**: 同行/列 SPE 重复读取相同 A/B 数据
- **解决**: 一个 SPE 读取, 广播给同行/列其他 SPE
- **API**: `rt_dma_row_ibcast()`, `rt_dma_col_ibcast()`, `rt_dma_ibcast()`
- **收益**: 减少 Global 读取 (COLS-1)/COLS

#### c. 数据重排 (Permute)
- **问题**: ACE 要求 localbN ≤ 32
- **解决**: B 矩阵重排为 [K/32][N/32][32][32] 布局
- **开销**: 重排本身有开销, 需要权衡
- **约束**: 如果 N > 32, 必须重排

**主循环伪代码**:
```
分配 SPM: A/B/C 双缓冲 + 重排空间
首次广播加载 A/B 到 SPM

for (idx in [0, nM*nN)):  // 遍历 bM, bN
    for (idK in [0, nK)):  // 遍历 bK
        交换双缓冲指针
        等待当前块广播完成
        广播预取下一块
        重排 B (如果需要)
        ACE 计算 (最后一次写回, 其他只累加)
    
    写回 C (精度转换 + 重排)
```

**启示**:
- 双缓冲 + 广播预取: 当前块计算与下一块加载并行
- K 维度内部只有最后一次写回, 减少写回次数
- 广播和重排是高级优化, 需要在简单版本稳定后再尝试

---

## 提取的最佳实践

### Tile 大小选择指南

| 参数 | 推荐值 | 约束 | 说明 |
|------|--------|------|------|
| ACE_K | 32 | 硬件固定 | ACE 原生 K 步长 |
| ACE_N | 32 | 硬件固定 | ACE 原生 N 宽度 |
| M2 (SPE 层 M) | 64-128 | M1 / ROWS | 每个 SPE 处理的行数 |
| N2 (SPE 层 N) | 32 | ≤ 32 | ACE 约束, 超过需重排 |
| K1 (外层 K) | 128-256 | 必须被 ACE_K 整除 | DMA 加载的 K 块大小 |
| M1 (外层 M) | 128-512 | M / ROWS 的因子 | SPA 层 M tile |
| N1 (外层 N) | 128-512 | N / COLS 的因子 | SPA 层 N tile |
| ROWS | 2-8 | SPA 行数 | 影响 A 数据复用 |
| COLS | 4-16 | SPA 列数 | 影响 B 数据复用 |

### LDM 容量分配策略

**公式**:
```
ldm_A = M2 × K1 × sizeof(FP16) × NUM_BUFFERS
ldm_B = K1 × N2 × sizeof(FP16) × NUM_BUFFERS
ldm_C = M2 × N2 × sizeof(FP32) × 1  (输出不需要双缓冲)
total = ldm_A + ldm_B + ldm_C
```

**约束**:
- total ≤ 128-256 KB (取决于硬件)
- 双缓冲 (NUM_BUFFERS=2) 提高流水线效率, 但占用 2x 空间
- 如果 LDM 不够, 减小 K1 或 M2

**示例配置** (M2=64, N2=32, K1=256):
```
ldm_A = 64 × 256 × 2 × 2 = 64 KB
ldm_B = 256 × 32 × 2 × 2 = 32 KB
ldm_C = 64 × 32 × 4 = 8 KB
total = 104 KB ✓
```

### 流水线设计模式

#### 模式 1: 简单双缓冲
```cpp
int dma_buf = 0, comp_buf = 1;

for (int k1 = 0; k1 < K; k1 += K1) {
    // DMA 加载 dma_buf
    memcpy_async(ldm_A[dma_buf], ..., MemcpyGlobalToSpm);
    memcpy_async(ldm_B[dma_buf], ..., MemcpyGlobalToSpm);
    
    // 等待上一轮 DMA 完成
    if (k1 > 0) memcpy_wait();
    
    // ACE 计算 comp_buf
    for (int k_ace = 0; k_ace < K1; k_ace += ACE_K) {
        matmul(..., ldm_A[comp_buf], ldm_B[comp_buf], ...);
    }
    
    // 交换
    swap(dma_buf, comp_buf);
}

// 等待最后一轮 DMA
memcpy_wait();
```

#### 模式 2: 完全流水线 (推荐)
```cpp
int dma_buf = 0, comp_buf = 1;

// 首次加载
memcpy_async(ldm_A[dma_buf], ..., MemcpyGlobalToSpm);
memcpy_async(ldm_B[dma_buf], ..., MemcpyGlobalToSpm);
memcpy_wait();

for (int k1 = 0; k1 < K; k1 += K1) {
    // 预取下一块到 dma_buf
    if (k1 + K1 < K) {
        memcpy_async(ldm_A[1-dma_buf], ..., MemcpyGlobalToSpm);
        memcpy_async(ldm_B[1-dma_buf], ..., MemcpyGlobalToSpm);
    }
    
    // 计算当前块 comp_buf
    matmul_set_flushing_output(handle, (k1 + K1 >= K));
    for (int k_ace = 0; k_ace < K1; k_ace += ACE_K) {
        matmul_compute(handle, ldm_A[comp_buf], ...);
    }
    
    // 等待预取完成
    if (k1 + K1 < K) memcpy_wait();
    
    // 交换
    swap(dma_buf, comp_buf);
}
```

### 关键 API 使用模式

#### memcpy_async + memcpy_wait
```cpp
// 发起异步 DMA
memcpy_async(spm_ptr, global_ptr, size, 0, {0,0}, MemcpyGlobalToSpm, handle);
// ... 可以做其他工作 ...
memcpy_wait(handle);  // 等待完成
```

#### matmul 分层 API
```cpp
MatmulHandle handle;
matmul_init(handle, MatmulHalfToFloat);

// 加载权重 (B 矩阵)
matmul_load_weight(handle, B_ptr, MatmulK32, MatmulN32);
matmul_wait_loading_weight(handle);

// 加载输入并计算 (A 矩阵)
matmul_set_flushing_output(handle, false);  // 累加不写回
matmul_compute(handle, A_ptr, M, MatmulK32, stride);
matmul_wait_loading_input(handle);

// 写回结果
matmul_set_flushing_output(handle, true);
matmul_store(handle, C_ptr, M, MatmulN32);
matmul_wait(handle);
```

---

## 性能瓶颈诊断方法

### 1. 计算 vs 带宽瓶颈
**判断方法**:
- 计算 FLOPS = 2 × M × N × K
- 数据量 = (M×K + K×N) × sizeof(FP16) + M×N × sizeof(FP32)
- 计算强度 = FLOPS / 数据量 (FLOPS/byte)
- 如果计算强度 > 100: 计算瓶颈
- 如果计算强度 < 50: 带宽瓶颈

**对于 M=N=8192, K=7680**:
- FLOPS = 2 × 8192 × 8192 × 7680 = 1.03 TFLOPS
- 数据量 = (8192×7680 + 7680×8192) × 2 + 8192×8192 × 4 = 496 MB
- 计算强度 = 1.03e12 / 496e6 = 2076 FLOPS/byte
- **结论**: 强计算瓶颈, 优化重点是 ACE 利用率

### 2. ACE 利用率
**理想时间**:
- 每个 ACE 计算 M2×N2×K1 需要 M2×N2×K1 / (32×32×32) cycles
- 总时间 = 理想时间 / ACE 频率

**实际测量**:
- 如果实际时间 >> 理想时间: ACE 未被充分利用
- 原因可能是: DMA 等待、指令调度不佳、LDM 访问冲突

### 3. DMA 带宽利用率
**理想 DMA 时间**:
- 数据量 / HBM 带宽

**实际测量**:
- 如果 DMA 时间 >> 理想时间: DMA 带宽未充分利用
- 原因可能是: 非对齐访问、小碎片传输、DMA 队列未满

---

## 调试和验证策略

### 1. 正确性验证
- 小规模测试: M=N=K=128, 对比 CPU 参考实现
- 中等规模: M=N=K=1024, 检查数值精度
- 全规模: M=N=8192, K=7680, 使用预计算的参考数据

### 2. 性能分析
- 逐步添加优化: baseline → ACE → double buffering → tiling
- 每次只改一个变量, 测量增量收益
- 记录每轮的 speedup 和 attribution

### 3. 常见问题排查
- **数值错误**: 检查 ACE_K/N 对齐, flushing_output 设置
- **性能不达标**: 检查 DMA 是否异步, 双缓冲是否正确
- **编译错误**: 检查 LDM 容量, 对齐要求
- **运行时崩溃**: 检查数组越界, 指针偏移

---

## 总结

**核心优化路线**:
1. ACE 矩阵引擎 (必须)
2. 异步 DMA + 双缓冲 (必须)
3. 两级 Tiling (必须)
4. 数据广播 (推荐)
5. 数据重排 (可选)

**关键参数**:
- ACE_K = 32, ACE_N = 32
- M2 = 64, N2 = 32, K1 = 256
- ROWS = 4, COLS = 8
- NUM_BUFFERS = 2

**预期性能**:
- Baseline (SIMD): ~100 ms
- ACE + 双缓冲: ~20-30 ms
- 完整优化: ~15-20 ms (接近理论上限 12.58 ms)
