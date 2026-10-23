---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p16
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第16部分 (ch13-api-reference-torch-sdaa-part2)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "19001-20190"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, api-reference, torch-sdaa, stream, event, amp, custom-op]
---

# TecoPyTorch 用户手册 v3.2.0（第16部分）

> 原文行范围：`19001-20190`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

                                           待查询的SDAA设备。
 device             torch.device | int
                                           默认值为None，表示获取当前SDAA设备的流。

                                           设定流的优先级。


 priority           int                         提示：

                                                该参数为预留项，目前暂无实际作用。



 使用示例

   >>> import torch
   >>> import torch_sdaa




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司           287

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          API 参考




   >>> torch.sdaa.Stream()
   <torch_sdaa.backend.Stream device=sdaa:1 sdaa_stream=0x555a54843580>
   >>> torch.sdaa.Stream(1)
   <torch_sdaa.backend.Stream device=sdaa:1 sdaa_stream=0x555a548435f0>
   >>> torch.sdaa.Stream(torch.device(0))
   <torch_sdaa.backend.Stream device=sdaa:0 sdaa_stream=0x555a5483a0b0>




13.4.1 query

   query()




 功能介绍

查询当前句柄对应的流上的任务是否全部完成。

 参数解释

无。

 返回值

 名称                   类型                    说明

                                            流上的全部任务是否完成：
                                                 True：已全部完成。
 ret                  Bool
                                                 False：未全部完成。



 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> s.query()
   True




13.4.2 record_event

   record_event(event=None)




 功能介绍

在当前句柄对应的流中插入一个事件。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                  288

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                         API 参考




 参数解释

 名称           类型                              说明

                                              待插入的事件。
 event        torch.sdaa.Event
                                              默认值为None，表示会构造一个新的事件并返回。


 返回值

 名称                        类型                                  说明

 event                     torch.sdaa.Event                    插入的事件。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> s.record_event()
   <torch_sdaa.backend.Event 0x555a5483ca20>
   >>> e = torch.sdaa.Event()
   >>> s.record_event(e)
   <torch_sdaa.backend.Event 0x555a54842e00>
   >>> e
   <torch_sdaa.backend.Event 0x555a54842e00>




13.4.3 synchronize

   synchronize()




 功能介绍

等待当前句柄对应的流上的任务全部完成。

 参数解释

无。

 返回值

无。

 使用示例




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                289

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                     API 参考




   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> s.synchronize()




13.4.4 wait_event

   wait_event(event)




 功能介绍

当前句柄对应的流需要等待指定的事件完成后再执行后续提交的任务。

 参数解释

 名称                      类型                               说明

 event                   torch.sdaa.Event                 需要等待的事件。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> e = torch.sdaa.Event()
   >>> s.wait_event(e)




13.4.5 wait_stream

   wait_stream(stream)




 功能介绍

当前句柄对应的流和其他流进行同步。

 参数解释




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司            290

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                       API 参考




 名称                   类型                            说明

                                                    待同步的流。

                                                          说明：
 stream               torch.sdaa.Stream
                                                          该函数不会等到当前流对应的任务队列中的任务完
                                                          成再返回，只会影响发起该调用之后的操作。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s1 = torch.sdaa.Stream()
   >>> s2 = torch.sdaa.Stream()
   >>> s1.wait_stream(s2)




13.5 torch.sdaa.Event

   _class_ torch.sdaa.Event(enable_timing=False, blocking=False, interprocess=False)




 功能介绍

获取事件的句柄。

事件是流的标记点，可用于监控任务进度，准确测量任务的执行时间，同时也可以同步流的任务。

 注意事项

     事件只能插入到同一个SDAA设备上的流，但任意SDAA设备上的流都可以等待该事件。

     只有在torch.sdaa.Event第一次插入到流或传给其他进程时，其内在的事件才会被惰性初始化。

 参数解释




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                291

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           API 参考




 名称                             类型           说明

                                             事件是否用于测量时间，默认值为False。
                                                  True：是。
 enable_timing                  bool
                                                  False：否。


                                             事件的wait操作是否会被阻塞，默认值为False。
                                                  True：是。
 blocking                       bool
                                                  False：否。


                                             是否可以在进程之间共享事件，默认值为False。
                                                  True：是。
 interprocess                   bool
                                                  False：否。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> e = torch.sdaa.Event()




