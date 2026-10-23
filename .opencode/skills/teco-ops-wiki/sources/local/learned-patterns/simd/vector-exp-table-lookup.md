---
id: local-learned-pattern-simd-vector-exp-table-lookup
title: 查表法向量 exp（`vexp_prec_table_2_fast`）
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/simd/vector-exp-table-lookup.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/simd/vector-exp-table-lookup.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- simd
- vector
- exp
- table
- lookup
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: needs_revalidation
pattern_type: optimization
---

# Pattern: 查表法向量 exp（`vexp_prec_table_2_fast`）

## 状态

needs_revalidation

## 类型

optimization

## 问题

attention kernel 的 softmax 或其他需要逐元素 exp 的阶段，如果每个标量调 `expf()`（32 次/tile × `q_per_kv` 行），标量 exp 延迟会串行堆积。需要一种批量向量化的 exp 方法，同时精度不能明显劣于标量 `expf`。

## 适用场景

- 需要对两个 `floatv16` 向量（共 32 个 float）做批量 exp。
- exp 输入范围在 `[-INF, ~20]` 以内（如 softmax 的 `score - max`）。
- LDM 能留出 ~10KB 给 exp table（2496 个 float）。
- 精度要求对标 `expf`，误差在 1e-5 量级以内。

## 不适用场景

- LDM 紧张（<15KB 余量），无法腾出 10KB table 空间。
- 只需单个 `floatv16` 的 exp（setup 开销摊不平）。
- exp 输入极值范围超出 table 覆盖（如 >20）。

## 核心思路

用多项式近似 + 查表组合替代标量 `expf`：预先在 LDM 上构建分段多项式系数表和指数部分查找表（`init_exp_zb_fast`），运行时通过 `vexp_prec_table_2_fast` 一次处理 2 个 `floatv16` 向量。

## 实现规则

### Table 初始化（kernel 启动时调用一次）

```cpp
#include "flash_attention_general.hpp"
// 或 #include "fa3_common.h"

float *exp_table = lmem_malloc<float>(/* 2496 */);
LMK::FLA3GEN::init_exp_zb_fast(exp_table);
```

Table 大小恒为 2496 floats = 9984 bytes ≈ 10KB。所有调用者共享同一份初始化逻辑。

### 运行时调用

```cpp
floatv16 exp_in[2] = {p0, p1};          // 每次处理 32 个 float
vexp_prec_table_2_fast(exp_in, exp_table);
p0 = exp_in[0];                          // exp(p0)
p1 = exp_in[1];                          // exp(p1)
```

### 算法概要（来自 `flash_attention_general_utils.h`）

```
exp(x) 分解为:
  1. x' = x × log2(e)           // 换底到 2
  2. k  = floor(x')              // 整数部分（2 的幂次）
  3. f  = x' - k                 // 小数部分 ∈ [0, 1)
  4. exp(x) = 2^k × 2^f         // 2^k 用查表，2^f 用多项式近似

多项式: c0 + f×(c1 + f×(c2 + f×(c3 + f×c4)))
```

## 伪代码

### 在 online softmax 中使用

```cpp
// 替换标量 expf 循环
floatv16 exp_in[2] = {scores_sub_max_0, scores_sub_max_1};
vexp_prec_table_2_fast(exp_in, exp_table);
// exp_in[0], exp_in[1] 现在包含 exp(scores - max)

// 可直接转为 half 供后续 ACE 使用
halfv16 ph0 = simd_pseudo_vfcvtsh(exp_in[0]);
halfv16 ph1 = simd_pseudo_vfcvtsh(exp_in[1]);
```

## 代码中的两种变体

| 变体 | 文件 | 特点 |
|------|------|------|
| `vexp_prec_table_2_fast` | `flash_attention_general_utils.h:60` | 高精度（~1e-7），多项式近似，2×floatv16 输入，每次调 `simd_seleq` 9 次 |
| `vexp_opt_table_acc` | `flash_decoding.h` | 快速路径，精度略低，用于 decode |

选择建议：prefill 用 `vexp_prec_table_2_fast`（精度优先），decode 或 latency-critical 用 `vexp_opt_table_acc`。

## 常见坑

- Table 在 `lmem_reset()` 后需要重新初始化（`lmem_reset` 清空 LDM 分配表，但不一定清零数据——保险起见每次 `lmem_reset` 后重新 `init_exp_zb_fast`）。
- 正确引用路径位于 flash_attention_general 或 fa3_common 头文件中。
- Table 大小硬编码为 2496。不要假定可以减小——减小会破坏查表偏移和多项式分段。
- 输入必须先减 max（softmax 场景）再传，exp 本身不处理数值稳定性。

## 验证

- 来源：`flash_mla_sparse` online softmax v7b 将 32 次标量 `expf` 替换为 `vexp_prec_table_2_fast`。
- 精度：DS4 smoke + tile sweep + 8192/64k all-head accuracy PASS，与标量 `expf` golden 误差在 1e-5 量级内。
- 性能：q_head=16, q_seq=65536 从 347.817 ms 降到 342.650 ms（v7b P-half pack 融合前），exp 替换是 v5 降维的主要贡献之一。
- 当前缺少只改变 exp 实现的独立 before/after 性能对照，因此降级为 `needs_revalidation`。
- evidence: simd-v1-fast-exp-table

## 来源沿革

- revision 未记录，`flash_attention_general_utils.h::vexp_prec_table_2_fast`。
- revision 未记录，`flash_attention_general.hpp::init_exp_zb_fast`。
- 原始正确性 stage 已蒸馏到 evidence `simd-v1-fast-exp-table`；补齐独立性能证据前不得作为默认优化。

## 相关模式

- `simd/online-softmax-tile-microkernel`：使用此 exp 的 online softmax 完整方案。
- `simd/c-quarter-reduce-fp32`：类似向量化数值计算的 SIMD pattern。
