# Kernel 优化教训：先调研，后优化

## 问题描述

在 LayerNorm kernel 优化案例中，出现了"本末倒置"的行为：
- **目标**：生成精度正确的算子 + 用最大努力优化出最优算子
- **实际行为**：快速生成 baseline → 3 轮迭代优化 → 结束任务
- **结果**：得到了"能跑的算子"，但不是"最优算子"

## 具体失误

### 1. 调研不充分
- ❌ 没有系统阅读 teco-ops-wiki 的所有相关页面
- ❌ 没有查看 tecocustom、sdcops 等生产实现
- ❌ 没有研究高级优化技巧（`memcpy_async`、P0/P1 双发射、ACE 等）
- ❌ 看到 `memcpy` 就用了，没想"有没有异步版本"

### 2. 优化太浅
- ❌ 只尝试了"常识性"优化（LDM 缓存、FP16、UNROLL）
- ❌ 没有探索 SDAA 特有的深度优化
- ❌ 3 轮迭代就停了，没有继续深挖

### 3. 行为模式错误
- ❌ 像完成"任务"一样执行 skill 流程
- ❌ 而不是像"研究者"一样深入探索
- ❌ 看到 `skill` 调用就快速执行，没有思考用户真正想要什么

## 遗漏的关键优化

### 1. 异步 DMA（`memcpy_async`）
**teco-ops-wiki 里明确记录**：
```
| Global ↔ SPM | `memcpy` / `memcpy_async` | 非阻塞仅此方向 |
```

**正确用法**（来自 `wiki/examples/sdaa-programming-guide-examples.md`）：
```cpp
memcpy_async(spm_input,  input + offset, size, 0, {0,0}, MemcpyGlobalToSpm);
memcpy_async(spm_weight, weight, size, 0, {0,0}, MemcpyGlobalToSpm);
memcpy_wait();  // 等待所有异步 DMA 完成
```

**我的错误**：
- 只用了同步的 `memcpy`
- 尝试了 double buffering 但用的是同步 API，所以没有效果
- 如果用了 `memcpy_async`，DMA 和计算可以真正重叠

### 2. P0/P1 双发射优化
**teco-ops-wiki 里有专门页面**：`wiki/techniques/p0-p1-overlap.md`
- T1 支持异步发射和双发射
- 计算指令走 P0，访存/DMA/RMA/ACE 走 P1
- 应该将独立 P1 工作靠近 P0 计算

**我的错误**：没有探索手动安排指令重叠

### 3. ACE 矩阵引擎
**teco-ops-wiki 里有专门页面**：`wiki/hardware/ace.md`
- ACE 是矩阵/异步加速路径
- 运行在 1.25 GHz（SPE 频率的一半）
- 如果 LayerNorm 可以映射到矩阵运算，可以用 ACE 加速

**我的错误**：完全没有考虑 ACE

### 4. 生产实现的优化策略
**tecocustom 的实现**（`teco-ops-wiki/artifacts/repos/tecocustom/dnn-custom-op-fused-layer-norm/`）：
- ✅ Double buffering（真正的异步 DMA）
- ✅ Kahan 求和（数值精度）
- ✅ 多 SPE 协作（复杂 workload 分配）
- ✅ 针对特定 shape 的特殊路径

**我的错误**：没有查看生产实现，自己从零摸索

## 正确的优化流程

### Phase 1: 充分调研（应该花 2-3 天甚至更长）

**必读文档**：
1. teco-ops-wiki 的所有硬件页面：
   - `wiki/hardware/*.md`（DMA、LDM、RMA、ACE、P0/P1 等）
2. teco-ops-wiki 的所有 API 页面：
   - `wiki/techniques/*.md`（SIMD、async、dual-issue 等）
3. teco-ops-wiki 的所有示例页面：
   - `wiki/examples/*.md`（完整 kernel 示例）
4. 生产实现代码：
   - `teco-ops-wiki/artifacts/repos/tecocustom/`
   - `teco-ops-wiki/artifacts/repos/sdcops/`
   - `teco-ops-wiki/artifacts/repos/tecoal/`

**关键问题**：
- 有哪些异步 API？（DMA、transpose、matmul 等）
- 有哪些高级优化技巧？（P0/P1、double buffering、pipeline 等）
- 生产实现是怎么做的？（学习最佳实践）
- 性能上限是多少？（理论分析）

### Phase 2: 设计优化策略

**基于调研**：
- 总结所有可能的优化方向
- 优先级排序：哪些优化最有潜力
- 预估性能上限
- 制定详细的优化计划

**不要**：
- 基于"常识"猜测优化方向
- 只看基础 API，忽略高级特性
- 跳过调研直接开始优化

### Phase 3: 执行优化

**迭代次数**：
- 可能需要 10+ 轮迭代，不是 3 轮
- 每轮尝试更深入的优化
- 不要急于结束

**每轮优化**：
- 尝试 1-2 个深度优化，不是 4 个浅层优化
- 记录成功和失败的原因
- 基于上一轮的结果调整策略

## 检查清单

在开始优化之前，确认：

- [ ] 已阅读 teco-ops-wiki 的所有硬件页面（`wiki/hardware/*.md`）
- [ ] 已阅读 teco-ops-wiki 的所有 API 页面（`wiki/techniques/*.md`）
- [ ] 已查看至少 2 个生产实现（tecocustom、sdcops、tecoal）
- [ ] 已了解所有异步 API（`memcpy_async`、`transpose_async` 等）
- [ ] 已了解 P0/P1 双发射优化
- [ ] 已了解 ACE 矩阵引擎
- [ ] 已分析性能上限（理论带宽、计算峰值）
- [ ] 已制定详细的优化计划（10+ 轮迭代）

## 核心原则

**用户的目标是"最优算子"，不是"完成任务"**

- ❌ 快速执行 skill 流程 → 3 轮迭代 → 结束
- ✅ 充分调研 → 深入优化 → 逼近性能上限

**先调研，后优化。不要本末倒置。**
