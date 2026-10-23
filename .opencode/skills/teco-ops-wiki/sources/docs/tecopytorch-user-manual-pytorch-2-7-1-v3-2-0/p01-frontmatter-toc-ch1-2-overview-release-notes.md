---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p01
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第1部分 (frontmatter-toc-ch1-2-overview-release-notes)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "1-966"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, overview, model-support, release-notes]
---

# TecoPyTorch 用户手册 v3.2.0（第1部分）

> 原文行范围：`1-966`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

TecoPyTorch用户手册（适配
PyTorch 2.7.1）


产品版本号：v3.2.0
发布日期：2026.06.04




太初(无锡)电子科技有限公司

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           版权声明




版权声明
本版权声明是太初（无锡）电子科技有限公司（以下简称“太初科技”）关于软件产品（下称“产品”）、编程指南以及软
件使用手册的全部版本（包含现有版本及未来更新版本）及与软件产品、编程指南以及软件使用手册全部版本相关的
源程序、源代码、示例、模型、场景、数据、域名、结构设计、图标、标志、标识、版面设计、文档资料等以及任何
由太初科技基于软件技术维护或支持服务所提供的数据、资料等（下称“产品信息”）做出的法律声明。



免责声明：

太初科技不就产品和产品信息做出任何担保、条件、陈述和保证（无论是明示的还是默示的，无论是依据成文法、普
通法、惯例还是其他任何原因），包括但不限于性能、结果、安全、不侵权、适销性、完整性、准确性、可不受干扰
性、可销售品质以及特定用途，太初科技不应对因下列原因产生的任何违约、损害赔偿、费用或问题承担赔偿责任，
包括但不限于：

（1）用户未按照软件使用手册/指南内容规范使用产品；

（2）因用户自身设计问题导致的损失；

（3）因用户将软件产品与非太初科技提供的任何其他软件、程序或设备的组合或使用而产生的损失；

（4）因电力供应故障、通讯网络故障等公共服务因素或移动通讯终端病毒或黑客攻击、系统不稳定等第三人因素产生
的损失；

（5） 因不可抗力等风险因素（是指不能预见、不能克服并不能避免且对一方或双方造成重大影响的客观事件，包括但
不限于自然灾害如洪水、地震、风暴等以及社会事件如战争、动乱、政府行为等。）致使软件产品的使用出现中断或
终止而产生的损失；

（6）在太初科技已尽善意管理或善意提醒的情况下，因常规或紧急的设备与系统维护、设备与系统故障、网络信息与
数据安全等因素产生的损失；

（7）因您提供的产品反馈信息侵犯第三方权利致使软件产品侵权而发生的侵权索赔；

（8）非因太初科技的原因引起的与软件产品有关的其它损失。



责任限制：

除法律规定不得排除或限制的赔偿责任外，无论相关责任是基于违约、违反保证、侵权（包括疏忽）、产品责任或任
何其他诉讼或责任理论而产生的，太初科技在任何情况下都无需对用户因使用或无法使用产品和产品信息而产生的任
何商业损害或间接经济损失承担赔偿责任（包括但不限于商誉损失、利润损失、信息损失、业务中断、计算机故障、
第三方索赔或因无法使用软件产品而寻求替代方案的支出费用），即使太初科技已被告知出现这种损失、损害、索赔
或费用的可能性。依据本声明以及太初科技的销售条款，太初科技在任何情况下承担的总体赔付金额仅限于用户购买
产品所支付的款项（如有）。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      I1

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           版权声明




信息准确性：

上述产品信息属于太初科技所有，且太初科技保留不经通知随时对产品信息或对任何产品和服务做出任何更改的权
利，但不承诺更新产品信息。产品使用指南/手册列出的性能测试和等级要使用特定芯片或计算机系统或组件来测量。
经该等测试，产品使用手册/指南所示结果反映了太初科技产品的测试性能。系统硬件或软件设计或配置的差异会影响
产品的实际性能。如上所述，太初科技不担保或保证产品性能及特定用途，用户需就产品进行必要测试以确认产品适
合并适用于用户计划或自行设计的应用及应用程序。



知识产权通知：

