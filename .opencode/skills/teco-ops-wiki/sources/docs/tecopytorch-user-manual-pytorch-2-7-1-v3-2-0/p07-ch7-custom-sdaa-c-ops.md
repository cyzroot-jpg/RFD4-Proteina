---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p07
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第7部分 (ch7-custom-sdaa-c-ops)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "7179-9044"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, custom-op, sdaa-extension, load-inline, cuda-migration, performance-analysis]
---

# TecoPyTorch 用户手册 v3.2.0（第7部分）

> 原文行范围：`7179-9044`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

7. 自定义SDAA C算子接入
7.1 基于SDAA Extenstion编写自定义算子
7.1.1 SDAA Extension简介
SDAA Extension是TecoPytorch提供的在Pytorch框架中适配自定义SDAA C算子的机制。通过SDAA Extension，
您可以将一个自定义的SDAA C算子接入到PyTorch框架中，并通过Python导入的方式实现算子的调用。


7.1.2 编写SDAA Extension
7.1.2.1 编写全新的SDAA C自定义算子
本文主要介绍如何编写一个全新的自定义SDAA C算子，将其接入到PyTorch框架，以实现您需要的算子功能。


     说明：

     自定义SDAA C算子接入PyTorch框架的方式与流程，与自定义C++/CUDA算子接入PyTorch框架的方式和
     流程基本一致，可参考 Custom C++ and CUDA Operators 了解详细信息。


 整体流程

编写一个自定义SDAA C算子的整体流程如下：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                 107

TecoPyTorch用户手册（适配PyTorch 2.7.1）                              自定义 SDAAC 算子接入




                                      图1 SDAA Extension编程流程

  1. 编写SDAA C算子：编写SDAA C算子，实现算子的计算功能。

 2. 编写自定义算子的C++函数：编写自定义算子的C++函数，用于Tensor数据处理以及对SDAA C算子的调用。

 3. 注册自定义算子为PyTorch算子：将自定义算子注册为PyTorch算子，使得在PyTorch框架的Python层能够调用
   到自定义算子。
 4. 编译算子：使用        setuptools 将SDAA C算子和C++函数代码编译成动态库。

 5. 调用自定义算子：在PyTorch框架中调用自定义算子。

 6. （可选）添加Compiler特性：为自定义算子添加torch.compile特性，使自定义算子支持Compiler功能。

 7. （可选）添加Autograd特性：为自定义算子添加torch.autograd特性，使自定义算子支持反向求导功能。


 步骤一：编写SDAA C算子

本例是一个实现float类型的Hardswish算子，介绍如何编写SDAA Extension，并实现自定义算子的
 torch.compile 和 autograd 特性支持。一个Extension的目录结构通常如下所示：




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                  108

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




   my_extension
   ├── setup.py                  # 编译安装
   ├── src
   │   ├── hardswish.cpp         # 自定义算子的C++函数实现和注册
   │   ├── teco_hardswish.h      # 自定义算子的SDAA C函数声明
   │   └── teco_hardswish.scpp   # 自定义算子的SDAA C函数实现
   └── test.py                   # 测试自定义算子



  1. 创建SDAA C文件            teco_hardswish.scpp ，编写实现           Hardswish 计算功能的SDAA C代码。代码如
   下：

           说明：

           本指南仅介绍 SDAA C算子接PyTorch 框架流程，如何使用SDAA C编写算子，可以参考《SDAA C编程
           指南》。


       // teco_hardswish.scpp
       #include <time.h>
       #include <string.h>
       #include <math.h>


       #include <simd.h>


       #include "teco_hardswish.h"


       namespace kernels {


       #define block_size 16
       #define ALIGN_DIV(a, b) ((a + b - 1) / b)
       #define MIN(a, b) ((a) < (b) ? (a) : (b))


       // hardswish算子的前向计算逻辑
       __device__ floatv16 hardswish_forward_impl(floatv16 self) {
             floatv16 zero = (floatv16)(0.0);
             floatv16 three = (floatv16)(3.0);
             floatv16 res = simd_selle(self + three, zero, self);   // self[i] <= -3.0
             res = simd_seleq((floatv16)(self == self), self, res);    // check nan
             res = simd_seleq((floatv16)(res >= three), res * (res + 3) / 6, res);
             return res;
       }


       // hardswish算子的反向计算逻辑
       __device__ floatv16 hardswish_backward_impl(floatv16 grad, floatv16 self) {
             floatv16 zero = (floatv16)(0.0);
             floatv16 three = (floatv16)(3.0);
             floatv16 neg_three = (floatv16)(-3.0);
             floatv16 one_half = (floatv16)(0.5);
             floatv16 res = simd_seleq((floatv16)(self < neg_three), grad * ((self / three) + one_half), zer
       o);
             res = simd_seleq((floatv16)(self <= three), grad, res);
             return res;
       }


       // 实现hardswish的前向计算kernel




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                  109

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                          自定义 SDAAC 算子接入




       __global__ void hardswish_forward_kernel(float* self, float* res, int len) {
           constexpr int MAX_BLK_LEN = (1 << 15) / sizeof(float);
           const int total_mem = ALIGN_DIV(len, (threadDim * block_size)) * block_size;
           const int max_mem = MIN(total_mem, MAX_BLK_LEN);


           if (threadIdx * total_mem > len) return;


           float* self_input = (float*)malloc(max_mem * sizeof(float));
           float* out = (float*)malloc(max_mem * sizeof(float));
           const int size = ALIGN_DIV(total_mem, max_mem);


           const int idx = threadIdx * total_mem;
           for (int i = 0; i < size; ++i) {
               sdaa::memcpy_async(self_input, self + idx + i * max_mem, max_mem * sizeof(float), sdaa::Mem
       cpyGlobalToSpm);
               sdaa::memcpy_wait();
               floatv16 self_v, res_v;
               for (int l = 0; l < max_mem; l += 16) {
                   simd_load(self_v, self_input + l);
                   res_v = hardswish_forward_impl(self_v);
                   simd_store(res_v, out + l);
               }
               sdaa::memcpy_async(res + idx + i * max_mem, out, max_mem * sizeof(float), sdaa::MemcpySpmTo
       Global);
           }
           sdaa::memcpy_wait();
           free(self_input);
           free(out);
       }


       // 实现hardswish的反向计算kernel
       __global__ void hardswish_backward_kernel(float* grad, float* self, float* res, int len) {
           constexpr int MAX_BLK_LEN = (1 << 15) / sizeof(float);
           const int total_mem = ALIGN_DIV(len, (threadDim * block_size)) * block_size;
           const int max_mem = MIN(total_mem, MAX_BLK_LEN);


           if (threadIdx * total_mem > len) return;


           float* self_input = (float*)malloc(max_mem * sizeof(float));
           float* grad_input = (float*)malloc(max_mem * sizeof(float));
           float* out = (float*)malloc(max_mem * sizeof(float));
           const int size = ALIGN_DIV(total_mem, max_mem);


           const int idx = threadIdx * total_mem;
           for (int i = 0; i < size; ++i) {
               sdaa::memcpy_async(self_input, self + idx + i * max_mem, max_mem * sizeof(float), sdaa::Mem
       cpyGlobalToSpm);
               sdaa::memcpy_async(grad_input, grad + idx + i * max_mem, max_mem * sizeof(float), sdaa::Mem
       cpyGlobalToSpm);
               sdaa::memcpy_wait();
               floatv16 self_v, grad_v, res_v;
               for (int l = 0; l < max_mem; l += 16) {
                   simd_load(self_v, self_input + l);
                   simd_load(grad_v, grad_input + l);
                   res_v = hardswish_backward_impl(grad_v, self_v);
                   simd_store(res_v, out + l);
               }
               sdaa::memcpy_async(res + idx + i * max_mem, out, max_mem * sizeof(float), sdaa::MemcpySpmTo
       Global);




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                               110

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             自定义 SDAAC 算子接入




              }
              sdaa::memcpy_wait();
              free(self_input);
              free(grad_input);
              free(out);
        }


        // 实现简单的函数调用，launchkernel在这里，简称为kernel_launcher函数
        void sdaa_hardswish_forward(sdaaStream_t stream, const float* input, float* out, int num) {
            hardswish_forward_kernel<<<1, stream>>>(const_cast<float*>(input), out, num);
        }


        // 同上，实现hardswish的反向函数调用
        void sdaa_hardswish_backward(sdaaStream_t stream, const float* grad, const float* input, float* ou
        t, int num) {
            hardswish_backward_kernel<<<1, stream>>>(const_cast<float*>(grad), const_cast<float*>(input), ou
        t, num);
        }


        }    // end namespace kernels


   其中：

             hardswish_forward_kernel 和          hardswish_backward_kernel 是Device端实现Hardswish
         前/反向计算的函数。
             sdaa_hardswish_forward 和          sdaa_hardswish_backward 是Host端的调用函数。

 2. 在    my_extension/src 文件夹下创建                teco_hardswish.h 头文件，在头文件中增加
        sdaa_hardswish_forward 和           sdaa_hardswish_backward 函数的声明，代码如下：

        // teco_hardswish.h
        #pragma once
        #include <sdaa_runtime.h>


        namespace kernels {
        void sdaa_hardswish_forward(sdaaStream_t stream, const float* input, float* out, int num);


        void sdaa_hardswish_backward(sdaaStream_t stream, const float* grad, const float* input, float* ou
        t, int num);


        }    // namespace kernels




 步骤二：编写自定义算子的C++函数

