---
id: doc-tecolibrt-user-manual-v1-2-0-p06
title: "TecoLIBRT 用户手册 v1.2.0 — 第6部分 (ch108-123-dma-broadcast)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "5510-6321"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, dma, broadcast, hardware-broadcast, ibcast, rt-dma-ibcast, rt-dma-ibcast-stride, rt-dma-col-ibcast, rt-dma-col-ibcast-stride, rt-dma-row-ibcast, rt-dma-row-ibcast-stride, fan-out, sdaa, teco-t1]
---

## 108. 广播操作
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca6c2861fcb11eebaac0242ac11000c

全广播列广播行广播


<a id="page-109"></a>
## 109. 全广播
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca770641fcb11eebaac0242ac11000c

rt_dma_ibcast()rt_dma_ibcast_stride()rt_h_dma_trans_ibcast()rt_s_dma_trans_ibcast()


<a id="page-110"></a>
## 110. rt_dma_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca8e4441fcb11eebaac0242ac11000c

```c
int rt_dma_ibcast(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，广播到所有计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-111"></a>
## 111. rt_dma_ibcast_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcaab4ea1fcb11eebaac0242ac11000c

```c
int rt_dma_ibcast_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，跨步广播到所有计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
bsize

 | 输入

 | 跨步向量块大小，单位：字节，需为4的整数倍。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-112"></a>
## 112. rt_h_dma_trans_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcac6f061fcb11eebaac0242ac11000c

```c
int rt_h_dma_trans_ibcast(
    _Float16    *dest,
    _Float16    *src,
    int         stride,
    void        *reply);

```

## 功能介绍
将设备内存上的`_Float16`数据，转置广播到所有计算核心SPE的SPM指定位置，一次完成`32*32*2B`向量块的转置广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-113"></a>
## 113. rt_s_dma_trans_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcae09241fcb11eebaac0242ac11000c

```c
int rt_s_dma_trans_ibcast(
    float   *dest,
    float   *src,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的`float`数据，转置广播到所有计算核心SPE的SPM指定位置，一次完成`16*16*4B`向量块的转置广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-114"></a>
## 114. 列广播
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcaec1ca1fcb11eebaac0242ac11000c

rt_dma_col_ibcast()rt_dma_col_ibcast_stride()rt_h_dma_trans_col_ibcast()rt_s_dma_trans_col_ibcast()


<a id="page-115"></a>
## 115. rt_dma_col_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb03ff01fcb11eebaac0242ac11000c

```c
int rt_dma_col_ibcast(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，广播到同一列计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-116"></a>
## 116. rt_dma_col_ibcast_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb253941fcb11eebaac0242ac11000c

```c
int rt_dma_col_ibcast_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，跨步广播到同一列计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
bsize

 | 输入

 | 跨步向量块大小，单位：字节，需为4的整数倍。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-117"></a>
## 117. rt_h_dma_trans_col_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb3ed801fcb11eebaac0242ac11000c

```c
int rt_h_dma_trans_col_ibcast(
    _Float16    *dest,
    _Float16    *src,
    int         stride,
    void        *reply);

```

## 功能介绍
将设备内存上的`_Float16`数据，转置广播到同一列计算核心SPE的SPM指定位置，一次完成`32*32*2B`向量块的转置广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-118"></a>
## 118. rt_s_dma_trans_col_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb634321fcb11eebaac0242ac11000c

```c
int rt_s_dma_trans_col_ibcast(
    float   *dest,
    float   *src,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的`float`数据，转置广播到同一列计算核心SPE的SPM指定位置，一次完成`16*16*4B`向量块的转置广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-119"></a>
## 119. 行广播
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb6ffc01fcb11eebaac0242ac11000c

rt_dma_row_ibcast()rt_dma_row_ibcast_stride()rt_h_dma_trans_row_ibcast()rt_s_dma_trans_row_ibcast()


<a id="page-120"></a>
## 120. rt_dma_row_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcb8f12c1fcb11eebaac0242ac11000c

```c
int rt_dma_row_ibcast(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，广播到同一行计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-121"></a>
## 121. rt_dma_row_ibcast_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcbaf6341fcb11eebaac0242ac11000c

```c
int rt_dma_row_ibcast_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的数据，跨步广播到同一行计算核心SPE的SPM指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |
bsize

 | 输入

 | 跨步向量块大小，单位：字节，需为4的整数倍。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为4的整数倍。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-122"></a>
## 122. rt_h_dma_trans_row_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcbcc1b21fcb11eebaac0242ac11000c

```c
int rt_h_dma_trans_row_ibcast(
    _Float16    *dest,
    _Float16    *src,
    int         stride,
    void        *reply);

```

## 功能介绍
将设备内存上的`_Float16`数据，转置广播到同一行计算核心SPE的SPM指定位置，一次完成`32*32*2B`向量块的转置广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-123"></a>
## 123. rt_s_dma_trans_row_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcbe874a1fcb11eebaac0242ac11000c

```c
int rt_s_dma_trans_row_ibcast(
    float   *dest,
    float   *src,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的`float`数据，转置广播到同一行计算核心SPE的SPM指定位置，一次完成`16*16*4B`向量块广播，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须64字节对齐。

 |
stride

 | 输入

 | 设备内存跨步，单位：字节，需为64的整数倍。在转置DMA中，跨步向量块为64字节。配置此参数时，需要固定减去64字节的跨步向量块。

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-124"></a>
