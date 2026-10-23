---
id: source-teco-ops-agent-ops-sdaa-op-template-references-elewise-device-pattern-93f942b7
title: "teco-ops-agent ops: sdaa-op-template/references/elewise-device-pattern.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/elewise-device-pattern.md
relative_source_path: sdaa-op-template/references/elewise-device-pattern.md
captured_at: 2026-08-04
---

# Elewise device 实现模式（matrix_add 验证）

> 从 `elewise` 脚手架 TODO 桩演进到可编译实现的推荐首版写法。

## 适用

- 逐元素二元：`C = A ⊙ B`（`batch_Sadd` / `batch_Smul` 等）
- 逐元素一元：`Y = f(X)`（`batch_Smul_a` 等）
- 矩阵/张量按 **行优先展平** 为 `total = rows * cols` 连续向量

## Args 结构（二元示例）

```cpp
typedef struct MatrixAddArgs {
    int slave_core_num;  // 32
    int rows;
    int cols;
    const void *a;
    const void *b;
    void *c;
} MatrixAddArgs;
```

一元脚手架生成的 `alpha/beta/x/y` 需按算子语义改掉。

## SPE 划分

```cpp
const int total = arg.rows * arg.cols;
const int cores = arg.slave_core_num;
const int chunk = (total + cores - 1) / cores;
const int begin = tid * chunk;
const int end = begin + chunk < total ? begin + chunk : total;
```

与 SPMD、`threadIdx/threadDim` 语义一致。

## LDM 与 tile 大小

| 项 | matrix_add 取值 | 说明 |
|----|-----------------|------|
| `kTileElems` | 1024 | 单次 DMA 元素数 |
| LDM 缓冲 | 3 × 1024 × 4B ≈ 12KB | A/B/C 各一块 |
| SPE LDM 上限 | 256KB | 留足栈与 malloc 余量 |

更大 tile 需对照 `rt_ldm_malloc` 预算与 DMA 8–16KB 最优块。

## 核心循环（阻塞 DMA 首版）

```cpp
for (int offset = begin; offset < end; offset += kTileElems) {
    const int tile_elems = min(kTileElems, end - offset);
    const int tile_bytes = tile_elems * (int)sizeof(float);

    rt_dma_get(a_ldm, a + offset, tile_bytes);
    rt_dma_get(b_ldm, b + offset, tile_bytes);
    batch_Sadd(a_ldm, b_ldm, c_ldm, tile_elems);
    rt_dma_put(c + offset, c_ldm, tile_bytes);
}
```

- `rt_dma_*` 的 `len` = **字节**
- `batch_*` 的 `len` = **元素个数**
- 进阶：双缓冲改用 `rt_dma_iget` + `rt_dma_wait_value`（见 librt skill）

## 头文件

```cpp
#include "common/ual/args/<op>_args.h"
#include "rt.h"
#include "tecokernel.h"
```

## 常见错误

| 现象 | 原因 |
|------|------|
| DMA 对齐错误 | `tile_bytes` 非 4 的倍数 |
| LDM 溢出 | 单 SPE 同时 malloc 过大 |
| 精度全错 | `begin/end` 划分与 host shape 不一致 |
| 仅 tid0 有结果 | `slave_core_num` 与划分逻辑不匹配 |