13.5.1 elapsed_time

   elapsed_time(end_event)




 功能介绍

统计从当前句柄对应的事件到参数end_event的执行时间，单位：毫秒。

 参数解释

 名称                                    类型                          说明

 end_event                             torch.sdaa.Event            结束事件。


 返回值


文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司               292

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                 API 参考




 名称                类型            说明

 ret               float         两个事件之间经过的时间，单位：毫秒。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> e1 = torch.sdaa.Event()
   >>> e2 = torch.sdaa.Event()
   >>> e1.record()
   >>> e2.record()
   >>> e1.elapsed_time(e2)
   2256.311767578125




13.5.2 query

   query()




 功能介绍

查询当前句柄对应的事件之前的所有任务是否完成。

 参数解释

无。

 返回值

 名称                  类型            说明

                                   当前事件之前的所有任务是否完成。
                                         True：全部完成。
 ret                 bool
                                         False：没有全部完成。



 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> e = torch.sdaa.Event()
   >>> a = torch.randn(100).to('sdaa')
   >>> b = torch.randn(100).to('sdaa')
   >>> c = a + b
   >>> e.record()




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司      293

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     API 参考




   >>> e.query()
   True




13.5.3 record

   record(stream=None)




 功能介绍

在目标流上插入当前句柄对应的事件。

 参数解释

 名称                      类型                       说明

                                                  待插入事件的流，默认值为None。

                                                       说明：

                                                         如果参数为None，则会使用
 stream                  torch.sdaa.Stream
                                                         torch.sdaa.current_stream作为参数。

                                                         事件与流需要在同一台SDAA设备。




 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> e = torch.sdaa.Event()
   >>> a = torch.randn(100).to('sdaa')
   >>> b = torch.randn(100).to('sdaa')
   >>> c = a + b
   >>> e.record()




13.5.4 synchronize

   synchronize()




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                            294

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                       API 参考




 功能介绍

等待当前句柄对应的事件之前的所有任务全部完成。

 参数解释

无。

 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> e = torch.sdaa.Event()
   >>> a = torch.randn(100).to('sdaa')
   >>> b = torch.randn(100).to('sdaa')
   >>> c = a + b
   >>> e.record()
   >>> e.synchronize()




13.5.5 wait

   wait(stream=None)




 功能介绍

后续提交到目标流的任务需等待当前句柄对应的事件完成才能继续执行。

 参数解释

 名称                      类型                    说明

                                               需要等待的SDAA流，默认值为None。

                                                    说明：

 stream                  torch.sdaa.Stream            如果参数为None，则会使用
                                                      torch.sdaa.current_stream作为参数。

                                                      事件与流需要在同一台SDAA设备。



 返回值


文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                            295

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   API 参考




无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> e = torch.sdaa.Event()
   >>> e.record()
   >>> e.wait(s)




13.6 torch.sdaa.amp
13.6.1 torch.sdaa.amp.autocast

   _class_ torch.sdaa.amp.autocast(enabled: bool = True,
                                      dtype: torch.dtype = torch.float16,
                                      cache_enabled: bool = True)




 功能介绍

实例化一个autocast的上下文管理器，在该上下文管理器下执行的计算都以混合精度进行。

 参数解释

 名称                 类型                         说明

                                               是否开启混合精度训练，默认值为True。
                                                    True：开启混合精度训练。
 enabled            bool
                                                    False：关闭混合精度训练。


                                               混合精度计算的计算类型，默认值为torch.float16。
                    torch.float16 |                 torch.float16：以FP16的精度进行计算。
 dtype
                    torch.bfloat16
                                                    torch.bfloat16：以BF16的精度进行计算。


                                               在精度转换的过程中，是否开启cache优化功能，默认值为True。
 cache_ena                                          True：开启。
                    bool
 bled
                                                    False：关闭。



 返回值



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                        296

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                       API 参考




