---
id: doc-sdaa-c-programming-guide-v3-1-0-p03b
title: "SDAA C 编程指南 v3.1.0 — 第3部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "8667-9924"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [atomic, matmul, memory, programming-model, sdaa, sdaa-c, teco-t1, thread-group-sync]
---

# SDAA C 编程指南 v3.1.0（第3部分）

> 本部分接续上文跨步拷贝（memcpy_async）的代码示例，继续 ch7 函数接口章节，覆盖 7.7 原子操作 与 7.8 矩阵乘。

本部分开头是上文跨步拷贝示例的结尾片段：

```cpp
    constexpr size_t stride_size = 2 * sizeof(int);
    // 其他代码逻辑
    // ...

    // 配置跨步参数，进行非阻塞跨步拷贝
    memcpy_async(g_dst, spm_src, size, section_size, {stride_size, 0},
                 MemcpySpmToGlobal);

    // 其他代码逻辑
}
```

## 7.7 原子操作

### 7.7.1 概述

多线程编程模型中，原子操作（Atomic Operation）可以保证多线程对同一块内存访问的串行性，从而提高数据操作的安全性和正确性。SDAA C 提供的原子操作主要有以下几类：

- **atomic_inc**：读取 Global 上的一个数据并使其自增，此操作不会被打断，返回旧值。
- **atomic_add**：使 Global 上的一个数据增加某值，此操作不会被打断，返回旧值。
- **atomic_add_noret**：使 Global 上的一个数据增加某值，此操作不会被打断，无返回值。
- **atomic_sub**：使 Global 上的一个数据减少某值，此操作不会被打断，返回旧值。
- **atomic_sub_noret**：使 Global 上的一个数据减少某值，此操作不会被打断，无返回值。
- **atomic_cas**：满足条件时，使 Global 上的一个数据替换为某值，此操作不会被打断，返回旧值。
- **atomic_cas_bool**：满足条件时，使 Global 上的一个数据替换为某值，此操作不会被打断，返回布尔值。

### 7.7.2 atomic_inc

```c
int64_t atomic_inc(int64_t* val)
```

**功能介绍**

对目标操作数加 1，操作数得到新值，旧值作为返回值返回。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的操作数指针，需要位于 Global 存储空间。 |

**返回值**

| 返回值类型 | 说明 |
|------------|------|
| long | 返回的旧值。 |

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;


__device__ int64_t val = 0;
__global__ void calc()
{
      ...
      int64_t ret;
      ret = atomic_inc(&val);


      ...
}
// ret 的值在不同线程上是不同的，且依次加一 例如：1，2，3，4, 5, 6... 与线程顺序无关
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
     ...
     int64_t ret;
     ret = atomic_inc(val);


     ...
}
// ret 的值在不同线程上是不同的，且依次加一 例如：*val+1，*val+2，*val+3，*val+4, *val+5... 与线程顺序无关
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.3 atomic_add

```c
int32_t atomic_add(int32_t* val, int32_t num)
int64_t atomic_add(int64_t* val, int64_t num)
float   atomic_add(float* val, float num)
double  atomic_add(double* val, double num)
```

**功能介绍**

对目标操作数加 num，操作数得到新值，返回旧值。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的操作数指针，需要位于 Global 存储空间。 |
| num | 增加的数值，即被加到操作数上的值。 |

**返回值**

返回旧值。

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;


__device__ int32_t val = 0;
__global__ void calc()
{
     ...
     int32_t old = atomic_add(&val, 10);
     ...
}
// val 的值在不同线程上是不同的，且依次加10 例如：10，20，30，40, 50... 且与线程顺序无关
// old 的值则是val的值在加10之前的旧值
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
     ...
     int32_t old = atomic_add(val, 10);
     ...
}
// *val 的值在不同线程上是不同的，且依次加10 例如：*val+10，*val+20，*val+30，*val+40, *val+50... 与线程顺序无关
// old 的值则是*val的值在加10之前的旧值
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.4 atomic_add_noret

```c
void atomic_add_noret(int32_t* val, int32_t num)
void atomic_add_noret(int64_t* val, int64_t num)
```

**功能介绍**

