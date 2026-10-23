---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p08
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第8部分 (ch8-model-training)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "9045-10763"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, amp, ddp, distributed-training, cpu-fallback]
---

# TecoPyTorch 用户手册 v3.2.0（第8部分）

> 原文行范围：`9045-10763`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

8. 模型训练
8.1 自动混合精度训练AMP
8.1.1 AMP简介
自动混合精度AMP（Automatic Mixed Precision）是深度学习模型训练过程中优化计算精度的一种方法。即在计算
过程中自动为算子选择合适的浮点精度，在保证训练精度不损失的前提下，提高模型训练的速度和效率。

在太初AI加速卡上，我们推荐使用混合精度的方式进行训练，以获取更佳的精度。

 原理介绍

在深度学习中，常用的浮点精度有三种：32位单精度浮点数（float32）和16位半精度浮点数（float16）。float32使
用32位（4字节）二进制位存储一个实数，float16使用16位（2字节）进行存储。




                                     图1 float32 和 float16的数据格式

对比float32和float16两种数据类型，float16具有以下优势：

  1. 内存占用少：float16占用的存储空间比float32小 ，可以训练更大的网络模型或者使用更大的bach_size进行模
   型训练。
 2. 计算速度快：float16比float32的计算速度快，在不要求计算精度时，使用float16可以提高深度学习模型的训练
   和推理速度。

但使用float16会存在以下问题：

  1. 数据溢出：float16表示的数据动态据范围比float32小，因此使用float16进行计算时，容易出现数据溢出的问
   题。
 2. 舍入误差：当网络模型的反向梯度很小时，由float32转换到float16会小于当前区间内的最小间隔，导致数据溢
   出。如0.00006666666在使用float32进行存储时可以正常表示，但转换到float16后会表示成0.000067，不满
   足FP16最小间隔的数会强制舍入。

针对使用float16引入的问题，可以使用自动混合float32与float16和权重备份（Weight Backup）、损失缩放（Loss
Scaling）进行解决：

  1. 自动混合精度计算：使用float16进行乘法计算和存储，使用float32进行加法计算，从而避免累加误差。

 2. 权重备份：复制一份float32的权重参数，用于训练时更新参数，解决舍入误差问题。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司            134

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                   模型训练




 3. 损失缩放：反向传播前，将Loss手动放大 2n 倍，减少数据溢出的问题。反向传播后，将权重缩小 2n 倍，恢复
   正常数值。

 工作过程

使用自动混合精度训练一个float32的模型时，会自动对精度要求较高的算子使用 float32 进行计算，对精度要求不高
的算子使用 float16 进行计算，从而提高模型训练速度同时降低存储空间。这样可以在不改变模型、不降低模型训练精
度的前提下，缩短训练时间，降低存储需求，从而支持更多的 batch_size、更大模型和更大尺寸的输入进行训练。自
动混合精度训练的基本过程如下：

  1. 复制一份float32的初始权重参数。

 2. 初始化缩放系数。

 3. 自动混合精度训练，每个迭代执行一次：

     a. 将参数和数据转为float16。

     b. 正向传播，模型参数均为float16，数据计算为混合精度。

     c. Loss乘以缩放系数进行缩放。

     d. 反向传播，模型参数与参数梯度均为float16。

     e. 参数梯度除以缩放系数，还原为缩放前的值。

      f. 通过优化器将float16的梯度转化成float32精度，并使用float32的参数梯度更新float32的权重参数。


8.1.2 开启AMP
本文主要介绍如何开启自动混合精度AMP。

 步骤一：导入模块并指定训练设备

   import torch
   import torch_sdaa # 导入必须的依赖库
   import torchvision
   from torchvision.datasets import MNIST


   # 设置太初AI加速卡运行环境
   torch.sdaa.set_device("sdaa:0")
   device = torch.device("sdaa:0")




 步骤二：定义训练参数及数据

   train_data = MNIST(
       root = './data',
       download = True,
       train = True,
       transform = torchvision.transforms.ToTensor()
   )# 数据集获取并完成预训练




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司            135

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     模型训练




   # 定义训练相关参数
   batch_size = 16
   model = make_model().to(device).to(memory_format=torch.channels_last)   # 把模型放到指定device上并转换权重数据
   为channels_last格式
   train_dataloader = torch.utils.data.DataLoader(train_data, batch_size=batch_size)    # 定义DataLoader
   loss_func = torch.nn.CrossEntropyLoss().to(device)   # 定义损失函数
   optimizer = torch.optim.SGD(model.parameters(), lr=0.1)    # 定义优化器
   scaler = torch.sdaa.amp.GradScaler()      # 定义GradScaler
   epochs = 2   # 设置训练的循环次数




 步骤三：开启AMP执行训练

   for epoch in range(epochs):
       for imgs, labels in train_dataloader:
           # 将数据和标签放置在device上并转换为channels_last格式
           imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
           with torch.sdaa.amp.autocast():      # 开启AMP环境
                outputs = model(imgs)     # 前向计算
                loss = loss_func(outputs, labels)    # 损失函数计算


           optimizer.zero_grad()
           scaler.scale(loss).backward()     # loss缩放并反向转播
           scaler.step(optimizer)       # 参数更新
           scaler.update()     # 基于动态Loss Scale更新loss_scaling系数




 完整示例

   import torch
   import torch_sdaa # 导入必须的依赖库
   import torchvision
   from torchvision.datasets import MNIST
   from torch import nn


   # 设置太初AI加速卡运行环境
   torch.sdaa.set_device("sdaa:0")
   device = torch.device("sdaa:0")


   def make_model():
       class Mnist(nn.Module):
           def __init__(self):
                super(Mnist, self).__init__()
                self.flat = nn.Flatten(1, -1)
                self.linear1 = nn.Linear(784, 512)
                self.relu = nn.ReLU()
                self.dropout = nn.Dropout(0.2)
                self.linear2 = nn.Linear(512, 10)


           def forward(self, x):
                x = self.flat(x)
                x = self.linear1(x)
                x = self.relu(x)
                x = self.dropout(x)
                x = self.linear2(x)
                return x




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                           136

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     模型训练




       return Mnist()


   train_data = MNIST(
       root = './data',
       download = True,
       train = True,
       transform = torchvision.transforms.ToTensor()
   )# 数据集获取并完成预训练
   # 定义训练相关参数
   batch_size = 16
   model = make_model().to(device).to(memory_format=torch.channels_last)   # 把模型放到指定device上并转换权重数据
   为channels_last格式
   train_dataloader = torch.utils.data.DataLoader(train_data, batch_size=batch_size)    # 定义DataLoader
   loss_func = torch.nn.CrossEntropyLoss().to(device)   # 定义损失函数
   optimizer = torch.optim.SGD(model.parameters(), lr=0.1)    # 定义优化器
   scaler = torch.sdaa.amp.GradScaler()      # 定义GradScaler
   epochs = 2   # 设置训练的循环次数


   for epoch in range(epochs):
       for imgs, labels in train_dataloader:
           # 将数据和标签放置在device上并转换为channels_last格式
           imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
           with torch.sdaa.amp.autocast():     # 开启AMP环境
                outputs = model(imgs)     # 前向计算
                loss = loss_func(outputs, labels)    # 损失函数计算


           optimizer.zero_grad()
           scaler.scale(loss).backward()     # loss缩放并反向转播
           scaler.step(optimizer)       # 参数更新
           scaler.update()     # 基于动态Loss Scale更新loss_scaling系数


   print('finish training')




