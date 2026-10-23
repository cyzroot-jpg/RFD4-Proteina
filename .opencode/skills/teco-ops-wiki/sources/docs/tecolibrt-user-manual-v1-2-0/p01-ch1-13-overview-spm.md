---
id: doc-tecolibrt-user-manual-v1-2-0-p01
title: "TecoLIBRT 用户手册 v1.2.0 — 第1部分 (ch1-13-overview-spm)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "154-809"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, rt, spm, ldm, rt-ldm-malloc, predefined-vars, rt-tid, rt-rid, rt-cid, quickstart, naming, sdaa, teco-t1]
---

## 1. TecoLIBRT用户手册
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc159d1a1fcb11eebaac0242ac11000c

什么是TecoLIBRT最新动态快速入门功能特性常见问题版权声明


<a id="page-2"></a>
## 2. 什么是TecoLIBRT
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#47b58614207611eebaac0242ac11000c

## 概述
TecoLIBRT面向已经熟练掌握SDAA C编程的用户，提供了一系列较为底层的运行时接口和通用属性，为性能优化的开发者提供更灵活、丰富的运行时支持。

同时，TecoLIBRT迭代补充了有助于片上计算性能优化的接口，比如规约接口、SPE间通信接口等，也增加了部分错误调试的功能，比如越界检查、SPM分配失败检查等。

## 核心功能
TecoLIBRT主要包含以下几类功能接口：

接口分类

 | 说明

 |
预定义变量

 | 获取当前SPE的编号、行号、列号信息。

 |
SPM管理

 | 申请、释放SPE的SPM空间。

 |
计算接口

 | 包含SPE间同步、矩阵乘法、远程访问SPM、时间统计等功能。

 |
SPE间通信

 | 包含SPE间的数据读写、广播操作（支持灵活选择广播的行/列），并提供阻塞、非阻塞式实现。

 |
设备内存访问

 | 包含设备内存与SPE间的数据读写、广播操作。

- 数据读写支持跨步、转置、物理地址、地址非对齐等情况的阻塞式、非阻塞式实现。

- 广播支持非阻塞式的跨步、转置、行/列的灵活选择。

 |
规约操作

 | 支持行、列、全阵列的累加运算，并将结果更新到指定SPE。

 |
检查与打印

 | 提供输入参数地址是否对齐、参数是否为零、参数是否相等的检查。提供INFO或ERROR，两种级别的日志打印功能。

 |


<a id="page-3"></a>
## 3. 核心概念
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc19e3841fcb11eebaac0242ac11000c

## SPE的行号和列号
每个计算核心阵列SPA包含四行八列，共32个计算核心SPE。其中，列号0~3为左半区，列号4~7为右半区。每个SPE从左上角到右下角编号为0~31。每个计算核心SPE有各自的行号和列号，以9号核心为例，行号为1，列号为1。

![image](images/1703349181-f046e6c2-a1b0-11ee-abe8-024214151608.png)

图2.1 SPA内的SPE编号示意图

## 地址对齐
地址对齐(Aligned Address)是指数据在内存中的存放位置需要满足一定的规则或要求，即：数据的起始地址必须符合一定的边界条件，通常以数据类型的字节长度为基准。例如，对于一个4字节的整型变量，要求其起始地址是4的倍数（如0、4、8、12等）。

这样的对齐方式可以让计算机在读取数据时更高效，减少访问的时间和成本，可以通过rt_align_n()检查地址对齐状态。

## 掩码
掩码(Mask)主要用于选择或屏蔽其他二进制数据中的特定位，通常与位运算结合使用。

具体而言，可以将需要选中的位设置为1，不需要选中的位设置为0。通过与运算(AND)将掩码与目标数据进行逻辑运算，实现清零或屏蔽选中位之外的操作目标。

例如，针对8位的二进制数 `11001101`，需要选中其中的第3位和第6位（从右向左数），可以通过以下步骤实现：

- 首先，创建掩码，将选中位设置为1，其他位设置为0，即 `00100100`。

- 其次，将这个掩码与原始数据进行与运算，得到一个结果为 `00000100` 的8位二进制数。

这意味着第3位和第6位被选中，其他位都被清零。

