---
id: doc-sdaa-c-programming-guide-v3-1-0-p02a
title: "SDAA C 编程指南 v3.1.0 — 第2部分 (ch7)"
type: source-doc-part
parent_doc: doc-sdaa-c-programming-guide-v3-1-0
product_version: "v3.1.0"
source_file: "external/文档/SDAA C编程指南_v3.1.0.pdf"
raw_text: "sources/docs/raw/SDAA C编程指南_v3.1.0.txt"
raw_line_range: "3859-5311"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [dma, matmul, memory, programming-model, rma, runtime, sdaa, sdaa-c, teco-t1, thread-group-sync]
---

# SDAA C 编程指南 v3.1.0（第2部分）

> 说明：本部分覆盖《SDAA C 编程指南 v3.1.0》第 7 章（函数接口）的一个连续片段，对应原始抽取文本第 3859 行至第 5311 行。本片段以前一节（内存初始化 `memset`）使用示例的尾部代码起始，主体内容为 7.6 数据搬运（DMA 数据搬运与 RMA 数据搬运）。

## 7.5.x 内存初始化示例（续）

> 本片段起始处为上一节（`memset`）"使用示例2 —— 对 SPM 存储空间进行初始化"的尾部代码续行。为保持无损，完整列出该示例的剩余部分。

对 SPM 存储空间进行初始化。

```c
__global__ void func()
{
    if (threadIdx != 0) {
        return;
    }

    // 在SPM存储空间中申请一段内存空间
    int *arr = (int *)malloc(100 * sizeof(int));

    // 对SPM内存arr进行初始化操作
    memset(arr, 0, 100 * sizeof(int));

    // 打印输出
    for (int i = 0; i < 100; i++) {
        printf("arr[%d] = %d\n", i, arr[i]);
    }

    // 释放申请的内存空间
    free(arr);
}
```

## 7.6 数据搬运

### 7.6.1 DMA数据搬运

#### 7.6.1.1 概述

DMA（Direct Memory Access）数据搬运是指同一 SPA 内的 Global 存储和 Global 存储之间、同一 SPE 内的 SPM 存储之间以及同一 SPA 内的 Global 存储和 SPM 存储之间的数据流动。

DMA 数据搬运可以分为阻塞型 DMA 数据搬运和非阻塞型 DMA 数据搬运：

- 阻塞型 DMA 数据搬运接口：使用简单，但性能不佳。
- 非阻塞型 DMA 数据搬运接口：使用相对复杂，但性能较好。

**阻塞型 DMA 数据搬运**

阻塞型 DMA 数据搬运由以下函数接口组成：

- `memcpy`：常规阻塞型数据搬运，数据搬运完成才可以执行下一条运算。
- `check_memcpy`：验证 `memcpy` 输入参数的合法性。
- `memcpy_stride`：带跨步功能的阻塞型数据搬运，数据搬运完成才可以执行下一条运算。
- `check_memcpy_stride`：验证 `memcpy_stride` 输入参数的合法性。

图1 阻塞型DMA数据搬运

**非阻塞型 DMA 数据搬运**

非阻塞型 DMA 数据搬运仅适用于 Global 存储和 SPM 存储之间的数据搬运，由以下函数接口组成：

- `MemcpyHandle`：用于控制不同的非阻塞型 DMA 数据搬运组。
- `memcpy_async`：非阻塞型数据搬运，数据搬运的同时可以执行下一条运算。
- `memcpy_wait`：非阻塞型数据搬运同步接口，确保所有非阻塞数据搬运完成。
- `check_memcpy_async`：验证 `memcpy_async` 输入参数的合法性。

图2 非阻塞型DMA数据搬运

#### 7.6.1.2 阻塞型DMA数据搬运

##### 7.6.1.2.1 memcpy

```c
void *memcpy(void *dst, const void *src, size_t size)
```

**功能介绍**

完成同一 SPA 内的 Global 存储和 Global 存储之间、同一 SPE 内的 SPM 存储之间以及同一 SPA 内的 Global 存储和 SPM 存储之间的阻塞型数据搬运。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址。 |
| size | 数据搬运量大小，单位：Byte。数据搬运量的大小受源地址及目标地址所在空间限制，由于 memcpy 接口源地址和目的地址不允许有重叠，因此不同存储空间的数据搬运量大小会有所区别，存储空间可用空间大小可参照不同存储空间可用大小：<br>· 若源地址与目标地址在同一块内存空间，则理论最大数据搬运量为：所在内存空间的二分之一。<br>· 若源地址与目标地址不在同一块内存空间，则理论最大数据搬运量为：空间较小者的空间大小。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| void * | 返回一个等同于 dst 的指针。 |

