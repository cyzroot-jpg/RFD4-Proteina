---
id: kernel-teco-al-gemm
title: "Teco-AL Hgemm：分块 + 广播 + 重排 + 双缓冲的完整优化路线"
type: kernel
architectures: [sdaa, teco-t1]
kernel_types: [gemm, matmul]
confidence: verified
languages: [sdaa-c, cpp]
related: [technique-teco-al-algo-branch-benchmarking, kernel-teco-al-conv-forward, kernel-teco-al-add-tensor]
sources: [doc-teco-al-docs-p06, doc-teco-al-docs-p02]
---

# Teco-AL Hgemm：分块 + 广播 + 重排 + 双缓冲的完整优化路线

`tecoalHgemm`（`doc-teco-al-docs-p06`）是 Teco-AL 三个完整讲解范例之一，也是 Teco-AL 仓库中优化幅度最大的公开案例：从单线程基线 42,406,765us 优化到双缓冲分支的 64us，userAPI 时间缩短约 66 万倍。完整分支进度见 `technique-teco-al-algo-branch-benchmarking`；本页聚焦其独有的分块/广播/重排设计。

## 计算与接口

标准 GEMM：`C = alpha*op(A)*op(B) + beta*C`，`op()` 为可选转置。`tecoalHgemm(handle, transa, transb, m, n, k, alpha, A, lda, B, ldb, beta, C, ldc, algo)`，float16 输入、行优先存储（NCHW），当前仅支持 `alpha=1`、`beta=0`。

## 三个关键设计（Matmul 分支之后）

### 1. 数据分块（Tiling）

计算总量是整个矩阵 C 的更新。分块发生在两个层级：
- SPA 层：单次循环计算 `bM × bN` 的 C 子块。
- SPE 层：SPA 内单个 SPE 在单次循环中计算 `localbM × localbN`。

### 2. 数据广播（Broadcast）

依次遍历 `bm/bn/bk` 小块时，同一行/列方向的多个 SPE 会重复用到相同的 A、B 子块。与其让每个 SPE 各自从 Global 重复读取，改为"分工读取 + 广播"——一个 SPE 读一次，广播给同行/列其余 SPE。行列广播方向可依据矩阵形状和线程组特点动态适配，这是本设计比朴素分块更进一步的地方。

### 3. 数据重排（Permute）

矩阵乘法加速单元对 `localbn` 维度有约束：超过 32 时必须先做数据重排（permute），计算完成后矩阵 C 也要对应重排回目标 layout。这是 Matmul 分支能加速、但需要额外开销维持正确性的关键代价——如果新算子也打算接入矩阵乘法单元且 tile 宽度可能超过 32，需要提前规划重排开销，不能假设"接入 Matmul 单元就是纯收益"。

## 主循环伪代码骨架

```
pA pB pC 分别为矩阵ABC的指针，pCurr/pNext 用于双缓冲
在SPM上分配矩阵ABC的双缓冲、重排空间
对矩阵AB进行首次计算数据的行列广播，Global -> SPM
for (idx in [0, nM*nN)):           // 遍历 bM,bN 小块
    idM, idN = idx / nN, idx % nN
    for (idK in [0, nK)):            // 遍历 bK 维度
        pCurrA, pCurrB = A[idM][idK], B[idK][idN]
        更新 pNextA/pNextB 指针（下一块）
        交换 AB 的计算/访存区域（双缓冲）
        等待 localbM/localbN/localbK 数据广播加载完成
        广播预取下一块 pNextA/pNextB
        重排 B 矩阵结构
        矩阵乘法单元计算（最后一次做写回，此前仅累加）
    对结果矩阵C进行精度转换、内存重排与写回
```

The broadcast prefetch for the next block overlaps the current matrix multiply,
and C is written only after the final K iteration. Verify this double-buffering
and reduced-writeback pattern against the bundled Teco-AL source.

## Evidence boundary

This page covers the reproducible public `interface` + `ual` route implemented
with `tecoalHgemm` and official matmul/broadcast interfaces. It does not claim a
register-level hardware upper bound. Inspect upstream source when that evidence
is required.
