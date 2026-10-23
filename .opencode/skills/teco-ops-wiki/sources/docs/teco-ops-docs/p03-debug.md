---
id: doc-teco-ops-docs-p03
title: "Teco-Ops 项目文档集 — 第p03部分 (README_DEBUG.md)"
type: source-doc-part
parent_doc: doc-teco-ops-docs
product_version: "commit d90ddf5"
source_file: "doc/README_DEBUG.md"
raw_text: "sources/docs/raw-teco-ops/README_DEBUG.txt"
raw_line_range: "1-264"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [teco-ops, debug, tecogdb, assert, abort, precision, printf]
---

# Teco-Ops 项目文档集（第p03部分：SDAA C 程序调试手册）

程序调试是应用程序开发人员在进行软件开发过程中必要的纠错手段。一款优秀的程序调试工具可以协助软件开发人员快速定位代码在编译、运行时发生错误的原因和位置，提升软件的开发效率。

SDAA C 为应用程序开发人员提供了配套的基本软件调试手段：

- **打印运行时日志**：通过打印运行时日志的方式，追踪打印计算核心 SPE 中代码的运行状态，从而定位出问题发生的具体原因。
- **TecoGDB 调试工具**：通过 TecoGDB 工具调试计算核心 SPE 的代码，从而定位出问题发生的具体原因。
- **终止设备端程序**：通过终止设备端程序的方式，在设备端的库函数代码中检测到无法修复的问题时，及时停止设备端程序的运行。
- **断言**：通过断言的方式，检测代码中存在的错误，出现错误时打印对应的文件行号等详细信息。

---

## 打印运行时日志

打印运行时日志是 SDAA C 提供的一个代码追踪手段。用户可以通过调用 `printf` 接口打印目标变量的运行时状态。

### 使用方法

- `printf` 接口是 SDAA C 提供的内置接口，用户使用时无需引入头文件。
- `printf` 接口参数与 C/C++ 提供的 `printf` 接口相同。
- 设置环境变量 `export SDAA_SYNC_PRINT=1`，可以按照 SPE 编号从小到大的顺序进行打印。

### 使用示例

以打印参数的相加结果为例，示例代码如下：

```c
__device__ void sum_func(int a, int b)
{
    int g_sum = a + b;
    printf("threadIdx: %lu, sum: %d\n", threadIdx, g_sum);
}

__global__ void bar()
{
    sum_func(1, 2);
}

int main()
{
    sdaaSetDevice(0);
    bar<<<1>>>();
    sdaaDeviceSynchronize();

    return 0;
}
```

不设置环境变量 `SDAA_SYNC_PRINT` 或者值默认为 0 时，会按照 SPE 的执行顺序进行打印。执行后打印结果如下：

```
threadIdx: 4, sum: 3
threadIdx: 0, sum: 3
threadIdx: 6, sum: 3
threadIdx: 7, sum: 3
......
```

设置环境变量 `SDAA_SYNC_PRINT=1`，按照 SPE 编号从小到大的顺序进行打印。执行后打印结果如下：

```
threadIdx: 0, sum: 3
threadIdx: 1, sum: 3
threadIdx: 2, sum: 3
threadIdx: 3, sum: 3
......
```

---

## TecoGDB 调试工具

TecoGDB（Tecorigin GNU Debugger）是基于 GNU GDB 开发的运行在 Linux 系统上的源码级调试工具，可以调试运行在太初 AI 加速卡上的程序，提供对被调试程序的运行控制和信息打印功能。该工具提供真实物理环境下的调试功能，避免仿真调试和真实环境运行的误差，方便准确定位问题。

更多内容，可参考《TecoGDB 命令行工具手册》。

---

## 终止设备端程序

终止设备端程序是 SDAA C 提供的协助调试手段。如果在设备端编写的库函数代码中检查到无法修复的问题，可以通过 `abort` 接口直接终止设备端的程序运行。

通过 `abort` 函数结束运行时：

- 如果设置了环境变量 `SDAA_ENABLE_COREDUMP_ON_EXCEPTION`：通知主机端生成包含错误相关上下文的 Core Dump 文件，并且终止主机端的代码执行。
- 如果没有设置该环境变量 `SDAA_ENABLE_COREDUMP_ON_EXCEPTION`：继续执行主机端的代码，后续通过执行 `sdaaDeviceSynchronize` 接口，获取对应的 abort 错误码。

### 使用方法

- `abort` 接口是 SDAA C 提供的内置接口，使用时无需引入头文件。
- `abort` 接口的参数与 C/C++ 提供的 `abort` 接口和用法相同。

### 使用示例

以检测除数不为 0 作为示例，当检查到除数为 0 时，执行 `abort` 终止 SPE 后续程序的运行。

```c
__device__ int g_sum = 0;
__device__ int my_div(int a, int b)
{
    if (b == 0) {
        // 如果除数为0，终止SPE后续程序的运行
        abort();
    }
    return a / b;
}

__device__ void my_compute(int a, int b)
{
    int div_result = my_div(a, b);
    g_sum = (a - b) * div_result;
}

__global__ void bar()
{
    my_compute(1, 2);
}

int main()
{
    sdaaSetDevice(0);
    bar<<<1>>>();
    sdaaDeviceSynchronize();

    return 0;
}
```

