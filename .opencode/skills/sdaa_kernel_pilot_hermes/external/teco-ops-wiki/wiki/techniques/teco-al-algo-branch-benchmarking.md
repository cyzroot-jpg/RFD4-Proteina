---
id: technique-teco-al-algo-branch-benchmarking
title: "Teco-AL 分支递进式性能优化方法论"
type: technique
architectures: [sdaa, teco-t1]
tags: [teco-al, algo-dispatch, benchmarking, tecotest, single-thread, multi-thread, dma, simd, matmul, broadcast, double-buffer]
confidence: verified
reproducibility: benchmarked
related: [kernel-teco-al-gemm, kernel-teco-al-conv-forward, kernel-teco-al-add-tensor, technique-teco-ops-interface-ual-layering]
sources: [doc-teco-al-docs-p05, doc-teco-al-docs-p06, doc-teco-al-docs-p07, doc-teco-al-docs-p01]
aliases: ["algo 分支", "性能递进", "tecotest benchmark"]
---

# Teco-AL 分支递进式性能优化方法论

Teco-AL 的三个完整讲解范例（`add_tensor`、`gemm`、`conv_forward`，见 `kernel-teco-al-add-tensor`/`kernel-teco-al-gemm`/`kernel-teco-al-conv-forward`）都采用同一套"分支递进"模式：每个算子实现多个 `TECOAL_ALGO_N` 分支，每个分支对应一种逐步加码的优化手段，并在设计文档中用同一张 host/userAPI 时间对照表记录每一步的真实收益。这是一套可直接复用的通用优化路线模板。

## 标准递进序列

三个范例呈现的分支顺序高度一致，可归纳为一个通用序列（各算子按自身计算特征增删中间步骤）：

1. **SingleThread**：单线程串行实现，仅用于验证正确性，不追求性能。
2. **MultiThreads**：多线程并行，任务均衡分配到各 SPE。
3. **DMA**：引入异步数据搬运，减少访存阻塞。
4. **SIMD**：使用向量指令替代标量运算。
5. **Matmul**（仅计算可转化为矩阵乘的算子，如 gemm、conv_forward 的 1x1 卷积分支）：使用矩阵乘法加速单元。
6. **Broadcast**：用广播替代各线程重复读取共享数据。
7. **DoubleBuffer**：双缓冲流水，重叠访存与计算。

`gemm` 在 Broadcast 之后额外插入"数据重排（Permute）"步骤（因矩阵乘法单元要求 localbn > 32 时数据需重排），`conv_forward` 在最前面额外插入"计算转换（conv-to-gemm 等价变换）"步骤——说明这套序列是可按算子特征插入/省略步骤的模板，而非固定管线。

## 真实性能数据对照（CI 环境实测，三个范例并列）

| 优化阶段 | add_tensor userAPI时间(us) | gemm userAPI时间(us) | conv_forward userAPI时间(us) |
|---|---|---|---|
| SingleThread | 1,479,308 | 42,406,765 | 31,436,209 |
| MultiThreads | 54,417 | 1,746,017 | 2,195,753 |
| DMA | 2,035 | 38,203 | 37,050 |
| SIMD | 209 | 7,757 | 2,861 |
| Matmul | — | 177 | 120 |
| Broadcast | — | 90 | 119 |
| Unroll / Permute | 143（Unroll） | — | — |
| DoubleBuffer | 128 | 64 | 116 |

三者的共同规律：**MultiThreads → DMA → SIMD 这几步的收益最大**（每步常有一到两个数量级的提升），而进入 Matmul/Broadcast/DoubleBuffer 阶段后收益迅速收窄——例如 gemm 从 Matmul(177us) 到 Broadcast(90us) 到 DoubleBuffer(64us) 每步仍在下降但降幅已远小于早期步骤；conv_forward 到了 Matmul(120us)/Broadcast(119us)/DoubleBuffer(116us) 阶段三者几乎持平。三张表里最终分支都仍比前一分支快（严格单调递减），但边际收益递减规律明显：早期步骤（尤其是引入 DMA 与 SIMD）是性价比最高的优化，后期步骤（Broadcast/DoubleBuffer）更多是在已经很快的基础上做精细收尾。

## host 时间保持恒定的含义

三张表中 host 时间始终维持在同一量级（add_tensor ≈81000us，gemm ≈400000us，conv_forward ≈415000us），跨越所有 `algo` 分支几乎不变——这是测试框架固定的启动/初始化/同步开销，与 kernel 本身性能无关。真正应该比较的是 **userAPI 时间**（对应 `doc-teco-ops-docs-p04` 中 tecotest 框架 perf sheet 的 `hardware time`/`interface time` 概念），host 时间不能反映优化效果，容易造成"看起来没变化"的误判。

## 复用到新算子开发的建议

1. 先用 SingleThread 分支把正确性跑通，再逐步加优化，不要跳过中间步骤直接写复杂实现——每一步都应该产出一条可比较的性能数据。
2. 每加一个分支就用 `unit_test_v2.py`（见 `doc-teco-al-docs-p01`）重新测一次，把 userAPI 时间记入设计文档的性能数据表，而不是只凭直觉判断"这样应该更快"。
3. 当收益进入边际递减阶段（如三个范例中 Matmul 之后的几步），继续投入精细优化前先评估性价比——`gemm`/`conv_forward` 到 Matmul 分支已经把 userAPI 时间压到两位数微秒，此后 Broadcast/DoubleBuffer 每步的绝对收益已经很小，是否值得继续优化取决于该算子在整体工作负载中的占比。
