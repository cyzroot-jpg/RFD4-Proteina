---
id: doc-sdaa-c-programming-guide-v3-1-0-p05c
title: "SDAA C 编程指南 v3.1.0 — 第5部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "16590-17319"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [memory, perf-sampling, programming-model, sdaa, sdaa-c, simd-vectorization, teco-t1]
---

# SDAA C 编程指南 v3.1.0（第5部分）

> 本部分覆盖 ch7 函数接口章节，内容衔接自 SIMD 取负（simd_neg）接口的返回值说明，包含按位运算类操作（7.10.12）与性能采样（7.11）。

## 7.10.11 simd_neg（续：返回值与示例）

> 说明：本片段衔接自 `simd_neg` 接口（取负/按位取负），此处给出其返回值类型表、注意事项与全部使用示例。

### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32、floatv16、halfv16 | 参数对应的向量类型。<br>输入向量 va 的元素中含有 NaN 时，该位置对应返回 -NaN。<br>输入向量 va 的元素中含有 +∞ 时，该位置对应返回 −∞ 。<br>输入向量 va 的元素中含有 −∞ 时，该位置对应返回 +∞ 。 |

### 注意事项

- 该接口支持原位操作。
- 可以使用运算符 `-` 进行平替。

### 使用示例 1

```c
intv16 va = {1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2};
intv16 vb = simd_neg(va);
// vb 是 [-1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2]
```

### 使用示例 2

```c
intv16 va = {1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2};
va = simd_bnot(va);    // 原位操作
// va 是 [-1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2]
```

### 使用示例 3

```c
shortv32 va = {1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2, 1, -2};
shortv32 vb = simd_neg(va);
// vb 是 [-1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2, -1, 2]
```

### 使用示例 4

```c
floatv16 va = {2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1};
floatv16 vb = simd_neg(va);
// vb 是 [-2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1]
```

### 使用示例 5

```c
halfv16 va = {2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1, 2.0, -0.1};
halfv16 vb = simd_neg(va);
// vb 是 [-2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1, -2.0, 0.1]
```

## 7.10.12 按位运算类操作

### 7.10.12.1 simd_band

```c
intv16 simd_band(intv16 va, intv16 vb)
shortv32 simd_band(shortv32 va, shortv32 vb)
```

#### 功能介绍

对向量 va 和 vb 的对应元素进行按位与计算后，返回结果向量。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| va | intv16、shortv32 型向量。 |
| vb | intv16、shortv32 型向量。 |

#### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32 | 参数对应的向量类型。 |

#### 注意事项

- 该接口支持原位操作。
- 可以使用算数运算符 `&` 进行平替。

#### 使用示例 1

```c
intv16 va = {1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
intv16 vc = simd_band(va, vb);
// vc 是 [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
```

#### 使用示例 2

```c
intv16 va = {1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
va = simd_band(va, vb);    // 原位操作
// va 是 [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
```

#### 使用示例 3

```c
shortv32 va = {1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2};
shortv32 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
shortv32 vc = simd_band(va, vb);
// vc 是 [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
```

### 7.10.12.2 simd_bxor

```c
intv16 simd_bxor(intv16 va, intv16 vb)
shortv32 simd_bxor(shortv32 va, shortv32 vb)
```

#### 功能介绍

对向量 va 和 vb 的对应元素进行按位异或计算后，返回结果向量。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| va | intv16、shortv32 型向量。 |
| vb | intv16、shortv32 型向量。 |

#### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32 | 参数对应的向量类型。 |

#### 注意事项

- 该接口支持原位操作。
- 可以使用算数运算符 `^` 进行平替。

#### 使用示例 1

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
intv16 vc = simd_bxor(va, vb);
// vc 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

#### 使用示例 2

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
va = simd_bxor(va, vb);    // 原位操作
// va 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

#### 使用示例 3

