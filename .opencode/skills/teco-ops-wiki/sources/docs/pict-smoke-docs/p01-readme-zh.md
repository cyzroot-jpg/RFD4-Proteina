---
id: doc-pict-smoke-docs-p01
title: "PICT_smoke 项目文档集 — 第p01部分 (README.md)"
type: source-doc-part
parent_doc: doc-pict-smoke-docs
product_version: "commit 9a928d4"
source_file: "README.md"
raw_text: "sources/docs/raw-pict-smoke/README.txt"
raw_line_range: "1-74"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [pict-smoke, sdaa-migration, training-guide, raymarching, torch-sdaa]
---

# PICT_smoke 项目文档集（第p01部分：README.md，SDAA 迁移与训练指南）

# Physics-Informed Learning of Characteristic Trajectories for Smoke Reconstruction
基于此开源模型（烟雾重建特征轨迹的物理学习）做cuda到sdaa的自定义算子迁移，并支持此模型在sdaa上运行

## 1. 模型概述
- 仓库链接：PICT_Smoke（原始项目主页）
- 论文链接：见 readme_en.md
- 视频链接：见 readme_en.md
- 详细信息参考readme_en.md（`doc-pict-smoke-docs-p02`）

## 2. 快速开始
使用本模型执行训练的主要流程如下：
1. 基础环境安装：介绍训练前需要完成的基础环境检查和安装。
2. 获取数据集：介绍如何获取训练所需的数据集。
3. 构建环境：介绍如何构建模型运行所需要的环境。
4. 启动训练：介绍如何运行训练。

### 2.1 基础环境安装

请参考基础环境安装章节，完成训练前的基础环境检查和安装。

### 2.2 准备数据集
#### 2.2.1 获取数据集
论文中使用的数据集可以从 Google Drive 下载（原文附有下载链接，此处不重复收录外部链接）。

#### 2.2.2 处理数据集
解压data.zip后放置在模型根目录下。


### 2.3 构建环境

所使用的环境下已经包含PyTorch框架虚拟环境。
1. 执行以下命令，启动虚拟环境。
    ```
    conda activate torch_env
    ```
2. 安装python依赖。
    ```
    pip install -r requirements.txt
    ```
3. 安装raymarching。
    ```
    cd ./raymarching
    USE_SDAA=1 pip3 install -v .
    cp build/lib.linux-x86_64-3.10/_raymarching_mob.cpython-310-x86_64-linux-gnu.so ./
    ```
### 2.4 启动训练

1. 在构建好的环境中，进入训练脚本所在目录。
    ```
    cd <ModelZoo_path>/PyTorch/build-in/Detection/PICT_smoke
    ```

2. 运行训练。
    - 以圆柱体场景为例：

    ```
    export TORCH_SDAA_AUTOLOAD=cuda_migrate  #自动迁移环境变量
    python train.py --config configs/cyl.txt

    ```

### 2.5 备注

#### if ffmpeg is not installed (test by ffmpeg -version)
conda install ffmpeg

#### Installing problem
- Ninja is required to load C++ extensions
```
pip install Ninja
```
