---
id: doc-teco-al-docs-p05
title: "Teco-AL 项目文档集 — 第p05部分 (doc/op_docs/add_tensor.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/add_tensor.md"
raw_text: "sources/docs/raw-teco-al/op_docs/add_tensor.txt"
raw_line_range: "1-97"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, add-tensor, tiling, double-buffer, simd, worked-example, benchmarked]
---

# Teco-AL 项目文档集（第p05部分：AddTensor 设计文档）

# tecoalAddTensor设计文档

> 原文包含两张示意图（`doc/op_docs/pics/add_tilling.png`、`add_double_buffer.png`），本知识库未收录图片，仅保留文字与伪代码说明。

## 计算原理

计算张量A与标量alpha之积，再加上张量C与beta之积，并将结果赋给C。
$$C = alpha*A + beta*C$$

## 功能实现
### 接口设计

为了完成上述计算功能，参考cudnnAddTensor，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalAddTensor(
    tecoalHandle_t                         handle,
    const void                             *alpha,
    const tecoalTensorDescriptor_t         aDesc,
    const void                             *A,
    const void                             *beta,
    const tecoalTensorDescriptor_t         cDesc,
    void                                   *C,
    tecoalAlgo_t                           algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|alpha| 输入 | 主机端 | 指向缩放系数的指针，float32类型。 |
|aDesc| 输入 | 主机端 | 数据A的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|A| 输入 | 设备端 | 指向aDesc描述的数据指针。 |
|beta| 输入 | 主机端 | 指向缩放系数的指针，float32类型。 |
|cDesc| 输入 |主机端  | 数据C的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|C| 输入/输出 | 设备端 | 指向cDesc描述的数据指针。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~5整数。 |

针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelAddTensorHalfSingleThread|基础AddTensor实现，仅使用单线程计算。|
|`TECOAL_ALGO_1`|tecoKernelAddTensorHalfMultiThreads|多线程并行计算，均衡分配任务。|
|`TECOAL_ALGO_2`|tecoKernelAddTensorHalfDMA|使用DMA数据搬运，减少访存开销。|
|`TECOAL_ALGO_3`|tecoKernelAddTensorHalfSIMD|使用SIMD指令实现，利用向量处理能力。|
|`TECOAL_ALGO_4`|tecoKernelAddTensorHalfUnroll|使用循环展开，提升指令并行。|
|`TECOAL_ALGO_5`|tecoKernelAddTensorHalfDoubleBuffer|使用双缓冲设计，并行访存与计算过程。|


### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| aDesc | float16 | Tensor4D | NHWC，NCHW，CHWN和NWHC，其中N\*H\*W\*C%2 == 0 |
| cDesc | float16 | Tensor4D | NHWC，NCHW，CHWN和NWHC，其中N\*H\*W\*C%2 == 0 |

## 性能优化

### 数据分块
计算总量为data_num，均分到各个线程并行执行，每个线程处理的任务量为per_spe_num。

### 流水设计
使用SIMD向量指令，相比标量有显著加速作用。创建2个数据搬运句柄与缓存空间，通过异步接口实现访存与计算的并行，如 t 和 t+1时刻。

### 伪代码思路
```
总计算任务量为data_num
每个线程计算量为per_spe_num，对应区间[start, end]，步长为单次能计算的最大值max_blk
异步搬运参与首次计算的A、C数据
for (int i = start; i < end; i += max_blk)
   等待上次数据搬运完成
   交换缓冲区
   另块缓冲区ADBUF开始下次数据异步搬运过程
   当前缓冲区CDBUF开始计算过程
   将CDBUF的计算结果从SPM异步搬运到Global存储中
end for
```

### 性能数据

依次运行各个分支，得到性能数据如下表，性能数据可能随软硬件环境不同，存在正常波动现象，CI环境测试结果如下：

|                名称               | host时间（us） | userAPI时间（us） |
|---------------------------------|--------------|-----------------|
| tecoKernelAddTensorHalfSingleThread | 81778         | 1479308          |
| tecoKernelAddTensorHalfMultiThreads | 81789         | 54417           |
| tecoKernelAddTensorHalfDMA | 81391         | 2035             |
| tecoKernelAddTensorHalfSIMD         | 81026         | 209              |
| tecoKernelAddTensorHalfUnroll         | 81944         | 143              |
| tecoKernelAddTensorHalfDoubleBuffer         | 81285         | 128              |
