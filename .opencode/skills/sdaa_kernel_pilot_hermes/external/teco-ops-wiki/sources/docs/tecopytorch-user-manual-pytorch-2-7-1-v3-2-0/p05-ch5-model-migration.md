---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p05
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第5部分 (ch5-model-migration)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "4639-6843"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, model-migration, cuda-migration, automatic-migration, manual-migration, troubleshooting]
---

# TecoPyTorch 用户手册 v3.2.0（第5部分）

> 原文行范围：`4639-6843`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

5. 模型迁移
5.1 迁移约束
开源PyTorch上训练的模型支持在CUDA和CPU设备上运行。如果使用TecoPyTorch在太初AI加速卡运行开源
PyTorch上训练好的模型，需要将模型脚本中的CUDA设备接口改为SDAA设备接口。

TecoPyTorch的SDAA接口与开源PyTorch的CUDA接口一一对应，您只需在原始模型脚本中导入TecoPyTorch的功
能模块，并将设备相关接口的中 cuda 全部替换为 sdaa ，便可完成PyTorch模型在太初AI加速卡上的开发、训
练以及调试。

本文主要介绍模型迁移时的限制约束和注意事项，包含以下几个方面。

 适配第三方库

   如果原始模型脚本中，调用了模型第三方库，且第三方库使用的是GPU，迁移过程可能会存在适配问题，请联系
   太初技术人员进行支持。

         说明：

         当前SDAA已支持的三方库，见三方库支持列表。


   如果原始模型脚本中，调用了第三方依赖库，且三方库使用的是CPU，可以使用 pip install 命令安装相应
   的依赖库，然后按照CPU上的方式使用即可。

         说明：

         如果您在太初AI加速卡上使用CPU相关的第三方库时，遇到CPU依赖问题，可以联系太初技术支持获取
         帮助。


 处理TecoPyTorch不支持的算子及函数

   如果原始模型中存在TecoPytorch当前不支持的算子（包括自定义的CUDA算子），TecoPyTorch会自动回落该
   算子到CPU进行计算；如果这些算子也不支持在CPU上运行，则需要参考SDAA C编程指南（详情请参考《SDAA
   C编程指南》的概述章节），重新开发算子。


         说明：

         TecoPytorch当前支持的算子，请参考PyTorch算子类API支持说明。


   以下PyTorch接口在TecoPytorch框架中没有对应的接口实现，请您在迁移前，对这些接口进行处理，否则迁移
   后的模型可能无法运行或者报错：
         torch.backends.cudnn




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司         68

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型迁移




           torch.backends.cuda

           torch.autograd.profiler.emit_nvtx

           torch.cuda.nccl

           torch.cuda.CUDAGraph

           torch.UntypedStorage._release_ipc_counter_cuda

           torch.UntypedStorage._share_cuda_

           torch.UntypedStorage._new_shared_cuda

           torch.TypedStorage._release_ipc_counter

           torch.TypedStorage._share_cuda_

           torch.TypedStorage._new_shared_cuda


 卷积算子计算

针对卷积计算，太初目前仅支持float16数据类型。如果模型中存在卷积计算，且没有开启autocast混合精度训练，仍
需要添加 GradScaler 相关代码，从而避免由于float16数据类型导致的精度下降问题。TecoPyTorch中添加
 GradScaler 的示例代码如下：


   scaler = torch.sdaa.amp.GradScaler()        # 定义GradScaler
   epochs = 2    # 设置训练的循环次数


   for epoch in range(epochs):
        for imgs, labels in train_dataloader:
            # 将数据和标签放置在device上并转换为channels_last格式
            imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
            with torch.sdaa.amp.autocast():      # 开启AMP环境
                 outputs = model(imgs)     # 前向计算
                 loss = loss_func(outputs, labels)      # 损失函数计算


            optimizer.zero_grad()
            scaler.scale(loss).backward()       # loss缩放并反向转播
            scaler.step(optimizer)       # 参数更新
            scaler.update()     # 基于动态Loss Scale更新loss_scaling系数




 设置分布式训练的SDAA计算设备数量