在 my_extension/src 文件夹下创建文件 hardswish.cpp ，编写Host端自定义C++ 算子，该部分代码主要
用于处理Tensor等Torch的数据类型检查和转换，以及调用 teco_hardswish.scpp 文件中定义的
 sdaa_hardswish_forward 和 sdaa_hardswish_backward 函数。代码如下：


     提示：

         .scpp文件 和         .cpp 文件名不能相同。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                                 111

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




       说明：

       PyTorch 2.0之后，官方提供了第三方后端设备支持，命名为                           PrivateUse1 ，以下代码中写到的
         PrivateUse1 指代的都是SDAA设备，详细信息请参考PrivateUse1官方文档。



   // hardswish.cpp
   // 1. include需要的头文件，至少需要包含下面三部分
   // 1.1 torch提供的extension所需的头文件
   #include <torch/extension.h>


   // 1.2 tecopytorch提供的extension所需的头文件
   // 包括 torch::sdaa::getCurrentSDAAStream(); torch::sdaa::synchronize(); torch::sdaa::get_default_genera
   tor()
   #include <torch_sdaa/sdaa_extension.h>


   // 1.3 包含kernel_launcher函数声明的头文件
   #include "teco_hardswish.h"


   // 这部分可能会涉及到pytorch的一些数据结构，可以参照pytorch官网。
   // hardswish前向算子
   at::Tensor hardswish_forward(const at::Tensor& input) {
       // 检查输入的数据类型是否为float
       TORCH_CHECK(input.dtype() == at::kFloat);
       // 检查输入的设备类型是否为SDAA
       TORCH_INTERNAL_ASSERT(input.device().type() == at::kPrivateUse1);


       // 将输入数据转换为连续的Tensor
       at::Tensor input_contig = input.contiguous();
       at::Tensor output = at::empty_like(input_contig);


       const float* input_ptr = input_contig.data_ptr<float>();
       float* output_ptr = output.data_ptr<float>();


       // 调用kernel_launcher中的hardswish前向算子
       kernels::sdaa_hardswish_forward(torch::sdaa::getCurrentSDAAStream(), input_ptr, output_ptr, input_con
   tig.numel());
       return output;
   }


   // hardswish反向算子
   at::Tensor hardswish_backward(const at::Tensor& grad, const at::Tensor& input) {
       // 检查输入的数据类型是否为float
       TORCH_CHECK(grad.dtype() == at::kFloat);
       TORCH_CHECK(input.dtype() == at::kFloat);
       // 检查输入的设备类型是否为SDAA
       TORCH_INTERNAL_ASSERT(grad.device().type() == at::kPrivateUse1);
       TORCH_INTERNAL_ASSERT(input.device().type() == at::kPrivateUse1);


       // 将输入数据转换为连续的Tensor
       at::Tensor grad_contig = grad.contiguous();
       at::Tensor input_contig = input.contiguous();
       at::Tensor output = at::empty_like(input_contig);


       const float* grad_ptr = grad_contig.data_ptr<float>();
       const float* input_ptr = input_contig.data_ptr<float>();




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                  112

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




       float* output_ptr = output.data_ptr<float>();


       // 调用kernel_launcher中的hardswish反向算子
       kernels::sdaa_hardswish_backward(torch::sdaa::getCurrentSDAAStream(), grad_ptr, input_ptr, output_pt
   r, input.numel());
       return output;
   }




 步骤三：注册自定义算子为PyTorch算子

PyTorch框架提供了TORCH_LIBRARY宏，用于将一个自定义算子注册为PyTorch算子。注册后的自定义算子会被自
动绑定到PyTorch框架的Python层，从而使Python层可以调用到该自定义算子。


       说明：

       该步骤涉及的代码和步骤二的代码写在同一个cpp文件中。


将自定义算子注册为PyTorch算子的主要流程如下：

  1. 初始化自定义算子注册。注册自定义算子到PyTorch框架，需要先执行自定义算子注册的静态初始化。

 2. 注册自定义算子。

       a. 定义算子Schema：定义自定义算子的接口规范，例如：算子名和算子输入输出信息。

       b. 绑定后端：将自定义算子绑定到SDAA计算后端。


 1. 初始化自定义算子注册

