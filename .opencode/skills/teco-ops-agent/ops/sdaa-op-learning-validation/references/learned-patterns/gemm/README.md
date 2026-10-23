# GEMM / GEMMEX / MatMul Pattern 路由索引

本文件是 GEMM 算子族的 Preflight 路由入口。GEMM 领域 composite pattern 保存在本目录，
DMA、RMA、ACE、SIMD 和 pipeline 的机制正文仍保存在各自机制目录；索引只定义开发前的检查顺序。

## 开发前检查顺序

| 代码或 shape 信号 | 优先读取 | 需要判断的问题 |
|---|---|---|
| M/N 二维分核并沿 K 拆分 | `gemm/2d-splitk-c-rma-reduce.md` | partial C 的列内 RMA gather、quarter reduce 和唯一写回是否闭合 |
| 同一 A tile 扫多个 N panel | `gemm/a-reuse-across-n.md` | loop 顺序能否让 A 跨 N 复用，避免重复 HBM load |
| 多列 SPE 共享 B panel | `gemm/b-row-ring-panel-sharing.md` | row-ring ownership、转发方向和每轮消费 panel 是否一致 |
| K loop 的 A/B DMA 与 ACE 串行 | `pipeline/ab-dma-double-buffer-ace-gemm.md` | ping/pong buffer、reply 和下一 K tile announce 是否可重叠 |
| B panel 转发暴露在 ACE/C reduce 外 | `pipeline/b-row-ring-forward-overlap.md` | ACE consume 后能否提前 issue RMA，并避免与 C reduce reply 冲突 |
| split-K partial C 本地规约 | `simd/c-quarter-reduce-fp32.md` | FP32 vector reduce 的展开、对齐、tail 与寄存器压力是否合适 |

## 领域边界

- 本索引覆盖 GEMM、GEMMEX、MatMul 与矩阵乘类 kernel。
- ACE tile、DMA/RMA、LDM 和 SIMD 单机制规则仍由对应机制目录维护。
- 领域 composite pattern 只有在多个机制形成已验证 GEMM 数据流时才保存在 `gemm/`。
- 索引中的 pattern 必须有长期 evidence；未验证候选继续保存在过程层 `op_learning/`。

## Preflight 自动触发信号

`GEMM`、`GEMMEX`、`MatMul`、`matrix multiply`、`矩阵乘`。

这些信号与“优化、实现、开发、修改”等代码动作词同时出现时，即使用户没有写“算子”或
“kernel”，UserPromptSubmit hook 也会自动触发 GEMM 路由。纯“测试 matmul”或“benchmark gemm”
不触发实现 Preflight，而是进入对应测试 skill。