---

## 断言

断言（assert）是 SDAA C 提供的检测错误手段。可以通过调用 `assert` 接口检查代码中是否出现错误，出现错误后会和 C/C++ 提供的 `assert` 一样，打印对应错误所在的文件行号等信息，之后终止设备端程序的运行。

通过 `assert` 函数终止设备端程序运行时：

- 如果设置了环境变量 `SDAA_ENABLE_COREDUMP_ON_EXCEPTION`：通知主机端生成包含错误相关上下文的 Core Dump 文件，并且终止主机端的代码执行。
- 如果没有设置环境变量 `SDAA_ENABLE_COREDUMP_ON_EXCEPTION`：继续执行主机端的代码，后续通过执行 `sdaaDeviceSynchronize` 接口，获取对应的 assert 错误码。

### 使用方法

- `assert` 接口是 SDAA C 提供的内置接口，使用时无需引入头文件。
- `assert` 接口的参数与 C/C++ 提供的 `assert` 接口和用法相同。

### 使用示例

以检测除数不为 0 作为示例，`assert` 会检查除数是否为 0，为 0 时会打印错误所在的文件行号信息并且终止 SPE 后续程序的执行。

```c
__device__ int g_sum = 0;
__device__ void my_div(int a, int b)
{
    // 如果除数为0，则打印错误信息并终止SPE后续程序的执行
    assert(b != 0 && "b should not be zero");
    g_sum = a / b;
}

__global__ void bar()
{
    my_div(1, 2);
}

int main()
{
    sdaaSetDevice(0);
    bar<<<1>>>();
    sdaaDeviceSynchronize();

    return 0;
}
```

---

## 精度问题

### 中间变量使用 half 导致精度问题

**问题释义**：数据类型是 half 时，计算中间变量仍然使用 half。

**问题现象**：结果精度不足。

**问题产生原因**：数据类型是 half 时，计算中间变量仍然使用 half，多次截断，最终致使结果精度不足。

**解决方案**：数据类型为 half 时，中间标量/向量都转为 float 进行计算。

**示例**：

```c
void calculate(half *a, half *b, float alpha, float beta, int num){
    half tmp;
    for (int i = 0; i < num; i++){
        tmp = alpha * exp(a[i]);    // 错误的，float与half相乘的结果应保存至float内
        b[i]= b[i] * alpha + tmp;
    }
}
```

### 整形计算溢出

**问题释义**：较大或较小的整形数，参与运算后，结果易发生溢出。

**问题现象**：以 maximum 算子为例，其功能为取两个张量各个位置的较大值。实现方式为两个向量相减后与 0 比较，`vsellew` 选择大于 0 的部分。但当被减数为 `INT_MIN` 时，部分结果错误。

**问题产生原因**：`INT_MIN`（-2147483648）减去一个正数时，其结果发生下溢出，差值的二进制表示为一个正数，比较结果错误。

**解决方案**：算子的功能是做比较，可以避免使用算数运算，通过 `vcmpltw` 实现比较。

**示例**：

```c
// 错误的
__device__ void batch_int32_maximum(int *x, int *y, int *z, int ln){
    intv16 v_x, v_y, v_z, v_temp;
    for (int i = 0; i < ln; i += 16) {
        simd_load(v_x, x + i);
        simd_load(v_y, y + i);
        v_temp = v_x - v_y;
        v_z = simd_vsellew(v_temp, v_y, v_x);
        simd_store(v_z, z + i);
    }
}
// 当x的某个元素的值为-2147483648（INT_MIN），对应y的元素值为1时，
// x-y发生下溢出，其值为2147483647（INT_MAX），因此z值为-2147483648，结果错误。

// 正确的
__device__ void batch_int32_maximum(int *x, int *y, int *z, int ln) {
    intv16 v_x, v_y, v_z, v_less;
    for (int i = 0; i < ln; i += 16){
        simd_load(v_x, x + i);
        simd_load(v_y, y + i);
        v_less = simd_vcmpltw(v_x, v_y);
        v_z = simd_vseleqw(v_less, v_x, v_y);
        simd_store(v_z, z + i);
    }
}
// 上述情况下不会产生溢出，计算结果正确。
```

### 数据下溢为 0

**问题释义**：计算结果数据下溢为 0。

**问题现象**：计算结果数据下溢为 0。

**问题产生原因**：超越函数精度不足，其计算结果参与后续计算，会带来精度损失。

**解决方案**：

- 根据实际场景需求，判断是否使用高精度的超越函数。
- 根据实际场景需求，计算过程采用 double 类型数据。

**示例**：

以串行代码为例，输入和输出都是 float 类型：

```c
// 错误的，引起数据溢出的写法：
y = tanh(x);
y += 1;

// 正确的，降低数据溢出的写法：
y = 1 + tanh((double)x);
```