通过 PYBIND11_MODULE 定义一个Python dummy module，确保在Python层导入自定义算子模块时，能够执
行自定义算子注册的静态初始化。

   // 定义一个Python dummy module，执行Python初始化相关操作
   PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {}




 2. 注册自定义算子

  1. 按照PyTorch的格式，定义并注册算子名和输入输出信息。

       a. 为算子选择一个namespace。建议选择项目的顶层目录名称作为算子命名空间名，本示例使用
            my_extension 作为算子namespace。

       b. 定义算子的Schema字符串，指定算子的输入和输出信息以及输入Tensor是否会发生变化。示例代码如下：


                说明：

                除支持Tensor和float类型外，也支持其他更多数据类型，具体类型和Schema格式请参考PyTorch
                官方文档。




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                 113

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




               // 定义my_hardswish前向和反向算子，注册到my_extension命名空间下
               TORCH_LIBRARY(my_extension, m) {
                   m.def("my_hardswish(Tensor a) -> Tensor");
                   m.def("my_hardswish_backward(Tensor grad, Tensor input) -> Tensor");
               }



 2. 注册自定义算子到SDAA后端。使用                       TORCH_LIBRARY_IMPL 将算子的C++函数指针绑定到算子对应的后端，
   使Python层调用自定义算子时能够调用到对应的SDAA C算子。示例代码如下：

         // 注册my_hardswish前向和反向算子到SDAA后端
         TORCH_LIBRARY_IMPL(my_extension, PrivateUse1, m) {
             m.impl("my_hardswish", &hardswish_forward);
             m.impl("my_hardswish_backward", &hardswish_backward);
         }



添加注册相关代码后，此时 hardswish.cpp 的完整代码如下：

   // hardswish.cpp
   // include需要的头文件，至少需要包含下面三部分
   // 1. torch提供的extension所需的头文件
   #include <torch/extension.h>


   // 2. tecopytorch提供的extension所需的头文件
   // 包括 torch::sdaa::getCurrentSDAAStream(); torch::sdaa::synchronize(); torch::sdaa::get_default_genera
   tor()
   #include <torch_sdaa/sdaa_extension.h>


   // 3. 包含kernel_launcher函数声明的头文件
   #include "teco_hardswish.h"


   // 这部分可能会涉及到pytorch的一些数据结构，可以参照pytorch官网。
   // hardswish前向算子
   at::Tensor hardswish_forward(const at::Tensor& input) {
       // 检查输入的数据类型是否为float
       TORCH_CHECK(input.dtype() == at::kFloat);
       // 检查输入的设备类型是否为SDAA
       TORCH_INTERNAL_ASSERT(input.device().type() == at::kPrivateUse1);


       // 将输入数据转换为连续的Tensor
       at::Tensor input_contig = input.contiguous();
       at::Tensor output = at::empty_like(input_contig);


       const float* input_ptr = input_contig.data_ptr<float>();
       float* output_ptr = output.data_ptr<float>();


       // 调用kernel_launcher中的hardswish前向算子
       kernels::sdaa_hardswish_forward(torch::sdaa::getCurrentSDAAStream(), input_ptr, output_ptr, input_con
   tig.numel());
       return output;
   }


   // hardswish反向算子
   at::Tensor hardswish_backward(const at::Tensor& grad, const at::Tensor& input) {
       // 检查输入的数据类型是否为float
       TORCH_CHECK(grad.dtype() == at::kFloat);




文档版本：v3.2.0                                 版权所有 © 太初(无锡)电子科技有限公司                                              114

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




       TORCH_CHECK(input.dtype() == at::kFloat);
       // 检查输入的设备类型是否为SDAA
       TORCH_INTERNAL_ASSERT(grad.device().type() == at::kPrivateUse1);
       TORCH_INTERNAL_ASSERT(input.device().type() == at::kPrivateUse1);


       // 将输入数据转换为连续的Tensor
       at::Tensor grad_contig = grad.contiguous();
       at::Tensor input_contig = input.contiguous();
       at::Tensor output = at::empty_like(input_contig);


       const float* grad_ptr = grad_contig.data_ptr<float>();
       const float* input_ptr = input_contig.data_ptr<float>();
       float* output_ptr = output.data_ptr<float>();


       // 调用kernel_launcher中的hardswish反向算子
       kernels::sdaa_hardswish_backward(torch::sdaa::getCurrentSDAAStream(), grad_ptr, input_ptr, output_pt
   r, input.numel());
       return output;
   }


   // 定义一个dummy Python module，执行Python初始化相关操作
   PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {}


   // 定义my_hardswish前向和反向算子，注册到my_extension命名空间下
   TORCH_LIBRARY(my_extension, m) {
       m.def("my_hardswish(Tensor a) -> Tensor");
       m.def("my_hardswish_backward(Tensor grad, Tensor input) -> Tensor");
   }


   // 注册my_hardswish前向和反向算子到SDAA后端
   TORCH_LIBRARY_IMPL(my_extension, PrivateUse1, m) {
       m.impl("my_hardswish", &hardswish_forward);
       m.impl("my_hardswish_backward", &hardswish_backward);
   }




 步骤四：编译算子

  1. 在    my_extension/ 目录下创建            setup.py 文件，编写编译和安装代码。代码如下：


            说明：

                编译算子时，需要通过 torch_sdaa.utils.cpp_extension 导入 TecoExtension 、
                  BuildExtension 和 CleanExtension 模块，将setuptools原生的构建函数替换成SDAA
                Extension提供的函数。

                  TecoExtension 、        BuildExtension 和         CleanExtension 模块，用于对SDAA C算子
                进行编译。


         from setuptools import setup, find_packages
         import torch, torch_sdaa
         from torch_sdaa.utils.cpp_extension import TecoExtension, BuildExtension, CleanExtension


         ext_name = 'my_extension'




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                                 115

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   自定义 SDAAC 算子接入




       setup(name=ext_name,    # Python模块名称，使用时import的名字
              ext_modules=[
                   TecoExtension( # 添加一个或多个TecoExtension
                       name=ext_name, # C++扩展模块名称，保持相同即可
                       # 指定要编译的文件
                       sources=['src/teco_hardswish.scpp', 'src/hardswish.cpp'])
              ],
              install_requires=['torch', 'torch_sdaa'],
              cmdclass={'build_ext': BuildExtension, 'clean': CleanExtension})


 2. 执行以下命令，编译自定义算子插件：


       python setup.py build_ext -i



编译完成后，会在 my_extension/ 目录下生成一个 my_extension.cpython-310-x86_64-linux-
gnu.so 动态库文件。


     说明：

     如果需要删除编译相关文件，可以通过 python setup.py clean 命令进行清除。


 步骤五：调用自定义算子

在Python命令行，执行如下代码，测试自定义算子是否能够调用成功。该代码通过与PyTorch框架的 Hardswish
计算结果进行对比，验证自定义算子的计算结果是否正确。


     提示：

     执行测试时的运行目录，必须有生成的 my_extension.cpython-310-x86_64-linux-gnu.so 文
     件。否则调自定义算子时，无法正常导入 my_extension 安装包。


   import torch
   import torch_sdaa


   # 使用自定义算子my_hardswish前，需要先导入动态库扩展模块
   import my_extension
   # 自定义算子绑定在Python层的torch.ops下
   def ext_hardswish(a):
       return torch.ops.my_extension.my_hardswish(a)


   a = torch.randn(10, 2)
   input_cpu = a.clone()
   input_sdaa = a.clone().to('sdaa')


   output_cpu = torch.nn.Hardswish()(input_cpu)
   output_sdaa = ext_hardswish(input_sdaa)
   print(torch.allclose(output_cpu, output_sdaa.cpu()))




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                  116

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             自定义 SDAAC 算子接入




