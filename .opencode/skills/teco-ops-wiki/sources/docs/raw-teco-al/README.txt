# Teco-AL

## 仓库简介

Teco-AL（Teco-Accelerated Libraries，太初加速库）提供了统一的算子库模型，用户可以使用SDAA C编程语言，基于Teco-AL的代码架构，实现灵活多样的算子接口。

推荐用户优先依次熟悉以下基础手册的内容，再进行Teco-AL算子开发实操，让学习过程变得循序渐进。

- [SDAA C编程指南](http://docs.tecorigin.com/release/sdaac/)：介绍SDAA C编程语言、语言规范、函数接口、数学函数、程序编译、程序调试及性能调优等内容。
- [性能优化手册-SDAAC篇](http://docs.tecorigin.com/release/sddac_perf_opt/)：介绍程序并行、函数接口、数学函数、程序编译过程中的性能优化内容。
- [性能优化手册-算子篇](http://docs.tecorigin.com/release/op_perf_opt/)：介绍经典的计算与访存优化办法。前者含向量指令、指令流水线、矩阵乘法加速单元；后者含双缓冲、广播优化办法。

Teco-AL仓库中的常用概念解释，例如：ops、ual、algo、args等缩略语；句柄、张量、存储格式、描述符、工作空间等通用概念，可以按需查阅[《开发指南——附录：核心概念》](./doc/tutorial/dev_guide.md#附录核心概念)了解详情。

## 算子支持现状
Teco-AL仓库中每个实现的算子，均有一对一配套的算子设计文档，用户可以查阅[./doc/op_docs/](./doc/op_docs/)目录，了解Teco-AL仓库目前已实现的算子，以及各个算子的功能特性与性能优化方案。各个算子文档包含3大内容模块：
- 计算原理：明确当前开发的算子具体执行的什么计算。
- 功能实现：根据计算场景，设计userAPI，明确功能特性与参数限制等计算边界。
- 性能优化：针对算子的计算特征，设计相应的性能优化办法，通过流程图、伪代码等方式说明。

```
# 讲解示例
add_tensor.md
gemm.md
conv_forward.md

# 设计文档模板
doc_template.md

# 赛题算子参考
activation_backward.md
activation_forward.md
arg_max.md
index_put.md
logical_not_tensor.md
masked_fill.md
masked_select.md
scale_tensor.md
scatter_nd_add.md
scatter_out.md
unary_ops.md
unique.md
```

## 目录结构

custom_ops 目录不同其他目录，它为通用算子开发提供简单的开发环境和流程，适合非赛题的初学者使用。

Teco-AL仓库通过将不同的组件和功能模块化，让项目的可维护性和可扩展性得到了增强。例如，
- 用户可以基于`ual/kernel/`目录下的底层计算函数，在`interface/ops/`层进行灵活组装。
- 用户可以基于`ual/args/`层提供的参数封装信息，进行参数获取或扩展。
- 用户可以基于`ual/ops/`层开发分支派发，针对不同的参数输入，快速匹配最适合的实现路径，为用户提供最佳性能。

### 全局概览
Teco-AL仓库整体目录介绍概览如下：

```bash
.
├── README.md                 # 项目的README文件，包含项目介绍、使用方法等
├── build.sh                  # 构建脚本，用于编译项目
├── CMakeLists.txt            # CMake配置文件，指定如何编译项目和链接依赖
├── CPPLINT.cfg               # C++代码风格检查的配置文件
├── env.sh                    # 环境设置脚本，设置编译和运行项目所需的环境变量
├── custom_ops                # custom算子开发，详见其目录下的README说明
├── doc                       # 仓库介绍文档、各个算子的设计文档
├── interface                 # 接口定义目录
│   ├── common                # 存放一些通用的接口定义或工具
│   ├── include               # 公共头文件目录
│   └── ops                   # 存放各算子的接口定义及其调用，并包含OP类接口（由ual层中的封装组合而成）
│       ├── add_tensor.cpp
│       └── other_ops.cpp
├── samples                   # 各个算子与CPU校验的测试代码
├── test/frame_work/tecotest  # 各个算子与CPU和GPU综合校验的测试代码
│   ├── zoo/tecoal/scale_tensor
│   │   ├── test_case         # 算子测试用例
│   │   ├── scale_tensor.cpp  # 测试代码文件
│   │   ├── scale_tensor.h    # 测试头文件
│   │   └── scale_tensor.py   # CPU/GPU代码文件
│   └── other_ops
├── tools                     # 存放项目相关的工具脚本或程序
└── ual                       # 核心计算层，将各算子封装为单独的OP对象，在OP中集成分支派发、__global__属性的接口
    ├── args                  # 存放各算子需要的参数结构定义
    │   ├── add_tensor_args.h
    │   └── other_ops.h
    ├── com                   # 通用组件或工具
    ├── ops                   # 算子分支派发目录
    │   ├── add_tensor
    │   │   ├── add_tensor.hpp
    │   │   ├── find_add_tensor.cpp
    │   │   └── find_add_tensor.h
    │   └── other_ops
    └── kernel                # 设备端核心计算逻辑的实现代码
        ├── add_tensor
        │   ├── add_tensor_ft16.scpp
        │   └── add_tensor.h
        └── other_ops

```

### 模块介绍

用户熟悉或开发各个算子代码，均需着重关注以下部分（本节统一使用tecoalAddTensor代码做示例介绍）。

注意：各处的`{opname}`变量表示算子在目录名或文件名中的名称，是Teco-AL仓库脚本自动化构建的索引，所有地方必须完全严格一致。

#### interface层（用户接口）
##### userAPI层（对外头文件）

- 路径地址：`interface/include/tecoal.h`（所有算子统一使用此路径）
- 代码介绍：将设计文档中的userAPI添加到对外头文件中，便于Teco-AL的用户调用。若有自定义的枚举或结构体，也需添加至头文件中。
- 实现示例：例如[interface/include/tecoal.h](./interface/include/tecoal.h)中的`tecoalAddTensor`属于userAPI；该接口中使用的`tecoalAlgo_t`属于自定义枚举；该接口中使用的`tecoalTensorDescriptor_t`属于自定义结构体。

##### ops层（算子定义与实现）

- 路径地址：`interface/ops/{opname}.cpp`
- 代码介绍：ops层接口实现代码，含：参数赋值、功能函数调用等功能。功能函数调用，通过`RUN_OP`实现，传入参数均由`args`封装，具有更好的扩展性。
- 实现示例：详见[interface/ops/add_tensor.cpp](./interface/ops/add_tensor.cpp)中的代码及其注释。

#### ual层（核心计算逻辑）

##### 参数定义

- 路径地址：`ual/args/{opname}_args.h`
- 代码介绍：包含两种场景下，算子所需参数的封装：计算参数、分支派发参数。
- 实现示例：详见[ual/args/add_tensor_args.h](./ual/args/add_tensor_args.h)中的代码及其注释。

##### 分支派发

- 路径地址：
    - `ual/ops/{opname}/{opname}.hpp`
    - `ual/ops/{opname}/find_{opname}.cpp`
    - `ual/ops/{opname}/find_{opname}.h`
- 代码介绍：
    - `.hpp`文件基于BaseOp模板构建，包含分支派发整体框架、由各个分支组成的数组。
    - `.cpp`文件包含具体分支进入的判断逻辑。
    - `.h`文件为对应头文件。
- 实现示例：详见[ual/ops/add_tensor/](./ual/ops/add_tensor)目录下的代码及其注释。

##### 计算实现

- 路径地址：
    - `ual/kernel/{opname}/{opname}.scpp`
    - `ual/kernel/{opname}/{opname}.h`
- 代码介绍：
    - `.scpp`文件包含设备端核心计算逻辑实现，对应设计文档中的功能代码。
    - `.h`文件为对应头文件。
- 实现示例：详见[ual/kernel/add_tensor/](./ual/kernel/add_tensor/)目录下的代码及其注释。

## 贡献指南

### 步骤一：fork仓库

将[Teco-AL官方仓库](https://gitee.com/tecorigin/teco-al)fork到贡献者的个人空间，点击仓库页面右上方的fork按钮即可，详情可以查阅gitee官方使用文档：[《Fork+PullRequest 模式》](https://help.gitee.com/base/%E5%BC%80%E5%8F%91%E5%8D%8F%E4%BD%9C/Fork+PullRequest%E6%A8%A1%E5%BC%8F)。

### 步骤二：功能开发

不同贡献者对已有算子，进行功能增强或性能优化等开发，均通过计算分支管理。计算分支与kernel实现函数一一对应，选择不同的计算分支，就代表使用不同的实现方式完成了同样结果的算子运算。

因此，贡献者在功能开发时，核心关注代码架构中的两部分：
- [“分支派发”](./README.md#分支派发)：定义了不同计算分支的进入判断条件。
- [“计算实现”](./README.md#计算实现)：对应不同计算实现的底层逻辑代码。

为了兼容不同用户对同个特性的多样化开发，Teco-AL仓库预设了`algo`参数，用于显式的指定计算分支，便于调试。例如，贡献者实现了新的kernel函数，那么贡献者可以在分支派发逻辑中，补充自己新增kernel函数的进入条件，如`if algo == my algo_id: execute my kernel function`。

此外，贡献者需要注意：
- SPM内存申请时，不能超过235KB，推荐使用仓库封装的[rt_spm_malloc()与rt_spm_free()等接口](./ual/com/rt.h)（接口封装占用128B，上限为235KB-128B=240512B），可以在超量申请时，报错提醒。
- 新增文件需要参考仓库已有文件，统一在文件头添加BSD License。
- 编码整体使用[《Google C++ 风格》](https://zh-google-styleguide.readthedocs.io/en/latest/google-cpp-styleguide/contents.html)，贡献者可以使用[format2google](./tools/format2google)脚本将代码规范化。再根据pre-commit自动触发的cpplint检查结果，按需规范化代码。
- 将自己新增的特性，更新到对应算子的设计文档中（[./doc/op_docs/](./doc/op_docs/)目录下），保证代码与文档信息无偏差，便于其他开发者查阅。

更多指引说明，可查阅[《开发指南》](./doc/tutorial/dev_guide.md)。

### 步骤三：功能自测

贡献者完成代码开发与文档更新以后，可以使用tecotest测试框架，选取`algo == my algo_id`的测例，对自己开发的算子进行性能与精度测试。

#### 环境依赖

Teco-AL的运行依赖以下组件，可以查阅[《环境安装手册》](http://docs.tecorigin.com/release/software_installation/)进行对应工具安装。

- TecoDriver
- TecoToolKit

此外，tecotest运行依赖环境，可以通过requirements.txt获取配置（若已有tecoal_gpu此conda环境，可以直接复用，无需额外更新），具体步骤如下：
```
cd test/frame_work/tecotest/tools
pip3 install -r requirements.txt
```

推荐使用conda环境，完成一次环境搭建后，可以多次复用。若服务器完成了conda安装，命令示例如下；若服务器没有conda，需要先安装conda。

```
# 初次搭建环境
conda create -n {your_conda_name} python==3.9
conda activate {your_conda_name}
cd test/frame_work/tecotest/tools
pip3 install -r requirements.txt
# coding ...

# 多次复用环境
conda activate {your_conda_name}
# coding ...

# 查询已有的conda环境
conda env list
# 以tecoal_gpu为例，若有此conda环境，可以直接复用，无需更新组件
conda activate tecoal_gpu
# coding ...
```


#### 测试步骤

算子测试，需要分别完成Teco-AL与tecotest编译，再使用unit_test_v2脚本运行测例，获取精度和性能结果。以scale_tensor为例，具体步骤如下（其余算子请对应替换算子名等内容，算子名以目录名为准，如scale_tensor，而不是API名，如tecoalScaleTensor。算子目录名需要保持各处完全一致）：

```
# teco-al编译
source env.sh
bash build.sh -f "scale_tensor"
# 注意：反向算子编译，依赖前向算子，例如：bash build.sh -f "activation_forward;activation_backward"

# tecotest编译
cd test/frame_work/tecotest
source env.sh
bash build.sh -f "scale_tensor"
# 注意：反向算子编译，依赖前向算子，例如：bash build.sh -f "activation_forward;activation_backward"

# 指定被测试的对象，请更换为您的teco-al仓库实际所在的目录
export LD_LIBRARY_PATH={!!!your_path!!!}/teco-al/build/lib/:$LD_LIBRARY_PATH

# 运行测例，例如使用0号SPA运行cases_dir目录下的所有基线代码测例，预热5次，性能取10次结果均值
# 实际开发调试时，请使用自己algo所属的测例，用于测试自己开发的计算分支
cd build
python ../tools/unit_test_v2.py --cases_dir=/eco/teco-al/scale_tensor/float/algo0 --warm_repeat=5  --perf_repeat=10  --gid=0
```

其中，unit_test_v2脚本支持以下配置：

- 必选
    - 指定测例，方式三选一即可：
        - `--cases_dir = {dir}`：指定测试用例所在的路径，会执行该路径下所有的测试用例。
        - `--case_path = {path of one prototxt file}`：指定单个测试用例。case_path路径中一定要包含与算子同名的目录，即一定需要包含`/{op_name}/`。
        - `--cases_list = {path of one txt file}`：指定一个.txt文件，其中包含多个case_path，逐一运行其中的测例。
    - 指定运行测例的SPA：`--gid = {num/nums}`，支持格式`--gid=2`，`--gid=0-2`，`--gid=1,2,3`。
- 可选
    - `--rand_n = {num}`：随机挑选指定数量的用例执行。
    - `--test_name = {op_name}`：通过算子名，选择被测试的单个算子。若不指定，默认运行指定测例中的所有算子。
    - `--warm_repeat = {num}`：测试性能时的预热功能，设置接口预先运行的次数（该部分运行时间不统计），用于消除启动、初始化等开销，默认取值为3次。
    - `--perf_repeat = {num}`：测试性能时的均值功能，设置接口实际运行的次数（该部分运行时间累加统计后取均值），默认取值为100次。
    - `--output = {filename}`：用于指定生成excel结果的文件命名。

#### 结果说明

unit_test_v2脚本运行后，在`teco-al/test/frame_work/tecotest/build`目录下，会生成测试结果excel（需注意：build目录会在每次编译后清空，若需保存测试结果，可以在每次编译前备份）。 测试结果各项信息如下，以赛题开发为例，需要尤其关注加粗信息：
- `summary sheet`：包含总测例数量、总算子数量、总执行时间、测例是否通过的数量情况、测试环境各项版本信息等。
- `failed_casepath sheet`：测试失败的测例地址合集。如果没有测试失败的测例，则没有这个sheet。
- `kernel_details sheet`：统计被测试的kernel函数及其调用次数。
- `op_details sheet`：统计被测试的算子及其调用次数和总硬件时间。
- **accu sheet**：精度测试结果，详情如下：
    - A-I列为测例信息，如参数shape、dtype、layout、分支信息等。
    - `DIFF3_MAX_GPU`：4个值分别对应CPU计算出的值、GPU计算出的值、误差最大点的Index、GPU与CPU的最大误差。
    - `DIFF3_MAX_TECO`：4个值分别对应CPU计算出的值、TECO计算出的值、误差最大点的Index、TECO与CPU的最大误差。
    - `DIFF3_MAX_THRESHOLD`：2个值分别对应TECO和GPU最大误差的最大通过倍数、TECO和GPU最大误差的实际倍数。
    - `DIFF3_MEAN_GPU`：4个值分别对应CPU计算出的值、GPU计算出的值、由于是平均误差index没有意义（所以取-1）、GPU与CPU的平均误差。
    - `DIFF3_MEAN_TECO`：4个值分别对应CPU计算出的值、TECO计算出的值、由于是平均误差index没有意义（所以取-1）、TECO与CPU的平均误差。
    - `DIFF3_MEAN_THRESHOLD`：2个值分别对应TECO和GPU平均误差的最大通过倍数、TECO和GPU平均误差的实际倍数。
    - **result: 正确性结果，PASS_S1或PASS_S2为通过，其余情况为不通过。**
    - `result_hash`: TECO计算结果的二进制哈希值。
    - `host_result`: 主机端是否有内存泄露，success表示没有内存泄露。
- **perf sheet**：性能测试结果，详情如下：
    - A-G列为测例信息，如参数shape、dtype、layout、分支信息等。
    - `interface time`：API接口时间。
    - **hardward time：kernel函数执行时间（用于性能比较）。**
    - `launch time`：launch kernel总时间。
    - `cache_miss_details`：cache miss发生次数、miss时长、对应的SPE信息。
    - `io bandWidth`：带宽。
    - `theory ios`：接口数据量，用于计算带宽，对应测试代码中的getTheoryIoSize()函数。
    - `compute_force`：算力。
    - `theory_ops`：接口计算量，用于计算算力，对应测试代码中的getTheoryOps()函数。
    - `minmax_hardware_time`：2个值分别对应最小、最大的硬件时间。
    - `minmax_hardware_time_gap`：最小、最大的硬件时间的差值。
    - `minmax_hardware_time_gap/avg(%)`：最小、最大的硬件时间的差值比例。
    - `result`: 正确性结果，PASS_S1或PASS_S2为通过，其余情况为不通过。
    - `host_result`: 主机端是否有内存泄露，success表示没有内存泄露。
    - `times`：测例在模型中的调用次数，tecotest单测算子时，默认为1。

其中，以赛题开发为例，精度通过的标准，具体计算如下：

diff(teco_result-baseline)  <= golden_threshold x diff(gpu_result-baseline)

各参数含义：
- baseline：CPU计算结果，采用double或int64数据类型。
- gpu_result：GPU计算结果。
- teco_result：TECO卡计算结果。
- diff函数选取DIFF3_MAX和DIFF3_MEAN（要求同时满足）。
    - DIFF3_MAX：最大单点相对/绝对误差。
    - DIFF3_MEAN：平均逐点相对/绝对误差。
- golden_threshold取值为2。

特别的，当diff(teco_result-baseline)小于1e-6时，也认为测试通过。

针对bfloat16数据类型（用16位二进制表示，其中1位用于sign，8位用于exponent，7位用于fraction），计算办法如下：
$$MSE\_RELA(swai, cpu) = \sum_{i=1}^{n} \frac{\lvert swai_i - cpu_i \rvert}{\lvert\max( swai_i , cpu_i )\rvert + 10^{-5}} / n$$

其中，阈值设为0.025，误差超过0.025则不通过。


#### 注意事项

赛题涉及的测例，已经将GPU运行结果一并与测例保存到指定目录。贡献者无需GPU环境，也能运行赛题提供的测例。

此外，贡献者若有非GPU依赖的精度调试需求，可以使用`samples`测试办法，与CPU直接校验。以tecoalAddTensor()算子精度与CPU误差不超过1e-5为例，其编译、运行、测试命令示例如下：

```bash
source env.sh
bash build.sh -f "add_tensor" --test on
cd build/bin
./test_add_tensor 0 1  # 首个数字用于指定SPA，第二个数字用于指定算法algo
```

出现以下结果，则表示运行成功：

```bash
...
C success rate 1.00
```

出现其余结果，则表示运行失败。例如若出现下方提示，用户需要添加正确的算法分支指定数字，具体范围需要查阅对应算子设计文档中`algo`参数的介绍，如[《tecoalAddTensor设计文档》](./doc/op_docs/add_tensor.md)写明`algo`范围是0~5的整数。

```bash
terminate called after throwing an instance of 'std::runtime_error'
  what():  The algo type does not exist!

Aborted (core dumped)
```

#### 使用限制

当前仓库仅支持以下测试情况，其余暂不支持，新增情况需要贡献者自己开发测试代码，构造测例。

- 以下算子仅支持samples测试：
    - add_tensor
    - gemm
- 以下算子仅支持tecotest测试：
    - activation_backward
    - activation_forward
    - arg_max
    - index_put
    - logical_not_tensor
    - masked_fill
    - masked_select
    - scale_tensor
    - scatter_nd_add
    - scatter_out
    - unary_ops
- 以下算子同时支持samples和tecotest测试：
    - conv_forward

### 步骤四：提交PR

PR（Pull Request）提交原则：每一个 PR = 一位用户实现的一个完整kernel函数，不支持一个 PR 包含多个特性，也不支持
单个特性拆分为多个 PR 提交。

以赛题完成为例：假设贡献者 A 计划开发 x、y、z，共3个赛题，那么贡献者 A 需要在自己fork的个人仓库，分别创建 x、y、z，3个git分支，按题目独立开发。开发完成后，每个分支对应提交一个 PR ，共计：3个赛题 = 3个分支 = 3个PR，不支持对应其余情况。

提交 PR 后，对应分支上的commit会自动同步到 PR 中。例如，贡献者 A 昨天完成了 x 分支的开发，已经提交了 x 的 PR，次日在 x 分支继续提交了bugfix或者进一步性能优化，此时不需要另建 PR，因为 x 分支原有的 PR 会自动同步 x 分支上的每一笔commit。

详情可以查阅gitee官方使用文档：[《Fork+PullRequest 模式》](https://help.gitee.com/base/%E5%BC%80%E5%8F%91%E5%8D%8F%E4%BD%9C/Fork+PullRequest%E6%A8%A1%E5%BC%8F)，例如问题6的说明：对 PR 的 bug 修改如何提交到该 PR 中。



## 常见问题

以赛题开发为例，贡献者通常会出现以下问题，请本地完成自查及其修复后，再提交PR：

- 非代码说明的注释代码，请删除，例如开发过程中的功能调试、打印代码等
- PR中的新feat不能破坏原有feat，需要兼容原有feat，即只能新增代码，不能删除原有代码
- SPM空间申请时，不要超过235KB。推荐使用仓库封装的[rt_spm_malloc()与rt_spm_free()等接口](./ual/com/rt.h)（上限240512B），可以在超量申请时，报错提醒。
- 针对自己开发的分支，需要完善[./doc/op_docs/](./doc/op_docs/)目录下的算子设计文档，说明性能优化思路，如数据分块、流水设计、广播操作等
- `git commit`提交的message信息，需要符合[commit_template](./tools/commit_template)模板规范，即`[<question_num>](<algo_num>): <subject>`格式，否则可能会影响CI环境上的测试结果
- 以赛题开发为例，赛事结果以每日自动化CI测评结果为准，不参考开发者自测的本地结果。CI测试环境与参赛者本地环境可能存在差异，无法比较两者的性能绝对值。但所有参赛者的CI测试环境都是一致的，因此CI测试结果可以比较绝对值，即性能榜单数据均源自统一的CI自动化测试环境。开发者在本地机器，可以参考自己性能优化过程的性能相对值进行优化代码的有效性检验。
- 一个PR变动文件通常在6个左右，1个PR = 1个算子 = 1个赛题，1个PR不允许变动多个算子，或多个赛题代码
    - 分支派发
        - ual/ops/opname/opname.hpp
        - ual/ops/opname/find_opname.cpp
        - ual/ops/opname/find_opname.h
    - 计算实现
        - ual/kernel/opname/opname.h
        - ual/kernel/opname/opname.scpp
    - 算子文档
        - doc/op_docs/opname.md
    - 参数调整（视情况可选）
        - interface/ops/opname.cpp
        - ual/args/opname_args.h
- 为避免代码抄袭，本gitee仓库已设置PR相互不可见。此外，选手可以在个人fork的仓库中，将个人仓库从“开源”设置改为“私有”，避免被抄袭。

![private](./doc/tutorial/pics/private.png)


## 发版记录

|版本号|说明|
|---|---|
|v1.0.0|本版本为首次正式发布版本。|

## 免责声明

- 使用限制：本开源仓库旨在促进生态交流，不得用于非法或未经授权的目的。用户需遵守相关法律法规，不得利用本仓库进行任何违法活动，如发生任何违法情形的，本仓库开发者和贡献者不承担任何法律责任。

- 责任限制：本仓库的开发者和贡献者对使用本仓库的结果不承担任何责任。用户需自行承担使用本仓库所带来的所有风险，包括但不限于财产、性能、安全性、兼容性等方面的问题。

- 知识产权声明：本仓库不侵犯任何第三方知识产权。后续贡献者应自行保证其贡献内容享有相关知识产权并在允许的范围内进行合法的发布、传播和使用，本仓库开发者不负责鉴别或审查。若因侵犯他人知识产权而造成法律责任（包括但不限于民事赔偿和刑事责任），由违约者自行承担。任何用户如发现任何侵权行为，请及时联系我们，我们将尽快删除相关内容。

## 许可认证

Teco-AL采用The 3-Clause BSD License。具体内容，请参见[LICENSE](./LICENSE)文件。
