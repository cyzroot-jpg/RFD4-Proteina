---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p09
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第9部分 (ch9-compiler-graph-compile)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "10764-11491"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, compiler, graph-compile, operator-support]
---

# TecoPyTorch 用户手册 v3.2.0（第9部分）

> 原文行范围：`10764-11491`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

9. Compiler图编译优化
9.1 使用说明
TecoPyTorch Compiler是基于PyTorch框架的torch.compile功能开发的、高度适配太初AI加速卡的图编译优化工
具，用于提升代码和模型的运行效率。

TecoPyTorch Compiler对原生torch.compile方法中的后端编译器inductor进行了扩展，除支持原生
  torch.compile 的主要功能外，同时针对太初AI加速卡硬件特性，引入了更多的编译加速手段，从而提高计算效
率，加速模型执行。

 函数接口说明

TecoPyTorch Compiler通过以下接口实现图编译优化功能。


   torch.compile(model=None, *, backend='teco_inductor', fullgraph=False, dynamic=None, mode=None, options
   =None, disable=False)




 参数解释

 参数名               说明

                   需要优化的模型或函数。

                           说明：
 model
                           TecoPyTorch Compile通过对模型中的算子进行融合，加速模型运行。当前
                           TecoPyTorch Compile只支持对Pointwise类和Reduction类进行算子编译融合。详
                           情可参考Compiler可编译算子说明。


                   优化模型或函数使用的编译后端。针对TecoPyTorch，其编译后端为 teco_inductor 。

                           说明：
 backend
                           TecoPyTorch Compile的编译后端，除支持原生                 torch.compile 功能外，同时
                           针对太初AI加速卡特性适配了更多的编译优化手段。详情可参考Compiler编译配置选
                           项。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  160

TecoPyTorch用户手册（适配PyTorch 2.7.1）                              Compiler 图编译优化




 参数名                 说明

                     是否将所有目标函数的计算图编译到一张计算图中。
                          False（默认值）：只尝试发现函数中可编译的区域并对其进行优化，不会将所有目标函数
 fullgraph                编译到一张图。
                          True：将所有目标函数编译到一张计算图中。此模式下，要求目标函数的整个函数都能被
                          捕获到一个图中，如果不能（即存在图形中断），则会引发错误。


 dynamic             预留参数，暂不支持设置。

 mode                预留参数，暂不支持设置。

 option              预留参数，暂不支持设置。

 disable             预留参数，暂不支持设置。


 使用示例

 示例一：编译函数

以下内容展示如何在代码中使用TecoPyTorch Compiler优化函数，加速代码运行。


     说明：

     为便于后续使用Profiler工具，查看开启Compile后的算子融合，建议您在代码中开启Profiler。具体方法，
     可参考开启Profiler。


原始代码：

   import torch
   import torch_sdaa


   a = torch.randn(100, 100).to('sdaa')
   b = torch.randn(100, 100).to('sdaa')
   c = torch.randn(100, 100).to('sdaa')


   def origin_fn(x, y, z):
       add = x + y
       mul = torch.mul(x, z)
       sub = torch.sub(mul, add)
       out = sub.ceil()
       return out



在原始代码中添加 torch.compile 代码，将包含 add 、 mul 、 sub 和 ceil 算子的函数传递给
 torch.compile 进行编译优化。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司               161

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     Compiler 图编译优化




   import torch
   import torch_sdaa


   a = torch.randn(100, 100).to('sdaa')
   b = torch.randn(100, 100).to('sdaa')
   c = torch.randn(100, 100).to('sdaa')


   def origin_fn(x, y, z):
       add = x + y
       mul = torch.mul(x, z)
       sub = torch.sub(mul, add)
       out = sub.ceil()
       return out
   # 添加compile代码
   compiled_fn = torch.compile(origin_fn, backend='teco_inductor')
   compiled_result = compiled_fn(a, b, c)



运行添加 torch.compile 后的代码，使用Profiler可视化工具，可以看到经过 torch.compile 编译优化后，
四个算子融合为一个算子，相比之前减少了三次数据搬运的时间，运行效率更高。




                                      图1 使用torch.compile编译函数前的算子调用




                                     图2 使用torch.compile编译函数后的算子调用


 示例二：模型编译

以下内容以Resnet50模型训练为例，展示如何使用TecoPyTorch Compiler加速模型训练。


     说明：

     为便于后续使用Profiler工具，查看开启Compile的算子融合，建议您在代码中开启Profiler。具体方法，可
     参考开启Profiler。


