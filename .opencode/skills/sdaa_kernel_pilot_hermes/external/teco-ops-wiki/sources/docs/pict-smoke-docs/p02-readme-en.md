---
id: doc-pict-smoke-docs-p02
title: "PICT_smoke 项目文档集 — 第p02部分 (readme_en.md)"
type: source-doc-part
parent_doc: doc-pict-smoke-docs
product_version: "commit 9a928d4"
source_file: "readme_en.md"
raw_text: "sources/docs/raw-pict-smoke/readme_en.txt"
raw_line_range: "1-83"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [pict-smoke, siggraph, original-project, citation, raymarching]
---

# PICT_smoke 项目文档集（第p02部分：readme_en.md，原始学术项目说明）

# Physics-Informed Learning of Characteristic Trajectories for Smoke Reconstruction

> Yiming Wang, Siyu Tang, Mengyu Chu

> SIGGRAPH 2024

> 原文附有项目/论文/arXiv/视频链接与一张效果图（`assets/teaser1.png`），本知识库为纯文本知识库，未收录图片与外部链接，仅保留文字说明与引用信息。

## Setup
```
# build environment with python 3.7
conda create -n pinf python=3.7
conda activate pinf

# if ffmpeg is not installed (test by ffmpeg -version)
conda install -c conda-forge ffmpeg
conda install ffmpeg

# requirments
pip install -r requirments

# raymarching
cd raymarching
pip install -e .

# test environment
python env_test.py
```

数据集下载链接见原仓库 README（Google Drive）。

## Run

### Training

Take the Cylinder scene as an example:

```
python train.py --config configs/cyl.txt
```

### Testing

```
# velocity voxel output
python test.py --config configs/cyl.txt --testskip 1 --output_voxel --full_vol_output

# render novel view
python test.py --config configs/cyl.txt --render_only

# static object mesh
python test.py --config configs/cyl.txt --mesh_only
```

## Installing problem
- Ninja is required to load C++ extensions
```
pip install Ninja
```

## Citation
```
@inproceedings{Wang2024PICT,
  author = {Wang, Yiming and Tang, Siyu and Chu, Mengyu},
  title = {Physics-Informed Learning of Characteristic Trajectories for Smoke Reconstruction},
  year = {2024},
  doi = {10.1145/3641519.3657483},
  booktitle = {ACM SIGGRAPH 2024 Conference Papers},
  articleno = {53},
  numpages = {11},
  series = {SIGGRAPH '24}
}
```

## 与 p01 的对比

对照 `doc-pict-smoke-docs-p01`（Tecorigin 的 SDAA 迁移版 README）可以看到迁移带来的三处关键差异：

1. 原始环境用 `pip install -e .`（原地可编辑安装，走 CUDA 编译路径）构建 raymarching 扩展；SDAA 版本改为 `USE_SDAA=1 pip3 install -v .`，通过环境变量在构建时切换到 `raymarching/src_sdaa/` 下的 `.scpp` 实现（见 `doc-pict-smoke-docs` 索引页"未收录内容"一节）。
2. SDAA 版本训练命令前需要 `export TORCH_SDAA_AUTOLOAD=cuda_migrate`，原始版本无此步骤——这是模型级别（而非单算子级别）CUDA→SDAA 自动迁移的关键开关，详见 `technique-pict-smoke-cuda-sdaa-model-migration`。
3. SDAA 版本构建产物需要手动复制 `.so` 文件（`cp build/lib.linux-x86_64-3.10/_raymarching_mob.cpython-310-x86_64-linux-gnu.so ./`），原始版本的可编辑安装不需要这一步——说明 SDAA 构建路径的产物放置位置与标准 `pip install -e .` 的自动链接机制不同，是迁移时容易遗漏的一步。
