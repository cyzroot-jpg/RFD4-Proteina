---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0"
type: source-doc
source_category: official-doc
product_version: "v3.2.0"
published_at: "2026-06-04"
created_at: "2026-07-07"
captured_at: "2026-07-07"
author: "docs.tecorigin.net"
doc_kind: tecopytorch-user-manual
pdf_pages: 333
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
architectures: [sdaa, teco-t1]
tags: [tecopytorch, pytorch, pytorch-2-7-1, torch-sdaa, model-migration, sdaa-extension, custom-op, amp, ddp, compiler, profiler, precision-debug, api-reference, sdaa]
languages: [python, pytorch, zh-cn]
confidence: verified
---

# TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0

> TecoPyTorch 是适配太初 AI 加速卡的 PyTorch 深度学习框架扩展（基于 PyTorch 2.7.1）。本手册覆盖模型支持、安装、环境变量、模型迁移、模型开发、自定义 SDAA C 算子接入、AMP/DDP 训练、Compiler 图编译优化、精度调测、性能调优、内存分析、API 参考、第三方库支持和常见问题。

这是《TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0》的**索引页**。完整、无损的正文按原始抽取行连续切分在下方 `part` 子页中（共 18 部分），所有 part 合并后覆盖 `raw_text` 的第 1-21108 行，不跳过封面、版权声明、目录、正文、API 表和 FAQ。原始 `pdftotext -layout` 抽取全文存于 `raw_text`，可逐行追溯。

## 文档元信息

- 标题：TecoPyTorch 用户手册（适配 PyTorch 2.7.1）
- 产品版本：v3.2.0
- 发布日期：2026.06.04
- PDF 创建时间：2026-06-26 17:45:19 CST
- 页数：333
- 原始 PDF：`external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf`
- 原始抽取全文：`sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt`（pdftotext -layout，完整无删减，21108 行，785520 字节）

## 完整内容分卷（part 子页）

| Part | 覆盖章节 | 原文行范围 | 主题 | 页面 |
|------|---------|-----------|------|------|
| p01 | 封面/版权/目录 + ch1-2 | 1-966 | 封面、版权声明、目录、概述、模型支持列表、最新动态 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p01` |
| p02 | ch3 | 967-2500 | 安装指南：Intel/AMD x86_64 Ubuntu 22.04、申威 8A UOS Server 20 前半部分 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p02` |
| p03 | ch3 | 2501-4395 | 安装指南：龙芯 LoongArch、海光 x86_64、飞腾 S5000C | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p03` |
| p04 | ch4 | 4396-4638 | 环境变量：自动加载、回落、日志、卷积 FP32/NHWC、BF16 clip | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p04` |
| p05 | ch5 | 4639-6843 | 模型迁移：迁移约束、自动迁移、手动迁移、迁移问题排查 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p05` |
| p06 | ch6 | 6844-7178 | 模型开发 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p06` |
| p07 | ch7 | 7179-9044 | 自定义 SDAA C 算子接入：SDAA Extension、CUDA 改写、load_inline、性能分析 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p07` |
| p08 | ch8 | 9045-10763 | 模型训练：AMP、DDP、分布式启动、CPU 回落与回落解析 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p08` |
| p09 | ch9 | 10764-11491 | Compiler 图编译优化：使用说明、可编译算子、编译配置选项 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p09` |
| p10 | ch10 | 11492-12460 | 精度调测：异常现象、原因、调试方法、Hook 调试函数 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p10` |
| p11 | ch11 | 12461-12989 | 性能调优：Profiler 使用和性能优化 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p11` |
| p12 | ch12 | 12990-13227 | 内存分析 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p12` |
| p13 | ch13 | 13228-15000 | API 参考：原生 PyTorch 算子类 API 支持说明（part 1） | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p13` |
| p14 | ch13 | 15001-17000 | API 参考：原生 PyTorch 算子类 API 支持说明（part 2） | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p14` |
| p15 | ch13 | 17001-19000 | API 参考：PyTorch CUDA API 比对与 torch.sdaa（part 1） | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p15` |
| p16 | ch13 | 19001-20190 | API 参考：torch.sdaa Stream/Event/amp 与自定义算子 API（part 2） | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p16` |
| p17 | ch14 | 20191-20541 | 第三方库支持列表 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p17` |
| p18 | ch15 | 20542-21108 | 常见问题：分布式、Dataloader、Docker、AMP、Conv layout 等 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p18` |

## 章节目录（原文）


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