示例输出结果如下：

   True




 （可选）步骤六：添加Compiler特性

如果需要在PyTorch的Compiler场景下使用自定义算子，您可以在调用自定义算子前，为自定义算子注册一个
 FakeTensor Kernel，实现自定义算子对torch.compile特性的支持。


     说明：

     关于Fake Tensor功能的详细介绍，可参考PyTorch官网文档说明。


注册自定义算子 FakeTensor Kernel，需要包含以下内容：

  1. 导入动态库扩展模块。


          # 使用自定义算子前，需要先导入动态库扩展模块
          import my_extension


 2. 使用      torch.library.register_fake 函数，注册自定义算子的                        FakeTensor 实现。


          @torch.library.register_fake("my_extension::my_hardswish")
          def _(a):
              torch._check(a.dtype == torch.float)
              return torch.empty_like(a)



 3. 添加torch.compile接口，实现图编译优化功能。


          compiled_fn = torch.compile(test_ext_hardswish_compile, backend='teco_inductor')



以 hardswish 自定义算子为例，为其添加torch.compile特性的示例代码如下：

   import torch
   import torch_sdaa


   # 使用自定义算子my_hardswish前，需要先导入动态库扩展模块
   import my_extension


   def ext_hardswish(a):
       return torch.ops.my_extension.my_hardswish(a)


   # torch.compile 支持
   # 注册hardswish的FakeTensor实现
   @torch.library.register_fake("my_extension::my_hardswish")
   def _(a):
       torch._check(a.dtype == torch.float)
       return torch.empty_like(a)




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                         117

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      自定义 SDAAC 算子接入




   # 测试torch.compile
   a = torch.randn(10, 2)
   input_cpu = a.clone()
   input_sdaa = a.clone().to('sdaa')


   def test_ext_hardswish_compile(a):
       return ext_hardswish(a)


   compiled_fn = torch.compile(test_ext_hardswish_compile, backend='teco_inductor')


   output_cpu = torch.nn.Hardswish()(input_cpu)
   output_sdaa = compiled_fn(input_sdaa)
   print(torch.allclose(output_cpu, output_sdaa.cpu()))



运行上述代码，输出结果为True，表示torch.compile特性添加成功。

   True




  （可选）步骤七：添加Autograd特性

为使自定义算子支持模型训练时的反向求导，您可以使用 torch.library.register_autograd 函数，为自定
义算子注册 autograd 特性。

注册 autograd 特性，需要包含以下内容：

  1. 导入动态库扩展模块。


          # 使用自定义算子前，需要先导入动态库扩展模块
          import my_extension


 2. 定义反向求导函数。

 3. 使用        torch.library.register_autograd 函数注册               autograd 特性。


          torch.library.register_autograd(
              "my_extension::my_hardswish", _backward, setup_context=_setup_context
          )



以 hardswish 自定义算子为例，为其添加 autograd 特性的示例代码如下：

   import torch
   import torch_sdaa


   # 使用自定义算子my_hardswish前，需要先导入动态库扩展模块
   import my_extension


   def ext_hardswish(a):
       return torch.ops.my_extension.my_hardswish(a)


   def ext_hardswish_backward(grad, a):
       return torch.ops.my_extension.my_hardswish_backward(grad, a)




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                                    118

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                自定义 SDAAC 算子接入




   # 定义反向求导函数
   def _backward(ctx, grad):
        a = ctx.saved_tensors[0]
        grad_a = None
        if ctx.needs_input_grad[0]:
            grad_a = ext_hardswish_backward(grad, a)
        return grad_a


   # 定义设置上下文函数
   def _setup_context(ctx, inputs, output):
        a = inputs[0]
        saved_a = None
        if ctx.needs_input_grad[0]:
            saved_a = a
        # 保存输入
        ctx.save_for_backward(saved_a)


   torch.library.register_autograd(
        "my_extension::my_hardswish", _backward, setup_context=_setup_context
   )


   # 前向测试
   a = torch.randn(10, 2)
   input_cpu = a.clone().requires_grad_()
   input_sdaa = a.clone().to('sdaa').requires_grad_()


   output_cpu = torch.nn.Hardswish()(input_cpu)
   output_sdaa = ext_hardswish(input_sdaa)
   print(torch.allclose(output_cpu, output_sdaa.cpu()))


   # 反向测试
   grad_output = torch.randn_like(a)
   grad_cpu = grad_output.clone()
   grad_sdaa = grad_output.clone().to('sdaa')


   output_cpu.backward(grad_cpu)
   output_sdaa.backward(grad_sdaa)
   print(torch.allclose(input_cpu.grad, input_sdaa.grad.cpu()))



运行上述代码，前向和方向的输出结果均为True，表示 autograd 特性添加成功。

   True
   True




 示例2：3D-VLP模型自定义算子

模型仓库见：https://github.com/leolyj/3D-VLP

原始的模型代码中含有CUDA自定义算子，在lib/pointnet2/_ext_src/src的.cu文件中，为了在SDAA设备上运行此
模型，需要编写相应的SDAA自定义算子，我们将SDAA自定义算子放在lib/pointnet2_sdaa目录下，以
lib/pointnet2/_ext_src/src/ball_query_gpu.cu文件中的CUDA算子为例，其原始代码如下：


   // Copyright (c) Facebook, Inc. and its affiliates.
   //




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                              119

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




   // This source code is licensed under the MIT license found in the
   // LICENSE file in the root directory of this source tree.


   #include <math.h>
   #include <stdio.h>
   #include <stdlib.h>


   #include "cuda_utils.h"


   // input: new_xyz(b, m, 3) xyz(b, n, 3)
   // output: idx(b, m, nsample)
   __global__ void query_ball_point_kernel(int b, int n, int m, float radius,
                                                       int nsample,
                                                       const float *__restrict__ new_xyz,
                                                       const float *__restrict__ xyz,
                                                       int *__restrict__ idx) {
       int batch_index = blockIdx.x;
       xyz += batch_index * n * 3;
       new_xyz += batch_index * m * 3;
       idx += m * nsample * batch_index;


       int index = threadIdx.x;
       int stride = blockDim.x;


       float radius2 = radius * radius;
       for (int j = index; j < m; j += stride) {
           float new_x = new_xyz[j * 3 + 0];
           float new_y = new_xyz[j * 3 + 1];
           float new_z = new_xyz[j * 3 + 2];
           for (int k = 0, cnt = 0; k < n && cnt < nsample; ++k) {
               float x = xyz[k * 3 + 0];
               float y = xyz[k * 3 + 1];
               float z = xyz[k * 3 + 2];
               float d2 = (new_x - x) * (new_x - x) + (new_y - y) * (new_y - y) +
                                (new_z - z) * (new_z - z);
               if (d2 < radius2) {
                   if (cnt == 0) {
                       for (int l = 0; l < nsample; ++l) {
                           idx[j * nsample + l] = k;
                       }
                   }
                   idx[j * nsample + cnt] = k;
                   ++cnt;
               }
           }
       }
   }


   void query_ball_point_kernel_wrapper(int b, int n, int m, float radius,
                                                    int nsample, const float *new_xyz,
                                                    const float *xyz, int *idx) {
       cudaStream_t stream = at::cuda::getCurrentCUDAStream();
       query_ball_point_kernel<<<b, opt_n_threads(m), 0, stream>>>(
               b, n, m, radius, nsample, new_xyz, xyz, idx);


       CUDA_CHECK_ERRORS();
   }




