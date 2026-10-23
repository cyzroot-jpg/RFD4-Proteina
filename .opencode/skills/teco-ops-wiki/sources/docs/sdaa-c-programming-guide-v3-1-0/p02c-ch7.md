---
id: doc-sdaa-c-programming-guide-v3-1-0-p02c
title: "SDAA C 编程指南 v3.1.0 — 第2部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "6149-7295"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [broadcast, matmul, memory, programming-model, sdaa, sdaa-c, teco-t1, tecocc, thread-group-sync]
---

# SDAA C 编程指南 v3.1.0（第2部分）

> 本部分覆盖 ch7「函数接口」中关于 SPM 间数据搬运的非阻塞型 RMA 操作收尾（`rma_async_put` 的注意事项与示例）、`rma_complete`、`rma_wait`、典型场景示例，以及 Broadcast 数据搬运的概述与 `BroadcastHandle` 配置接口。本段为原文第 6149-7295 行的结构化整理，严格保持原文顺序。

## 7.6.2.3 非阻塞型 RMA 数据搬运接口（续）

### 7.6.2.3.3 rma_async_put（续：注意事项与示例）

> 说明：本段从 `rma_async_put` 的「注意事项」末尾的提示开始，承接其前面的函数签名、功能介绍、参数解释与返回值（位于本部分起始行之前）。

#### 注意事项（续）

> 提示：
>
> 在使用 `malloc` 分配 SPM 存储空间之前，如果已经对涉及 RMA 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 RMA 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

使用非阻塞型 RMA 操作，将 0 号计算核心中指定的 SPM 地址空间中的数据拷贝到 1 号计算核心指定的 SPM 地址空间内。

```cpp
using namespace sdaa;
#define SIZE 100


// 使用__local__ 分配的SPM存储空间
__local__ int local_addr[SIZE];
__local__ int remote_addr[SIZE];


__global__ void func()
{
    // 初始化0号计算核心中local_addr的值
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            local_addr[i] = i;
        }
    }


    // 初始化1号计算核心中remote_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            remote_addr[i] = 0;
        }
    }


    // 创建用于进行非阻塞RMA操作的句柄
    RmaHandle handle;
    // 在进行非阻塞RMA操作前进行计算核心之间的同步
    sync_threads();


    // 0号计算核心发起非阻塞RMA操作
    if (threadIdx == 0) {
        // 配置1号计算核心为远端核心
        rma_set_thread_id(handle, 1);
        // 发起非阻塞RMA PUT操作
        rma_async_put(local_addr, remote_addr, SIZE * sizeof(int), handle);


        // 等待当前计算核心完成非阻塞RMA PUT操作
        // 使用了rma_complete接口，关于该接口用户可参考rma_complete小节的介绍
        rma_complete(handle);


        // 其他代码逻辑
    }


    // 1号计算核心等待0号计算核心完成非阻塞RMA操作
    if (threadIdx == 1) {
        // 配置0号计算核心为远端核心
        rma_set_thread_id(handle, 0);


        // 等待1号计算核心完成非阻塞RMA操作逻辑
        // 使用了rma_wait接口，关于该接口用户可参考rma_wait小节的介绍
        rma_wait(handle);
    }
}
```

#### 使用示例 2

使用非阻塞型 RMA 操作，将 0 号计算核心中指定的 SPM 地址空间中的数据拷贝到 1 号计算核心指定的 SPM 地址空间内。

```cpp
using namespace sdaa;
#define SIZE 100


__global__ void func()
{
    // 使用malloc申请SPM空间
    int *spm_addr = (int *)malloc(SIZE * sizeof(int));


    // 初始化0号计算核心中spm_addr的值
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            spm_addr[i] = i;
        }
    }


    // 初始化1号计算核心中spm_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            spm_addr[i] = 0;
        }
    }


    // 创建用于进行非阻塞RMA操作的句柄
    RmaHandle handle;
    // 在进行非阻塞RMA操作前进行计算核心之间的同步
    sync_threads();


    // 0号计算核心发起非阻塞RMA操作
    if (threadIdx == 0) {
        // 配置1号计算核心为远端核心
        rma_set_thread_id(handle, 1);
        // 发起非阻塞RMA PUT操作
        rma_async_put(spm_addr, spm_addr, SIZE * sizeof(int), handle);


        // 等待当前计算核心完成非阻塞RMA PUT操作
        // 使用了rma_complete接口，关于该接口用户可参考rma_complete小节的介绍
        rma_complete(handle);


        // 其他代码逻辑
    }


    // 1号计算核心等待0号计算核心完成非阻塞RMA操作
    if (threadIdx == 1) {
        // 配置0号计算核心为远端核心
        rma_set_thread_id(handle, 0);


        // 等待1号计算核心完成非阻塞RMA操作逻辑
        // 使用了rma_wait接口，关于该接口用户可参考rma_wait小节的介绍
        rma_wait(handle);
    }


    free(spm_addr);
}
```

