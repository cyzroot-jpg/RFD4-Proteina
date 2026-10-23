---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p10
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第10部分 (ch10-precision-debug)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "11492-12460"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, precision-debug, hook-debug, troubleshooting]
---

# TecoPyTorch 用户手册 v3.2.0（第10部分）

> 原文行范围：`11492-12460`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

10. 精度调测
10.1 精度异常现象
模型出现精度异常，主要体现在模型的Loss（损失值）和Metrics（度量指标）两个方面。

 Loss异常

Loss异常通常表示为以下几种情况：

   Loss爆炸：Loss出现NaN（非数值）、Inf（无穷）等异常值。

   Loss为0：训练初期或过程中，Loss值突然降为0或接近0。

   Loss不收敛或下降异常，无法与Golden精度对齐。此情况可以分为以下几种场景：


         说明：

         在本文档中，将计算结果经过严格验证且作为基准参考的计算设备（如：CPU/CUDA）称为 Golden。


       少量iter下，Loss与Golden完全不对齐，没有下降趋势。




                                           图1 Loss无下降趋势


       少量iter下，Loss有下降趋势，但比Golden差。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司       172

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           精度调测




                                        图2 Loss下降，比CUDA差


       大量iter下，Loss有下降趋势，但比CUDA/CPU差。

 Metrics异常

Metrics异常主要表现为模型的准确度（Accuracy）、精确度（Precision）等度量指标达不到官方数值，或远低于
正常训练结果。




10.2 精度问题原因
影响模型精度的常见原因如下：

   混合精度问题，例如：未开启自动混合精度（AMP），或自动混合精度组件使用不正确， loss_scale 参数
   设置不合理。
   模型超参数问题，例如：学习率、优化器超参、Batch Size、Epoch设置不合理。

   模型权重问题，例如：模型权重初始化有误、预训练模型加载不正确。

   数据集问题，例如：数据集错误、数据集存在脏数据、数据集处理方式不正确等。

   算子精度问题：算子在SDAA上存在精度问题等。

 混合精度问题

在太初AI加速卡上，我们推荐使用混合精度的方式进行训练，以获取更佳的精度。此外，对于卷积来说，太初AI加速卡
仅使用float16进行计算，为避免低精度数据类型而导致的梯度异常问题，在您开启 autocast 的同时，也需要开启
 GradScaler 管理梯度。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     173

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                 精度调测




如果您已开启自动混合精度，模型精度出现异常，建议您检查混合精度的 Autocast 与 GradScaler 组件的相
关参数设置是否合适。

   您可以参考Autocast与GradScaler的官方API，检查两个组件的相关代码是否正确。

     GradScaler 中影响模型精度的参数为            loss_scale ，控制梯度的缩放倍数：

         过大的 loss_scale 可能导致梯度爆炸，使模型权重更新过大，难以收敛到最优解。

         过小的 loss_scale 可能导致梯度下溢，使模型权重无法得到有效更新。

 模型超参数问题

影响精度的模型超参数类问题，主要包含以下几个方面：

 超参数类型            说明

                  学习率是模型训练中一个重要的超参数。学习率设置不合理，对精度的影响如下：
                       学习率过大：会导致Loss不下降或不收敛。
 学习率
                       学习率过小：会导致Loss下降过慢，收敛速度慢。

                  您可以参考官方学习率进行设置。

                  模型优化器的超参数设置不正确或不合理会影响模型的精度。例如，SGD优化器，其主要超参
                  数为 momentum 和 weight_decay ，分别是用于加速SGD收敛的动量与控制参数的幅
 优化器超参            度、以防止过拟合的权重衰减。
                  当您使用与官方相同的优化器时，建议您的优化器的超参数与官方保持一致。

                  Batch Size是模型训练过程中，每次模型权重更新时所使用的样本数量。

                  增大Batch Size，大部分情况下会加速训练，但过大的Batch Size会影响超参数的设置，影
 Batch Size
                  响模型收敛。
                  针对SDAA计算设备硬件特性，建议Batch Size设置为2的倍数，例如：32、64、128等。

                  Epoch是指模型对整个数据集进行学习的次数。Epoch设置不合理，对精度的影响如下：

                       Epoch过少，会导致模型参数不收敛，学习不到有效的参数。
 Epoch
                       Epcoh过多，会导致模型过拟合。

                  您可以根据训练过程中，验证集上模型效果的变化情况，合理选择Epoch的数目。


 模型权重问题

