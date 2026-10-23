---
id: kernel-teco-al-add-tensor
title: "Teco-AL AddTensor：elementwise 分块 + SIMD + 双缓冲流水基线案例"
type: kernel
architectures: [sdaa, teco-t1]
kernel_types: [elementwise]
confidence: verified
languages: [sdaa-c, cpp]
related: [technique-teco-al-algo-branch-benchmarking, kernel-teco-al-gemm, kernel-teco-al-conv-forward]
sources: [doc-teco-al-docs-p05, doc-teco-al-docs-p02]
---

# Teco-AL AddTensor：elementwise 分块 + SIMD + 双缓冲流水基线案例

`tecoalAddTensor`（`doc-teco-al-docs-p05`）是 Teco-AL 三个完整讲解范例中计算最简单的一个（`C = alpha*A + beta*C`），因此最适合作为理解"分块 + 双缓冲流水"这套通用手法的入门案例——不涉及 `kernel-teco-al-gemm`/`kernel-teco-al-conv-forward` 中矩阵乘法单元、广播、重排等更复杂的机制。

## 计算与接口

`tecoalAddTensor(handle, alpha, aDesc, A, beta, cDesc, C, algo)`，float16、Tensor4D，要求 `N*H*W*C % 2 == 0`。6 个分支：SingleThread → MultiThreads → DMA → SIMD → **Unroll** → DoubleBuffer——注意这里第 5 步是 Unroll（循环展开）而不是 Matmul/Broadcast，因为纯 elementwise 计算没有矩阵乘法单元可用，循环展开是这类算子在 SIMD 之后的下一个可用手段。

## 数据分块

计算总量 `data_num` 均分给各线程，每个线程处理 `per_spe_num` 个元素——这是最简单的静态均分，不涉及 GEMM/Conv 案例中"沿某一维度切块 + 广播共享数据"的复杂性，因为 elementwise 计算的每个输出元素只依赖对应位置的输入，天然没有数据复用的机会。

## 双缓冲流水设计

创建 2 个数据搬运句柄与缓存空间，通过异步接口让访存和计算并行进行（t 时刻搬运数据、t+1 时刻计算，与下一批数据的搬运重叠）：

```
总计算任务量为data_num
每个线程计算量为per_spe_num，对应区间[start, end]，步长为单次能计算的最大值max_blk
异步搬运参与首次计算的A、C数据
for (i = start; i < end; i += max_blk):
    等待上次数据搬运完成
    交换缓冲区
    另一块缓冲区ADBUF开始下次数据异步搬运
    当前缓冲区CDBUF开始计算
    将CDBUF的计算结果从SPM异步搬运到Global存储
```

这个骨架是 `kernel-teco-al-gemm`/`kernel-teco-al-conv-forward` 双缓冲循环的简化版：没有 K 维度累加、没有广播等待、没有矩阵乘法单元调用，只有"搬运下一块 / 计算当前块 / 写回上一块结果"三件事情交替进行——建议先理解本页的双缓冲骨架，再去看 GEMM/Conv 案例中在此基础上叠加的额外机制，比直接从最复杂的 GEMM 案例入手更容易建立正确的心智模型。

## 真实性能数据（CI 环境实测）

| 分支 | userAPI时间(us) | 相对上一步加速比 |
|---|---|---|
| SingleThread | 1,479,308 | — |
| MultiThreads | 54,417 | 27.2x |
| DMA | 2,035 | 26.7x |
| SIMD | 209 | 9.7x |
| Unroll | 143 | 1.5x |
| DoubleBuffer | 128 | 1.1x |

与 `technique-teco-al-algo-branch-benchmarking` 中三个案例横向对比一致：早期步骤（MultiThreads、DMA）收益最大，Unroll/DoubleBuffer 阶段已进入边际递减区间。对于计算强度极低的纯 elementwise 算子，这也提示一个通用结论：**访存优化（DMA 异步化）通常比计算侧优化（SIMD 之后的进一步手段）贡献更大的早期收益**，因为 elementwise 算子天生是访存瓶颈而非计算瓶颈。