```c
shortv32 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
shortv32 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
shortv32 vc = simd_bxor(va, vb);
// vc 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

### 7.10.12.3 simd_bor

```c
intv16 simd_bor(intv16 va, intv16 vb)
shortv32 simd_bor(shortv32 va, shortv32 vb)
```

#### 功能介绍

对向量 va 和 vb 的对应元素进行按位或计算后，返回结果向量。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| va | intv16、shortv32 型向量。 |
| vb | intv16、shortv32 型向量。 |

#### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32 | 参数对应的向量类型。 |

#### 注意事项

- 该接口支持原位操作。
- 可以使用算数运算符 `|` 进行平替。

#### 使用示例 1

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
intv16 vc = simd_bor(va, vb);
// vc 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

#### 使用示例 2

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
va = simd_bor(va, vb);    // 原位操作
// va 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

#### 使用示例 3

```c
shortv32 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
shortv32 vb = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
shortv32 vc = simd_bor(va, vb);
// vc 是 [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3]
```

### 7.10.12.4 simd_bnor

```c
intv16 simd_bnor(intv16 va, intv16 vb)
shortv32 simd_bnor(shortv32 va, shortv32 vb)
```

#### 功能介绍

对向量 vb 中的各元素进行按位取反操作后，再与 va 对应的元素进行按位或运算，返回结果向量。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| va | intv16、shortv32 型向量。 |
| vb | intv16、shortv32 型向量。 |

#### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32 | 参数对应的向量类型。 |

#### 注意事项

- 该接口支持原位操作。
- 可以使用算数运算符 `| ~` 进行平替。

#### 使用示例 1

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
intv16 vc = simd_bnor(va, vb);
// vc 是 [-1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2]
```

#### 使用示例 2

```c
intv16 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
intv16 vb = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
va = simd_bnor(va, vb);    // 原位操作
// va 是 [-1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2]
```

#### 使用示例 3

```c
shortv32 va = {0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2};
shortv32 vb = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
shortv32 vc = simd_bnor(va, vb);
// vc 是 [-1.0, -2.0, -1.0, -2.0, -1.0, -2.0, -1.0, -2.0, -1.0, -2.0, -1.0, -2.0, -1.0, -2.0, -1.0, -2.0]
```

### 7.10.12.5 simd_bnot

```c
intv16 simd_bnot(intv16 va)
shortv32 simd_bnot(shortv32 va)
```

#### 功能介绍

对向量 va 中各元素进行按位取反计算后，返回结果向量。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| va | intv16、shortv32 型向量。 |

#### 返回值

| 返回值类型 | 说明 |
|------------|------|
| intv16、shortv32 | 参数对应的向量类型。 |

#### 注意事项

- 该接口支持原位操作。
- 可以使用算数运算符 `~` 进行平替。

#### 使用示例 1

```c
intv16 va = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
intv16 vb = simd_bnot(va);
// vb 是 [-1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2]
```

#### 使用示例 2

```c
intv16 va = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
va = simd_bnot(va);    // 原位操作
// va 是 [-1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2]
```

#### 使用示例 3

```c
shortv32 va = {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1};
shortv32 vb = simd_bnot(va);
// vb 是 [-1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2, -1, -2]
```

## 7.11 性能采样

### 7.11.1 概述

性能采样利用 perf_start 和 perf_stop 函数接口，通过指定太初 AI 加速卡中的性能寄存器的取值，从而获取特定代码片段中的性能数据，用户可以通过使用 perf_print 接口将采集到的性能数据打印到终端。性能采样操作使用灵活，接口简单，可以满足用户对性能分析的需求。

性能分析操作由以下函数接口组成：

- **perf_start**：开始性能采样接口，通过此接口标识性能采样的起始位置。
- **perf_stop**：结束性能采样接口，通过此接口标识性能采样的结束位置。
- **perf_print**：在终端界面输出采集到的性能数据（延时拍数和指令缓存脱靶次数）。
- **clock**：获取当前 SPE 内时钟周期计数器的值。

### 7.11.2 perf_start

```c
void perf_start()
```

#### 功能介绍

标识性能采样的起始位置。

#### 参数解释

无。

#### 返回值

无。

#### 注意事项

- 需要手动包含 `sdaa_perf.h` 头文件。
- perf_start 需要与 perf_stop 配合使用，并且需要一一对应，不支持嵌套使用。

#### 使用示例

以统计某段循环加法代码的执行周期为例，介绍如何使用 perf_start 和 perf_stop。