**注意事项**

- 暂不支持不同 SPE 内的 SPM 存储之间的数据搬运，可参考 RMA 数据搬运和 Broadcast 数据搬运。
- 当前 memcpy 接口会额外占用 SPM 堆空间：由于 Global 存储和 Global 存储之间的数据搬运需要以 SPM 存储空间作为中转，会临时占用 SPM 20KB 的堆空间，数据搬运完成后释放。

**使用示例**

使用 DMA 数据搬运阻塞接口完成 Global 存储空间与 SPM 存储空间之间，Global 存储空间之间以及 SPM 存储空间之间的数据搬运。

```c
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                              17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化Global存储上input_1中的数据
__device__ int input_1[32] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 将数据从Global存储拷贝到SPM存储
__global__ void test_global_to_spm()
{
    int *tmp = (int *)malloc(32 * sizeof(int));
    if (threadIdx == 0) {
        memcpy(tmp, &input[0], 32 * sizeof(int));
    }
    free(tmp);
}

// 将数据从SPM存储拷贝到Global存储
__global__ void test_spm_to_global()
{
    int *tmp = (int *)malloc(32 * sizeof(int));
    init_array_get(tmp, 32, 9);
    if (threadIdx == 0) {
        memcpy(&input[0], tmp, 32 * sizeof(int));
    }
    free(tmp);
}

// 将数据从Global存储拷贝到Global存储
__global__ void test_global_to_global()
{
    if (threadIdx == 0) {
        memcpy(&input_1[0], &input[0], 32 * sizeof(int));
    }
}

// 将数据从SPM存储拷贝到同一计算核心上的SPM存储
__global__ void test_spm_to_spm()
{
    if (threadIdx == 0) {
        int *tmp = (int *)malloc(32 * sizeof(int));
        int *tmp_1 = (int *)malloc(32 * sizeof(int));
        init_array_get(tmp, 32, 9);
        init_array_get(tmp_1, 32, 0);
        memcpy(tmp, tmp_1, 32 * sizeof(int));
        free(tmp);
        free(tmp_1);
    }
}
```

##### 7.6.1.2.2 check_memcpy

```c
unsigned int check_memcpy(const void *dst, const void *src, size_t size)
```

**功能介绍**

验证 memcpy 输入参数的合法性，通过返回值判断输入参数是否满足特定的输入要求，如：源地址与目的地址是否有重叠、当前接口占用 SPM 堆空间是否超出剩余可用堆空间大小等。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址。 |
| size | 数据搬运量大小，单位：Byte。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| unsigned int | 参数合法性验证结果，每个 Bit 代表不同的状态信息。对应枚举型 MemcpyStatus，表示合法性验证的状态信息，当前可表示状态有：<br>· MEMCPY_SUCC：参数无误。<br>· MEMCPY_ERR_ADDR_ILLEGAL：源地址或目的地址不合法，需要是有效地址。<br>· MEMCPY_ERR_MEM_OVERLAP：源地址和目的地址存在重叠。<br>· MEMCPY_ERR_SPM_OVERSIZE：当前接口占用 SPM 堆空间超出剩余可用堆空间。 |

返回的具体状态信息可参照如下表格：

| 第 0 位 | 第 1 位 | 第 2 位 | 第 3 位 |
|--------|--------|--------|--------|
| 0：参数无误。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 |
| 1：参数有误。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。源地址或目的地址不合法，需要是有效地址。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。源地址和目的地址存在重叠。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。当前接口占用 SPM 堆空间超出剩余可用堆空间。 |

**注意事项**

需要引入 sdaa 命名空间。

**使用示例**

使用不携带跨步参数的 check_memcpy 接口，对数据搬运参数进行安全检查。

```c
__global__ void test(void *dst, const void *src, size_t size)
{
    if (threadIdx != 0) { return; }
    // 获取check_memcpy函数的返回值
    int check_val = sdaa::check_memcpy(dst, src, size);

    // 通过check_memcpy的返回值确认memcpy参数是否合法，合法则进行memcpy操作
    if (check_val == MEMCPY_SUCC) {
        memcpy(dst, src, size);
    }
}
```

##### 7.6.1.2.3 memcpy_stride

```c
void *memcpy_stride(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d)
```

**功能介绍**

