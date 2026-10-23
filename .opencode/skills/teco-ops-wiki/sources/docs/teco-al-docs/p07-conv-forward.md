---
id: doc-teco-al-docs-p07
title: "Teco-AL 项目文档集 — 第p07部分 (doc/op_docs/conv_forward.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/conv_forward.md"
raw_text: "sources/docs/raw-teco-al/op_docs/conv_forward.txt"
raw_line_range: "1-157"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, conv-forward, conv2gemm, tiling, broadcast, double-buffer, matmul, worked-example, benchmarked]
---

# Teco-AL 项目文档集（第p07部分：ConvolutionForward 设计文档）

# tecoalConvolutionForward设计文档

> 原文包含三张示意图（`doc/op_docs/pics/conv_cal.png`、`conv_2gemm.png`、`conv_tilling.png`、`conv_bcast.png`），本知识库未收录图片，仅保留文字、公式与伪代码说明。

## 计算原理

使用指定权重w对输入x执行卷积运算，并将计算结果在张量y中进行更新。计算原理和过程如下：

1. 滑动权重：权重以一定的步长在输入图像上滑动。

1. 逐元素乘积和累加：在每个位置，权重与输入图像的对应局部区域进行逐元素相乘，然后将这些乘积的结果相加，得到输出特征图的一个像素值。

1. 重复步骤：重复上述步骤，将权重在输入图像上滑动，直到覆盖整个图像。这将生成一个输出特征图，其中每个像素值都是通过权重在输入图像上的滑动计算得到的。

$$y_{n, e, f, m}=\alpha \times \sum_{c=0}^{C-1} \sum_{r=0}^{R-1} \sum_{s=0}^{S-1} x_{n, e+r, f+s, c} \cdot w_{c, r, s, m} + \beta \times y_{n, e, f, m}$$

其中，
- x、w、y分别代表输入、权重、输出矩阵，形状分别为NHWC、CRSM、NEFM。
- alpha、beta分别代表缩放系数。

## 功能实现
### 接口设计

为了完成上述计算功能，参考cudnnConvolutionForward，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalConvolutionForward(
    tecoalHandle_t                          handle,
    const void                              *alpha,
    const tecoalTensorDescriptor_t          xDesc,
    const void                              *x,
    const tecoalFilterDescriptor_t          wDesc,
    const void                              *w,
    const tecoalConvolutionDescriptor_t     convDesc,
    tecoalAlgo_t                            algo,
    void                                    *workSpace,
    size_t                                  workSpaceSizeInBytes,
    const void                              *beta,
    const tecoalTensorDescriptor_t          yDesc,
    void                                    *y);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
|alpha| 输入 | 主机端 | 指向缩放系数的指针，float32类型。 |
|xDesc| 输入 | 主机端 | 数据x的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。|
|x| 输入 | 设备端 | 指向xDesc描述的数据指针。|
|wDesc| 输入 | 主机端 | 数据w的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。|
|w| 输入 | 设备端 | 指向wDesc描述的数据指针。|
|convDesc| 输入 | 主机端 | 卷积描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。 |
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，支持情况如下。|
|workSpace| 输入 | 设备端 | 指向指定卷积算法需要工作空间的数据指针。如果某个指定卷积算法不需要工作空间，该指针可以为空。详见《开发指南——核心概念——工作空间》（`doc-teco-al-docs-p02`）章节的介绍。 |
|workSpaceSizeInBytes| 输入 | 主机端 | 指定所需要的工作空间占用大小，单位：字节。|
|beta| 输入 | 主机端 | 指向缩放系数的指针，float32类型。|
|yDesc| 输入 |主机端  | 数据y的描述符。详见《开发指南——核心概念——描述符》（`doc-teco-al-docs-p02`）章节的介绍。|
|y| 输入/输出 | 设备端 | 指向yDesc描述的数据指针。 |

针对`algo`参数，不同取值含义如下：

