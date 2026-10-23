---
id: doc-tecolibrt-user-manual-v1-2-0-p07
title: "TecoLIBRT 用户手册 v1.2.0 — 第7部分 (ch124-145-reduce-check-print)"
type: source-doc-part
parent_doc: doc-tecolibrt-user-manual-v1-2-0
product_version: "v1.2.0"
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
raw_line_range: "6322-7565"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecolibrt, reduce, rt-rma-allreduce, rt-rma-reduce, rt-rma-col-reduce, check, print, rt-log, rt-warning, rt-align-n, faq, sdaa, teco-t1]
---

## 124. 规约操作
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcbf3cc61fcb11eebaac0242ac11000c

rt_rma_allreduce()rt_rma_reduce()rt_rma_allreduce_to()rt_rma_col_reduce()rt_rma_col_reduce_to()rt_rma_row_reduce()rt_rma_row_reduce_to()


<a id="page-125"></a>
## 125. rt_rma_allreduce()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcc161c21fcb11eebaac0242ac11000c

```c
void rt_rma_allreduce(
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，所有SPE上的数据做累加，并在32个SPE上更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
data

 | 输入/输出

 | 执行全阵列规约的32个SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于计算核心之间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行全阵列规约的数据个数。

 |
type

 | 输入

 | 执行全阵列规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-126"></a>
## 126. rt_rma_reduce()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcc2f8f21fcb11eebaac0242ac11000c

```c
void rt_rma_reduce(
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，所有SPE上的数据做累加，在0号SPE上更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
data

 | 输入/输出

 | 执行全阵列规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行全阵列规约的数据个数。

 |
type

 | 输入

 | 执行全阵列规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-127"></a>
## 127. rt_rma_allreduce_to()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcc4b0e81fcb11eebaac0242ac11000c

```c
void rt_rma_allreduce_to(
    int         core_id,
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，所有SPE上的数据做累加，并在指定SPE上更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
core_id

 | 输入

 | 更新累加结果的目标SPE编号（0~31）。

 |
data

 | 输入/输出

 | 执行全阵列规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行全阵列规约的数据个数。

 |
type

 | 输入

 | 执行全阵列规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-128"></a>
## 128. rt_rma_col_reduce()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcc6c48c1fcb11eebaac0242ac11000c

```c
void rt_rma_col_reduce(
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，将与当前SPE同一列上所有SPE的数据做累加，在该列第0行上的SPE更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
data

 | 输入/输出

 | 执行列规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行列规约的数据个数。

 |
type

 | 输入

 | 执行列规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-129"></a>
## 129. rt_rma_col_reduce_to()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcc873cc1fcb11eebaac0242ac11000c

```c
void rt_rma_col_reduce_to(
    int         core_id,
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，将与当前SPE同一列上所有SPE的数据做累加，在指定SPE上更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
core_id

 | 输入

 | 更新累加结果的目标SPE的行号（0~3）。

 |
data

 | 输入/输出

 | 执行列规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行列规约的数据个数。

 |
type

 | 输入

 | 执行列规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-130"></a>
## 130. rt_rma_row_reduce()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcca6d081fcb11eebaac0242ac11000c

```c
void rt_rma_row_reduce(
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，将与当前SPE同一行上所有SPE的数据做累加，在该行第0列上的SPE更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
data

 | 输入/输出

 | 执行行规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行行规约的数据个数。

 |
type

 | 输入

 | 执行行规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-131"></a>
## 131. rt_rma_row_reduce_to()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bccbf7041fcb11eebaac0242ac11000c

```c
void rt_rma_row_reduce_to(
    int         core_id,
    void        *data,
    void        *buf,
    int         len,
    RED_TYPE    type);

```

## 功能介绍
对一个计算核心阵列SPA内，将与当前SPE同一行上所有SPE的数据做累加，在指定SPE上更新累加结果，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
core_id

 | 输入

 | 更新累加结果的目标SPE的列号（0~7）。

 |
data

 | 输入/输出

 | 执行行规约的当前SPE的SPM地址，地址必须4字节对齐。内存空间大小应不大于buf。

 |
buf

 | 输入

 | 用于核间通信的当前SPE的SPM缓存地址，地址必须4字节对齐。内存空间大小应不小于data。

 |
len

 | 输入

 | 执行行规约的数据个数。

 |
type

 | 输入

 | 执行行规约的数据类型，具体如下：

RED_TYPE取值

 | 说明

 |
`FLOAT_TYPE`

 | 单精度浮点数

 |
`HALF_TYPE`

 | 半精度浮点数

 |
`INT_TYPE`

 | 整数

 |
`UINT_TYPE`

 | 无符号整数

 |
`SHORT_TYPE`

 | 短整数

 |
`USHORT_TYPE`

 | 无符号短整数

 |
 |

## 返回值
暂无明确含义。


<a id="page-132"></a>
## 132. 检查与打印
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bccca5781fcb11eebaac0242ac11000c

检查接口打印接口


<a id="page-133"></a>
## 133. 检查接口
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bccd48ca1fcb11eebaac0242ac11000c

rt_align_n()rt_equal_f()rt_nequal_f()rt_equal_zero_f()rt_nequal_zero_f()


<a id="page-134"></a>
## 134. rt_align_n()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcceb9581fcb11eebaac0242ac11000c

```c
int rt_align_n(
    void    *v,
    int     n);

```

## 功能介绍
判断地址是否按照指定要求对齐，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
v

 | 输入

 | 待检查地址。

 |
n

 | 输入

 | 地址对齐的长度。

 |

## 返回值
名称

 | 说明

 |
1

 | 满足地址对齐要求。

 |
0

 | 不满足地址对齐要求。

 |


<a id="page-135"></a>
## 135. rt_equal_f()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd01ece1fcb11eebaac0242ac11000c

```c
int rt_equal_f(
    float   a,
    float   b);

```

## 功能介绍
判断浮点数a, b是否相等。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
a

 | 输入

 | 待比较的浮点数。

 |
b

 | 输入

 | 待比较的浮点数。

 |

## 返回值
名称

 | 说明

 |
1

 | a, b相等。

 |
0

 | a, b不相等。

 |


<a id="page-136"></a>
## 136. rt_nequal_f()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd17ddc1fcb11eebaac0242ac11000c

```c
int rt_nequal_f(
    float   a,
    float   b);

```

## 功能介绍
判断浮点数a, b是否不相等。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
a

 | 输入

 | 待比较的浮点数。

 |
b

 | 输入

 | 待比较的浮点数。

 |

## 返回值
名称

 | 说明

 |
1

 | a, b不相等。

 |
0

 | a, b相等。

 |


<a id="page-137"></a>
## 137. rt_equal_zero_f()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd2bea41fcb11eebaac0242ac11000c

```c
int rt_equal_zero_f(
    float   a);

```

## 功能介绍
判断浮点数a是否为0。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
a

 | 输入

 | 待判断的浮点数。

 |

## 返回值
名称

 | 说明

 |
1

 | a等于0。

 |
0

 | a不等于0。

 |


<a id="page-138"></a>
## 138. rt_nequal_zero_f()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd512bc1fcb11eebaac0242ac11000c

```c
int rt_nequal_zero_f(
    float   a);

```

## 功能介绍
判断浮点数a是否不为0。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
a

 | 输入

 | 待判断的浮点数。

 |

## 返回值
名称

 | 说明

 |
1

 | a不等于0。

 |
0

 | a等于0。

 |


<a id="page-139"></a>
## 139. 打印接口
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd5abf01fcb11eebaac0242ac11000c

rt_log()rt_log_if()rt_warning()rt_warning_if()


<a id="page-140"></a>
## 140. rt_log()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd6b00e1fcb11eebaac0242ac11000c

```c
void rt_log(
    string  format,
    ...);

```

## 功能介绍
打印INFO级日志，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
format

 | 输入

 | 需要打印的内容。

 |

## 返回值
暂无明确含义。


<a id="page-141"></a>
## 141. rt_log_if()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd877041fcb11eebaac0242ac11000c

```c
void rt_log_if(
    string  cond,
    string  format,
    ...);

```

## 功能介绍
当满足指定条件时，打印INFO级日志，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
cond

 | 输入

 | 需要满足的条件。

 |
format

 | 输入

 | 需要打印的内容。

 |

## 返回值
暂无明确含义。


<a id="page-142"></a>
## 142. rt_warning()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcd97e7e1fcb11eebaac0242ac11000c

```c
void rt_warning(
    string  format,
    ...);

```

## 功能介绍
打印ERROR级日志，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
format

 | 输入

 | 需要打印的内容。

 |

## 返回值
暂无明确含义。


<a id="page-143"></a>
## 143. rt_warning_if()
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcdaa2181fcb11eebaac0242ac11000c

```c
void rt_warning_if(
    string  cond,
    string  format,
    ...);

```

## 功能介绍
当满足指定条件时，打印ERROR级日志，阻塞式。

## 注意事项
无。

## 参数解释
名称

 | 输入/输出

 | 说明

 |
cond

 | 输入

 | 需要满足的条件。

 |
format

 | 输入

 | 需要打印的内容。

 |

## 返回值
暂无明确含义。


<a id="page-144"></a>
## 144. 常见问题
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#bcdb4b781fcb11eebaac0242ac11000c

## 矩阵计算类接口常见报错原因
调用矩阵计算接口出现报错时，可以从以下角度排查：

- 西向指令、北向指令不匹配，比如没有指定切换北向的标志。

- 西向指令没有在合适的时候指定切换输出缓冲的标记，导致写回数据失败。

- 数据地址没有64字节对齐。

## 数据传输类接口常见报错原因
进行数据传输过程中出现报错，可以从以下角度排查：

- DMA接口的参数没有4字节对齐。

- RMA接口的参数没有4字节对齐。

- 回答字没有使用C/C++中的`volatile`关键字标识，导致偶发错误。

- 缺少同步指令，导致偶发计算错误。

- 广播操作没有在清零回答字以后同步。


<a id="page-145"></a>
## 145. 版权声明
更新时间：2025-03-06 14:57:17
http://docs.tecorigin.net/release/tecolibrt/v1.2.0/#f1c89eee1fcb11ee90930242ac11000c

本版权声明是太初（无锡）电子科技有限公司（以下简称“太初科技”）关于软件产品（下称“产品”）、编程指南以及软件使用手册的全部版本（包含现有版本及未来更新版本）及与软件产品、编程指南以及软件使用手册全部版本相关的源程序、源代码、示例、模型、场景、数据、域名、结构设计、图标、标志、标识、版面设计、文档资料等以及任何由太初科技基于软件技术维护或支持服务所提供的数据、资料等（下称“产品信息”）做出的法律声明。

## 免责声明
太初科技不就产品和产品信息做出任何担保、条件、陈述和保证（无论是明示的还是默示的，无论是依据成文法、普通法、惯例还是其他任何原因），包括但不限于性能、结果、安全、不侵权、适销性、完整性、准确性、可不受干扰性、可销售品质以及特定用途，太初科技不应对因下列原因产生的任何违约、损害赔偿、费用或问题承担赔偿责任，包括但不限于：

- 用户未按照软件使用手册/指南内容规范使用产品；

- 因用户自身设计问题导致的损失；

- 因用户将软件产品与非太初科技提供的任何其他软件、程序或设备的组合或使用而产生的损失；

- 因电力供应故障、通讯网络故障等公共服务因素或移动通讯终端病毒或黑客攻击、系统不稳定等第三人因素产生的损失；

- 因不可抗力等风险因素（是指不能预见、不能克服并不能避免且对一方或双方造成重大影响的客观事件，包括但不限于自然灾害如洪水、地震、风暴等以及社会事件如战争、动乱、政府行为等。）致使软件产品的使用出现中断或终止而产生的损失；

- 在太初科技已尽善意管理或善意提醒的情况下，因常规或紧急的设备与系统维护、设备与系统故障、网络信息与数据安全等因素产生的损失；

- 因您提供的产品反馈信息侵犯第三方权利致使软件产品侵权而发生的侵权索赔；

- 非因太初科技的原因引起的与软件产品有关的其它损失。

## 责任限制
除法律规定不得排除或限制的赔偿责任外，无论相关责任是基于违约、违反保证、侵权（包括疏忽）、产品责任或任何其他诉讼或责任理论而产生的，太初科技在任何情况下都无需对用户因使用或无法使用产品和产品信息而产生的任何商业损害或间接经济损失承担赔偿责任（包括但不限于商誉损失、利润损失、信息损失、业务中断、计算机故障、第三方索赔或因无法使用软件产品而寻求替代方案的支出费用），即使太初科技已被告知出现这种损失、损害、索赔或费用的可能性。依据本声明以及太初科技的销售条款，太初科技在任何情况下承担的总体赔付金额仅限于用户购买产品所支付的款项（如有）。

## 信息准确性
上述产品信息属于太初科技所有，且太初科技保留不经通知随时对产品信息或对任何产品和服务做出任何更改的权利，但不承诺更新产品信息。产品使用指南/手册列出的性能测试和等级要使用特定芯片或计算机系统或组件来测量。经该等测试，产品使用手册/指南所示结果反映了太初科技产品的测试性能。系统硬件或软件设计或配置的差异会影响产品的实际性能。如上所述，太初科技不担保或保证产品性能及特定用途，用户需就产品进行必要测试以确认产品适合并适用于用户计划或自行设计的应用及应用程序。

## 知识产权通知
产品及其产品信息的著作权、商标权、专利权等知识产权以及商业秘密属于太初科技及/或相关权利人专属所有或持有，受《中华人民共和国著作权法》《计算机软件保护条例》《中华人民共和国商标法》《中华人民共和国专利法》及适用之国际公约中有关著作权、商标权、专利权及/或其他财产所有权法律的保护。

任何单位和个人未经太初科技书面授权，不得以任何目的（包括但不限于学习、研究等非商业用途）修改、截取、编纂、上传、出版、发布等或以任何方式和媒介复制、转载和传播产品信息的任何部分，否则将视为侵权，太初科技保留依法追究其侵权损害赔偿责任。除了用户使用产品和产品信息的权利，太初科技不就任何专利、版权、商标、商业秘密或任何其他知识产权或所有权授予任何明示或暗示的权利或许可。

太初科技的“太初元碁”“Tecorigin”等文字及/或标识，以及太初科技的其他标志、标识、徽记、产品和服务名称均为太初科技在中国和其他国家的商标，如有宣传、展示等使用需要，需事先取得太初科技的书面授权。

版权声明

© 2023 太初（无锡）电子科技有限公司 保留一切权利。
