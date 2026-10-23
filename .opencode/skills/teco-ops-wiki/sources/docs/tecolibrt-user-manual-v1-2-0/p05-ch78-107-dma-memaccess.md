---
id: doc-tecolibrt-user-manual-v1-2-0-p05
title: "TecoLIBRT 用户手册 v1.2.0 — 第5部分 (ch78-107-dma-memaccess)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "3798-5509"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, dma, device-memory, rt-dma, rt-dma-get, rt-dma-iget, rt-dma-get-stride, rt-dma-iget-stride, rt-dma-put, rt-dma-iput, rt-dma-phy-get, rt-unaligned-dma-get, sdaa, teco-t1]
---

## 78. 设备内存访问
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc79ea2c1fcb11eebaac0242ac11000c

通用接口数据读取数据写出广播操作


<a id="page-79"></a>
## 79. 通用接口
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7a85721fcb11eebaac0242ac11000c

rt_dma()rt_dma_wait_value()


<a id="page-80"></a>
## 80. rt_dma()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7d0d601fcb11eebaac0242ac11000c

```c
int rt_dma(
    dma_mode        Mode,
    DMA_OP          Op,
    void            *Addr,
    void            *Ldm_addr,
    int             Len,
    void            *Rrply,
    int             Bcast_mask,
    int             Stride,
    int             Bsize);

```

## 功能介绍
在设备内存和SPE的SPM间进行数据传输。传输模式由mode指定，传输方向由op指定，非阻塞式。分为以下两种情况：

- SPM读取设备内存的数据，将设备内存的数据读取到SPM的指定位置。

- SPM向设备内存写入数据，将SPM的数据写入设备内存的指定位置。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Mode

 | 输入

 | DMA传输命令模式，二进制低四位有效，dma_mode[3]要求为0。

- `0x0`：单计算核心SPE模式。

- `0x1`：行多播模式，仅dma_get使用。

- `0x2`：列多播模式，仅dma_get使用。

- 其他：保留。

 |
Op

 | 输入

 | DMA传输命令操作码，二进制低四位有效。DMA_OP[3]是转置标志，为1表示转置。该标志仅在数据读取（即[3:0]=0x1或0x3）时有效。

- `0x0`：数据写出。

- `0x1`：数据读取。

- `0x2`：数据写出（物理地址）。

- `0x3`：数据读取（物理地址）。

- 其他：保留。

 |
Addr

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
Ldm_addr

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
Len

 | 输入

 | DMA传输数据量，单位：字节。

 |
Rrply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |
Bcast_mask

 | 输入

 | DMA传输多播使能。列多播时，表示参与多播的列。即：某位为1，表示对应的列参加多播，详见核心概念中的掩码介绍。仅支持同个SPA内的列多播。

 |
Stride

 | 输入

 | 设备内存跨步，单位：字节。

 |
Bsize

 | 输入

 | 跨步向量块大小，DMA跨步传输时有效，表示DMA传输的跨步向量块大小，单位：字节。

 |

## 返回值
暂无明确含义。


<a id="page-81"></a>
## 81. rt_dma_wait_value()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7e4c981fcb11eebaac0242ac11000c

```c
int rt_dma_wait_value(
    void    *reply,
    int     value);

```

## 功能介绍
等待DMA回答字，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
reply

 | 输入

 | DMA传输回答字地址，必须为SPE的SPM存储空间地址，地址必须4字节对齐。

 |
value

 | 输入

 | DMA传输完成时，回答字的目标值。

 |

## 返回值
暂无明确含义。


<a id="page-82"></a>
## 82. 数据读取
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7eff801fcb11eebaac0242ac11000c

rt_dma_get()rt_dma_iget()rt_dma_get_stride()rt_dma_iget_stride()rt_dma_phy_get()rt_dma_phy_iget()rt_dma_phy_get_stride()rt_dma_phy_iget_stride()rt_h_dma_trans_get()rt_h_dma_trans_iget()rt_s_dma_trans_get()rt_s_dma_trans_iget()rt_unaligned_dma_get()rt_unaligned_dma_get_stride()


<a id="page-83"></a>
## 83. rt_dma_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc805b781fcb11eebaac0242ac11000c

