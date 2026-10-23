---
id: doc-perf-optimization-operator-v1-1-0-g01
title: "性能优化手册 算子篇 v1.1.0 — 第g01部分 (body)"
type: source-doc-part
parent_doc: doc-perf-optimization-operator-v1-1-0
product_version: "v1.1.0"
source_file: "external/文档/性能优化手册-算子篇_v1.1.0.pdf"
raw_text: "sources/docs/raw/性能优化手册-算子篇_v1.1.0.txt"
raw_line_range: "122-162"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [broadcast, matmul, perf-optimization, runtime, sdaa, teco-t1]
---

# 性能优化手册 算子篇 v1.1.0（第g01部分）

## 1. 概述

本文主要介绍如何开发高效的并行算法，或对已有算法进行性能优化，并结合太初 AI 加速卡提供了实际的性能优化案例。整体结构如下：

| 名称 | 说明 |
|------|------|
| 性能度量 | 介绍了两大性能指标及其计算办法：浮点性能 FLOPS 和 IO 带宽。 |
| 性能优化 | 介绍了计算相关优化办法及其示例：向量指令、指令流水线、矩阵乘法加速单元。<br>介绍了访存相关优化办法及其示例：双缓冲设计、广播机制。 |
| 优化实战 | 以求解下三角线性方程组为例，从串行实现入手，逐步融合多种优化手段，综合演示性能优化的思路与方法。 |

## 2. 最新动态

### 2.1 v1.1.0 更新记录

| 更新内容 |
|----------|
| 根据加速卡频率变动，更新各章节性能数据。 |
| 按需补充各章节伪代码与代码的注释。 |
