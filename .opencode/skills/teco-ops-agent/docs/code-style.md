# Code Style

本文件是项目级代码规范。生成或修改 `.swcu` / `.h` / `.hpp` / `.cpp` 前必须先阅读本文件，并按本文件约束实现。

## 适用范围

- `swdnn_test_ops/src/**`
- `ops/**/scripts` 中生成 C/C++/SWCU 代码的脚本或模板
- 所有新算子、算子优化、学习验证产物中的 C/C++/SWCU 代码

## 基础格式

- 遵守 Google C++ Style 的基本格式。
- 一行只写一条语句，禁止 `a = b; c = d;` 放同一行。
- 运算符两侧留空格：`a = b + c`，不是 `a=b+c`。
- 禁止尾随空格。
- 缩进使用 4 个空格，保持现有文件风格一致。
- 新代码默认使用 ASCII。除非文件已有非 ASCII 内容或业务文本必须使用中文，否则代码标识符和注释不要引入非 ASCII。
- 注释只解释不明显的硬件约束、地址映射、同步/ownership，不写“给变量赋值”这类空注释。

## 命名规范

- 函数、局部变量、指针、reply 变量使用 `snake_case`。
  - 示例：`c_accum`、`a_tile`、`wait_dma_reply`。
- 常量使用 `UPPER_SNAKE_CASE`。
  - 示例：`SLAVE_CORE_NUM`、`ROWS`、`COLS`。
- 不使用无语义的 `k` 前缀作为常量命名习惯。
  - 禁止：`kMTile`、`kMacroKTile`、`kAceKStep`。
  - 推荐：`M2`、`K1`、`K3`。
- Host 侧固定 shape 可以直接使用 `M/N/K`；kernel 参数仍用小写 `m/n/k`。
- 变量名应体现数据所在空间或用途。
  - HBM 指针：`a_hbm`、`c_hbm`。
  - LDM tile：`a_tile`、`b_tile`、`c_tile`。
  - RMA 接收区：`c_rma_0`、`c_rma_1`。

## GEMM 分块命名

GEMM / GEMMEX 中按层级命名 tile，避免混用 `tile`、`macro`、`step`：

| 层级 | 含义 | 命名 |
|------|------|------|
| 核组 macro tile | 一个 32 SPE 组共同覆盖的 M/N/K 范围 | `M1` / `N1` / `K1` |
| 单 SPE tile | 一个 SPE 单次 ACE 主计算覆盖的 M/N/K 范围 | `M2` / `N2` / `K2` |
| ACE 内层 step | ACE 每次 north/west step 的 K 粒度 | `K3` |
| 2D 分核维度 | SPE grid 的行列数 | `ROWS` / `COLS` |

示例：

```cpp
constexpr int SLAVE_CORE_NUM = 32;
constexpr int M = 2048;
constexpr int N = 2048;
constexpr int K = 8192;
constexpr int ROWS = 4;
constexpr int COLS = 8;
constexpr int M2 = 96;
constexpr int N2 = 32;
constexpr int K2 = 512;
constexpr int M1 = M2 * COLS;
constexpr int K1 = K2 * ROWS;
constexpr int K3 = 32;
```

规则：

- `M2/N2/K2` 必须表示单 SPE tile，不用于 32 核组总 tile。
- `M1/N1/K1` 必须表示核组层级；如果某一轴没有 macro 概念，不要强行定义。
- `K3` 固定表示 ACE 内层 K step，通常为 32。
- `ROWS/COLS` 只表示 2D SPE grid，不表示矩阵行列。

## Device Kernel 结构

- 单文件算子应保持顺序：全局常量、`__device__` helper、`__global__` kernel、host test driver。
- `__global__` 函数命名为 `teco_slave_<op>`。
- 使用 `_PEN` 获取 SPE id；需要 2D grid 时使用 `_ROW` / `_COL`。
- helper 函数优先 `static __device__ inline __attribute__((always_inline))`。
- 不引入 args struct / namespace 作为新单文件算子的参数封装。

## DMA / RMA / ACE 规则

- DMA/RMA reply 必须在复用前清零。
- wait 点卡消费者，不要在发起 next DMA 后立刻 wait next。
- 使用 `rt_rma_iput` / `rt_rma_iget` 时必须使用 `__rt_local_rply` / `__rt_remote_rply`，禁止把普通局部 `volatile int` 作为远端 reply。
- 批量 RMA 写远端时，远端接收 buffer 必须分区，禁止多个 pending RMA 写同一地址。
- `rt_ace_writeback` 的 precision flag 直接传 `0` 或 `1`，禁止生成 `ACE_PREC`。
- `rt_ace_writeback` 的 `Ysize` 是行数，不是字节数。
- ACE west load stride 按 rt 接口口径使用 `K / 32 - 1` 一类表达，禁止混用底层描述符的 `+1` 语义。

## SIMD 规则

- 涉及 `simd_load` / `simd_store` / 向量运算的循环，必须使用 8x 展开或等效软件流水。
- 禁止朴素 1x 循环：`for (i += 16) { load; add; store; }`。
- 写 SIMD 前先确认 P0/P1 流水排布，避免同下标 add 和 store 的 RAW 依赖导致无法双发。

## 性能尝试与回退

- 性能优化必须保留正确性门禁：L3 `success_rate == 1.0`。
- 如果优化尝试精度通过但 benchmark 回退，主实现必须回退到最佳已验证版本。
- 回退不是丢弃信息：必须在 `swdnn_test_ops/op_learning/<topic>/learned_patterns.md` 和 `stage_results/<stage>.json` 记录：
  - 尝试内容
  - 性能前后对比
  - 回退原因
  - 下一步建议
- 不把性能回退的实现留在交付路径中，除非用户明确要求保留用于调试。

## 文档同步

- 修改 tile、分核、LDM buffer、DMA/RMA/ACE 数据流后，同步更新 `op_design/<op>/design.json` / `design.md`。
- 单点优化验证后，同步更新对应 `op_learning/<topic>/learned_patterns.md` 和 `stage_results/<stage>.json`。
- 长期稳定经验才提升到 `ops/sdaa-op-learning-validation/references/learned-patterns/`；失败或回退只记录为过程经验。