1. 当wDesc中的R与S取值均为1时：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelConvFwdFT16SingleThread|基础串行实现，仅使用单线程计算。|
|`TECOAL_ALGO_1`|tecoKernelConvFwdFT16MultiThreads|多线程并行计算，均衡分配任务。|
|`TECOAL_ALGO_2`|tecoKernelConvFwdFT16DMA|使用DMA数据搬运，减少访存开销。|
|`TECOAL_ALGO_3`|tecoKernelConvFwdFT16SIMD|使用SIMD指令实现，利用向量处理能力。|
|`TECOAL_ALGO_4`|tecoKernelConvFwdFT16Matmul|使用矩阵乘法单元进行计算。|
|`TECOAL_ALGO_5`|tecoKernelConvFwdFT16Broadcast|使用数据广播，提升传输效率。|
|`TECOAL_ALGO_6`|tecoKernelConvFwdFT16DoubleBuffer|使用双缓冲设计，并行访存与计算过程。|

2. 当wDesc中的R与S取值均不为1时：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelConvFwdNodilationBaseline|赛题优化的基线代码。|
|`TECOAL_ALGO_...`|赛题补充内容。|赛题补充内容。|
|`TECOAL_ALGO_n`|赛题补充内容。|赛题补充内容。|

### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| xDesc | float16 | Tensor4D | NHWC，其中C必须为32的整数倍，对应数据指针必须4B对齐。 |
| wDesc | float16 | Tensor4D | CRSM，其中M必须为32的整数倍，对应数据指针必须4B对齐。 |
| yDesc | float16 | Tensor4D | NHWC，其中C必须为32的整数倍，对应数据指针必须4B对齐。 |
| alpha | float32，目前仅支持为1 | \ | \ |
| beta | float32，目前仅支持为0 | \ | \ |

## 性能优化

### 当wDesc中的R与S取值均为1时

#### 计算转换

当参数取值满足：R = 1，S =1，pad = 0，stride = 1，dilation = 1时，卷积运算可以等价转换为矩阵乘法，使用矩阵乘法单元进行加速。

#### 数据分块
在N维度对计算任务进行切分，每个SPE计算一个` [HW, C] * [C, M] = [HW, M] `的矩阵乘法，矩阵沿着 C 维度进行累加计算，即`x1 * w1 = y1`。C 维度遍历结束，y1 累加乘法计算完成。然后遍历 M、HW 维度，完成整个矩阵的计算。

#### 数据广播
在N维度对计算任务进行切分，每个SPE计算使用的数据w是相同的，可以通过广播进行数据传输。

#### 伪代码思路
```
异步将首个输入数据x从Global空间传输到SPM上的buffer1
使用广播传输整个权重w数据
N维度切分计算任务
for (int n = tid; n < N; n += threadDim) {
    若未计算完成，异步搬运下一块参与计算的输入数据x到buffer2
    等待权重广播完成
    等待参与当前计算的输入数据x搬运完成
    遍历EF和M维度
    for (int ef = 0; ef < EF; ef += bEF) {
        for (int m = 0; m < M; m += bM) {
            for (int c = 0; c < C; c += bC) {
                执行矩阵乘法计算
            }
            存储矩阵乘法计算结果
            等待矩阵乘法计算完成
        }
    }
    将输出数据y传输回Global内存
    交换输入缓冲区的双缓冲标志
}
释放分配的内存
```

#### 性能数据

使用samples依次运行各个分支，得到性能数据如下表。可见随着优化策略的不断丰富，userAPI时间不断缩短，相对host时间加速最高可达3585倍，性能逐步上升（性能数据可能随软硬件环境不同，存在正常波动现象）。

|                名称               | host时间（us） | userAPI时间（us） |
|---------------------------------|--------------|-----------------|
| tecoKernelConvFwdFT16SingleThread | 414862         | 31436209          |
| tecoKernelConvFwdFT16MultiThreads | 414686         | 2195753           |
| tecoKernelConvFwdFT16DMA          | 415635         | 37050             |
| tecoKernelConvFwdFT16SIMD         | 415447         | 2861              |
| tecoKernelConvFwdFT16Matmul       | 415696         | 120              |
| tecoKernelConvFwdFT16Broadcast    | 415393         | 119              |
| tecoKernelConvFwdFT16DoubleBuffer | 415807         | 116              |

### 当wDesc中的R与S取值均不为1时

赛题补充内容：
1. 标明自己实现的具体计算分支
2. 优化设计说明
3. 性能自测数据（测例路径 + tecotest的硬件时间均值）