8.2 分布式训练DDP
8.2.1 DDP简介
分布式数据并行DDP（Distributed Data Parallelism）是一种数据并行方法，常用于多计算设备的模型训练场景。

分布式数据并行DDP将整个模型复制到多个设备上，并同时在每个设备上处理不同的数据子集。每个设备上的模型副
本独立地进行前向传播和反向传播，再将梯度聚合以更新模型参数。因此，分布式数据并行DDP可以通过并行的方式
增加每一次迭代所处理的全局数据量（global batch），从而提升模型训练的吞吐量。




                                                 图1 分布式数据并行DDP




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                           137

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            模型训练




 DDP优势

分布式数据并行DDP以并行的方式处理数据和更新参数，在大规模和复杂的深度学习任务中具有以下优势：

  1. 加速模型训练速度：利用多个计算设备并行处理数据，有效利用设备的计算能力。相较于单计算设备训练，DDP
   可以在相同的时间内处理更多的数据，从而加快模型训练速度。
 2. 提高模型性能：通过使用更大的batch_size提高模型的性能。较大的batch_size有助于提高梯度估计的准确
   性，从而更好地优化模型参数，提高模型性能。
 3. 高扩展性：DDP可以适应各种规模的分布式训练设置。它可以应用于具有几十个或数百个计算设备的大规模训练
   集群，也可以用于较小规模的本地多GPU训练。此外，DDP还可以与其他分布式训练策略（如模型并行和数据并
   行）结合使用，以进一步提高性能和扩展性。
 4. 内存效率：DDP训练可以减少对每个设备的内存需求。相比将整个模型复制到每个设备上，DDP仅需复制模型参
   数，而不复制整个模型。这可以减少每个设备的内存占用，使得更大规模的模型可以在有限的设备内存下进行训
   练。

 工作流程

分布式数据并行DDP的工作流程如下：

  1. 模型参数复制：在DDP训练中，模型的初始参数会被复制到每个工作设备上。这样，每个设备都有一份完整的模
   型参数副本，以便并行计算。
 2. 数据分发：将训练数据集划分为多个子集，每个子集分发到不同的设备上。每个设备只处理对应的数据子集。

 3. 前向传播：每个设备上的副本独立进行前向传播，并计算损失函数值。

 4. 反向传播和梯度聚合：每个设备上的副本独立进行反向传播，并计算相应的梯度。再将各个设备上的梯度进行聚
   合（如：求和或求平均）。
 5. 参数更新：使用聚合后的梯度更新模型的参数，通常使用优化算法（如：随机梯度下降）更新模型的参数。

 6. 循环迭代：重复执行上述步骤，直到达到预定的训练迭代次数或其他循环停止条件。


8.2.2 基本概念
本文档主要介绍TecoPyTorch分布式训练的基本概念。

 基本概念

分布式训练的主要概念如下表所示：

 概念                    说明

 group                 进程组。在一次任务中，所有进程组成的group通常被称为全局进程组。

 world_size            group（全局进程组）中的进程个数。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司        138

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




 概念                      说明

                         进程在group的序号，序号从0开始，其中0号进程通常为主进程。
                         例如：有2台机器，每台机器上有一张太初AI加速卡，每张加速卡上有4个可用的SDAA计
                         算设备：
 rank
                              第一台机器加速卡的0, 1, 2, 3号SDAA计算设备，对应 rank 设置为0, 1, 2, 3。

                              第二台机器加速卡的0, 1, 2, 3号SDAA计算设备，对应 rank 设置为4, 5, 6, 7。


 local_world_size        单机器节点上的进程个数。

                         进程在单机器节点中的序号，序号从0开始。
                         例如：有2台机器，每台机器上有一张太初AI加速卡，每张加速卡上有4个可用的SDAA计
                         算设备：
                              第一台机器加速卡的0, 1, 2, 3号SDAA计算设备，对应 local_rank 设置为0, 1,
 local_rank                   2, 3。

                              第二台机器加速卡的0, 1, 2, 3号SDAA计算设备，对应 local_rank 设置为0, 1,
                              2, 3。

                           local_rank 的作用范围是单个机器节点的进程，而                         rank 的作用范围是
                           group 中所有机器节点上的进程。



8.2.3 核心功能
TecoPyTorch是基于太初AI加速卡适配的PyTorch深度学习框架，其支持使用PyTorch框架原生的torch.distributed
分布式通信包和DistributedDataParallel分布式数据并行类，在太初AI加速卡上进行分布式通信和训练。

