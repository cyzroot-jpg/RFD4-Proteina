# 开发指南

## 概述

本文主要阐明用户在Teco-AL仓库开发算子时，可以参考的信息。推荐用户优先依次熟悉以下基础手册的内容，再进行算子开发实操，让学习过程变得循序渐进。

- [SDAA C编程指南](http://docs.tecorigin.com/release/sdaac/)：介绍SDAA C编程语言、语言规范、函数接口、数学函数、程序编译、程序调试及性能调优等内容。
- [性能优化手册-SDAAC篇](http://docs.tecorigin.com/release/sddac_perf_opt/)：介绍程序并行、函数接口、数学函数、程序编译过程中的性能优化内容。
- [性能优化手册-算子篇](http://docs.tecorigin.com/release/op_perf_opt/)：介绍经典的计算与访存优化办法。前者含向量指令、指令流水线、矩阵乘法加速单元；后者含双缓冲、广播优化办法。


Teco-AL算子开发，需要兼顾由易到难的3个方面：代码风格、代码结构、代码逻辑。

## 代码风格

Teco-AL仓库为C++代码仓库，采用C++11标准，统一使用[《Google C++ 风格》](https://zh-google-styleguide.readthedocs.io/en/latest/google-cpp-styleguide/contents.html)进行编码，用户可以点击链接，查阅google规范详情。

Teco-AL仓库提供了以下工具，保障仓库内的代码风格统一。
|名称|说明|类别|
|---|---|---|
|cpplint|[pre_commit](../../tools/pre-commit)脚本在用户每次`git commit`前，会自动进行cpplint检查。|自动触发执行|
|format2google|[format2google](../../tools/format2google)脚本提供了自动规整代码的功能。例如在`teco-al`目录下，执行`./tools/format2google ./ual/kernel/add_tensor/add_tensor_ft16.scpp`命令，表示对`./ual/kernel/add_tensor/add_tensor_ft16.scpp`文件进行自动格式化操作。|用户手动执行|


## 代码结构

基于Teco-AL的整体目录结构（详见[README](../../README.md#目录结构)），用户熟悉或开发各个算子代码均需要着重关注以下部分（本节统一使用tecoalAddTensor代码做示例介绍）。

注意：各处的`{opname}`变量表示算子在目录名或文件名中的名称，是Teco-AL仓库脚本自动化构建的索引，所有地方必须完全严格一致。

### interface层（用户接口）
#### userAPI层（对外头文件）

- 路径地址：`interface/include/tecoal.h`（所有算子统一使用此路径）
- 代码介绍：将设计文档中的userAPI添加到对外头文件中，便于Teco-AL的用户调用。若有自定义的枚举或结构体，也需添加至头文件中。
- 实现示例：例如[interface/include/tecoal.h](../../interface/include/tecoal.h)中的`tecoalAddTensor`属于userAPI；该接口中使用的`tecoalAlgo_t`属于自定义枚举；该接口中使用的`tecoalTensorDescriptor_t`属于自定义结构体。

#### ops层（算子定义与实现）

- 路径地址：`interface/ops/{opname}.cpp`
- 代码介绍：ops层接口实现代码，含：参数赋值、功能函数调用等功能。功能函数调用，通过`RUN_OP`实现，传入参数均由`args`封装，具有更好的扩展性。
- 实现示例：详见[interface/ops/add_tensor.cpp](../../interface/ops/add_tensor.cpp)中的代码及其注释。

### ual层（核心计算逻辑）

#### 参数定义

- 路径地址：`ual/args/{opname}_args.h`
- 代码介绍：包含两种场景下，算子所需参数的封装：计算参数、分支派发参数。
- 实现示例：详见[ual/args/add_tensor_args.h](../../ual/args/add_tensor_args.h)中的代码及其注释。

#### 分支派发

- 路径地址：
    - `ual/ops/{opname}/{opname}.hpp`
    - `ual/ops/{opname}/find_{opname}.cpp`
    - `ual/ops/{opname}/find_{opname}.h`
- 代码介绍：
    - `.hpp`文件基于BaseOp模板构建，包含分支派发整体框架、由各个分支组成的数组。
    - `.cpp`文件包含具体分支进入的判断逻辑。
    - `.h`文件为对应头文件。
- 实现示例：详见[ual/ops/add_tensor/](../../ual/ops/add_tensor)目录下的代码及其注释。

#### 计算实现

- 路径地址：
    - `ual/kernel/{opname}/{opname}.scpp`
    - `ual/kernel/{opname}/{opname}.h`
- 代码介绍：
    - `.scpp`文件包含设备端核心计算逻辑实现，对应设计文档中的功能代码。
    - `.h`文件为对应头文件。
- 实现示例：详见[ual/kernel/add_tensor/](../../ual/kernel/add_tensor/)目录下的代码及其注释。


## 代码逻辑

算子开发任务通常可以分为以下3类：
- 功能实现：是指一个算子的支持情况从无到有的过程。
- 功能增强：是指在已有算子的基础上，进行功能特性的扩展，例如新增数据类型支持、解除原有的参数shape限制。
- 性能优化：是指对已有功能特性的性能提升，仅改变计算性能，不改变功能支持情况。

不同类别的开发任务，对应着不同的逻辑代码开发范围，核心修改逻辑概要如下：
|是否需要开发|功能实现|功能增强|性能优化|
|---|---|---|---|
| interface-userAPI层| 是 |否 |否 |
|interface-ops层 |是 | 否| 否|
|ual层-参数定义 |是 |否 |否 |
|ual层-分支派发 |是 |是 | 是|
|ual层-计算实现 | 是| 是|是 |


## 附录：核心概念

### 常见术语
|常见术语|说明|
|---|---|
|ops|Operations，算子，用于描述在深度学习等领域中的操作或运算。|
|ual|Unified Accelerated Libraries，统一加速库，集成各种加速计算的底层库，用于优化计算性能。|
|algo|Algorithm，算法，针对功能特性和性能优化，设计的实现思路。|
|args|Arguments，参数，函数或程序中用于传递给函数或命令的值。|

### 句柄

句柄（Handle）是用于管理和配置Teco-AL操作的对象，关联了算子所使用的计算阵列SPA资源。调用Teco-AL时，需要经过以下步骤：

1. 创建句柄：使用tecoalCreate()函数创建一个句柄。

1. 绑定Stream：使用tecoalSetStream()函数绑定Stream。

1. 执行操作：使用句柄和其他参数，调用相应的Teco-AL函数来执行具体的深度学习操作，如卷积、矩阵乘法等。

1. 销毁句柄：计算完毕，使用tecoalDestroy()函数销毁句柄，释放相关的内存和资源。

### 张量

张量（Tensor）在Teco-AL中扮演着重要的角色，因为神经网络的计算过程涉及大量的矩阵和向量运算。张量是存储和表示神经网络输入、输出和参数的数据结构，可以有效地表示数据并在不同层之间传递和共享信息。

张量的维度可以是任意的，从一维到多维（不超过8维），用于表示不同形状的数据。

|名称|说明|
|---|---|
|一维张量（向量）|一维张量表示为单行或单列的数据集合，即具有单个轴的数组。|
|二维张量（矩阵）|二维张量表示为行和列的排列，即具有两个轴的数组，其中第一个轴表示行，第二个轴表示列。|
|三维张量|三维张量可以看作是二维矩阵的集合，每个矩阵都具有相同的行和列。例如，一个形状为(2, 3, 4)的三维张量表示为两个二维矩阵，每个矩阵具有3行和4列。|
|更高维张量|除了一维、二维和三维张量之外，Teco-AL还可以使用更高维度的张量来表示更复杂的数据，最大不超过8维。例如，四维张量可以用于表示图像数据，各个维度的信息包含批次大小、通道数、图像高度和图像宽度。|

![concept_tensor](./pics/concept_tensor.png)

### 存储格式

以四维张量`(N, W, H, C)`为例，四个维度结合图像方面的物理含义如下：

- N(Batch)：一个批次内图片的数量，即一次处理的图片数量。

- H(Height)：垂直高度方向的像素个数，即图片的高。

- W(Width)：水平宽度方向的像素个数，即图片的宽。

- C(Channels)：特征图通道数，例如灰度图像为通道数1，彩色RGB图像为3。

四维张量在内存中的不同的存储顺序，可以分为几种常见的存储格式：NHWC、NCHW、CHWN、NWHC。对于大规模数据处理和高性能计算的情况，合理选择数据布局可以提高内存访问效率和计算性能


![concept_layout](./pics/concept_layout.png)


### 描述符

Teco-AL库中的描述符主要用于保存算子的输入、输出、权重、算子参数等信息，主要有三类。

|名称|说明|
|---|---|
|Tensor描述符|用于描述算子的输入和输出张量，包括维度、数据类型、形状等信息。|
|Filter描述符|用于描述算子的权重张量，包括维度、数据类型、形状等信息。|
|算子描述符|用于规定算子的各种参数和选项，例如卷积操作的步幅(stride)、填充(pad)、卷积模式等。|

### 工作空间

工作空间（workspace）是一个内存缓冲区，用于存储深度学习操作执行过程中的中间计算结果和临时数据，这样可以优化内存的使用，提高训练和推理任务的性能。

Teco-AL库中的部分算子提供了workspace参数，用于指定存储计算中间数据的内存，工作空间内存只需在设备端进行分配，其大小通常需要通过算子提供的GetWorkspace()接口来获取。