## 跨步操作
跨步操作(Stride Operation)可以根据需求选择性地跳过某些元素或以特定步长从存储介质加载数据，而不是按照顺序逐个元素地加载。具体选择可以通过设置跨步参数，定义步长(Stride)和数量来实现，步长表示每次读取操作应该跳过的元素数量，数量表示需要读取的元素总数。步长(Stride)统一从跨步向量块(bsize)的end开始计算，而非start。


<a id="page-4"></a>
## 4. 命名规则
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#5eaa37b6207611eebaac0242ac11000c

针对大量高灵活性的功能组合，TecoLIBRT接口命名由以下关键字组成，通过关键字的组合，限定接口功能。例如，rt_dma_col_ibcast_stride() 含 `dma`、`col`、`i`、`bcast`、`stride`这5个关键字，代表着设备内存与SPE间的跨步列广播操作，属于非阻塞式。

关键字

 | 含义

 |
`col`

 | 列操作。

 |
`row`

 | 行操作。

 |
`rma`

 | SPE间通信。

 |
`dma`

 | 设备内存（Global存储空间）与SPE间通信。

 |
`i`

 | 非阻塞式。

 |
`bcast`

 | 广播。

 |
`mcast`

 | 多播。

 |
`other`

 | 当前SPE不接收数据。

 |
`coll`

 | 指定行/列。

 |
`stride`

 | 跨步。

 |
`trans`

 | 转置，支持 s类型`16*16*4B`和 h类型`32*32*2B`。

 |
`phy`

 | 物理地址。

 |
`unaligned`

 | 地址非对齐。

 |
`reduce`

 | 规约。

 |


<a id="page-5"></a>
## 5. 最新动态
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc1bc8a21fcb11eebaac0242ac11000c

## v1.2.0版本
- 新增功能

名称

 | 说明

 |
rt_synchronized_peer()

 | SPE间点对点同步。

 |
rt_rma_row_mcast_other()

 | SPE间行多播（当前SPE不接收数据）。

 |
rt_rma_col_imcast_other()

 | 非阻塞式，SPE间列多播（当前SPE不接收数据）。

 |
rt_rma_row_imcast_other()

 | 非阻塞式，SPE间行多播（当前SPE不接收数据）。

 |

## v1.1.0版本
- 新增功能

名称

 | 说明

 |
rt_unaligned_dma_get()

 | 地址非对齐情况下，设备内存和SPE间的数据读取操作。

 |
rt_unaligned_dma_put()

 | 地址非对齐情况下，设备内存和SPE间的数据写出操作。

 |
rt_unaligned_dma_get_stride()

 | 地址非对齐情况下，设备内存和SPE间的数据跨步读取操作。

 |
rt_unaligned_dma_put_stride()

 | 地址非对齐情况下，设备内存和SPE间的数据跨步写出操作。

 |

## v1.0.0版本
初版发布。


<a id="page-6"></a>
## 6. 快速入门
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc1db2ca1fcb11eebaac0242ac11000c

本节将以设备内存访问和矩阵乘法为例，演示相关接口的使用方式。其中，

- 设备内存访问部分：提供了阻塞式和非阻塞式两种接入情况，详见下方代码及其注释。

- 矩阵乘法部分：提供了矩阵不拆分计算和矩阵拆分计算两种接入情况，详见下方代码及其注释。

## 设备内存访问示例

### 阻塞接口

```c
int blk_num = 1024;

// 分别为 x, y, z 申请SPM存储空间
float *x_buf = rt_ldm_malloc(blk_num * sizeof(float));
float *y_buf = rt_ldm_malloc(blk_num * sizeof(float));
float *z_buf = rt_ldm_malloc(blk_num * sizeof(float));

// 将 x, y的数据从设备内存读取到SPM上
rt_dma_get(x_buf, x, blk_num * sizeof(float));
rt_dma_get(y_buf, y, blk_num * sizeof(float));

// 执行 z = x + y 的运算操作
for(int i = 0; i < blk_num; i++){
    z_buf[i] = x_buf[i] + y_buf[i];
}

// 将结果数据 z 从SPM上，写入设备内存
rt_dma_put(z, z_buf, blk_num * sizeof(float));

// 释放 x, y, z 的SPM存储空间
rt_ldm_free(x_buf);
rt_ldm_free(y_buf);
rt_ldm_free(z_buf);

```