本节主要介绍TecoPyTorch分布式数据并行的核心功能，包括：

      init_process_group ：初始化分布式通信进程组。

      DistributedSampler ：执行分布式数据采样。

      DistributedDataParallel ：执行分布式数据并行。


 init_process_group

在TecoPyTorch分布式训练中，多个进程需要相互通信和同步，以确保模型训练的一致性和高效性。

通过初始化分布式通信进程组，TecoPyTorch能够管理参与训练的进程，使其按照预定的方式交换梯度、参数等信
息，从而实现模型的同步更新。

使用 init_process_group 函数，初始化分布式通信进程组。 init_process_group 函数的定义如下：

   torch.distributed.init_process_group(backend,init_method=None,timeout=None,world_size=-1,rank=-1,store=
   None)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  139

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               模型训练




 参数解释

               是否必
 参数                       说明
               填

 backend       是          通信后端，TecoPyTorch仅支持设置为 tccl 。

                          初始化进程组的方式：
                                   env://var （默认）：使用环境变量。该方式从环境变量中读取进程配置
                               信息，需要设置的环境变量包括： MASTER_ADDR 、 MASTER_PORT 、
                                RANK 和 WORLD_SIZE 。其中， rank 和 world_size 可以在接
                               口中设置。
 init_meth
               否                   tcp://ip:port ：使用TCP连接。该方式通过指定的IP地址和端口，各个
 od
                               进程进行信息交换。 此种方式需要在接口中设置          rank 和   world_size
                               参数。
                                   file://path ：使用共享文件系统。该方式通过共享文件系统，所有进程
                               进行信息共享。此种方式需要在接口中设置          rank 和   world_size 参
                               数。


 timeout       否          进程操作的超时时间，单位：分钟（min），默认值为30分钟。

                          参与分布式训练的进程个数。默认值为-1，表示从环境变量中获取。

 world_siz                      说明：
               否
 e
                                当指定 store 参数时，该参数必须设置。


                          当前进程的序号。默认值为-1，表示从环境变量中获取。


 rank          否                说明：

                                当指定 store 参数时，该参数必须设置。


                          key-value存储，用于在不同进程间交换地址和链接信息。该参数与
                            init_method 参数互斥。

                          具体使用方法可参考PyTorch官方文档说明。
 store         否
                                说明：

                                当指定 store 参数时， rank 和 world_size 参数必须设置。



 使用示例



文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                            140

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




以使用 env://var 和 tcp://ip:port 方式初始化分布式通信进程组为例，示例代码如下：

   # file_name: test_init.py
   import os, argparse
   import torch
   import torch_sdaa
   import torch.distributed as dist
   # 定义从命令行解析的环境变量
   parse = argparse.ArgumentParser()
   parse.add_argument('--init_method', type=str)
   parse.add_argument('--rank', type=int)
   parse.add_argument('--ws', type=int)
   args = parse.parse_args()
   # 设置计算使用的设备
   torch.sdaa.set_device(args.rank)
   # 定义进程组初始化方法
   if args.init_method == 'TCP':
       dist.init_process_group('tccl', init_method='tcp://127.0.0.1:28765', rank=args.rank, world_size=arg
   s.ws)
   elif args.init_method == 'ENV':
       dist.init_process_group('tccl', init_method='env://')


   rank = dist.get_rank()
   # 打印rank的初始化信息
   print(f"rank = {rank} is initialized")
   tensor = torch.tensor([1, 2, 3, 4]).sdaa()
   print(tensor)



假设在单机、4个SDAA计算设备上分布式运行上述代码文件，需要打开4个终端，并同时运行以下命令：


     说明：

           本文以手动运行多个程序的方法为例，启动分布式训练。如需使用其他多进程的启动和管理方式，可参考
           启动分布式训练。
           手动启动多进程时，开启的终端数需要与 word_size 的数值相同。


      env://var 方式运行命令：在命令行提供主进程的地址                            MASTER_ADDR 、端口        MASTER_PORT 、进程
      RANK 和进程数量            WORLD_SIZE 。


       MASTER_ADDR='localhost' MASTER_PORT=28765 RANK=0 WORLD_SIZE=4 python3 test_init.py --init_method=EN
       V
       MASTER_ADDR='localhost' MASTER_PORT=28765 RANK=1 WORLD_SIZE=4 python3 test_init.py --init_method=EN
       V
       MASTER_ADDR='localhost' MASTER_PORT=28765 RANK=2 WORLD_SIZE=4 python3 test_init.py --init_method=EN
       V
       MASTER_ADDR='localhost' MASTER_PORT=28765 RANK=3 WORLD_SIZE=4 python3 test_init.py --init_method=EN
       V



      tcp://ip:port 方式运行命令：在命令行提供进程                       rank ，以及进程数量            world_size 。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                                 141

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




       python3 test_init.py --init_method=TCP --rank=0 --ws=4
       python3 test_init.py --init_method=TCP --rank=1 --ws=4
       python3 test_init.py --init_method=TCP --rank=2 --ws=4
       python3 test_init.py --init_method=TCP --rank=3 --ws=4




 执行结果

运行结束后，将在每个终端输出以下信息：


     说明：

     如果启动的进程未达到 world_size 的数量，则进程会一直等待，直到所有进程都开始运行，等待时长取
     决于timeout参数值，默认为30分钟。


   # rank0 的终端输出信息：
   rank 0 is initialized
   tensor([1, 2, 3, 4], device='sdaa:0')
   # rank1的终端输出信息
   rank 1 is initialized
   tensor([1, 2, 3, 4], device='sdaa:1')
   # rank2的终端输出信息
   rank 2 is initialized
   tensor([1, 2, 3, 4], device='sdaa:2')
   # rank3的终端输出信息
   rank 3 is initialized
   tensor([1, 2, 3, 4], device='sdaa:3')




 DistributedSampler

在TecoPyTorch分布式训练中，需要先划分数据集，再将划分后的每个子数据集分配给不同的进程进行训练。

  DistributedSampler 能够根据数据集的大小和进程数量动态地调整每个进程所需的数据子集大小，从而确保数