产品及其产品信息的著作权、商标权、专利权等知识产权以及商业秘密属于太初科技及/或相关权利人专属所有或持
有，受《中华人民共和国著作权法》《计算机软件保护条例》《中华人民共和国商标法》《中华人民共和国专利法》
及适用之国际公约中有关著作权、商标权、专利权及/或其他财产所有权法律的保护。

任何单位和个人未经太初科技书面授权，不得以任何目的（包括但不限于学习、研究等非商业用途）修改、截取、编
纂、上传、出版、发布等或以任何方式和媒介复制、转载和传播产品信息的任何部分，否则将视为侵权，太初科技保
留依法追究其侵权损害赔偿责任。除了用户使用产品和产品信息的权利，太初科技不就任何专利、版权、商标、商业
秘密或任何其他知识产权或所有权授予任何明示或暗示的权利或许可。

太初科技的“太初元碁”“Tecorigin”等文字及/或标识，以及太初科技的其他标志、标识、徽记、产品和服务名称均为太
初科技在中国和其他国家的商标，如有宣传、展示等使用需要，需事先取得太初科技的书面授权。

版权声明

© 2024 太初（无锡）电子科技有限公司 保留一切权利。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      II
                                                              2

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




目录
1. 概述                                                       1
 1.1 什么是TecoPyTorch                                          1
 1.2 模型支持列表                                                  1
   1.2.1 Intel/AMD（Ubuntu 22.04）                             1
   1.2.2 海光 7380/7375（Kylin V10）                            4
   1.2.3 申威 8A（UOS Server 20）                               5
   1.2.4 龙芯 3C6000（Loongnix Server 23.1）                    6
   1.2.5 飞腾S5000C（Kylin V10国防版）                             7

2. 最新动态                                                     8
 2.1 v3.2.0更新记录                                             8
 2.2 v3.1.0更新记录                                             8
 2.3 v3.0.0更新记录                                             9
 2.4 v2.3.0更新记录                                             9

