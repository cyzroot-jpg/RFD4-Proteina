---
id: doc-tecolibrt-user-manual-v1-2-0-p03
title: "TecoLIBRT 用户手册 v1.2.0 — 第3部分 (ch34-60-rma-remote-bcast)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "1476-2754"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, rma, remote-spm, rt-remote-load, rt-rma, rt-rma-get, rt-rma-iget, rt-rma-put, rt-rma-iput, rt-rma-bcast, rt-rma-ibcast, rt-rma-col-ibcast, broadcast, sdaa, teco-t1]
---

## 34. 远程访问SPM
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3813901fcb11eebaac0242ac11000c

rt_remote_load()rt_remote_store()


<a id="page-35"></a>
## 35. rt_remote_load()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3959bc1fcb11eebaac0242ac11000c

```c
void rt_remote_load(
    void    var,
    int     remote_core_id,
    void    *r_ptr);

```

## 功能介绍
从目标计算核心SPE的指定SPM存储空间上加载数据，阻塞式。

## 前提条件
必须保证当前计算核心SPE与目标计算核心SPE都申请了该SPM存储空间。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
var

 | 输出

 | 加载数据值。

 |
remote_core_id

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_ptr

 | 输入

 | 目标SPE的SPM存储空间地址。

 |

## 返回值
暂无明确含义。


<a id="page-36"></a>
## 36. rt_remote_store()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3aa8d01fcb11eebaac0242ac11000c

```c
void rt_remote_store(
    void    val,
    int     remote_core_id,
    void    *r_ptr);

```

## 功能介绍
在目标计算核心SPE的指定SPM存储空间上存储数据，阻塞式。

## 前提条件
必须保证当前计算核心SPE与目标计算核心SPE都申请了该SPM存储空间。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
val

 | 输入

 | 存储数据值。

 |
remote_core_id

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_ptr

 | 输入

 | 目标SPE的SPM存储空间地址。

 |

## 返回值
暂无明确含义。


<a id="page-37"></a>
## 37. 时间统计
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3b48bc1fcb11eebaac0242ac11000c

rt_time_cycle()


<a id="page-38"></a>
## 38. rt_time_cycle()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3c1ad01fcb11eebaac0242ac11000c

```c
unsigned long rt_time_cycle();

```

## 功能介绍
获取计算核心SPE的时间周期，与C标准库(time.h)中clock()函数对应，阻塞式。

## 注意事项
无。

## 参数解释
无。

## 返回值
计算核心SPE的周期数。


<a id="page-39"></a>
## 39. SPE间通信
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3cc4081fcb11eebaac0242ac11000c

通用接口数据读取数据写出广播操作


<a id="page-40"></a>
## 40. 通用接口
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3d65481fcb11eebaac0242ac11000c

rt_rma()rt_rma_wait_value()rt_memcpy()rt_memmove()


<a id="page-41"></a>
## 41. rt_rma()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3f98fe1fcb11eebaac0242ac11000c

```c
int rt_rma(
    rma_mode        Mode,
    rma_op          Op,
    void            *Remote_ldm_ddr,
    void            *Ldm_addr,
    int             Len,
    void            *Remote_rrply,
    void            *Rrply,
    int             Bcast_mask,
    int             Remote_id);

```

## 功能介绍
在同一计算核心阵列SPA内，在当前SPE指定的SPM存储空间和远端SPE指定的SPM存储空间传输数据，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Mode

 | 输入

 | RMA传输命令模式。

- `0x0`：单计算核心SPE模式。

- `0x1`：行多播模式（当前SPE不接收数据）。

- `0x2`：列多播模式（当前SPE不接收数据）。

- `0x5`：行多播模式。

- `0x6`：列多播模式。

 |
Op

 | 输入

 | RMA传输命令操作码。

- `0x0`：表示数据写出，从当前SPE传输数据到远端SPE。

- `0x1`：表示数据读取，从远端SPE传输数据到当前SPE。

 |
Remote_ldm_ddr

 | 输入

 | 数据搬运的目的地址，远端SPE的SPM存储空间地址，地址必须4字节对齐。

 |
Ldm_addr

 | 输入

 | 数据搬运的源地址，当前SPE的SPM存储空间地址，地址必须4字节对齐。

 |
Len

 | 输入

 | RMA传输数据量，单位：字节。

 |
Remote_rrply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |
Rrply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
Bcast_mask

 | 输入

 | 用于选择参与多播的行/列。