### 7.6.2.3.4 rma_complete

```cpp
void rma_complete(RmaHandle &handle, RmaOperateMode operateMode = RmaNormalMode)
```

#### 功能介绍

等待当前计算核心 SPE 完成非阻塞型 RMA 数据搬运。

#### 参数解释

| 参数名称 | 说明 |
|---|---|
| handle | RmaHandle 类型变量，用于存储远端计算核心的 ID。 |
| operateMode | 枚举类型 RmaOperateMode，支持以下两种模式：<br>• **RmaNormalMode**：常规模式，由编译器自动计算当前计算核心发起的非阻塞 RMA 数据搬运次数，该模式为默认配置模式。该模式下非阻塞 RMA 数据搬运的效率较低。<br>• **RmaCustomizeMode**：自定义模式，需要由用户手动写入当前计算核心发起的非阻塞 RMA 数据搬运次数。需配合 rma_wait 的 rmaTime 参数使用。该模式下非阻塞 RMA 数据搬运的效率高。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- 要求 `rma_complete` 与 `rma_wait` 需要成对使用。
- `RmaNormalMode` 和 `RmaCustomizeMode` 两种模式不能混合使用。
- 使用 `RmaNormalMode` 模式，要求用户在远端 SPE 使用 `rma_wait` 时，不能写入非阻塞 RMA 操作次数。
- 使用 `RmaCustomizeMode` 模式，要求用户在远端 SPE 使用 `rma_wait` 时，需要准确写入非阻塞 RMA 操作次数。
- 执行完 `rma_complete` 函数，表示当前 SPE 已完成非阻塞 RMA 数据搬运。用户可以根据需要，对当前 SPE `local_addr` 中的数据进行更改。

#### 使用示例

使用非阻塞型 RMA 操作，将 1 号计算核心中指定的 SPM 地址空间中的数据拷贝到 0 号计算核心指定的 SPM 地址空间内。

```cpp
using namespace sdaa;
#define SIZE 100


__local__ int local_addr[SIZE];
__local__ int remote_addr[SIZE];


__global__ void func()
{
    // 初始化0号计算核心中local_addr的值
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            local_addr[i] = 0;
        }
    }


    // 初始化1号计算核心中remote_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            remote_addr[i] = i;
        }
    }


    // 创建用于进行非阻塞RMA操作的句柄
    RmaHandle handle;
    // 在进行非阻塞RMA操作前进行计算核心之间的同步
    sync_threads();


    // 0号计算核心发起非阻塞RMA操作
    if (threadIdx == 0) {
        // 配置1号计算核心为远端核心
        rma_set_thread_id(handle, 1);
        // 发起非阻塞RMA GET操作
        rma_async_get(local_addr, remote_addr, SIZE * sizeof(int), handle);


        // 使用默认的RmaNormalMode等待当前计算核心完成非阻塞RMA GET操作
        rma_complete(handle);


        // 执行完rma_complete，当前计算核心就可以随意操作由远端获取到的数据了
        for(int i = 0; i < SIZE; i++) {
            printf("local_addr[%d] = %d\n", i, local_addr[i]);
        }
    }


    // 1号计算核心等待0号计算核心完成非阻塞RMA操作
    if (threadIdx == 1) {
        // 配置0号计算核心为向当前计算核心发起非阻塞RMA操作的计算核心
        rma_set_thread_id(handle, 0);


        // 等待1号计算核心完成非阻塞RMA操作逻辑
        // 使用了rma_wait接口，关于该接口用户可参考rma_wait小节的介绍
        rma_wait(handle);
    }
}
```

