---
id: doc-teco-al-docs-p19
title: "Teco-AL 项目文档集 — 第p19部分 (doc/op_docs/unique.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/unique.md"
raw_text: "sources/docs/raw-teco-al/op_docs/unique.txt"
raw_line_range: "1-82"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, unique, sort, dedup]
---

# Teco-AL 项目文档集（第p19部分：Unique 设计文档）

# tecoalUnique设计文档

## 计算原理

返回输入张量中的独有元素。

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalUnique(
    tecoalHandle_t                         handle,
    tecoalUniqueMode_t                     mode,
    int                                    axis,
    bool                                   sorted,
    bool                                   return_inverse,
    bool                                   return_counts,
    const tecoalTensorDescriptor_t         inputDesc,
    const void                             *input,
    const tecoalTensorDescriptor_t         outputDesc,
    void                                   *output,
    const tecoalTensorDescriptor_t         inverseDesc,
    void                                   *inverse,
    const tecoalTensorDescriptor_t         countsDesc,
    void                                   *counts,
    void                                   *out_size,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|mode| 输入 | 主机端 | 选择是否按照轴进行操作。`TECOAL_UNIQUE_NONE`代表将输入平铺为一维的张量后再选取独有元素。`TECOAL_UNIQUE_NOT_NONE`代表按照指定的轴选取独有元素。暂只支持前者。 |
|axis| 输入 | 主机端 | 指定选取独有元素的轴。暂只支持取值为零。 |
|sorted| 输入 | 主机端 | 输出的元素是否按升序排序。 |
|return_inverse| 输入 | 主机端 | 是否返回输入的元素对应在独有元素中的索引。 |
|return_counts| 输入 | 主机端 | 是否返回每个独有元素在输入数据中的个数。 |
|inputDesc| 输入 | 主机端 | 数据input的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|input| 输入 | 设备端 | 指向inputDesc描述的数据指针。 |
|outputDesc| 输入 | 主机端 | 数据output的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|output| 输出 | 设备端 | 指向outputDesc描述的数据指针。 |
|inverseDesc| 输入 | 主机端 | 数据inverse的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|inverse| 输出 | 设备端 | 指向inverseDesc描述的数据指针。 |
|countsDesc| 输入 | 主机端 | 数据counts的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|counts| 输出 | 设备端 | 指向countsDesc描述的数据指针。 |
|out_size| 输出 | 设备端 | 独有元素的个数，int64类型。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelUniqueSortedInt64|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。

注意：当前仅支持`TECOAL_UNIQUE_NONE`模式，`axis`暂只支持取值为零。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| inputDesc | int64 | TensorND | 任意存储格式 |
| outputDesc | int64 | Tensor1D | 任意存储格式 |
| inverseDesc | int64 | TensorND | 任意存储格式 |
| countsDesc | int64 | Tensor1D | 任意存储格式 |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
