---
id: doc-sdaa-c-programming-guide-v3-1-0-p02b
title: "SDAA C 编程指南 v3.1.0 — 第2部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "5312-6148"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [matmul, memory, programming-model, rma, sdaa, sdaa-c, teco-t1, thread-group-sync]
---

# SDAA C 编程指南 v3.1.0（第2部分）

本部分覆盖第 7 章（函数接口）中阻塞型 RMA 数据搬运接口 `rma_get`（续）、`rma_put`，以及非阻塞型 RMA 数据搬运的句柄与配置接口（`RmaHandle`、`rma_set_thread_id`、`rma_set_thread_group`）、`rma_async_get` 与 `rma_async_put`。

## 7.6.2.2 阻塞型 RMA 数据搬运（续）

### 7.6.2.2.1 rma_get（续：注意事项与使用示例）

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- 数据搬运的数据量需要是 4B 的整数倍。
- 仅当前 SPE 和远端 SPE 需要执行该函数接口，其他 SPE 不能执行。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 RMA 数据搬运的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。正确的使用方法，可参考使用示例 2。

> **提示：**
>
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 RMA 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 RMA 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

将 1 号计算核心中指定的 SPM 地址空间中的数据拷贝到 0 号计算核心指定的 SPM 地址空间内。

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
            local_addr[i] = 0;
        }
    }


    // 初始化1号计算核心中remote_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            remote_addr[i] = i;
        }
    }


    // 仅0号计算核心和1号计算核心执行该函数接口
    if ((threadIdx == 0) || (threadIdx == 1)) {
        rma_get(local_addr, remote_addr, SIZE * sizeof(int), 0, 1);
    }


    // 阻塞接口执行完后打印0号计算核心中local_addr的内容
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            printf("local_addr[%d] = %d\n", i, local_addr[i]);
        }
    }
}
```

#### 使用示例 2

将 1 号计算核心中指定的 SPM 地址空间中的数据拷贝到 0 号计算核心指定的 SPM 地址空间内。

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
            spm_addr[i] = 0;
        }
    }


    // 初始化1号计算核心中remote_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            spm_addr[i] = i;
        }
    }


    // 仅0号计算核心和1号计算核心执行该函数接口
    if ((threadIdx == 0) || (threadIdx == 1)) {
        rma_get(spm_addr, spm_addr, SIZE * sizeof(int), 0, 1);
    }


    // 阻塞接口执行完后打印0号计算核心中spm_addr的内容
    if (threadIdx == 0) {
        for (int i = 0; i < SIZE; i++) {
            printf("spm_addr[%d] = %d\n", i, spm_addr[i]);
        }
    }


    free(spm_addr);
}
```

### 7.6.2.2.2 rma_put

```cpp
void rma_put(const void *local_addr, void *remote_addr, size_t size, unsigned long local_id, unsigned long remote_id)
```

#### 功能介绍

在同一计算核心阵列 SPA 内，将当前计算核心 SPE 中指定的 SPM 存储数据以阻塞的方式搬运到远端计算核心 SPE 中指定的 SPM 存储空间内。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| local_addr | 数据搬运的源地址，当前计算核心的 SPM 存储空间地址。 |
| remote_addr | 数据搬运的目的地址，远端计算核心的 SPM 存储空间地址。 |
| size | 数据搬运大小，单位：Byte。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| local_id | 发起 RMA 操作的计算核心 ID。 |
| remote_id | 远端计算核心的 ID。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- 数据搬运的数据量需要是 4B 的整数倍。
- 仅当前 SPE 和远端 SPE 需要执行该函数接口，其他 SPE 不能执行。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 RMA 数据搬运的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。正确的使用方法，可参考使用示例 2。

> **提示：**
>
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 RMA 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 RMA 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

将 0 号计算核心中指定的 SPM 地址空间中的数据拷贝到 1 号计算核心指定的 SPM 地址空间内。

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


    // 仅0号计算核心和1号计算核心执行该函数接口
    if ((threadIdx == 0) || (threadIdx == 1)) {
        rma_put(local_addr, remote_addr, SIZE * sizeof(int), 0, 1);
    }


    // 阻塞接口执行完后打印1号计算核心中remote_addr的内容
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            printf("remote_addr[%d] = %d\n", i, remote_addr[i]);
        }
    }
}
```

#### 使用示例 2

将 0 号计算核心中指定的 SPM 地址空间中的数据拷贝到 1 号计算核心指定的 SPM 地址空间内。

```cpp
using namespace sdaa;
#define SIZE 100