对目标操作数加 num，操作数得到新值，无返回值。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的操作数指针，需要位于 Global 存储空间。 |
| num | 增加的数值，即被加到操作数上的值。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 0;
__global__ void calc()
{
    ...
    atomic_add_noret(&val, 10);
    ...
}
// val 的值在不同线程上是不同的，且依次加10 例如：10，20，30，40, 50... 且与线程顺序无关
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
    ...
    atomic_add_noret(val, 10);
    ...
}
// *val 的值在不同线程上是不同的，且依次加10 例如：*val+10，*val+20，*val+30，*val+40, *val+50... 与线程顺序无关
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.5 atomic_sub

```c
int32_t atomic_sub(int32_t* val, int32_t num)
int64_t atomic_sub(int64_t* val, int64_t num)
```

**功能介绍**

对目标操作数减 num，操作数得到新值，返回旧值。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的操作数指针，需要位于 Global 存储空间。 |
| num | 减小的数值，即从操作数上减去的值。 |

**返回值**

返回旧值。

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 0;
__global__ void calc()
{
     ...
     int32_t old = atomic_sub(&val, 10);
     ...
}
// val 的值在不同线程上是不同的，且依次减10 例如：-10，-20，-30，-40, -50... 且与线程顺序无关
// old 的值则是val的值在减10之前的旧值
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
     ...
     int32_t old = atomic_sub(val, 10);
     ...
}
// *val 的值在不同线程上是不同的，且依次减10 例如：*val-10，*val-20，*val-30，*val-40, *val-50... 与线程顺序无关
// old 的值则是val的值在减10之前的旧值
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.6 atomic_sub_noret

```c
void atomic_sub_noret(int32_t* val, int32_t num)
void atomic_sub_noret(int64_t* val, int64_t num)
```

**功能介绍**

对目标操作数减 num，操作数得到新值，无返回值。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的操作数指针，需要位于 Global 存储空间。 |
| num | 减小的数值，即从操作数上减去的值。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 0;
__global__ void calc()
{
     ...
     atomic_sub_noret(&val, 10);
     ...
}
// val 的值在不同线程上是不同的，且依次减10 例如：-10，-20，-30，-40, -50... 且与线程顺序无关
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
     ...
     atomic_sub_noret(val, 10);
     ...
}
// *val 的值在不同线程上是不同的，且依次减10 例如：*val-10，*val-20，*val-30，*val-40, *val-50... 与线程顺序无关
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.7 atomic_cas

```c
int32_t atomic_cas(int32_t* val, int32_t compare, int32_t new_val)
int64_t atomic_cas(int64_t* val, int64_t compare, int64_t new_val)
```

**功能介绍**

如果目标操作数等于 compare，则把 new_val 赋值给操作数，返回旧值。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的目标操作数指针，需要位于 Global 存储空间。 |
| compare | 比较值，与目标操作数比较。 |
| new_val | 新值，如果目标操作数与 compare 相同，则将新值赋给操作数。 |

**返回值**

返回旧值。

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 1;
__global__ void calc()
{
     ...
     // 有一个线程返回旧值1, 且把新值5赋给val。其他线程返回旧值5，且val值为5
     int32_t old = atomic_cas(&val, 1, 5);


     ...
}
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
    ...
    // 若传入的*val的值与1相等，则有一个线程返回旧值1, 且把新值5赋给*val。其他线程返回旧值5，且*val值为5
    // 若传入的*val的值与1不相等，所有线程返回*val旧值，且*val保持旧值
    int32_t old = atomic_cas(val, 1, 5);
    ...
}
```

**使用示例 3**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 1;
__global__ void calc()
{
    ...
    // 所有线程返回旧值 1, 且val的值保持1
    int32_t old = atomic_cas(&val, 0, 5);
    ...
}
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

### 7.7.8 atomic_cas_bool

```c
bool atomic_cas_bool(int32_t* val, int32_t compare, int32_t new_val)
bool atomic_cas_bool(int64_t* val, int64_t compare, int64_t new_val)
```

**功能介绍**

如果目标操作数等于 compare，则把 new_val 赋值给操作数，返回 true；否则返回 false。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| val | 待计算的目标操作数指针，需要位于 Global 存储空间。 |
| compare | 比较值，与目标操作数比较。 |
| new_val | 新值，如果目标操作数与 compare 相同，则将新值赋给操作数。 |

**返回值**

| 返回值类型 | 说明 |
|------------|------|
| bool | 赋值成功返回 true；否则返回 false。 |

**注意事项**

- 需要手动包含 `sdaa_atomic.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例 1**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 1;
__global__ void calc()
{
      ...
      // 有一个线程返回true，且val值更新为5, 其他线程返回false，val值为5
      bool ret = atomic_cas_bool(&val, 1, 5);
      ...
}
```

**使用示例 2**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
// val 是用 sdaaMalloc 在全局内存上创建
__global__ void calc(int32_t *val)
{
      ...
      // 若传入的*val的值与1相等，则有一个线程返回true, 且把新值5赋给val。其他线程返回false，且val值为5
      // 若传入的*val的值与1不相等，所有线程返回false, 且*val保持旧值
      bool ret = atomic_cas_bool(val, 1, 5);
      ...
}
```

