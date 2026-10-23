---
id: doc-teco-al-docs-p17
title: "Teco-AL 项目文档集 — 第p17部分 (doc/op_docs/scatter_out.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/scatter_out.md"
raw_text: "sources/docs/raw-teco-al/op_docs/scatter_out.txt"
raw_line_range: "1-122"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, scatter-out, scatter, reduction]
---

# Teco-AL 项目文档集（第p17部分：ScatterOut 设计文档）

# tecoalScatterOut设计文档

## 计算原理

实现散射功能，将input中所有的值或alpha，按照index中的索引分散到output中。


## 功能实现
### 接口设计

为了完成上述计算功能，参考torch.Tensor.scatter_，可进行userAPI接口设计。

```c++
typedef enum {
    TECOAL_SCATTEROUT_REDUCTION_NONE = 0,
    TECOAL_SCATTEROUT_REDUCTION_ADD = 1,
    TECOAL_SCATTEROUT_REDUCTION_MULTIPLY = 2,
} tecoalScatterOutReductionMode_t;

typedef enum {
    TECOAL_SCATTEROUT_INPUT_SCALAR = 0,
    TECOAL_SCATTEROUT_INPUT_ARRAY = 1,
} tecoalScatterOutInputType_t;

tecoalStatus_t TECOALWINAPI tecoalScatterOut(
    tecoalHandle_t                         handle,
    const unsigned int                     target_dim,
    const float                            alpha,
    const tecoalScatterOutInputType_t      input_type,
    const tecoalScatterOutReductionMode_t  reduce,
    const tecoalTensorDescriptor_t         inputDesc,
    const void                             *input,
    const tecoalTensorDescriptor_t         indexDesc,
    const void                             *index,
    const tecoalTensorDescriptor_t         outputDesc,
    void                                   *output,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|target_dim| 输入 | 主机端 | 分散的维度。 |
|alpha| 输入 | 主机端 | SCALAR模式下输入的标量值。 |
|input_type| 输入 | 主机端 | 输入的类型。`TECOAL_SCATTEROUT_INPUT_SCALAR`标量模式。`TECOAL_SCATTEROUT_INPUT_ARRAY`数组模式。 |
|reduce| 输入 | 主机端 | 规约操作的模式。 |
|inputDesc| 输入 | 主机端 | 数据input的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|input| 输入 | 设备端 | 指向inputDesc描述的数据指针。 |
|indexDesc| 输入 | 主机端 | 数据index的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|index| 输入 | 设备端 | 指向indexDesc描述的数据指针。 |
|outputDesc| 输入 |主机端  | 数据output的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|output| 输入/输出 | 设备端 | 指向outputDesc描述的数据指针。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |

针对`reduce`参数，不同取值含义如下：
```python
### TECOAL_SCATTEROUT_REDUCTION_NONE
### 根据index中的索引，按照dim的方向，找到输出对应的位置，进行替换。以3D为例：
### 数组模式
output[index[i][j][k]][j][k] = input[i][j][k]    ### if dim == 0
output[i][index[i][j][k]][k] = input[i][j][k]    ### if dim == 1
output[i][j][index[i][j][k]] = input[i][j][k]    ### if dim == 2

### 标量模式
output[index[i][j][k]][j][k] = alpha            ### if dim == 0
output[i][index[i][j][k]][k] = alpha            ### if dim == 1
output[i][j][index[i][j][k]] = alpha            ### if dim == 2


### TECOAL_SCATTEROUT_REDUCTION_ADD
### 根据index中的索引，按照dim的方向，找到输出对应的位置，累加并更新。以3D为例：
### 数组模式
output[index[i][j][k]][j][k] += input[i][j][k]    ### if dim == 0
output[i][index[i][j][k]][k] += input[i][j][k]    ### if dim == 1
output[i][j][index[i][j][k]] += input[i][j][k]    ### if dim == 2

### 标量模式
output[index[i][j][k]][j][k] += alpha           ### if dim == 0
output[i][index[i][j][k]][k] += alpha           ### if dim == 1
output[i][j][index[i][j][k]] += alpha           ### if dim == 2


### TECOAL_SCATTEROUT_REDUCTION_MULTIPLY
### 根据index中的索引，按照dim的方向，找到输出对应的位置，累乘并更新。以3D为例：
### 数组模式
output[index[i][j][k]][j][k] *= input[i][j][k]    ### if dim == 0
output[i][index[i][j][k]][k] *= input[i][j][k]    ### if dim == 1
output[i][j][index[i][j][k]] *= input[i][j][k]    ### if dim == 2

### 标量模式
output[index[i][j][k]][j][k] *= alpha           ### if dim == 0
output[i][index[i][j][k]][k] *= alpha           ### if dim == 1
output[i][j][index[i][j][k]] *= alpha           ### if dim == 2
```

针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelScatterOut|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| inputDesc | float32 | TensorND | 任意存储格式 |
| indexDesc | int64 | TensorND | 任意存储格式|
| outputDesc | float32 | TensorND | 任意存储格式|

## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
