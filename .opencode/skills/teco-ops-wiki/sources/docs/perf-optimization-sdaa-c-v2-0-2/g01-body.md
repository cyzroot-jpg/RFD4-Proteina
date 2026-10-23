---
id: doc-perf-optimization-sdaa-c-v2-0-2-g01
title: "性能优化手册 SDAA C 篇 v2.0.2 — 第g01部分 (body)"
type: source-doc-part
parent_doc: doc-perf-optimization-sdaa-c-v2-0-2
product_version: "v2.0.2"
source_file: "external/文档/性能优化手册-SDAA C篇_v2.0.2.pdf"
raw_text: "sources/docs/raw/性能优化手册-SDAA C篇_v2.0.2.txt"
raw_line_range: "174-222"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [broadcast, math-functions, memory, perf-optimization, perf-sampling, programming-model, sdaa, teco-t1, tecocc, thread-group-sync]
---

# 性能优化手册 SDAA C 篇 v2.0.2（第g01部分）

## 1. 概述

本手册主要介绍基于 SDAA C 的性能调优方法，最大程度上利用 SDAA 异构并行计算平台的硬件资源实现最佳性能编程，主要结构如下：

| 名称 | 说明 |
|------|------|
| 性能度量 | 性能度量相关的指标和工具：<br>- 性能指标：指令周期和访存带宽，可以在一定程度上反应计算和访存相关操作的性能。<br>- SDAA C 支持的性能采样工具以及性能分析工具。 |
| 性能优化 | 具体的性能优化方法。<br>- 程序并行：从任务级、线程级（SPMD）到指令级（SIMD）不同粒度的并行化方法。<br>- 接口特性优化：介绍函数接口、数学函数等优化方法。<br>- 程序编译：介绍 SDAA C 支持的一些编译优化方法。 |

本手册主要面向具有一定编程经验且对程序性能有一定要求的用户。手册中讨论的内容主要基于 SDAA C 编程语言，因此您需要能阅读 C/C++ 代码并且能够使用 SDAA C 进行编程，建议您先阅读《SDAA C 编程指南》再阅读本手册以获得最佳的使用体验。

## 2. 最新动态

### 2.1 v2.0.2 更新记录

| 更新内容 | |
|------|------|
| 描述 | 文档 |
| 更新 DMA 数据搬运章节内容：<br>- 更新 SPE ID 相关章节 memcpy_async 接口形式。 | SPE ID 相关 |
| 更新 DMA 数据搬运章节内容：<br>- 更新非阻塞型 DMA 数据搬运 memcpy_async 接口形式。 | 非阻塞型 DMA 数据搬运 |
| 更新 Broadcast 数据搬运章节内容：<br>- 更新 SPE ID 相关章节 broadcast 接口形式。 | SPE ID 相关 |
| 更新 Broadcast 数据搬运章节内容：<br>- 更新非阻塞型 Broadcast 数据搬运章节 broadcast_async 接口形式。 | 非阻塞型 Broadcast 数据搬运 |