据在进程间均匀分配。

  DistributedSampler 函数的定义如下：


   torch.utils.data.distributed.DistributedSampler(dataset, num_replicas=None, rank=None, shuffle=True, se
   ed=0, drop_last=False)




 参数解释

 参数                  是否必填            说明

 dataset             是               需要加载的完整数据集。

 num_replicas        否               参与分布式训练的进程数量，默认为 world_size 。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  142

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                             模型训练




 参数                  是否必填            说明

 rank                否               当前进程的序号。

                                     是否打乱数据集。
                                          True（默认值）：打乱数据集。
 shuffle             否
                                          False：不打乱数据集。


                                     随机种子，用于初始化随机数生成器，仅当 shuffle 设置为True时使
                                     用。

 seed                否                     提示：

                                           在分布式训练场景中， seed 值需要在所有进程中保持一致。


                                     数据长度不能被 world_size 整除时，是否丢弃剩下的数据。
                                          True：丢弃剩下的数据。
 drop_last           否
                                          False（默认值）：不丢弃剩下的数据。



  DistributedSampler 的数据分配，可以使用如下索引函数进行理解：


   indices[self.rank: self.total_size: self.num_replicas]



例如：有12条数据（ total_size )， num_replicas=4 , 则每个进程拿取数据的索引为：

   rank0: [0,4,8]; rank1: [1,5,9]; rank2: [2,6,10]; rank3: [3,7,11]




 使用示例

进行分布式训练时，使用 DistributedSampler 划分数据集，并将划分后的数据集加载到具体模型副本的步骤如
下：

  1. 定义    DistributedSampler ，对数据集进行采样和划分。

 2. 在     Dataloader 中使用       sampler 参数，加载划分后的数据集。

 3. 调用     set_epoch(epoch) 更新         DistributedSampler 内部，确保每个epoch都能以相同的方式打乱数
   据，从而提升模型的训练效果。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                     143

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            模型训练




       sampler = DistributedSampler(dataset)
       loader = DataLoader(dataset, sampler=sampler)
       for epoch in range(start_epoch, n_epochs):
           sampler.set_epoch(epoch) # 设置epoch更新种子
           train(loader)




 DistributedDataParallel

  DistributedDataParallel 是分布式训练的执行模块，通过在每个进程的模型副本之间同步梯度，实现数据并
行。

执行分布式训练，只需使用 torch.nn.parallel.DistributedDataParallel 对模型进行封装，示例如下：

   local_rank = dist.get_rank()
   model = Model.to('sdaa')
   model = DistributedDataParallel(model, device_ids=[local_rank])
   # device_ids 需保持默认值None 或 与当前进程设置的device保持一致




8.2.4 分布式训练启动方法
8.2.4.1 概述
PyTorch提供了多种分布式训练启动方法，用于简化分布式训练任务的启动和管理。常用的方法如下：

     torchrun：PyTorch分布式训练的命令行工具，封装了PyTorch分布式训练的常用配置，支持通过简单的命令行
     参数启动多进程或多节点的分布式训练任务。
     torch.distributed.launch：PyTorch分布式训练工具，属于torch.distributed模块，用于单节点或多节点上启
     动多个分布式进程。

          说明：

          PyTorch从1.10版本开始，建议使用                torchrun 代替     torch.distributed.launch 。


     mp.spawn：PyTorch用于启动多进程训练的函数，通过torch.multiprocessing模块创建多个进程，在进程之
     间进行通信和数据同步。


8.2.4.2 torchrun
  torchrun 是 PyTorch 中的一个命令行工具，旨在简化分布式训练任务的启动和管理。                               torchrun 封装了
PyTorch分布式训练的常用配置，可以通过简单的命令行参数启动多进程或多节点的分布式训练任务。

本文使用一个简单的示例，展示如何在TecoPyTorch中使用 torchrun 启动多进程。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                    144

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




     说明：

     torchrun的详细示例和使用方法，请参考torchrun开启示例。



 训练脚本

本示例使用的训练脚本代码如下（test_torchrun.py）：

   import os
   import torch
   import torch_sdaa
   import torch.nn as nn
   import torch.optim as optim
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP
   # 读取环境变量
   local_rank = int(os.environ['LOCAL_RANK'])
   master_addr = os.environ['MASTER_ADDR']
   master_port = os.environ['MASTER_PORT']
   # 设置计算设备
   torch.sdaa.set_device(local_rank)
   # 初始化进程组
   dist.init_process_group('tccl', init_method='env://')
   rank = dist.get_rank()
   print(f"rank = {rank} is initialized in {master_addr}:{master_port}; local_rank = {local_rank}")
   torch.sdaa.set_device(rank)
   tensor = torch.tensor([1, 2, 3, 4]).sdaa()
   print(tensor)




 启动命令

使用 torchrun 时，可以指定多个参数控制分布式训练的行为，主要包括：

      nnodes ：使用的机器数量。默认值为1，表示单机。

      node_rank ：节点的序号，从0开始。在多节点训练时，每个节点需要指定一个唯一的序号。

      nproc_per_node ：每个节点上的进程数量。

      master_addr ：主节点的IP地址，即rank0对应的主机地址。其它节点需要通过这个地址与master节点通
   信。
      master_port ：主节点的端口号，用于节点间的通信。

例如，在单机上启动4个进程，执行以下命令启动分布式训练：


     说明：

     在单机情况下：

               nnodes 参数不需要指定。



文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                            145

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             模型训练




               nproc_per_node 参数需要指定。

               master_addr 、    master_port 和       node_rank 由环境自动配置，无需配置。




   torchrun --nproc_per_node 4 test_torchrun.py




 执行结果

   rank = 0 is initialized in 127.0.0.1:29500; local_rank = 0
   rank = 1 is initialized in 127.0.0.1:29500; local_rank = 1
   rank = 2 is initialized in 127.0.0.1:29500; local_rank = 2
   rank = 3 is initialized in 127.0.0.1:29500; local_rank = 3
   tensor([1, 2, 3, 4], device='sdaa:0')
   tensor([1, 2, 3, 4], device='sdaa:1')
   tensor([1, 2, 3, 4], device='sdaa:2')
   tensor([1, 2, 3, 4], device='sdaa:3')




