---
id: doc-teco-al-docs-p13
title: "Teco-AL 项目文档集 — 第p13部分 (doc/op_docs/masked_fill.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/masked_fill.md"
raw_text: "sources/docs/raw-teco-al/op_docs/masked_fill.txt"
raw_line_range: "1-68"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, masked-fill, mask, broadcast]
---

# Teco-AL 项目文档集（第p13部分：MaskedFill 设计文档）

# tecoalMaskedFill设计文档

## 计算原理

提供掩码填充功能。当mask值为TRUE时，对应位置的input将用value填充，并返回输出out。

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalMaskedFill(
    tecoalHandle_t                         handle,
    const float                            value,
    const tecoalTensorDescriptor_t         inputDesc,
    const void                             *input,
    const tecoalTensorDescriptor_t         maskDesc,
    const void                             *mask,
    const tecoalTensorDescriptor_t         outputDesc,
    void                                   *output,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|value| 输入 | 主机端 | 填充值。 |
|inputDesc| 输入 | 主机端 | 数据input的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|input| 输入 | 设备端 | 指向inputDesc描述的数据指针。 |
|maskDesc| 输入 | 主机端 | 数据mask的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|mask| 输入 | 设备端 | 指向maskDesc描述的数据指针。 |
|outputDesc| 输入 | 主机端 | 数据output的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|output| 输出 | 设备端 | 指向outputDesc描述的数据指针。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelMaskedFillFT32|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。

注意：mask的shape必须支持对input的单向广播。


|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| inputDesc | float32 | TensorND | 任意存储格式 |
| maskDesc | uint8 | TensorND | 任意存储格式 |
| outputDesc | float32 | TensorND | 任意存储格式 |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
