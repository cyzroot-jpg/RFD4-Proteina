---
id: doc-sdaa-c-programming-guide-v3-1-0-p03c
title: "SDAA C 编程指南 v3.1.0 — 第3部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "9925-10895"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [matmul, programming-model, sdaa, sdaa-c, teco-t1]
---

# SDAA C 编程指南 v3.1.0（第3部分）

> 本部分覆盖第 7 章函数接口中矩阵乘（matmul）相关接口的内容（原始抽取文本第 9925 至 10895 行）。该范围内的内容主要为 `7.8.3.2.1 matmul_init`（接续上一部分）的使用示例，以及 `7.8.3.2.2 matmul_load_weight`、`7.8.3.2.3 matmul_compute`、`7.8.3.2.4 matmul_store`（接续到下一部分）三个函数接口的完整说明。

## 7.8 函数接口（续）

### 7.8.3 矩阵乘接口（续）

#### 7.8.3.2 矩阵乘函数接口（续）

##### 7.8.3.2.1 matmul_init（使用示例续）

> 注：本范围起始处接续上一部分 `matmul_init` 的使用示例 2 与使用示例 3。

###### matmul_init 使用示例 2（续）

完成 200\*32\*32 的矩阵乘运算。

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_updating_weight` 共同完成 200\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵前半，128*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 128, MatmulK32);



    // 输出计算结果写回到指定地址，128*32个float型数据
    matmul_store(handle, output, 128, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);


    // 不使能更新权重矩阵，即使用上次加载的权重矩阵
    matmul_set_updating_weight(handle, false);


    // 加载输入矩阵后半，72*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + 128 * MatmulK32, 72, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，72*32个float型数据
    matmul_store(handle, output + 128 * MatmulN32, 72, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

###### matmul_init 使用示例 3

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_flushing_output` 共同完成 100\*64\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 不使能计算结果输出，即暂存入累加缓冲区
    matmul_set_flushing_output(handle, false);


    // 加载权重矩阵上半，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 跨步加载输入矩阵左半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32, 1);


    // 使能计算结果输出，下次计算结果累加后输出
    matmul_set_flushing_output(handle, true);


    // 加载权重矩阵下半，32*32个half型数据
    matmul_load_weight(handle, weight + MatmulK32 * MatmulN32, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 跨步加载输入矩阵右半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + MatmulK32, 100, MatmulK32, 1);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

##### 7.8.3.2.2 matmul_load_weight

```cpp
void matmul_load_weight(MatmulHandle &handle, void *weight, MatmulKSize k, MatmulNSize n, unsigned int stride = 0)
```

**功能介绍**

从 SPM 指定地址加载权重矩阵到矩阵乘计算单元上。

**参数解释**

| 参数名称 | 说明 |
|---|---|
| handle | MatmulHandle 型变量。配置矩阵乘的参数，从而使用不同的矩阵乘功能。 |
| weight | 权重矩阵首地址，需位于 SPM。 |
| k | 权重矩阵行数。枚举类型 MatmulKSize，当前支持：<br>MatmulK32：权重矩阵行数为 32。 |
| n | 权重矩阵列数。枚举类型 MatmulNSize，当前支持：<br>MatmulN32：权重矩阵列数为 32。 |
| stride | 加载权重矩阵的跨步步长。<br><br>说明：<br>预留项，目前仅支持步长为 0。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。
- 当前权重矩阵、输入矩阵和输出矩阵的行列要求为：

| 权重矩阵 | 输入矩阵 | 输出矩阵 |
|---|---|---|
| MatmulK32 \* MatmulN32 | (1~128) \* MatmulK32 | (1~128) \* MatmulN32 |