8.2.4.3 torch.distributed.launch
  torch.distributed.launch 是torch.distributed中的一个启动模块，用于单节点或多节点上启动多个分布式
进程。

本文使用一个简单的示例，展示如何在TecoPyTorch中使用 torch.distributed.launch 启动多进程。


     说明：

          PyTorch从1.10版本开始，建议使用                 torchrun 代替     torch.distributed.launch 。

               torch.distributed.launch 的详细示例和使用方法，请参考torch.distributed.launch开启方
          式。



 训练脚本

本示例使用的训练脚本代码如下（test_launch.py）：

   # filename: test_launch.py
   import torch
   import torch_sdaa
   import torch.distributed as dist
   import torch.multiprocessing as mp
   import os
   # 读取环境变量
   local_rank = int(os.environ['LOCAL_RANK'])
   master_addr = os.environ['MASTER_ADDR']
   master_port = os.environ['MASTER_PORT']
   # 设置设备
   torch.sdaa.set_device(local_rank)




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                  146

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




   # 初始化通信进程
   dist.init_process_group('tccl', init_method='env://')
   rank = dist.get_rank()
   print(f"rank = {rank} is initialized in {master_addr}:{master_port}; local_rank = {local_rank}")
   torch.sdaa.set_device(rank)
   tensor = torch.tensor([1, 2, 3, 4]).sdaa()
   print(tensor)




 启动命令

在使用 torch.distributed.launch 时，可以指定多个参数控制分布式训练的行为，主要包括：

      nnodes ：使用的机器数量。默认值为1，表示单机。

      node_rank ：节点的序号，从0开始。在多节点训练时，每个节点需要指定一个唯一的序号。

      nproc_per_node ：每个节点上的进程数量。

      master_addr ：主节点的IP地址，即rank0对应的主机地址。其它节点需要通过这个地址与master节点通
   信。
      master_port ：主节点的端口号，用于节点间的通信。

例如，在单机上启动4个进程，执行以下命令启动分布式训练：


     说明：

     在单机情况下：

            nnodes 参数不需要指定。

            nproc_per_node 参数需要指定。

            master_addr 、        master_port 和       node_rank 由环境自动配置，无需配置。




   python3 -m torch.distributed.launch   --nproc_per_node=4 test_launch.py




 执行结果

   rank = 0 is initialized in 127.0.0.1:29500; local_rank = 0
   rank = 1 is initialized in 127.0.0.1:29500; local_rank = 1
   rank = 2 is initialized in 127.0.0.1:29500; local_rank = 2
   rank = 3 is initialized in 127.0.0.1:29500; local_rank = 3
   tensor([1, 2, 3, 4], device='sdaa:0')
   tensor([1, 2, 3, 4], device='sdaa:1')
   tensor([1, 2, 3, 4], device='sdaa:2')
   tensor([1, 2, 3, 4], device='sdaa:3')




8.2.4.4 mp.spawn

文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                          147

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   模型训练




  mp.spawn 是PyTorch提供的一个函数，通过                  multiprocessing 模块创建多个进程，并使用PyTorch的分布
式通信接口 torch.distributed ，在进程之间进行通信和数据同步。

 函数定义

  mp.spawn 函数的定义如下：


   mp.spawn(fn, args=(), nprocs=1, join=True, daemon=False)




 参数解释

 参数                    说明

 fn                    进程执行的函数。

                       传递给 fn 函数的参数。

                             说明：
 args
                                fn 函数的第一个参数，不需要通过             args 传递，该参数由   spawn 自动
                             设置为当前进程的排名。


 nprocs                进程个数。

                       是否加入同一进程池。
                            True（默认值）：当前进程加入进程池。
 join
                            False：当前进程不加入进程池。


                       是否创建守护进程。
                            True（默认值）：创建守护进程。
 daemon
                            False：不创建守护进程。



 使用示例

以下是一个简单的示例，展示如何在TecoPyTorch中使用 mp.spawn 启动多进程训练。


        说明：

         mp.spawn 的详细示例和使用方法，请参考mp.spawn开启方式。



 训练脚本


文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                             148

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                              模型训练




本示例使用的训练脚本代码如下（test_spawn.py）：

   # file_name: test_spawn.py
   import torch
   import torch_sdaa
   import torch.distributed as dist
   import torch.multiprocessing as mp


   # 定义训练函数
   def fn(rank, ws, nums):
       torch.sdaa.set_device(rank)
       # 初始化通讯进程
       dist.init_process_group('tccl', init_method='tcp://127.0.0.1:28765',
                                rank=rank, world_size=ws)
       rank = dist.get_rank()
       print(f"rank = {rank} is initialized")
       torch.sdaa.set_device(rank)
       tensor = torch.tensor(nums).sdaa()
       print(tensor)
   # 定义主函数，args参数是一个元组，包含了所有需要传递给训练函数的参数。
   if __name__ == "__main__":
       ws = 4
       mp.spawn(fn, nprocs=ws, args=(ws, [1, 2, 3, 4]))




 启动命令

执行以下命令，启动分布式训练。

   python3 test_spawn.py




 执行结果

   rank = 0 is initialized
   rank = 1 is initialized
   rank = 2 is initialized
   rank = 3 is initialized
   tensor([1, 2, 3, 4], device='sdaa:0')
   tensor([1, 2, 3, 4], device='sdaa:1')
   tensor([1, 2, 3, 4], device='sdaa:2')
   tensor([1, 2, 3, 4], device='sdaa:3')




8.2.5 分布式训练示例
8.2.5.1 示例代码
本文以 main.py 为示例，介绍如何在PyTorch框架下开启分布式数据并行DDP。

 示例代码

  main.py



