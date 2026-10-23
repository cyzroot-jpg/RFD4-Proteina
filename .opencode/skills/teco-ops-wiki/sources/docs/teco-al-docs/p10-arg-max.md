---
id: doc-teco-al-docs-p10
title: "Teco-AL 项目文档集 — 第p10部分 (doc/op_docs/arg_max.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/arg_max.md"
raw_text: "sources/docs/raw-teco-al/op_docs/arg_max.txt"
raw_line_range: "1-59"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, arg-max, reduction]
---

# Teco-AL 项目文档集（第p10部分：Argmax 设计文档）

# tecoalArgmax设计文档

## 计算原理

沿给定维度，寻找张量的最大值坐标。

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalArgmax(
    tecoalHandle_t                         handle,
    const int                              axis,
    const tecoalTensorDescriptor_t         xDesc,
    const void                             *x,
    const tecoalTensorDescriptor_t         yDesc,
    void                                   *y,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|axis| 输入 | 主机端 | 指定寻找最大值坐标的轴。 |
|xDesc| 输入 | 主机端 | 数据x的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|x| 输入 | 设备端 | 指向xDesc描述的数据指针。 |
|yDesc| 输入 | 主机端 | 数据y的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|y| 输出 | 设备端 | 最大值索引结果的指针。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelArgmaxFT16|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| xDesc | float16 | TensorND | 任意存储格式 |
| yDesc | int64 | TensorND | 任意存储格式 |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