影响精度的模型权重类问题，主要包含以下2个方面：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司               174

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            精度调测




 问题类型         说明

              模型权重初始化是在模型训练开始前，为权重参数赋予初始值，是模型训练过程中的一个重要步
              骤。
 模型权重初
              如果模型的权重初始化方式与官方不一致，则可能导致模型在训练过程中的Loss值无法与官方的值
 始化
              对齐。
              建议您使用与官方一致的模型权重初始化方式。

              当进行迁移学习或需要加载预训练权重/骨干模型时，请确保加载正确的模型权重。
 预训练模型
 加载           建议您使用预训练模型进行简单的推理，查看推理结果是否正确，以验证是否加载了正确的模型权
              重。


 数据集问题

影响精度的数据集类问题，主要包含以下几个方面：

 问题类型                  说明

 数据集缺失                 常见于文件较多的数据集，包括文件丢失、文件损坏等。

 数据集存在脏数据              据集中存在标签错误、图像错误，或是存在 NaN/Inf等形式的数据。

                       数据集中某种类别的数据占数据集的绝大部分，其它类别的数据占数据集整体的一小部
 数据集不均衡
                       分。

 非官方数据集                使用的是非官方标准数据集。

 数据未进行预处理              很多数据集从官方网站下载下来后，需要对数据集进行预处理，才可以进行模型训练。


 算子精度问题

为验证某个算子在SDAA上是否存在精度问题，可以将它强制切换到CPU上执行。

切换算子到CPU上计算后，如果模型的精度符合预期，则表明此算子在SDAA上存在精度问题，请使用《DumpInfo工
具用户手册》收集模型中该算子的详细参数信息，并通过issue将相关信息反馈给太初元碁工程师，便于其快速复现和
修复。


     说明：

     DumpInfo是太初元碁提供的一款算子信息采集工具。该工具通过环境变量控制，可以保存算子库调用时的接
     口运行信息，例如：数据形状（Shape）和实际数据等。关于DumpInfo工具的详细信息，请参考
     《DumpInfo工具用户手册》。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司        175

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     精度调测




10.3 精度调试方法
10.3.1 模型迁移场景下的精度调试方法
本文主要介绍将模型迁移到太初AI加速卡上进行训练，出现精度问题时，如何进行精度调试。


     说明：

         关于精度异常的现象，请参考精度异常现象。

         关于精度异常的原因，请参考精度问题原因。



 前置知识

为更好地理解和解决迁移场景下的精度异常问题，建议您学习或者了解以下内容，便于后续进行精度异常定位：

 内容                 说明

                    模型训练过程中Loss出现NaN，通常是由于数值不稳定导致的计算异常。
                    具体表现为：在计算过程中产生了INF（无穷大）或对无效输入进行了数学运算（如负数开
                    平方、对非正数取对数、0除0等），这些操作会生成NaN（非数值）。
 NaN基础知识
                    在实数运算体系中，复数结果不会被保留而是直接转换为NaN。由于NaN具有传染性（任何
                    涉及NaN的计算结果都会变为NaN），一旦出现NaN，后续所有依赖该结果的计算都会被
                    污染。更多详细信息，可以参考NaN。

                    自动混合精度AMP分为两个部分：autocast 和 GradScaler。
                         autocast：负责将部分计算的数据类型转化为float16。

                         GradScaler：负责处理由于数值精度的降低带来的上溢出和下溢出现象。


                             说明：

                             GradScaler处理过程：
 自动混合精度
 AMP                               1. 在反向传播之前，对Loss进行放大。

                               2. 在梯度更新前，检查当前梯度中是否存在NaN：

                                      若存在NaN：则丢弃当前梯度，不进行更新。

                                      若不存在NaN：则将梯度进行相应的缩放，再进行梯度更新。


                    自动混合精度AMP的更多计算细节，请参考PyTorch官方文档。




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司             176

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    精度调测




 内容                 说明

                    针对float16类型的卷积和矩阵乘法的运算，TecoPytorch进行了深度优化，使用AMP可以
                    大幅度提升模型性能。
 在TecoPytorch            针对卷积计算，TecoPytorch仅使用float16进行计算，为避免低精度数据类型而导致
 上开启AMP                  的梯度溢出问题，需要开启AMP。
                         针对矩阵乘法计算，开启AMP可以获得较好的性能，并确保精度稳定。



 调试流程