### 7.6.2.3.5 rma_wait

```cpp
void rma_wait(RmaHandle &handle, unsigned int rmaTime = 0xffff)
```

#### 功能介绍

等待远端计算核心 SPE 完成非阻塞型 RMA 数据搬运。

#### 参数解释

| 参数名称 | 说明 |
|---|---|
| handle | RmaHandle 类型变量，用于存储向当前 SPE 发起非阻塞 RMA 操作的其他 SPE 信息。 |
| rmaTime | 其他 SPE 向当前 SPE 发起非阻塞 RMA 操作的次数，默认为 0xffff。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- 要求 `rma_wait` 和 `rma_complete` 需要成对使用。
- `rmaTime` 是否写入需要与 `rma_complete` 的 `RmaOperateMode` 参数严格对应。
  - 当 `RmaOperateMode` 为 `RmaNormalMode` 时：
    - `rmaTime` 需要使用默认值。
    - 当前 SPE 在发起 `rma_wait` 时，不在 `handle` 配置之内的其他 SPE 不能向当前计算核心发起非阻塞 RMA 操作。
  - 当 `RmaOperateMode` 为 `RmaCustomizeMode` 时：
    - 用户需要准确写入其他 SPE 向当前 SPE 发起的非阻塞 RMA 操作的次数，即当前 SPE 在完成等待上一次其他 SPE 向当前 SPE 发起的非阻塞 RMA 数据搬运后，到当前时间点之间，其他 SPE 向当前 SPE 发起的非阻塞 RMA 数据搬运次数。
    - 当前 SPE 在发起 `rma_wait` 时，不允许其他任何 SPE 向当前 SPE 发起非阻塞 RMA 操作。
- 执行完 `rma_wait`，表示当前 SPE 已完成非阻塞 RMA 数据搬运，用户可以根据需要，对当前 SPE `remote_addr` 中的数据进行更改。

#### 使用示例

1 号和 2 号计算核心使用 RmaCustomizeMode 分别向 0 号计算核心发起非阻塞型 RMA PUT 操作。

```cpp
using namespace sdaa;
#define SIZE 100
#define REMOTE_SIZE 50


__local__ int remote_addr[SIZE];
__local__ int local_addr[REMOTE_SIZE];


__global__ void func()
{
    // 初始化0号计算核心中remote_addr的值
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            remote_addr[i] = 0;
        }
    }


    // 初始化1号计算核心中local_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < REMOTE_SIZE; i++) {
            local_addr[i] = i;
        }
    }


    // 初始化2号计算核心中local_addr的值
    if (threadIdx == 2) {
        for (int i = 0; i < REMOTE_SIZE; i++) {
            local_addr[i] = i * 2;
        }
    }


    // 创建用于进行非阻塞RMA操作的句柄
    RmaHandle handle;
    // 在进行非阻塞RMA操作前进行计算核心之间的同步
    sync_threads();


    // 1号计算核心向0号计算核心发起RMA PUT操作
    if (threadIdx == 1) {
        // 配置0号计算核心为远端核心
        rma_set_thread_id(handle, 0);
        // 发起非阻塞RMA PUT操作
        rma_async_put(local_addr, remote_addr, REMOTE_SIZE * sizeof(int), handle);


        // 使用RmaCustomizeMode等待当前计算核心完成非阻塞RMA PUT操作
        rma_complete(handle, RmaCustomizeMode);
    }


    // 2号计算核心向0号计算核心发起RMA PUT操作
    if (threadIdx == 2) {
        // 配置0号计算核心为远端核心
        rma_set_thread_id(handle, 0);
        // 发起非阻塞RMA PUT操作
        rma_async_put(local_addr, remote_addr + REMOTE_SIZE, REMOTE_SIZE * sizeof(int), handle);


        // 使用RmaCustomizeMode等待当前计算核心完成非阻塞RMA PUT操作
        rma_complete(handle, RmaCustomizeMode);
    }


    if (threadIdx == 0) {
        // 声明由远端计算核心SPE1和SPE2的ID组成的线程组
        ThreadGroup remote_thread_group(0x6);
        // 为0号计算核心配置线程组
        rma_set_thread_group(handle, &remote_thread_group);


        // 等待1号和2号计算核心完成非阻塞RMA操作逻辑
        // 第二个参数2，表示有两个计算核心向当前计算核心总共发起了2次的非阻塞RMA操作
        rma_wait(handle, 2);


        // 打印输出
        for (int i = 0; i < SIZE; i++) {
            printf("%d\n", remote_addr[i]);
        }
    }
}
```

