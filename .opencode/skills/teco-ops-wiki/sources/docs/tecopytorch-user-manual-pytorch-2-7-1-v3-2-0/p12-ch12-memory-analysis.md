---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p12
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第12部分 (ch12-memory-analysis)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "12990-13227"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, memory-analysis]
---

# TecoPyTorch 用户手册 v3.2.0（第12部分）

> 原文行范围：`12990-13227`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

12. 内存分析
在进行模型训练时，模型参数、优化器状态以及中间结果等都会占用内存。为便于您了解模型训练过程中的内存使用
情况及分析内存问题，TecoPyTorch提供了一种生成内存快照（snapshot）的方法。该快照记录了模型训练过程
中，任意时间点的内存分配状态以及分配事件的历史记录，同时您可以将快照数据保持下来生成Pickle文件，用于可视
化辅助分析。

 生成内存快照

生成内存快照的整体步骤如下：

  1. 在训练开始前，启用内存历史记录。

 2. 运行待分析的训练代码。

 3. 在训练结束后，保存快照文件，生成Pickle文件。

生成快照的典型模板代码如下：


     说明：

         torch.sdaa.memory.record_memory_history 和        torch.sdaa.memory.dump_snapshot
     函数的详细信息，可参考TecoPyTorch与PyTorch CUDA的API比对。


   # 启用内存历史记录
   torch.sdaa.memory.record_memory_history()
   ...
   # 运行待分析的代码
   train(epoch)
   ...
   # 保存快照文件，参数为文件名，建议后缀以pickle结尾
   torch.sdaa.memory.dump_snapshot("snapshot_0.pickle")




 加载内存快照

  1. 打开pytorch.org/memory_viz网站。

 2. 将Pickle文件拖放到网站的页面中，即可查看可视化的快照数据，并进行内存分析。


 查看活动内存时间线

活跃内存时间线，主要记录Tensor在计算过程中占用的内存大小及其存活的周期。

  1. 在网页中左上角的下拉框中，选择Active Memory Timeline，查看活动内存时间线信息。

 2. 将鼠标悬停在已分配的内存块上，可以查看该块内存分配时的堆栈跟踪信息，以及其存储在设备上的首地址等详
   细信息。



文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                 198

TecoPyTorch用户手册（适配PyTorch 2.7.1）                           内存分析




                                        图1 活动内存时间线

活动内存时间线主要包含以下两部分信息：

 信息              说明

                 内存块申请及释放的时间线信息。
                      横轴：表示时间。

 1
                      纵轴：表示峰值存储大小。

                      块的长度：表示内存块从申请到释放持续的时长。

                      块的高度：表示内存块的实际大小。


 2               内存块的大小及申请时的堆栈跟踪信息。鼠标悬停在内存块上即可显示。


 查看分配器状态历史记录

内存分配器状态历史记录，记录了内存块的分配与释放信息。

在网页中左上角的下拉框中，选择Allocator State Hitory，查看内存分配器状态历史信息。




                                       图2 分配器状态历史记录

内存分配器状态历史记录，主要包含以下三部分信息：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司     199

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     内存分析




 信息            说明

               分配器状态历史记录。
               分配器状态历史记录按照时间顺序记录了模型从训练开始到训练结束过程中的所有内存分配
 1
               （alloc）和释放（free）事件。
               选择一个事件（alloc或free），可以查看该事件发生时，分配器状态的直观摘要。

               事件发生时分配器状态的直观摘要。此摘要显示当前分配器的状态：

 2
                      彩色的内存块：表示已经分配出去的内存。

                      空白的内存块：表示缓存但暂未使用的内存。


               堆栈跟踪信息。将鼠标悬停在可视化工具区域2的彩色矩形块上，可以查看内存分配和堆栈跟踪信
               息。
                      内存分配信息。例如：b61001ade0000_2 8.0MiB (8388608 bytes) allocation (stream
                      0）。其中：
 3                       b61001ade0000_2为内存地址，地址中的“_2”表示该地址被使用过2次。您可以在时间
                         线中查找b61001ade0000，获取该内存被申请/释放的历史记录。
                         8.0MiB (8388608 bytes）为分配的内存大小。

                      内存分配时的函数调用信息，即什么函数使用了该内存。



 自定义内存分配器

如果TecoPyTorch默认的内存分配器不符合您的内存分配和使用需求，您可以自定义内存分配器，然后将自定义的内
存分配器注册到TecoPyTorch中使用。

  1. 使用C/C++函数定义分配器程序。本文以一个跟踪所有内存操作的基本分配器为例，示例代码如下：


       #include <sys/types.h>
       #include <torch/extension.h>


       #include <sdaa_runtime.h>


       extern "C" {


       void* my_malloc(ssize_t size, int device, sdaaStream_t stream) {
           void* ptr = nullptr;
           sdaaMalloc(&ptr, size);
           return ptr;
       }


       void my_free(void* ptr, ssize_t size, int device, sdaaStream_t stream) {
           if (ptr) sdaaFree(ptr);
       }


       }




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                             200

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                      内存分析




       PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
           m.def("my_malloc", [](size_t size, int device, void* stream) {
               return my_malloc(size, device, reinterpret_cast<sdaaStream_t>(stream));
           }, "");
           m.def("my_free", [](void* ptr, ssize_t size, int device, void* stream) {
               return my_free(ptr, size, device, reinterpret_cast<sdaaStream_t>(stream));
           }, "");
       }


 2. 编译内存分配器的C/C++程序，生成                    .so 文件。

 3. 创建并切换内存分配器。

     a. 使用    torch.sdaa.memory.SDAAPluggableAllocator 函数，创建一个内存分配器对象，并将其注
       册到TecoPyTorch中使用。

           import torch
           import torch_sdaa


           new_alloc = torch.sdaa.memory.SDAAPluggableAllocator('alloc.so', 'my_malloc', 'my_free')


       其中：

              alloc.so ：编译生成的生成                 .so 文件名称，请根据实际情况填写。

              my_malloc ：内存分配器程序中定义的                   alloc 函数的名称，请根据实际情况填写。

              my_free ：内存分配器程序中定义的                  free 函数的名称，请根据实际情况填写。

     b. 使用    torch.sdaa.memory.change_current_allocator 函数，切换内存分配器。


              提示：

              申请Tensor内存时，TecoPyTorch默认使用内置的内存分配器进行初始化。如果您需要切换内存分
              配器，请在内存申请之前操作，否则会在运行时产生错误："Can't swap an already initialized
              allocator"。


           import torch
           import torch_sdaa


           # Load the allocator
           new_alloc = torch.sdaa.memory.SDAAPluggableAllocator('alloc.so', 'my_malloc', 'my_free')
           # Swap the current allocator
           torch.sdaa.memory.change_current_allocator(new_alloc)
           # This will allocate memory in the device using the new allocator
           b = torch.zeros(10, device='sdaa')




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                             201

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考