在了解前置知识后，可以参考以下步骤进行精度异常的排查和定位。




                                         图1 精度调试流程


 步骤一：检查TecoPytorch上的训练配置信息是否与CUDA一致

  1. 检查rank数量，确保两者设置相同。模型调试时，建议将rank数量设置为1。

 2. 检查batch size、学习率等超参数，确保两者设置相同。

 3. 检查模型输入是否存在非规格化数。TecoPytorch不支持非规格化数，如果输入中存在非规格化数，需要手动将
   数据类型转换为float进行计算。
 4. 检查其它可能存在不一致的数据配置，例如：若要对齐两者第一个iter前向的中间值，需要两者均使用单进程的
   Dataloader。如果配置了多进程的Dataloader，会导致同一个batch的数据相同，但是顺序不同。


 步骤二：检查是否开启自动混合精度AMP

如果原始模型没有使用AMP，推荐您在TecoPytorch上开启AMP进行训练，以获取更佳的模型性能。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                  177

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  精度调测




  1. 检查训练是否开启了AMP。

       如果没有使用AMP，请开启AMP，重新进行训练。

       如果已使用AMP，请执行步骤2。

 2. 检查scale值。

       若scale值持续降低，出现梯度溢出现象，可检查输入数据是否存在异常值（如NaN或Inf）并进行输入异常
       处理，或者使用梯度裁剪提升训练稳定性。

              说明：

              使用PyTorch的 GradScaler.get_scale() 接口，可以获取scale值。


       若scale值无上述异常，请执行步骤三。

 步骤三：定位精度异常算子

使用Python调试器pdb、Hook函数打印异常数据和算子回落的方式，定位影响模型精度的算子。

  1. 定位精度异常的算子。

       方法一：使用Python调试器pdb同时对两者的代码进行断点调试，从而定位精度异常的算子。

       方法二：使用Hook调试函数打印模型的相关信息，根据算子的执行情况，定位精度异常的算子。关于Hook
       的介绍和使用，可参考Hook调试函数（详情请参考《TecoPyTorch用户手册（适配PyTorch 2.4.0）》的
       Hook使用介绍章节）章节和PyTorch官方文档中对应的API接口。以下代码展示如何使用Hook调试函数打印
       卷积算子在前向和反向中的执行情况。

          from functools import partial


          def observe_input_output_forward(module, module_input, module_output, name):
              if not hasattr(module, 'weight'):
                  return


              input = module_input[0]
              output = module_output
              weight = module.weight


              with torch.no_grad():
                  m = input.float().cpu().abs().max().item()
                  print(f"observe_input_output:::forward:::{name}:::input:::{m}")
                  o = output.float().cpu().abs().max().item()
                  print(f"observe_input_output:::forward:::{name}:::output:::{o}")


          def observe_input_output_backward(module, module_gradinput, module_gradoutput, name):
              if not hasattr(module, "weight") or not hasattr(module.weight, 'grad'):
                  return


              gradinput = module_gradinput[0]
              gradoutput = module_gradoutput[0]
              weightgrad = module.weight.grad




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                       178

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                       精度调测




              try:
                  with torch.no_grad():
                        print(f"observe_input_output:::backward:::{name}:::{module}:::gradinput {gradinput.
          data.cpu().abs().max()}")
                        print(f"observe_input_output:::backward:::{name}:::{module}:::gradoutput {gradoutpu
          t.data.cpu().abs().max()}")
                        print(f"observe_input_output:::backward:::{name}:::{module}:::weightgrad {weightgra
          d.data.cpu().abs().max()}")
              except:
                  pass


          for name, module in model.named_modules():
              if len(list(module.children())) == 0 and "conv" in str(module).lower():
                  module.register_forward_hook(partial(
                        observe_input_output_forward,
                        name=name))
                  module.register_full_backward_hook(partial(
                        observe_input_output_backward,
                        name=name))



       方法三：将算子逐一回落到CPU上进行计算，从而定位精度异常的算子。关于如何强制算子回落到CPU上计
       算，请参考强制算子回落CPU计算。
 2. 定位到精度异常的算子后，请使用《DumpInfo工具用户手册》收集模型中该算子的详细参数信息，并通过issue
   提交给太初元碁工程师。

