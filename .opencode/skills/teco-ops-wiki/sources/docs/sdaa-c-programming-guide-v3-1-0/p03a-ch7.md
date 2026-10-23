---
id: doc-sdaa-c-programming-guide-v3-1-0-p03a
title: "SDAA C 编程指南 v3.1.0 — 第3部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "7296-8666"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [broadcast, matmul, memory, programming-model, sdaa, sdaa-c, teco-t1, thread-group-sync]
---

# SDAA C 编程指南 v3.1.0（第3部分）

本部分覆盖第 7 章函数接口中 Broadcast 数据搬运（线程组配置、阻塞型 / 非阻塞型 Broadcast、典型场景示例）以及跨步类型（MemoryStride）相关内容。

## 7.6.3.2.3 broadcast_set_thread_group

```cpp
void broadcast_set_thread_group(BroadcastHandle &handle, ThreadGroup *thread_group)
```

### 功能介绍

通过线程组的方式设置当前 SPA 内的各个 SPE 是否接收广播数据。

### 参数解释

| 参数名称 | 说明 |
|----------|------|
| handle | BroadcastHandle 类型变量，标识当前的广播组。 |
| thread_group | ThreadGroup 指针类型变量，用于配置 SPE 是否加入广播组并接收数据。 |

### 返回值

无。

### 注意事项

- 需要引入 sdaa 命名空间。
- 使用 `broadcast_set_thread_group` 接口为 BroadcastHandle 类型变量配置完线程组后，如果需要对线程组进行修改可直接使用 ThreadGroup 的相关配置接口。在修改完线程组后无需再次使用 `broadcast_set_thread_group` 为同一个 BroadcastHandle 类型变量进行配置。

### 使用示例

```cpp
using namespace sdaa;
__global__ void func()
{
      ThreadGroup thread_group(0xFF00);    // 创建ThreadGroup类型变量，将SPE8~SPE15组成一个线程组
      BroadcastHandle handle;              // 创建BroadcastHandle类型变量
      broadcast_set_thread_group(handle, &thread_group);   // 为handle配置线程组
      sync_threads(); // 计算核心之间进行一次同步操作


      // 执行Broadcast操作，广播到SPE8~15


      thread_group_exclude(thread_group, 8); // 修改广播组，仅SPE9~SPE15接收数据


      // 无需使用broadcast_set_thread_group再次对handle进行配置，可直接执行Broadcast操作，广播到SPE9~SPE15
}
```

## 7.6.3.3 阻塞型 Broadcast 数据搬运

### 7.6.3.3.1 broadcast

```cpp
void broadcast(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, unsigned long root, BroadcastDirect direct)
void broadcast(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, unsigned long root, BroadcastDirect direct, BroadcastHandle &handle)
```

#### 功能介绍

在同一计算核心阵列 SPA 内，将指定存储空间的数据以阻塞的方式搬运到所有 SPE 的 SPM 存储空间，或搬运到由 `BroadcastHandle` 指定 SPE 的 SPM 存储空间内。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| dst | Broadcast 数据搬运的目的地址。 |
| src | Broadcast 数据搬运的源地址。 |
| size | Broadcast 数据搬运大小，单位：Byte，需要是 4B 的整数倍。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| section_1d | 一维数据搬运单元大小，单位 Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源和目标存储空间的一维跨步单元大小，单位：Byte。说明：MemoryStride 的设置受硬件限制：目前仅支持在 Global 存储空间，设置跨步单元的大小。跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。如果 MemoryStride 中的 `dst_stride` 和 `src_stride` 都设置为 0，则为连续数据搬运，且当前接口的 `section_1d` 参数无效。 |
| root | 发送方的 SPE 的 threadIdx。数据搬运方向为 BroadcastGlobalToSpm 时，root 需为线程组内的某个线程。 |
| direct | 枚举类型 BroadcastDirect，Broadcast 数据搬运方向。非跨步场景：支持以下数据搬运方向：BroadcastGlobalToSpm：Global 存储空间向 SPM 存储空间的 Broadcast 数据搬运。BroadcastSpmToSpm：SPM 存储空间到 SPM 存储空间的 Broadcast 数据搬运。跨步场景：支持以下数据搬运方向中 Global 存储空间跨步设置：BroadcastGlobalToSpm：Global 存储空间向 SPM 存储空间的 Broadcast 数据搬运。 |
| handle | （可选）BroadcastHandle 类型变量，表示当前广播组，用于标识接收广播的 SPE。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- Broadcast 数据搬运的数据量需要是 4B 的整数倍。
- 如果使用跨步功能，Global 存储空间的跨步需要是 4B 的整数倍。
- 不使用 `BroadcastHandle` 参数时，为全广播（SPA 内所有 SPE 均参与），此时所有 SPE 都必须执行 broadcast 函数，否则会造成同步失败，可参考使用示例 1。
- 使用 `BroadcastHandle` 参数时，不要求所有 SPE 必须执行 broadcast 函数，但发送方 SPE 和 `BroadcastHandle` 广播组内的所有 SPE 都需要执行 broadcast 函数，否则会造成不可预知的结果（即不能保证广播完成），可参考使用示例 2。
- 多次执行 `broadcast` 函数向同一地址发送不同数据时，接收方无法保证接收数据的时序准确性。您可以使用 sync_threads 进行数据同步，从而确保连续接收数据的安全性，可参考使用示例 3。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 Broadcast 操作的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。使用 malloc 分配完 SPM 空间后，在发起 Broadcast 操作前，需要使用 sync_threads 进行同步。正确的使用方法，可参考使用示例 2。