3. 安装指南                                                    10
 3.1 Intel/AMD（x86_64）                                     10
   3.1.1 Ubuntu 22.04                                      10
    3.1.1.1 Conda+Pip安装                                    10
      3.1.1.1.1 安装依赖                                       10
      3.1.1.1.2 安装准备                                        11
      3.1.1.1.3 安装TecoPyTorch                               11
        3.1.1.1.3.1 创建Anaconda环境                            11
        3.1.1.1.3.2 获取软件安装包                                12
        3.1.1.1.3.3 安装软件安装包                                13
        3.1.1.1.3.4 升/降级软件安装包                              14
        3.1.1.1.3.5 卸载软件安装包                                16



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    III
                                                             3

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




    3.1.1.2 Docker安装                                       17
      3.1.1.2.1 安装依赖                                       17
      3.1.1.2.2 安装准备                                       18
      3.1.1.2.3 安装步骤                                       18
        3.1.1.2.3.1 获取Docker镜像                             18
        3.1.1.2.3.2 构建Docker容器                             19
        3.1.1.2.3.3 进入Docker容器                             20
        3.1.1.2.3.4 验证TecoPyTorch                          21
 3.2 申威 8A（SW-64)                                          21
   3.2.1 UOS Server 20                                     21
    3.2.1.1 Pip安装                                          21
      3.2.1.1.1 安装依赖                                       21
      3.2.1.1.2 安装准备                                       22
      3.2.1.1.3 安装TecoPyTorch                              23
        3.2.1.1.3.1 创建Python虚拟环境                           23
        3.2.1.1.3.2 获取软件安装包                                24
        3.2.1.1.3.3 安装软件安装包                                25
        3.2.1.1.3.4 升/降级软件安装包                              25
        3.2.1.1.3.5 卸载软件安装包                                27
    3.2.1.2 Docker安装                                       28
      3.2.1.2.1 安装依赖                                       28
      3.2.1.2.2 安装准备                                       28
      3.2.1.2.3 安装步骤                                       29
        3.2.1.2.3.1 获取Docker镜像                             29
        3.2.1.2.3.2 构建Docker容器                             30
        3.2.1.2.3.3 进入Docker容器                             31
        3.2.1.2.3.4 验证TecoPytorch                          31
 3.3 龙芯 3C6000（LoongArch）                                  32


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    IV
                                                             4

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




   3.3.1 Loongnix Server 23.1                              32
    3.3.1.1 Pip                                            32
      3.3.1.1.1 安装依赖                                       32
      3.3.1.1.2 安装准备                                       33
      3.3.1.1.3 安装TecoPyTorch                              33
        3.3.1.1.3.1 创建Python虚拟环境                           33
        3.3.1.1.3.2 获取软件安装包                                34
        3.3.1.1.3.3 安装软件安装包                                35
        3.3.1.1.3.4 升/降级软件安装包                              36
        3.3.1.1.3.5 卸载软件安装包                                37
    3.3.1.2 Docker                                         38
      3.3.1.2.1 安装依赖                                       38
      3.3.1.2.2 安装准备                                       38
      3.3.1.2.3 安装步骤                                       39
        3.3.1.2.3.1 获取Docker镜像                             39
        3.3.1.2.3.2 构建Docker容器                             40
        3.3.1.2.3.3 进入Docker容器                             41
        3.3.1.2.3.4 验证TecoPytorch                          41
 3.4 海光 7380/7375（x86_64）                                  42
   3.4.1 Kylin V10 SP3                                     42
    3.4.1.1 Conda+Pip安装                                    42
      3.4.1.1.1 安装依赖                                       42
      3.4.1.1.2 安装准备                                       43
      3.4.1.1.3 安装TecoPyTorch                              43
        3.4.1.1.3.1 创建Anaconda环境                           43
        3.4.1.1.3.2 获取软件安装包                                44
        3.4.1.1.3.3 安装软件安装包                                45
        3.4.1.1.3.4 升/降级软件安装包                              46


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    V
                                                            5

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




        3.4.1.1.3.5 卸载软件安装包                                47
    3.4.1.2 Docker安装                                       48
      3.4.1.2.1 安装依赖                                       48
      3.4.1.2.2 安装准备                                       49
      3.4.1.2.3 安装步骤                                       49
        3.4.1.2.3.1 获取Docker镜像                             49
        3.4.1.2.3.2 构建Docker容器                             50
        3.4.1.2.3.3 进入Docker容器                             51
        3.4.1.2.3.4 验证TecoPyTorch                          51
 3.5 飞腾 S5000C                                             52
   3.5.1 Kylin V10（国防版）                                    52
    3.5.1.1 Conda+Pip安装                                    52
      3.5.1.1.1 安装依赖                                       52
      3.5.1.1.2 安装准备                                       53
      3.5.1.1.3 安装TecoPyTorch                              54
        3.5.1.1.3.1 创建Anaconda环境                           54
        3.5.1.1.3.2 获取软件安装包                                54
        3.5.1.1.3.3 安装软件安装包                                55
        3.5.1.1.3.4 升/降级软件安装包                              56
        3.5.1.1.3.5 卸载软件安装包                                58
    3.5.1.2 Docker安装                                       58
      3.5.1.2.1 安装依赖                                       58
      3.5.1.2.2 安装准备                                       59
      3.5.1.2.3 安装步骤                                       59
        3.5.1.2.3.1 获取Docker镜像                             59
        3.5.1.2.3.2 构建Docker容器                             60
        3.5.1.2.3.3 进入Docker容器                             61
        3.5.1.2.3.4 验证TecoPytorch                          62


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    VI
                                                             6

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




4. 环境变量                                                    63
 4.1 TORCH_DEVICE_BACKEND_AUTOLOAD                         63
 4.2 TORCH_SDAA_AUTOLOAD                                   63
 4.3 TORCH_SDAA_RUNTIME_AUTOFALLBACK                       63
 4.4 TORCH_SDAA_FALLBACK_OPS                               64
 4.5 TORCH_SDAA_LOG_LEVEL                                  64
 4.6 TORCH_SDAA_CONV_USE_FP32                              65
 4.7 TORCH_SDAA_CONV2D_BACKWARD_USE_FP32                   65
 4.8 TORCH_SDAA_CONV_WEIGHT_CHWN                           66
 4.9 TORCH_SDAA_BF16_CLIP                                  66