尝试以上步骤后，如果Loss收敛，但模型在SDAA上的精度与CUDA/CPU上的精度相比，仍存在一点差距，则可能是
因为算子在SDAA上的底层实现，与CPU/CUDA等其它硬件平台的实现不同。此场景下，如果想继续提高精度，可以
尝试训练更长的轮次（epoch）。


     说明：

     如果epoch数量翻倍，对应的学习率衰减则需要减半。




10.3.2 模型开发场景下的精度调试方法
本文主要介绍当您自行研发的模型在训练过程中出现精度问题时，如何进行调试。

 前提条件

   待调试的模型，其训练程序可正常运行。

   模型训练日志可以正常输出，例如：可以观察到每次迭代（step）的Loss值等信息。

 调试流程

通常情况下，模型出现精度异常时，精度调试的流程如下：




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                 179

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           精度调测




                                        图1 模型精度调试流程


 步骤一：检查模型结构

模型结构是指训练模型时所使用的网络结构，是模型训练的基础。

在模型训练过程中出现精度异常时，您可以使用TensorBoard工具，可视化地检查模型结构中每个节点的名称、属
性、参数、输入输出等是否与官方模型结构相同。如果存在不一致的内容，建议您与官方模型结构保持一致，避免模
型精度异常。


     说明：



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     180

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            精度调测




     关于TensorBoard的使用方法，可参考TensorBoard官方说明。


 步骤二：检查模型组网

检查模型各个组件的代码实现是否与官方一致，如果存在不一致的内容，建议您参考官方代码进行修改。

模型各组件包括但不限于：

   优化器

   学习率调整策略

   损失函数

   评价指标

 步骤三：检查超参数

检查模型的超参数设置是否合理，较为关键的超参数包括：学习率、Batch Size、优化器超参和Epoch。

 学习率

您可以使用以下方式调整学习率：

   未更换优化器：可以根据Batch Size的大小，调整学习率。学习率应随Batch Size的增大而增大，减小而减小。

   更换优化器：需要根据已选择的优化器设置学习率，同时结合Batch Size大小，对学习率进行调整。

更换学习率后，您可以试运行，观察Loss曲线的下降情况，如果Loss曲线几乎不下降或是上升，则该学习率可能不合
适，需要重新调整。

 Batch Size

检查Batch Size设置是否合理，可以先从较小Batch Size开始，逐步增大。


     说明：

     在改变Batch Size的同时，您需要同步修改学习率。学习率应随Batch Size的增大而增大，减小而减小。


 优化器超参

针对优化器超参，请检查以下点：

   更换优化器后，建议使用默认的超参数。

   不同优化器的学习率的大小一般不相同，请根据选择的优化器，设置学习率。

 Epoch值



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司        181

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    精度调测




