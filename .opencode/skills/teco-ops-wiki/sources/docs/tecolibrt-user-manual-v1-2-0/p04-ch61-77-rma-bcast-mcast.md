---
id: doc-tecolibrt-user-manual-v1-2-0-p04
title: "TecoLIBRT 用户手册 v1.2.0 — 第4部分 (ch61-77-rma-bcast-mcast)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "2755-3797"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, rma, broadcast, multicast, rt-rma-bcast-other, rt-rma-col-mcast, rt-rma-row-mcast, sdaa, teco-t1]
---

## 61. 广播发起的SPE不接收广播数据
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc59e0561fcb11eebaac0242ac11000c

rt_rma_bcast_other()rt_rma_col_bcast_other()rt_rma_col_ibcast_other()rt_rma_row_bcast_other()rt_rma_row_ibcast_other()rt_rma_col_bcast_coll_other()rt_rma_row_bcast_coll_other()


<a id="page-62"></a>
## 62. rt_rma_bcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc5bf65c1fcb11eebaac0242ac11000c

```c
int rt_rma_bcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
RMA广播数据给所有计算核心SPE（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-63"></a>
## 63. rt_rma_col_bcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc5e66f81fcb11eebaac0242ac11000c

```c
int rt_rma_col_bcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
RMA列广播数据，由特定计算核心SPE发起，同一列上所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-64"></a>
## 64. rt_rma_col_ibcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc60d7f81fcb11eebaac0242ac11000c

```c
int rt_rma_col_ibcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    void    *r_rply);

```

## 功能介绍
RMA列广播数据，由特定计算核心SPE发起，同一列上所有SPE接收数据（当前SPE不接收数据），非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-65"></a>
## 65. rt_rma_row_bcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc62ac9a1fcb11eebaac0242ac11000c

```c
int rt_rma_row_bcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
RMA行广播数据，由特定计算核心SPE发起，同一行上所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-66"></a>
## 66. rt_rma_row_ibcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc651eee1fcb11eebaac0242ac11000c

```c
int rt_rma_row_ibcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    void    *r_rply);

```

## 功能介绍
RMA行广播数据，由特定计算核心SPE发起，同一行上所有SPE接收数据（当前SPE不接收数据），非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-67"></a>
## 67. rt_rma_col_bcast_coll_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc678e721fcb11eebaac0242ac11000c

```c
int rt_rma_col_bcast_coll_other(
    void    *dst,
    void    *src,
    int     len,
    int     root);

```

## 功能介绍
RMA列广播数据，由指定行上的计算核心SPE发起，同一列上所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
root

 | 输入

 | 指定发起RMA广播的计算核心SPE所在的目标行。

 |

## 返回值
暂无明确含义。


<a id="page-68"></a>
## 68. rt_rma_row_bcast_coll_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc6967061fcb11eebaac0242ac11000c

```c
int rt_rma_row_bcast_coll_other(
    void    *dst,
    void    *src,
    int     len,
    int     root);

```

## 功能介绍
RMA行广播数据，由指定列上的计算核心SPE发起，同一行上所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
root

 | 输入

 | 指定发起RMA广播的计算核心SPE所在的目标列。

 |

## 返回值
暂无明确含义。


<a id="page-69"></a>
## 69. 行/列多播
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc6a157a1fcb11eebaac0242ac11000c

rt_rma_col_mcast()rt_rma_col_imcast()rt_rma_col_mcast_other()rt_rma_col_imcast_other()rt_rma_row_mcast()rt_rma_row_imcast()rt_rma_row_mcast_other()rt_rma_row_imcast_other()


<a id="page-70"></a>
## 70. rt_rma_col_mcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc6c784c1fcb11eebaac0242ac11000c

```c
int rt_rma_col_mcast(
    void    *dst,
    void    *src,
    int     len,
    int     r_cols_mask,
    void    *r_rply);

```

## 功能介绍
RMA列多播数据，由特定计算核心SPE发起，指定多列上的所有SPE接收数据，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_cols_mask

 | 输入

 | 参与多播的列。某位为1，表示对应的列参与多播，仅低8位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-71"></a>
## 71. rt_rma_col_imcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc6e4b361fcb11eebaac0242ac11000c

```c
int rt_rma_col_imcast(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    int     r_cols_mask,
    void    *r_rply);

```

## 功能介绍
RMA列多播数据，由特定计算核心SPE发起，指定多列上的所有SPE接收数据，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_cols_mask

 | 输入

 | 参与多播的列。某位为1，表示对应的列参与多播，仅低8位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-72"></a>
## 72. rt_rma_col_mcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc700f8e1fcb11eebaac0242ac11000c

```c
int rt_rma_col_mcast_other(
    void    *dst,
    void    *src,
    int     len,
    int     r_cols_mask,
    void    *r_rply);

```

## 功能介绍
RMA列多播数据，由特定计算核心SPE发起，指定多列上的所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_cols_mask

 | 输入

 | 参与多播的列。某位为1，表示对应的列参与多播，仅低8位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-73"></a>
## 73. rt_rma_col_imcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc71e0fc1fcb11eebaac0242ac11000c

```c
int rt_rma_col_imcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    int     r_cols_mask,
    void    *r_rply);

```

## 功能介绍
RMA列多播数据，由特定计算核心SPE发起，指定多列上的所有SPE接收数据（当前SPE不接收数据），非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_cols_mask

 | 输入

 | 参与多播的列。某位为1，表示对应的列参与多播，仅低8位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-74"></a>
## 74. rt_rma_row_mcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc738b0a1fcb11eebaac0242ac11000c

```c
int rt_rma_row_mcast(
    void    *dst,
    void    *src,
    int     len,
    int     r_rows_mask,
    void    *r_rply);

```

## 功能介绍
RMA行多播数据，由特定计算核心SPE发起，指定多行上的所有SPE接收数据，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_rows_mask

 | 输入

 | 参与多播的行。某位为1，表示对应的行参与多播，仅低4位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-75"></a>
## 75. rt_rma_row_imcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7553f41fcb11eebaac0242ac11000c

```c
int rt_rma_row_imcast(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    int     r_rows_mask,
    void    *r_rply);

```

## 功能介绍
RMA行多播数据，由特定计算核心SPE发起，指定多行上的所有SPE接收数据，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_rows_mask

 | 输入

 | 参与多播的行。某位为1，表示对应的行参与多播，仅低4位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-76"></a>
## 76. rt_rma_row_mcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc7703661fcb11eebaac0242ac11000c

```c
int rt_rma_row_mcast_other(
    void    *dst,
    void    *src,
    int     len,
    int     r_rows_mask,
    void    *r_rply);

```

## 功能介绍
RMA行多播数据，由特定计算核心SPE发起，指定多行上的所有SPE接收数据（当前SPE不接收数据），阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_rows_mask

 | 输入

 | 参与多播的行。某位为1，表示对应的行参与多播，仅低4位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-77"></a>
## 77. rt_rma_row_imcast_other()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc78c8541fcb11eebaac0242ac11000c

```c
int rt_rma_row_imcast_other(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    int     r_rows_mask,
    void    *r_rply);

```

## 功能介绍
RMA行多播数据，由特定计算核心SPE发起，指定多行上的所有SPE接收数据（当前SPE不接收数据），非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dst

 | 输入

 | RMA广播目标SPE的SPM存储空间地址，地址必须4字节对齐。

 |
src

 | 输入

 | RMA广播当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
r_rows_mask

 | 输入

 | 参与多播的行。某位为1，表示对应的行参与多播，仅低4位有效，详见核心概念中的掩码介绍。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-78"></a>
