---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p04
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第4部分 (ch4-env-vars)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "4396-4638"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, env-vars, fallback, logging, convolution, bf16]
---

# TecoPyTorch 用户手册 v3.2.0（第4部分）

> 原文行范围：`4396-4638`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

4. 环境变量
4.1 TORCH_DEVICE_BACKEND_AUTOLOAD
 TORCH_DEVICE_BACKEND_AUTOLOAD 用于设置导入 torch 功能时，是否开启 torch_sdaa 自动导入功
能。开启该功能后，在您导入 torch 模块时，无需再单独导入 torch_sdaa 模块，即可实现对
 torch_sdaa 功能的使用。


     提示：

     如果需要使用 torch_sdaa 模块下的自定义功能接口（即 torch_sdaa.xxx.xxx 格式的API接口），
     仍需使用 import torch_sdaa 进行手动导入。


 名称                          默认值       取值

                                       设置导入 torch 功能时，是否开启 torch_sdaa 自动导入
                                       功能。
 TORCH_DEVICE_BACKEN
                             无              1：开启。默认情况下，该环境变量自动开启。
 D_AUTOLOAD
                                            其它值：关闭。



4.2 TORCH_SDAA_AUTOLOAD
  TORCH_SDAA_AUTOLOAD 用于设置在TecoPyTorch中自动引入的功能模块。


 名称                     默认值          取值

 TORCH_SDAA_AUT                      设置在TecoPyTorch中自动引入的功能模块。目前支持：
                        无
 OLOAD                               cuda_migrate。




4.3 TORCH_SDAA_RUNTIME_AUTOFALLBACK
  TORCH_SDAA_RUNTIME_AUTOFALLBACK 用于设置模型训练时，是否开启算子强制回落至CPU计算的功能。


     提示：

     该环境变量开启后，需要配合TORCH_SDAA_FALLBACK_OPS环境变量一起使用。具体使用方法，请参考
     强制算子回落CPU计算。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                     63

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         环境变量




 名称                             默认值        取值

                                           设置是否开启算子强制回落至CPU计算的功能。
                                                1：开启。

 TORCH_SDAA_RUNTIME_A                           其他值：关闭。
                                无
 UTOFALLBACK
                                           开启该环境变量的示例如下：

                                              export TORCH_SDAA_RUNTIME_AUTOFALLBACK=1




4.4 TORCH_SDAA_FALLBACK_OPS
  TORCH_SDAA_FALLBACK_OPS 用于设置模型训练时，回落至CPU计算的算子。


     提示：

     使用该环境变量前，需要先开启TORCH_SDAA_RUNTIME_AUTOFALLBACK环境变量。具体使用方法，请
     参考强制算子回落CPU计算。


 名称                         默认值          取值

                                         设置回落至CPU计算的算子。使用示例如下：

                                              说明：

 TORCH_SDAA_FALLBAC                           如果需要同时设置多个算子，请使用英文逗号进行分
                            无
 K_OPS                                        割。


                                            export TORCH_SDAA_RUNTIME_AUTOFALLBACK=1
                                            export TORCH_SDAA_FALLBACK_OPS=add,sub




4.5 TORCH_SDAA_LOG_LEVEL
  TORCH_SDAA_LOG_LEVEL 用于设置模型训练时日志的输出级别。




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                                   64

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                环境变量




 名称                    默认值         取值

                                   设置模型训练时日志的输出级别：
                                        trace：记录最详细的执行跟踪，例如：函数调用栈、耗时统计等，
                                        适用于深度性能优化或底层逻辑分析的场景。
                                        debug： 记录调试细节，例如：变量值、分支逻辑等，适用于开
                                        发/测试阶段排查问题原因。
                                        info：记录关键流程信息，例如：正常运行状态的关键节点，适用于
                                        环境或系统状态的常规监控。
                                        warn： 记录告警信息。

                                        error：记录运行时的错误。

                                        critical：记录致命错误，例如：程序崩溃。
 TORCH_SDAA_LO
                       无                off：关闭所有日志输出。
 G_LEVEL

                                             说明：

                                                   TORCH_SDAA_LOG_LEVEL 环境变量的值不区别大
                                                 小写。
                                                 日志等级由低到高分别为 trace 、 debug 、
                                                  info 、 warn 、 error 、 critical 和
                                                  off 。


                                   环境变量的使用示例如下：

                                      export TORCH_SDAA_LOG_LEVEL=debug




4.6 TORCH_SDAA_CONV_USE_FP32
  TORCH_SDAA_CONV_USE_FP32 用于设置Conv算子的前向计算是否始终使用FP32进行计算。


 名称                                  默认值          取值和说明

                                                  设置Conv算子的前向计算是否始终使用FP32进行计
                                                  算。
 TORCH_SDAA_CONV_USE_FP32            无                1：始终使用FP32进行计算。

                                                      其他值：算子内部将FP32输入转FP16进行计算。



4.7 TORCH_SDAA_CONV2D_BACKWARD_USE_FP32


文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                             65

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                        环境变量




  TORCH_SDAA_CONV2D_BACKWARD_USE_FP32 用于设置Conv2d算子的反向计算是否始终使用FP32进行计算。


 名称                                  默认值      取值和说明

                                              设置Conv2d算子的反向计算是否始终使用FP32进行计
                                              算。
 TORCH_SDAA_CONV2D_BACKWAR
                                     无           1：始终使用FP32进行计算。
 D_USE_FP32
                                                 其他值：算子内部将FP32输入转FP16进行计算。



4.8 TORCH_SDAA_CONV_WEIGHT_CHWN
  TORCH_SDAA_CONV_WEIGHT_CHWN 用于设置Conv类算子
（Conv1d/ConvTranspose1d/Conv2d/ConvTranspose2d）的权重是否使用CHWN格式。


     提示：

     开启该环境变量能提升模型性能，但也会导致随机数计算结果与不开启该环境相比，存在一定的差异。这种差
     异会干扰精度比较，因此在需要严格对齐精度的场景下，请关闭此功能。


 名称                                  默认值     取值和说明

                                             Conv类算子的权重是否使用CHWN格式：
 TORCH_SDAA_CONV_WEIGHT_C                       1：使用CHWN格式。
                                     无
 HWN
                                                其他值：不作处理。




4.9 TORCH_SDAA_BF16_CLIP
  TORCH_SDAA_BF16_CLIP 用于设置在进行bfloat16精度的矩阵乘法运算时，是否对输入值进行裁剪，以防止数值
溢出。


     说明：

     此环境变量主要影响包含矩阵乘的算子，例如： mm 、 addmm 、 bmm 和 flash attention
     等。当这些算子进行矩阵乘计算时，如果输入值较大， TORCH_SDAA_BF16_CLIP 自动将输入张量的值裁
     剪到一个安全的范围内。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                     66

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            环境变量




 名称                                默认值     取值和说明

                                           矩阵乘法计算时，是否对输入的值进行裁剪。
                                              1：将输入的值裁剪到[-65407,65407]范围。
 TORCH_SDAA_BF16_CLIP              无
                                              其他值：不作处理。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                       67

TecoPyTorch用户手册（适配PyTorch 2.7.1）                              模型迁移