无。

 使用示例

   import torch
   import torch_sdaa


   x_fp32 = torch.randn((2, 2), dtype=torch.float32, device='sdaa')
   x_fp16 = torch.randn((2, 2), dtype=torch.float16, device='sdaa')


   with torch.sdaa.amp.autocast():
       y1 = torch.log(x_fp16)          # amp policy=fp32
       y2 = torch.mm(x_fp32, x_fp32)   # amp policy=lower_precision_fp
   assert(y1.dtype == torch.float32)
   assert(y2.dtype == torch.float16)


   with torch.sdaa.amp.autocast(dtype=torch.bfloat16):
       y = torch.mm(x_fp32, x_fp32)    # amp policy=lower_precision_fp
   assert(y.dtype == torch.bfloat16)




13.6.2 torch.sdaa.amp.GradScaler

   _class_ torch.sdaa.amp.GradScaler(init_scale=2.**16, growth_factor=2.0, backoff_factor=0.5, growth_inte
   rval=2000, enabled=True)




 功能介绍

如果某个算子的正向计算是FP16 输入，则该算子的反向计算将产生 FP16的梯度。较小的梯度值可能无法在float16中表
示。这些值将会被置为0（下溢），因此相应参数的更新将丢失。为了防止下溢，GradScaler将网络的损失函数值乘
以一个比例因子，并对缩放后的损失函数值调用反向传播。梯度值会变的更大，因此它们不会刷新为零。

 注意事项

每个参数的梯度（.grad 属性）在优化器更新参数之前应该是未缩放的，因此缩放因子不会影响学习率。

 参数解释

 名称               类型            说明

 init_scale       float         初始的缩放值，默认为2.0的16次方。

 growth_fac                     如果间隔growth_interval个迭代没有发现inf/NaN值，则缩放值会乘以
                  float
 tor                            growth_factor，默认为2.0。

 backoff_fac
                  float         如果当前迭代发现inf/NaN值，则缩放值会乘以backoff_factor，默认为0.5。
 tor




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                                 297

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                  API 参考




 名称                  类型             说明

 growth_inte
                     float          迭代次数，用于约束缩放值的变化。
 rval

                                    是否启用缩放功能，默认为True。
                                         True：开启。
 enabled             bool
                                         False：关闭。



 返回值

无。

 使用示例

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
        return Mnist()


   train_data = MNIST(
        root = './data',
        download = True,
        train = True,
        transform = torchvision.transforms.ToTensor()
   )# 数据集获取并完成预训练
   # 定义训练相关参数
   batch_size = 16




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司      298

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     API 参考




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




13.6.3 torch.sdaa.amp.is_autocast_enabled

   torch.sdaa.amp.is_autocast_enabled()




 功能介绍

查询autocast自动混合精度功能是否已被启用。

 参数解释

无。

 返回值

 名称             类型            说明

                              autocast自动混合精度功能是否已被启用：

                                   True：autocast自动混合精度功能已被启用。
 ret            bool
                                   False：autocast自动混合精度功能未被启用。



 使用示例

   >>> import torch
   >>> import torch_sdaa




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                           299

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          API 参考




   >>> with torch.sdaa.amp.autocast():
   ...     print(torch.sdaa.amp.is_autocast_enabled())
   True




13.6.4 torch.sdaa.amp.set_autocast_enabled

   torch.sdaa.amp.set_autocast_enabled(enable)




 功能介绍

设置开启或关闭autocast自动混合精度功能。


     说明：

     推荐使用torch.sdaa.amp.autocast上下文管理器控制autocast功能的启用和关闭。


 参数解释

 名称                   类型         说明

                                 是否开启autocast自动混合精度功能：
                                         True：启用autocast自动混合精度功能。
 enable               bool
                                         False：关闭autocast自动混合精度功能。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.amp.set_autocast_enabled(True)
   ...     print(torch.sdaa.amp.is_autocast_enabled())
   True
   >>> torch.sdaa.amp.set_autocast_enabled(False)
   ...     print(torch.sdaa.amp.is_autocast_enabled())
   False