```c
#include "sdaa_perf.h"
#define SIZE 1000


__device__ void sum_func(const int *arr1, const int *arr2, int len, int *res_arr)
{
    // 设置采集性能项为执行周期，并开始采集
    perf_start();
    for (int i = 0; i < len; i++) {
        res_arr[i] = arr1[i] + arr2[i];
    }
    // 结束性能采集
    (void)perf_stop();
}


__global__ void test()
{
    int *res_arr = (int *)malloc(SIZE * sizeof(int));
    int array1[SIZE];
    int array2[SIZE];
    for (int i = 0; i < SIZE; i++) {
        array1[i] = i;
        array2[i] = i * 10;
    }
    sum_func(array1, array2, SIZE, res_arr);
    free(res_arr);
}


int main()
{
    sdaaSetDevice(0);
    test<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

### 7.11.3 perf_stop

```c
PerfData perf_stop()
```

#### 功能介绍

标识性能采样的结束位置。

#### 参数解释

无。

#### 返回值

| 参数名称 | 说明 |
|----------|------|
| PerfData | 性能采样的结构体数据，可参考 PerfData，目前支持：<br>latency：延时拍数，单位：拍。<br>cache_miss：指令缓存脱靶次数，单位：次。 |

#### 注意事项

- 需要手动包含 `sdaa_perf.h` 头文件。
- perf_stop 需要与 perf_start 配合使用，并且需要一一对应，不支持嵌套使用。

#### 使用示例

以统计某段循环加法代码的执行周期为例，介绍如何使用 perf_start 和 perf_stop 。

```c
#include "sdaa_perf.h"
#define SIZE 1000


__device__ void sum_func(const int *arr1, const int *arr2, int len, int *res_arr)
{
    // 设置采集性能项为执行周期，并开始采集
    perf_start();
    for (int i = 0; i < len; i++) {
        res_arr[i] = arr1[i] + arr2[i];
    }
    // 结束性能采集
    PerfData tmp_data = perf_stop();
    // 自行打印采集的性能数据
    printf("perf latency:%lu, cache miss:%lu\n",
              tmp_data.latency, tmp_data.cache_miss);
}


__global__ void test()
{
    int *res_arr = (int *)malloc(SIZE * sizeof(int));
    int array1[SIZE];
    int array2[SIZE];
    for (int i = 0; i < SIZE; i++) {
        array1[i] = i;
        array2[i] = i * 10;
    }
    sum_func(array1, array2, SIZE, res_arr);
    free(res_arr);
}


int main()
{
    sdaaSetDevice(0);
    test<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

### 7.11.4 perf_print

```c
void perf_print()
```

#### 功能介绍

在终端界面输出采集到的性能数据，包括：延时拍数和指令缓存脱靶次数等。

#### 参数解释

无。

#### 返回值

无。

#### 注意事项

- 需要手动包含 `sdaa_perf.h` 头文件。
- 用户需要在采集完性能数据后才能使用 perf_print 输出性能数据。
- 为避免对其他代码产生影响，保证性能数据采集的准确性，请将 perf_print 放在 Kernel 函数返回前的位置。
- 每个 SPE 最多采集 10 组性能数据。如果采集数量超过 10 组，会保留最后的 10 组数据。

#### 使用示例

以统计某段循环加法代码的执行周期为例，介绍如何使用 perf_print 输出采集的性能数据。

```c
#include "sdaa_perf.h"
#define SIZE 1000


__device__ void sum_func(const int *arr1, const int *arr2, int len, int *res_arr)
{
    // 设置采集性能项为执行周期，并开始采集
    perf_start();
    for (int i = 0; i < len; i++) {
        res_arr[i] = arr1[i] + arr2[i];
    }
    // 结束性能采集
    (void)perf_stop();
}


__global__ void test()
{
    int *res_arr = (int *)malloc(SIZE * sizeof(int));
    int array1[SIZE];
    int array2[SIZE];
    for (int i = 0; i < SIZE; i++) {
        array1[i] = i;
        array2[i] = i * 10;
    }
    sum_func(array1, array2, SIZE, res_arr);
    free(res_arr);
    // 输出采集的性能数据
    perf_print();
}


int main()
{
    sdaaSetDevice(0);
    test<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```
