---
id: doc-tecolibrt-user-manual-v1-2-0-p02
title: "TecoLIBRT 用户手册 v1.2.0 — 第2部分 (ch14-33-ace-matmul-sync)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "810-1475"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, ace, matmul, rt-ace-config-kernel, rt-ace-load-north, rt-ace-load-west, rt-ace-writeback, rt-ace-north-count, rt-ace-west-count, rt-wait-north, rt-wait-west, rt-synchronized-array, spe-sync, sdaa, teco-t1]
---

## 14. 计算接口
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2610f01fcb11eebaac0242ac11000c

SPE间同步矩阵乘法远程访问SPM时间统计


<a id="page-15"></a>
## 15. SPE间同步
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc26b5781fcb11eebaac0242ac11000c

rt_synchronized_array()rt_synchronized_col()rt_synchronized_row()rt_synchronized_peer()rt_synchronized_col_p2p()rt_synchronized_row_p2p()rt_synchronized_col_lefthalf()rt_synchronized_col_righthalf()


<a id="page-16"></a>
## 16. rt_synchronized_array()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc278c501fcb11eebaac0242ac11000c

```c
int rt_synchronized_array();

```

## 功能介绍
全阵列同步，同步全部32个计算核心SPE。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-17"></a>
## 17. rt_synchronized_col()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc286a621fcb11eebaac0242ac11000c

```c
int rt_synchronized_col();

```

## 功能介绍
列同步，同步同一列上所有计算核心SPE。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-18"></a>
## 18. rt_synchronized_row()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2940221fcb11eebaac0242ac11000c

```c
int rt_synchronized_row();

```

## 功能介绍
行同步，同步同一行上所有计算核心SPE。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-19"></a>
## 19. rt_synchronized_peer()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2a59301fcb11eebaac0242ac11000c

```c
int rt_synchronized_peer(
    int     tid);

```

## 功能介绍
点对点同步，同步当前计算核心SPE与指定SPE。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
tid

 | 输入

 | 设置与当前SPE进行同步的SPE编号，二进制低5位有效，左两位表示SPE的行号，右三位表示SPE的列号。例如：在`01001`中，`01`表示行号，`001`表示列号，即指定编号为9的SPE与当前SPE进行同步。

 |

## 返回值
暂无明确含义。


<a id="page-20"></a>
## 20. rt_synchronized_col_p2p()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2b75c21fcb11eebaac0242ac11000c

```c
int rt_synchronized_col_p2p(
    int     row_ssync_mask);

```

## 功能介绍
同步同一列中，由掩码参数指定的所有计算核心SPE。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
row_ssync_mask

 | 输入

 | 设置参与同步的计算核心SPE行号掩码，仅低4位有效。若某位为1，表示该列对应行上的计算核心SPE参与同步，详见核心概念中的掩码介绍。

 |

## 返回值
暂无明确含义。


<a id="page-21"></a>
## 21. rt_synchronized_row_p2p()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2c87501fcb11eebaac0242ac11000c

```c
int rt_synchronized_row_p2p(
    int     col_ssync_mask);

```

## 功能介绍
同步同一行中，由掩码参数指定的所有计算核心SPE。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
col_ssync_mask

 | 输入

 | 设置参与同步的计算核心SPE列号掩码，仅低8位有效。若某位为1，表示该行对应列上的SPE参与同步，详见核心概念中的掩码介绍。

 |

## 返回值
暂无明确含义。


<a id="page-22"></a>
## 22. rt_synchronized_col_lefthalf()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2d60261fcb11eebaac0242ac11000c

```c
int rt_synchronized_col_lefthalf();

```

## 功能介绍
同步列号为0~3的所有计算核心SPE，即计算阵列SPA的左半区。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-23"></a>
## 23. rt_synchronized_col_righthalf()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2e44e61fcb11eebaac0242ac11000c

```c
int rt_synchronized_col_righthalf();

```

## 功能介绍
同步列号为4~7的所有计算核心SPE，即计算阵列SPA的右半区。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-24"></a>
## 24. 矩阵乘法
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2ee6bc1fcb11eebaac0242ac11000c

rt_ace_config_kernel()rt_ace_load_north()rt_ace_load_west()rt_ace_writeback()rt_ace_barrier_kernel()rt_ace_north_count()rt_ace_west_count()rt_wait_north()rt_wait_west()


<a id="page-25"></a>
## 25. rt_ace_config_kernel()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc2ffc141fcb11eebaac0242ac11000c

```c
int rt_ace_config_kernel(
    ACE_CONFIG         Comptype);

```

## 功能介绍
配置脉动阵列常用的参数，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Comptype

 | 输入

 | 选择计算加速引擎内的操作种类。

- 1：`_Float16`。

- 2：`int16`。

- 4：`int8`。

 |

## 返回值
暂无明确含义。


<a id="page-26"></a>
## 26. rt_ace_load_north()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc33418a1fcb11eebaac0242ac11000c

```c
int rt_ace_load_north(
    void    *Waddr,
    int     Loadstride);

```

## 功能介绍
加载北向数据，通常为矩阵A∗BA*BA∗B中的矩阵BBB，非阻塞式。