完成同一 SPA 内的 Global 存储和 Global 存储之间、同一 SPE 内的 SPM 存储之间以及同一 SPA 内的 Global 存储和 SPM 存储之间带跨步功能的阻塞型数据搬运。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址。 |
| size | 数据搬运量大小，单位：Byte。<br>说明：<br>· 数据搬运量的大小受源地址和目的地址所在空间限制。<br>· 由于 memcpy_stride 接口的源地址和目的地址不允许有重叠，因此不同存储空间的数据搬运量大小会有所区别。<br>· Global 存储空间和 SPM 存储空间的可用空间大小，可参考存储空间章节的存储空间可用大小：<br>　- 若源地址与目的地址在同一块存储空间，则理论最大数据搬运量为：所在存储空间的二分之一。<br>　- 若源地址与目的地址不在同一块存储空间，则理论最大数据搬运量为：空间较小者的空间大小。 |
| section_1d | 一维数据搬运单元的大小，单位 Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源和目标存储空间的一维跨步单元大小，单位：Byte。<br>说明：<br>· MemoryStride 的设置受硬件限制：<br>　- 目前仅支持在 Global 存储空间，设置跨步单元的大小。<br>　- 跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。<br>· 如果 MemoryStride 中的 dst_stride 和 src_stride 都设置为 0，则为连续数据搬运，且当前接口的 section_1d 参数无效。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| void * | 返回一个等同于 dst 的指针。 |

**注意事项**

- 需要引入 sdaa 命名空间。
- 暂不支持不同 SPE 内的 SPM 存储之间的数据搬运，可参考 RMA 数据搬运和 Broadcast 数据搬运。
- 当前 memcpy_stride 接口会额外占用 SPM 堆空间情况：由于 Global 存储和 Global 存储之间的数据搬运需要以 SPM 存储空间作为中转，会临时占用 SPM 20KB 的堆空间，数据搬运完成后释放。
- DMA 数据搬运的跨步功能不支持在 SPM 存储空间上设置跨步单元的大小。因此，SPM 存储空间向 SPM 存储空间仅支持搬运连续数据。

**使用示例**

使用 DMA 数据搬运阻塞接口的跨步功能完成 Global 存储空间与 SPM 存储空间之间，Global 存储空间之间以及 SPM 存储空间之间的数据搬运。

```c
using namespace sdaa;
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                            17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化Global存储上input_1中的数据
__device__ int input_1[32] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// 初始化Global存储上input_2中的数据
__device__ int input_2[32] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 使用跨步功能将数据从Global存储空间拷贝到SPM存储空间
__device__ void test_global_to_spm()
{
    // 数据搬运大小是64B
    constexpr size_t size = 16 * sizeof(int);
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 对总数据块申请SPM空间
    int *spm_arr = (int *)malloc(size);
    // 在调用memcpy_stride 接口时，填入目的地址，源地址，数据块大小和MemoryStride对象
    memcpy_stride(spm_arr, input, size, section, {0, glbmem_stride});

    // 其他代码逻辑
    ...
    // 释放SPM空间
    free(spm_arr);
}

// 使用跨步功能将数据从SPM存储空间拷贝到Global存储空间
__device__ void test_spm_to_global()
{
    if (threadIdx != 0) {
        return;
    }
    // 数据搬运大小是64B
    constexpr size_t size = 16 * sizeof(int);
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 对总数据块申请SPM空间
    int *spm_arr = (int *)malloc(size);
    // 初始化源数据
    init_array_get(spm_arr, 16, 10);
    // 在调用memcpy_stride 接口时，填入目的地址，源地址，数据块大小和stride对象
    memcpy_stride(input_2, spm_arr, size, section, {glbmem_stride, 0});

    // 其他代码逻辑
    ...
    // 释放SPM空间
    free(spm_arr);
}

// 使用跨步功能将数据从Global存储空间拷贝到Global存储空间
__device__ void test_global_to_global()
{
    if (threadIdx != 0) {
        return;
    }
    // 数据搬运大小是64B
    constexpr size_t size = 16 * sizeof(int);
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 在调用memcpy_stride 接口时，填入目的地址，源地址，数据块大小和stride对象
    memcpy_stride(input_2, input, size, section, {glbmem_stride, glbmem_stride});

    // 其他代码逻辑
    ...
}

// 使用跨步功能将数据从SPM存储空间拷贝到SPM存储空间
__device__ void test_spm_to_spm()
{
    // 数据搬运大小是64B
    constexpr size_t size = 16 * sizeof(int);
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 给源数据和目的地址数据申请SPM空间
    int *spm_arr_1 = (int *)malloc(section_num * section);
    int *spm_arr_2 = (int *)malloc(section_num * section);
    // 初始化源数据和目的地址数据
    init_array_get(spm_arr_1, 16, 10);
    init_array_get(spm_arr_2, 16, 0);
    // 在调用memcpy_stride 接口时，填入目的地址，源地址，数据块大小和stride对象
    memcpy_stride(spm_arr_2, spm_arr_1, size, section, {0, 0});

    // 其他代码逻辑
    ...
    // 释放SPM空间
    free(spm_arr_2);
    free(spm_arr_1);
}
```

