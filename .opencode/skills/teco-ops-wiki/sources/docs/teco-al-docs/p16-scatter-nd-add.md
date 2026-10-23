---
id: doc-teco-al-docs-p16
title: "Teco-AL 项目文档集 — 第p16部分 (doc/op_docs/scatter_nd_add.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/scatter_nd_add.md"
raw_text: "sources/docs/raw-teco-al/op_docs/scatter_nd_add.txt"
raw_line_range: "1-80"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, scatter-nd-add, scatter, sparse]
---

# Teco-AL 项目文档集（第p16部分：ScatterNdAdd 设计文档）

# tecoalScatterNdAdd设计文档

## 计算原理

通过对张量中的单个值或切片应用稀疏加法，从而得到输出的张量，具体如下：

- 根据index，得到对应的updates切片。

- 根据index的最后一维，得到x切片。

- 两者相加得到最终的输出张量。

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalScatterNdAdd(
    tecoalHandle_t                         handle,
    const tecoalTensorDescriptor_t         xDesc,
    const void                             *x,
    const tecoalTensorDescriptor_t         indexDesc,
    const void                             *index,
    const tecoalTensorDescriptor_t         updatesDesc,
    const void                             *updates,
    const tecoalTensorDescriptor_t         outDesc,
    void                                   *out,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
| xDesc       | 输入      | 主机端        | 数据x的张量描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。       |
| x           | 输入      | 设备端        | 指向x描述的数据指针。                                    |
| indexDesc   | 输入      | 主机端        | 数据index的张量描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。   |
| index       | 输入      | 设备端        | 指向index描述的数据指针。                                |
| updatesDesc | 输入      | 主机端        | 数据updates的张量描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
| updates     | 输入      | 设备端        | 指向updates描述的数据指针。                              |
| outDesc     | 输入      | 主机端        | 数据out的张量描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。     |
| out         | 输出      | 设备端        | 指向out描述的数据指针。                                  |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelScatterNdAddIndex32|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。

- index的维度必须大于1，并且`index.shape[-1] <= x.ndim`。

- updates必须和x有相同的数据类型，形状必须是`index.shape[:1] + x.shape[index.shape[-1]:]`。

|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| xDesc | float32，float16，int32，int64或double |  TensorND | 任意存储格式 |
| indexDesc | int32 |  TensorND | 任意存储格式 |
| updatesDesc | float32，float16，int32，int64或double |  TensorND | 任意存储格式 |
| outDesc | float32，float16，int32，int64或double |  TensorND | 任意存储格式 |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