一个合理的Epoch值标准是Loss值不再减小，且Metrics不再上升，甚至开始下降。

     如果模型训练不收敛，可能是Epoch值过小，建议增大。

     如果模型训练出现过拟合，可能是Epoch值过大，建议减小。

 步骤四：检查数据集

数据集的相关设置控制着模型输入，可在以下方面进行检查。

 问题类型             处理措施

 数据集缺失            检查数据集文件的MD5码与官方数据是否相同。如果不同，建议重新下载数据集。

                  检查异常数据：
                      当数据集较小时，可对数据集进行完整检查。例如：
 数据集存在脏                   对于文本数据集，可直接将文本打印出来，查看是否存在 NaN/Inf 等异常值。
 数据
                          对于图像数据集，可将图像可视化，查看是否符合标签。

                      当数据集较大或是数据较多时，建议采用抽样的方式进行检查。


                  您可以打印所有类型的数据数量，或者对数据集进行可视化处理画出柱状图，从而查看数据集
 数据集不均衡
                  中不同类型数据的分布情况。

                  若您使用的是自制数据集，或是其他同类型的非官方数据集，您需要自行评估数据集质量，确
 非官方数据集
                  保数据集满足模型训练要求。如果无法评估或者确定数据集质量，建议您使用官方数据集。

 数据未进行预
                  请确保使用与官方相同的数据处理方式。
 处理


 步骤五：检查模型Loss曲线

Loss曲线反映了模型的收敛性，正常情况下，Loss曲线呈现下降趋势，且最后趋于平缓。

您可以通过观察Loss曲线，判断模型训练是否收敛、是否出现过拟合以及是否出现梯度爆炸等。Loss曲线异常及其调
试方式如下：

 问题类型                    处理措施

                         通常是由学习率设置过大导致，建议调小学习率。
 Loss曲线未呈现下降趋
 势                       如果训练需要使用较大的学习率，建议使用warm-up的方式，使学习率从小到大缓
                         慢上升。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司              182

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                精度调测




 问题类型                    处理措施

                         手动调整学习率，一般是调小学习率。
 Loss曲线出现异常数值
 （NaN/Inf）               若多次调整学习率后，Loss曲线仍出现异常值，您可以尝试调整                 loss_scale 至
                         一个较小的数值再重新进行训练。

 Loss曲线先下降，后上
                         训练可能出现了过拟合，建议您在Loss值趋于稳定的Epoch停止训练。
 升


 步骤六：验证精度Metrics指标

Metrics指标可以直观地反映模型的收敛情况，您可以通过对比Metrics指标，检查训练是否达到预期。

     Metrics指标正常：与官方指标差距在1%内，则精度调试结束。

     Metrics指标异常：建议您按照上述步骤一到步骤五，重新进行调试。


10.4 Hook调试函数
10.4.1 Hook使用介绍
在PyTorch框架中，Hook机制允许开发者在模型的前向传播或反向传播过程中，插入自定义的代码逻辑。通过Hook
机制，您可以在不改变网络结构的基础上，便捷地获取网络中间层的输出、查看及修改模型的参数以及梯度等信息。

本文主要介绍Hook类型及其使用方法。

 注意事项

     不当的Hook函数实现可能导致训练不稳定或难以预料的行为，请谨慎使用Hook函数。

     使用Hook函数时，尤其是在处理大型模型或长时间运行的训练时，需谨慎管理资源，避免内存泄漏。

     当模型中存在多个相同类型的模块时，需要正确注册和管理Hook，以免Hook混淆或重复执行。

 Hook类型

PyTorch提供了两种类型的Hook：针对             Tensor 的Hook和针对   nn.Module 的Hook。


 Tensor Hook

用于在某个Tensor的梯度计算完成后插入自定义操作。这类Hook常用于监控或修改梯度值，可帮助开发者调试梯度消
失、爆炸问题。

 注册函数：register_hook(hook_fn)