> **提示：**
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 Broadcast 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 Broadcast 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

```cpp
using namespace sdaa;
#define SIZE 10


// 使用__local__ 分配的SPM存储空间
__local__ int dst[SIZE];
__local__ int src[SIZE];


__global__ void func()
{
    ... // 准备广播数据


    broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm); // 正确，0号SPE广播到所有SPE


    if (threadIdx < 8) { // 假设threadDim > 8
        broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm); // 错误，无handle的broadcast只能做全广播
    }
}
```

#### 使用示例 2

```cpp
using namespace sdaa;
#define SIZE 10


__global__ void func()
{
    // 使用malloc申请SPM空间（需要确保参与广播的SPE上dst和src地址相同）
    int *dst = (int *)malloc(SIZE * sizeof(int));
    int *src = (int *)malloc(SIZE * sizeof(int));


    ... // 准备广播数据


    BroadcastHandle handle; // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确，0号SPE广播到所有SPE

    if (threadIdx < 8) { // 假设threadDim > 8
         broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 错误，只能保证SPE0~SPE7接收完数据，不能保证其余SPE接收完数据
    }


    ThreadGroup thread_group(0xFF);     // 定义由SPE0~SPE7组成的线程组
    broadcast_set_thread_group(handle, &thread_group); // 设置仅SPE0~SPE7接收广播


    broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确，仅SPE0~SPE7接收数据，其余SPE执行broadcast时将立即退出


    if (threadIdx < 8) {
         broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确
    }


    if (threadIdx == 0 || thread_group_is_included(thread_group, threadIdx)) {
         broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确，确保数据发送方SPE和线程组内的SPE进入
    }


    if (threadIdx < 4) {
         broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 错误，仅SPE0~3接收完数据，不能保证SPE4~7接收完数据
    }


    free(src);
    free(dst);
}
```

#### 使用示例 3

```cpp
using namespace sdaa;
#define SIZE 10


// 使用__local__ 分配的SPM存储空间
__local__ int dst[SIZE];
__local__ int src[SIZE];


__global__ void func()
{
    ... // 准备广播数据


    const unsigned int root = 0; // 发送方ID
    BroadcastHandle handle; // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    // 错误示范：
    // root多次向相同地址广播数据，由于各线程独立执行，因此不能保证各线程执行broadcast操作的时序性。
    // 例如发送方执行速度较快，在执行第二次broadcast时，其他线程还没执行第一次broadcast，
    // 就可能导致发送方第二次发送的数据覆盖第一次发送的数据，其他线程在执行第一次broadcast后接收到的数据
    // 实际为发送方第二次发送的数据。
    for (int i = 0; i < 100; i++) {
        if (threadIdx == root) {
            src[0] = i; // 修改src的值
        }
        broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, root, BroadcastSpmToSpm, handle); // 发送方线程向其他线程发送数据
        if (threadIdx != root) {
            if (dst[0] == i) ... // 获取dst的值
        }
    }


    // 正确做法：
    // 在处理有可能因线程不同步而导致的数据冲突的问题时，可加上线程同步操作，
    // 以保证各线程执行broadcast操作的时序性。
    for (int i = 0; i < 100; i++) {
        if (threadIdx == root) {
            src[0] = i; // 修改src的值
        }
        sync_threads(); // 在发送数据前加上同步，确保其他线程进入能接收数据的状态
        broadcast(dst, src, SIZE * sizeof(int), 0, {0, 0}, root, BroadcastSpmToSpm, handle); // 发送方线程向其他线程发送数据
        if (threadIdx != root) {
            if (dst[0] == i) ... // 获取dst的值
        }
    }


}
```