##### 7.6.1.2.4 check_memcpy_stride

```c
unsigned int check_memcpy_stride(const void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d)
```

**功能介绍**

验证 memcpy_stride 输入参数的合法性，通过返回值判断输入参数是否满足特定的输入要求，如：源地址与目的地址是否有重叠、当前接口占用 SPM 堆空间是否超出剩余可用堆空间大小等。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址。 |
| size | 数据搬运量的大小，单位：Byte。<br>说明：<br>· 数据搬运量的大小受源地址和目的地址所在空间限制。<br>· 由于 memcpy_stride 接口的源地址和目的地址不允许有重叠，因此不同存储空间的数据搬运量大小会有所区别。<br>· Global 存储空间和 SPM 存储空间的可用空间大小，可参考存储空间章节的存储空间可用大小：<br>　- 若源地址与目的地址在同一块存储空间，则理论最大数据搬运量为：所在存储空间的二分之一。<br>　- 若源地址与目的地址不在同一块存储空间，则理论最大数据搬运量为：空间较小者的空间大小。 |
| section_1d | 一维数据搬运单元的大小，单位：Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源和目标存储空间的一维跨步单元大小，单位：Byte。<br>说明：<br>· MemoryStride 的设置受硬件限制：<br>　- 目前仅支持在 Global 存储空间，设置跨步单元的大小。<br>　- 跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。<br>· 如果 MemoryStride 中的 dst_stride 和 src_stride 都设置为 0，则为连续数据搬运，且当前接口的 section_1d 参数无效。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| unsigned int | 参数合法性验证结果，每个 Bit 代表不同的状态信息。对应枚举型 MemcpyStatus，表示合法性验证的状态信息，当前可表示状态有：<br>· MEMCPY_SUCC：参数无误。<br>· MEMCPY_ERR_ADDR_ILLEGAL：源地址或目的地址不合法，需要是有效地址。<br>· MEMCPY_ERR_MEM_OVERLAP：源地址和目的地址存在重叠。<br>· MEMCPY_ERR_SPM_OVERSIZE：当前接口占用 SPM 堆空间超出剩余可用堆空间。<br>· MEMCPY_ERR_STRIDE_PARAM：跨步参数错误。 |

返回的具体状态信息可参照如下表格：

| 第 0 位 | 第 1 位 | 第 2 位 | 第 3 位 | 第 4 位 |
|--------|--------|--------|--------|--------|
| 0：参数无误。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 |
| 1：参数有误。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。源地址或目的地址不合法，需要是有效地址。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。源地址和目的地址存在重叠。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。当前接口占用 SPM 堆空间超出剩余可用堆空间。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：跨步参数错误。 |

**注意事项**

需要引入 sdaa 命名空间。

**使用示例**

使用带跨步参数的 check_memcpy_stride 接口，对数据搬运参数进行安全检查。

```c
using namespace sdaa;
__global__ void test(void *dst, const void *src, size_t size)
{
    if (threadIdx != 0) {
        return;
    }
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 获取check_memcpy_stride函数的返回值
    int check_val = check_memcpy_stride(dst, src, size, section, {0, glbmem_stride});

    // 通过check_memcpy_stride的返回值确认memcpy参数是否合法，合法则进行带跨步的memcpy操作
    if (check_val == MEMCPY_SUCC) {
        // 在调用memcpy_stride 接口时，填入目的地址，源地址，数据块大小和stride对象
        memcpy_stride(dst, src, size, section, {0, glbmem_stride});
    }
}
```

#### 7.6.1.3 非阻塞型DMA数据搬运

##### 7.6.1.3.1 MemcpyHandle及配置接口

###### 7.6.1.3.1.1 概述

MemcpyHandle 是非阻塞 DMA 数据搬运的句柄，可以控制不同 memcpy_async 搬运操作所属的非阻塞型 DMA 数据搬运组。MemcpyHandle 由以下函数接口组成：

- `MemcpyHandle`：控制不同 memcpy_async 搬运操作所属的非阻塞型 DMA 数据搬运组。

###### 7.6.1.3.1.2 MemcpyHandle

```cpp
MemcpyHandle::MemcpyHandle()
```

**功能介绍**

