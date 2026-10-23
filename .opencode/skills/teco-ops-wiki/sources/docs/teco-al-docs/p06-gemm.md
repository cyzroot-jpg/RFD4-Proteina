---
id: doc-teco-al-docs-p06
title: "Teco-AL 项目文档集 — 第p06部分 (doc/op_docs/gemm.md)"
type: source-doc-part
parent_doc: doc-teco-al-docs
product_version: "v1.0.0 / commit 17c5cd6"
source_file: "doc/op_docs/gemm.md"
raw_text: "sources/docs/raw-teco-al/op_docs/gemm.txt"
raw_line_range: "1-142"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-al, gemm, hgemm, tiling, broadcast, permute, double-buffer, matmul, worked-example, benchmarked]
---

# Teco-AL 项目文档集（第p06部分：Hgemm 设计文档）

# tecoalHgemm设计文档

> 原文包含三张示意图（`doc/op_docs/pics/gemm_cal.png`、`gemm_tilling.png`、`gemm_bcast.png`、`gemm_permute.png`），本知识库未收录图片，仅保留文字、公式与伪代码说明。

## 计算原理

执行通用矩阵乘法操作（GEMM，General Matrix Multiplication）。
$$C = alpha*op(A) * op(B) + beta * C$$

其中，
- A、B、C分别代表输入输出矩阵。
- alpha、beta分别代表缩放系数。
- op(A)、op(B)分别代表矩阵A、B是否进行转置选择后的结果。以矩阵A为例：
$$op(A)=\begin{cases}
A  , \quad  if \quad  transa == \text{N}\\
A^T  , \quad  if \quad  transa == \text{T}
\end{cases}
$$

## 功能实现
### 接口设计

为了完成上述计算功能，参考cublasHgemm，可进行userAPI接口设计。

```c++
tecoalStatus_t TECOALWINAPI tecoalHgemm(
    tecoalHandle_t                          handle,
    tecoalOperation_t                       transa,
    tecoalOperation_t                       transb,
    int                                     m,
    int                                     n,
    int                                     k,
    float                                   alpha,
    const void                              *A,
    int                                     lda,
    const void                              *B,
    int                                     ldb,
    float                                   beta,
    void                                    *C,
    int                                     ldc,
    tecoalAlgo_t                            algo);
```
### 参数信息

其中，各参数含义如下：
|参数|输入/输出|主机端/设备端|说明|
|---|---|---|---|
|handle| 输入 | 主机端 | Teco-AL句柄。详见《开发指南——核心概念——句柄》（`doc-teco-al-docs-p02`）章节的介绍。 |
| transa| 输入 | 主机端 |  矩阵$A$的运算操作符。|
| transb| 输入 | 主机端 |  矩阵$B$的运算操作符。|
| m| 输入 | 主机端 |  矩阵$op(A)$与矩阵$C$的行。|
| n| 输入 | 主机端 |  矩阵$op(B)$与矩阵$C$的列。|
| k| 输入 | 主机端 |  矩阵$op(A)$的列，矩阵$op(B)$的行。|
| alpha| 输入 | 主机端 |  用于乘法的标量。|
| A| 输入 | 设备端 |  用于乘法的矩阵$A$。 <br> - 若$transa$取值为`TECOAL_OP_N`，表示维度为$m*lda$且$lda \ge max(1,k)$的矩阵。 <br> - 若$transa$取值为`TECOAL_OP_T`，表示维度为$k*lda$且$lda \ge max(1,m)$的矩阵。|
| lda| 输入 | 主机端 |  用于存储矩阵$A$的二维数组在内存中同列相邻元素的距离。|
| B| 输入 | 设备端 |  用于乘法的矩阵$B$。 <br> - 若$transb$取值为`TECOAL_OP_N`，表示维度为$k*ldb$且$ldb \ge max(1,n)$的矩阵。 <br> - 若$transb$取值为`TECOAL_OP_T`，表示维度为$n*ldb$且$ldb \ge max(1,k)$的矩阵。|
| ldb| 输入 | 主机端 |  用于存储矩阵$B$的二维数组在内存中同列相邻元素的距离。|
| beta| 输入 | 主机端 |  用于乘法的标量。|
| C| 输入/输出 | 设备端 |  维度为$m*ldc$且$ldc \ge max(1,n)$的矩阵。|
| ldc| 输入 | 主机端 |  用于存储矩阵$C$的二维数组在内存中同列相邻元素的距离。|
|algo| 输入 | 主机端 | 用于指定不同性能的实现算法，可选0~6的整数。 |