#### 使用示例 4

```cpp
using namespace sdaa;


#define SRC_SIZE 100
#define DST_SIZE 50


__device__ int src[SRC_SIZE];
__global__ void func()
{
    // 仅使用SPE0初始化Global存储空间数组
    if (threadIdx == 0) {
        for (int i = 0; i < SRC_SIZE; i++) {
            src[i] = i;
        }
    }


    int *dst = (int *)malloc(DST_SIZE * sizeof(int));   // 声明目的地址
    // 初始化目标存储空间
    for(int i = 0; i < DST_SIZE; i++) {
        dst[i] = 0;
    }


    // 进行Global存储空间跨步为40B的广播
    size_t global_stride = 10 * sizeof(int);
    ThreadGroup thread_group(0xFF00);      // 定义SPE8~SPE15组成线程组
    BroadcastHandle handle(&thread_group); // 定义BroadcastHandle类型变量
    sync_threads();    // 创建完handle后执行一次同步操作


    // 仅发起广播的SPE和线程组内的SPE执行广播操作
    if ((threadIdx == 0) || (thread_group_is_included(thread_group, threadIdx))) {
        broadcast(dst, src, DST_SIZE * sizeof(int), 10 * sizeof(int), {0, global_stride}, 0, BroadcastGlobalToSpm, handle);
    }


    ... // 其他操作


    thread_group_set_mask(thread_group, 0xFF0000);    // 修改线程组，当前线程组内由SPE16~SPE23构成
    // 使用线程组配置接口修改完线程组后直接进行新一轮的广播操作
    if ((threadIdx == 31) || (thread_group_is_included(thread_group, threadIdx))) {
        broadcast(dst, src, DST_SIZE * sizeof(int), 10 * sizeof(int), {0, global_stride}, 31, BroadcastGlobalToSpm, handle);
    }


    ... // 其他操作


    free(dst);
}
```

## 7.6.3.4 非阻塞型 Broadcast 数据搬运

### 7.6.3.4.1 broadcast_async

```cpp
void broadcast_async(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, unsigned long root, BroadcastDirect direct, BroadcastHandle &handle)
void broadcast_async(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, BroadcastDirect direct, BroadcastHandle &handle)
```

#### 功能介绍

在同一计算核心阵列 SPA 内，将指定存储空间的数据以非阻塞的方式搬运到由 BroadcastHandle 指定的部分或全部 SPE 的 SPM 存储空间内。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| dst | Broadcast 数据搬运的目的地址。 |
| src | Broadcast 数据搬运的源地址。 |
| size | Broadcast 数据搬运大小，单位：Byte，需要是 4B 的整数倍。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| section_1d | 一维数据搬运单元大小，单位 Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源和目标存储空间的一维跨步单元大小，单位：Byte。说明：MemoryStride 的设置受硬件限制：目前仅支持在 Global 存储空间，设置跨步单元的大小。跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。如果 MemoryStride 中的 `dst_stride` 和 `src_stride` 都设置为 0，则为连续数据搬运，且当前接口的 `section_1d` 参数无效。 |
| root | （可选）表示发送方的 SPE 的 threadIdx。说明：使用带 root 参数的 broadcast_async 接口时：需要发送方 SPE 和 BroadcastHandle 广播组内的 SPE 都需要执行该函数，否则会造成不可预知的结果（即不能保证广播完成），可参考使用示例 5。需要配合 `broadcast_wait(BroadcastHandle &handle)` 接口使用。使用不带 root 参数的 broadcast_async 接口时：仅需在发送方的 SPE 内执行该函数，可参考使用示例 2。需要配合 `broadcast_wait(BroadcastHandle &handle, unsigned int until_times)` 接口使用。 |
| direct | 枚举类型 BroadcastDirect，Broadcast 数据搬运方向。非跨步场景：支持以下数据搬运方向：BroadcastGlobalToSpm：Global 存储空间向 SPM 存储空间的 Broadcast 数据搬运。BroadcastSpmToSpm：SPM 存储空间到 SPM 存储空间的 Broadcast 数据搬运。跨步场景：支持以下数据搬运方向：BroadcastGlobalToSpm：Global 存储空间向 SPM 存储空间的 Broadcast 数据搬运。 |
| handle | BroadcastHandle 类型变量，表示当前广播组，用于标识接收广播的 SPE。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- SPM 存储空间地址需要 4B 对齐。
- Broadcast 数据搬运的数据量需要是 4B 的整数倍。
- 如果使用跨步功能，Global 存储空间的跨步需要是 4B 的整数倍。
- `broadcast_async` 需要与 broadcast_wait 配合使用，多个 `broadcast_async` 可以用同一个 broadcast_wait 等待。
- 多次执行 broadcast 函数向同一地址发送不同数据时，接收方无法保证接收数据的时序准确性。您可以使用 sync_threads 进行数据同步，从而确保连续接收数据的安全性，可参考使用示例 6。
- 使用 malloc 分配 SPM 存储空间时，需要在所有涉及 Broadcast 操作的 SPE 都可以执行到的代码区域内进行，并且要确保所有 SPE 分配的 SPM 空间首地址相同。使用 malloc 分配完 SPM 空间后，在发起 Broadcast 操作前，需要使用 sync_threads 进行同步。正确的使用方法，可参考使用示例 1 和使用示例 2。