Tensor Hook的注册函数是        register_hook(hook_fn) 。用于在某个Tensor的梯度计算完成后插入自定义操
作。



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                           183

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            精度调测




使用示例：

   import torch
   import torch_sdaa


   device = torch.device('sdaa')


   def grad_hook(grad):
       print(f"Gradient: {grad}")


   x = torch.ones(2, 2, requires_grad=True).to(device)
   y = x * 2
   y_hook = y.register_hook(grad_hook)    # 注册hook并返回该hook的handle
   z = y.sum()
   z.backward()        # 触发反向传播，进而调用grad_hook
   y_hook.remove()     # 取消hook注册的操作




 Module Hook

用于在模块执行期间插入自定义操作。Module Hook包含三类注册函数：

      register_forward_pre_hook : 在模块的前向传播开始前执行，用于观察或修改输入数据。

      register_forward_hook : 在模块的前向传播完成后执行，用于获取和分析中间输出特征。

      register_full_backward_hook : 在模块的反向传播过程中执行，允许访问和修改模块的输入梯度。


 注册函数1：register_forward_pre_hook(hook_fn)

在 nn.Module 的前向传播开始前插入自定义操作，用于观察或修改输入数据。

使用示例：

   import torch
   import torch_sdaa
   from torch import nn


   device = torch.device('sdaa')


   def forward_pre_hook(module, input):
       print(f'Inside {module.__class__.__name__}, input shape: {input[0].shape}')


   relu = nn.ReLU().to(device)
   relu_hook = relu.register_forward_pre_hook(forward_pre_hook)   # 注册hook并返回该hook的handle
   x = torch.randn(2, 2, 2).to(device)
   y = relu(x)
   relu_hook.remove()    # 取消hook注册的操作




 注册函数2：register_forward_hook(hook_fn)

在 nn.Module 的前向传播完成后插入自定义操作，用于获取和分析中间输出特征。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                184

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                           精度调测




使用示例：

   import torch
   import torch_sdaa
   from torch import nn


   device = torch.device('sdaa')


   def forward_hook(module, input, output):
       print(f'Inside {module.__class__.__name__}, '
             f'input shape: {input[0].shape}, output shape: {output.shape}')


   relu = nn.ReLU().to(device)
   relu_hook = relu.register_forward_hook(forward_hook)   # 注册hook并返回该hook的handle
   x = torch.randn(2, 2, 2).to(device)
   y = relu(x)
   relu_hook.remove()   # 取消hook注册的操作




 注册函数3：register_full_backward_hook(hook_fn)

在 nn.Module 模块的反向传播过程中插入自定义操作，允许访问和修改模块的输入梯度。

使用示例：

   import torch
   import torch_sdaa
   from torch import nn


   device = torch.device('sdaa')


   def backward_hook(module, grad_in, grad_out):
       print(f'Inside {module.__class__.__name__}, '
             f'grad_input shape: {grad_in[0].shape}, '
             f'grad_output shape: {grad_out[0].shape}')


   relu = nn.ReLU().to(device)
   relu_hook = relu.register_full_backward_hook(backward_hook)   # 注册hook并返回该hook的handle
   x = torch.randn(2, 2, 2, requires_grad=True).to(device)
   y = relu(x)
   grad = torch.ones_like(y)
   y.backward(grad)
   relu_hook.remove()   # 取消hook注册的操作