## 注意事项
北向数据矩阵大小限制为32*32。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Waddr

 | 输入

 | 当前SPE的SPM存储空间起始访问地址，地址必须64字节对齐。

 |
Loadstride

 | 输入

 | 访问北向数据的掩码，一般设为0，表示32行矩阵全部加载。

 |

## 返回值
暂无明确含义。


<a id="page-27"></a>
## 27. rt_ace_load_west()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3536a21fcb11eebaac0242ac11000c

```c
int rt_ace_load_west(
    void    *Xaddr,
    int     Accumaddr,
    int     Accumflag,
    int     Xsize,
    int     Loadstride,
    int     Lastflag,
    int     Precision,
    int     Northflag);

```

## 功能介绍
加载西向数据，通常为矩阵A∗BA*BA∗B中的矩阵AAA，非阻塞式。

## 注意事项
西向数据矩阵大小限制为(≤128) * 32。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Xaddr

 | 输入

 | 当前SPE的SPM存储空间起始访问地址，地址必须64字节对齐。

 |
Accumaddr

 | 输入

 | 计算结果累加器缓冲写入的矩阵起始地址，单位：行，取值范围：0~127，0表示第0行。

 |
Accumflag

 | 输入

 | 是否更新起始写入地址。

- 0：表示紧跟在前一次计算结果之后写入，此时显式设置的地址无效。若前一次结果写入已经到达累加缓冲器的最后位置，则下一次加载西向数据必须显式设置累加器缓冲的起始写入地址，否则会产生不可预知的结果。

- 1：表示累加器写入起始地址为Accumaddr指定的值。

 |
Xsize

 | 输入

 | 西向数据量，即累加器更新条目，取值范围：1~128。

 |
Loadstride

 | 输入

 | 数据加载跨步，跨步向量块大小为64字节，0表示一个跨步。

 |
Lastflag

 | 输入

 | 累加结束标志，即：是否为最后一次计算。

- 0：表示累加尚未结束。

- 1：表示累加结束，切换累加器缓冲区。

 |
Precision

 | 输入

 | 仅在rt_ace_config_kernel()配置为int8时有效，用于选择高位还是低位参与累加运算。在其余数据类型配置下，该位失效。

- 0：表示低位参与运算。

- 1：表示高位参与运算。

 |
Northflag

 | 输入

 | 是否需要更新北向数据。

- 0：表示不切换北向数据缓冲区。

- 1：表示切换北向数据缓冲区。

 |

## 返回值
暂无明确含义。


<a id="page-28"></a>
## 28. rt_ace_writeback()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc368f481fcb11eebaac0242ac11000c

```c
int rt_ace_writeback(
    void        *Yaddr,
    int         Ysize,
    void        *Yrply,
    ACE_PREC    Precisionflag);
```

## 功能介绍
将累加结果写回SPE的SPM存储空间，非阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
Yaddr

 | 输入

 | 当前SPE的SPM存储空间起始访问地址，地址必须64字节对齐。

 |
Ysize

 | 输入

 | 表示128条目中，需要写回的条目数，0表示128个条目全部写回。每个条目为一整行，即64字节数据。

 |
Yrply

 | 输入

 | 回答字地址，地址必须4字节对齐。

 |
Precisionflag

 | 输出

 | 累加结果写回精度。

- 0：表示按照16位结果写回。

- 1：表示按照32位结果写回。

 |

## 返回值
暂无明确含义。


<a id="page-29"></a>
## 29. rt_ace_barrier_kernel()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bc3773fe1fcb11eebaac0242ac11000c

```c
int rt_ace_barrier_kernel();

```

## 功能介绍
累加结果写回栏栅，保证在累加器中的值对所有线程可见，防止对该值的重排序，阻塞式。

## 注意事项
无。

## 参数解释
无。

## 返回值
暂无明确含义。


<a id="page-30"></a>
## 30. rt_ace_north_count()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#11ba42b279ee11eeb4c00242ac110008

```c
int rt_ace_north_count();

```

## 功能介绍
获取北向数据完成加载次数。

## 注意事项
无。

## 参数解释
无。

## 返回值
北向数据完成加载次数。


<a id="page-31"></a>
## 31. rt_ace_west_count()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#b708241479ee11eebca50242ac110008

```c
int rt_ace_west_count();

```

## 功能介绍
获取西向数据完成加载次数。

## 注意事项
无。

## 参数解释
无。

## 返回值
西向数据完成加载次数。


<a id="page-32"></a>
## 32. rt_wait_north()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#f17e649679ee11eebca50242ac110008

```c
int rt_wait_north(end, start);

```

## 功能介绍
等待北向数据加载完成。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
end

 | 输入

 | 北向数据完成加载次数， 由rt_ace_north_count()获得。

 |
start

 | 输入

 | 发起北向数据加载指令次数。

 |

## 返回值
暂无明确含义。


<a id="page-33"></a>
## 33. rt_wait_west()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#43b1d55879f011eebca50242ac110008

```c
int rt_wait_west(end, start);

```

## 功能介绍
等待西向数据加载完成。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
end

 | 输入

 | 西向数据完成加载次数， 由rt_ace_west_count()获得。

 |
start

 | 输入

 | 发起西向数据加载指令次数。

 |

## 返回值
暂无明确含义。


<a id="page-34"></a>