> **提示：**
> 在使用 malloc 分配 SPM 存储空间之前，如果已经对涉及 Broadcast 数据搬运的 SPE 申请过大小不同的 SPM 存储空间，请先释放这部分 SPM 内存空间，以确保所有涉及 Broadcast 数据搬运的 SPE 申请的 SPM 存储空间的首地址相同。

#### 使用示例 1

SPE0 使用带 root 参数的 broadcast_async 向 SPA 内所有 SPE 发起广播操作。

```cpp
using namespace sdaa;
#define SIZE1 10
#define SIZE2 20


// 使用 __local__ 分配的SPM存储空间
__local__ int dst1[SIZE1];
__local__ int src1[SIZE1];
__local__ int dst2[SIZE2];
__local__ int src2[SIZE2];


__global__ void func()
{
    ... // 准备广播数据


    ThreadGroup thread_group(0xFFFFFFFF);    // 使用mask的方式创建线程组
    BroadcastHandle handle(&thread_group);   // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    broadcast_async(dst1, src1, SIZE1 * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle);   // 0号SPE广播到所有SPE


    ... // 其他代码逻辑


    broadcast_wait(handle);   // 等待SPE0完成发送操作和线程组内SPE完成接收广播的操作


    thread_group_exclude(thread_group, 0);    // 使用线程组接口从当前线程组内删除SPE0
    broadcast_async(dst2, src2, SIZE2 * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle);   // 0号SPE广播到除自身外的所有其他SPE（即自身不接收）


    ... // 其他代码逻辑


    broadcast_wait(handle); // 等待SPE0完成发送操作和线程组内SPE完成接收广播的操作
}
```

#### 使用示例 2

SPE0 使用不带 root 参数的 broadcast_async 向 SPA 内所有 SPE 发起广播操作。

```cpp
using namespace sdaa;
#define SIZE1 10


// 使用 __local__ 分配的SPM存储空间
__local__ int dst1[SIZE1];
__local__ int src1[SIZE1];


__global__ void func()
{
    ... // 准备广播数据


    ThreadGroup thread_group(0xFFFFFFFF);    // 使用掩码的方式创建线程组
    BroadcastHandle handle(&thread_group);   // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    // 仅线程组内的SPE0执行广播操作
    if (threadIdx == 0) {
        broadcast_async(dst1, src1, SIZE1 * sizeof(int), 0, {0, 0}, BroadcastSpmToSpm, handle); // 0号SPE广播到所有SPE
    }
    ... // 其他代码逻辑


    if (thread_group_is_included(thread_group, threadIdx)) {
        broadcast_wait(handle, 1); // 等待线程组所有SPE完成发送广播或/与接收广播的操作
    }
}
```

#### 使用示例 3

SPE0 使用带 root 参数的 broadcast_async 向 SPE0~SPE7 发起带跨步行为的广播操作。