## 7.6.2.4 典型场景示例

### 7.6.2.4.1 单个计算核心向多个计算核心发起非阻塞 RMA 操作

本文主要介绍单个计算核心向多个计算核心发起非阻塞 RMA 操作。

#### 编程思路

- **步骤一**：0 号计算核心 SPE 分别使用 RmaNormalMode 模式和 RmaCustomizeMode 模式通过非阻塞 RMA `rma_async_get` 操作从 1 号计算核心 SPE 获取数据进行加工。
- **步骤二**：0 号计算核心 SPE 完成数据加工后通过非阻塞 RMA 的 `rma_async_put` 操作将数据发送到 2 号和 3 号计算核心 SPE。
- **步骤三**：2 号 3 号计算核心 SPE 成功接收数据后，打印输出数据。

> 图1 单个计算核心向多个计算核心发起非阻塞 RMA 操作

#### RmaNormalMode 模式

```cpp
using namespace sdaa;
// 声明SPM内存空间
__local__   int local_addr[10];
__local__   int remote_addr[10];


__global__ void func()
{
    // 初始化0号计算核心SPE local_addr内存值
    if (threadIdx == 0) {
        for (int i = 0; i < 10; i++) {
            local_addr[i] = 0;
        }
    }


    // 初始化1号计算核心SPE remote_addr内存值
    if (threadIdx == 1) {
        for (int i = 0; i < 10; i++) {
            remote_addr[i] = i;
        }
    }


    // 初始化2号和3号计算核心SPE remote_addr内存值
    if ((threadIdx == 2) || (threadIdx == 3)) {
        for (int i = 0; i < 10; i++) {
            remote_addr[i] = 0;
        }
    }


    // 定义RmaHandle类型的变量
    RmaHandle handle;
    // 同步操作
    sync_threads();


    if (threadIdx == 0) {
        // 0号计算核心SPE使用非阻塞RMA的rma_async_get操作，获取1号计算核心SPE remote_addr中的值
        rma_set_thread_id(handle, 1);
        rma_async_get(local_addr, remote_addr, 10 * sizeof(int), handle);


        // 等待0号计算核心SPE完成非阻塞RMA GET
        rma_complete(handle);


        // 0号计算核心SPE完成非阻塞RMA的rma_async_get操作后，对数据进行二次加工
        for (int i = 0; i < 10; i++) {
            local_addr[i] *= 2;
        }


        // 0号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到2号和3号计算核心
        rma_set_thread_id(handle, 2);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_set_thread_id(handle, 3);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_complete(handle);
    }


    if (threadIdx == 1) {
        // 1号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的rma_async_get操作完成
        rma_set_thread_id(handle, 0);
        rma_wait(handle);
    }


    if (threadIdx == 2) {
        // 2号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        rma_set_thread_id(handle, 0);
        rma_wait(handle);


        // 2号计算核心SPE等待非阻塞RMA的rma_async_put操作完成后，对数据进行打印输出
        printf("SPE 2: ");
        for (int i = 0; i < 10; i++) {
            printf("%d\t", remote_addr[i]);
        }
        printf("\n");
    }


    if (threadIdx == 3) {
        // 3号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        rma_set_thread_id(handle, 0);
        rma_wait(handle);


        // 3号计算核心SPE等待非阻塞RMA的rma_async_put操作完成后，对数据进行打印输出
        printf("SPE 3: ");
        for (int i = 0; i < 10; i++) {
            printf("%d\t", remote_addr[i]);
        }
        printf("\n");
    }
}


int main()
{
    // 设置使用0号计算核心阵列
    sdaaSetDevice(0);
    // 核函数调用
    func<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

#### RmaCustomizeMode 模式

```cpp
using namespace sdaa;
// 声明SPM内存空间
__local__   int local_addr[10];
__local__   int remote_addr[10];