10.4.2 Hook使用示例
本节以模型开发章节的模型为例，介绍如何在模型中添加一个register_forward_hook函数，该Hook函数在
nn.Module的前向传播完成后插入自定义操作，可用于监控中间输出特征数据是否异常。


 操作步骤

  1. 注册register_forward_hook函数，记录某一层的输出特征图。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                               185

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         精度调测




       feature_map_histories = []


       def hook_feature_maps(module, input, output):
           feature_map_histories.append(output.detach().cpu())


       # 假设需要记录第一层Conv2d的输出特征图
       model.conv1.register_forward_hook(hook_feature_maps)



 2. 打印记录的特征图的平均绝对值，提供模型学习动态的粗略指标。


       # 每10个batch打印一次特征图的统计信息
       if batch_idx % 10 == 0:
           avg_abs = torch.mean(torch.abs(torch.cat(feature_map_histories))).item()
           print(f'Epoch: {epoch}, Batch: {batch_idx}, Avg. Abs. Feature Map Val: {avg_abs}')
           feature_map_histories.clear()     # 清空历史记录，准备下一组数据




 完整示例代码

   import torch   #torch
   import torch_sdaa    #导入torch_sdaa
   import numpy as np
   from torch.utils.data import DataLoader
   from torchvision import transforms
   from torchvision import datasets
   import torch.nn.functional as F


   device = torch.device('sdaa')


   batch_size = 64
   learning_rate = 0.01
   momentum = 0.5
   EPOCH = 10


   transform = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,))])


   train_dataset = datasets.MNIST(root='./data/mnist', train=True, transform=transform, download=True)
   test_dataset = datasets.MNIST(root='./data/mnist', train=False, transform=transform, download=True)   #
   train=True训练集，train=False测试集
   train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
   test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)


   class Net(torch.nn.Module):


       def __init__(self):
           super(Net, self).__init__()
           self.conv1 = torch.nn.Sequential(
                torch.nn.Conv2d(1, 10, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
           )
           self.conv2 = torch.nn.Sequential(
                torch.nn.Conv2d(10, 20, kernel_size=5),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               186

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         精度调测




             )
             self.fc = torch.nn.Sequential(
                 torch.nn.Linear(320, 50),
                 torch.nn.Linear(50, 10),
             )


         def forward(self, x):
             batch_size = x.size(0)
             x = self.conv1(x)   # 一层卷积层，一层池化层，一层激活层
             x = self.conv2(x)   #一层卷积层，一层池化层，一层激活层
             x = x.flatten(1)    # flatten变成全连接网络需要的输入 (batch, 20,4,4) ==> (batch,320), -1 此处自动算出的
   是320
             x = self.fc(x)
             return x   # 最后输出的是维度为10的，也就是（对应数学符号的0~9）


   model = Net().to(device)


   feature_map_histories = []


   def hook_feature_maps(module, input, output):
         feature_map_histories.append(output.detach().cpu())


   # 假设我们对第一个卷积层的输出感兴趣
   model.conv1.register_forward_hook(hook_feature_maps)
   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)



   def train(epoch):
         running_loss = 0.0
         running_total = 0
         running_correct = 0
         for batch_idx, data in enumerate(train_loader, 0):
             inputs, target = data[0].to(device), data[1].to(device)
             optimizer.zero_grad()


             # forward + backward + update
             outputs = model(inputs.to(device))
             loss = criterion(outputs, target)


             loss.backward()
             optimizer.step()


             running_loss += loss.item()
             _, predicted = torch.max(outputs.data, dim=1)
             running_total += inputs.shape[0]
             running_correct += (predicted == target).sum().item()


             if batch_idx % 300 == 299:
                 print('[%d, %5d]: loss: %.3f , acc: %.2f %%'
                        % (epoch + 1, batch_idx + 1, running_loss / 300, 100 * running_correct / running_tota
   l))
                 running_loss = 0.0
                 running_total = 0
                 running_correct = 0


             # 每10个batch打印一次特征图的统计信息
             if batch_idx % 10 == 0:
                 avg_abs = torch.mean(torch.abs(torch.cat(feature_map_histories))).item()




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                                187

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                    精度调测




               print(f'Epoch: {epoch}, Batch: {batch_idx}, Avg. Abs. Feature Map Val: {avg_abs}')
               feature_map_histories.clear()   # 清空历史记录，准备下一组数据
      torch.save(model.state_dict(), './model_mnist.pth')


   if __name__ == '__main__':
      train(epoch=1)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                           188

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   性能调优