```cpp
using namespace sdaa;
#define SRC_SIZE 100
#define DST_SIZE 50


__device__ int src[SRC_SIZE];
__global__ void func()
{
    // 仅使用SPE0初始化Global存储空间数组
    if (threadIdx == 0) {
        for (int i = 0; i < SRC_SIZE; i++) {
            src[i] = i;
        }
    }


    // 使用malloc申请SPM空间
    int *dst = (int *)malloc(DST_SIZE * sizeof(int));
    // 初始化目标存储空间
    for(int i = 0; i < DST_SIZE; i++) {
        dst[i] = 0;
    }


    // 进行Global存储空间跨步为40B的广播
    size_t global_stride = 10 * sizeof(int);
    ThreadGroup thread_group(0xFF);       // 定义SPE0~SPE7组成线程组
    BroadcastHandle handle(&thread_group); // 定义BroadcastHandle类型变量
    sync_threads();       // 创建完handle后执行一次同步操作


    // 仅发起广播的SPE和线程组内的SPE执行广播操作
    if (thread_group_is_included(thread_group, threadIdx)) {
        broadcast_async(dst, src, DST_SIZE * sizeof(int), 10 * sizeof(int), {0, global_stride}, 0, BroadcastGlobalToSpm, handle);
    }


    ... // 其他操作


    broadcast_wait(handle);
    free(dst);
}
```

#### 使用示例 4

SPE0 使用不带 root 参数的 broadcast_async 向 SPE0~SPE7 发起带跨步行为的广播操作。

```cpp
using namespace sdaa;
#define SRC_SIZE 100
#define DST_SIZE 50


__device__ int src[SRC_SIZE];
__global__ void func()
{
    // 仅使用SPE0初始化Global存储空间数组
    if (threadIdx == 0) {
        for (int i = 0; i < SRC_SIZE; i++) {
            src[i] = i;
        }
    }


    // 使用malloc申请SPM空间
    int *dst = (int *)malloc(DST_SIZE * sizeof(int));
    // 初始化目标存储空间
    for(int i = 0; i < DST_SIZE; i++) {
        dst[i] = 0;
    }


    // 进行Global存储空间跨步为40B的广播
    size_t global_stride = 10 * sizeof(int);
    ThreadGroup thread_group(0xFF);       // 定义SPE0~SPE7组成线程组
    BroadcastHandle handle(&thread_group);   // 定义BroadcastHandle类型变量
    sync_threads();       // 创建完handle后执行一次同步操作


    // 仅线程组内的SPE0执行广播操作
    if (threadIdx == 0) {
        broadcast_async(dst, src, DST_SIZE * sizeof(int), 10 * sizeof(int), {0, global_stride}, BroadcastGlobalToSpm, handle);
    }


    ... // 其他操作


    if (thread_group_is_included(thread_group, threadIdx)) {
        broadcast_wait(handle, 1);
    }
    free(dst);
}
```

#### 使用示例 5

错误示范：展示 BroadcastHandle 广播组内存在 SPE 未执行广播操作。

```cpp
using namespace sdaa;
#define SIZE 10


__global__ void func()
{
    // 使用malloc申请SPM空间（需要确保参与广播的SPE上dst和src地址相同）
    int *dst = (int *)malloc(SIZE * sizeof(int));
    int *src = (int *)malloc(SIZE * sizeof(int));


    ... // 准备广播数据


    BroadcastHandle handle; // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 发起广播操作之前，计算核心之间进行一次同步操作


    broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确，0号SPE广播到所有SPE


    if (threadIdx < 8) { // 假设threadDim > 8
        broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 错误，只能保证SPE0~7接收完数据，不能保证其余SPE接收完数据
    }


    ThreadGroup thread_group(0xFF);                    //   定义由SPE0~SPE7组成的线程组
    broadcast_set_thread_group(handle, &thread_group); // 设置仅SPE0~SPE7接收广播
    broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确，仅SPE0~7接收数据，其余SPE执行broadcast将立即退出


    if (threadIdx < 8) {
        broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 正确
    }


    if (threadIdx == 0 || thread_group_is_included(thread_group, threadIdx)) {
        broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle);   // 正确，确保数据发送方SPE和线程组内的SPE进入
    }


    if (threadIdx < 4) {
        broadcast_wait(handle); // 错误，仅SPE0~3接收完数据，不能保证SPE4~7接收完数据
    }


    broadcast_wait(handle); // 等待所有broadcast_async操作完成


    free(src);
    free(dst);
}
```

#### 使用示例 6