**使用示例 3**

```c
#include <sdaa_atomic.h>
using namespace sdaa;
__device__ int32_t val = 1;
__global__ void calc()
{
    ...
    // 所有线程返回false，val值保持为1
    bool ret = atomic_cas_bool(&val, 0, 5);
    ...
}
```

**相关推荐**

更详细的原子操作使用示例，可参考使用 CAS 完成自定义原子操作。

## 7.8 矩阵乘

### 7.8.1 概述

矩阵乘函数接口实现了高效的二维矩阵乘法计算，从调用接口上可分为阻塞型矩阵乘和非阻塞型矩阵乘：

- **阻塞型矩阵乘**：使用简单，但性能不佳。
- **非阻塞型矩阵乘**：使用相对复杂，但性能较好。

**阻塞型矩阵乘**

阻塞型矩阵乘由以下函数接口组成：

- **matmul**：进行矩阵乘计算，矩阵地址可以位于 SPM 或 Global 上，且矩阵的维度可变，同时支持原位操作。
- **check_matmul**：验证 matmul 函数输入参数的合法性，通过返回值判断输入参数是否满足特定的输入要求，如：地址对齐、当前接口占用 SPM 堆空间不能超出剩余可用堆空间等。

**非阻塞型矩阵乘**

非阻塞型矩阵乘可分为配置型操作和调用型操作。

- **配置型操作**：通过修改参数完成多种矩阵乘功能，由以下函数接口组成：
  - **MatmulHandle**：配置矩阵乘的参数，从而使用不同的矩阵乘功能。
  - **matmul_set_updating_weight**：设置是否更新权重矩阵。
  - **matmul_set_flushing_output**：设置是否可以输出计算结果到 SPM 空间。
  - **matmul_set_weight_row_padding**：通过掩码的方式，设置加载权重矩阵时，是否填充空行。
  - **matmul_set_output_row_offset**：设置计算结果的行偏移。
  - **matmul_wait_loading_input**：等待输入矩阵加载完成。
  - **matmul_wait_loading_weight**：等待权重矩阵加载完成。
- **调用型操作**：是调用矩阵乘进行计算的必要步骤，由以下函数接口组成：
  - **matmul_init**：初始化矩阵乘接口，并配置输入和输出数据的类型。
  - **matmul_load_weight**：从 SPM 指定地址加载权重矩阵到矩阵乘计算单元上。
  - **matmul_compute**：从 SPM 指定地址加载输入矩阵，并与加载好的权重矩阵做矩阵乘运算。
  - **matmul_store**：将矩阵乘运算的计算结果写回到 SPM 指定地址上。
  - **matmul_wait**：等待矩阵乘写回操作完成。

### 7.8.2 阻塞型矩阵乘

#### 7.8.2.1 matmul

```c
void matmul(MatmulDataType type, void *output, const void *input, const void *weight, unsigned int m, unsigned int k, unsigned int n)
```

**功能介绍**

计算两个矩阵的乘法。支持原位操作，且矩阵的维度可变。

形式：output<sub>m×n</sub> = input<sub>m×k</sub> × weight<sub>k×n</sub>

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| type | 枚举型 MatmulDataType，表示参与矩阵乘运算的数据类型，当前支持：<br>• **MatmulHalfToHalf**：16 位半精度浮点型运算，输出 16 位半精度浮点型。<br>• **MatmulHalfToFloat**：16 位半精度浮点型运算，输出 32 位单精度浮点型。<br>• **MatmulShortToShort**：16 位有符号短整型运算，输出 16 位有符号短整型。<br>• **MatmulShortToInt**：16 位有符号短整型运算，输出 32 位有符号整型。 |
| output | 输出矩阵首地址，可位于 SPM 或 Global。 |
| input | 输入矩阵首地址，可位于 SPM 或 Global。 |
| weight | 权重矩阵首地址，可位于 SPM 或 Global。 |
| m | 输入矩阵和输出矩阵的行数，无大小限制。 |
| k | 输入矩阵列数，也是权重矩阵行数，无大小限制。 |
| n | 权重矩阵和输出矩阵的列数，无大小限制。 |