用于控制不同 memcpy_async 搬运操作所属的非阻塞型 DMA 数据搬运组。同一搬运组内的所有 memcpy_async 搬运操作可以只调用一次 memcpy_wait 进行同步。如果不指定 MemcpyHandle，则使用系统默认的非阻塞型 DMA 数据搬运组。

**注意事项**

需要引入 sdaa 命名空间。

**使用示例**

```cpp
using namespace sdaa;
__device__ void func()
{
    // 创建MemcpyHandle类型变量
    MemcpyHandle handle;

    // 执行非阻塞型DMA操作
}
```

##### 7.6.1.3.2 memcpy_async

```cpp
void *memcpy_async(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d,
MemcpyDirect direct)
void *memcpy_async(void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d,
MemcpyDirect direct, MemcpyHandle &handle)
```

**功能介绍**

完成同一 SPA 内的 Global 存储和 SPM 存储之间的非阻塞型数据搬运。可以通过 MemcpyHandle 控制所属的非阻塞型 DMA 数据搬运组，若没有使用 MemcpyHandle，则使用系统默认的非阻塞型 DMA 数据搬运组。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址，需要 4B 对齐。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址，需要 4B 对齐。 |
| size | 数据搬运量大小，单位：Byte，需要是 4B 的整数倍。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：对应 SPM 存储空间的大小。 |
| section_1d | 一维数据搬运单元大小，单位 Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源和目标存储空间的一维跨步单元大小，单位：Byte。<br>说明：<br>· MemoryStride 的设置受硬件限制：<br>　- 目前仅支持在 Global 存储空间，设置跨步单元的大小。<br>　- 跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。<br>· 如果 MemoryStride 中的 dst_stride 和 src_stride 都设置为 0，则为连续数据搬运，且参数 section_1d 无效。 |
| direct | 枚举类型 MemcpyDirect，支持以下两种数据搬运模式：<br>· MemcpyGlobalToSpm：Global 存储向 SPM 存储的数据搬运。<br>· MemcpySpmToGlobal：SPM 存储向 Global 存储的数据搬运。 |
| handle | （可选）MemcpyHandle 类型变量，用于控制不同的非阻塞型 DMA 数据搬运组。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| void * | 返回一个等同于 dst 的指针。 |

**注意事项**

- 需要引入 sdaa 命名空间。
- 暂不支持以下功能：
  - 同一计算核心上 SPM 存储之间的非阻塞型数据搬运。
  - Global 存储和 Global 存储之间的非阻塞型数据搬运。
  - 不同计算核心的 SPM 存储之间的数据搬运，可参考 RMA 数据搬运和 Broadcast 数据搬运。
- Global 和 SPM 的存储空间地址需要 4B 对齐。
- memcpy_async 需要与 memcpy_wait 配合使用。

**使用示例1**

以 Global 存储和 SPM 存储上长度为 32 个 int 的数组为例，介绍如何使用 memcpy_async 和 memcpy_wait 将 Global 存储上的数据非阻塞拷贝到 SPM 存储。

```cpp
using namespace sdaa;
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                            17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 将数据从Global存储拷贝到SPM存储
__global__ void test_global_to_spm_async()
{
    int *tmp = (int *)malloc(32 * sizeof(int));
    init_array_get(tmp, 32, 9);
    if (threadIdx == 0) {
        // 非阻塞型拷贝，填入目的地址，源地址，搬运数据量，搬运方向是Global到SPM
        memcpy_async(tmp, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm);
    }

    // 等待直到完成所有的非阻塞型数据搬运
    memcpy_wait();
    free(tmp);
}
```

**使用示例2**

以 Global 存储和 SPM 存储上两个长度为 32 个 int 的数组为例，介绍如何使用 MemcpyHandle、memcpy_async 和 memcpy_wait 将 Global 存储上的数据非阻塞拷贝到 SPM 存储。

```cpp
using namespace sdaa;
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                             17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 将数据从Global存储拷贝到SPM存储
__global__ void test_global_to_spm_async()
{
    // 申请SPM上的空间
    int *tmp1 = (int *)malloc(32 * sizeof(int));
    int *tmp2 = (int *)malloc(64 * sizeof(int));
    int *tmp3 = (int *)malloc(64 * sizeof(int));
    // 给申请的SPM空间做数据初始化
    init_array_get(tmp1, 32, 9);
    init_array_get(tmp2, 32, 9);
    init_array_get(tmp3, 32, 9);
    // 声明2个MemcpyHandle
    MemcpyHandle handle1, handle2;
    if (threadIdx == 0) {
        // 非阻塞拷贝
        memcpy_async(tmp1, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm);               // 使用默认组
        memcpy_async(tmp2, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle1);      // 使用handle1组
        memcpy_async(tmp3, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle1);      // 使用handle1组
        memcpy_async(tmp2 + 32, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle2); // 使用handle2组
        memcpy_async(tmp3 + 32, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle2); // 使用handle2组
    }

    // 等待直到完成所有的非阻塞数据搬运
    memcpy_wait();        // 等待默认组上所有非阻塞拷贝操作完成
    memcpy_wait(handle1); // 等待handle1组上所有非阻塞拷贝操作完成
    memcpy_wait(handle2); // 等待hanlde2组上所有非阻塞拷贝操作完成

    free(tmp3);
    free(tmp2);
    free(tmp1);
}
```