针对`algo`参数，不同取值含义如下：

|算法取值|计算分支|含义说明|
|---|---|---|
|`TECOAL_ALGO_0`|tecoKernelGemmFT16SingleThread|基础GEMM实现，仅使用单线程计算。|
|`TECOAL_ALGO_1`|tecoKernelGemmFT16MultiThreads|多线程并行计算，均衡分配任务。|
|`TECOAL_ALGO_2`|tecoKernelGemmFT16DMA|使用DMA数据搬运，减少访存开销。|
|`TECOAL_ALGO_3`|tecoKernelGemmFT16SIMD|使用SIMD指令实现，利用向量处理能力。|
|`TECOAL_ALGO_4`|tecoKernelGemmFT16Matmul|使用矩阵乘法单元进行计算。|
|`TECOAL_ALGO_5`|tecoKernelGemmFT16Broadcast|使用数据广播，提升传输效率。|
|`TECOAL_ALGO_6`|tecoKernelGemmFT16DoubleBuffer|使用双缓冲设计，并行访存与计算过程。|

### 类型限制
当前计算分支，主要完成以下功能实现，其余情况暂不支持。
|参数|数据类型|维度信息|存储格式|
|---|---|---|---|
| A | float16 | Tensor2D | 行优先存储（NCHW） |
| B | float16 | Tensor2D | 行优先存储（NCHW） |
| C | float16 | Tensor2D | 行优先存储（NCHW） |
| alpha | float32，目前仅支持为1 | \ | \ |
| beta | float32，目前仅支持为0 | \ | \ |

## 性能优化

### 数据分块
计算总量为整个矩阵C的更新，单个SPA计算核心阵列中的SPE均分矩阵C的计算任务：
- 单个SPE在单次循环中计算localbM×localbN
- 单个SPA在单次循环中计算bM×bN

### 数据广播
依次遍历计算各个bm、bn、bk小块，每次计算的维度为localbm、localbn、localbk。因为计算矩阵C中的小块，在行列方向会分别用到相同的矩阵A与B小块。因此，各个SPE重复多次读取数据的效率，不如分工读取数据后再广播的效果。其中，行列广播方向可以根据矩阵形状与线程组特点适配调整。

### 数据重排
根据矩阵乘法单元的特性，在localbn数据维度大于32时，需要进行数据重排操作（permute）。同时，计算得到的矩阵C也需要对应进行重排。

### 伪代码思路
```
pA pB pC分别为矩阵ABC的指针，对应pCurr pNext用于双缓冲
在SPM上分配矩阵ABC的双缓冲、重排空间
对矩阵AB进行首次计算数据的行列广播，将数据从Global内存搬运到SPM
for (int idx = 0; idx < nM * nN; ++idx) {  // 遍历bM bN小块
    idM = idx / nN;
    idN = idx % nN;
        for (idK = 0; idK < nK; ++idK) {   // 遍历bK维度
            pCurrA、pCurrB分别为A[idM][idK]与B[idK][idN]
            根据维度遍历情况，更新pNextA和pNextB指针
            交换矩阵AB的计算和访存区域
            等待localbM localbN localbK数据广播加载完成
            广播预取下一块pNextA pNextB数据
            重排B矩阵结构
            使用矩阵乘法单元进行计算（最后一次计算进行写回，此前仅做累加）
            }
        对结果矩阵C进行精度转换，内存重排与写回
}
```


### 性能数据

依次运行各个分支，得到性能数据如下表，性能数据可能随软硬件环境不同，存在正常波动现象，CI环境测试结果如下：

|            分支名称            | host时间（us） | userAPI时间（us） |
|------------------------------|--------------|-----------------|
| tecoKernelGemmFT16SingleThread | 400931         | 42406765          |
| tecoKernelGemmFT16MultiThreads | 406197         | 1746017           |
| tecoKernelGemmFT16DMA          | 400771         | 38203             |
| tecoKernelGemmFT16SIMD         | 400541         | 7757              |
| tecoKernelGemmFT16Matmul       | 400149         | 177               |
| tecoKernelGemmFT16Broadcast    | 394824         | 90               |
| tecoKernelGemmFT16DoubleBuffer | 403325         | 64               |