__global__ void func()
{
    // 使用malloc申请SPM空间
    int *spm_addr= (int *)malloc(SIZE * sizeof(int));


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


    // 仅0号计算核心和1号计算核心执行该函数接口
    if ((threadIdx == 0) || (threadIdx == 1)) {
        rma_put(spm_addr, spm_addr, SIZE * sizeof(int), 0, 1);
    }


    // 阻塞接口执行完后打印1号计算核心中spm_addr的内容
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            printf("spm_addr[%d] = %d\n", i, spm_addr[i]);
        }
    }


    free(spm_addr);
}
```

## 7.6.2.3 非阻塞型 RMA 数据搬运

### 7.6.2.3.1 RmaHandle 及配置接口

#### 7.6.2.3.1.1 概述

RmaHandle 是非阻塞型 RMA 数据搬运的句柄，由以下函数接口组成：

- **RmaHandle**：用于存储远端计算核心 SPE 的 ID。
- **rma_set_thread_id**：配置远端计算核心 SPE 的 ID。
- **rma_set_thread_group**：配置由多个远端计算核心 SPE 的 ID 组成的线程组。

#### 7.6.2.3.1.2 RmaHandle

```cpp
RmaHandle::RmaHandle()
```

##### 功能介绍

用于存储远端计算核心 SPE 的 ID。

##### 注意事项

- 需要引入 sdaa 命名空间。
- 使用 RmaHandle 创建变量时需要在当前计算核心 SPE 和远端计算核心 SPE 都可以执行到的代码段内创建。
- 在创建完 RmaHandle 类型的变量后和执行非阻塞型 RMA 数据搬运之前需要使用 sync_threads 函数接口在计算核心间进行一次同步操作。

##### 使用示例

```cpp
using namespace sdaa;
__global__ void func()
{
    // 创建RmaHandle类型变量
    RmaHandle handle;


    // 其他代码逻辑


    // 计算核心之间进行一次同步操作
    sync_threads();


    // 执行非阻塞型RMA操作
}
```

#### 7.6.2.3.1.3 rma_set_thread_id

```cpp
void rma_set_thread_id(RmaHandle &handle, unsigned long remote_thread_id)
```

##### 功能介绍

配置远端计算核心 SPE 的 ID。

##### 参数解释

| 参数名称 | 说明 |
|----------|------|
| handle | RmaHandle 类型变量，用于存储远端计算核心的 ID。 |
| remote_thread_id | 远端计算核心的 ID。 |

##### 返回值

无。

##### 注意事项

- 需要引入 sdaa 命名空间。
- 如果使用 rma_set_thread_id 前，已使用 rma_set_thread_group 为同一个 RmaHandle 类型变量配置了由多个远端 SPE 的 ID 组成的线程组，则使用 remote_thread_id 为 RmaHandle 类型变量配置远端 SPE 的 ID 后，RmaHandle 类型变量中的线程组仅保留当前配置的一个远端 SPE 的 ID。

##### 使用示例

SPE 0 向 SPE 2 发起非阻塞型 RMA 数据搬运。

```cpp
using namespace sdaa;
__device__ void func()
{
    RmaHandle handle;


    // 其他代码逻辑


    // 计算核心之间进行一次同步操作
    sync_threads();


    if (threadIdx == 0) {
        // 为0号计算核心配置远端ID
        rma_set_thread_id(handle, 2);


        // 执行非阻塞型RMA操作
    }


    if (threadIdx == 2) {
        // 为2号计算核心配置远端ID
        rma_set_thread_id(handle, 0);


        // 执行非阻塞型RMA等待操作
    }
}
```

#### 7.6.2.3.1.4 rma_set_thread_group

```cpp
void rma_set_thread_group(RmaHandle &handle, ThreadGroup *remote_thread_group)
```

##### 功能介绍

配置由多个远端计算核心 SPE 的 ID 组成的线程组。

> **说明：**
>
> 配置由多个远端计算核心 SPE 的 ID 组成的线程组建议配合 rma_wait 使用，等待线程组中的 SPE 完成非阻塞型 RMA 数据搬运。

##### 参数解释

| 参数名称 | 说明 |
|----------|------|
| handle | RmaHandle 类型变量，用于存储远端计算核心的 ID。 |
| remote_thread_group | 由多个远端计算核心 SPE 的 ID 组成的线程组。 |

##### 返回值

无。

##### 注意事项

- 需要引入 sdaa 命名空间。
- 如果使用 rma_set_thread_group 为 RmaHandle 类型变量配置线程组前，已使用 rma_set_thread_id 为同一个 RmaHandle 类型变量配置了一个远端 SPE 的 ID，则使用 rma_set_thread_group 配置线程组后，RmaHandle 类型变量仅保留当前配置的线程组。

##### 使用示例

SPE 0 向 SPE 2 发起非阻塞型 RMA 数据搬运。

```cpp
using namespace sdaa;
__device__ void func()
{
     RmaHandle handle;


     // 其他代码逻辑


     // 计算核心之间进行一次同步操作
     sync_threads();


     if (threadIdx == 0) {
         // 为0号计算核心配置远端ID
         rma_set_thread_id(handle, 2);


         // 执行非阻塞型RMA操作
     }


     if (threadIdx == 1) {
         // 为1号计算核心配置远端ID
         rma_set_thread_id(handle, 2);


         // 执行非阻塞型RMA操作
     }


     if (threadIdx == 2) {
         // 声明由远端计算核心SPE的ID组成的线程组
         ThreadGroup remote_thread_group(0x3);
         // 为2号计算核心配置线程组
         rma_set_thread_group(handle, &remote_thread_group);


         // 执行非阻塞型RMA等待操作
     }


     // 其他代码逻辑
}
```

### 7.6.2.3.2 rma_async_get

```cpp
void rma_async_get(void *local_addr, const void *remote_addr, size_t size, RmaHandle &handle)
```

#### 功能介绍

将远端计算核心 SPE 中指定的 SPM 存储空间数据非阻塞拷贝到当前计算核心 SPE 中指定的 SPM 存储空间内。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| local_addr | 数据搬运的目的地址，当前计算核心的 SPM 存储空间地址。 |
| remote_addr | 数据搬运的源地址，远端计算核心的 SPM 存储空间地址。 |
| size | 数据搬运大小，单位：Byte。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| handle | RmaHandle 类型变量，用于存储远端计算核心的 ID。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- 数据搬运的数据量需要是 4B 的整数倍。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 RMA 数据搬运的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。使用 malloc 分配完 SPM 空间后，在执行非阻塞型 RMA 数据搬运之前，需要使用 sync_threads 进行同步。正确的使用方法，可参考使用示例 2。

> **提示：**
>
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 RMA 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 RMA 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

使用非阻塞型 RMA 操作，将 1 号计算核心中指定的 SPM 地址空间中的数据拷贝到 0 号计算核心指定的 SPM 地址空间内。

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


        // 等待当前计算核心完成非阻塞RMA GET操作
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

使用非阻塞型 RMA 操作，将 1 号计算核心中指定的 SPM 地址空间中的数据拷贝到 0 号计算核心指定的 SPM 地址空间内。

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
            spm_addr[i] = 0;
        }
    }


    // 初始化1号计算核心中spm_addr的值
    if (threadIdx == 1) {
        for (int i = 0; i < SIZE; i++) {
            spm_addr[i] = i;
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
        rma_async_get(spm_addr, spm_addr, SIZE * sizeof(int), handle);


        // 等待当前计算核心完成非阻塞RMA GET操作
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

### 7.6.2.3.3 rma_async_put

```cpp
void rma_async_put(const void *local_addr, void *remote_addr, size_t size, RmaHandle &handle)
```

#### 功能介绍

将当前计算核心 SPE 中指定的 SPM 存储空间数据非阻塞拷贝到远端计算核心 SPE 中指定的 SPM 存储空间内。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| local_addr | 数据搬运的源地址，当前计算核心的 SPM 存储空间地址。 |
| remote_addr | 数据搬运的目的地址，远端计算核心的 SPM 存储空间地址。 |
| size | 数据搬运大小，单位：Byte。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| handle | RmaHandle 类型变量，用于存储远端计算核心的 ID。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- 数据搬运的数据量需要是 4B 的整数倍。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 RMA 数据搬运的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。使用 malloc 分配完 SPM 空间后，在执行非阻塞型 RMA 数据搬运之前，需要使用 sync_threads 进行同步。正确的使用方法，可参考使用示例 2。

> **提示：**
>
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 RMA 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 RMA 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

<!-- rma_async_put 的使用示例 1、使用示例 2 起始于第 6153 行，属于本文档下一部分（第3部分）的行范围，故在此不重复收录。 -->
