---
id: source-teco-ops-agent-ops-sdaa-op-template-references-device-parallel-patterns-fb669b54
title: "teco-ops-agent ops: sdaa-op-template/references/device-parallel-patterns.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/device-parallel-patterns.md
relative_source_path: sdaa-op-template/references/device-parallel-patterns.md
captured_at: 2026-08-04
---

# Device 并行与多遍 Kernel 通用模式

## SPE 索引：`_PEN` vs `rt_tid`

| API | 典型用途 |
|-----|----------|
| `rt_tid` / `tid` | 单次分块：elewise `begin/end` |
| `_PEN` | 跨行 stride：`for (row = _PEN; row < rows; row += slave_core_num)` |

**反模式**：reduce / row-wise 算子只在 `tid==0` 或只处理 `row=tid` 一行 → 其余行输出保持 host `memset(0)`。

**检查**：`verify_not_all_zero_*` 报 partial zeros → 查循环上界与 stride。

## Elewise 分块模板

```cpp
const int total = ...;
const int cores = arg.slave_core_num;
const int chunk = (total + cores - 1) / cores;
const int begin = tid * chunk;
const int end = min(begin + chunk, total);
```

保证 `union [begin,end)` 覆盖 `[0,total)` 且无重叠。

## Row-wise reduce 模板

```cpp
for (int row = _PEN; row < arg.rows; row += arg.slave_core_num) {
    const T *row_x = x + (size_t)row * arg.cols;
    T *row_y = y + (size_t)row * arg.cols;
    // per-row: tile along cols
}
```

`args.slave_core_num` 与 device 循环一致（通常 32）。

## 多遍流水（通用）

适用于：max → 非线性 → sum → normalize 等。

```
Pass1: read x  → partial stats (e.g. max)
Pass2: read x  → write intermediate to y (or temp)
Pass3: read y  → normalize → write y
```

| 原则 | 说明 |
|------|------|
| 分离 LDM | 输入 / 中间 / 累加器分 buffer |
| 行级原子性 | 一行内各 pass 完成后再处理下一行 |
| 勿 early-continue 整行 | `sum<=0` 时若 `continue` 且未写 `y`，该行全 0 |
| 标量在 float | `inv_sum` 用 float，再 `batch_Smul_a` |

## DMA 对齐分支（fp16 等）

```cpp
const int bytes = elems * (int)sizeof(half);
if ((bytes & 3) == 0 && (((uintptr_t)dst | (uintptr_t)src) & 3) == 0)
    rt_dma_get(...);
else
    rt_unaligned_dma_get(...);
```

首轮验证用对齐 `cols` 可简化路径；奇数维作为 **L3 压力阶段** 再加。

## Args 命名空间

Kernel 签名建议全限定：

```cpp
__global__ void teco_slave_my_op_float(tecoblas::ual::ops::MyOpArgs arg);
```

Demo 侧：`using namespace tecoblas::ual::slave;` 以便调用 `teco_slave_*`。
