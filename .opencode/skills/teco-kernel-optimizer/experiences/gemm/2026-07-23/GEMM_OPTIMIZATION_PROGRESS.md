# GEMM 优化迭代总结

## 任务目标
使用 `teco-kernel-optimizer` skill 对 `swdnn_test_ops` 中的 GEMM 算子进行 10 次迭代优化。

## 已完成工作

### 1. 环境检查与预检 ✅
- SDAA 设备: `/dev/tcaicard0`
- tecocc: clang version 11.0.0
- Torch-SDAA: 3.2.0
- 目标 kernel: `src/gemm/gemm_fp16_pvc_fp32_32x_demo.swcu`
- 测试函数: `gemm_fp16_pvc_fp32_32x_test_kernel`

### 2. 充分调研阶段 ✅
按照 `LESSONS_LEARNED.md` 的要求，完成了系统性调研：

#### Wiki 查询（5+ 次不同角度）
1. GEMM FP16 FP32 优化技术
2. ACE 矩阵引擎与双缓冲
3. 异步 DMA 与流水线重叠
4. RMA 通信与广播
5. LDM/SPM 内存优化

#### 生产实现分析
- **Teco-AL GEMM** (`teco-al/custom_ops/gemm/gemm.scpp`): batch GEMM 实现
- **Teco-AL 异步矩阵乘示例** (`matmul_async_128_64_32.scpp`): 完整异步流程
- **Teco-AL GEMM 文档** (`kernel-teco-al-gemm`): 分块+广播+重排+双缓冲路线

#### 提取的关键知识
- ACE 原生大小: K=32, N=32
- Handle-based API: `matmul_init/load_weight/compute/store`
- 异步 DMA: `memcpy_async` + `memcpy_wait`
- 双缓冲: 交错 DMA 加载与计算
- 累加控制: `matmul_set_flushing_output(handle, is_last_k)`
- 数据广播: `rt_dma_ibcast/row_ibcast/col_ibcast`

### 3. 研究文档 ✅
创建了两份完整的研究文档：

#### OPTIMIZATION_RESEARCH.md
- 算子规格与性能上限分析
- 10 种优化方法（按优先级 P1-P3 排序）
- Tile 大小选择指南
- LDM 容量分配策略
- 流水线设计模式
- 关键约束检查清单

#### PRODUCTION_ANALYSIS.md
- 3 个生产实现的详细分析
- 提取的最佳实践
- API 使用模式
- 性能瓶颈诊断方法
- 调试和验证策略

### 4. 迭代优化运行初始化 ✅
- 运行目录: `run_20260723_153212/`
- 配置: 10 次迭代，4 个分支
- 目标 kernel: `gemm_fp16_pvc_fp32_32x_demo.swcu`

### 5. 迭代 1 尝试 ⚠️
创建了 4 个分支变体，均使用 ACE handle-based API：
- b1: 正确的 ACE Handle API
- b2: 优化的 Tile 大小
- b3: 异步 DMA 流水线
- b4: 保守版本（安全回退）

**结果**: 所有分支运行成功（~371 ms），但**正确性检查失败**。

## 当前阻塞问题

### Baseline 正确性问题
所有尝试的 kernel 实现都无法产生与参考数据匹配的输出值：
- 计算值与参考值完全不匹配
- 出现负值（不应该出现在正数矩阵乘中）
- 数值差异极大（diff > 70-140）

### 已尝试的方法
1. ❌ 简单 `matmul()` 函数 - 累加不正确
2. ❌ Handle-based API（多种变体）- ACE 启动失败或结果错误
3. ❌ 向量指令实现 - 正确但太慢（超时）
4. ❌ 简化版本（小 tile）- 覆盖范围不完整

### 可能的原因
1. ACE API 参数配置错误（stride, flushing, load/compute 顺序）
2. 数据布局或内存对齐问题
3. LDM 容量或分配问题
4. 参考数据生成方式与 kernel 不匹配

## 已完成的任务清单

- [x] 环境检查与预检
- [x] 充分调研（wiki 查询、生产实现分析）
- [x] 创建研究文档（OPTIMIZATION_RESEARCH.md, PRODUCTION_ANALYSIS.md）
- [x] 初始化优化运行
- [ ] 建立正确的 baseline（**阻塞中**）
- [ ] 完成 10 次优化迭代
- [ ] 生成最终优化报告