5. 模型迁移                                                    68
 5.1 迁移约束                                                  68
 5.2 自动迁移                                                  70
   5.2.1 迁移方法                                              70
   5.2.2 迁移示例                                               73
 5.3 手动迁移                                                  84
   5.3.1 迁移方法                                              84
   5.3.2 迁移示例                                              92
 5.4 迁移问题排查                                                95
   5.4.1 概述                                                96
   5.4.2 前置知识                                              96
   5.4.3 环境和数据处理类                                          97
   5.4.4 训练中断类                                             98
   5.4.5 精度异常类                                             101

6. 模型开发                                                    102
7. 自定义SDAA C算子接入                                           107
 7.1 基于SDAA Extenstion编写自定义算子                              107
   7.1.1 SDAA Extension简介                                  107


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    VII7

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




   7.1.2 编写SDAA Extension                                  107
    7.1.2.1 编写全新的SDAA C自定义算子                               107
    7.1.2.2 改写CUDA自定义算子为SDAA C自定义算子                        123
 7.2 基于PyTorch的load_inline编写自定义算子                          131
 7.3 自定义SDAA C算子性能分析                                       133

8. 模型训练                                                    134
 8.1 自动混合精度训练AMP                                           134
   8.1.1 AMP简介                                             134
   8.1.2 开启AMP                                             135
 8.2 分布式训练DDP                                              137
   8.2.1 DDP简介                                             137
   8.2.2 基本概念                                              138
   8.2.3 核心功能                                              139
   8.2.4 分布式训练启动方法                                         144
    8.2.4.1 概述                                             144
    8.2.4.2 torchrun                                       144
    8.2.4.3 torch.distributed.launch                       146
    8.2.4.4 mp.spawn                                       147
   8.2.5 分布式训练示例                                           149
    8.2.5.1 示例代码                                           149
    8.2.5.2 torchrun开启示例                                   150
    8.2.5.3 torch.distributed.launch开启示例                   152
    8.2.5.4 mp.spawn开启示例                                   153
    8.2.5.5 mpirun开启示例                                     155
 8.3 强制算子回落CPU计算                                           156
 8.4 解析回落到CPU上计算的算子                                        157

9. Compiler图编译优化                                           160
 9.1 使用说明                                                  160


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    VIII
                                                              8

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            目录




 9.2 可编译算子说明                                               166
 9.3 编译配置选项说明                                              169

10. 精度调测                                                   172
 10.1 精度异常现象                                               172
 10.2 精度问题原因                                               173
 10.3 精度调试方法                                               176
   10.3.1 模型迁移场景下的精度调试方法                                   176
   10.3.2 模型开发场景下的精度调试方法                                   179
 10.4 Hook调试函数                                             183
   10.4.1 Hook使用介绍                                         183
   10.4.2 Hook使用示例                                         185

11. 性能调优                                                   189
 11.1 Profiler使用介绍                                         189
   11.1.1 开启Profiler                                       189
   11.1.2 性能数据可视化                                          192
 11.2 性能优化                                                 194

12. 内存分析                                                   198
13. API参考                                                  202
 13.1 原生PyTorch算子类API支持说明                                  202
   13.1.1 torch                                            202
   13.1.2 torch.nn                                         239
   13.1.3 torch.nn.functional                              247
   13.1.4 torch.Tensor                                     249
   13.1.5 torch.distributions                              265
   13.1.6 torch.random                                     266
   13.1.7 torch.cuda                                       266
   13.1.8 torch.jit                                        266
 13.2 TecoPyTorch与PyTorch CUDA的功能性API比对                    266


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     IX
                                                              9

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           目录




 13.3 torch.sdaa                                           271
   13.3.1 torch.sdaa.is_available                          271
   13.3.2 torch.sdaa.device_count                          272
   13.3.3 torch.sdaa.set_device                            272
   13.3.4 torch.sdaa.device                                273
   13.3.5 torch.sdaa.current_device                        274
   13.3.6 torch.sdaa.synchronize                           274
   13.3.7 torch.sdaa.current_stream                        275
   13.3.8 torch.sdaa.default_stream                        275
   13.3.9 torch.sdaa.stream                                276
   13.3.10 torch.sdaa.set_stream                           277
   13.3.11 torch.sdaa.is_bf16_supported                    277
   13.3.12 torch.sdaa.Generator                            278
   13.3.13 torch.sdaa.random_align_nv_device               279
   13.3.14 torch.sdaa.manual_seed                          279
   13.3.15 torch.sdaa.manual_seed_all                      280
   13.3.16 torch.sdaa.seed                                 281
   13.3.17 torch.sdaa.seed_all                             281
   13.3.18 torch.sdaa.initial_seed                         282
   13.3.19 torch.sdaa.get_rng_state                        283
   13.3.20 torch.sdaa.get_rng_state_all                    284
   13.3.21 torch.sdaa.set_rng_state                        284
   13.3.22 torch.sdaa.set_rng_state_all                    285
   13.3.23 torch.sdaa.StreamContext                        286
   13.3.24 torch.sdaa.device_memory_used                   286
 13.4 torch.sdaa.Stream                                    287
   13.4.1 query                                            288
   13.4.2 record_event                                     288


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      X
                                                             10

