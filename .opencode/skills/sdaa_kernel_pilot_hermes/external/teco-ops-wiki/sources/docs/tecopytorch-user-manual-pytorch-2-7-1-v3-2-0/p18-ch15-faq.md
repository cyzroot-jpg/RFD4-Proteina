---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p18
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第18部分 (ch15-faq)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "20542-21108"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, faq, troubleshooting, distributed-training, docker, amp, convolution]
---

# TecoPyTorch 用户手册 v3.2.0（第18部分）

> 原文行范围：`20542-21108`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

15. 常见问题
15.1 分布式通信时初始化过程停滞，host端报socket timeout错误
 问题描述

分布式通信时，初始化过程停滞，Host端报错 socket timeout 。

 可能原因

机器socket绑定的端口不可用。

 解决方案

  1. 使用以下Python函数，查找当前系统中的可用端口。


       def find_free_port():
           import socket
           from contextlib import closing


           with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
               s.bind(('', 0))
               s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
               return str(s.getsockname()[1])



 2. 将查询到的可用端口，加入                 MASTER_PORT 环境变量中。


       export MASTER_PORT=<free_port>


   其中： free_port 是步骤1查询到的可用端口。


15.2 数据读取时Dataloader worker线程报错，Resource
temporarily unavailable
 问题描述