### 非阻塞双缓冲计算

```c
if(curr_num > 0){
    // 将 x, y的数据从设备内存读取到SPM上
    rt_dma_iget(pD_x, x + tid * blk_num, curr_num * sizeof(float), &x_get_reply);
    rt_dma_iget(pD_y, y + tid * blk_num, curr_num * sizeof(float), &y_get_reply);
}

for(int idx =(tid * blk_num); idx < data_num; idx += (slave_core_num*blk_num)){
    next_num = MIN(blk_num, data_num - idx - slave_core_num * blk_num);

    rt_dma_wait_value(&x_get_reply, 1); x_get_reply = 0;
    rt_dma_wait_value(&y_get_reply, 1); y_get_reply = 0;

    pTemp = pC_x; pC_x = pD_x; pD_x = pTemp;
    pTemp = pC_y; pC_y = pD_y; pD_y = pTemp;

    if(next_num>0){
        rt_dma_iget(pD_x, x + idx + slave_core_num * blk_num, next_num * sizeof(float), &x_get_reply);
        rt_dma_iget(pD_y, y + idy + slave_core_num * blk_num, next_num * sizeof(float), &y_get_reply);
    }

    // 执行 z = x + y 的运算操作
    for(int i = 0; i < curr_num; i++){
        pC_z[i] = pC_x[i] + pC_y[i]
    }

    rt_dma_wait_value(&z_put_reply, 1);
    z_put_reply = 0;
    pTemp = pC_z; pC_z = pD_z; pD_z = pTemp;

    // 将结果数据 z 从SPM上，写入设备内存
    rt_dma_iput(z + idx, pD_z, curr_num * sizeof(float), &z_put_reply);
    curr_num = next_num
}
rt_dma_wait_value(&z_put_reply, 1);

```

## 矩阵乘法示例

### 普通情况

```c
int i, j, k;
int M, N, K;

M = 128;
N = 32;
K = 32;

// 分别为 ldm_a, ldm_b, ldm_c_ace 申请SPM存储空间
_Float16 *ldm_a = rt_ldm_malloc(M * K * sizeof(_Float16));
_Float16 *ldm_b = rt_ldm_malloc(K * N * sizeof(_Float16));
_Float16 *ldm_c_ace = rt_ldm_malloc(M * N * sizeof(_Float16));

memset(ldm_c_ace, 0, M * N * sizeof(_Float16));

// 填充矩阵数据
for(i = 0; i < M * K; i++){
    ldm_a[i] = i % K + i;
}
for(i = 0; i < K * N; i++){
    ldm_b[i] = 1;
}

// 配置脉动阵列
rt_ace_config_kernel(1);

// 加载北向数据
rt_ace_load_north(ldm_b, 0);

// 加载西向数据
rt_ace_load_west(ldm_a, 0, 1, M, 0, 1, 0, 1);

// 累加结果写回
ace_reply = 0;
rt_ace_writeback(ldm_c_ace, M, &ace_reply, 0);
while(ace_reply != 1);

// 释放 ldm_a, ldm_b, ldm_c_ace 的SPM存储空间
rt_ldm_free(ldm_a);
rt_ldm_free(ldm_b);
rt_ldm_free(ldm_c_ace);

```

### 数据分块情况