TecoPyTorch用户手册（适配PyTorch 2.7.1）                             目录




   13.4.3 synchronize                                       289
   13.4.4 wait_event                                        290
   13.4.5 wait_stream                                       290
 13.5 torch.sdaa.Event                                      291
   13.5.1 elapsed_time                                      292
   13.5.2 query                                             293
   13.5.3 record                                            294
   13.5.4 synchronize                                       294
   13.5.5 wait                                              295
 13.6 torch.sdaa.amp                                        296
   13.6.1 torch.sdaa.amp.autocast                           296
   13.6.2 torch.sdaa.amp.GradScaler                         297
   13.6.3 torch.sdaa.amp.is_autocast_enabled                299
   13.6.4 torch.sdaa.amp.set_autocast_enabled               300
   13.6.5 torch.sdaa.amp.register_autocast_dtype_function   300
   13.6.6 torch.sdaa.amp.register_autocast_dtype_module     301
 13.7 自定义算子API                                              302
   13.7.1 torch.ops.sdaa.fused_fast_attention_v3            302

14. 第三方库支持列表                                                306
15. 常见问题                                                    312
 15.1 分布式通信时初始化过程停滞，host端报socket timeout错误                  312
 15.2 数据读取时Dataloader worker线程报错，Resource temporarily
 unavailable                                                312
 15.3 模型进行分布式训练时出现报错，Invalid arguments                      314
 15.4 模型进行分布式训练时出现报错，NotImplementedError                    314
 15.5 运行模型训练时出现报错，RuntimeError: cannot resize variables that
 require grad，如何解决？                                        315




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      XI
                                                              11

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                   目录




 15.6 运行模型训练时出现报错，RuntimeError:
 torch.nn.functional.binary_cross_entropy and torch.nn.BCELoss are
 unsafe to autocast，如何解决？                                          316
 15.7 导入torch_sdaa时报错，libsddev.so.0: cannot open shared object
 file，如何解决？                                                    317
 15.8 Pip安装时出现Timeout报错，如何解决？                                      317
 15.9 Conv算子不支持group参数，如何解决？                                       318
 15.10 如何在Docker环境中查看TecoPyTorch及其依赖组件版本信息？                        318
 15.11 使用TecoSMI查看加速卡硬件信息时，Volatile SPE-Util列为N/A，如何处
 理？                                                  318
 15.12 为什么Docker环境中teco-smi-c命令显示的进程PID和ps命令显示的PID不
 一致？                                              319
 15.13 运行包含卷积的模型，为什么不使用AMP的情况下，也需要开启
 GradScaler？                                                      320
 15.14 为何更推荐使用AMP的方式运行训练？                                         320
 15.15 为何卷积更推荐使用NHWC的layout进行计算？                                  320




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司            XII
                                                                    12

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    概述




1. 概述
1.1 什么是TecoPyTorch
TecoPyTorch是高度适配太初AI加速卡的PyTorch深度学习框架（基于原生PyTorch 2.7.1版本），兼容PyTorch框架
的原生API。通过整合太初元碁的底层组件（如：驱动、运行时、计算库、通信库和各类工具等），使您能够在太初AI
加速卡上高效、便捷地运行PyTorch完成训练。