错误示范：通过广播接口向同一地址发送不同数据时，未使用 sync_threads 进行数据同步，无法保证连续接受数据的安全性。

```cpp
using namespace sdaa;
#define SIZE 10
__local__ int dst[SIZE];
__local__ int src[SIZE];


__global__ void func()
{
    ... // 准备广播数据


    const unsigned int root = 0; // 发送方ID
    BroadcastHandle handle; // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    // 错误示范：
    // root多次向相同地址广播数据，由于各线程独立执行，因此不能保证各线程执行broadcast_async操作的时序性。
    // 例如发送方执行速度较快，在执行第二次broadcast_async时，其他线程还没执行第一次broadcast_async，
    // 就可能导致发送方第二次发送的数据覆盖第一次发送的数据，其他线程在执行第一次broadcast_async后接收到的数据
    // 实际为发送方第二次发送的数据。
    for (int i = 0; i < 100; i++) {
        if (threadIdx == root) {
            broadcast_wait(handle); // 确保发送方发送完src上数据后再修改，同时会等待0号线程接收完成上次发送的数据
            src[0] = i; // 修改src的值
        }
        broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, root, BroadcastSpmToSpm, handle); // 发送方线程向其他线程发送数据
        if (threadIdx != root) {
            broadcast_wait(handle); // 等待dst上接收数据
            if (dst[0] == i) ... // 获取dst的值
        }
    }


    // 正确做法：
    // 在处理有可能因线程不同步而导致的数据冲突的问题时，可加上线程同步操作，
    // 以保证各线程执行broadcast_async操作的时序性。
    for (int i = 0; i < 100; i++) {
        if (threadIdx == root) {
            broadcast_wait(handle); // 确保发送方发送完src上数据后再修改，同时会等待0号线程接收完成上次发送的数据
            src[0] = i; // 修改src的值
        }
        sync_threads(); // 在发送数据前加上同步，确保其他线程进入能接收数据的状态
        broadcast_async(dst, src, SIZE * sizeof(int), 0, {0, 0}, root, BroadcastSpmToSpm, handle); // 发送方线程向其他线程发送数据
        if (threadIdx != root) {
            broadcast_wait(handle); // 等待dst上接收数据
            if (dst[0] == i) ... // 获取dst的值
        }
    }
}
```

### 7.6.3.4.2 broadcast_wait

```cpp
void broadcast_wait(BroadcastHandle &handle)
void broadcast_wait(BroadcastHandle &handle, unsigned int until_times)
```

#### 功能介绍

等待当前计算核心 SPE 上所有使用同一个 `BroadcastHandle` 的非阻塞型 Broadcast 数据搬运操作完成。

#### 参数解释

| 参数名称 | 说明 |
|----------|------|
| handle | BroadcastHandle 类型变量，表示当前广播组，用于标识接收广播的 SPE。 |
| until_time | （可选）当前 SPE 接收广播数据的次数。说明：不带 until_time 参数的 broadcast_wait 接口，需要搭配带 root 参数的 broadcast_async 接口使用。带 until_time 参数的 broadcast_wait 接口，需要搭配不带 root 参数的 broadcast_async 接口使用。 |

#### 返回值

无。

#### 注意事项

- 需要引入 sdaa 命名空间。
- 使用 `broadcast_wait` 时，不要求所有 SPE 必须执行该函数接口，但需要注意发送方或者 `BroadcastHandle` 广播组内包含的 SPE 若未执行 `broadcast_wait`，则不能保证发送和接收广播的操作完成，可参考使用示例。

#### 使用示例 1

```cpp
using namespace sdaa;
#define SIZE1 10
#define SIZE2 20
#define SIZE3 30
__local__ int dst1[SIZE1];
__local__ int src1[SIZE1];
__local__ int dst2[SIZE2];
__local__ int src2[SIZE2];
__local__ int dst3[SIZE3];
__local__ int src3[SIZE3];


__global__ void func()
{
    ... // 准备广播数据


    ThreadGroup thread_group(0xFFFFFFFF);    // 使用mask的方式创建线程组
    BroadcastHandle handle(&thread_group); // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    broadcast_async(dst1, src1, SIZE1 * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 0号SPE广播到所有SPE

    thread_group_exclude(thread_group, 0);
    broadcast_async(dst2, src2, SIZE2 * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 0号SPE广播到除自身外的所有其他SPE（即自身不接收）


    ... // 其他代码逻辑


    broadcast_wait(handle); // 等待所有SPE完成发送广播或/与接收广播的操作


    thread_group_set_mask(thread_group, 0xFF); // 设置handle，仅SPE0~7接收广播
    broadcast_async(dst3, src3, SIZE3 * sizeof(int), 0, {0, 0}, 0, BroadcastSpmToSpm, handle); // 0号SPE广播到SPE0~7
    if (threadIdx <= 4) {
        broadcast_wait(handle); // 不建议，无法保证SPE5~7接收完数据
    }
    if (threadIdx == 0 || thread_group_is_included(thread_group, threadIdx)) {
        broadcast_wait(handle); // 正确，可以保证SPE0发送完数据，以及SPE8~15接收完数据
    }
    broadcast_wait(handle); // 正确，未参与广播的SPE执行后无需等待即可退出
}
```