__global__ void func()
{
    // 初始化0号计算核心SPE local_addr内存值
    if (threadIdx == 0) {
        for (int i = 0; i < 10; i++) {
            local_addr[i] = 0;
        }
    }


    // 初始化1号计算核心SPE remote_addr内存值
    if (threadIdx == 1) {
        for (int i = 0; i < 10; i++) {
            remote_addr[i] = i;
        }
    }


    // 初始化2号和3号计算核心SPE remote_addr内存值
    if ((threadIdx == 2) || (threadIdx == 3)) {
        for (int i = 0; i < 10; i++) {
            remote_addr[i] = 0;
        }
    }


    // 定义RmaHandle类型的变量
    RmaHandle handle;
    // 同步操作
    sync_threads();


    if (threadIdx == 0) {
        // 0号计算核心SPE使用非阻塞RMA的rma_async_get操作，获取1号计算核心SPE remote_addr中的值
        rma_set_thread_id(handle, 1);
        rma_async_get(local_addr, remote_addr, 10 * sizeof(int), handle);


        // 等待0号计算核心SPE完成非阻塞RMA的rma_async_get操作
        rma_complete(handle, RmaCustomizeMode);


        // 0号计算核心SPE完成非阻塞RMA的rma_async_get操作后，对数据进行二次加工
        for (int i = 0; i < 10; i++) {
            local_addr[i] *= 2;
        }


        // 0号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到2号和3号计算核心
        rma_set_thread_id(handle, 2);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_set_thread_id(handle, 3);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_complete(handle, RmaCustomizeMode);
    }


    if (threadIdx == 1) {
        // 1号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的rma_async_get操作完成
        rma_set_thread_id(handle, 0);
        // 1表示0号计算核心SPE通过RmaCustomizeMode向1号计算核心SPE发起了1次非阻塞RMA操作
        rma_wait(handle, 1);
    }


    if (threadIdx == 2) {
        // 2号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的 rma_async_put操作完成
        rma_set_thread_id(handle, 0);
        // 1表示0号计算核心SPE通过RmaCustomizeMode向2号计算核心SPE发起了1次非阻塞RMA操作
        rma_wait(handle, 1);


        // 2号计算核心SPE等待非阻塞RMA的rma_async_put操作完成后，对数据进行打印输出
        printf("SPE 2: ");
        for (int i = 0; i < 10; i++) {
            printf("%d\t", remote_addr[i]);
        }
        printf("\n");
    }


    if (threadIdx == 3) {
        // 3号计算核心SPE等待0号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        rma_set_thread_id(handle, 0);
        // 1表示0号计算核心SPE通过RmaCustomizeMode向2号计算核心SPE发起了1次非阻塞RMA操作
        rma_wait(handle, 1);


        // 3号计算核心SPE等待非阻塞RMA rma_async_put完成后，对数据进行打印输出
        printf("SPE 3: ");
        for (int i = 0; i < 10; i++) {
            printf("%d\t", remote_addr[i]);
        }
        printf("\n");
    }
}