## 建议的下一步

### 选项 1: 继续调试 ACE API（推荐）
- 查找更多 ACE API 的使用示例
- 与 Teco 技术支持确认正确的 API 用法
- 逐步验证：先验证单个 tile 的计算正确性
- **预计时间**: 2-4 小时

### 选项 2: 使用不同的计算路径
- 尝试使用 `sdaa_matmul.h` 中的其他 API
- 使用 TecoDNN 或 TecoBLAS 库函数
- 实现纯向量指令版本（牺牲性能换取正确性）
- **预计时间**: 1-2 小时

### 选项 3: 跳过正确性，继续优化（不推荐）
- 假设 kernel 逻辑正确，继续添加优化
- 风险: 优化一个错误的 kernel 没有意义
- **预计时间**: 2-3 小时完成 10 次迭代

### 选项 4: 请求用户协助
- 提供已知正确的 baseline kernel
- 确认参考数据的生成方式
- 确认 ACE API 的正确用法
- **预计时间**: 取决于响应速度

## 关键发现

### 性能特征
- 当前 kernel 运行时间: ~371 ms
- 理论计算时间: ~12.58 ms（计算受限）
- 理论带宽时间: ~0.41 ms
- **结论**: 当前 kernel 距离理论上限有 30x 差距，有很大优化空间

### 优化机会
1. **ACE 利用率**: 当前可能未充分利用 ACE 矩阵引擎
2. **DMA 重叠**: 未实现异步 DMA 和双缓冲
3. **数据复用**: 未使用广播减少 Global 内存访问
4. **Tile 优化**: 可以调整 tile 大小提高 LDM 利用率

### 已学习的 SDAA/TECO 知识
- SPA/SPE 架构: 32 SPEs (4×8 网格)
- ACE 矩阵引擎: 专用矩阵乘加速单元
- LDM/SPM: 片上高速存储，容量有限
- DMA: Global ↔ SPM 数据传输
- RMA: SPE 间 SPM 数据交换
- 双缓冲: 隐藏 DMA 延迟的关键技术

## 运行目录结构

```
run_20260723_153212/
├── state.json                    # 优化状态
├── env.json                      # 环境信息
├── tree/                         # 工作副本
│   ├── src/gemm/                 # GEMM kernel
│   ├── ref_data/                 # 参考数据
│   └── build/                    # 构建目录
├── baseline/                     # Baseline 测量
├── iterv1/                       # 迭代 1
│   ├── wiki_queries.json        # Wiki 查询结果
│   ├── analysis.md              # 迭代分析
│   ├── methods.json             # 方法列表
│   └── branches/b{1..4}/        # 4 个分支
└── ref_data/                     # 参考数据副本
```

## 参考资源

### 已使用的文档
- `OPTIMIZATION_RESEARCH.md` - 优化方法全面调研
- `PRODUCTION_ANALYSIS.md` - 生产实现分析
- `LESSONS_LEARNED.md` - 先调研后优化的教训

### Wiki 页面
- `kernel-teco-al-gemm` - Teco-AL GEMM 完整优化路线
- `doc-tecolibrt-user-manual-v1-2-0-p02` - ACE matmul API
- `doc-tecolibrt-user-manual-v1-2-0-p06` - DMA broadcast API
- `doc-perf-optimization-operator-v1-1-0` - 性能优化手册

### 生产实现示例
- `teco-al/custom_ops/gemm/gemm.scpp`
- `teco-al/SDAAC_examples/matmul/matmul_async_128_64_32.scpp`
- `teco-al/SDAAC_examples/matmul/matmul_half.scpp`

## 总结

已完成充分的调研和准备工作，创建了完整的研究文档，初始化了优化运行。但在迭代 1 遇到 baseline 正确性问题，所有尝试的 ACE API 实现都无法产生正确的结果。

**建议**: 优先解决 ACE API 的正确性问题，可以选择继续调试、使用不同的计算路径、或请求用户协助。一旦建立正确的 baseline，后续的 10 次优化迭代可以快速推进。