#### 使用示例 2

```cpp
using namespace sdaa;
#define SIZE1 10
#define SIZE2 20
__local__ int dst1[SIZE1];
__local__ int src1[SIZE1];
__local__ int dst2[SIZE2];
__local__ int src2[SIZE2];


__global__ void func()
{
    ... // 准备广播数据


    ThreadGroup thread_group(0xFFFFFFFF);   // 使用mask的方式创建线程组
    BroadcastHandle handle(&thread_group); // 创建BroadcastHandle类型变量，所有SPE均接收数据
    sync_threads(); // 计算核心之间进行一次同步操作


    if (threadIdx == 0) {
        broadcast_async(dst1, src1, SIZE1 * sizeof(int), 0, {0, 0}, BroadcastSpmToSpm, handle); // 0号SPE广播到SPA内所有SPE
    }


    ... // 其他代码逻辑


    if (thread_group_is_included(thread_group, threadIdx)) {
        broadcast_wait(handle, 1); // 等待所有SPE完成发送广播或/与接收广播的操作
    }


    thread_group_set_mask(thread_group, 0xFF); // 设置handle，仅SPE0~7接收广播
    if (threadIdx == 0) {
        broadcast_async(dst2, src2, SIZE2 * sizeof(int), 0, {0, 0}, BroadcastSpmToSpm, handle); // 0号SPE广播到SPE0~7
    }
    if (threadIdx <= 4) {
        broadcast_wait(handle, 1); // 不建议，无法保证SPE5~7接收完数据
    }
    if (threadIdx == 0 || thread_group_is_included(thread_group, threadIdx)) {
        broadcast_wait(handle, 1); // 正确，可以保证SPE0发送完数据，以及SPE8~15接收完数据
    }
    broadcast_wait(handle, 1); // 错误，未参与广播的SPE不能执行该操作
}
```

## 7.6.3.5 典型场景示例

### 7.6.3.5.1 模拟核心阵列进行横向、纵向广播

本示例通过将部分 SPE 自定义为二维阵列组，并模拟行横向和列纵向广播，从而实现二维阵列组中全广播的效果。

#### 编程思路

- 步骤一：给不同行、不同列的 SPE 划分广播组。
- 步骤二：每个 SPE 分别向同行、同列的 SPE 广播组上不同地址发送数据。
- 步骤三：此时每个 SPE 上应当拥有相同数据，打印比较。

#### 代码示例