原始模型：

   import torch
   import torch_sdaa




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                      162

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                           Compiler 图编译优化




   import numpy as np
   from torch.utils.data import DataLoader
   import torchvision
   from torchvision import transforms
   from torchvision import datasets
   import torch.nn.functional as F
   import torch.nn as nn
   import time


   device = torch.device('sdaa')


   batch_size = 64
   learning_rate = 0.01
   momentum = 0.5
   EPOCH = 10


   transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.ToTensor(),
        transforms.Normalize((0.485, 0.456, 0.406), (0.229, 0.224, 0.225))])


   train_dataset = datasets.CIFAR10(root='./data/cifar10', train=True, download = True，transform=transfor
   m)   # 若本地没有CIFAR10数据集，则需要加上download=True
   test_dataset = datasets.CIFAR10(root='./data/cifar10', train=False, download = True，transform=transfor
   m)   # train=True训练集，train=False测试集
   train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
   test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)


   myModel = torchvision.models.resnet50()
   inchannel = myModel.fc.in_features
   myModel.fc = nn.Linear(inchannel, 10)


   model = myModel.to(device)


   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)



   def train(epoch):
        running_loss = 0.0
        running_total = 0
        running_correct = 0
        train_time = []
        start_time = time.time()
        for batch_idx, data in enumerate(train_loader, 0):
            inputs, target = data[0].to(device), data[1].to(device)
            inputs = inputs.contiguous(memory_format=torch.channels_last)
            optimizer.zero_grad()


            outputs = model(inputs.to(device))
            loss = criterion(outputs, target)


            loss.backward()
            optimizer.step()
            end_time = time.time()
            train_time.append(end_time-start_time)
            running_loss += loss.item()
            _, predicted = torch.max(outputs.data, dim=1)




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                             163

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            Compiler 图编译优化




            running_total += inputs.shape[0]
            running_correct += (predicted == target).sum().item()


            if (batch_idx >=11): break
            start_time = time.time()


        print('avg train time is ', np.mean(train_time[5:]) * 1000, "ms")
   if __name__ == '__main__':
        train(epoch=1)



在原始模型中添加 torch.compile 代码，将模型传递给 torch.compile 进行编译优化。

   import torch
   import torch_sdaa
   import numpy as np
   from torch.utils.data import DataLoader
   import torchvision
   from torchvision import transforms
   from torchvision import datasets
   import torch.nn.functional as F
   import torch.nn as nn
   import time


   device = torch.device('sdaa')


   batch_size = 64
   learning_rate = 0.01
   momentum = 0.5
   EPOCH = 10


   transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.ToTensor(),
        transforms.Normalize((0.485, 0.456, 0.406), (0.229, 0.224, 0.225))])


   train_dataset = datasets.CIFAR10(root='./data/cifar10', train=True, download = True, transform=transfor
   m)   # 若本地没有CIFAR10数据集，则需要加上download=True
   test_dataset = datasets.CIFAR10(root='./data/cifar10', train=False, download = True, transform=transfor
   m)   # train=True训练集，train=False测试集
   train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
   test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)


   myModel = torchvision.models.resnet50()
   inchannel = myModel.fc.in_features
   myModel.fc = nn.Linear(inchannel, 10)


   model = myModel.to(device)


   # 开启Compile模型优化，若不开启Compile将torch.compile注释
   model = torch.compile(model, backend='teco_inductor')


   criterion = torch.nn.CrossEntropyLoss().to(device)
   optimizer = torch.optim.SGD(model.parameters(), lr=learning_rate, momentum=momentum)


   def train(epoch):
        running_loss = 0.0




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               164

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           Compiler 图编译优化




      running_total = 0
      running_correct = 0
      train_time = []
      start_time = time.time()
      for batch_idx, data in enumerate(train_loader, 0):
           inputs, target = data[0].to(device), data[1].to(device)
           inputs = inputs.contiguous(memory_format=torch.channels_last)
           optimizer.zero_grad()


           outputs = model(inputs.to(device))
           loss = criterion(outputs, target)


           loss.backward()
           optimizer.step()
           end_time = time.time()
           train_time.append(end_time-start_time)
           running_loss += loss.item()
           _, predicted = torch.max(outputs.data, dim=1)
           running_total += inputs.shape[0]
           running_correct += (predicted == target).sum().item()


           if (batch_idx >=11): break
           start_time = time.time()


      print('avg train time is ', np.mean(train_time[5:]) * 1000, "ms")
   if __name__ == '__main__':
      train(epoch=1)



经过实验测试：

   开启 torch.compile 前，模型在单SDAA计算设备上的平均训练时间如下：


          说明：

          实际输出的平均训练时间受数据波动因素及SDAA计算设备工作状况影响，可能会存在一定波动。


       avg train time is 5118.187295065985 ms


   开启 torch.compile 后，模型在单SDAA计算设备上的平均训练时间如下：


          说明：

          实际输出的平均训练时间受数据波动因素及SDAA计算设备工作状况影响，可能会存在一定波动。


       avg train time is 5005.288883491799 ms