**返回值**

无。

**注意事项**

输入矩阵 input、权重矩阵 weight 和输出矩阵 output 可以位于 Global 或 SPM。

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。
- 对齐要求：
  - 如果某矩阵位于 Global：
    1. 该矩阵大小需为 4B 的整数倍，以满足 DMA 传输量的大小限制。
    2. 该矩阵首地址需要 4B 对齐，以满足 DMA 要求。
  - 如果某矩阵位于 SPM：
    1. 如果满足 `k == 32 && n == 32`，且该矩阵为 output 和 input，则该矩阵首地址需要 64B 对齐。
    2. 否则，如果满足 `k % 32 == 0`，且该矩阵为 input，则该矩阵首地址需要 64B 对齐。
- 当前 matmul 接口会额外占用 SPM 堆空间情况：
  - 如果满足以下条件之一，需要额外占用对应矩阵数据大小的 SPM 堆空间；
    - 输入参数中矩阵地址位于 Global。
    - `n <= 32` 且输入参数中 output 矩阵地址与 input 或 weight 地址空间有重叠。
  - 如果数据类型是 `MatmulHalfToHalf` 或 `MatmulShortToShort`：
    1. 满足 `k == 32 && n == 32` 时，不需要额外占用 SPM 堆空间。
    2. 不满足条件 1，但满足 `k % 32 == 0 && n % 32 == 0` 时，需要额外占用 **10KB** 的 SPM 堆空间。
    3. 如果不满足以上两种情况，需要额外占用 **18KB** 的 SPM 堆空间。
  - 如果数据类型是 `MatmulHalfToFloat` 或 `MatmulShortToInt`：
    1. 满足 `k == 32 && n == 32` 时，不需要额外占用 SPM 堆空间。
    2. 不满足条件 1，但满足 `k % 32 == 0 && n % 32 == 0` 时，需要额外占用 **18KB** 的 SPM 堆空间。
    3. 如果不满足以上两种情况，需要额外占用 **26KB** 的 SPM 堆空间。

**使用示例 1**

矩阵位于 Global 时调用 matmul。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void test(const void *data_a, const void *data_b, void *data_c)
{
    if (threadIdx != 0) { return; }
    // 设置matmul输入数据类型为half，输出为float
    matmul(MatmulHalfToFloat, data_c, data_a, data_b, 200, 100, 100);
}


int main()
{
    ...
    half *dev_a = NULL;
    half *dev_b = NULL;
    float *dev_c = NULL;
    sdaaMalloc((void **)&dev_a, 200 * 100 * sizeof(half));
    sdaaMalloc((void **)&dev_b, 100 * 100 * sizeof(half));
    sdaaMalloc((void **)&dev_c, 200 * 100 * sizeof(float));
    ...
    // 准备矩阵数据
    ...
    test<<<1>>>(dev_a, dev_b, dev_c);
    ...
}
```

**使用示例 2**

矩阵位于 SPM 时调用 matmul。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void test(const void *data_a, const void *data_b, void *data_c)
{
    if (threadIdx != 0) { return; }
    // 在SPM上申请输入矩阵数据空间
    half *input = (half *)malloc(200 * 100 * sizeof(half));
    memcpy_async(input, data_a, 200 * 100 * sizeof(half), 0, {0, 0}, MemcpyGlobalToSpm);
    // 在SPM上申请权重矩阵数据空间
    half *weight = (half *)malloc(100 * 100 * sizeof(half));
    memcpy_async(weight, data_b, 100 * 100 * sizeof(half), 0, {0, 0}, MemcpyGlobalToSpm);
    // 在SPM上申请输出矩阵数据空间
    float *output = (float *)malloc(200 * 100 * sizeof(float));
    memcpy_wait();
    // 进行同步的矩阵乘法
    matmul(MatmulHalfToFloat, output, input, weight, 200, 100, 100);
    // 将计算完成的数据从SPM上copy到Global数据空间上
    memcpy(data_c, output, 200 * 100 * sizeof(float));


    free(output);
    free(weight);
    free(input);
}


int main()
{
    ...
    half *dev_a = NULL;
    half *dev_b = NULL;
    float *dev_c = NULL;
    sdaaMalloc((void **)&dev_a, 200 * 100 * sizeof(half));
    sdaaMalloc((void **)&dev_b, 100 * 100 * sizeof(half));
    sdaaMalloc((void **)&dev_c, 200 * 100 * sizeof(float));
    ...
    // 准备矩阵数据
    ...
    test<<<1>>>(dev_a, dev_b, dev_c);
    ...
}
```