```c
M = 128;
N = 64;
K = 96;

// 分别为 ldm_a, ldm_b, ldm_c_ace 申请SPM存储空间
ldm_a = rt_ldm_malloc(M * K * sizeof(_Float16));
ldm_b = rt_ldm_malloc(K * N * sizeof(_Float16));
ldm_c_ace = rt_ldm_malloc(M * N * sizeof(_Float16));

memset(ldm_c_ace, 0, M * N * sizeof(_Float16));

// 填充矩阵数据
for(i = 0; i < M * K; i++){
    ldm_a[i] = i % K + i;
}
for(i = 0; i < K * N; i++){
    ldm_b[i] = i % N - i;
}

// 假设ldm_a上的数据维度为[M, K]
// 假设ldm_b上的数据维度为[K/32, N/32, 32, 32]
// 分块计算
for(j = 0; j < N; j += 32){
    for(k = 0; k < K; k += 32){
        // 加载北向数据
        rt_ace_load_north(ldm_b + k * N + j* 32, 0);
        // 加载西向数据
        rt_ace_load_west(ldm_a + k, 0, 1, M, (K - 32) / 32, (k + 32 >= K), 0, 1);
    }

    // 累加结果写回
    ace_reply = 0;
    rt_ace_writeback(ldm_c_ace + M * j, M, &ace_reply, 0);
    while(ace_reply == 0);
}

// 释放 ldm_a, ldm_b, ldm_c_ace 的SPM存储空间
rt_ldm_free(ldm_a);
rt_ldm_free(ldm_b);
rt_ldm_free(ldm_c_ace);

```


<a id="page-7"></a>
## 7. 功能特性
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#f993b15e1fcb11eebaac0242ac11000c

预定义变量SPM管理计算接口SPE间通信设备内存访问规约操作检查与打印


<a id="page-8"></a>
## 8. 预定义变量
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc1e92121fcb11eebaac0242ac11000c

## rt_tid
功能介绍

计算核心SPE的编号（0~31）。

## rt_rid
功能介绍

计算核心SPE的行号（0~3）。

## rt_cid
功能介绍

计算核心SPE的列号（0~7）。


<a id="page-9"></a>
## 9. SPM管理
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc1f86d61fcb11eebaac0242ac11000c

rt_ldm_malloc()rt_ldm_malloc_try_left()rt_ldm_malloc_try_right()rt_ldm_free()


<a id="page-10"></a>
## 10. rt_ldm_malloc()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc20d9d21fcb11eebaac0242ac11000c

```c
void* rt_ldm_malloc(
    size_t  size);

```

## 功能介绍
在计算核心SPE的SPM上申请64字节对齐的空间。默认从左半区开始申请，与rt_ldm_malloc_try_left()功能效果相同。

## 注意事项
必须配合rt_ldm_free()使用，不能与libos_ldm_free()或者libos_ldm_malloc()混用。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
size

 | 输入

 | 申请空间大小，单位：字节。

 |

## 返回值
名称

 | 说明

 |
结果指针

 | 空间申请成功。

 |
NULL

 | 空间申请失败。

 |


<a id="page-11"></a>
## 11. rt_ldm_malloc_try_left()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2239761fcb11eebaac0242ac11000c

```c
void* rt_ldm_malloc_try_left(
    size_t  size);

```

## 功能介绍
在SPM存储空间的左半区申请64字节对齐的空间。若左半区空间不足，超出部分会分布在右半区。

## 注意事项
必须配合rt_ldm_free()使用，不能与libos_ldm_free()或者libos_ldm_malloc()混用。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
size

 | 输入

 | 申请空间大小，单位：字节。

 |

## 返回值
名称

 | 说明

 |
结果指针

 | 空间申请成功。

 |
NULL

 | 空间申请失败。

 |


<a id="page-12"></a>
## 12. rt_ldm_malloc_try_right()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc23924e1fcb11eebaac0242ac11000c

```c
void* rt_ldm_malloc_try_right(
    size_t  size);

```

## 功能介绍
在SPM存储空间的右半区申请64字节对齐的空间。若右半区空间不足，超出部分会分布在左半区。

## 注意事项
必须配合rt_ldm_free()使用，不能与libos_ldm_free()或者libos_ldm_malloc()混用。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
size

 | 输入

 | 申请空间大小，单位：字节。

 |

## 返回值
名称

 | 说明

 |
结果指针

 | 空间申请成功。

 |
NULL

 | 空间申请失败。

 |


<a id="page-13"></a>
## 13. rt_ldm_free()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc24c43e1fcb11eebaac0242ac11000c

```c
void rt_ldm_free(
    void    *ptr);

```

## 功能介绍
释放由rt_ldm_malloc()，rt_ldm_malloc_try_left()，rt_ldm_malloc_try_right()申请的SPM存储空间。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
ptr

 | 输入

 | 需要释放空间的SPM首地址。

 |

## 返回值
暂无明确含义。


<a id="page-14"></a>