文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                   149

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           模型训练




   import os
   import torch
   import torch_sdaa
   import torch.nn as nn
   import torch.optim as optim
   # 导入DDP所需的依赖库
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP
   def main():
       # 设置device
       device = torch.device(f"sdaa:0")
       torch.sdaa.set_device(device)


       model = nn.Linear(10, 10).to(device) # 构造模型


       loss_fn = nn.MSELoss() # 定义loss
       optimizer = torch.optim.SGD(model.parameters(), lr=0.001) # 定义优化器


       model.train() # 设置训练模型
       for i in range(1000):
           data= torch.randn(20, 10).to(device) # 数据放到device上
           labels = torch.randn(20, 10).to(device) # 标签数据放到device上
           optimizer.zero_grad()
           outputs = model(data) # 前向计算
           loss = loss_fn(outputs, labels) # loss计算
           loss.backward() # loss反向传播
           optimizer.step() # 更新参数
           print(f"rank:0, loss:{loss.cpu().item()}")


   if __name__ == "__main__": # 主程序入口
       main()




8.2.5.2 torchrun开启示例
请先在示例代码 main.py 中进行代码适配，再启动分布式数据并行DDP。

 适配步骤

  1. 配置环境变量，从外部获取                local_rank 参数。


       # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
       os.environ['MASTER_ADDR'] = 'localhost' # 设置IP
       # 从外部获取local_rank参数
       local_rank = int(os.environ.get("LOCAL_RANK", -1))


 2. 在main函数中，设置            device ，并初始化         ProcessGroup 。


       # DDP backend初始化
       # rank号和device一一对应，进行set device
       # 需要在初始化ProcessGroup之前进行set device，tccl限制
       device = torch.device(f"sdaa:{local_rank}")
       torch.sdaa.set_device(device)




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                 150

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                    模型训练




       # 初始化ProcessGroup，通信后端选择tccl
       torch.distributed.init_process_group(backend="tccl", init_method="env://")



 3. 在main函数中，开启DDP模式。


       ddp_model = DDP(model) # DDP model




 启动命令

  torchrun --nproc_per_node 4 main.py


 完整代码

   import os
   import torch
   import torch_sdaa
   import torch.nn as nn
   import torch.optim as optim
   # 导入DDP所需的依赖库
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP


   # # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
   os.environ['MASTER_ADDR'] = 'localhost' # 设置IP
   # 从外部获取local_rank参数
   local_rank = int(os.environ.get("LOCAL_RANK", -1))


   def main():
       # DDP backend初始化
       # rank号和device一一对应，进行set device
       # 需要在初始化ProcessGroup之前进行set device，tccl限制
       device = torch.device(f"sdaa:{local_rank}")
       torch.sdaa.set_device(device)
       # 初始化ProcessGroup，通信后端选择tccl
       torch.distributed.init_process_group(backend="tccl", init_method="env://")


       model = nn.Linear(10, 10).to(device) # 构造模型
       ddp_model = DDP(model) # DDP model


       loss_fn = nn.MSELoss() # 定义loss
       optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.001) # 定义优化器


       model.train() # 设置训练模型
       for i in range(1000):
           data= torch.randn(20, 10).to(device) # 数据放到device上
           labels = torch.randn(20, 10).to(device) # 标签数据放到device上
           optimizer.zero_grad()
           outputs = model(data) # 前向计算
           loss = loss_fn(outputs, labels) # loss计算
           loss.backward() # loss反向传播
           optimizer.step() # 更新参数
           print(f"rank:{local_rank}, loss:{loss.cpu().item()}")




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                           151

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      模型训练




   if __name__ == "__main__": # 主程序入口
         main()




8.2.5.3 torch.distributed.launch开启示例
请先在示例代码 main.py 中进行代码适配，再启动分布式数据并行DDP。

 适配步骤

  1. 以    argparse 方式，从外部获取              local_rank 参数。


         # 从外部得到local_rank参数
         parser = argparse.ArgumentParser()
         parser.add_argument("--local-rank", default=-1, type=int)
         FLAGS = parser.parse_args()
         local_rank = FLAGS.local_rank


 2. 在main函数中，设置             device 并初始化         ProcessGroup 。


         # DDP backend初始化
         device = torch.device(f"sdaa:{local_rank}")
         torch.sdaa.set_device(device)
         # 初始化ProcessGroup，通信后端选择tccl
         torch.distributed.init_process_group(backend="tccl", init_method="env://")



 3. 在main函数中，开启DDP模式。


         ddp_model = DDP(model) # DDP model




 启动命令

以单机1卡、4个SDAA计算设备为例，启动命令如下：

  python -m torch.distributed.launch --nproc_per_node 4 main.py


 完整代码

   import os
   import argparse
   import torch
   import torch_sdaa
   import torch.nn as nn
   import torch.optim as optim
   # 导入DDP所需的依赖库
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP


   # 从外部得到local_rank参数
   parser = argparse.ArgumentParser()
   parser.add_argument("--local-rank", default=-1, type=int)




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                          152

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      模型训练




   FLAGS = parser.parse_args()
   local_rank = FLAGS.local_rank


   def main():
      # DDP backend初始化
      device = torch.device(f"sdaa:{local_rank}")
      torch.sdaa.set_device(device)
      # 初始化ProcessGroup，通信后端选择tccl
      torch.distributed.init_process_group(backend="tccl", init_method="env://")


      model = nn.Linear(10, 10).to(device) # 构造模型
      ddp_model = DDP(model) # DDP model


      loss_fn = nn.MSELoss() # 定义loss
      optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.001) # 定义优化器


      model.train() # 设置训练模型
      for i in range(1000):
           data= torch.randn(20, 10).to(device) # 数据放到device上
           labels = torch.randn(20, 10).to(device) # 标签数据放到device上
           optimizer.zero_grad()
           outputs = model(data) # 前向计算
           loss = loss_fn(outputs, labels) # loss计算
           loss.backward() # loss反向传播
           optimizer.step() # 更新参数
           print(f"rank:{local_rank}, loss:{loss.cpu().item()}")


   if __name__ == "__main__": # 主程序入口
      main()