- 行多播时，用于选择参与多播的行，仅低4位有效。

- 列多播时，用于选择参与多播的列，仅低8位有效。

具体选择方式如下，详见核心概念中的掩码介绍。

- 某位为1，表示对应的行/列参与多播。

- 某位为0，表示对应的行/列不参与多播。

 |
Remote_id

 | 输入

 | 远端计算核心SPE的编号（0~31）。仅`mode`为0x0，即单SPE模式下有效。

 |

## 返回值
暂无明确含义。


<a id="page-42"></a>
## 42. rt_rma_wait_value()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc40c0941fcb11eebaac0242ac11000c

```c
int rt_rma_wait_value(
    void    *reply,
    int     value);

```

## 功能介绍
等待RMA数据搬运结束，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
reply

 | 输入

 | RMA传输回答字的地址，地址必须4字节对齐。

 |
value

 | 输入

 | RMA传输完成时，回答字的目标值。

 |

## 返回值
暂无明确含义。


<a id="page-43"></a>
## 43. rt_memcpy()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc41f9f01fcb11eebaac0242ac11000c

```c
void rt_memcpy(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
支持大数据量，地址不对齐情况下，同一个计算核心SPE内的数据复制操作。

## 注意事项
不支持SPM存储空间内存重叠的情况。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | 数据复制的目标SPM存储空间地址。

 |
src

 | 输入

 | 数据复制的源SPM存储空间地址。

 |
len

 | 输入

 | 待复制的数据量，单位：字节。

 |

## 返回值
暂无明确含义。


<a id="page-44"></a>
## 44. rt_memmove()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4334dc1fcb11eebaac0242ac11000c

```c
void rt_memmove(
    void    *dest,
    void    *src,
    int     len);