**使用示例3**

以 Global 存储和 SPM 存储上两个长度为 200、数据类型为 short 的数组为例，介绍如何使用 MemoryStride、MemcpyHandle、memcpy_async 和 memcpy_wait 将 SPM 存储上的数据以跨步的方式搬运到 Global 存储空间。

```cpp
using namespace sdaa;
#define SIZE 200
#define STRIDE 4
#define SECTION 4
#define SECTION_NUM 20
#define DATA_SIZE 80
__device__ short g_dst[SIZE];

__global__ void func(short *d_dst, short *d_src)
{
    if (threadIdx != 0) {
        return;
    }

    // 在SPM存储空间申请内存
    short *spm_src = (short *)malloc(SIZE * sizeof(short));
    for (int i = 0; i < SIZE; i++) {
        g_dst[i] = d_dst[i];     // 初始化Global存储空间变量
        spm_src[i] = d_src[i];   // 初始化SPM存储空间变量
    }

    // 声明handle
    MemcpyHandle handle;

    // 配置跨步参数，进行非阻塞跨步拷贝
    memcpy_async(g_dst, spm_src, DATA_SIZE * sizeof(short),
                 SECTION * sizeof(short), {STRIDE * sizeof(short), 0},
                 MemcpySpmToGlobal, handle);
    memcpy_wait(handle);       // 等待handle组上的非阻塞拷贝完成

    // 其他代码逻辑

    free(spm_src);
}
```

##### 7.6.1.3.3 memcpy_wait

```cpp
void memcpy_wait()
void memcpy_wait(MemcpyHandle &handle)
```

**功能介绍**

非阻塞数据搬运同步，确保之前所有的数据搬运完成。可以通过 MemcpyHandle 控制所属的非阻塞型 DMA 数据搬运组，若没有使用 MemcpyHandle，则使用系统默认的非阻塞型 DMA 数据搬运组。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| handle | （可选）MemcpyHandle 类型变量，用于控制不同的非阻塞型 DMA 数据搬运组。 |

**返回值**

无。

**注意事项**

- 需要引入 sdaa 命名空间。
- memcpy_wait 需要与 memcpy_async 配合使用。

**使用示例1**

以 Global 存储和 SPM 存储上长度为 32 个 int 的数组为例，介绍如何使用 memcpy_async 和 memcpy_wait 将 Global 存储上的数据非阻塞拷贝到 SPM 存储。

```cpp
using namespace sdaa;
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                            17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 将数据从Global存储拷贝到SPM存储
__global__ void test_global_to_spm_async()
{
    int *tmp = (int *)malloc(32 * sizeof(int));
    init_array_get(tmp, 32, 9);
    if (threadIdx == 0) {
        // 非阻塞拷贝
        memcpy_async(tmp, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm);
    }

    // 等待默认组上所有非阻塞拷贝操作完成
    memcpy_wait();
    free(tmp);
}
```

**使用示例2**

以 Global 存储和 SPM 存储上两个长度为 32 个 int 的数组为例，介绍如何使用 MemcpyHandle、memcpy_async 和 memcpy_wait 将 Global 存储上的数据非阻塞拷贝到 SPM 存储。

