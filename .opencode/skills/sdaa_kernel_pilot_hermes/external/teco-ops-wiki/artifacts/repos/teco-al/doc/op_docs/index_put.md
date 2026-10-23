# tecoalIndexPut设计文档


## 计算原理

根据索引 indices 和给定值 value，原位修改 output 的数据。

- 当 `accumulate == false `时：`output[idx]=value[i]`
- 当 `accumulate == true` 时：`output[idx]=output[idx]+value[i]`

其中， idx 的值由索引张量 indices 的数据类型决定。

当索引类型为int64时，输入张量的最高维度上选择索引对应的数据块，按序写入输出张量。

`idx=(indices[0][i], indices[1][i], ..., indices[indices.length - 1][i])`

对于 indices 中的每个张量 index，有：

1. index 应为1维张量。

2. 除长度为1的张量外，其余张量的长度应一致。

3. index 中每个元素的值不能超过 output.shape 中对应维度的最大取值。

对于张量 value 有：

1. `value.shape[0]==indices[0].shape[0]`
2. 若 `i≠0` ，则 `value.shape[i]=1 或 value.shape[i]=output.shape[i]`​​。
    1. 若 `value.shape[i]=output.shape[i]`，则将 value 的值更新到 output 对应的位置上。
    2. 若 `value.shape[i]=1，则将 value[i][0] `广播到 output 对应的位置上。

例如，若需要选择 `output[1][2][3], output[5][6][7], ..., output[98][23][101]` 进行更新，则索引 indices 应当由如下的三个一维张量组成：`([1, 5, ..., 98], [2, 6, ..., 23], [3, 7, ..., 101])`

## 功能实现
### 接口设计

为了完成上述计算功能，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalIndexPut(
    tecoalHandle_t                         handle,
    int                                    indices_length,
    bool                                   accumulate,
    const tecoalTensorDescriptor_t         *indicesDesc,
    void                                   **indices,
    const tecoalTensorDescriptor_t         valuesDesc,
    const void                             *values,
    const tecoalTensorDescriptor_t         inputDesc,
    const void                             *input,
    const tecoalTensorDescriptor_t         outputDesc,
    void                                   *output,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见[《开发指南——核心概念——句柄》](../tutorial/dev_guide.md#句柄)章节的介绍。 |
| indices_length | 输入      | 主机端        | 索引的张量个数，等于indices的长度。                                                  |
| accumulate     | 输入      | 设备端        | 选择更新模式，True：更新时将value累加到对应位置。其余情况，更新时直接通过value赋值。 |
| indicesDesc    | 输入      | 主机端        | 索引张量的描述符构成的数组。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。                          |
| indices        | 输入      | 设备端        | 指向indicesDesc的数据指针构成的指针数组。                                            |
| valuesDesc     | 输入      | 主机端        | 数据values的描述符。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。                                  |
| values         | 输入      | 设备端        | 需要更新的结果数据。                                                                 |
| inputDesc      | 输入      | 主机端        | 数据input的描述符。预留参数，实际无操作。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。             |
| input          | 输入      | 设备端        | 指向inputDesc描述的数据指针。预留参数，实际无操作。                                  |
| outputDesc     | 输入      | 主机端        | 数据output的描述符。详见[《开发指南——核心概念——描述符》](../tutorial/dev_guide.md#描述符)章节的介绍。                                  |
| output         | 输入/输出 | 设备端        | 指向outputDesc的数据指针。                                                           |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~n整数。 |


针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelIndexPutInt64Indices|基础实现。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| indicesDesc[i] | int64 | Tensor4D | NCHW |
| valuesDesc | half |Tensor4D | NCHW |
| inputDesc | half |Tensor4D | NCHW |
| outputDesc | half |Tensor4D | NCHW |


## 性能优化

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）


