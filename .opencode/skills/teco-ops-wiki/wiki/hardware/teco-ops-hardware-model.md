---
id: hw-teco-ops-hardware-model
title: "Teco-Ops 硬件与编程模型速览（SPA/SPE/SPMD）"
type: hardware
architectures: [sdaa, teco-t1]
tags: [spa, spe, su, sreg, vpu, vreg, fu, spm, global-memory, spmd, heterogeneous-computing]
confidence: verified
related: [technique-teco-ops-interface-ual-layering, kernel-teco-ops-flatten-rays]
sources: [doc-teco-ops-docs, doc-teco-ops-docs-p07, doc-sdaa-c-programming-guide-v3-1-0, doc-sdaa-c-getting-started-v1-1-0]
aliases: ["异构计算", "SPMD", "SU", "SREG", "VPU", "VREG", "FU", "SPM"]
---

# Teco-Ops 硬件与编程模型速览（SPA/SPE/SPMD）

面向刚接触算子开发的读者，总结 Teco-Ops 文档（`doc-teco-ops-docs-p07`）给出的硬件与编程模型入门知识；权威、完整的接口规范以 `doc-sdaa-c-programming-guide-v3-1-0` 为准。

## 异构计算模型

- Host 端（CPU）：负责 Device 端内存资源的申请/释放，控制 Device 端任务调度。
- Device 端（太初 AI 加速卡）：由计算核心阵列 SPA（Synergistic Processor Element Array）+ Global 高带宽存储器构成，负责大规模数据运算。
- 一个 SPA 类似于 GPU 的一张卡（可用 `teco-smi` 查看 SPA 数量），由若干计算核心 SPE（Synergistic Processor Element）构成。

## SPE 内部部件

| 部件 | 全称 | 作用 | 只能访问 |
|---|---|---|---|
| SU | Scalar Unit | 标量运算（算术/逻辑） | 标量寄存器 SREG |
| SREG | Scalar Register | 存储标量数据 | SPM / Global |
| VPU | Vector Processing Unit | 向量运算（存储/算术/类型转换/比较选择） | 向量寄存器 VREG |
| VREG | Vector Register | 存储向量数据，支持并行读写 | SPM / Global |
| FU | Function Unit | 矩阵乘等计算 | 仅 SPM |
| SPM | 片上存储 | 堆/栈/local 三段，带宽高但容量小 | FU/SREG/VREG/Global |

SPM 进一步细分为堆空间、栈空间（可选 `--stack-on-global` 切换到 Global）、local 空间（`__local__` 关键字声明），三者都可与 SPA 内 Global 存储空间交换数据。

## SPMD 编程范式

SDAA C 遵循 SPMD（Single Program Multiple Data）：同一 SPA 内所有 SPE 运行同一份程序，通过 `threadIdx`（当前 SPE 编号）和 `threadDim`（SPE 总数）为每个 SPE 分配子任务。典型数据切分模式（当计算量不能整除 SPE 数时）：

```
cal_time = SIZE / threadDim        // 每个 SPE 至少承担的次数
for i in [0, cal_time): g_data[i * threadDim + threadIdx]++

remain_time = SIZE % threadDim     // 余数部分只分配给前 remain_time 个 SPE
if (threadIdx + 1) <= remain_time: g_data[cal_time * threadDim + threadIdx]++
```

Kernel 函数以 `__global__` 修饰，Host 端通过 `<<<...>>>` 语法发起调用。

## 存储空间与数据传输路径

- 主机端内存：`malloc`/`free`。
- 设备端 Global 存储空间：`__device__` 声明，或 `sdaaMalloc`/`sdaaFree` 动态申请；SPA 内所有 SPE 共享，容量大但带宽低于 SPM。
- SPM（片上）：SPE 私有，堆用 `malloc`/`free`（`get_heap_size` 查询容量），栈自动管理（`get_stack_size` 查询），local 用 `__local__` 声明（`get_local_size` 查询）。
- 数据传输路径：Host↔Global 用 `sdaaMemcpy`；Global↔Global（同 SPA 内）用 `memcpy`；不同 SPE 之间的 SPM↔SPM 用 RMA 接口；同一 SPE 内 SPM 内部传输用 `memcpy`。

## 与 flatten_rays 示例的对应关系

`kernel-teco-ops-flatten-rays` 中的 tiling 策略直接建立在本页的 SPMD 模型和 `threadIdx`/`threadDim` 切分公式之上：将 N 条光线均分给各 SPE，每个 SPE 处理 `[start, end)` 区间。