int main()
{
    // 设置使用0号计算核心阵列
    sdaaSetDevice(0);
    // 核函数调用
    func<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

### 7.6.2.4.2 多个计算核心向单个计算核心发起非阻塞 RMA 操作

本文主要介绍多个计算核心向单个计算核心发起非阻塞 RMA 操作。

#### 编程思路

- **步骤一**：1 号计算核心 SPE 分别使用 RmaNormalMode 模式和 RmaCustomizeMode 模式通过非阻塞 RMA 的 `rma_async_put` 操作将数据发送到 0 号计算核心 SPE 上。
- **步骤二**：0 号计算核心 SPE 完成数据接收后，2 号 3 号计算核心 SPE 分别使用 RmaNormalMode 模式和 RmaCustomizeMode 模式通过非阻塞 RMA 的 `rma_async_put` 操作将数据发送到 0 号计算核心 SPE 上。
- **步骤三**：0 号计算核心 SPE 成功接收数据后，打印输出数据。

> 图1 多个计算核心向单个计算核心发起非阻塞 RMA 操作

#### RmaNormalMode 模式

```cpp
using namespace sdaa;
__local__   int local_addr[10];
__local__   int remote_addr[30];


__global__ void func()
{
    // 初始化0号计算核心SPE remote_addr内存值
    if (threadIdx == 0) {
        for (int i = 0; i < 30; i++) {
            remote_addr[i] = 0;
        }
    }


    // 初始化1号，2号和3号计算核心SPE local_addr内存值
    if ((threadIdx == 1) || (threadIdx == 2) || (threadIdx == 3)) {
        for (int i = 0; i < 10; i++) {
            local_addr[i] = i * threadIdx;
        }
    }


    // 定义RmaHandle类型的变量
    RmaHandle handle;
    // 同步操作
    sync_threads();


    if (threadIdx == 1) {
        // 1号计算核心SPE通过非阻塞RMA rma_async_put操作，将数据发送到0号计算核心
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_complete(handle);
    }


    if (threadIdx == 0) {
        // 0号计算核心SPE等待1号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        rma_set_thread_id(handle, 1);
        rma_wait(handle);
    }


    // 同步操作
    sync_threads();


    if (threadIdx == 2) {
        // 2号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到0号计算核心SPE
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr + 10, 10 * sizeof(int), handle);


        rma_complete(handle);
    }


    if (threadIdx == 3) {
        // 3号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到0号计算核心SPE
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr + 20, 10 * sizeof(int), handle);
        rma_complete(handle);
    }


    if (threadIdx == 0) {
        // 0号计算核心SPE等待2号和3号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        ThreadGroup remote_thread_group(0xC);
        rma_set_thread_group(handle, &remote_thread_group);
        rma_wait(handle);


        // 0号计算核心SPE等待非阻塞RMA的rma_async_put操作完成后，进行打印输出
        printf("SPE 0: ");
        for (int i = 0; i < 30; i++) {
            printf("%d\t", remote_addr[i]);
        }


        printf("\n");
    }
}


int main()
{
    // 设置使用0号计算核心阵列
    sdaaSetDevice(0);
    // 核函数调用
    func<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

#### RmaCustomizeMode 模式

```cpp
using namespace sdaa;
__local__ int local_addr[10];
__local__ int remote_addr[30];


__global__ void func()
{
    // 初始化0号计算核心SPE remote_addr内存值
    if (threadIdx == 0) {
        for (int i = 0; i < 30; i++) {
            remote_addr[i] = 0;
        }
    }


    // 初始化1号，2号和3号计算核心SPE local_addr内存值
    if ((threadIdx == 1) || (threadIdx == 2) || (threadIdx == 3)) {
        for (int i = 0; i < 10; i++) {
            local_addr[i] = i * threadIdx;
        }
    }


    // 定义RmaHandle类型的变量
    RmaHandle handle;
    // 同步操作
    sync_threads();


    if (threadIdx == 1) {
        // 1号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到0号计算核心SPE
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr, 10 * sizeof(int), handle);


        rma_complete(handle, RmaCustomizeMode);
    }


    if (threadIdx == 0) {
        // 0号计算核心SPE等待1号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        rma_set_thread_id(handle, 1);
        // 1表示0号计算核心在完成上一次非阻塞RMA操作有，其他计算核心向0号计算核心发起了1次非阻塞RMA操作
        rma_wait(handle, 1);
    }


    // 同步操作
    sync_threads();


    if (threadIdx == 2) {
        // 2号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到0号计算核心SPE
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr + 10, 10 * sizeof(int), handle);


        rma_complete(handle, RmaCustomizeMode);
    }


    if (threadIdx == 3) {
        // 3号计算核心SPE通过非阻塞RMA的rma_async_put操作，将数据发送到0号计算核心SPE
        rma_set_thread_id(handle, 0);
        rma_async_put(local_addr, remote_addr + 20, 10 * sizeof(int), handle);


        rma_complete(handle, RmaCustomizeMode);
    }


    if (threadIdx == 0) {
        // 0号计算核心SPE等待2号和3号计算核心SPE发起的非阻塞RMA的rma_async_put操作完成
        ThreadGroup remote_thread_group(0xC);
        rma_set_thread_group(handle, &remote_thread_group);
        // 2表示0号计算核心在完成上一次非阻塞RMA操作有，其他计算核心向0号计算核心发起了2次非阻塞RMA操作
        rma_wait(handle, 2);


        // 0号计算核心SPE等待非阻塞RMA PUT完成后进行打印输出
        printf("SPE 0: ");
        for (int i = 0; i < 30; i++) {
            printf("%d\t", remote_addr[i]);
        }


        printf("\n");
    }
}