```cpp
using namespace sdaa;
// 初始化Global存储上input中的数据
__device__ int input[32] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                             17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};

// 初始化SPM存储中的数据
__device__ void init_array_get(int *array, int num, int val)
{
    for (int i = 0; i < num; i++) {
        array[i] = val;
    }
}

// 将数据从Global存储拷贝到SPM存储
__global__ void test_global_to_spm_async()
{
    // 在SPM上申请数据空间
    int *tmp1 = (int *)malloc(32 * sizeof(int));
    int *tmp2 = (int *)malloc(64 * sizeof(int));
    int *tmp3 = (int *)malloc(64 * sizeof(int));
    // 给申请的数据空间初始化数据
    init_array_get(tmp1, 32, 9);
    init_array_get(tmp2, 32, 9);
    init_array_get(tmp3, 32, 9);
    MemcpyHandle handle1, handle2;
    if (threadIdx == 0) {
        // 非阻塞拷贝
        memcpy_async(tmp1, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm);               // 使用默认组
        memcpy_async(tmp2, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle1);      // 使用handle1组
        memcpy_async(tmp3, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle1);      // 使用handle1组
        memcpy_async(tmp2 + 32, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle2); // 使用handle2组
        memcpy_async(tmp3 + 32, &input[0], 32 * sizeof(int), 0, {0, 0}, MemcpyGlobalToSpm, handle2); // 使用handle2组
    }

    // 等待直到完成所有的非阻塞数据搬运
    memcpy_wait();        // 等待默认组上所有非阻塞拷贝操作完成
    memcpy_wait(handle1); // 等待handle1组上所有非阻塞拷贝操作完成
    memcpy_wait(handle2); // 等待hanlde2组上所有非阻塞拷贝操作完成

    free(tmp3);
    free(tmp2);
    free(tmp1);
}
```

##### 7.6.1.3.4 check_memcpy_async

```cpp
unsigned int check_memcpy_async(const void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, MemcpyDirect direct)
unsigned int check_memcpy_async(const void *dst, const void *src, size_t size, size_t section_1d, MemoryStride stride_1d, MemcpyDirect direct, MemcpyHandle &handle)
```

**功能介绍**

验证 memcpy_async 输入参数的合法性，通过返回值判断输入参数是否满足特定的输入要求，如：源地址与目的地址是否对齐、数据搬运量是否符合要求等。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| dst | 数据搬运的目的地址，可以为 Global 存储或 SPM 存储的地址，需要 4B 对齐。 |
| src | 数据搬运的源地址，可以为 Global 存储或 SPM 存储的地址，需要 4B 对齐。 |
| size | 数据搬运量的大小，单位：Byte，需要是 4B 的整数倍。<br>说明：<br>· 数据搬运量的大小受 SPM 存储空间大小限制，可参考存储空间可用大小章节获取对应的堆空间、栈空间、local 空间等的大小。<br>· 理论最大数据搬运量为：对应 SPM 存储空间的大小。 |
| section_1d | 一维数据搬运单元大小，单位：Byte，需要是 4B 的整数倍。 |
| stride_1d | MemoryStride 结构体类型变量，设置源地址和目的地址存储空间的一维跨步单元大小，单位：Byte。<br>说明：<br>· MemoryStride 的设置受硬件限制：<br>　- 目前仅支持在 Global 存储空间，设置跨步单元的大小。<br>　- 跨步单元的大小，需要小于 Global 存储空间的大小，可参考存储空间可用大小。<br>· 如果 MemoryStride 中的 dst_stride 和 src_stride 都设置为 0，则为连续数据搬运，且当前接口的 section_1d 参数无效。 |
| direct | 枚举类型 MemcpyDirect，支持以下两种数据搬运模式：<br>· MemcpyGlobalToSpm：Global 存储空间到 SPM 存储空间的数据搬运。<br>· MemcpySpmToGlobal：SPM 存储空间到 Global 存储空间的数据搬运。 |
| handle | （可选）MemcpyHandle 类型变量，用于控制不同的非阻塞型 DMA 数据搬运组。 |

**返回值**

| 返回值类型 | 说明 |
|-----------|------|
| unsigned int | 参数合法性验证结果，每个 Bit 代表不同的状态信息。对应枚举型 MemcpyAsyncStatus，当前可表示状态有：<br>· MEMCPY_ASYNC_SUCC：参数无误。<br>· MEMCPY_ASYNC_ERR_ADDR_UNALIGNED：源地址或目的地址不满足对齐要求。<br>· MEMCPY_ASYNC_ERR_SIZE_ILLEGAL：数据搬运量不满足要求。<br>· MEMCPY_ASYNC_ERR_DIRECT_ILLEGAL：数据搬运方向不满足要求。<br>· MEMCPY_ASYNC_ERR_STRIDE_PARAM：跨步参数错误。 |

返回的具体状态信息可参照如下表格：

| 第 0 位 | 第 1 位 | 第 2 位 | 第 3 位 | 第 4 位 |
|--------|--------|--------|--------|--------|
| 0：参数无误。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 | 第 0 位是 0 时，此位保留。 |
| 1：参数有误。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。源地址或目的地址不满足对齐要求。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。数据搬运量不满足要求。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。数据搬运方向不满足要求。 | 第 0 位是 1 时，此位：<br>0：正常。<br>1：错误。跨步参数错误。 |