8.2.5.4 mp.spawn开启示例
请先在示例代码 main.py 中进行代码适配，再启动分布式数据并行DDP。

 适配步骤

  1. 设置IP地址和端口号。


       # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
       os.environ['MASTER_ADDR'] = 'localhost' # 设置IP
       os.environ['MASTER_PORT'] = '29503'     # 设置端口号


 2. 定义    world_size 参数和           mp.spawn 函数，并将主程序入口下的               main() 修改如下：


       world_size=4 # 4张卡进行训练，配置不超过当前环境中的可用卡数
       mp.spawn(main(),
                 args=(world_size,),
                 nprocs=world_size,
                 join=True)



 3. 在main函数中，设置               device 并初始化     ProcessGroup 。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                            153

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               模型训练




       # 必须在初始化ProcessGroup之前进行set device，tccl限制
       device = torch.device(f"sdaa:{rank}")
       torch.sdaa.set_device(device)
       # 初始化ProcessGroup，通信后端选择tccl
       dist.init_process_group('tccl', rank=rank, world_size=world_size)



 4. 在main函数中，开启DDP模式。


       ddp_model = DDP(model) # DDP model




 启动命令

  python main.py


 适配后的代码

   import os
   import torch
   import torch_sdaa
   import torch.nn as nn
   import torch.optim as optim
   import torch.multiprocessing as mp
   # 导入DDP所需的依赖库
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP


   # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
   os.environ['MASTER_ADDR'] = 'localhost' # 设置IP
   os.environ['MASTER_PORT'] = '29503'      # 设置端口号


   def demo_basic(rank, world_size):
       # 必须在初始化ProcessGroup之前进行set device，tccl限制
       device = torch.device(f"sdaa:{rank}")
       torch.sdaa.set_device(device)
       # 初始化ProcessGroup，通信后端选择tccl
       dist.init_process_group('tccl', rank=rank, world_size=world_size)


       model = nn.Linear(10, 10).to(device) # 构造模型
       ddp_model = DDP(model) # DDP model


       loss_fn = nn.MSELoss() # 定义loss
       optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.001) # 定义优化器


       model.train() # 设置训练模型
       for i in range(1000):
           data= torch.randn(20, 10).to(device) # 数据放到device上
           labels = torch.randn(20, 10).to(device) # 标签数据放到device上
           optimizer.zero_grad()
           outputs = model(data) # 前向计算
           loss = loss_fn(outputs, labels) # loss计算
           loss.backward() # loss反向传播
           optimizer.step() # 更新参数
           print(f"rank:{rank}, loss:{loss.cpu().item()}")




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                   154

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           模型训练




   def main(demo_fn, world_size):
       mp.spawn(demo_fn,
                  args=(world_size,),
                  nprocs=world_size,
                  join=True)


   if __name__ == "__main__": # 主程序入口
        world_size=4 # 4张卡进行训练
        main(demo_basic, world_size)




8.2.5.5 mpirun开启示例
请先在示例代码 main.py 中进行代码适配，再启动分布式数据并行DDP。

 适配步骤

  1. MPI启动后，通过环境变量获取                    rank 和   world_size 。


       # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
       os.environ['MASTER_ADDR'] = '127.0.0.1' # 设置IP
       os.environ['MASTER_PORT'] = '29503'       # 设置端口号


       # ProcessGroup的总进程数，通过MPI启动后设置的环境变量获取
       world_size = int(os.environ['OMPI_COMM_WORLD_SIZE'])
       # 当前进程的rank，通过MPI启动后设置的环境变量获取
       rank = int(os.environ['OMPI_COMM_WORLD_RANK'])


 2. 在main函数中，设置                device 并初始化       ProcessGroup 。


       # DDP backend初始化
       device = torch.device(f"sdaa:{local_rank}")
       torch.sdaa.set_device(device)
       # 初始化ProcessGroup，通信后端选择tccl
       dist.init_process_group('tccl', rank=rank, world_size=world_size)


 3. 在main函数中，开启DDP模式。


       ddp_model = DDP(model) # DDP model




 启动命令

  mpirun -np 4 python main.py


 适配后的代码

   import os
   import torch
   import torch_sdaa




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司              155

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               模型训练




   import torch.nn as nn
   import torch.optim as optim
   # 导入DDP所需的依赖库
   import torch.distributed as dist
   from torch.nn.parallel import DistributedDataParallel as DDP


   # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
   os.environ['MASTER_ADDR'] = '127.0.0.1' # 设置IP
   os.environ['MASTER_PORT'] = '29503'      # 设置端口号
   # ProcessGroup的总进程数，通过MPI启动后设置的环境变量获取
   world_size = int(os.environ['OMPI_COMM_WORLD_SIZE'])
   # 当前进程的rank，通过MPI启动后设置的环境变量获取
   rank = int(os.environ['OMPI_COMM_WORLD_RANK'])


   def main(world_size,rank):
       # DDP backend初始化
       device = torch.device(f"sdaa:{rank}")
       torch.sdaa.set_device(device)
       # 初始化ProcessGroup，通信后端选择tccl
       dist.init_process_group('tccl', rank=rank, world_size=world_size)


       model = nn.Linear(10, 10).to(device) # 构造模型
       ddp_model = DDP(model) # DDP model


       loss_fn = nn.MSELoss() # 定义loss
       optimizer = torch.optim.SGD(ddp_model.parameters(), lr=0.001) # 定义优化器


       model.train() # 设置训练模型
       for i in range(1000):
           data= torch.randn(20, 10).to(device) # 数据放到device上
           labels = torch.randn(20, 10).to(device) # 标签数据放到device上
           optimizer.zero_grad()
           outputs = model(data) # 前向计算
           loss = loss_fn(outputs, labels) # loss计算
           loss.backward() # loss反向传播
           optimizer.step() # 更新参数
           print(f"rank:{rank}, loss:{loss.cpu().item()}")


   if __name__ == "__main__": # 主程序入口
       main(world_size,rank)




8.3 强制算子回落CPU计算
当模型因精度调试或其他场景需要在CPU上运行算子时，您可以强制将运行在SDAA设备上的算子回落到CPU上进行计
算。