13.6.5 torch.sdaa.amp.register_autocast_dtype_function

   torch.sdaa.amp.register_autocast_dtype_function(module, name, dtype)




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司               300

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                       API 参考




 功能介绍

为指定的函数注册AMP（Automatic Mixed Precision，自动混合精度）的规则。

 参数解释

 名称                   类型                          说明

                                                  函数对应的Python模块，例如：torch，
 module               python module
                                                  torch.nn.functional。

 name                 str                         函数名称。

                                                  需要注册的AMP规则：
                      torch.float16 |                  torch.float16：以FP16的精度进行计算。
 dtype
                      torch.float32
                                                       torch.float32：以 FP32 的精度进行计算。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.amp.register_autocast_dtype_function(torch, 'abs', torch.float16)
   >>> x = torch.randn((10, 20), dtype=torch.float32, requires_grad=True).to('sdaa')
   >>> with torch.sdaa.amp.autocast():
   ...     y = torch.abs(x)
   >>> print(y.dtype)
   torch.float16
   >>> torch.sdaa.amp.register_autocast_dtype_function(torch, 'abs', torch.float32)
   >>> x = torch.randn((10, 20), dtype=torch.float32, requires_grad=True).to('sdaa')
   >>> with torch.sdaa.amp.autocast():
   ...     y = torch.abs(x)
   >>> print(y.dtype)
   torch.float32




13.6.6 torch.sdaa.amp.register_autocast_dtype_module

   torch.sdaa.amp.register_autocast_dtype_module(module, name, dtype)




 功能介绍

为指定的torch.nn.Module类注册AMP（Automatic Mixed Precision，自动混合精度）的规则。



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                             301

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         API 参考




 参数解释

 名称                   类型                             说明

                                                     类对应的Python模块。


 module               python module                        提示：

                                                           目前该参数只支持设为torch.nn。


 name                 str                            类的名称。

                                                     需要注册的AMP规则：
                      torch.float16 |                     torch.float16：以FP16的精度进行计算。
 dtype
                      torch.float32
                                                          torch.float32：以FP32的精度进行计算。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.amp.register_autocast_dtype_module(torch.nn, 'Tanh', torch.float16)
   >>> x = torch.randn((10, 20), dtype=torch.float32, requires_grad=True).to("sdaa")
   >>> tanh = torch.nn.Tanh().to("sdaa")
   >>> with torch.sdaa.amp.autocast(enabled=True): y = tanh(x)
   >>> assert y.dtype == torch.float16




13.7 自定义算子API
13.7.1 torch.ops.sdaa.fused_fast_attention_v3

   torch.ops.sdaa.fused_fast_attention_v3




 功能介绍

  sdaa::fused_fast_attention_v3 是在 SDAA 计算设备上实现的融合 Flash Attention V3 算子（包含前向
+ Autograd 反向传播）。Python 侧通过                 torch.ops.sdaa.fused_fast_attention_v3 调用。


 参数解释



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                              302

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                               API 参考




 函数签名（Torch 算子 Schema）

   (Tensor query, Tensor key, Tensor value,
    float p_dropout, float softmax_scale, float grad_scalar,
    str softmax_mode, int head_begin, int total_head_num,
    int q_seq_len, int seq_offset,
    Tensor? sink=None, bool? causal=False, int[2]? window_size=None)
   -> (Tensor, Tensor)



第一个返回值为注意力输出，第二个为 softmax 的 log-sum-exp（ softmax_lse ），dtype 为
 float32 。