**注意事项**

需要引入 sdaa 命名空间。

**使用示例**

使用带跨步参数的 check_memcpy_async 接口，对数据搬运参数进行安全检查。

```cpp
using namespace sdaa;
__device__ void func(void *dst, const void *src, size_t size)
{
    if (threadIdx != 0) {
        return;
    }
    // 每个数据搬运单元大小是8B
    constexpr size_t section = 2 * sizeof(int);
    // Global上的跨步大小是8B
    constexpr size_t glbmem_stride = 2 * sizeof(int);
    // 创建MemcpyHandle类的对象
    MemcpyHandle handle;
    // 获取check_memcpy_async函数的返回值
    int check_val = check_memcpy_async(dst, src, size, section, {0, glbmem_stride}, MemcpyGlobalToSpm, handle);

    // 通过check_memcpy_async的返回值确认memcpy_async参数是否合法，合法则进行memcpy_async操作
    if (check_val == MEMCPY_ASYNC_SUCC) {
        memcpy_async(dst, src, size, section, {0, glbmem_stride}, MemcpyGlobalToSpm, handle);

        // 其他代码逻辑
        ...

        memcpy_wait(handle);
    }
}
```

### 7.6.2 RMA数据搬运

#### 7.6.2.1 概述

RMA（Remote Memory Access）数据搬运是指同一计算核心阵列 SPA 内两个不同计算核心 SPE 的 SPM 存储之间的数据流动。

RMA 数据搬运可以分为阻塞型 RMA 数据搬运和非阻塞型 RMA 数据搬运：

- 阻塞型 RMA 数据搬运：使用简单，但性能不佳。
- 非阻塞型 RMA 数据搬运：使用相对复杂，但性能较好。

图1 RMA数据搬运

**阻塞型 RMA 数据搬运**

阻塞型 RMA 操作由以下函数接口组成：

- `rma_get`：在同一计算核心阵列 SPA 内，将远端计算核心 SPE 中指定的 SPM 存储数据以阻塞的方式搬运到当前计算核心 SPE 中指定的 SPM 存储空间内。
- `rma_put`：在同一计算核心阵列 SPA 内，将当前计算核心 SPE 中指定的 SPM 存储数据以阻塞的方式搬运到远端计算核心 SPE 中指定的 SPM 存储空间内。

**非阻塞型 RMA 数据搬运**

非阻塞型 RMA 操作由以下函数接口组成：

- `RmaHandle`：用于存储远端计算核心 SPE 的 ID。
- `rma_set_thread_id`：配置远端计算核心 SPE 的 ID。
- `rma_set_thread_group`：配置由多个远端计算核心 SPE 的 ID 组成的线程组。
- `rma_async_get`：将远端计算核心 SPE 中指定的 SPM 存储空间数据非阻塞拷贝到当前计算核心 SPE 中指定的 SPM 存储空间内。
- `rma_async_put`：将当前计算核心 SPE 中指定的 SPM 存储空间数据非阻塞拷贝到远端计算核心 SPE 中指定的 SPM 存储空间内。
- `rma_complete`：等待当前计算核心 SPE 完成非阻塞型 RMA 数据搬运。
- `rma_wait`：等待远端计算核心 SPE 完成非阻塞型 RMA 数据搬运。

#### 7.6.2.2 阻塞型RMA数据搬运

##### 7.6.2.2.1 rma_get

```c
void rma_get(void *local_addr, const void *remote_addr, size_t size, unsigned long local_id, unsigned long remote_id)
```

**功能介绍**

在同一计算核心阵列 SPA 内，将远端计算核心 SPE 中指定的 SPM 存储数据以阻塞的方式搬运到当前计算核心 SPE 中指定的 SPM 存储空间内。

**参数解释**

| 参数名称 | 说明 |
|---------|------|
| local_addr | 数据搬运的目的地址，当前计算核心的 SPM 存储空间地址。 |
| remote_addr | 数据搬运的源地址，远端计算核心的 SPM 存储空间地址。 |
| size | 数据搬运大小，单位：Byte。数据搬运量的大小受 SPM 存储空间大小限制，可参照不同存储空间可用大小，理论最大数据搬运量为：源地址和目标地址所在空间较小者的空间大小。 |
| local_id | 发起 RMA 操作的计算核心 ID。 |
| remote_id | 远端计算核心的 ID。 |

**返回值**

无。

> 注：本片段在此处截断于 rma_get 的"返回值：无。"之后；rma_get 的注意事项、使用示例及后续 RMA 接口（rma_put 及非阻塞型 RMA 接口等）由文档的后续部分继续覆盖。