模型训练过程中，数据读取阶段，Dataloader worker线程出现以下报错：

   OpenBLAS blas_thread_init: pthread_create failed for thread 14 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 15 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 16 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 17 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 18 of 24: Resource temporarily unavailable




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                               312

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      常见问题




   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 19 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 20 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 21 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 22 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   OpenBLAS blas_thread_init: pthread_create failed for thread 23 of 24: Resource temporarily unavailable
   OpenBLAS blas_thread_init: RLIMIT_NPROC 65535 current, 65535 max
   Traceback (most recent call last):
    File "main.py", line 1, in <module>
      import torch   #torch
    File "/path/to/torch/__init__.py", line 933, in <module>
      from ._tensor import Tensor
    File "/path/to/torch/_tensor.py", line 21, in <module>
      from torch.overrides import (
    File "<frozen importlib._bootstrap>", line 991, in _find_and_load
    File "<frozen importlib._bootstrap>", line 975, in _find_and_load_unlocked
    File "<frozen importlib._bootstrap>", line 671, in _load_unlocked
    File "<frozen importlib._bootstrap_external>", line 779, in exec_module
    File "<frozen importlib._bootstrap_external>", line 874, in get_code
    File "<frozen importlib._bootstrap_external>", line 973, in get_data
   MemoryError




 可能原因

该问题由系统分配给进程的内存资源不足导致。

 解决方案

您可以尝试以下方式，解决进程使用的内存资源不足的问题：

   方式一：调整系统分配给进程的内存资源大小。

   执行以下命令，移除内存资源大小限制。

       ulimit -v unlimited


   方式二：调整worker线程数量，降低对内存资源的消耗。

   降低Dataloader的worker线程数量，减少worker线程对系统资源的消耗。调整worker数量的示例如下：




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                               313

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      常见问题




       # ...
       train_loader = torch.utils.data.DataLoader(
           train_dataset,
           batch_size=args.batch_size,
           shuffle=(not args.distributed),
           num_workers=args.num_workers,   # 降低传入的num_worker大小
           pin_memory=True,
           sampler=train_sampler,
       )
       # ...




15.3 模型进行分布式训练时出现报错，Invalid arguments
 问题描述

模型开启分布式训练，初始化进程组时，出现以下报错：

   AttributeError: module 'torch.distributed' has no attribute 'utils' ValueError:
   Assertion device.index() == usedDeviceIdx_ failed at ProcessGroupTCCL.cpp (610). Invalid arguments: Onl
   y support the device of ProcessGroupTCCL at tccl::broadcast




 可能原因

在初始化进程组前，没有指定计算使用的SDAA计算设备，导致计算使用的SDAA计算设备与数据加载的SDAA计算设
备不一致。

 解决方案

在初始化进程组前，指定计算使用的SDAA计算设备。设置示例如下：

   device = torch.device(f"sdaa:{local_rank}")


   # 在 init_process_group 前进行 set_device 操作
   torch.sdaa.set_device(device)


   torch.distributed.init_process_group(backend="tccl", init_method="env://")




15.4 模型进行分布式训练时出现报错，NotImplementedError
 问题描述

模型开启分布式训练，初始化进程组时，出现以下报错：

   NotImplementedError: Could not run 'c10d::broadcast_' with arguments from the 'SDAA' backend. This coul
   d be because the operator doesn't exist for this backend, or was omitted during the selective/custom bu
   ild process (if using custom build). If you are a Facebook employee using PyTorch on mobile, please vis




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               314

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      常见问题




   it https://fburl.com/ptmfixes for possible resolutions. 'c10d::broadcast_' is only available for these
   backends: [CPU, CUDA, BackendSelect, Python, FuncTorchDynamicLayerBackMode, Functionalize, Named, Conju
   gate, Negative, ZeroTensor, ADInplaceOrView, AutogradOther, AutogradCPU, AutogradCUDA, AutogradXLA, Aut
   ogradSDAA, AutogradMPS, AutogradXPU, AutogradHPU, AutogradLazy, AutogradMeta, Tracer, AutocastCPU, Auto
   castCUDA, AutocastSDAA, FuncTorchBatched, FuncTorchVmapMode, Batched, VmapMode, FuncTorchGradWrapper, P
   ythonTLSSnapshot, FuncTorchDynamicLayerFrontMode, PythonDispatcher].




 可能原因

初始化进程组时，传入的通信后端不是 tccl 。

 解决方案

初始化进程组时，设置通信后端为 tccl 。设置示例如下：

   torch.distributed.init_process_group(backend="tccl", init_method="env://")




15.5 运行模型训练时出现报错，RuntimeError: cannot resize
variables that require grad，如何解决？
 问题描述

运行模型训练时，出现以下报错：

   RuntimeError: cannot resize variables that require grad




 可能原因

改变计算梯度的张量形状，会破坏梯度计算所需的连续性。因此调整计算梯度的张量形状时（如使用 resize_() ,
 view() 或 reshape() ），PyTorch会提示此报错信息。


 解决方案

使用非原地操作替代原地操作，或者使用 detach().clone() 方法，创建与原始计算图分离的数据副本，从而确
保形状调整等操作能安全执行且不影响梯度计算。

 方式一：使用非原地操作代替原地操作

避免使用      resize_() 、       view_() 等原地操作，改用非原地操作，如：.                       view() 、     .reshape() ：


   # 错误：原地操作
   x.resize_(new_shape)


   # 正确：非原地操作
   x = x.view(new_shape)   # 或 x = x.reshape(new_shape)




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                                  315

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                        常见问题




 方式二：创建与原始计算图分离的数据副本

使用 detach().clone() 方法，创建与原始计算图分离的数据副本。此场景下，能安全执行形状调整等操作且不
影响梯度计算。

   import torch
   # 创建需要梯度的张量
   original = torch.tensor([1.0, 2.0, 3.0], requires_grad=True)


   # 分离并克隆
   safe_copy = original.detach().clone()


   # 调整形状 (原为 [3] -> 调整为 [1, 3])
   resized = safe_copy.view(1, 3)


   # 执行计算操作
   result = resized.sum()


   # 反向传播 (仅original需要梯度，safe_copy不影响）
   result.backward()


   print("调整后的张量:", resized)
   print("原始张量的梯度:", original.grad)        # 输出: tensor([1., 1., 1.])




15.6 运行模型训练时出现报错，RuntimeError:
torch.nn.functional.binary_cross_entropy and
torch.nn.BCELoss are unsafe to autocast，如何解决？
 问题描述

运行模型训练时，出现以下报错：

   RuntimeError: torch.nn.functional.binary_cross_entropy and torch.nn.BCELoss are unsafe to autocast




 可能原因

  torch.nn.functional.binary_cross_entropy 和                torch.nn.BCELoss 算子不支持使用自动混合精度
计算。

 解决方案

可以通过以下两种方式解决该问题：

   方式一：在模型中关闭 autocast 功能。

   方式二：在模型的 autocast 模块中，排除报错的算子。示例如下：

       import torch
       from torch.sdaa import amp




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                               316

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     常见问题




       # 在训练循环中
       with amp.autocast():
           # 模型的前向传播
           output = model(input_data)


           # 排除特定算子的部分
           with amp.autocast(enabled=False):
               # 需要保持 float32 精度的操作
               # 例如：需要高数值精度的损失函数
               loss = custom_loss_function(output.float(), target.float())




15.7 导入torch_sdaa时报错，libsddev.so.0: cannot open shared
object file，如何解决？
 问题描述

导入 torch_sdaa 时，出现以下报错：

   >>> import torch_sdaa
   Traceback (most recent call last):
     File "<string>", line 1, in <module>
     File "/path/to/torch_sdaa/__init__.py", line 6, in <module>
       from . import (
   ImportError: libsddev.so: cannot open shared object file: No such file or directory




 可能原因

未添加基础环境相关的环境变量。

 解决方案

执行以下命令，添加基础环境相关的环境变量。

   source /opt/tecoai/setvars.sh




15.8 Pip安装时出现Timeout报错，如何解决？
 问题描述

使用 pip install 安装时，出现以下报错：

   raise ReadTimeoutError(self._pool, None, 'Read timed out.')
   ReadTimeoutError: HTTPSConnectionPool(host='files.pythonhosted.org', port=443): Read timed out.




 可能原因



文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                          317

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                            常见问题




该问题可能是由于当前所使用的网络不稳定，或是所下载的包较大，导致下载时间过长而出现超时。

 解决方案

使用 pip install 命令安装时，在命令后使用                       -i 参数指定下载源，如配置临时的清华镜像源：


   pip install numpy -i https://pypi.tuna.tsinghua.edu.cn/simple




15.9 Conv算子不支持group参数，如何解决？
当前TecoPyTorch的Conv算子只支持 group=1 和深度可分离卷积，其他卷积类型正在支持中。

对于不支持的情况，可以fallback到CPU进行计算。


15.10 如何在Docker环境中查看TecoPyTorch及其依赖组件版本信息？
如果您通过Docker方式（详情请参考《TecoPyTorch用户手册（适配PyTorch 2.0.1）》的Docker安装章节）安装了
TecoPyTorch，可以按照以下步骤查看TecoPyTorch及其依赖组件的版本信息：

  1. 在Docker中，执行以下命令，进入TecoPytorch的Conda环境。


       conda activate torch_env


 2. 执行以下命令，显示TecoPytorch及其依赖组件的版本信息。


       python -c "import torch_sdaa"


   输出的版本信息示例如下（示例显示的是TecoPytorch v1.8.0及其依赖组件版本信息）：

       --------------+------------------------------------------------
        Host IP       | <host_ip>
        PyTorch       | 2.0.0a0+gitdfe6533
        Torch-SDAA    | 1.8.0a1+git01910b2
       --------------+------------------------------------------------
        SDAA Driver   | 1.2.0b0 (N/A)
        SDAA Runtime | 1.2.1b0 (/opt/tecoai/lib64/libsdaart.so)
        SDPTI         | 1.1.2b0 (/opt/tecoai/lib64/libsdpti.so)
        TecoDNN       | 1.21.0a4 (/opt/tecoai/lib64/libtecodnn.so)
        TecoBLAS      | 1.21.0a4 (/opt/tecoai/lib64/libtecoblas.so)
        CustomDNN     | 1.20.0a0 (/opt/tecoai/lib64/libtecodnn_ext.so)
        TecoRAND      | 1.8.0a1 (/opt/tecoai/lib64/libtecorand.so)
        TCCL          | 1.18.0b0 (/opt/tecoai/lib64/libtccl.so)
       --------------+------------------------------------------------




15.11 使用TecoSMI查看加速卡硬件信息时，Volatile SPE-Util列为
N/A，如何处理？


文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                 318

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             常见问题




 问题描述

使用 teco-smi -c 命令查询SDAA计算设备的基本信息时，Volatile SPE-Util列的部分值显示为N/A，如下所
示：

   (torch_env) root@DevGen03:/softwares# teco-smi -c
   Wed Jun   5 02:46:48 2024
   +-----------------------------------------------------------------------------+
   |   TCML: x.x.x        SDAADriver: x.x.x             SDAARuntime: x.x.x               |
   |---------------------------------+------------------------+------------------|
   | Index   Name                      | Bus-Id                 | Health        Volatile |
   |         Temp             Pwr Usage|           Memory-Usage|                SPE-Util |
   |=============================================================================|
   |   0     TECO_AICARD_01            | 00000000:01:00.0       | OK                     |
   |         35C                  90W |           0MB / 15296MB |                     0% |
   |-------------------------------+----------------------+----------------------|
   |   1     TECO_AICARD_01            | 00000000:01:00.0       | OK                     |
   |         35C                  90W |       165MB / 15296MB |                       0% |
   |-------------------------------+----------------------+----------------------|
   |   2     TECO_AICARD_01            | 00000000:01:00.0       | OK                     |
   |         35C                  90W |       165MB / 15296MB |                       0% |
   |-------------------------------+----------------------+----------------------|
   |   3     TECO_AICARD_01            | 00000000:01:00.0       | OK                     |
   |         35C                  90W |       165MB / 15296MB |                       0% |
   +-------------------------------+----------------------+----------------------+
   |   4     TECO_AICARD_01            | 00000000:02:00.0       | DEVICE_LOST            |
   |         40C                  90W |           0MB / 15296MB |                   N/A |
   |-------------------------------+----------------------+----------------------|
   |   5     TECO_AICARD_01            | 00000000:02:00.0       | DEVICE_LOST            |
   |         40C                  90W |           0MB / 15296MB |                   N/A |
   |-------------------------------+----------------------+----------------------|
   |   6     TECO_AICARD_01            | 00000000:02:00.0       | DEVICE_LOST            |
   |         40C                  90W |           0MB / 15296MB |                   N/A |
   |-------------------------------+----------------------+----------------------|
   |   7     TECO_AICARD_01            | 00000000:02:00.0       | DEVICE_LOST            |
   |         40C                  90W |           0MB / 15296MB |                   N/A |
   +-------------------------------+----------------------+----------------------+




 解决方案

Volatile SPE-Util列为N/A时，表明对应SDAA计算设备的SPE不可用，太初AI加速卡出现了掉卡行为。请联系太初元
碁技术支持人员解决。




15.12 为什么Docker环境中teco-smi-c命令显示的进程PID和ps命令显
示的PID不一致？
在Docker环境中， teco-smi -c 命名显示的进程是宿主机上的进程， ps 命令显示的是Docker内部的进程，
因为显示的进程内容不同，所以两个命令显示的进程PID不一致。




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                               319

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     常见问题




15.13 运行包含卷积的模型，为什么不使用AMP的情况下，也需要开启
GradScaler？
当不使用AMP（自动混合精度）时，所有计算默认使用FP32。为提升模型训练性能，卷积在太初AI加速卡上仅使用
FP16（半精度）进行计算。

为实现卷积在加速卡的计算，加速卡会将FP32输入转换成FP16进行计算，最后使用FP32输出，所以实际计算使用的仍
是FP16。但使用FP16进行计算可能会因为数值范围较小而出现梯度消失或溢出的问题。

为了确保在这种情况下训练的稳定性和效率，需要使用自动混合精度的 grad_scaler 参数管理梯度，避免由于使
用低精度数据类型而导致的数值问题。TecoPyTorch中添加 GradScaler 的示例代码如下：

   scaler = torch.sdaa.amp.GradScaler()      # 定义GradScaler
   epochs = 2   # 设置训练的循环次数


   for epoch in range(epochs):
      for imgs, labels in train_dataloader:
           # 将数据和标签放置在device上并转换为channels_last格式
           imgs, labels = imgs.to(device).to(memory_format=torch.channels_last), labels.to(device)
           with torch.sdaa.amp.autocast():    # 开启AMP环境
                outputs = model(imgs)     # 前向计算
                loss = loss_func(outputs, labels)    # 损失函数计算


           optimizer.zero_grad()
           scaler.scale(loss).backward()     # loss缩放并反向转播
           scaler.step(optimizer)       # 参数更新
           scaler.update()     # 基于动态Loss Scale更新loss_scaling系数




15.14 为何更推荐使用AMP的方式运行训练？
针对float16类型的卷积和矩阵乘法的运算，太初AI加速卡在软件层次进行了深度优化，使用AMP计算可以提升性能。

关于如何开启AMP，可参考自动混合精度训练AMP（详情请参考《TecoPyTorch用户手册（适配PyTorch 2.0.1）》
的自动混合精度训练AMP章节）。


15.15 为何卷积更推荐使用NHWC的layout进行计算？
太初AI加速卡适合计算NHWC的layout，所以太初元碁卷积算子计算使用的layout是NHWC。

如果卷积使用NCHW输入，则会额外进行几次内存拷贝，转成channel last再进行计算，计算效率相比会降低。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                         320