文档版本：v3.2.0                                       版权所有 © 太初(无锡)电子科技有限公司                                 120

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         自定义 SDAAC 算子接入




首先将其包含的头文件 cuda_utils.h 中的CUDA函数接口换成对应SDAA C函数接口，然后对cu文件中的函数进
行改写，改写成SDAA后的代码如下：

   // Copyright (c) Facebook, Inc. and its affiliates.
   //
   // This source code is licensed under the MIT license found in the
   // LICENSE file in the root directory of this source tree.


   #include <math.h>
   #include <stdio.h>
   #include <stdlib.h>


   #include "sdaa_utils.h"


   // input: new_xyz(b, m, 3) xyz(b, n, 3)
   // output: idx(b, m, nsample)
   __global__ void query_ball_point_kernel(dim3 sdaaGridDim, dim3 sdaaBlockDim,
                                               int b, int n, int m, float radius,
                                               int nsample,
                                               const float *__restrict__ new_xyz,
                                               const float *__restrict__ xyz,
                                               int *__restrict__ idx) {
     int linearblockDim = sdaaGridDim.z * sdaaGridDim.y * sdaaGridDim.x;
     // threadIdx


     for (int linearblockIdx = threadIdx; linearblockIdx < linearblockDim;
             linearblockIdx += 32) {
        // z = i / (DimX * DimY);
        // int remainder = i % (DimX * DimY);
        // y = remainder / DimX;
        // x = remainder % DimX;


        int blockIdx_z =
              linearblockIdx / (sdaaGridDim.x * sdaaGridDim.y); // 计算z坐标
        int remainder = linearblockIdx %
                          (sdaaGridDim.x * sdaaGridDim.y); // 剩余部分用于计算y和x
        int blockIdx_y = remainder / sdaaGridDim.x;           // 计算y坐标
        int blockIdx_x = remainder % sdaaGridDim.x;           // 计算x坐标


        //     for (int blockIdx_z = 0; blockIdx_z < sdaaGridDim.z; blockIdx_z ++) {
        //       for (int blockIdx_y = 0; blockIdx_y < sdaaGridDim.y; blockIdx_y ++) {
        //         for (int blockIdx_x = 0; blockIdx_x < sdaaGridDim.x; blockIdx_x ++)
        //         {


        for (int threadIdx_z = 0; threadIdx_z < sdaaBlockDim.z; threadIdx_z++) {
          for (int threadIdx_y = 0; threadIdx_y < sdaaBlockDim.y; threadIdx_y++) {
              for (int threadIdx_x = 0; threadIdx_x < sdaaBlockDim.x; threadIdx_x++) {


               int batch_index = blockIdx_x;
               xyz += batch_index * n * 3;
               new_xyz += batch_index * m * 3;
               idx += m * nsample * batch_index;


               int index = threadIdx_x;
               int stride = sdaaBlockDim.x;


               float radius2 = radius * radius;




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                      121

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                    自定义 SDAAC 算子接入




                       for (int j = index; j < m; j += stride) {
                           // m * 3
                           float new_x = new_xyz[j * 3 + 0];
                           float new_y = new_xyz[j * 3 + 1];
                           float new_z = new_xyz[j * 3 + 2];
                           for (int k = 0, cnt = 0; k < n && cnt < nsample; ++k) {
                               // n * 3
                               float x = xyz[k * 3 + 0];
                               float y = xyz[k * 3 + 1];
                               float z = xyz[k * 3 + 2];
                               float d2 = (new_x - x) * (new_x - x) + (new_y - y) * (new_y - y) +
                                                (new_z - z) * (new_z - z);
                               if (d2 < radius2) {
                                   if (cnt == 0) {
                                       for (int l = 0; l < nsample; ++l) {
                                           // m * nsample
                                           idx[j * nsample + l] = k;
                                       }
                                   }
                                   idx[j * nsample + cnt] = k;
                                   ++cnt;
                               }
                           }
                       }
                   }
               }
           }
       }
   }


   void query_ball_point_kernel_wrapper(int b, int n, int m, float radius,
                                                            int nsample, const float *new_xyz,
                                                            const float *xyz, int *idx) {
       // cudaStream_t stream = at::cuda::getCurrentCUDAStream();
       //      Launch kernel
       dim3 blocks(b);
       dim3 threads(256); // Number of threads per block
       query_ball_point_kernel<<<1>>>(blocks, threads, b, n, m, radius, nsample,
                                                        new_xyz, xyz, idx);


       SDAA_CHECK_ERRORS();
   }



对应的setup.py文件修改如下：

   # Copyright (c) Facebook, Inc. and its affiliates.
   #
   # This source code is licensed under the MIT license found in the
   # LICENSE file in the root directory of this source tree.


   from setuptools import setup
   import torch
   import torch_sdaa
   from torch_sdaa.utils.cpp_extension import TecoExtension, BuildExtension, CleanExtension
   import glob


   _ext_src_root = "_ext_src"