```cpp
using namespace sdaa;
#define THREAD_NUM 16 // 设置共16个SPE参与广播
#define ROW_NUM 4   // 划分为4行4列
#define COL_NUM 4


#define IS_SAME_ROW(i, j) (i / COL_NUM == j / COL_NUM)
#define IS_SAME_COL(i, j) (i % COL_NUM == j % COL_NUM)


// 声明SPM内存空间
__local__ int local_value;
__local__ int all_data1[THREAD_NUM];
__local__ int all_data2[THREAD_NUM];


__global__ void testBroadcast()
{
    // 计算每个SPE在当前阵列中的行列位置
    const unsigned int row_id = threadIdx / COL_NUM;
    const unsigned int col_id = threadIdx % COL_NUM;
    const size_t size = sizeof(int);


    ThreadGroup row_thread_group, col_thread_group;


    // 每个SPE上的线程组为包括自身在内的同行同列广播组
    for (int i = 0; i < THREAD_NUM; i++) {
        if (IS_SAME_ROW(i, threadIdx)) {
            thread_group_include(row_thread_group, i);
        }
        if (IS_SAME_COL(i, threadIdx)) {
            thread_group_include(col_thread_group, i);
        }
    }


    // 定义控制行列方向上广播组的BroadcastHandle类型变量
    BroadcastHandle row_handle(&row_thread_group);
    BroadcastHandle col_handle(&col_thread_group);
    sync_threads();


    local_value = threadIdx;
    // 先将自身数据广播到当前行，后将包含当前行的所有数据广播到当前列
    broadcast_async(all_data1 + threadIdx, &local_value, size, 0, {0, 0}, threadIdx,
                      BroadcastSpmToSpm, row_handle);


    broadcast_wait(row_handle);


    broadcast_async(all_data1 + row_id * COL_NUM, all_data1 + row_id * COL_NUM,
                      size * COL_NUM, 0, {0, 0}, threadIdx, BroadcastSpmToSpm, col_handle);
    broadcast_wait(col_handle);


    // 打印结果验证
    if (threadIdx == 0) {
          for (int i = 0; i < THREAD_NUM; i++) printf("%d ", all_data1[i]);
          printf("\n");
    }


    // 上述代码应与全广播效果相同
    ThreadGroup all_thread_group(0xFFFF);
    BroadcastHandle all_handle(&all_thread_group);
    broadcast(all_data2 + threadIdx, &local_value, size, 0, {0, 0}, threadIdx, BroadcastSpmToSpm, all_handle);


    // 打印结果验证
    if (threadIdx == 0) {
          for (int i = 0; i < THREAD_NUM; i++) printf("%d ", all_data2[i]);
          printf("\n");
    }
}


int main() {
    // 设置使用0号计算核心阵列
    sdaaSetDevice(0);
    // 核函数调用
    testBroadcast<<<1>>>();
    sdaaDeviceSynchronize();
    return 0;
}
```

## 7.6.4 跨步类型

### 7.6.4.1 概述

跨步是指从一段连续的数据中每隔一段固定的距离获取一段固定长度的数据，跨步由以下函数接口组成：

- MemoryStride：配置跨步数据搬运的结构体变量。

#### 跨步方式

SDAA C 目前支持以下跨步方式：

- Global 存储空间向 SPM 存储空间

  图1 Global 存储空间向 SPM 存储空间

- SPM 存储空间向 Global 存储空间

  图2 SPM 存储空间向 Global 存储空间

- Global 存储空间向 Global 存储空间

  图3 Global 存储空间向 Global 存储空间

- SPM 存储空间向 SPM 存储空间

  > **说明：**
  > 不支持在 SPM 存储空间上设置跨步单元的大小。因此，SPM 存储空间向 SPM 存储空间仅支持搬运连续数据。

  图4 SPM 存储空间向 SPM 存储空间

### 7.6.4.2 MemoryStride

```cpp
typedef struct {
    size_t dst_stride;
    size_t src_stride;
} MemoryStride;
```

#### 功能介绍

配置跨步数据搬运的结构体变量。

#### 参数解释

| 变量名称 | 说明 |
|----------|------|
| dst_stride | 目标存储空间的跨步单元大小，单位：Byte。说明：仅支持在 Global 存储空间，设置该参数。若目标存储空间位于 SPM，则该变量值无效。 |
| src_stride | 源存储空间的跨步单元大小，单位：Byte。说明：仅支持在 Global 存储空间，设置该参数。若目标源存储空间位于 SPM，则该变量值无效。 |

#### 注意事项

- 需要引入 sdaa 命名空间。
- 如果参数 `dst_stride` 和 `src_stride` 都设置为 0，则为连续数据搬运。
- 受硬件限制，目前仅支持在 Global 存储空间，设置跨步单元大小。

#### 使用示例 1

配置跨步参数，创建 MemoryStride 类型变量。

```cpp
using namespace sdaa;
__global__ void func()
{
    // 创建MemoryStride类型变量，设置目标存储空间的跨步
    MemoryStride stride = {stride_size, 0};


    // 其他代码逻辑
}
```

#### 使用示例 2

配置跨步参数，不创建 MemoryStride 类型变量。

```cpp
using namespace sdaa;
__global__ void func()
{
    constexpr size_t stride_size = 2 * sizeof(int);
    // 其他代码逻辑
    // ...


    // 配置跨步参数，进行非阻塞跨步拷贝
    memcpy_async(g_dst, spm_src, size, section_size, {stride_size, 0},
                 MemcpySpmToGlobal);


    // 其他代码逻辑
}
```