```c
int rt_dma_get(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
将设备内存的数据读取到SPM存储空间的指定位置，阻塞式。

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

## 返回值
暂无明确含义。


<a id="page-84"></a>
## 84. rt_dma_iget()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc826a441fcb11eebaac0242ac11000c

```c
int rt_dma_iget(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
将设备内存的数据读取到SPM存储空间的指定位置，非阻塞式。

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


<a id="page-85"></a>
## 85. rt_dma_get_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8463e41fcb11eebaac0242ac11000c

```c
int rt_dma_get_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride);

```

## 功能介绍
将设备内存的数据读取到SPM存储空间的指定位置，含跨步操作，阻塞式。

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

## 返回值
暂无明确含义。


<a id="page-86"></a>
## 86. rt_dma_iget_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc861cfc1fcb11eebaac0242ac11000c

```c
int rt_dma_iget_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存的数据读取到SPM存储空间的指定位置，含跨步操作，非阻塞式。

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


<a id="page-87"></a>
## 87. rt_dma_phy_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8781141fcb11eebaac0242ac11000c

```c
int rt_dma_phy_get(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
使用物理地址，将设备内存的数据读取到SPM存储空间的指定位置，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |

## 返回值
暂无明确含义。


<a id="page-88"></a>
## 88. rt_dma_phy_iget()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc88ebb21fcb11eebaac0242ac11000c

```c
int rt_dma_phy_iget(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
使用物理地址，将设备内存的数据读取到SPM存储空间的指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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


<a id="page-89"></a>
## 89. rt_dma_phy_get_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8a845e1fcb11eebaac0242ac11000c

```c
int rt_dma_phy_get_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride);

```

## 功能介绍
使用物理地址，将设备内存的数据读取到SPM存储空间的指定位置，含跨步操作，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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

## 返回值
暂无明确含义。


<a id="page-90"></a>
## 90. rt_dma_phy_iget_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8c51261fcb11eebaac0242ac11000c

```c
int rt_dma_phy_iget_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
使用物理地址，将设备内存的数据读取到SPM存储空间的指定位置，含跨步操作，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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


<a id="page-91"></a>
## 91. rt_h_dma_trans_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8dba5c1fcb11eebaac0242ac11000c

```c
int rt_h_dma_trans_get(
    _Float16    *dest,
    _Float16    *src,
    int         stride);

```

## 功能介绍
将设备内存上的`_Float16`数据转置读取到SPM存储空间的指定位置，一次完成`32*32*2B`向量块的转置读取，阻塞式。

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

## 返回值
暂无明确含义。


<a id="page-92"></a>
## 92. rt_h_dma_trans_iget()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc8f527c1fcb11eebaac0242ac11000c

```c
int rt_h_dma_trans_iget(
    _Float16    *dest,
    _Float16    *src,
    int         stride,
    void        *reply);

```

## 功能介绍
将设备内存上的`_Float16`数据转置读取到SPM存储空间的指定位置，一次完成`32*32*2B`向量块的转置读取，非阻塞式。

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


<a id="page-93"></a>
## 93. rt_s_dma_trans_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc90cc381fcb11eebaac0242ac11000c

```c
int rt_s_dma_trans_get(
    float   *dest,
    float   *src,
    int     stride);

```

## 功能介绍
将设备内存上的`float`数据转置读取到SPM存储空间的指定位置，一次完成`16*16*4B`向量块的转置读取，阻塞式。

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

## 返回值
暂无明确含义。


<a id="page-94"></a>
## 94. rt_s_dma_trans_iget()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9253be1fcb11eebaac0242ac11000c

```c
int rt_s_dma_trans_iget(
    float   *dest,
    float   *src,
    int     stride,
    void    *reply);

```

## 功能介绍
将设备内存上的`float`数据转置读取到SPM存储空间的指定位置，一次完成`16*16*4B`向量块的转置读取，非阻塞式。

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


<a id="page-95"></a>
## 95. rt_unaligned_dma_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc93ac5a1fcb11eebaac0242ac11000c

```c
void rt_unaligned_dma_get(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
支持地址非对齐情况下，将设备内存的数据读取到SPM存储空间的指定位置，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，无任何对齐要求。

 |
src

 | 输入

 | DMA传输设备内存地址，无任何对齐要求。

 |
len

 | 输入

 | DMA传输数据量，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |

## 返回值
暂无明确含义。


<a id="page-96"></a>
## 96. rt_unaligned_dma_get_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9559d81fcb11eebaac0242ac11000c

```c
void rt_unaligned_dma_get_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride);

