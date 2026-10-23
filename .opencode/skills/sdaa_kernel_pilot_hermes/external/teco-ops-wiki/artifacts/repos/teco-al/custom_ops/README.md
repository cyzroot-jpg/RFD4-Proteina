## 简介

custom_ops是一个独立的文件夹，目的是指导初次接触SDAA C的开发者学习算子开发; 而其他文件夹主要是 太初社区 为了算子活动比赛准备的内容，对代码合入有一定规范要求（主要为了比赛的自动化测试等）。
custom_ops相较于Teco-AL仓库提供的比赛示例代码，学习成本低，您仅需要了解[SDAA C编程语言](http://docs.tecorigin.com/release/sdaac/)，使用较少的步骤，即可完成算子的开发和验证。

如何进行算子开发，您可以阅读以下内容：

- [SDAA C编程指南](http://docs.tecorigin.com/release/sdaac/)：介绍SDAA编程模型、语言规范、函数接口、数学函数、程序编译、程序调试及性能调优等内容。
- [SDAA C零基础入门](http://docs.tecorigin.net/release/sdaac_beginner_guide/)：介绍算子的基本概念、算子开发的流程、并以加法和矩阵乘为例，介绍如何进行算子开发。**注意:** 本目录下的add和gemm算子示例，与《SDAA C零基础入门》的示例基本一致。

如果您对开发的算子性能有更高的要求，推荐阅读：

- [性能优化手册-SDAAC篇](http://docs.tecorigin.com/release/sddac_perf_opt/)：介绍程序并行、函数接口、数学函数、程序编译过程中的性能优化方法。
- [性能优化手册-算子篇](http://docs.tecorigin.com/release/op_perf_opt/)：介绍计算与访存优化方法。计算相关优化包括向量指令、指令流水线、矩阵乘法加速单元等优化方法；访存相关优化包括双缓冲、广播等优化方法。

本文档主要介绍如何将已开发的算子合入custom_ops目录。


## 目录结构
custom_ops目录结构如下：

```bash
.
├── README.md                 # README文件，包含目录介绍、环境依赖、算子贡献指南、免责声明、许可认证等
├── run_customops.sh          # 构建和运行脚本，用于编译和运行算子
├── common.h                  # 可供使用的公共接口
├── add                       # add 算法示例文件夹
│   ├── add.scpp              # add 算法代码示例
│   └── makefile              # makefile 编译脚本
├── examples                  # 简单测例文件夹
│   ├── hello.scpp            # 展示如何打印"Hello AI Card"
│   ├── makefile              # makefile 编译脚本
│   └── spmd.scpp             # 展示如何使用SPMD编程范式完成数组自增操作
├── gemm                      # gemm 算法示例文件夹
│   ├── gemm.scpp             # gemm 算法代码示例
│   └── makefile              # makefile 编译脚本
└── other_ops                 # 贡献者的自定义算子文件夹

```

## 环境依赖

custom_ops的运行依赖以下组件，可以参考[环境安装手册](http://docs.tecorigin.com/release/software_installation/)进行安装。

- TecoDriver
- TecoToolKit


### 步骤一：创建文件夹

1. 在custom_ops目录下，创建文件夹，用于存放您的算子代码和编译运行脚本。例如，您要开发的是sigmoid算法，可以创建一个名称为sigmoid的文件夹。
2. 复制示例目录add下的makefile编译脚本，到新创建的文件夹下。

### 步骤二：开发算子

1. 在步骤一创建的目录下，创建后缀为.scpp的文件，例如：sigmoid.scpp。

2. 根据需要实现的算法功能开发算子，可以参考[SDAA C编程指南](http://docs.tecorigin.com/release/sdaac/)、[SDAA C零基础入门](http://docs.tecorigin.net/release/sdaac_beginner_guide/)进行算子开发。

   **注意:** 算子代码和测试代码均需开发。

### 步骤三：编译运行

在custom_ops目录下，运行以下命令，编译并运行算子。

```
bash ../env_dev.sh
bash run_customops.sh
```
**执行结果**

系统根据您测试代码的运行情况，打印测试结果。

### 步骤四：提交PR

PR（Pull Request）提交原则：一个PR需要包括一个完整的算子代码或改进代码，详情可以查阅gitee官方使用文档：[《Fork+PullRequest 模式》](https://help.gitee.com/base/%E5%BC%80%E5%8F%91%E5%8D%8F%E4%BD%9C/Fork+PullRequest%E6%A8%A1%E5%BC%8F)。

**注意:** PR提交的目标分支是：**tecorigin/teco-al:custom_ops**

提交PR需要按照以下提示信息，填写commit内容：  

- please input standard format for commit: {[type]: <subject> }  
- the type should be one of: 'feat', 'fix', 'perf', 'refactor', 'ci', 'tool', 'docs', 'test'   

例如：  

```
git commit -m "[feat]: add new operator sigmoid"
```

## 贡献指南

将算子合入custom_ops目录的主要流程如下：

1. **创建文件夹**：创建用于存放算子代码和编译运行脚本的文件夹，并复制示例算子的编译运行脚本到此文件夹下。
2. **开发算子**：根据需要实现的算法功能开发算子。
3. **编译运行算子**：编译并运行算子，获取算子的计算结果。
4. **提交PR**：提交代码至custom_ops目录。

## 免责声明

- 使用限制：本开源仓库旨在促进生态交流，不得用于非法或未经授权的目的。用户需遵守相关法律法规，不得利用本仓库进行任何违法活动，如发生任何违法情形的，本仓库开发者和贡献者不承担任何法律责任。

- 责任限制：本仓库的开发者和贡献者对使用本仓库的结果不承担任何责任。用户需自行承担使用本仓库所带来的所有风险，包括但不限于财产、性能、安全性、兼容性等方面的问题。

- 知识产权声明：本仓库不侵犯任何第三方知识产权。后续贡献者应自行保证其贡献内容享有相关知识产权并在允许的范围内进行合法的发布、传播和使用，本仓库开发者不负责鉴别或审查。若因侵犯他人知识产权而造成法律责任（包括但不限于民事赔偿和刑事责任），由违约者自行承担。任何用户如发现任何侵权行为，请及时联系我们，我们将尽快删除相关内容。

## 许可认证

Teco-AL采用The 3-Clause BSD License。具体内容，请参见[LICENSE](./LICENSE)文件。
