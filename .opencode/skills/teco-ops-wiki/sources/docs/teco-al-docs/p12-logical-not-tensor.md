---
id: doc-teco-al-docs-p12
title: "Teco-AL 项目文档集 — 第p12部分 (doc/op_docs/logical_not_tensor.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/logical_not_tensor.md"
raw_text: "sources/docs/raw-teco-al/op_docs/logical_not_tensor.txt"
raw_line_range: "1-59"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, logical-not-tensor, elementwise]
---

# Teco-AL 项目文档集（第p12部分：LogicalNotTensor 设计文档）

# tecoalLogicalNotTensor设计文档

## 计算原理

执行逻辑非操作。


## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalLogicalNotTensor(
    tecoalHandle_t                         handle,
    const tecoalTensorDescriptor_t         aDesc,
    const void                             *A,
    const tecoalTensorDescriptor_t         cDesc,
    void                                   *C,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
| aDesc  | 输入      | 主机端        | 数据A的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
| A      | 输入      | 设备端        | 指向aDesc描述的数据指针。                      |
| cDesc  | 输入      | 主机端        | 数据C的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
| C      | 输出      | 设备端        | 指向cDesc描述的数据指针。                      |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelLogicalNotTensorBool|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| aDesc | bool | Tensor4D | NHWC |
| cDesc | bool | Tensor4D | NHWC |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