通过Profiler可视化工具，可以看到开启 torch.compile 后，ResNet50模型的Conv、BatchNorm和ReLU算子
中的BatchNorm和ReLU被融合成了一个Kernel，从而减少了启动时间，加速模型计算。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                         165

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                Compiler 图编译优化




                                   图3 torch.compile开启前的模型算子调用




                                   图4 torch.compile开启后的模型算子调用




9.2 可编译算子说明
TecoPyTorch Compiler目前支持对Pointwise类、Reduction类和Foreach类算子进行编译融合，且在编译融合过
程中支持广播特性。


     说明：

     对于暂不支持融合的算子，例如：Conv类算子和GEMM类算子，编译时会回退至非融合实现，调用
     TecoPytorch中的算子接口进行计算。



 可编译算子列表




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                    166

TecoPyTorch用户手册（适配PyTorch 2.7.1）                              Compiler 图编译优化




 类型                       算子名称

 Pointwise                    add

                              sub

                              mul

                              div

                              le

                              lt

                              ge

                              gt

                              eq

                              ne

                              abs

                              sin

                              cos

                              neg

                              reciprocal

                              exp

                              exp2

                              expm1

                              erf

                              sqrt

                              rsqrt

                              log1p

                              tan

                              tanh

                              signbit

                              pow

                              log

                              round




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司               167

TecoPyTorch用户手册（适配PyTorch 2.7.1）                              Compiler 图编译优化




 类型                       算子名称
                              floor

                              ceil

                              trunc

                              truncdiv

                              fmod

                              lgamma

                              acos

                              asin

                              asinh

                              atan2

                              atan

                              atanh

                              copysign

                              hypot

                              erfc

                              log10

                              relu

                              minimum

                              maximum

                              squre

                              where

                              mod

                              to(dtype)

                              logical_and

                              logical_or

                              sigmoid

                              sign




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司               168

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            Compiler 图编译优化




 类型                       算子名称

                              sum

                              mean

 Reduction                    var

                              var_mean

                              amax


                              _foreach_add

                              _foreach_mul

                              _foreach_div

                              _foreach_neg

                              _foreach_abs

                              _foreach_sqrt

                              _foreach_maximum

                              _foreach_minimum
 Foreach
                              _foreach_clamp_max

                              _foreach_clamp_min

                              _foreach_reciprocal

                              _foreach_copy

                              _foreach_addcmul

                              _foreach_addcdiv

                              _foreach_lerp

                              _foreach_pow



9.3 编译配置选项说明
针对太初AI加速卡的硬件特性，TecoPyTorch Compiler的编译后端提供了以下编译选项，用于加速编译。


     说明：

     使用TecoPyTorch Compile功能时，只有当您需要更改编译选项的默认值时，才需要显式地指定待更改的配
     置项；不指定时，TecoPyTorch Compile使用编译选项的默认值。



文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司               169

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                   Compiler 图编译优化




 配置选项                         说明

                              是否允许PyTorch Profiler读取Kernel运行信息。
                                   True：允许。
 enable_kernel_profile
                                   False（默认值）：不允许。


                              是否在运行编译计算图前后，进行线程同步，方便测试Kernel性能。
                                   True：进行线程同步。
 debug_sync_graph
                                   False（默认值）：不进行线程同步。


                              是否在编译优化及代码生成过程中使用128位SIMD指令。
                                   True（默认值）：使用128位SIMD指令。
 use_simd128
                                   False：不使用128位SIMD指令。


                              是否在编译优化及代码生成过程中使用高性能算法，提高计算速度。
                                   True（默认值）：使用高性能算法。开启高性能算法，可能会导致部分算子精
 higher_performance                度下降。
                                   False：不使用高性能算法。


                              是否在代码生成过程中使用表计算方法，提高计算速度。
                                   True（默认值）：使用查表法计算。开启查表法，可能导致部分算子精度下
 use_table                         降。
                                   False：不使用查表法计算。



 使用示例

如果您需要更改编译选项的默认值，可在 torch.compile 代码前，显式地指定待更改的配置项。示例如下：

   import torch
   import torch_sdaa


   torch_sdaa._inductor.config.teco.enable_kernel_profile = True
   torch_sdaa._inductor.config.teco.debug_sync_graph = True
   torch_sdaa._inductor.config.teco.use_simd128 = True
   torch_sdaa._inductor.config.teco.higher_performance = True
   torch_sdaa._inductor.config.teco.use_table = True


   a = torch.randn(100, 100).to('sdaa')
   b = torch.randn(100, 100).to('sdaa')
   c = torch.randn(100, 100).to('sdaa')


   def origin_fn(x, y, z):




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                    170

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     Compiler 图编译优化




       add = x + y
       mul = torch.mul(x, z)
       sub = torch.sub(mul, add)
       out = sub.ceil()
       return out


   compiled_fn = torch.compile(origin_fn, backend='teco_inductor')


   compiled_result = compiled_fn(a, b, c)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                      171

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           精度调测