**使用示例 1**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input` 共同完成 100\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 2**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_updating_weight` 共同完成 200\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵前半，128*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 128, MatmulK32);



    // 输出计算结果写回到指定地址，128*32个float型数据
    matmul_store(handle, output, 128, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);


    // 不使能更新权重矩阵，即使用上次加载的权重矩阵
    matmul_set_updating_weight(handle, false);


    // 加载输入矩阵后半，72*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + 128 * MatmulK32, 72, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，72*32个float型数据
    matmul_store(handle, output + 128 * MatmulN32, 72, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 3**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_flushing_output` 共同完成 100\*64\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 不使能计算结果输出，即暂存入累加缓冲区
    matmul_set_flushing_output(handle, false);


    // 加载权重矩阵上半，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 跨步加载输入矩阵左半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32, 1);


    // 使能计算结果输出，下次计算结果累加后输出
    matmul_set_flushing_output(handle, true);


    // 加载权重矩阵下半，32*32个half型数据
    matmul_load_weight(handle, weight + MatmulK32 * MatmulN32, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 跨步加载输入矩阵右半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + MatmulK32, 100, MatmulK32, 1);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

##### 7.8.3.2.3 matmul_compute

```cpp
void matmul_compute(MatmulHandle &handle, void *input, unsigned int m, MatmulKSize k, unsigned int stride = 0)
```

**功能介绍**

从 SPM 指定地址加载输入矩阵，并与加载好的权重矩阵做矩阵乘运算。

**参数解释**

| 参数名称 | 说明 |
|---|---|
| handle | MatmulHandle 型变量。配置矩阵乘的参数，从而使用不同的矩阵乘功能。 |
| input | 输入矩阵首地址，需位于 SPM。 |
| m | 输入矩阵行数。有效值：1~128。 |
| k | 输入矩阵列数。枚举类型 MatmulKSize，当前支持：<br>MatmulK32：输入矩阵列数为 32。 |
| stride | 加载输入矩阵的跨步步长。<br><br>说明：<br>跨步步长 = stride \* 64Byte，例如：<br>stride 为 0 时，跨步步长为 0Byte。<br>stride 为 1 时，跨步步长为 64Byte。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。
- 当前权重矩阵、输入矩阵和输出矩阵的行列要求为：

| 权重矩阵 | 输入矩阵 | 输出矩阵 |
|---|---|---|
| MatmulK32 \* MatmulN32 | (1~128) \* MatmulK32 | (1~128) \* MatmulN32 |

**使用示例 1**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input` 共同完成 100\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 2**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_updating_weight` 共同完成 200\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵前半，128*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 128, MatmulK32);



    // 输出计算结果写回到指定地址，128*32个float型数据
    matmul_store(handle, output, 128, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);


    // 不使能更新权重矩阵，即使用上次加载的权重矩阵
    matmul_set_updating_weight(handle, false);


    // 加载输入矩阵后半，72*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + 128 * MatmulK32, 72, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，72*32个float型数据
    matmul_store(handle, output + 128 * MatmulN32, 72, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 3**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_flushing_output` 共同完成 100\*64\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 不使能计算结果输出，即暂存入累加缓冲区
    matmul_set_flushing_output(handle, false);


    // 加载权重矩阵上半，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 跨步加载输入矩阵左半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32, 1);


    // 使能计算结果输出，下次计算结果累加后输出
    matmul_set_flushing_output(handle, true);


    // 加载权重矩阵下半，32*32个half型数据
    matmul_load_weight(handle, weight + MatmulK32 * MatmulN32, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 跨步加载输入矩阵右半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + MatmulK32, 100, MatmulK32, 1);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

##### 7.8.3.2.4 matmul_store

```cpp
void matmul_store(MatmulHandle &handle, void *output, unsigned int m, MatmulNSize n)
```

**功能介绍**

将矩阵乘运算的计算结果写回到 SPM 指定地址上。

**参数解释**

| 参数名称 | 说明 |
|---|---|
| handle | MatmulHandle 型变量。配置矩阵乘的参数，从而使用不同的矩阵乘功能。 |
| output | 输出矩阵首地址，需位于 SPM。 |
| m | 输出矩阵行数。有效值：1~128。 |
| n | 输出矩阵列数。枚举类型 MatmulNSize，当前支持：<br>MatmulN32：输出矩阵列数为 32。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。
- 当前权重矩阵、输入矩阵和输出矩阵的行列要求为：

| 权重矩阵 | 输入矩阵 | 输出矩阵 |
|---|---|---|
| MatmulK32 \* MatmulN32 | (1~128) \* MatmulK32 | (1~128) \* MatmulN32 |

- 调用 `matmul_store` 时，如果上次 `matmul_store` 之后的所有 `matmul_compute` 调用都配置为不输出计算结果，则调用 `matmul_store` 输出计算结果时，会发生调用异常。您可以在创建 MatmulHandle 或调用 `matmul_set_flushing_output` 时配置输出计算结果使能 `matmul_store`。

**使用示例 1**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input` 共同完成 100\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，100*32个float型数据
    matmul_store(handle, output, 100, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 2**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_updating_weight` 共同完成 200\*32\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 加载权重矩阵，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 加载输入矩阵前半，128*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 128, MatmulK32);



    // 输出计算结果写回到指定地址，128*32个float型数据
    matmul_store(handle, output, 128, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);


    // 不使能更新权重矩阵，即使用上次加载的权重矩阵
    matmul_set_updating_weight(handle, false);


    // 加载输入矩阵后半，72*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + 128 * MatmulK32, 72, MatmulK32);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);


    ... // 此时可修改input地址上数据


    // 输出计算结果写回到指定地址，72*32个float型数据
    matmul_store(handle, output + 128 * MatmulN32, 72, MatmulN32);


    // 等待写回完成
    matmul_wait(handle);
}
```

**使用示例 3**

使用 `matmul_init`、`matmul_load_weight`、`matmul_compute`、`matmul_store`、`matmul_wait`、`matmul_wait_loading_weight`、`matmul_wait_loading_input`、`matmul_set_flushing_output` 共同完成 100\*64\*32 的矩阵乘运算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void func()
{
    ... // 准备矩阵数据


    // 创建MatmulHandle类型变量，使用默认参数
    MatmulHandle handle;


    // 初始化矩阵乘接口并配置数据类型
    matmul_init(handle, MatmulHalfToFloat);


    // 不使能计算结果输出，即暂存入累加缓冲区
    matmul_set_flushing_output(handle, false);


    // 加载权重矩阵上半，32*32个half型数据
    matmul_load_weight(handle, weight, MatmulK32, MatmulN32);


    // 跨步加载输入矩阵左半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input, 100, MatmulK32, 1);


    // 使能计算结果输出，下次计算结果累加后输出
    matmul_set_flushing_output(handle, true);


    // 加载权重矩阵下半，32*32个half型数据
    matmul_load_weight(handle, weight + MatmulK32 * MatmulN32, MatmulK32, MatmulN32);


    // 等待权重矩阵加载完成
    matmul_wait_loading_weight(handle);


    ... // 此时可修改weight地址上数据


    // 跨步加载输入矩阵右半，100*32个half型数据，并开始矩阵乘运算
    matmul_compute(handle, input + MatmulK32, 100, MatmulK32, 1);


    // 等待输入矩阵加载完成
    matmul_wait_loading_input(handle);

    // ...（本部分到此结束，使用示例 3 接续到下一部分）
}
```

> 注：`matmul_store` 的使用示例 3 在原始抽取文本第 10895 行处中断（接续到下一部分）。