```

## 功能介绍
支持地址非对齐情况下，将设备内存的数据读取到SPM存储空间的指定位置，含跨步操作，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，无任何对齐要求。

 |
src

 | 输入

 | DMA传输设备内存地址，无任何对齐要求。

 |
len

 | 输入

 | DMA传输数据量，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |
bsize

 | 输入

 | 跨步向量块大小，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |
stride

 | 输入

 | 设备内存跨步，以字节为单位， 可为任意整数。

 |

## 返回值
暂无明确含义。


<a id="page-97"></a>
## 97. 数据写出
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9609be1fcb11eebaac0242ac11000c

rt_dma_put()rt_dma_iput()rt_dma_put_stride()rt_dma_iput_stride()rt_dma_phy_put()rt_dma_phy_iput()rt_dma_phy_put_stride()rt_dma_phy_iput_stride()rt_unaligned_dma_put()rt_unaligned_dma_put_stride()


<a id="page-98"></a>
## 98. rt_dma_put()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc97765a1fcb11eebaac0242ac11000c

```c
int rt_dma_put(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
将SPM存储空间的数据写入到设备内存的指定位置，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |

## 返回值
暂无明确含义。


<a id="page-99"></a>
## 99. rt_dma_iput()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc98feb21fcb11eebaac0242ac11000c

```c
int rt_dma_iput(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
将SPM存储空间的数据写入到设备内存的指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

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


<a id="page-100"></a>
## 100. rt_dma_put_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9a9cea1fcb11eebaac0242ac11000c

```c
int rt_dma_put_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride);

```

## 功能介绍
将SPM存储空间的数据写入到设备内存的指定位置，含跨步操作，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

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

## 返回值
暂无明确含义。


<a id="page-101"></a>
## 101. rt_dma_iput_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9c65481fcb11eebaac0242ac11000c

```c
int rt_dma_iput_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
将SPM存储空间的数据写入到设备内存的指定位置，含跨步操作，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，地址必须4字节对齐。

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


<a id="page-102"></a>
## 102. rt_dma_phy_put()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9e162c1fcb11eebaac0242ac11000c

```c
int rt_dma_phy_put(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
使用物理地址，将SPM存储空间的数据写入到设备内存的指定位置，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

 |
len

 | 输入

 | DMA传输数据量，单位：字节，需为4的整数倍。

 |

## 返回值
暂无明确含义。


<a id="page-103"></a>
## 103. rt_dma_phy_iput()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc9f86d81fcb11eebaac0242ac11000c

```c
int rt_dma_phy_iput(
    void    *dest,
    void    *src,
    int     len,
    void    *reply);

```

## 功能介绍
使用物理地址，将SPM存储空间的数据写入到设备内存的指定位置，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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


<a id="page-104"></a>
## 104. rt_dma_phy_put_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca117b41fcb11eebaac0242ac11000c

```c
int rt_dma_phy_put_stride(
    void    *dest,
    void    *src,
    int    len,
    int    bsize,
    int    stride);

```

## 功能介绍
使用物理地址，将SPM存储空间的数据写入到设备内存的指定位置，含跨步操作，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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

## 返回值
暂无明确含义。


<a id="page-105"></a>
## 105. rt_dma_phy_iput_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca2f87c1fcb11eebaac0242ac11000c

```c
int rt_dma_phy_iput_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride,
    void    *reply);

```

## 功能介绍
使用物理地址，将SPM存储空间的数据写入到设备内存的指定位置，含跨步操作，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，地址必须4字节对齐。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间物理地址，地址必须4字节对齐。

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


<a id="page-106"></a>
## 106. rt_unaligned_dma_put()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca45a821fcb11eebaac0242ac11000c

```c
void rt_unaligned_dma_put(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
支持地址非对齐情况下，将SPM存储空间的数据写入到设备内存的指定位置，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，无任何对齐要求。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，无任何对齐要求。

 |
len

 | 输入

 | DMA传输数据量，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |

## 返回值
暂无明确含义。


<a id="page-107"></a>
## 107. rt_unaligned_dma_put_stride()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bca600621fcb11eebaac0242ac11000c

```c
void rt_unaligned_dma_put_stride(
    void    *dest,
    void    *src,
    int     len,
    int     bsize,
    int     stride);

```

## 功能介绍
支持地址非对齐情况下，将SPM存储空间的数据写入到设备内存的指定位置，含跨步操作，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | DMA传输设备内存地址，无任何对齐要求。

 |
src

 | 输入

 | DMA传输当前SPE的SPM存储空间地址，无任何对齐要求。

 |
len

 | 输入

 | DMA传输数据量，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |
bsize

 | 输入

 | 跨步向量块大小，以字节为单位，可为不超过SPM存储空间大小的任意整数。

 |
stride

 | 输入

 | 设备内存跨步，以字节为单位， 可为任意整数。

 |

## 返回值
暂无明确含义。


<a id="page-108"></a>