本节介绍如何将指定算子强制回落至CPU上进行计算。

 操作步骤

  1. 设置   TORCH_SDAA_RUNTIME_AUTOFALLBACK 环境变量，开启算子强制回落至CPU计算的功能。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                   156

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               模型训练




       export TORCH_SDAA_RUNTIME_AUTOFALLBACK=1


 2. 设置   TORCH_SDAA_FALLBACK_OPS 环境变量，指定回落到CPU上计算的算子。


       export TORCH_SDAA_FALLBACK_OPS=<op_name>




         说明：

              算子名称 op_name 可从log日志或者profiler文件中获取。以 aten::add 为例，算子名称是
               add 。

              支持同时设置多个算子，算子之间请使用英文逗号进行分割。


 3. 执行以下命令，运行模型训练脚本，将步骤2指定的算子，回落到CPU上进行计算。


       python <your_model.py>


   其中： your_model.py 为模型训练脚本。


8.4 解析回落到CPU上计算的算子
进行模型训练时，如果模型中存在SDAA计算设备不支持的算子，TecoPyTorch会将这些算子回落到CPU上进行计
算。

为便于您分析模型中回落到CPU上计算的具体算子，TecoPyTorch提供了CPU回落算子分析工具。

本节介绍如何使用该工具分析模型训练过程中回落到CPU上进行计算的算子。

 操作步骤

  1. 运行模型前，执行以下命令，开启                 TORCH_SDAA_LOG_LEVEL 环境变量，并将变量值设置为   debug 。


         说明：

           debug 表示调试模式，该级别日志通常用于程序调试，以便尽可能多的获取内部程序运行状态信息。



       export TORCH_SDAA_LOG_LEVEL=debug


 2. 执行以下命令，运行模型并将运行日志保存到名为                        sdaa.log 的文件中。


         说明：

         如果运行模型仅用于分析回落到CPU上计算的算子，您可以在模型运行一个step（一次循环，包含模型
         前向传播和反向传播）后，结束运行，此时日志中已经记录所有算子的调用情况。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                         157

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




       python demo.py | tee sdaa.log


 3. 将以下解析代码保存在名为                 coverage.py 的Python文件。解析代码通过分析运行日志，输出算子的调用信
   息。

       import argparse
       import re


       def get_api_info(path):
           pattern_api = '(?<=sdaa::)\s*\w+'
           pattern_fallback = '(?<=default::)\s*\w+'
           all_api_set = set()
           fallback_api_set = set()
           with open(path, 'r', encoding='utf-8') as f:
               lines = f.readlines()
           for line in lines:
               if 'sdaa::' in line:
                   api = re.search(pattern_api, line).group()
                   all_api_set.add(api)
               if 'default::' in line:
                   api = re.search(pattern_fallback, line).group()
                   fallback_api_set.add(api)
           return sorted(list(all_api_set)), sorted(list(fallback_api_set))



       if __name__ == '__main__':
           parser = argparse.ArgumentParser(description='算子覆盖率统计')
           parser.add_argument('--path', type=str, help='日志文件路径', required=True)
           args = parser.parse_args()
           all_api_set, fallback_api_set = get_api_info(args.path)
           print(f"all api: {all_api_set}, total: {len(all_api_set)}\n")
           print(f"fallback op: {fallback_api_set}, total: {len(fallback_api_set)}\n")
           print(f"coverage rate: {(1 - len(fallback_api_set) / len(all_api_set)) * 100:.2f}%")



 4. 执行以下命令，运行解析脚本。


       python coverage.py --path sdaa.log



   其中：

          coverage.py 为解析代码的Python文件。

          sdaa.log 为模型运行日志的保存文件。


 执行结果

运行解析脚本，查看模型训练时调用的算子和总数量、回落到CPU的算子和总数量以及算子覆盖率。示例如下：

   all api: ['_amp_foreach_non_finite_check_and_unscale_', '_amp_update_scale_', '_cat', '_convolution',
   '_copy_from', '_index_put_impl_', '_local_scalar_dense', '_reshape_alias', '_s_where', 'abs_out', 'ad
   d', 'add_', 'alias', 'all_out', 'arange_out', 'as_strided', 'as_strided_', 'atan', 'bitwise_and', 'bitw
   ise_and_', 'bitwise_or_', 'clamp', 'clamp_', 'clamp_min_out', 'contiguous', 'convolution_backward_overr
   ideable', 'convolution_overrideable', 'copy_stride', 'div', 'div_', 'eq', 'exp_', 'fill_', 'ge', 'gt',




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               158

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型训练




   'index', 'le', 'log_', 'lt', 'masked_fill_', 'max', 'max_pool2d', 'maximum', 'mean', 'minimum', 'mul',
   'mul_', 'native_batch_norm', 'native_batch_norm_backward', 'ne', 'neg', 'nonzero', 'pow', 'reciprocal',
   'remainder', 'resize_', 'rsub', 'sigmoid', 'sigmoid_backward', 'silu_', 'silu_backward', 'sub', 'sub_',
   'sum', 'swai', 'unfold', 'upsample_nearest2d_backward_out', 'upsample_nearest2d_out', 'view', 'zero_'],
   total: 70


   fallback op: ['_amp_update_scale_', '_cat', '_index_put_impl_', '_local_scalar_dense', 'all_out', 'ata
   n', 'clamp', 'fill_', 'index', 'maximum', 'minimum', 'mul', 'ne', 'nonzero_out', 'reciprocal', 'remaind
   er'], total: 16


   coverage rate: 77.14%



其中：

      all_api 表示模型训练时调用的算子；同一行的                        total 表示调用的算子总数量。

      fallback op 表示模型训练时回落到CPU上进行计算的算子；同一行的                                 total 表示回落到CPU上进行计
   算的算子总数量。
      coverage rate ：算子覆盖率，即SDAA计算设备上运行的算子数量与运行模型时调用到的所有算子数量的
   比例。

 后续操作

在获取回落到CPU上计算的算子后，欢迎您参考太初元碁算子提需模板，通过issue将缺失算子的信息提交给太初元碁
工程师，便于后续复现和支持该算子。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  159

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            Compiler 图编译优化