启动分布式训练时，需要指定训练使用的SDAA计算设备（对应GPU的卡）数量，该数量需要设置为 2n (n需要大于
等于2）。您可以使用 teco-smi-c 命令，查看当前系统中可用的SDAA计算设备数量。示例如下：

    teco-smi-c
    +-----------------------------------------------------------------------------+
    |    TCML: x.x.x           SDAADriver: x.x.x             SDAARuntime: x.x.x         |
    |-------------------------------+----------------------+----------------------|
    | Index     Name                     | Bus-Id                | Health      SPE-Util |
    |           Temp          Pwr Usage|             Memory-Usage|                      |




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                         69

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         模型迁移




    |=============================================================================|
    |   0       TECO_AICARD_01          | 00000000:22:00.0       | OK             0% |
    |           0C                   0W |          0MB / 15296MB |                   |
    |-------------------------------+----------------------+----------------------|
    |   1       TECO_AICARD_01          | 00000000:22:00.0       | OK             0% |
    |           0C                   0W |          0MB / 15296MB |                   |
    |-------------------------------+----------------------+----------------------|
    |   2       TECO_AICARD_01          | 00000000:22:00.0       | OK             0% |
    |           0C                   0W |          0MB / 15296MB |                   |
    |-------------------------------+----------------------+----------------------|
    |   3       TECO_AICARD_01          | 00000000:22:00.0       | OK             0% |
    |           0C                   0W |          0MB / 15296MB |                   |
    |-------------------------------+----------------------+----------------------|
    +-----------------------------------------------------------------------------+
    | Processes:                                                                     |
    |   Tcaicard         PID     Process name                           Memory Usage |
    |=============================================================================|
    |       3        1230779     sdaa_runtime_te                                2 MB |
    +-----------------------------------------------------------------------------+



 Index 字段是SDAA计算设备的编号，您可以看到示例中的太初AI加速卡包含4个SDAA计算设备，每个SDAA计算
设备提供了15+G的显存空间。




5.2 自动迁移
5.2.1 迁移方法
TecoPyTorch提供了模型的自动迁移方法。只需在原始模型训练脚本中导入自动迁移代码，或者在运行模型训练脚本
前设置自动迁移环境变量，即可实现训练模型从CUDA设备到太初AI加速卡上的迁移。

本文主要介绍如何使用自动迁移方法，进行模型迁移。

 使用限制

   模型的迁移约束，可参考迁移约束。

   使用自动迁移方法迁移模型时，存在以下功能限制：

        不支持 torch.jit.script 迁移。自动迁移方法使用了Python的动态图模式，但
         torch.jit.script 不支持Python的动态语法，因此原始训练脚本中包含 torch.jit.script
        时，使用自动迁移功能会产生冲突。若您的训练脚本中必须使用 torch.jit.script 功能，请使用手动
        迁移方法，进行迁移。
        自动迁移方法会自动替换 init_process_group 中的 backend 值替换为 tccl ，但如果代码中包
        含 backend 判断的逻辑代码，例如： assert backend in ['gloo', 'nccl'] 、 if
        backend == 'nccl' ，则不会自动替换判断代码中的 backend 值，需要您手动将 nccl 修改为写
        为 tccl 。

 操作步骤



文档版本：v3.2.0                                 版权所有 © 太初(无锡)电子科技有限公司                           70

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                           模型迁移




 方法一：导入自动迁移代码

  1. 导入自动迁移模块：在模型训练脚本中，添加                            from torch_sdaa.utils import cuda_migrate 模块代
   码。示例如下：

       from torch_sdaa.utils import cuda_migrate      # 使用torch_sdaa自动迁移方法


 2. （推荐）开启自动混合精度AMP：如果原始模型中没有使用AMP，建议您在模型迁移时添加AMP进行训练。针对
   float16类型的卷积和矩阵乘法的运算，太初AI加速卡在软件层次进行了深度优化，使用AMP计算可以极大提升性
   能。

         提示：

         针对卷积计算，太初当前软件栈仅存在float16类型的实现。所以在存在卷积计算的模型中，即使不使用
         autocast，也需要添加`GradScaler`相关代码，避免float16类型出现数值溢出导致精度下降的问题。


   开启AMP的示例代码如下：

       ...
       from torch.sdaa import amp                  # 导入AMP
       scaler = torch.sdaa.amp.GradScaler()        # 定义GradScaler
       ...
       for epoch in range(epochs):
             for imgs, labels in train_dataloader:
                 imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
                 with torch.sdaa.amp.autocast():     # 开启AMP环境
                     outputs = model(imgs)
                     loss = loss_func(outputs, labels)
                 optimizer.zero_grad()
                 scaler.scale(loss).backward()       # loss缩放并反向转播
                 scaler.step(optimizer)      # 参数更新
                 scaler.update()    # 基于动态Loss Scale更新loss_scaling系数


 3. （推荐）开启分布式训练DDP：如果原始模型中没有使用DDP，建议您在模型迁移时添加DDP，使用多个SDAA计
   算设备进行训练，以提升模型训练效率。
   以torchrun为例，开启DDP的示例代码如下：


         说明：

         更多DDP的启动方法，请参考分布式训练示例。


       ...
       # 导入DDP所需的依赖库
       import torch.distributed as dist
       from torch.nn.parallel import DistributedDataParallel as DDP
       # # 设置IP:PORT，框架启动TCP Store为ProcessGroup服务
       os.environ['MASTER_ADDR'] = 'localhost' # 设置IP
       # 从外部获取local_rank参数
       local_rank = int(os.environ.get("LOCAL_RANK", -1))




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                               71

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        模型迁移




       def main():
           # DDP backend初始化
           # rank号和device一一对应，进行set device
           # 需要在初始化ProcessGroup之前进行set device，tccl限制
           device = torch.device(f"sdaa:{local_rank}")
           torch.sdaa.set_device(device)
           # 初始化ProcessGroup，通信后端选择tccl
           torch.distributed.init_process_group(backend="tccl", init_method="env://")
           ...
           ddp_model = DDP(model) # DDP model
           ...



 4. 保存并执行模型脚本，可参考运行模型训练。


 方法二：设置自动迁移环境变量

  1. （推荐）在模型运行脚本中，开启自动混合精度AMP、分布式训练DDP。

       开启自动混合精度AMP：如果原始模型中没有使用AMP，建议您在模型迁移时添加AMP进行训练。针对
       float16类型的卷积和矩阵乘法的运算，太初AI加速卡在软件层次进行了深度优化，使用AMP计算可以极大提
       升性能。

              提示：

              针对卷积计算，太初当前软件栈仅存在float16类型的实现。所以在存在卷积计算的模型中，即使不
              使用autocast，也需要添加`GradScaler`相关代码，避免float16类型出现数值溢出导致精度下降
              的问题。

       开启AMP的示例代码如下：

           ...
           from torch.sdaa import amp                  # 导入AMP
           scaler = torch.sdaa.amp.GradScaler()        # 定义GradScaler
           ...
           for epoch in range(epochs):
                 for imgs, labels in train_dataloader:
                     imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
                     with torch.sdaa.amp.autocast():     # 开启AMP环境
                         outputs = model(imgs)
                         loss = loss_func(outputs, labels)
                     optimizer.zero_grad()
                     scaler.scale(loss).backward()     # loss缩放并反向转播
                     scaler.step(optimizer)      # 参数更新
                     scaler.update()    # 基于动态Loss Scale更新loss_scaling系数


       开启分布式训练DDP：如果原始模型中没有使用DDP，建议您在模型迁移时添加DDP，使用多个SDAA计算设
       备进行训练，以提升模型训练效率。
       以torchrun为例，开启DDP的示例代码如下：


              说明：



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                                 72

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     模型迁移




              更多DDP的启动方法，请参考分布式训练示例。



           ...
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
                 ...
                 ddp_model = DDP(model) # DDP model
                 ...



 2. 在运行模型训练脚本前，设置环境变量                      TORCH_SDAA_AUTOLOAD=cuda_migrate 。示例如下：


       # 设置cuda_migrate环境变量
       export TORCH_SDAA_AUTOLOAD=cuda_migrate



 3. 执行模型脚本，可参考运行模型训练。


 执行结果

运行模型训练后，如果生成权重文件，则说明模型迁移成功。


     说明：

     在自动迁移模型时，如果存在不支持的算子，会出现如下提示：


        Torch-SDAA migrate unsupports "<api_name>" api. Please report a requirement to Torch-SDAA.



     如需要支持，请联系太初技术支持团队获取帮助。




5.2.2 迁移示例
本节以PyTorch官网的ResNet50模型训练脚本为例，介绍如何使用自动迁移方法将CUDA设备上训练的模型迁移到太
初AI加速卡上进行训练。



文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                           73

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                          模型迁移




 获取ResNet50模型训练脚本

点击此链接，获取PyTorch官网提供的、基于ImageNet数据集的ResNet50模型训练脚本 main.py 。


     说明：

     该模型训练脚本已开启DDP，但未开启AMP。


 操作步骤

  1. 在模型训练脚本          main.py 中，导入            from torch_sdaa.utils import cuda_migrate 代码。


       from torch_sdaa.utils import cuda_migrate    # 使用torch_sdaa自动迁移方法


 2. （推荐）开启自动混合精度AMP：原始模型训练脚本中没有使用AMP，迁移时建议开启。

     a. 添加    GradScaler 代码。


           ...
           from torch.sdaa import amp                  # 导入AMP
           model.train()
           scaler = amp.GradScaler()                # 添加GradScaler
           end = time.time()
           ...


     b. 添加AMP的开启代码。


              ...
              # compute output
              # 注释掉原有的output和loss代码
              # output = model(images)
              # loss = criterion(output, target)
              # 添加AMP开启代码
              with amp.autocast():
                    output = model(images)
                    loss = criterion(output, target)


              # measure accuracy and record loss
              acc1, acc5 = accuracy(output, target, topk=(1, 5))
              losses.update(loss.item(), images.size(0))
              top1.update(acc1[0], images.size(0))
              top5.update(acc5[0], images.size(0))


              # compute gradient and do SGD step
              optimizer.zero_grad()
              # 注释掉原有代码
              # loss.backward()
              # optimizer.step()
              # 添加以下新代码
              scaler.scale(loss).backward()       # loss缩放并反向转播
              scaler.step(optimizer)         # 更新参数（自动unscaling）




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                74

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型迁移




                 scaler.update()   # 更新loss_scaling系数
                 ...




 运行模型训练

参考以下步骤，运行迁移后的模型训练脚本。

  1. 下载ImageNet数据集，并保存至运行环境目录下，例如：                          /mnt/dataset/imagenet 。

 2. 执行以下命令，运行迁移后的                  main.py 脚本。

        模型单卡（即单SDAA计算设备）训练：

           python main.py /mnt/dataset/imagenet --gpu 0 --batch-size 128 --lr 0.1 --epochs 90 --arch resne
           t50 --workers 40 --momentum 0.9 --weight-decay 1e-4



        模型分布式训练：

           python main.py /mnt/dataset/imagenet --gpu 0 --batch-size 8 --lr 0.1 --epochs 90 --arch resnet5
           0 --workers 40 --momentum 0.9 --weight-decay 1e-4 --multiprocessing-distributed --dist-url 'tc
           p://127.0.0.1:65501' --world-size 1 --rank 0 --dist-backend 'nccl'



训练完成后，会在模型训练脚本所在目录生成名为 model_best.pth.tar 的模型权重文件。

 迁移后的模型训练脚本

通过导入自动迁移代码的方法迁移模型，迁移后的模型训练脚本代码如下：

   import argparse
   import os
   import random
   import shutil
   import time
   import warnings
   from enum import Enum


   import torch
   from torch_sdaa.utils import cuda_migrate   # 自动迁移方法
   from torch.sdaa import amp                # 导入AMP
   import torch.backends.cudnn as cudnn
   import torch.distributed as dist
   import torch.multiprocessing as mp
   import torch.nn as nn
   import torch.nn.parallel
   import torch.optim
   import torch.utils.data
   import torch.utils.data.distributed
   import torchvision.datasets as datasets
   import torchvision.models as models
   import torchvision.transforms as transforms
   from torch.optim.lr_scheduler import StepLR
   from torch.utils.data import Subset




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               75

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            模型迁移




   model_names = sorted(name for name in models.__dict__
      if name.islower() and not name.startswith("__")
      and callable(models.__dict__[name]))


   parser = argparse.ArgumentParser(description='PyTorch ImageNet Training')
   parser.add_argument('data', metavar='DIR', nargs='?', default='imagenet',
                       help='path to dataset (default: imagenet)')
   parser.add_argument('-a', '--arch', metavar='ARCH', default='resnet18',
                       choices=model_names,
                       help='model architecture: ' +
                           ' | '.join(model_names) +
                           ' (default: resnet18)')
   parser.add_argument('-j', '--workers', default=4, type=int, metavar='N',
                       help='number of data loading workers (default: 4)')
   parser.add_argument('--epochs', default=90, type=int, metavar='N',
                       help='number of total epochs to run')
   parser.add_argument('--start-epoch', default=0, type=int, metavar='N',
                       help='manual epoch number (useful on restarts)')
   parser.add_argument('-b', '--batch-size', default=256, type=int,
                       metavar='N',
                       help='mini-batch size (default: 256), this is the total '
                            'batch size of all GPUs on the current node when '
                            'using Data Parallel or Distributed Data Parallel')
   parser.add_argument('--lr', '--learning-rate', default=0.1, type=float,
                       metavar='LR', help='initial learning rate', dest='lr')
   parser.add_argument('--momentum', default=0.9, type=float, metavar='M',
                       help='momentum')
   parser.add_argument('--wd', '--weight-decay', default=1e-4, type=float,
                       metavar='W', help='weight decay (default: 1e-4)',
                       dest='weight_decay')
   parser.add_argument('-p', '--print-freq', default=10, type=int,
                       metavar='N', help='print frequency (default: 10)')
   parser.add_argument('--resume', default='', type=str, metavar='PATH',
                       help='path to latest checkpoint (default: none)')
   parser.add_argument('-e', '--evaluate', dest='evaluate', action='store_true',
                       help='evaluate model on validation set')
   parser.add_argument('--pretrained', dest='pretrained', action='store_true',
                       help='use pre-trained model')
   parser.add_argument('--world-size', default=-1, type=int,
                       help='number of nodes for distributed training')
   parser.add_argument('--rank', default=-1, type=int,
                       help='node rank for distributed training')
   parser.add_argument('--dist-url', default='tcp://224.66.41.62:23456', type=str,
                       help='url used to set up distributed training')
   parser.add_argument('--dist-backend', default='nccl', type=str,
                       help='distributed backend')
   parser.add_argument('--seed', default=None, type=int,
                       help='seed for initializing training. ')
   parser.add_argument('--gpu', default=None, type=int,
                       help='GPU id to use.')
   parser.add_argument('--multiprocessing-distributed', action='store_true',
                       help='Use multi-processing distributed training to launch '
                            'N processes per node, which has N GPUs. This is the '
                            'fastest way to use PyTorch for either single node or '
                            'multi node data parallel training')
   parser.add_argument('--dummy', action='store_true', help="use fake data to benchmark")


   best_acc1 = 0




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                    76

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        模型迁移




   def main():
       args = parser.parse_args()


       if args.seed is not None:
           random.seed(args.seed)
           torch.manual_seed(args.seed)
           cudnn.deterministic = True
           cudnn.benchmark = False
           warnings.warn('You have chosen to seed training. '
                          'This will turn on the CUDNN deterministic setting, '
                          'which can slow down your training considerably! '
                          'You may see unexpected behavior when restarting '
                          'from checkpoints.')


       if args.gpu is not None:
           warnings.warn('You have chosen a specific GPU. This will completely '
                          'disable data parallelism.')


       if args.dist_url == "env://" and args.world_size == -1:
           args.world_size = int(os.environ["WORLD_SIZE"])


       args.distributed = args.world_size > 1 or args.multiprocessing_distributed


       if torch.cuda.is_available():
           ngpus_per_node = torch.cuda.device_count()
           if ngpus_per_node == 1 and args.dist_backend == "nccl":
                 warnings.warn("nccl backend >=2.5 requires GPU count>1, see https://github.com/NVIDIA/nccl/
   issues/103 perhaps use 'gloo'")
       else:
           ngpus_per_node = 1


       if args.multiprocessing_distributed:
           # Since we have ngpus_per_node processes per node, the total world_size
           # needs to be adjusted accordingly
           args.world_size = ngpus_per_node * args.world_size
           # Use torch.multiprocessing.spawn to launch distributed processes: the
           # main_worker process function
           mp.spawn(main_worker, nprocs=ngpus_per_node, args=(ngpus_per_node, args))
       else:
           # Simply call main_worker function
           main_worker(args.gpu, ngpus_per_node, args)



   def main_worker(gpu, ngpus_per_node, args):
       global best_acc1
       args.gpu = gpu


       if args.gpu is not None:
           print("Use GPU: {} for training".format(args.gpu))


       if args.distributed:
           if args.dist_url == "env://" and args.rank == -1:
                 args.rank = int(os.environ["RANK"])
           if args.multiprocessing_distributed:
                 # For multiprocessing distributed training, rank needs to be the
                 # global rank among all the processes
                 args.rank = args.rank * ngpus_per_node + gpu
           dist.init_process_group(backend=args.dist_backend, init_method=args.dist_url,




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                  77

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                    模型迁移




                                  world_size=args.world_size, rank=args.rank)
      # create model
      if args.pretrained:
          print("=> using pre-trained model '{}'".format(args.arch))
          model = models.__dict__[args.arch](pretrained=True)
      else:
          print("=> creating model '{}'".format(args.arch))
          model = models.__dict__[args.arch]()


      if not torch.cuda.is_available() and not torch.backends.mps.is_available():
          print('using CPU, this will be slow')
      elif args.distributed:
          # For multiprocessing distributed, DistributedDataParallel constructor
          # should always set the single device scope, otherwise,
          # DistributedDataParallel will use all available devices.
          if torch.cuda.is_available():
              if args.gpu is not None:
                  torch.cuda.set_device(args.gpu)
                  model.cuda(args.gpu)
                  # When using a single GPU per process and per
                  # DistributedDataParallel, we need to divide the batch size
                  # ourselves based on the total number of GPUs of the current node.
                  args.batch_size = int(args.batch_size / ngpus_per_node)
                  args.workers = int((args.workers + ngpus_per_node - 1) / ngpus_per_node)
                  model = torch.nn.parallel.DistributedDataParallel(model, device_ids=[args.gpu])
              else:
                  model.cuda()
                  # DistributedDataParallel will divide and allocate batch_size to all
                  # available GPUs if device_ids are not set
                  model = torch.nn.parallel.DistributedDataParallel(model)
      elif args.gpu is not None and torch.cuda.is_available():
          torch.cuda.set_device(args.gpu)
          model = model.cuda(args.gpu)
      elif torch.backends.mps.is_available():
          device = torch.device("mps")
          model = model.to(device)
      else:
          # DataParallel will divide and allocate batch_size to all available GPUs
          if args.arch.startswith('alexnet') or args.arch.startswith('vgg'):
              model.features = torch.nn.DataParallel(model.features)
              model.cuda()
          else:
              model = torch.nn.DataParallel(model).cuda()


      if torch.cuda.is_available():
          if args.gpu:
              device = torch.device('cuda:{}'.format(args.gpu))
          else:
              device = torch.device("cuda")
      elif torch.backends.mps.is_available():
          device = torch.device("mps")
      else:
          device = torch.device("cpu")
      # define loss function (criterion), optimizer, and learning rate scheduler
      criterion = nn.CrossEntropyLoss().to(device)


      optimizer = torch.optim.SGD(model.parameters(), args.lr,
                                  momentum=args.momentum,
                                  weight_decay=args.weight_decay)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                            78

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   模型迁移




      """Sets the learning rate to the initial LR decayed by 10 every 30 epochs"""
      scheduler = StepLR(optimizer, step_size=30, gamma=0.1)


      # optionally resume from a checkpoint
      if args.resume:
          if os.path.isfile(args.resume):
              print("=> loading checkpoint '{}'".format(args.resume))
              if args.gpu is None:
                    checkpoint = torch.load(args.resume)
              elif torch.cuda.is_available():
                    # Map model to be loaded to specified single gpu.
                    loc = 'cuda:{}'.format(args.gpu)
                    checkpoint = torch.load(args.resume, map_location=loc)
              args.start_epoch = checkpoint['epoch']
              best_acc1 = checkpoint['best_acc1']
              if args.gpu is not None:
                    # best_acc1 may be from a checkpoint from a different GPU
                    best_acc1 = best_acc1.to(args.gpu)
              model.load_state_dict(checkpoint['state_dict'])
              optimizer.load_state_dict(checkpoint['optimizer'])
              scheduler.load_state_dict(checkpoint['scheduler'])
              print("=> loaded checkpoint '{}' (epoch {})"
                      .format(args.resume, checkpoint['epoch']))
          else:
              print("=> no checkpoint found at '{}'".format(args.resume))



      # Data loading code
      if args.dummy:
          print("=> Dummy data is used!")
          train_dataset = datasets.FakeData(1281167, (3, 224, 224), 1000, transforms.ToTensor())
          val_dataset = datasets.FakeData(50000, (3, 224, 224), 1000, transforms.ToTensor())
      else:
          traindir = os.path.join(args.data, 'train')
          valdir = os.path.join(args.data, 'val')
          normalize = transforms.Normalize(mean=[0.485, 0.456, 0.406],
                                         std=[0.229, 0.224, 0.225])


          train_dataset = datasets.ImageFolder(
              traindir,
              transforms.Compose([
                    transforms.RandomResizedCrop(224),
                    transforms.RandomHorizontalFlip(),
                    transforms.ToTensor(),
                    normalize,
              ]))


          val_dataset = datasets.ImageFolder(
              valdir,
              transforms.Compose([
                    transforms.Resize(256),
                    transforms.CenterCrop(224),
                    transforms.ToTensor(),
                    normalize,
              ]))


      if args.distributed:
          train_sampler = torch.utils.data.distributed.DistributedSampler(train_dataset)




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                          79

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型迁移




           val_sampler = torch.utils.data.distributed.DistributedSampler(val_dataset, shuffle=False, drop_
   last=True)
      else:
           train_sampler = None
           val_sampler = None


      train_loader = torch.utils.data.DataLoader(
           train_dataset, batch_size=args.batch_size, shuffle=(train_sampler is None),
           num_workers=args.workers, pin_memory=True, sampler=train_sampler)


      val_loader = torch.utils.data.DataLoader(
           val_dataset, batch_size=args.batch_size, shuffle=False,
           num_workers=args.workers, pin_memory=True, sampler=val_sampler)


      if args.evaluate:
           validate(val_loader, model, criterion, args)
           return


      for epoch in range(args.start_epoch, args.epochs):
           if args.distributed:
                train_sampler.set_epoch(epoch)


           # train for one epoch
           train(train_loader, model, criterion, optimizer, epoch, device, args)


           # evaluate on validation set
           acc1 = validate(val_loader, model, criterion, args)


           scheduler.step()


           # remember best acc@1 and save checkpoint
           is_best = acc1 > best_acc1
           best_acc1 = max(acc1, best_acc1)


           if not args.multiprocessing_distributed or (args.multiprocessing_distributed
                    and args.rank % ngpus_per_node == 0):
                save_checkpoint({
                    'epoch': epoch + 1,
                    'arch': args.arch,
                    'state_dict': model.state_dict(),
                    'best_acc1': best_acc1,
                    'optimizer' : optimizer.state_dict(),
                    'scheduler' : scheduler.state_dict()
                }, is_best)



   def train(train_loader, model, criterion, optimizer, epoch, device, args):
      batch_time = AverageMeter('Time', ':6.3f')
      data_time = AverageMeter('Data', ':6.3f')
      losses = AverageMeter('Loss', ':.4e')
      top1 = AverageMeter('Acc@1', ':6.2f')
      top5 = AverageMeter('Acc@5', ':6.2f')
      progress = ProgressMeter(
           len(train_loader),
           [batch_time, data_time, losses, top1, top5],
           prefix="Epoch: [{}]".format(epoch))


      # switch to train mode
      model.train()




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                              80

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            模型迁移




      # add GradScaler
      scaler = amp.GradScaler()
      end = time.time()
      for i, (images, target) in enumerate(train_loader):
           # measure data loading time
           data_time.update(time.time() - end)


           # move data to the same device as model
           images = images.to(device, non_blocking=True)
           target = target.to(device, non_blocking=True)


           # compute output
           with amp.autocast():
               output = model(images)
               loss = criterion(output, target)


           # measure accuracy and record loss
           acc1, acc5 = accuracy(output, target, topk=(1, 5))
           losses.update(loss.item(), images.size(0))
           top1.update(acc1[0], images.size(0))
           top5.update(acc5[0], images.size(0))


           # compute gradient and do SGD step
           optimizer.zero_grad()
           scaler.scale(loss).backward()    # loss缩放并反向转播
           scaler.step(optimizer)     # 更新参数（自动unscaling）
           scaler.update()     # 更新loss_scaling系数


           # measure elapsed time
           batch_time.update(time.time() - end)
           end = time.time()


           if i % args.print_freq == 0:
               progress.display(i + 1)


   def validate(val_loader, model, criterion, args):


      def run_validate(loader, base_progress=0):
           with torch.no_grad():
               end = time.time()
               for i, (images, target) in enumerate(loader):
                   i = base_progress + i
                   if args.gpu is not None and torch.cuda.is_available():
                       images = images.cuda(args.gpu, non_blocking=True)
                   if torch.backends.mps.is_available():
                       images = images.to('mps')
                       target = target.to('mps')
                   if torch.cuda.is_available():
                       target = target.cuda(args.gpu, non_blocking=True)


                   # compute output
                   output = model(images)
                   loss = criterion(output, target)


                   # measure accuracy and record loss
                   acc1, acc5 = accuracy(output, target, topk=(1, 5))
                   losses.update(loss.item(), images.size(0))
                   top1.update(acc1[0], images.size(0))
                   top5.update(acc5[0], images.size(0))




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                 81

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型迁移




                      # measure elapsed time
                      batch_time.update(time.time() - end)
                      end = time.time()


                      if i % args.print_freq == 0:
                          progress.display(i + 1)


       batch_time = AverageMeter('Time', ':6.3f', Summary.NONE)
       losses = AverageMeter('Loss', ':.4e', Summary.NONE)
       top1 = AverageMeter('Acc@1', ':6.2f', Summary.AVERAGE)
       top5 = AverageMeter('Acc@5', ':6.2f', Summary.AVERAGE)
       progress = ProgressMeter(
           len(val_loader) + (args.distributed and (len(val_loader.sampler) * args.world_size < len(val_lo
   ader.dataset))),
           [batch_time, losses, top1, top5],
           prefix='Test: ')


       # switch to evaluate mode
       model.eval()


       run_validate(val_loader)
       if args.distributed:
           top1.all_reduce()
           top5.all_reduce()


       if args.distributed and (len(val_loader.sampler) * args.world_size < len(val_loader.dataset)):
           aux_val_dataset = Subset(val_loader.dataset,
                                       range(len(val_loader.sampler) * args.world_size, len(val_loader.datase
   t)))
           aux_val_loader = torch.utils.data.DataLoader(
                 aux_val_dataset, batch_size=args.batch_size, shuffle=False,
                 num_workers=args.workers, pin_memory=True)
           run_validate(aux_val_loader, len(val_loader))


       progress.display_summary()


       return top1.avg



   def save_checkpoint(state, is_best, filename='checkpoint.pth.tar'):
       torch.save(state, filename)
       if is_best:
           shutil.copyfile(filename, 'model_best.pth.tar')


   class Summary(Enum):
       NONE = 0
       AVERAGE = 1
       SUM = 2
       COUNT = 3


   class AverageMeter(object):
       """Computes and stores the average and current value"""
       def __init__(self, name, fmt=':f', summary_type=Summary.AVERAGE):
           self.name = name
           self.fmt = fmt
           self.summary_type = summary_type
           self.reset()




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                                 82

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                              模型迁移




       def reset(self):
           self.val = 0
           self.avg = 0
           self.sum = 0
           self.count = 0


       def update(self, val, n=1):
           self.val = val
           self.sum += val * n
           self.count += n
           self.avg = self.sum / self.count


       def all_reduce(self):
           if torch.cuda.is_available():
               device = torch.device("cuda")
           elif torch.backends.mps.is_available():
               device = torch.device("mps")
           else:
               device = torch.device("cpu")
           total = torch.tensor([self.sum, self.count], dtype=torch.float32, device=device)
           dist.all_reduce(total, dist.ReduceOp.SUM, async_op=False)
           self.sum, self.count = total.tolist()
           self.avg = self.sum / self.count


       def __str__(self):
           fmtstr = '{name} {val' + self.fmt + '} ({avg' + self.fmt + '})'
           return fmtstr.format(**self.__dict__)


       def summary(self):
           fmtstr = ''
           if self.summary_type is Summary.NONE:
               fmtstr = ''
           elif self.summary_type is Summary.AVERAGE:
               fmtstr = '{name} {avg:.3f}'
           elif self.summary_type is Summary.SUM:
               fmtstr = '{name} {sum:.3f}'
           elif self.summary_type is Summary.COUNT:
               fmtstr = '{name} {count:.3f}'
           else:
               raise ValueError('invalid summary type %r' % self.summary_type)


           return fmtstr.format(**self.__dict__)



   class ProgressMeter(object):
       def __init__(self, num_batches, meters, prefix=""):
           self.batch_fmtstr = self._get_batch_fmtstr(num_batches)
           self.meters = meters
           self.prefix = prefix


       def display(self, batch):
           entries = [self.prefix + self.batch_fmtstr.format(batch)]
           entries += [str(meter) for meter in self.meters]
           print('\t'.join(entries))


       def display_summary(self):
           entries = [" *"]
           entries += [meter.summary() for meter in self.meters]
           print(' '.join(entries))




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                     83

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             模型迁移




      def _get_batch_fmtstr(self, num_batches):
           num_digits = len(str(num_batches // 1))
           fmt = '{:' + str(num_digits) + 'd}'
           return '[' + fmt + '/' + fmt.format(num_batches) + ']'


   def accuracy(output, target, topk=(1,)):
      """Computes the accuracy over the k top predictions for the specified values of k"""
      with torch.no_grad():
           maxk = max(topk)
           batch_size = target.size(0)


           _, pred = output.topk(maxk, 1, True, True)
           pred = pred.t()
           correct = pred.eq(target.view(1, -1).expand_as(pred))


           res = []
           for k in topk:
               correct_k = correct[:k].reshape(-1).float().sum(0, keepdim=True)
               res.append(correct_k.mul_(100.0 / batch_size))
           return res



   if __name__ == '__main__':
      main()




5.3 手动迁移
5.3.1 迁移方法
本文主要介绍单卡训练及分布训练场景下的模型手动迁移方法。

 迁移约束

模型的迁移约束，可参考迁移约束。

 单卡训练迁移

单卡训练场景，即PyTorch原始模型脚本使用单卡（对应太初的单个SDAA计算设备）进行训练的场景。

 迁移流程

单卡训练场景的迁移流程如下图所示：




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                  84

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           模型迁移




                                       图1 单卡训练模型迁移流程


 步骤一：导入torch_sdaa模块

在原始模型训练脚本中，导入 torch_sdaa 模块。

   import torch
   import torch_sdaa




 步骤二：切换模型训练的设备

在原始模型训练脚本中，指定SDAA作为训练设备。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      85

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                        模型迁移




   # 修改前，使用CUDA作为训练设备：
   # device = torch.device('cuda')


   # 修改后，使用SDAA作为训练设备：
   device = torch.device('sdaa')




 步骤三：替换PyTorch框架接口

   将原始模型训练脚本中的所有 torch.cuda 接口替换为 torch.sdaa 接口。TecoPyTorch的SDAA接口与
   开源PyTorch的CUDA接口一一对应，只需将原始模型中相关API的 cuda 字样改为 sdaa 即可。

          说明：

          TecoPyTorch与PyTorch框架接口的详细对应关系，请参考TecoPyTorch与PyTorch CUDA的功能性
          API比对。


   以 torch.cuda.is_available() 和 torch.cuda.device_count() 为例，替换方法如下：

       # 修改前的CUDA接口:
       # torch.cuda.is_available()


       # 改为SDAA接口：
       torch.sdaa.is_available()


       # 修改前的CUDA接口：
       # torch.cuda.device_count()


       # 修改后CUDA接口：
       torch.sdaa.device_count()



   将原始模型训练脚本中的模型、损失函数、数据集等对象的加载设备由 cuda 改为 sdaa 。示例如下：

       # 修改前，模型加载到CUDA：
       # model.to('cuda')


       # 修改为模型加载到SDAA：
       model.to('sdaa')


       # 修改前，损失函数加载到CUDA：
       # criterion = nn.CrossEntropyLoss()
       # criterion.to('cuda')


       # 修改为损失函数加载到SDAA：
       criterion = nn.CrossEntropyLoss()
       criterion.to('sdaa')


       # 修改前，数据集加载到CUDA：
       # images.to('cuda', non_blocking=True)
       # target = target.to('cuda', non_blocking=True)


       # 修改为数据集加载到SDAA:




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                86

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        模型迁移




       images.to('sdaa', non_blocking=True)
       target = target.to('sdaa', non_blocking=True)



   替换Tensor创建接口。如果原始模型训练脚本中包含创建指定数据类型的Tensor接口，需要将接口的中device
   参数的值由 cuda 改为 sdaa 。

     PyTorch接口                                                太初SDAA计算设备接口

     torch.tensor([1,2,3],dtype=torch.long,device='           torch.tensor([1,2,3],dtype=torch.long,device='
     cuda')                                                   sdaa')

     torch.tensor([1,2,3],dtype=torch.int,device='cu          torch.tensor([1,2,3],dtype=torch.int,device='s
     da')                                                     daa')

     torch.tensor([1,2,3],dtype=torch.half,device='c          torch.tensor([1,2,3],dtype=torch.half,device='
     uda')                                                    sdaa')

     torch.tensor([1,2,3],dtype=torch.float,device='          torch.tensor([1,2,3],dtype=torch.float,device='
     cuda')                                                   sdaa')

     torch.tensor([1,2,3],dtype=torch.bool,device='           torch.tensor([1,2,3],dtype=torch.bool,device='
     cuda')                                                   sdaa')

   替换示例如下：

       # 修改前：
       # torch.tensor([1,2,3],dtype=torch.long,device='cuda')
       # torch.tensor([1,2,3],dtype=torch.int,device='cuda')


       # 修改后：
       torch.tensor([1,2,3],dtype=torch.long,device='sdaa')
       torch.tensor([1,2,3],dtype=torch.int,device='sdaa')




 （可选）步骤四：切换输入数据的数据格式

为了提高模型训练的性能，建议您在模型迁移的过程中，修改输入数据的数据格式为 NHWC 。示例如下：

   for batch_idx, (data, target) in enumerate(train_loader):
      data = data.to(device) # 数据拷贝到设备上
      target = target.to(device) # 数据拷贝到设备上
      data = data.to(memory_format=torch.channels_last) # 数据格式转换为NHWC（channels_last）




 （推荐）步骤五：开启自动混合精度AMP

建议您在模型中开启AMP。针对float16类型的卷积和矩阵乘法的运算，太初AI加速卡在软件层次进行了深度优化，使
用AMP计算可以极大提升性能。


     提示：



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                     87

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         模型迁移




     针对卷积计算，太初当前软件栈仅存在float16类型的实现。所以在存在卷积计算的模型中，即使不使用
     autocast，也需要添加`GradScaler`相关代码，避免float16类型出现数值溢出导致精度下降的问题。


开启AMP的示例代码如下：

   ...
   from torch.sdaa import amp                    # 导入AMP
   scaler = torch.sdaa.amp.GradScaler()          # 定义GradScaler
   ...
   for epoch in range(epochs):
         for imgs, labels in train_dataloader:
               imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
               with torch.sdaa.amp.autocast():    # 开启AMP环境
                   outputs = model(imgs)
                   loss = loss_func(outputs, labels)
               optimizer.zero_grad()
               scaler.scale(loss).backward()     # loss缩放并反向转播
               scaler.step(optimizer)      # 参数更新
               scaler.update()    # 基于动态Loss Scale更新loss_scaling系数




 （推荐）步骤六：开启分布式训练DDP

建议您在模型中开启分布式训练DDP，使用多个SDAA计算设备进行训练，以提升模型训练效。

以torchrun为例，开启DDP的示例代码如下：


     说明：

     更多DDP的启动方法，请参考分布式训练示例。



   ...
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
         ...
         ddp_model = DDP(model) # DDP model
         ...




文档版本：v3.2.0                                 版权所有 © 太初(无锡)电子科技有限公司                                           88

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           模型迁移




 分布式训练迁移

分布式训练场景，即PyTorch原始模型脚本开启了DDP分布式训练的场景。


     说明：

     与单卡训练场景的模型迁移相比，分布式场景下的模型迁移，需要在单卡训练迁移的基础上，指定分布式训练
     的计算设备和通信后端。


 迁移流程




                                       图2 分布式训练迁移流程


 步骤一：导入torch_sdaa模块

在原始模型训练脚本中，导入 torch_sdaa 模块。

   import torch
   import torch_sdaa




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      89

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     模型迁移




 步骤二：切换模型训练的设备

在原始模型训练脚本中，指定SDAA作为训练设备。

   # 修改前，使用CUDA作为训练设备：
   # device = torch.device('cuda')


   # 修改后，使用SDAA作为训练设备：
   device = torch.device('sdaa')




 步骤三：替换PyTorch框架接口

   将原始模型训练脚本中的所有 torch.cuda 接口替换为 torch.sdaa 接口。TecoPyTorch的SDAA接口与
   开源PyTorch的CUDA接口一一对应，只需将原始模型中相关API的 cuda 字样改为 sdaa 即可。

          说明：

          TecoPyTorch与PyTorch框架接口的详细对应关系，请参考TecoPyTorch与PyTorch CUDA的功能性
          API比对。


   以 torch.cuda.is_available 和 torch.cuda.device_count 为例，替换方法如下：

       # 修改前的CUDA接口:
       # torch.cuda.is_available()


       # 改为SDAA接口：
       torch.sdaa.is_available()


       # 修改前的CUDA接口：
       # torch.cuda.device_count()


       # 修改后CUDA接口：
       torch.sdaa.device_count()



   将原始模型训练脚本中的模型、损失函数、数据集等对象的加载设备由 cuda 改为 sdaa 。示例如下：

       # 修改前，模型加载到CUDA：
       # model.to('cuda')


       # 修改为模型加载到SDAA：
       model.to('sdaa')


       # 修改前，损失函数加载到CUDA：
       # criterion = nn.CrossEntropyLoss()
       # criterion.to('cuda')


       # 修改为损失函数加载到SDAA：
       criterion = nn.CrossEntropyLoss()
       criterion.to('sdaa')


       # 修改前，数据集加载到CUDA：
       # images.to('cuda', non_blocking=True)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                90

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        模型迁移




       # target = target.to('cuda', non_blocking=True)


       # 修改为数据集加载到SDAA:
       images.to('sdaa', non_blocking=True)
       target = target.to('sdaa', non_blocking=True)



   替换Tensor创建接口。如果原始模型训练脚本中包含创建指定数据类型的Tensor接口，需要将接口的中device
   参数的值由 cuda 改为 sdaa 。

     PyTorch接口                                                太初SDAA计算设备接口

     torch.tensor([1,2,3],dtype=torch.long,device='           torch.tensor([1,2,3],dtype=torch.long,device='
     cuda')                                                   sdaa')

     torch.tensor([1,2,3],dtype=torch.int,device='cu          torch.tensor([1,2,3],dtype=torch.int,device='s
     da')                                                     daa')

     torch.tensor([1,2,3],dtype=torch.half,device='c          torch.tensor([1,2,3],dtype=torch.half,device='
     uda')                                                    sdaa')

     torch.tensor([1,2,3],dtype=torch.float,device='          torch.tensor([1,2,3],dtype=torch.float,device='
     cuda')                                                   sdaa')

     torch.tensor([1,2,3],dtype=torch.bool,device='           torch.tensor([1,2,3],dtype=torch.bool,device='
     cuda')                                                   sdaa')

   替换示例如下：

       # 修改前：
       # torch.tensor([1,2,3],dtype=torch.long,device='cuda')
       # torch.tensor([1,2,3],dtype=torch.int,device='cuda')


       # 修改后：
       torch.tensor([1,2,3],dtype=torch.long,device='sdaa')
       torch.tensor([1,2,3],dtype=torch.int,device='sdaa')




 （可选）步骤四：切换输入数据的数据格式

为了提高模型训练的性能，建议您在模型迁移的过程中，修改输入数据的数据格式为 NHWC 。示例如下：

   for batch_idx, (data, target) in enumerate(train_loader):
      data = data.to(device) # 数据拷贝到设备上
      target = target.to(device) # 数据拷贝到设备上
      data = data.to(memory_format=torch.channels_last) # 数据格式转换为NHWC（channels_last）




 （推荐）步骤五：开启自动混合精度AMP

建议您在模型中开启AMP。针对float16类型的卷积和矩阵乘法的运算，太初AI加速卡在软件层次进行了深度优化，使
用AMP计算可以极大提升性能。



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                     91

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        模型迁移




     提示：

     针对卷积计算，太初当前软件栈仅存在float16类型的实现。所以在存在卷积计算的模型中，即使不使用
     autocast，也需要添加`GradScaler`相关代码，避免float16类型出现数值溢出导致精度下降的问题。


开启AMP的示例代码如下：

   ...
   from torch.sdaa import amp                   # 导入AMP
   scaler = torch.sdaa.amp.GradScaler()         # 定义GradScaler
   ...
   for epoch in range(epochs):
         for imgs, labels in train_dataloader:
              imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
              with torch.sdaa.amp.autocast():    # 开启AMP环境
                  outputs = model(imgs)
                  loss = loss_func(outputs, labels)
              optimizer.zero_grad()
              scaler.scale(loss).backward()     # loss缩放并反向转播
              scaler.step(optimizer)      # 参数更新
              scaler.update()    # 基于动态Loss Scale更新loss_scaling系数




 步骤六：指定分布式训练计算设备和通信后端

   在 init_process_group 接口前，使用 torch.sdaa.set_device(device) 设置device。

         device = torch.device(f"sdaa:{local_rank}")
         torch.sdaa.set_device(device)



   将 init_process_group 接口的 backend 参数值由 nccl 改为 tccl 。

         # 修改前，GPU使用NCCL作为通信后端：
         # dist.init_process_group(backend='nccl', init_method=INIT_METHOD, rank=rank, world_size=world_siz
         e)


         # 修改后，SDAA使用TCCL作为通信后端：
         dist.init_process_group(backend='tccl', init_method=INIT_METHOD, rank=rank, world_size=world_size)




5.3.2 迁移示例
本节以基于ImageNet数据集的ResNet50模型训练为例，介绍如何将模型从CUDA设备迁移到太初AI加速卡上进行训
练。

 获取ResNet50模型训练脚本

点击此链接，获取PyTorch官网提供的、基于ImageNet数据集的ResNet50模型训练脚本 main.py 。



文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                              92

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         模型迁移




     说明：

     该模型训练脚本已开启DDP，但未开启AMP。


 操作步骤

参考以下步骤，修改仓库中的 main.py 训练脚本。

 步骤一：导入torch_sdaa模块

在 main.py 训练脚本中，导入 torch_sdaa 和 amp 模块。

   import torch
   # 导入torch_sdaa
   import torch_sdaa
   # 导入AMP
   from torch.sdaa import amp
   import torch.nn as nn
   import torch.nn.parallel
   import torch.backends.cudnn as cudnn
   import torch.distributed as dist
   import torch.optim
   from torch.optim.lr_scheduler import S
   import torch.multiprocessing as mp
   import torch.utils.data
   import torch.utils.data.distributed
   import torchvision.transforms as trans
   import torchvision.datasets as dataset
   import torchvision.models as models




 步骤二：切换模型训练的设备

修改 main.py 训练脚本中的以下接口，指定SDAA作为训练设备。

 原始接口                                         修改后接口

 torch.device('cuda:
                                              torch.device('sdaa:{}'.format(args.gpu))
 {}'.format(args.gpu))

 torch.device("cuda")                         torch.device("sdaa")


 步骤三：替换PyTorch接口

   将 main.py 训练脚本中的以下 torch.cuda 接口替换为 torch.sdaa 接口。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                              93

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                       模型迁移




     原始接口                              修改后接口                         接口说明

                                                                     获取device（SDAA计算设备）数
     torch.cuda.device_count()         torch.sdaa.device_count()
                                                                     量

                                                                     判断device（SDAA计算设备）是
     torch.cuda.is_available()         torch.sdaa.is_available()
                                                                     否可用

     torch.cuda.set_device(args        torch.sdaa.set_device(args.
                                                                     指定使用SDAA计算设备进行计算
     .gpu）                             gpu)

   将 main.py 训练脚本中的模型、损失函数、数据集等数据对象的加载设备由 cuda 改为 sdaa 。

     原始接口                              修改后接口                         接口说明

     model.cuda()                      model.to('sdaa')              切换模型至SDAA计算设备

     nn.CrossEntropyLoss()             nn.CrossEntropyLoss()
                                                                     切换损失函数至SDAA计算设备
     .cuda(args.gpu)                   .sdaa(args.gpu)

     'cuda:{}'.format(args.gpu)        'sdaa:{}'.format(args.gpu)    切换设备字符串为SDAA计算设备

     images.cuda(args.gpu,             images.sdaa(args.gpu,
                                                                     切换数据至SDAA计算设备
     non_blocking=True)                non_blocking=True)

     target.cuda(args.gpu,             target.sdaa(args.gpu,
                                                                     切换数据至SDAA计算设备
     non_blocking=True)                non_blocking=True)


 步骤四：开启AMP混合精度训练

原始模型没有使用自动混合精度训练（AMP），迁移时建议开启AMP训练。参考以下示例，添加AMP相关代码。

  1. 添加   GradScaler 代码。


       ...
       from torch.sdaa import amp              # 导入AMP
       model.train()
       scaler = amp.GradScaler()               # 添加GradScaler
       end = time.time()
       ...



 2. 添加AMP的开启代码。


          ...
          # compute output
          # 注释掉原有的output和loss代码
          # output = model(images)
          # loss = criterion(output, target)
          # 添加AMP开启代码
          with amp.autocast():




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                94

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      模型迁移




                output = model(images)
                loss = criterion(output, target)


          # measure accuracy and record loss
          acc1, acc5 = accuracy(output, target, topk=(1, 5))
          losses.update(loss.item(), images.size(0))
          top1.update(acc1[0], images.size(0))
          top5.update(acc5[0], images.size(0))


          # compute gradient and do SGD step
          optimizer.zero_grad()
          # 注释掉原有代码
          # loss.backward()
          # optimizer.step()
          # 添加以下新代码
          scaler.scale(loss).backward()      # loss缩放并反向转播
          scaler.step(optimizer)      # 更新参数（自动unscaling）
          scaler.update()      # 更新loss_scaling系数
          ...




 步骤五：指定分布式训练计算设备

在 init_process_group 接口前，使用 torch.sdaa.set_device(device) 设置device。

   torch.sdaa.set_device(args.gpu)
   dist.init_process_group(backend=args.dist_backend, init_method=args.dist_url,
                                     world_size=args.world_size, rank=args.rank)




 运行模型训练

参考以下步骤，运行迁移后的模型训练脚本。

  1. 下载ImageNet数据集，并保存至运行环境目录下，例如：                             /mnt/dataset/imagenet 。

 2. 执行以下命令，运行迁移后的                  main.py 脚本。

        模型单卡（即单SDAA计算设备）训练：

           python main.py /mnt/dataset/imagenet --gpu 0 --batch-size 128 --lr 0.1 --epochs 90 --arch resne
           t50 --workers 40 --momentum 0.9 --weight-decay 1e-4


        模型分布式训练（指定 tccl 作为通信后端）：

           python main.py /mnt/dataset/imagenet --gpu 0 --batch-size 8 --lr 0.1 --epochs 90 --arch resnet5
           0 --workers 40 --momentum 0.9 --weight-decay 1e-4 --multiprocessing-distributed --dist-url 'tc
           p://127.0.0.1:65501' --world-size 1 --rank 0 --dist-backend 'tccl'



训练完成后，会在模型训练脚本所在目录生成名为 model_best.pth.tar 的模型权重文件。


5.4 迁移问题排查


文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               95

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                   模型迁移




5.4.1 概述
由于编程模型、算子支持程度以及加速卡硬件特性等方面的差异，将模型从CUDA迁移至SDAA进行训练时，可能会遇
到如：训练报错、Loss异常等问题。

本文主要介绍如何排查模型迁移过程中的常见问题。

 问题类型

将模型从CUDA迁移至SDAA进行训练时，常见问题通常可以分为以下几类：

 问题类型                       说明

                            与环境和数据处理相关的错误，例如：环境搭建错误、CUDA环境类错误、数据错
 环境和数据处理错误                  误等。
                            这类错误通常出现在模型尚未运行至前向/反向计算阶段。

                            由于算子不支持、算子功能缺失、内存溢出、Core Dump等问题，导致训练过程
 训练中断                       中断。
                            这类问题出现在模型已运行至前向/反向计算阶段。

                            模型精度出现异常，例如：Loss值出现NaN、Loss不收敛或与CUDA结果不一致
 精度异常                       等情况。
                            该类问题主要出现在模型可以正常跑通前向阶段。




5.4.2 前置知识
为更好地理解和解决迁移过程中遇到的问题，建议您提前学习或者了解以下内容：

 内容                说明

                   由于编程模型、算子支持程度以及加速卡硬件特性等方面的差异，将模型从CUDA迁移至
 迁移的局限性
                   SDAA进行训练时存在一些约束、限制及注意事项，具体可参考迁移约束。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                96

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                       模型迁移




 内容                说明

                        模型训练部分：了解自动混合精度AMP、DDP分布式数据并行及TecoPyTorch对未接
                        入算子的CPU回落机制（详情请参考《TecoPyTorch用户手册（适配PyTorch
                        2.4.0）》的解析回落到CPU上计算的算子章节）。

 TecoPytorch模           精度调测部分：了解框架的Hook机制（详情请参考《TecoPyTorch用户手册（适配
 型训练、性能和                PyTorch 2.4.0）》的Hook使用章节），以便进行复杂的代码插入，协助判断问题。
 精度相关知识
                        性能调优部分：了解Profiler可视化工具（详情请参考《TecoPyTorch用户手册（适配
                        PyTorch 2.4.0）》的性能数据可视化章节），以便更好地分析代码调用。

                        常见问题部分：了解AMP训练、GradScaler等常见问题。


                   TecoPyTorch提供了环境变量TORCH_SDAA_LOG_LEVEL，用于开启训练日志及设置日
 训练日志开启方           志级别。
 法                 模型调试时，您可以设置 TORCH_SDAA_LOG_LEVEL=debug ，打印TecoPytorch调用
                   的所有接口信息，用于问题定位。

                   熟悉Python调试方法，包括使用Python调试器pdb，进行程序的基本调试，便于协助问题
 Python调试方法
                   定位。


5.4.3 环境和数据处理类
运行迁移后的模型时，当模型尚未运行至前向/反向计算阶段，可能会出现环境和数据处理相关的错误，具体如下：

   环境搭建类报错

   CUDA环境类报错

   数据处理类报错

 环境搭建类报错

 可能原因

模型所需的PyTorch和Python版本不正确、环境变量设置错误、权限问题等。

 解决方案

请参考模型原始仓库中环境搭建相关文档，根据具体的报错信息进行排查。例如：检查PyTorch版本和Python版本是
否符合TecoPytorch的版本要求、检查环境变量的路径是否设置正确、检查是否具有足够的运行权限等。

 CUDA环境类报错

 可能原因




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                     97

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           模型迁移




原始模型中存在 pynvml 、 nvml 等CUDA相关库以及CUDA硬件和软件环境相关代码，导致在SDAA计算设备上
运行训练时，出现报错，例如：

   NotImplementdError：SDAA device doesn't have compute capblity property




 解决方案

  1. 注释报错中的CUDA相关库或者软件代码。

 2. 将原始代码中在CUDA硬件上执行的数据，修改为在太初AI加速卡执行。

 3. 如果仍无法解决问题，请收集相关报错信息，通过issue的方式，联系太初元碁工程师。


 数据处理类报错

 可能原因

加载的数据错误、预处理的方式、格式转换错误等。

 解决方案

请参考模型原始仓库中数据处理的相关文档，根据具体的错误信息进行排查，例如：检查加载数据的路径是否正确、
检查预处理方式是否正确、确认输入数据的格式和形状等。




5.4.4 训练中断类
训练中断是指迁移后的模型运行至前向/反向计算阶段停止训练。本节主要介绍导致训练中断的原因和解决方案。

 可能原因

训练中断的常见原因如下：

   算子在SDAA和CPU均不支持计算。算子不支持在太初AI加速卡上进行计算，回落到CPU上后，也不支持在CPU
   上进行计算。
   算子功能缺失。例如：算子的某个特性在TecoPytorch上不支持、输入的形状（shape）或数据类型（dtype）
   算子不支持。
   不支持的函数模块。部分Torch库由于版本过低，部分函数在新版本的PyTorch上已经不支持或者废弃，例如：
    torch.cuda.amp.autocast 模块函数等。

   不支持的三方库。模型中包含TecoPytorch当前不支持的三方库。TecoPytorch支持的三方库，详见三方库支持
   列表。
   内存溢出（OOM）。模型未开启DDP或者batch size参数设置不合理，导致训练内存溢出。

   其他未知原因。无法通过报错信息进行定位的原因，例如：coredump、segmentation fault、kill signal等。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                   98

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      模型迁移




 解决方案

 算子在SDAA和CPU均不支持计算

请参考太初元碁算子提需模板，将不支持的算子通过issue提交给太初元碁工程师。

 算子功能缺失

由于算子功能缺失导致训练中断，请执行以下步骤：

  1. 将问题算子回落至CPU上计算。

       方法一：使用 TORCH_SDAA_RUNTIME_AUTOFALLBACK 环境变量，强制将算子回落至CPU进行计算，请
       参考强制算子回落CPU计算。
         a. 运行训练前，设置         TORCH_SDAA_RUNTIME_AUTOFALLBACK=1 。

         b. 指定回落至CPU计算的算子：               TORCH_SDAA_FALLBACK_OPS=<op_name1>,<op_nameN> 。


                 说明：

                     算子名称可从log日志或者profiler文件中获取，以 aten::add 为例，算子名称是
                      add 。

                     如果同时指定多个算子名称，请使用英文逗号进行分割。


       方法二：修改模型代码，将相关算子和数据切换到CPU上计算。

           针对函数类型的计算，参考以下内容，修改模型代码，将计算设备切换为CPU。

              # out = self.relu(out)
              device = out.device
              warnings.warn("fallback relu to cpu")
              out = out.to("cpu")
              out = self.relu(out)
              out = out.to("device")



           针对Module类，参考以下内容，修改PyTorch源码中的 forward 函数，将计算设备切换为CPU。


                 提示：

                 不要回落Module的Parameter至CPU，否则会导致优化器更新时出现问题。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                               99

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           模型迁移




              def conv2d_forward(self, input):
                  device = input.device
                  input = input.to("cpu")
                  weight_cpu = self.weight.to("cpu")
                  out = self._conv_forward(input, weight_cpu, self.bias)
                  return out.to(device)
              torch.nn.Conv2d.forward = conv2d_forward



 2. 如果仍存在问题，请参考太初元碁算子提需模板，将存在问题的算子通过issue提交给太初元碁工程师。


 不支持的函数模块

如果模型中使用的Torch库版本较低，库中的部分函数在新版本的PyTorch上已经不支持或者废弃，例如：
 torch.cuda.amp.autocast 模块函数等，将无法在TecoPyTorch中运行。

针对这类问题，请使用PyTorch最新版本的函数替换已经不支持或者废弃的函数。

 不支持的三方库

如果原始模型脚本中，调用了TecoPyTorch当前未适配的三方库，请将不支持的三方库名称通过issue提交给太初元
碁工程师。

当前TecoPyTorch已经支持的第三方库，请参考第三方库支持列表。

 内存溢出（OOM）

如果模型训练过程中出现了内存溢出（OOM）的问题，请执行以下步骤：

  1. 检查模型是否开启了DDP。

     a. 如果没有使用DDP，请开启DDP进行模型训练，具体可参考分布式训练DDP（详情请参考《TecoPyTorch用
       户手册（适配PyTorch 2.4.0）》的分布式训练DDP章节）。
     b. 如果已使用DDP，请执行步骤2。

 2. 调小模型的batch size参数。

 3. 如果问题依然存在，请将出现问题的模型名称和环境信息，通过issue提交给太初元碁工程师。


 其他未知原因

当无法通过报错信息直接定位到问题时，例如：coredump、segmentation fault、kill signal等，您可以通过以下
方法进一步定位问题：

   观察Python栈，问题点通常位于Python栈附近。

       如果有对应的Python栈，可以直接观察Python栈信息，定位错误出现的地方。

       如果训练挂起，无法直接查看Python栈，可以按下 ctrl+c （仅按一次），打印出Python栈，进行观
       察。




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                    100

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           模型迁移




   观察训练日志：设置 TORCH_SDAA_LOG_LEVEL=debug ，通过日志信息定位问题算子。您也可以将打印的日
   志，通过issue提交给太初元碁工程师进行定位。
   使用Python调试器pdb在模型的前向阶段，通过断点的方式，进行逐行调试。




5.4.5 精度异常类
模型训练过程中，出现Loss异常或者Loss值无法与CUDA对齐，则说明模型可能精度存在问题 。

关于具体的Loss异常现象，请参考精度异常现象。

关于Loss异常排查及解决方案，请参考模型迁移场景下的精度调试方法。




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司      101

TecoPyTorch用户手册（适配PyTorch 2.7.1）                             模型开发