```

## 功能介绍
支持大数据量，地址不对齐情况下，同一个计算核心SPE内的数据移动操作。

## 注意事项
能够处理SPM存储空间内存重叠的问题。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
dest

 | 输入

 | 数据移动的源SPM存储空间地址。

 |
src

 | 输入

 | 数据移动的目标SPM存储空间地址。

 |
len

 | 输入

 | 待移动的数据量，单位：字节。

 |

## 返回值
暂无明确含义。


<a id="page-45"></a>
## 45. 数据读取
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc43e3e61fcb11eebaac0242ac11000c

rt_rma_get()rt_rma_iget()


<a id="page-46"></a>
## 46. rt_rma_get()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc455ab41fcb11eebaac0242ac11000c

```c
int rt_rma_get(
    void    *l_addr,
    int     len,
    int     r_tid,
    void    *r_addr,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将远端计算核心SPE中指定的SPM存储数据以阻塞的方式搬运到当前计算核心SPE中指定的SPM存储空间内。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
l_addr

 | 输入

 | 数据搬运的目的地址，当前计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_tid

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_addr

 | 输入

 | 数据搬运的源地址，远端计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-47"></a>
## 47. rt_rma_iget()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc46f1261fcb11eebaac0242ac11000c

```c
int rt_rma_iget(
    void    *l_addr,
    void    *l_rply,
    int     len,
    int     r_tid,
    void    *r_addr,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将远端计算核心SPE中指定的SPM存储数据以非阻塞的方式搬运到当前计算核心SPE中指定的SPM存储空间内。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
l_addr

 | 输入

 | 数据搬运的目的地址，当前计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_tid

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_addr

 | 输入

 | 数据搬运的源地址，远端计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-48"></a>
## 48. 数据写出
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc47a1d41fcb11eebaac0242ac11000c

rt_rma_put()rt_rma_iput()


<a id="page-49"></a>
## 49. rt_rma_put()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc493b981fcb11eebaac0242ac11000c

```c
int rt_rma_put(
    void    *l_addr,
    int     len,
    int     r_tid,
    void    *r_addr,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将当前计算核心SPE中指定的SPM存储数据以阻塞的方式搬运到远端计算核心SPE中指定的SPM存储空间内。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
l_addr

 | 输入

 | 数据搬运的源地址，当前计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_tid

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_addr

 | 输入

 | 数据搬运的目的地址，远端计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-50"></a>
## 50. rt_rma_iput()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4adb241fcb11eebaac0242ac11000c

```c
int rt_rma_iput(
    void    *l_addr,
    void    *l_rply,
    int     len,
    int     r_tid,
    void    *r_addr,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将当前计算核心SPE中指定的SPM存储数据以非阻塞的方式搬运到远端计算核心SPE中指定的SPM存储空间内。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
l_addr

 | 输入

 | 数据搬运的源地址，当前计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

 |
len

 | 输入

 | RMA传输数据量，单位：字节，需为4的整数倍。

 |
r_tid

 | 输入

 | 目标计算核心SPE的编号（0~31）。

 |
r_addr

 | 输入

 | 数据搬运的目的地址，远端计算核心的SPM存储空间地址，地址必须4字节对齐。

 |
r_rply

 | 输入

 | RMA远程传输回答字地址，地址必须4字节对齐。

 |

## 返回值
暂无明确含义。


<a id="page-51"></a>
## 51. 广播操作
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4b88e41fcb11eebaac0242ac11000c

广播发起的SPE接收广播数据广播发起的SPE不接收广播数据行/列多播


<a id="page-52"></a>
## 52. 广播发起的SPE接收广播数据
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4c2d9e1fcb11eebaac0242ac11000c

rt_rma_bcast()rt_rma_ibcast()rt_rma_col_bcast()rt_rma_col_ibcast()rt_rma_row_bcast()rt_rma_row_ibcast()rt_rma_col_bcast_coll()rt_rma_row_bcast_coll()


<a id="page-53"></a>
## 53. rt_rma_bcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4da0f21fcb11eebaac0242ac11000c

```c
int rt_rma_bcast(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将发送方计算核心SPE中指定的SPM存储数据以阻塞的方式搬运到SPA内所有SPE。

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


<a id="page-54"></a>
## 54. rt_rma_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc4f37a01fcb11eebaac0242ac11000c

```c
int rt_rma_ibcast(
    void    *dst,
    void    *src,
    void    *l_rply,
    int     len,
    void    *r_rply);

```

## 功能介绍
在同一计算核心阵列SPA内，将发送方计算核心SPE中指定的SPM存储数据以非阻塞的方式搬运到SPA内所有SPE。

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
l_rply

 | 输入

 | RMA当前传输回答字地址，地址必须4字节对齐。

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


<a id="page-55"></a>
## 55. rt_rma_col_bcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc50ac2a1fcb11eebaac0242ac11000c

```c
int rt_rma_col_bcast(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
RMA列广播数据，由特定计算核心SPE发起，同一列上所有SPE接收数据，阻塞式。

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


<a id="page-56"></a>
## 56. rt_rma_col_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc5242561fcb11eebaac0242ac11000c

```c
int rt_rma_col_ibcast(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    void    *r_rply);

```

## 功能介绍
RMA列广播数据，由特定计算核心SPE发起，同一列上所有SPE接收数据，非阻塞式。

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


<a id="page-57"></a>
## 57. rt_rma_row_bcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc53ba961fcb11eebaac0242ac11000c

```c
int rt_rma_row_bcast(
    void    *dst,
    void    *src,
    int     len,
    void    *r_rply);

```

## 功能介绍
RMA行广播数据，由特定计算核心SPE发起，同一行上所有SPE接收数据，阻塞式。

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


<a id="page-58"></a>
## 58. rt_rma_row_ibcast()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc55d4b61fcb11eebaac0242ac11000c

```c
int rt_rma_row_ibcast(
    void    *dst,
    void    *src,
    int     len,
    void    *l_rply,
    void    *r_rply);

```

## 功能介绍
RMA行广播数据，由特定计算核心SPE发起，同一行上所有SPE接收数据，非阻塞式。

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


<a id="page-59"></a>
## 59. rt_rma_col_bcast_coll()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc579ed61fcb11eebaac0242ac11000c

```c
int rt_rma_col_bcast_coll(
    void    *dst,
    void    *src,
    int     len,
    int     root);

```

## 功能介绍
RMA列广播数据，由指定行上的计算核心SPE发起，同一列上所有SPE接收数据，阻塞式。

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


<a id="page-60"></a>
## 60. rt_rma_row_bcast_coll()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc59229c1fcb11eebaac0242ac11000c

```c
int rt_rma_row_bcast_coll(
    void    *dst,
    void    *src,
    int     len,
    int     root);

```

## 功能介绍
RMA行广播数据，由指定列上的计算核心SPE发起，同一行上所有SPE接收数据，阻塞式。

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


<a id="page-61"></a>
