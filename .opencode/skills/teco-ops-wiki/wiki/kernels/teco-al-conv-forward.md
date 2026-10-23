---
id: kernel-teco-al-conv-forward
title: "Teco-AL ConvolutionForward：conv-to-gemm 等价转换 + 分块广播双缓冲"
type: kernel
architectures: [sdaa, teco-t1]
kernel_types: [convolution, gemm]
confidence: verified
languages: [sdaa-c, cpp]
related: [technique-teco-al-algo-branch-benchmarking, kernel-teco-al-gemm, kernel-teco-al-add-tensor]
sources: [doc-teco-al-docs-p07, doc-teco-al-docs-p02]
---

# Teco-AL ConvolutionForward：conv-to-gemm 等价转换 + 分块广播双缓冲

`tecoalConvolutionForward`（`doc-teco-al-docs-p07`）是 Teco-AL 三个完整讲解范例之一。它的性能优化路线在 `technique-teco-al-algo-branch-benchmarking` 描述的标准递进序列之前，额外插入了一步"计算转换"，是本页的核心内容。

## 计算与接口

$$y_{n,e,f,m} = \alpha \sum_{c,r,s} x_{n,e+r,f+s,c} \cdot w_{c,r,s,m} + \beta \cdot y_{n,e,f,m}$$

`x`（NHWC）、`w`（CRSM）、`y`（NEFM），float16，`C`/`M` 须为 32 的整数倍且数据指针 4B 对齐。接口 `tecoalConvolutionForward(handle, alpha, xDesc, x, wDesc, w, convDesc, algo, workSpace, workSpaceSizeInBytes, beta, yDesc, y)`。文档对 `algo` 的支持情况按卷积核形状一分为二：

- **R=1, S=1**（等价于 1x1 卷积）：有完整的 7 级优化分支（SingleThread → ... → DoubleBuffer），是本页重点。
- **R≠1, S≠1**（一般卷积核）：只有一个基线分支 `tecoKernelConvFwdNodilationBaseline`，性能优化章节留空标注"赛题补充内容"——即通用卷积核形状的优化路线尚未在公开文档中给出参考实现，需要贡献者自行探索。

## 关键设计：conv-to-gemm 等价转换

当 `R=1, S=1, pad=0, stride=1, dilation=1` 同时满足时，卷积退化为矩阵乘法，可以直接复用矩阵乘法加速单元——这是整条优化路线里收益最大的一步（对照 `technique-teco-al-algo-branch-benchmarking` 的表格，从 SIMD 的 2861us 直接跳到 Matmul 的 120us，约 24 倍提升，是三个范例中单步收益最集中的一次跃升）。

转换后的分块策略：
- 在 N 维度切分计算任务，每个 SPE 计算一个 `[HW, C] × [C, M] = [HW, M]` 的矩阵乘法。
- 沿 C 维度累加（`x1 * w1 = y1`，C 遍历结束即完成累加），再遍历 M、HW 维度完成整个矩阵计算。
- 权重 w 对所有 SPE 相同，因此通过广播传输（而不是每个 SPE 各自读取）。

## 主循环伪代码骨架

```
异步将首个输入数据x从Global传输到SPM的buffer1
广播传输整个权重w
N维度切分计算任务
for (n = tid; n < N; n += threadDim):
    若未计算完成，异步搬运下一块输入x到buffer2
    等待权重广播完成
    等待当前输入x搬运完成
    for (ef in [0,EF), step bEF):
        for (m in [0,M), step bM):
            for (c in [0,C), step bC):
                矩阵乘法计算
            存储矩阵乘法计算结果
            等待矩阵乘法计算完成
    输出y传输回Global
    交换输入缓冲区双缓冲标志
释放分配的内存
```

与 `kernel-teco-al-gemm` 的主循环对比：两者都是"广播权重/共享矩阵 + 双缓冲预取下一块输入 + 矩阵乘法单元计算"的结构，区别在于 GEMM 案例的双缓冲发生在 A/B/C 三个矩阵上并额外需要 permute 重排，而这里的双缓冲只发生在输入 x 上（权重 w 广播一次即可复用，不需要每次重新广播）——因为卷积场景下权重在整个 N 维度遍历过程中保持不变，这是与通用 GEMM（A、B 都随分块变化）的关键差异，也是"利用计算模式的不变量减少重复搬运"这一优化思路的具体体现。

## 真实性能数据（CI 环境实测）

| 分支 | userAPI时间(us) | 相对 SingleThread 加速比 |
|---|---|---|
| SingleThread | 31,436,209 | 1x |
| MultiThreads | 2,195,753 | 14x |
| DMA | 37,050 | 848x |
| SIMD | 2,861 | 10,988x |
| Matmul | 120 | 261,968x |
| Broadcast | 119 | 264,170x |
| DoubleBuffer | 116 | 271,001x（文档原文标注"最高可达3585倍"指相对 host 时间，而非 SingleThread） |

## 尚未覆盖的部分

R≠1/S≠1（通用卷积核）分支的性能优化章节在原文中留空。若任务涉及非 1x1 卷积核，本页给出的 conv-to-gemm 技巧不能直接套用（等价条件不满足），需要另行设计分块/访存策略——这是明确的知识边界，不应假设通用卷积也能走同样的加速路径。