**使用示例 3**

支持原位计算。

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void test(void *data_a)
{
    if (threadIdx != 0) { return; }
    // 申请一块数据空间，既是输入矩阵，权重矩阵数据空间，也是输出矩阵空间
    half *spm_a = (half *)malloc(32 * 32 * sizeof(half));
    memcpy(spm_a, data_a, 32 * 32 * sizeof(half));
    // 进行同步矩阵乘法
    matmul(MatmulHalfToHalf, spm_a, spm_a, spm_a, 32, 32, 32);


    memcpy(data_a, spm_a, 32 * 32 * sizeof(half));


    free(spm_a);
}


int main()
{
    ...
    half *dev_a = NULL;
    sdaaMalloc((void **)&dev_a, 32 * 32 * sizeof(half));
    ...
    // 准备矩阵数据
    ...
    test<<<1>>>(dev_a);
    ...
}
```

#### 7.8.2.2 check_matmul

```c
unsigned int check_matmul(MatmulDataType type, void *output, const void *input, const void *weight, unsigned int m, unsigned int k, unsigned int n)
```

**功能介绍**

验证阻塞型矩阵乘接口输入参数的合法性。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| type | 枚举型 MatmulDataType，表示参与矩阵乘运算的数据类型，当前支持：<br>• **MatmulHalfToHalf**：16 位半精度浮点型运算，输出 16 位半精度浮点型。<br>• **MatmulHalfToFloat**：16 位半精度浮点型运算，输出 32 位单精度浮点型。<br>• **MatmulShortToShort**：16 位有符号短整型运算，输出 16 位有符号短整型。<br>• **MatmulShortToInt**：16 位有符号短整型运算，输出 32 位有符号整型。 |
| output | 输出矩阵首地址，可位于 SPM 或 Global。 |
| input | 输入矩阵首地址，可位于 SPM 或 Global。 |
| weight | 权重矩阵首地址，可位于 SPM 或 Global。 |
| m | 输入矩阵和输出矩阵的行数，无大小限制。 |
| k | 输入矩阵列数，也是权重矩阵行数，无大小限制。 |
| n | 权重矩阵和输出矩阵的列数，无大小限制。 |

**返回值**

| 返回值类型 | 说明 |
|------------|------|
| unsigned int | 参数合法性验证结果，每个 Bit 代表不同的状态信息。对应枚举型 MatmulStatus，表示合法性验证的状态信息，当前可表示状态有：<br>• **MATMUL_SUCC**：参数无误。<br>• **MATMUL_ERROR_DMA_SIZE_UNALIGNED**：各矩阵大小（即 DMA 传输量）不是 4B 整数倍。<br>• **MATMUL_ERROR_GLOBAL_ADDR_UNALIGNED**：输入矩阵首地址在 Global 上但没有 4B 对齐。<br>• **MATMUL_ERROR_SPM_ADDR_UNALIGNED**：输入矩阵首地址在 SPM 上但没有 64B 对齐。<br>• **MATMUL_ERROR_SPM_OVERSIZE**：当前接口占用 SPM 堆空间超出剩余可用堆空间。 |

返回的具体状态信息可参照如下表格：

| Bit 位 | 含义 |
|--------|------|
| 第 0 位 | 0：参数无误。<br>1：参数有误。 |
| 第 1 位 | 第 0 位是 0 时，此位保留。<br>第 0 位是 1 时，此位：0：正常；1：错误。各矩阵大小（即 DMA 传输量）不是 4B 整数倍。 |
| 第 2 位 | 第 0 位是 0 时，此位保留。<br>第 0 位是 1 时，此位：0：正常；1：错误。输入矩阵首地址在 Global 上但没有 4B 对齐。 |
| 第 3 位 | 第 0 位是 0 时，此位保留。<br>第 0 位是 1 时，此位：0：正常；1：错误。输入矩阵首地址在 SPM 上但没有 64B 对齐。 |
| 第 4 位 | 第 0 位是 0 时，此位保留。<br>第 0 位是 1 时，此位：0：正常；1：错误。当前接口占用 SPM 堆空间超出剩余可用堆空间。 |
| 第 5~31 位 | 保留。 |

**注意事项**

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。

**使用示例**

```cpp
#include <sdaa_matmul.h>
using namespace sdaa;
__global__ void test(const void *data_a, const void *data_b, void *data_c)
{
    if (threadIdx != 0) { return; }
    // 矩阵乘参数合法化检查
    int check_val = check_matmul(MatmulHalfToFloat, data_c, data_a, data_b, 200, 100, 100);
    if (check_val == MATMUL_SUCC) {
        matmul(MatmulHalfToFloat, data_c, data_a, data_b, 200, 100, 100);
    }
}
```

### 7.8.3 非阻塞型矩阵乘

#### 7.8.3.1 使用逻辑

非阻塞型矩阵乘接口可分为调用型接口和配置型接口，其中：

- **调用型接口**：是非阻塞型矩阵乘的必要接口步骤。
- **配置型接口**：通过修改相关配置项修改部分调用型接口的行为。

非阻塞型矩阵乘接口的使用逻辑为：

1. **matmul_init**：初始化矩阵乘计算单元，并配置输入输出的数据类型。
2. **matmul_load_weight**：从 SPM 的指定地址加载权重矩阵到权重矩阵加载缓冲区。

   > 说明：
   >
   > 可以通过配置型接口 matmul_set_weight_row_padding 设置加载权重矩阵时，是否填充空行，该接口作用于当前和之后阶段的 matmul_load_weight。

3. **matmul_compute**：从 SPM 加载输入矩阵并计算与权重矩阵的乘积。

   > 说明：
   >
   > 以下接口作用于当前和之后阶段的 matmul_compute。
   >
   > - 可以通过配置型接口 matmul_set_updating_weight 设置是否从权重矩阵加载缓冲区更新权重矩阵。
   > - 可以通过配置型接口 matmul_set_output_row_offset 设置计算结果写入计算结果累加缓冲区时的行偏移。
   > - 可以通过配置型接口 matmul_set_flushing_output 设置是否使能从累加缓冲区向 SPM 输出计算结果。

4. **matmul_store**：从计算结果累加缓冲区输出计算结果到 SPM 的指定地址。
5. **matmul_wait**：等待矩阵乘的计算结果写出完成。

图 1：非阻塞型矩阵乘的使用逻辑

#### 7.8.3.2 调用型操作

##### 7.8.3.2.1 matmul_init

```c
void matmul_init(MatmulHandle &handle, MatmulDataType type)
```

**功能介绍**

初始化矩阵乘接口，并配置输入和输出数据的类型。

**参数解释**

| 参数名称 | 说明 |
|----------|------|
| handle | MatmulHandle 型变量。配置矩阵乘的参数，从而使用不同的矩阵乘功能。 |
| type | 枚举型 MatmulDataType，表示参与矩阵乘运算的数据类型，当前支持：<br>• **MatmulHalfToHalf**：16 位半精度浮点型运算，输出 16 位半精度浮点型。<br>• **MatmulHalfToFloat**：16 位半精度浮点型运算，输出 32 位单精度浮点型。<br>• **MatmulShortToShort**：16 位有符号短整型运算，输出 16 位有符号短整型。<br>• **MatmulShortToInt**：16 位有符号短整型运算，输出 32 位有符号整型。 |

**返回值**

无。

**注意事项**

- 需要手动包含 `sdaa_matmul.h` 头文件。
- 需要引入 sdaa 命名空间。
- 此接口隐含栏栅语义，会等待之前的所有矩阵乘运算完成。
- 暂不支持 int8 型矩阵乘计算。

**使用示例 1**

使用 matmul_init、matmul_load_weight、matmul_compute、matmul_store、matmul_wait、matmul_wait_loading_weight、matmul_wait_loading_input 共同完成 100\*32\*32 的矩阵乘运算。

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

使用 matmul_init、matmul_load_weight、matmul_compute、matmul_store、matmul_wait、matmul_wait_loading_weight、matmul_wait_loading_input、matmul_set_updating_weight 共同……（本部分范围在此截断，使用示例 2 的代码内容续见下一部分。）
