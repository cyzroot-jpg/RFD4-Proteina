---
id: doc-sdaa-c-programming-guide-v3-1-0
title: "SDAA C 编程指南 v3.1.0"
type: source-doc
source_category: official-doc
product_version: "v3.1.0"
published_at: "2026-01-16"
created_at: "2026-03-26"
captured_at: "2026-06-23"
author: "docs.tecorigin.net"
doc_kind: programming-guide
pdf_pages: 671
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
architectures: [sdaa, teco-t1]
tags: [spa, spe, spm, dma, rma, ace, simd, matmul, broadcast, atomic, transpose, perf-sampling, tecocc, sdaa-c]
languages: [sdaa-c, sdaa-cpp, tecocc, zh-cn]
confidence: verified
---

# SDAA C 编程指南 v3.1.0

> SDAA C 异构编程模型的权威指南：编程模型、语言规范、全部设备端函数接口（线程组/DMA/RMA/Broadcast/原子/matmul/transpose/SIMD/性能采样）、数学与高层接口、编译调试、性能调优、示例与算子开发。

这是《SDAA C 编程指南 v3.1.0》的**索引页**。完整、无损的结构化正文按章节切分在下方 `part` 子页中（共 27 部分），每个 part 保留原文全部 API/参数表/约束/代码示例/性能数据。原始 `pdftotext` 抽取的全文存于 `raw_text`，可逐行追溯。

## 文档元信息

- 标题：SDAA C 编程指南
- 版本：v3.1.0
- 页数：671
- PDF 创建时间：2026-03-26
- 原始 PDF：`external/文档/SDAA C编程指南_v3.1.0.pdf`
- 原始抽取全文：`sources/docs/raw/SDAA C编程指南_v3.1.0.txt`（pdftotext -layout，完整无删减）

## 完整内容分卷（part 子页）

| Part | 覆盖章节 | 原文行范围 | 页面 |
|------|---------|-----------|------|
| p01 | ch1-2-3-4-5-6-7 | 849-3858 | `doc-sdaa-c-programming-guide-v3-1-0-p01` |
| p02a | ch7 | 3859-5311 | `doc-sdaa-c-programming-guide-v3-1-0-p02a` |
| p02b | ch7 | 5312-6148 | `doc-sdaa-c-programming-guide-v3-1-0-p02b` |
| p02c | ch7 | 6149-7295 | `doc-sdaa-c-programming-guide-v3-1-0-p02c` |
| p03a | ch7 | 7296-8666 | `doc-sdaa-c-programming-guide-v3-1-0-p03a` |
| p03b | ch7 | 8667-9924 | `doc-sdaa-c-programming-guide-v3-1-0-p03b` |
| p03c | ch7 | 9925-10895 | `doc-sdaa-c-programming-guide-v3-1-0-p03c` |
| p04 | ch7 | 10896-13967 | `doc-sdaa-c-programming-guide-v3-1-0-p04` |
| p05a | ch7 | 13968-15724 | `doc-sdaa-c-programming-guide-v3-1-0-p05a` |
| p05b | ch7 | 15725-16589 | `doc-sdaa-c-programming-guide-v3-1-0-p05b` |
| p05c | ch7 | 16590-17319 | `doc-sdaa-c-programming-guide-v3-1-0-p05c` |
| p06 | ch7-8 | 17320-20358 | `doc-sdaa-c-programming-guide-v3-1-0-p06` |
| p07 | ch8 | 20359-23428 | `doc-sdaa-c-programming-guide-v3-1-0-p07` |
| p08 | ch8-9-10-11-12-13 | 23429-26560 | `doc-sdaa-c-programming-guide-v3-1-0-p08` |
| p14 | ch17 | 43300-43743 | `doc-sdaa-c-programming-guide-v3-1-0-p14` |
| pg01 | body | 833-848 | `doc-sdaa-c-programming-guide-v3-1-0-g01` |
| pg02 | ch13 | 26561-28161 | `doc-sdaa-c-programming-guide-v3-1-0-g02` |
| pg03 | ch13 | 28162-29762 | `doc-sdaa-c-programming-guide-v3-1-0-g03` |
| pg04 | ch13 | 29763-31363 | `doc-sdaa-c-programming-guide-v3-1-0-g04` |
| pg05 | ch13-15 | 31364-32827 | `doc-sdaa-c-programming-guide-v3-1-0-g05` |
| pg06 | ch15 | 32828-34428 | `doc-sdaa-c-programming-guide-v3-1-0-g06` |
| pg07 | ch15-16 | 34429-35993 | `doc-sdaa-c-programming-guide-v3-1-0-g07` |
| pg08 | ch16 | 35994-37594 | `doc-sdaa-c-programming-guide-v3-1-0-g08` |
| pg09 | ch16 | 37595-39195 | `doc-sdaa-c-programming-guide-v3-1-0-g09` |
| pg10 | ch16 | 39196-40796 | `doc-sdaa-c-programming-guide-v3-1-0-g10` |
| pg11 | ch16 | 40797-42397 | `doc-sdaa-c-programming-guide-v3-1-0-g11` |
| pg12 | ch16-17 | 42398-43299 | `doc-sdaa-c-programming-guide-v3-1-0-g12` |

