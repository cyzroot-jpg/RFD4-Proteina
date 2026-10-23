---
id: pattern-teco-ops-precision-pitfalls
title: "Teco-Ops 算子精度问题三类模式"
type: pattern
architectures: [sdaa, teco-t1]
tags: [precision, half, overflow, underflow, simd, debug]
confidence: verified
symptoms: [precision-loss, integer-overflow, value-underflow-to-zero]
candidate_techniques: [technique-teco-ops-interface-ual-layering]
related: [hw-teco-ops-hardware-model]
sources: [doc-teco-ops-docs-p03]
---

# Teco-Ops 算子精度问题三类模式

来自 Teco-Ops 调试手册（`doc-teco-ops-docs-p03`）总结的三类高频精度 bug，都属于「结果偏差但不 crash」的隐蔽问题，建议在算子正确性验证阶段主动排查。

## 模式一：half 中间变量截断

**信号**：dtype 为 `half` 的算子，结果精度不足但不报错。

**根因**：计算中间变量仍用 `half` 存储，多次运算反复截断尾数。

**修复**：dtype 为 `half` 时，中间标量/向量一律先转 `float` 再参与运算。

```c
// 错误：float 与 half 相乘结果存回 half
half tmp = alpha * exp(a[i]);
// 正确：中间结果保持 float
float tmp = alpha * exp((float)a[i]);
```

## 模式二：有符号整型减法下溢

**信号**：`maximum`/`minimum` 等基于「减法后与 0 比较」实现的算子，在极值（如 `INT_MIN`）输入下结果错误。

**根因**：`INT_MIN`（-2147483648）减去正数发生下溢，二进制表示变为正数，比较结果反转。

**修复**：涉及比较语义的算子避免用算术运算模拟比较，改用直接比较指令（如 SIMD 的 `vcmpltw` + `vseleqw` 组合），而非「相减后 `vsellew` 选大于 0 部分」。

```c
// 错误：算术减法模拟比较，遇 INT_MIN 溢出
v_temp = v_x - v_y; v_z = simd_vsellew(v_temp, v_y, v_x);
// 正确：直接比较，不经过减法
v_less = simd_vcmpltw(v_x, v_y); v_z = simd_vseleqw(v_less, v_x, v_y);
```

## 模式三：超越函数结果下溢为 0

**信号**：链式调用超越函数（如 `tanh`）后结果异常趋近 0。

**根因**：超越函数本身精度不足，中间结果参与后续运算被进一步放大误差。

**修复**：视场景改用高精度实现，或将计算过程提升到 `double`。

```c
// 错误：float 精度下 tanh 链式运算易下溢
y = tanh(x); y += 1;
// 正确：提升到 double 计算
y = 1 + tanh((double)x);
```

## 排查建议

1. 先用 `printf`（`export SDAA_SYNC_PRINT=1` 保证按 SPE 编号顺序打印）定位数值异常发生的具体 SPE 与位置。
2. 若怀疑越界/非法访问导致的崩溃而非纯精度偏差，改用 `assert`/`abort` 配合 `SDAA_ENABLE_COREDUMP_ON_EXCEPTION` 产生 Core Dump。
3. 三类模式均可在 `cpuCompute()` baseline 实现与 `compute()` 设备实现之间做逐元素 diff 定位，而不需要先上 profiler。
