---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p11
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第11部分 (ch11-performance-tuning)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "12461-12989"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, profiler, performance-tuning]
---

# TecoPyTorch 用户手册 v3.2.0（第11部分）

> 原文行范围：`12461-12989`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

11. 性能调优
11.1 Profiler使用介绍
11.1.1 开启Profiler
Profiler是PyTorch的性能分析工具，用于在模型训练或推理过程中采集函数和算子的执行时间等信息，以便进行性能
瓶颈分析及针对性的性能优化。TecoPyTorch对PyTorch原生Profiler进行了适配，扩展了Profiler的功能，使其能够
在太初AI加速卡上统计函数的计算时间等信息。

本节介绍如何在TecoPyTorch框架中开启Profiler功能。


     说明：

     TecoPyTorch的Profiler用法与PyTorch原生的Profiler基本一致。关于PyTorch原生Profiler使用介绍，可参
     考PyTorch官网说明。


 操作步骤

  1. 在模型代码中，创建Profiler实例，并定义Profiler相关参数。


       save_path="./profiler_file_dir"
       p = torch.profiler.profile(
           activities=[
                torch.profiler.ProfilerActivity.CPU,
                torch.profiler.ProfilerActivity.SDAA,
           ],
           schedule=torch.profiler.schedule(
                       wait=1,
                       warmup=1,
                       active=1,
                       repeat=1),
           record_shapes=True,
           on_trace_ready=torch.profiler.tensorboard_trace_handler(save_path))


   参数说明：

     参数               类型            说明

                                    指定Profiler所要分析的设备，默认是 ProfilerActivity.CPU 和
                                     ProfilerActivity.CUDA 。
     activities       iterable
                                    使用时需要将 ProfilerActivity.CUDA 改成
                                     ProfilerActivity.SDAA 。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                       189

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   性能调优




     参数                类型          说明

                                   定义Profiler在模型训练过程中的调度策略。通过指定不同的参数，可以控制
                                   Profiler开始工作前的等待次数、何时进行预热迭代、何时进行活跃迭代以及是
                                   否重复Profiler调度等。
                                   例如：设置 wait=1,warmup=1,active=2,repeat=1 ，表示Profiler将
                                   跳过第一次迭代，在第二次迭代进行预热，在第三次和第四次迭代记录数据，
                       Callabl     整个Profiler调度结束后将再重复一次。
     schedule
                       e
                                         说明：

                                         关于 torch.profiler.schedule 函数参数的详细说明，可参考
                                         TORCH.PROFILER。




                                   是否记录算子的形状信息。
     record_sh                          True：记录算子的形状信息。
                       bool
     apes
                                        False：不记录算子的形状信息。


     on_trace_         Callabl
                                   将Profiler收集的性能数据保存为TensorBoard可以读取的格式。
     ready             e

 2. 在需要进行采集性能数据的功能模块，开启Profiler。


       p.start()
       #
       #for i in range(N):
       #    some_functions you'd like to profile
       #    p.step()
       #
       p.stop()


   其中：

           prof.start() ：开始记录性能数据。

           prof.stop() ：结束记录性能数据。

           prof.step() ：指示Profiler进入下一个 batch。


 完整示例

以模型开发章节的手写数字识别模型为例，定义并开启Profiler的完整程序如下：

   import torch    #torch
   import torch_sdaa    #导入torch_sdaa




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                             190

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         性能调优




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


   train_dataset = datasets.MNIST(root='./data/mnist', train=True, transform=transform)
   test_dataset = datasets.MNIST(root='./data/mnist', train=False, transform=transform)
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
           )
           self.fc = torch.nn.Sequential(
                torch.nn.Linear(320, 50),
                torch.nn.Linear(50, 10),
           )


       def forward(self, x):
           batch_size = x.size(0)
           x = self.conv1(x)
           x = self.conv2(x)
           x = x.flatten(1)
           x = self.fc(x)
           return x



   model = Net().to(device)


   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)



   def train(epoch):
       running_loss = 0.0
       running_total = 0
       running_correct = 0




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                              191

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         性能调优




         # 定义profiler
         save_path="./profiler_file_dir" #profiler文件的保存路径
         p = torch.profiler.profile(
             activities=[
                  torch.profiler.ProfilerActivity.CPU,
                  torch.profiler.ProfilerActivity.SDAA,
             ],
             schedule=torch.profiler.schedule(
                          wait=1,
                          warmup=1,
                          active=1,
                          repeat=1),
             record_shapes=True,
             on_trace_ready=torch.profiler.tensorboard_trace_handler(save_path))
         # 启动Profiler
         p.start()


         for batch_idx, data in enumerate(train_loader, 0):
             inputs, target = data[0].to(device), data[1].to(device)
             optimizer.zero_grad()


             # forward + backward + update
             outputs = model(inputs.to(device))
             loss = criterion(outputs, target)


             loss.backward()
             optimizer.step()


             # 对前五个step进行profile
             if batch_idx<5:
                  p.step()
             elif batch_idx==5:
                  p.stop()


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


         torch.save(model.state_dict(), './model_mnist.pth')



   if __name__ == '__main__':
         train(epoch=1)




11.1.2 性能数据可视化
Profiler运行结束后，会将所有采集到的性能数据生成为                             chrome trace 格式的JSON文件。




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                                192

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                性能调优




 查看性能数据

  1. 在浏览器中，输入https://ui.perfetto.dev/，或about:tracing。

 2. 加载Profiler产生的JSON文件（如          trace.json ），对性能数据进行可视化分析。


     说明：

     可使用以下快捷键进行操作：W 放大，S 缩小， A 左移， D 右移。




                                        图1 性能数据可视化