文档版本：v3.2.0                                                 版权所有 © 太初(无锡)电子科技有限公司                               122

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




   _ext_sources = glob.glob("{}/src/*.cpp".format(_ext_src_root)) + glob.glob(
       "{}/src/*.scpp".format(_ext_src_root)
   )
   _ext_headers = glob.glob("{}/include/*".format(_ext_src_root))


   setup(
       name='pointnet2',
       ext_modules=[
            TecoExtension(
                name='pointnet2._ext',
                sources=_ext_sources,
                extra_compile_args={
                     #"cxx": ["-O2", "-I{}".format("{}/include".format(_ext_src_root))],
                     #"nvcc": ["-O2", "-I{}".format("{}/include".format(_ext_src_root))],
                },
            )
       ],
       cmdclass={
            'build_ext': BuildExtension
       }



对group_points_gpu.cu、interpolate_gpu.cu和sampling_gpu.cu文件也进行相应改写，最后在
lib/pointnet2_sdaa目录下执行以下命令编译自定义算子：


   python setup.py build_ext




7.1.2.2 改写CUDA自定义算子为SDAA C自定义算子
将开源模型迁移至太初AI加速卡训练时，若原始模型包含CUDA自定义算子，您需要将其改写为对应的SDAA C算子，
以确保模型在太初AI加速卡上无缝运行。

本文将以3D-VLP模型为例，介绍如何改写模型中的CUDA自定义算子，并将其接入到TecoPyTorch框架，使模型能够
在太初AI加速卡上运行。

 前提条件

包含CUDA自定义算子的模型，在CUDA设备上能成功运行。

 3D-VLP模型自定义算子

模型仓库见：https://github.com/leolyj/3D-VLP。

该模型是一种融合三维视觉与语言理解的预训练模型，旨在通过多模态对齐实现更深入的场景理解与交互能力。其核
心目标是将3D视觉数据（如点云、深度图等）与自然语言描述关联，支持机器人操作、医学诊断、导航规划等下游任
务。

原始的模型仓库含有4个CUDA自定义算子，即 lib/pointnet2/_ext_src/src 目录下的4个 .cu 文件。自
定义算子的目录结构如下所示：




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                         123

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                    自定义 SDAAC 算子接入




   lib/pointnet2/
   ├── _ext-src/
   │   ├── include/
   │   ├── src/
   │   │   ├── ball_query_gpu.cu    # ball_query kernel实现
   │   │   ├── group_points_gpu.cu # group_point kernel实现
   │   │   ├── interpolate_gpu.cu   # interpolate kernel实现
   │   │   ├── sampling_gpu.cu      # sampling kernel实现
   │   │   └── ...
   ├── pointnet2_utils.py           # Python接口封装
   └── setup.py                     # CUDA扩展编译脚本




 适配流程

PyTorch接入SDAA C自定义算子的方式和流程，与PyTorch接入CUDA自定义算子的基本一致，主要差异在自定义算
子的Kernel编程语言和函数编译模块。因此，想要在太初AI加速卡上运行包含CUDA自定义算子的模型，请参考以下流
程修改相应代码：




                                    图1 CUDA自定义算子改写为SDAA C自定义算子的流程

  1. 编写SDAA C算子Kernel：参考CUDA自定义算子Kernel，使用SDAA C编程语言（详情请参考《SDAA C编程指
   南》的快速入门章节），实现相应的SDAA C算子Kernel。
 2. 改写C++源文件中的CUDA函数为SDAA C函数：使用SDAA C编程语言（详情请参考《SDAA C编程指南》的快
   速入门章节），将C++源文件中用到的CUDA头文件、宏定义、数据结构和Runtime接口等，改写成对应的SDAA
   C实现。

 3. 编写SDAA C自定义算子的编译脚本：参考CUDA自定义算子的编译脚本，编写SDAA C自定义算子的编译脚本。


 步骤一：编写SDAA C算子Kernel

参考CUDA自定义算子Kernel，使用SDAA C编程语言，实现相应的SDAA C算子Kernel。具体步骤如下：

  1. 下载3D-VLP模型仓库的代码。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                    124

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                        自定义 SDAAC 算子接入




       git clone https://github.com/leolyj/3D-VLP.git


 2. 参考仓库中CUDA自定义算子的目录结构，在                           lib 目录下，创建适配SDAA C自定义算子的目录结构
   （ include 目录为非必需），示例如下：

       lib/pointnet2_sdaa/
       ├── _ext-src/
       │     ├── include/
       │     ├── src/
       │     │   ├── sdaa_utils.h
       │     │   ├── ball_query_gpu.scpp      # ball_query kernel实现
       │     │   ├── group_points_gpu.scpp # group_point kernel实现
       │     │   ├── interpolate_gpu.scpp     # interpolate kernel实现
       │     │   ├── sampling_gpu.scpp        # sampling kernel实现
       │     │   └── ...
       ├── pointnet2_utils.py              # Python接口封装
       └── setup.py                        # CUDA扩展编译脚本


 3. 进入      lib/pointnet2_sdaa/_ext_src/src/ 目录，按照《SDAA C编程指南》，将所有CUDA自定义算子
   的Kernel，改写为SDAA C自定义算子Kernel。
   以 ball_query_gpu.cu 文件中的 ball_query 算子为例，其原始代码如下：

       // Copyright (c) Facebook, Inc. and its affiliates.
       //
       // This source code is licensed under the MIT license found in the
       // LICENSE file in the root directory of this source tree.


       #include <math.h>
       #include <stdio.h>
       #include <stdlib.h>


       #include "cuda_utils.h"


       // input: new_xyz(b, m, 3) xyz(b, n, 3)
       // output: idx(b, m, nsample)
       __global__ void query_ball_point_kernel(int b, int n, int m, float radius,
                                                   int nsample,
                                                   const float *__restrict__ new_xyz,
                                                   const float *__restrict__ xyz,
                                                   int *__restrict__ idx) {
           int batch_index = blockIdx.x;
           xyz += batch_index * n * 3;
           new_xyz += batch_index * m * 3;
           idx += m * nsample * batch_index;


           int index = threadIdx.x;
           int stride = blockDim.x;


           float radius2 = radius * radius;
           for (int j = index; j < m; j += stride) {
             float new_x = new_xyz[j * 3 + 0];
             float new_y = new_xyz[j * 3 + 1];
             float new_z = new_xyz[j * 3 + 2];
             for (int k = 0, cnt = 0; k < n && cnt < nsample; ++k) {




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                                    125

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                自定义 SDAAC 算子接入




                   float x = xyz[k * 3 + 0];
                   float y = xyz[k * 3 + 1];
                   float z = xyz[k * 3 + 2];
                   float d2 = (new_x - x) * (new_x - x) + (new_y - y) * (new_y - y) +
                                   (new_z - z) * (new_z - z);
                   if (d2 < radius2) {
                       if (cnt == 0) {
                           for (int l = 0; l < nsample; ++l) {
                               idx[j * nsample + l] = k;
                           }
                       }
                       idx[j * nsample + cnt] = k;
                       ++cnt;
                   }
               }
           }
       }


       void query_ball_point_kernel_wrapper(int b, int n, int m, float radius,
                                                        int nsample, const float *new_xyz,
                                                        const float *xyz, int *idx) {
           cudaStream_t stream = at::cuda::getCurrentCUDAStream();
           query_ball_point_kernel<<<b, opt_n_threads(m), 0, stream>>>(
                   b, n, m, radius, nsample, new_xyz, xyz, idx);


           CUDA_CHECK_ERRORS();
       }


   基于SDAA C编程语言，实现的 ball_query 算子Kernel如下：


            说明：

            需要对所有的自定义CUDA算子Kernel（即__global__函数）进行改写，3D-VLP模型需要修改的自定
            义算子包括： ball_query 、 group_points 、 interpolate 和 sampling 。


       // Copyright (c) Facebook, Inc. and its affiliates.
       //
       // This source code is licensed under the MIT license found in the
       // LICENSE file in the root directory of this source tree.


       #include <math.h>
       #include <stdio.h>
       #include <stdlib.h>


       //将原来的cuda_utils.h 改为sdaa_utils.h
       #include "sdaa_utils.h"


       // input: new_xyz(b, m, 3) xyz(b, n, 3)
       // output: idx(b, m, nsample)
       __global__ void query_ball_point_kernel(dim3 sdaaGridDim, dim3 sdaaBlockDim,
                                                           int b, int n, int m, float radius,
                                                           int nsample,
                                                           const float *__restrict__ new_xyz,
                                                           const float *__restrict__ xyz,
                                                           int *__restrict__ idx) {




文档版本：v3.2.0                                       版权所有 © 太初(无锡)电子科技有限公司                                     126

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                               自定义 SDAAC 算子接入




        int linearblockDim = sdaaGridDim.z * sdaaGridDim.y * sdaaGridDim.x;
        // threadIdx


        for (int linearblockIdx = threadIdx; linearblockIdx < linearblockDim;
               linearblockIdx += 32) {
          // z = i / (DimX * DimY);
          // int remainder = i % (DimX * DimY);
          // y = remainder / DimX;
          // x = remainder % DimX;


          int blockIdx_z =
                linearblockIdx / (sdaaGridDim.x * sdaaGridDim.y); // 计算z坐标
          int remainder = linearblockIdx %
                                      (sdaaGridDim.x * sdaaGridDim.y); // 剩余部分用于计算y和x
          int blockIdx_y = remainder / sdaaGridDim.x;                  // 计算y坐标
          int blockIdx_x = remainder % sdaaGridDim.x;                  // 计算x坐标


          //    for (int blockIdx_z = 0; blockIdx_z < sdaaGridDim.z; blockIdx_z ++) {
          //         for (int blockIdx_y = 0; blockIdx_y < sdaaGridDim.y; blockIdx_y ++) {
          //             for (int blockIdx_x = 0; blockIdx_x < sdaaGridDim.x; blockIdx_x ++)
          //             {


          for (int threadIdx_z = 0; threadIdx_z < sdaaBlockDim.z; threadIdx_z++) {
              for (int threadIdx_y = 0; threadIdx_y < sdaaBlockDim.y; threadIdx_y++) {
                for (int threadIdx_x = 0; threadIdx_x < sdaaBlockDim.x; threadIdx_x++) {


                 int batch_index = blockIdx_x;
                 xyz += batch_index * n * 3;
                 new_xyz += batch_index * m * 3;
                 idx += m * nsample * batch_index;


                 int index = threadIdx_x;
                 int stride = sdaaBlockDim.x;


                 float radius2 = radius * radius;
                 for (int j = index; j < m; j += stride) {
                     // m * 3
                     float new_x = new_xyz[j * 3 + 0];
                     float new_y = new_xyz[j * 3 + 1];
                     float new_z = new_xyz[j * 3 + 2];
                     for (int k = 0, cnt = 0; k < n && cnt < nsample; ++k) {
                          // n * 3
                          float x = xyz[k * 3 + 0];
                          float y = xyz[k * 3 + 1];
                          float z = xyz[k * 3 + 2];
                          float d2 = (new_x - x) * (new_x - x) + (new_y - y) * (new_y - y) +
                                          (new_z - z) * (new_z - z);
                          if (d2 < radius2) {
                              if (cnt == 0) {
                                  for (int l = 0; l < nsample; ++l) {
                                      // m * nsample
                                      idx[j * nsample + l] = k;
                                  }
                              }
                              idx[j * nsample + cnt] = k;
                              ++cnt;
                          }
                     }
                 }




文档版本：v3.2.0                                      版权所有 © 太初(无锡)电子科技有限公司                                     127

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         自定义 SDAAC 算子接入




                         }
                     }
                 }
             }
         }


         void query_ball_point_kernel_wrapper(int b, int n, int m, float radius,
                                                 int nsample, const float *new_xyz,
                                                 const float *xyz, int *idx) {
             // cudaStream_t stream = at::cuda::getCurrentCUDAStream();
             //      Launch kernel
             dim3 blocks(b);
             dim3 threads(256); // Number of threads per block
             query_ball_point_kernel<<<1>>>(blocks, threads, b, n, m, radius, nsample,
                                            new_xyz, xyz, idx);


             SDAA_CHECK_ERRORS();
         }




 步骤二：改写C++源文件中的CUDA函数为SDAA C函数

使用SDAA C编程语言（详情请参考《SDAA C编程指南》的快速入门章节），将C++源文件中用到的CUDA头文件、
宏定义、数据结构和Runtime接口等，改写成对应的SDAA C实现。

本示例中，由于CUDA自定义算子的Kernel实现过程中引用了 cuda_utils.h 头文件，需要对该文件中的函数进
行修改，使其符合SDAA C的编程格式和要求。 cuda_utils.h 文件的内容如下：

   // Copyright (c) Facebook, Inc. and its affiliates.
   //
   // This source code is licensed under the MIT license found in the
   // LICENSE file in the root directory of this source tree.


   #ifndef _CUDA_UTILS_H
   #define _CUDA_UTILS_H


   #include <ATen/ATen.h>
   #include <ATen/cuda/CUDAContext.h>
   #include <cmath>


   #include <cuda.h>
   #include <cuda_runtime.h>


   #include <vector>


   #define TOTAL_THREADS 512


   inline int opt_n_threads(int work_size) {
       const int pow_2 = std::log(static_cast<double>(work_size)) / std::log(2.0);


       return max(min(1 << pow_2, TOTAL_THREADS), 1);
   }


   inline dim3 opt_block_config(int x, int y) {
       const int x_threads = opt_n_threads(x);
       const int y_threads =
             max(min(opt_n_threads(y), TOTAL_THREADS / x_threads), 1);




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                      128

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      自定义 SDAAC 算子接入




       dim3 block_config(x_threads, y_threads, 1);


       return block_config;
   }


   #define CUDA_CHECK_ERRORS()                                                  \
       do {                                                                     \
           cudaError_t err = cudaGetLastError();                                \
           if (cudaSuccess != err) {                                            \
               fprintf(stderr, "CUDA kernel failed : %s\n%s at L:%d in %s\n",   \
                       cudaGetErrorString(err), __PRETTY_FUNCTION__, __LINE__, \
                       __FILE__);                                               \
               exit(-1);                                                        \
           }                                                                    \
       } while (0)


   #endif



基于SDAA C编程语言，实现的 sdaa_utils.h 文件内容如下：

   // Copyright (c) Facebook, Inc. and its affiliates.
   //
   // This source code is licensed under the MIT license found in the
   // LICENSE file in the root directory of this source tree.


   #ifndef _SDAA_UTILS_H
   #define _SDAA_UTILS_H


   #include <ATen/ATen.h>
   //#include <ATen/cuda/CUDAContext.h>
   #include <cmath>


   //#include <cuda.h>
   #include <sdaa_runtime.h>


   #include <vector>


   #if defined(__SDAA__) && defined(__clang__)


   struct uint3 {
       unsigned int x, y, z;
   };


   typedef struct uint3 uint3;


   struct dim3 {
       unsigned int x, y, z;
   #if defined(__cplusplus)
   #if __cplusplus >= 201103L
       __host__ __device__ constexpr dim3(unsigned int vx = 1, unsigned int vy = 1,
                                              unsigned int vz = 1)
               : x(vx), y(vy), z(vz) {}
       __host__ __device__ constexpr dim3(uint3 v) : x(v.x), y(v.y), z(v.z) {}
       __host__ __device__ constexpr operator uint3(void) const {
           return uint3{x, y, z};
       }
   #else




文档版本：v3.2.0                                 版权所有 © 太初(无锡)电子科技有限公司                                 129

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                      自定义 SDAAC 算子接入




     __host__ __device__ dim3(unsigned int vx = 1, unsigned int vy = 1,
                                  unsigned int vz = 1)
             : x(vx), y(vy), z(vz) {}
     __host__ __device__ dim3(uint3 v) : x(v.x), y(v.y), z(v.z) {}
     __host__ __device__ operator uint3(void) const {
         uint3 t;
         t.x = x;
         t.y = y;
         t.z = z;
         return t;
     }
   #endif // __cplusplus >= 201103L
   #endif // __cplusplus
   };
   #endif


   #define SDAA_CHECK_ERRORS()                                                \
     do {                                                                     \
         sdaaError_t err = sdaaGetLastError();                                \
         if (sdaaSuccess != err) {                                            \
             fprintf(stderr, "SDAA kernel failed : %s\n%s at L:%d in %s\n",   \
                     sdaaGetErrorString(err), __PRETTY_FUNCTION__, __LINE__, \
                     __FILE__);                                               \
             exit(-1);                                                        \
         }                                                                    \
     } while (0)


   #endif




 步骤三：编写SDAA C自定义算子的编译脚本

  1. 参考CUDA自定义算子的                 setup.py 编译脚本，编写SDAA C自定义算子对应的                  setup.py 编译脚本，示例
   如下：

              说明：

                  编译算子时，需要通过 torch_sdaa.utils.cpp_extension 导入 TecoExtension 、
                    BuildExtension 和 CleanExtension 模块，将setuptools原生的构建函数替换成SDAA
                  Extension提供的函数。

                     TecoExtension 、       BuildExtension 和        CleanExtension 模块，用于对SDAA C算子
                  进行编译。



         # Copyright (c) Facebook, Inc. and its affiliates.
         # # This source code is licensed under the MIT license found in the
         # LICENSE file in the root directory of this source tree.


         from setuptools import setup
         # 注释掉原生的CUDAExtension编译
         # from torch.utils.cpp_extension import BuildExtension, CUDAExtension
         import torch
         # 导入torch_sdaa模块
         import torch_sdaa




文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                   130

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 自定义 SDAAC 算子接入




        # 使用SDAA extension编译模块扩展模块
        from torch_sdaa.utils.cpp_extension import TecoExtension, BuildExtension, CleanExtension
        import glob


        _ext_src_root = "_ext_src"
        _ext_sources = glob.glob("{}/src/*.cpp".format(_ext_src_root)) + glob.glob(
            "{}/src/*.scpp".format(_ext_src_root)
        )
        _ext_headers = glob.glob("{}/include/*".format(_ext_src_root))


        setup(
            name='pointnet2',
            ext_modules=[
                 TecoExtension(
                      name='pointnet2._ext',
                      sources=_ext_sources,
                      extra_compile_args={
                           #"cxx": ["-O2", "-I{}".format("{}/include".format(_ext_src_root))],
                           #"nvcc": ["-O2", "-I{}".format("{}/include".format(_ext_src_root))],
                      },
                 )
            ],
            cmdclass={
                 'build_ext': BuildExtension
            }



 2. 在   lib/pointnet2_sdaa 目录下，执行以下命令，编译SDAA C自定义算子：


        python setup.py build_ext


   编译完成后，会生成类似于 ext.cpython-310-x86_64-linux-gnu.so 的 .so 文件。

 后续操作

按照3D-VLP模型仓库的使用说明，在太初AI加速卡上运行模型。具体请参考模型使用说明。




7.2 基于PyTorch的load_inline编写自定义算子
本文介绍如何使用 PyTorch 的 load_inline 功能编写自定义算子。

 load_inline功能简介

load_inline 是 PyTorch 提供的一个即时编译（JIT，即 Just-In-Time）与加载工具。它允许你将 C++ 或SDAA 的
源代码作为字符串直接写在 Python 文件里，在程序运行时自动编译并加载为一个 Python 可调用的自定义算子模
块。

load_inline功能大大简化了自定义算子的编写，无需维护单独的源文件或编写复杂的                                           setup.py 构建脚本，非常
适合进行快速原型验证。

 使用示例


文档版本：v3.2.0                               版权所有 © 太初(无锡)电子科技有限公司                                              131

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                            自定义 SDAAC 算子接入




下面是一个使用load_inline功能实现的自定义加法算子的示例：

   #
   # load_inline示例
   #
   import torch
   import torch_sdaa
   from torch_sdaa.utils.cpp_extension import load_inline


   def test_load_inline():
       # 定义sdaa kernel和cpp函数my_add，用于加法计算
       sdaa_src = """
       __global__ void vec_add(float* x, float* y, float* z, int total_num) {
             // 将所有数据切分为threadDim块，每块含有tile_num个数据，分给不同的SPE去计算
             uint32_t tile_num = total_num / threadDim;
             // 计算出tile_num个数据占用多少字节的数据空间
             uint32_t spm_size = tile_num * sizeof(float);
             // malloc som
             float *spm_x = (float *)malloc(spm_size);
             float *spm_y = (float *)malloc(spm_size);
             float *spm_z = (float *)malloc(spm_size);
             // load
             memcpy(spm_x, (x + threadIdx * tile_num), spm_size);
             memcpy(spm_y, (y + threadIdx * tile_num), spm_size);


             // 每个计算核心SPE相隔tile_num个float数据，且循环tile_num次，进行加法计算
             for (uint32_t i = 0; i < tile_num; i++) {
                 // compute
                 spm_z[i] = spm_x[i] + spm_y[i];
             }
             // store
             memcpy((z + threadIdx * tile_num), spm_z, spm_size);
       }


       void my_add(torch::Tensor& a, torch::Tensor& b, torch::Tensor& c) {
             vec_add<<<0>>>(a.data_ptr<float>(),b.data_ptr<float>(),c.data_ptr<float>(),a.numel());
       }
       """


       # 定义cpp函数作为接口
       cpp_src = "void my_add(torch::Tensor& a, torch::Tensor& b, torch::Tensor& c);"


       # 使用load_inline功能加载sdaa模块
       sdaa_module = load_inline(
             name="vec_add_sdaa",
             cpp_sources=cpp_src,
             sdaa_sources=sdaa_src,
             functions=["my_add"],
             verbose=False,
       )


       #在cpu上运行加法计算，作为参考
       a0 = torch.rand([1024])
       b0 = torch.rand([1024])
       out_cpu = a0 + b0


       a = a0.sdaa()
       b = b0.sdaa()




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                           132

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     自定义 SDAAC 算子接入




       out_sdaa = torch.empty_like(a)


       # 在sdaa上运行加法计算
       vec_add_sdaa = sdaa_module.my_add
       vec_add_sdaa(a, b, out_sdaa)
       assert torch.allclose(out_cpu, out_sdaa.cpu()), "out_sdaa.cpu() != out_cpu"


   if __name__ == "__main__":
       test_load_inline()
       print("test_load_inline pass")



执行后输出：

   test_load_inline pass




7.3 自定义SDAA C算子性能分析
自定义SDAA C算子与PyTorch标准算子一样，可以直接使用Torch Profiler工具分析性能，使用方法详见性能调优章
节。




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司                                    133

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                 模型训练