TecoPyTorch采用Python扩展包的形式对原生PyTorch进行支持，太初将所有关于太初AI加速卡的操作都放在一个单
独的Python扩展包中，然后将该包导入原生PyTorch，从而支持在太初AI加速卡上的运算。

   TecoPyTorch兼容原生PyTorch的Python编程接口和原生PyTorch网络模型，支持以在线逐层的方式进行训练。

   网络权重可以从pth格式文件读取，已支持的分类和检测网络结构由Torchvision管理，可以从Torchvision读
   取。
   对于训练任务，支持float32/half数据类型模型。

   对于推理任务，暂时只支持float32数据类型。

为了能在PyTorch中方便地使用太初AI加速卡，TecoPyTorch在PyTorch后端进行了以下扩展：

   通过PyTorch调用太初AI加速卡支持的网络模型计算。

   对于太初AI加速卡暂不支持的算子，且该算子已在TecoPyTorch中添加注册，支持该类算子自动切换到CPU上执
   行。
   PyTorch中与TecoPyTorch相关接口的语义与CPU和GPU的接口语义保持一致。

   支持CPU和太初AI加速卡之间的无缝切换。


1.2 模型支持列表
1.2.1 Intel/AMD（Ubuntu 22.04）
 强化学习

 模型                  训练模式                    是否使用分布式训练

 DQN                 AMP                     否

 PPO                 AMP                     否


 语音




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                 1

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           概述




 模型                                训练模式             是否使用分布式训练

 PANN                              AMP              否

 ECAPA-TDNN                        AMP              否

 wav2vec2                          AMP              否

 HiFi-GAN                          AMP              否

 YourTTS                           AMP              否

 Wav2Lip                           AMP              否

 WeNet                             AMP              否

 FastSpeech2                       AMP              否


 自然语言处理

 模型                                       训练模式             是否使用分布式训练

 GPT2                                     AMP              否

 XLNet                                    AMP              否

 BERT/finetune                            AMP              否

 BERT                                     AMP              否

 NEZHA                                    AMP              否

 PGN                                      AMP              否

 PL-Marker                                AMP              否

 W2NER                                    AMP              否

 UIE                                      AMP              否

 Seq2SeqTransformer                       AMP              否


 计算机视觉

 模型                                         训练模式               是否使用分布式训练

 EfficientnetV2                             AMP                否




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                    2

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       概述




 模型                                         训练模式           是否使用分布式训练

 SimSwap                                    AMP            否

 VGG                                        AMP            否

 FasterRCNN-R101-FPN3x                      AMP            否

 ArcFace                                    AMP            否

 FaceShifter                                AMP            否

 MobileNetV3                                AMP            否

 Hourglass                                  AMP            否

 RetinaFace                                 AMP            否

 FaceNet                                    AMP            否

 SSD                                        AMP            否

 Yolov5                                     AMP            否

 Inceptionv3                                AMP            否

 rt-detr                                    AMP            否

 Yolov3                                     AMP            否

 DeepLabv3                                  AMP            否

 HRNet                                      AMP            否

 YOLOair                                    AMP            否

 ResNet                                     AMP            否

 U-Net                                      AMP            否

 Mask-R-CNN                                 AMP            否

 InternImage                                AMP            否

 YOLOv7                                     AMP            否

 Vision Transformer                         AMP            否


 推荐系统



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                3

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       概述




 模型                                 训练模式            是否使用分布式训练

 DIN                                AMP             否

 DLRM                               AMP             否

 WideAndDeep                        AMP             否


 图神经网络

 模型                       训练模式                 是否使用分布式训练

 DeCorr                   AMP                  否


 其他

 模型                                          训练模式          是否使用分布式训练

 Vision/Transformer/timm                     AMP           否

 Co-DETR                                     AMP           否

 YOLOv9                                      AMP           否

 YOLOv8                                      AMP           否

 YOLOv10                                     AMP           否

 YOLOv11                                     AMP           否

 Swin/Transformer/timm                       AMP           否

 MlPerf-Mask-R-CNN                           AMP           否

 YOLOv4                                      AMP           否

 ultralytics                                 AMP           否


 模型数据

   精度：TeCode

   性能：TeCode