可视化性能数据说明如下：

 位置和标
              说明
 号

 1            主进程的Python线程。显示主进程里Python线程的事件（即函数调用信息）。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司          193

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                  性能调优




 位置和标
              说明
 号

              线程上的事件。包括CPU和SDAA计算设备上存在的事件。
                   CPU端的事件：

                      PyTorch的aten接口：名称以     aten:: 或者
                        autograd::engine::evaluate_function 开头。

                      TecoPyTorch接口：名称以     sdaa:: 开头。

                      太初元碁算子加速库接口：名称以 tecoblas:: 、 tecodnn:: 和
                       tecorand:: 开头。
 2
                      太初元碁集合通信库接口：名称以 tccl:: 开头。

                      SDAARuntime接口：名称以      sdaart:: 开头。

                   SDAA计算设备端的事件（此类事件名称没有特定的前缀）：

                      gpu_memcpy：设备内存拷贝。

                      gpu_memset：设备内存设置。

                      kernel：设备上的Kernel执行。


              事件的详细信息。
 3            当单击一个事件时，会在可视化窗口下方区域显示其详细信息，例如：事件名称、类别、耗时和函
              数参数等。


 后续操作

如果定位到某个算子的计算存在异常或者性能不能满足需求，欢迎您通过issue将相应算子的Profiler文件提交给太初
元碁工程师，便于后续复现和解决问题。


11.2 性能优化
本节主要介绍在TecoPyTorch框架中对模型性能进行调优的流程和方法。

 调优流程

在TecoPyTorch框架中进行性能优化的整体流程如下图所示：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司            194

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           性能调优




                                         图1 性能优化流程


 步骤一：获取基准性能数据

基准性能数据是评估性能的标准参考数据。您可以参考按照以下步骤获取基准性能数据：

  1. 固定硬件参数（如CPU频率、太初AI加速卡频率）以及软件环境配置，确保这些要素在测试过程中保持一致。

 2. 在相同的环境下多次执行模型代码，观察并记录模型的典型性能数据，包括但不限于单步耗时、吞吐量等关键指
   标。在收集到一系列稳定的数据后，将这些数据作为性能调优的基准。

 步骤二：分析性能瓶颈

使用Profiler采集性能数据，对模型进行性能分析，了解模型的性能瓶颈。

常见的性能瓶颈：

   SDAA计算设备未支持的算子，在CPU上运行耗时占比很大。

   模型中DataLoader环节，耗时占比较大。

   模型中存在与 data_format 强相关的算子，且 data_format 为NCHW。

   模型中含有卷积算子，输入和权重为 torch.contiguous_format 格式。

   模型中存在由小算子组合而成的功能模块。

   模型中已支持的算子，在SDAA计算设备上运行耗时占比较大。


         说明：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     195

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                性能调优




          算子耗时占比较大，通常涉及底层算子的支持和优化，您可以收集相关算子信息，联系太初技术支持人
          员。


 步骤三：采用合适的策略进行优化

针对常见的性能瓶颈，常用的优化手段如下：

   启用DataLoader多进程加载数据

   转换数据格式

   开启自动混合精度训练AMP

   转换卷积算子权重格式

   使用自定义算子

 启用DataLoader多进程数据加载

PyTorch的DataLoader类支持多进程，在数据预处理耗时或数据集较大的情况下，使用多进程可以加快数据集的加载
速度，减少主进程等待读取数据的时间。

在TecoPyTorch框架中，可以通过设置 num_workers 参数的方式，启用DataLoader多进程加载数据。


       说明：

        num_workers 参数设置过大，可能会导致死锁现象。


       请根据机器逻辑线程数和实际性能提升效果，设置合理的值。



   # 使用DataLoader，并设置num_workers参数来启用多进程
   data_loader = DataLoader(
       dataset,
       batch_size=32,
       shuffle=True,
       num_workers=4,          # 启用4个进程加载数据
       pin_memory=True,        # 将数据复制到锁页内存中以加速数据传输
   )




 转换数据格式

在SDAA计算设备上，数据格式为NHWC比NCHW具有更高的性能。

如果在Profiler中观察到一些算子的输入数据格式为NCHW，可通过修改模型脚本代码，将其转换为NHWC格式。使用
示例如下：


       提示：




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司         196

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          性能调优




     在模型计算过程中，中间一些层的输出值可能会转回NCHW格式，需要再添加转换代码，使NHWC格式继续
     保持下去。


   t=t.to(memory_format=torch.channels_last) # 对于4D Tensor
   t=t.unqueeze(2).to(memory_format=torch.channels_last) # 对于3D Tensor




 开启自动混合精度训练

使用自动混合精度训练AMP可以减少显存使用，提升模型的训练速度。AMP的详细介绍及使用，可参考自动混合精度
训练AMP。

 转换算子权重格式

对于图像和语音领域常用的卷积神经网络模型，通常会调用Conv2D、Conv1D等算子，您可以将卷积的权重设置成
CHWN格式，从而减少中间的格式转换，提高计算效率。

设置以下环境变量，转换卷积算子权重格式为CHWN。

   export SET_CONV2D_WEIGHT_CHWN=1 #将Conv2d和ConvTranspose2d的权重设置为CHWN格式
   export SET_CONV1D_WEIGHT_CHWN=1 #将Conv1d和ConvTranspose1d的权重设置为CHWN格式




 使用自定义算子

模型中若存在使用多个小算子组合实现的模块功能或者某些API性能未达标时，您可以基于SDAA C开发融合算子或高
性能算子对其进行优化，并将开发的算子接入TecoPyTorch框架。


     说明：

         关于如何使用SDAA C开发算子，可参考SDAA C编程指南（详情请参考《SDAA C编程指南》的概述章
         节）。
         关于如何将自定义算子接入TecoPyTorch，可参考自定义算子接入。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                 197

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                       内存分析