其它约定：

      query 、     key 、    value 的 dtype 须一致，且为                float16 /   bfloat16 /   float32 之
   一。内部计算会把 fp32 的 Q/K/V 转成 fp16 再算；若开启高精度融合输出（见环境变量一节），输出可为
   fp32。

      query 与      key 的最后一维（QK head dim）必须相同：                     q.size(3) == k.size(3) 。

      value 的最后一维（V head dim）可与 QK 维不同；输出最后一维与                             v.size(3) 一致。

   GQA / MQA：支持 query 头数多于 KV 头数，要求                    query.size(2) % key.size(2) == 0 ，且
      num_query_groups = query.size(2) // key.size(2) （实现中                   num_heads 取自 query 的头
   数）。
   张量布局与形状约束

   通过该公开算子调用时，实现里固定使用以下四维布局：

     轴      含义

     0      序列长度（query 侧为            q_seq_len 对应维；K/V 侧为 KV 序列长度              kv_seq_len ）

     1      batch_size

     2      头数

     3      每个头的特征维


     提示：

     直接调用        torch.ops.sdaa.fused_fast_attention_v3 时不暴露                 format_idx ，仅支持上述
         [S, B, H, D] 布局。若你的张量是                [B, S, H, D] 或          [B, H, S, D] ，需先   permute
     /   contiguous 成        [S, B, H, D] 再调用。



 参数详细说明




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                                         303

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             API 参考




 参数                  类型                  说明

     query ,
     key ,           Tensor              见上节布局与 dtype。
     value

     p_dropout       float               Attention dropout 概率。

     softmax_scal                        Softmax 前的缩放，常用         1/sqrt(d) ，   d 为 QK head
                     float
 e                                       dim。

     grad_scalar     float               反向时的梯度缩放系数（保存进 autograd 上下文）。

     softmax_mod
                     str                 掩码与 ALiBi 行为，见下表。
 e

                                         与    mask_up_alibi 等配合，表示当前分片 / heads 的起始
     head_begin      int
                                         head 索引（如张量并行）。

     total_head_n
                     int                 全局总 head 数（ALiBi 等场景）；非 ALiBi 时常为         0 。
 um

                                         Query 有效序列长度；若与          query.size(0) 一致，可直接传
     q_seq_len       int
                                             query.size(0) 。

                                         序列偏移（例如 KV cache / 分段注意力时 K/V 在全局序列中的起
     seq_offset      int
                                         点）。

                     Tensor |            可选一维 float32 张量，长度须等于 query.size(2)
     sink
                     None                （query 的 head 数）；不传或空表示不使用 sink。

                                         因果相关行为；若与 window_size 同时传入且为                True ，实
     causal          bool | None
                                         现会把 window_size 的右侧窗口置为 0。

                     tuple/list[int,i    可选长度为 2 的滑动窗口 [left, right] （负数可表示“无界”
     window_size
                     nt] | None          侧，具体语义以底层 tecocustom 库的文档为准）。


 softmax_mode 取值

仅支持以下字符串（否则报错）：

 取值                        含义

 "mask_up_tri"             上三角因果掩码

 "mask_up_alibi"           上三角 + ALiBi（需正确设置         head_begin /    total_head_num ）

 "mask_all"                全掩码，通常不会用到



文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                   304

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            API 参考




 取值                       含义

 "mask_none"              无掩码


 返回值

       out ：与     query 同 layout 类型，shape为             [query.size(0), query.size(1),
     query.size(2), value.size(3)] 。

       softmax_lse ：shape为            [batch_size, num_heads, q_seq_len] ，dtype恒为       float32 。

其中     batch_size 、      num_heads 由        query 的维 1、维 2 推出；         q_seq_len 为传入参数（通常等于
  query.size(0) ）。


 使用示例

   import math
   import torch


   # 假设已在 SDAA 上创建张量
   S, B, H, Dq, Dv = 128, 4, 8, 64, 64
   q = torch.randn(S, B, H, Dq, device="sdaa", dtype=torch.bfloat16)
   k = torch.randn(S, B, H, Dq, device="sdaa", dtype=torch.bfloat16)
   v = torch.randn(S, B, H, Dv, device="sdaa", dtype=torch.bfloat16)


   scale = 1.0 / math.sqrt(Dq)
   out, softmax_lse = torch.ops.sdaa.fused_fast_attention_v3(
       q, k, v,
       0.0,           # p_dropout
       scale,         # softmax_scale
       1.0,           # grad_scalar
       "mask_up_tri", # softmax_mode：上三角
       0,             # head_begin
       0,             # total_head_num
       S,             # q_seq_len
       0,             # seq_offset
       None,          # sink
       True,          # causal
       None,          # window_size
   )




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                 305

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                         第三方库支持列表