## 章节目录（原文）

  - 1.1 图说SDAA C（p.1）
  - 1.2 什么是SDAA C？（p.1）
  - 1.3 产品优势（p.3）
  - 1.4 工作流程（p.4）
  - 1.5 设备端代码使用限制（p.4）
  - 2.1 v3.1.0更新记录（p.8）
  - 2.2 v3.0.1更新记录（p.8）
  - 2.3 v3.0.0更新记录（p.8）
  - 2.4 v2.3.1更新记录（p.8）
  - 2.5 v2.2.1更新记录（p.8）
  - 2.6 v2.1.1更新记录（p.10）
  - 2.7 v2.1.0更新记录（p.10）
  - 2.8 v2.0.2更新记录（p.11）
  - 2.9 v2.0.1更新记录（p.13）
  - 2.10 v2.0.0更新记录（p.13）
  - 2.11 v1.16.0更新记录（p.14）
  - 2.12 v1.15.0更新记录（p.14）
  - 2.13 v1.14.0更新记录（p.15）
  - 2.14 v1.13.0更新记录（p.18）
  - 2.15 v1.12.0更新记录（p.19）
  - 2.16 v1.11.0更新记录（p.19）
  - 2.17 v1.10.0更新记录（p.20）
  - 2.18 v1.9.0更新记录（p.20）
  - 3.1 概述（p.21）
  - 3.2 步骤一：安装软件（p.21）
  - 3.3 步骤二：编写程序（p.21）
  - 3.4 步骤三：编译程序（p.22）
  - 3.5 步骤四：运行程序（p.22）
  - 4.1 概述（p.24）
  - 4.2 SPMD（p.24）
  - 4.3 Kernel函数（p.27）
  - 4.4 存储空间（p.27）
  - 4.5 硬件架构（p.30）
  - 4.6 数据传输（p.31）
  - 4.7 SDAARuntime接口（p.33）
  - 5.1 语法（p.34）
  - 5.2 关键字（p.34）
  - 5.3 数据类型（p.38）
  - 5.4 头文件（p.39）
  - 5.5 命名空间（p.39）
  - 5.6 常用SDAARuntime接口（p.40）
  - 6.1 SDAA_SYNC_PRINT（p.42）
  - 7.1 概述（p.43）
  - 7.2 线程组（p.43）
  - 7.3 计算核心SPE同步（p.50）
  - 7.4 SPM内存分配和释放（p.53）
  - 7.5 内存初始化（p.55）
  - 7.6 数据搬运（p.57）
  - 7.7 原子操作（p.128）
  - 7.8 矩阵乘（p.138）
  - 7.9 转置操作（p.177）
  - 7.10 向量操作（p.191）
  - 7.11 性能采样（p.255）
  - 7.12 设备信息查询（p.262）
  - 7.13 程序调试（p.264）
  - 8.1 概述（p.270）
  - 8.2 单精度标量接口（p.270）
  - 8.3 双精度标量接口（p.296）
  - 8.4 向量接口（p.323）
  - 9.1 概述（p.355）
  - 9.2 数学函数（p.355）
  - 9.3 激活函数（p.368）
  - 9.4 规约函数（p.371）
  - 10.1 命令行选项（p.373）
  - 10.2 编译流程（p.374）
  - 10.3 编译方式（p.376）
  - 10.4 编译示例（p.378）
  - 11.1 概述（p.383）
  - 11.2 打印运行时日志（p.383）
  - 11.3 TecoGDB调试工具（p.384）
  - 11.4 终止设备端程序（p.384）
  - 11.5 断言（p.385）
  - 12.1 TecoGDB调试工具（p.387）
  - 12.2 sdaacfilt符号解码工具（p.387）
  - 13.1 概述（p.389）
  - 13.2 性能度量（p.389）
  - 13.3 性能优化（p.392）
  - 15.1 向量运算（p.485）
  - 15.2 使用SPMD完成矩阵乘（p.493）
  - 15.3 使用SUMMA算法实现矩阵乘（p.503）
  - 15.4 使用CAS完成自定义原子操作（p.519）
  - 16.1 概述（p.527）
  - 16.2 算子开发实战（p.527）
  - 16.3 算子性能调优（p.549）
  - 16.4 算子调优实战（p.571）
  - 17.1 如何使用CMake构建？（p.637）
  - 17.3 CUDA程序迁移（p.644）