int main()
{
    // 设置使用0号计算核心阵列
    sdaaSetDevice(0);
    // 核函数调用
    func<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

## 7.6.3 Broadcast 数据搬运

### 7.6.3.1 概述

Broadcast 数据搬运是指同一计算核心阵列 SPA 内，指定的计算核心 SPE 向多个 SPE 传输数据。Broadcast 数据搬运可以通过 BroadcastHandle 配置 SPE 加入广播组，进而接收广播数据。

从调用接口上可以分为阻塞型 Broadcast 数据搬运和非阻塞型 Broadcast 数据搬运：

- **阻塞型 Broadcast 数据搬运接口**：使用简单，但性能不佳。
- **非阻塞型 Broadcast 数据搬运接口**：使用相对复杂，但性能较好。

#### BroadcastHandle 及配置接口

BroadcastHandle 及配置接口由以下函数接口组成：

- **BroadcastHandle**：用于配置广播组，控制接收广播的计算核心 SPE。
- **broadcast_set_thread_group**：通过线程组的方式设置当前 SPA 内的各个 SPE 是否接收广播数据。

#### 阻塞型 Broadcast 数据搬运

阻塞型 Broadcast 操作由以下函数接口组成：

- **broadcast**：在同一计算核心阵列 SPA 内，将指定存储空间的数据以阻塞的方式搬运到所有 SPE 的 SPM 存储空间，或搬运到由 `BroadcastHandle` 指定 SPE 的 SPM 存储空间内。

#### 非阻塞型 Broadcast 数据搬运

非阻塞型 Broadcast 操作由以下函数接口组成：

- **broadcast_async**：在同一计算核心阵列 SPA 内，将指定存储空间的数据以非阻塞的方式搬运到由 `BroadcastHandle` 指定的部分或全部 SPE 的 SPM 存储空间内。
- **broadcast_wait**：等待当前计算核心 SPE 上所有使用同一个 `BroadcastHandle` 的非阻塞型 Broadcast 数据搬运操作完成。

### 7.6.3.2 BroadcastHandle 及配置接口

#### 7.6.3.2.1 概述

BroadcastHandle 是 Broadcast 数据搬运的句柄，由以下函数接口组成：

- **BroadcastHandle**：用于配置当前广播组，控制接收广播的计算核心 SPE 和数据搬运过程中的跨步参数。
- **broadcast_set_thread_group**：通过线程组的方式设置当前 SPA 内的各个 SPE 是否接收广播数据。

#### 7.6.3.2.2 BroadcastHandle

```cpp
BroadcastHandle::BroadcastHandle()
BroadcastHandle::BroadcastHandle(ThreadGroup *thread_group)
```

##### 功能介绍

用于配置当前广播组。默认广播组包括当前计算核心阵列 SPA 内所有计算核心 SPE，即所有 SPE 均接受广播数据。

##### 参数解释

| 参数名称 | 说明 |
|---|---|
| thread_group | ThreadGroup 指针类型变量，用于配置 SPE 是否加入广播组并接收数据。 |

##### 注意事项

- 需要引入 sdaa 命名空间。
- 使用 `BroadcastHandle` 创建变量时需要在当前所有 SPE 都可以执行到的代码段内创建。
- 在创建完 `BroadcastHandle` 类型的变量后，且在执行 Broadcast 数据搬运之前，需要使用 `sync_threads` 函数接口在 SPE 间进行一次同步操作。

##### 使用示例 1

```cpp
using namespace sdaa;
__global__ void func()
{
    BroadcastHandle handle; // 创建BroadcastHandle类型变量，所有SPE均接收数据


    // 其他代码逻辑


    sync_threads(); // 计算核心之间进行一次同步操作


    // 执行Broadcast操作
}
```

##### 使用示例 2

```cpp
using namespace sdaa;
__global__ void func()
{
    ThreadGroup thread_group(0xFF00);
    BroadcastHandle handle(&thread_group); // 创建BroadcastHandle类型变量，仅SPE8~15接收数据


    // 其他代码逻辑


    sync_threads(); // 计算核心之间进行一次同步操作


    // 执行Broadcast操作
}
```