1.2.2 海光 7380/7375（Kylin V10）
 计算机视觉


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                4

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            概述




 模型                        训练模式                 是否使用分布式训练

 YOLOv5                    AMP                  否

 ResNet                    AMP                  否

 YOLOv7                    AMP                  否


 其他

 模型                         训练模式                是否使用分布式训练

 YOLOv9                     AMP                 否

 YOLOv8                     AMP                 否

 YOLOv10                    AMP                 否

 YOLOv11                    AMP                 否

 YOLOv4                     AMP                 否


 模型数据

   精度：TeCode

   性能：TeCode


1.2.3 申威 8A（UOS Server 20）
 计算机视觉

 模型                        训练模式                 是否使用分布式训练

 YOLOv5                    AMP                  否

 ResNet                    AMP                  否

 YOLOv7                    AMP                  否


 其他

 模型                         训练模式                是否使用分布式训练

 YOLOv9                     AMP                 否




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     5

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            概述




 模型                         训练模式                是否使用分布式训练

 YOLOv8                     AMP                 否

 YOLOv10                    AMP                 否

 YOLOv11                    AMP                 否

 YOLOv4                     AMP                 否


 模型数据

   精度：TeCode

   性能：TeCode


1.2.4 龙芯 3C6000（Loongnix Server 23.1）
 计算机视觉

 模型                        训练模式                 是否使用分布式训练

 YOLOv5                    AMP                  否

 ResNet                    AMP                  否

 YOLOv7                    AMP                  否


 其他

 模型                         训练模式                是否使用分布式训练

 YOLOv9                     AMP                 否

 YOLOv8                     AMP                 否

 YOLOv10                    AMP                 否

 YOLOv11                    AMP                 否

 YOLOv4                     AMP                 否


 模型数据

   精度：TeCode

   性能：TeCode



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     6

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           概述




1.2.5 飞腾S5000C（Kylin V10国防版）
 计算机视觉

 模型                       训练模式                 是否使用分布式训练

 ResNet                   AMP                  否


 模型数据

   精度：TeCode

   性能：TeCode




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司    7

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                    最新动态




2. 最新动态
2.1 v3.2.0更新记录
 新增内容

 描述                                                文档

 新增load_inline功能，编写自定义算子。                          基于PyTorch的load_inline编写自定义算子

 新增 torch.ops.sdaa.fused_fast_attention_v3         torch.ops.sdaa.fused_fast_attention_v
 自定义算子。                                            3



2.2 v3.1.0更新记录
 新增内容

 描述                                                文档

 新增申威8A+UOS Server 20系统的安装说明。                      申威 8A（SW-64)

 新增龙芯3C6000+Loongnix Server 23.1系统的安装说明。           龙芯 3C6000（LoongArch）

 新增海光7380/7375+Kylin V10系统的安装说明。                   海光 7380/7375（x86_64）

 新增飞腾S5000C+Kylin V10（国防版）系统的安装说明。                 飞腾 S5000C

 新增 torch.sdaa.device_memory_used 接口。              torch.sdaa.device_memory_used


 更新内容

 描述                                                文档

 更新原生PyTorch算子类API支持说明。                            原生PyTorch算子类API支持说明


 删除内容

 描述                                                文档

 删除 TORCH_SDAA_USE_FUSED_ATTENTION 环境变量，
                                                   N/A
 该环境变量功能已废弃。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                   8

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                         最新动态




2.3 v3.0.0更新记录
 新增内容

 描述                                                文档

 新增以下环境变量：
       TORCH_SDAA_CONV_WEIGHT_CHWN

       TORCH_SDAA_BF16_CLIP                        环境变量

       TORCH_SDAA_USE_FUSED_ATTENTION




 更新内容

 描述                                                文档

 更新原生PyTorch算子类API支持说明。                            原生PyTorch算子类API支持说明


 删除内容

 描述                                                文档

 本版本不支持海光7380/7375操作系统的安装，删除相应安装
                                                   N/A
 内容。




2.4 v2.3.0更新记录
 更新内容

本版本为首次正式发布版本。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                    9

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    安装指南
