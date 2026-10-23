---
id: doc-pict-smoke-docs
title: "PICT_smoke 项目文档集"
type: source-doc
source_category: public-repo-doc
product_version: "commit 9a928d4"
published_at: "2026-07-06"
created_at: "2026-07-06"
captured_at: "2026-07-10"
author: "Tecorigin/PICT_smoke (GitHub)"
doc_kind: repo-documentation
source_repo: "https://github.com/Tecorigin/PICT_smoke"
source_branch: "main"
source_commit: "9a928d46fe7370d12e7ad76ad9e6134ff949d2e5"
license: "unspecified upstream; original PICT project is SIGGRAPH 2024 academic code (see readme_en.md citation)"
source_file: "README.md, readme_en.md"
raw_text: "sources/docs/raw-pict-smoke/"
architectures: [sdaa, teco-t1]
tags: [pict-smoke, cuda-migration, model-zoo, raymarching, pytorch-extension, siggraph]
languages: [cpp, python, zh-cn]
confidence: verified
---

# PICT_smoke 项目文档集

> PICT_smoke 是 Tecorigin 对开源学术项目 *Physics-Informed Learning of Characteristic Trajectories for Smoke Reconstruction*（SIGGRAPH 2024，烟雾重建的物理信息特征轨迹学习）做 CUDA→SDAA 自定义算子迁移后的模型仓库，用于验证/演示该模型可在 SDAA 平台上运行。仓库定位为 ModelZoo 中的一个迁移示例（原文路径引用 `<ModelZoo_path>/PyTorch/build-in/Detection/PICT_smoke`），而非算子开发框架，与 Teco-Ops/Teco-AL 的性质不同。

这是 PICT_smoke 项目文档集的**索引页**。本仓库文件规模很小（45 个文件），且没有独立的 `doc/` 目录，文档内容仅为仓库根目录的两份 README。完整正文按原始文件切分在下方 `part` 子页中（共 2 部分）。仓库完整源码（含 CUDA/SDAA 迁移代码）已作为逐字快照收录于 `artifacts/repos/PICT_smoke/`（见下方"完整源码快照"一节）。

## 文档元信息

- 来源仓库：`https://github.com/Tecorigin/PICT_smoke`（公开仓库，非私有，BSD 等开源协议未在仓库中声明；原始学术项目引用信息见 p02）
- 采集分支：`main`
- 采集 commit：`9a928d46fe7370d12e7ad76ad9e6134ff949d2e5`（2026-07-06，仓库创建后 4 天内的采集）
- 本页采集范围：仓库根目录的 `README.md`（中文，SDAA 迁移与训练指南）与 `readme_en.md`（英文，原始学术项目说明与引用信息）
- 原始全文：`sources/docs/raw-pict-smoke/`（逐文件保留，未做任何改写）

## 完整源码快照

`artifacts/repos/PICT_smoke/` 收录了本仓库在采集 commit 下的**完整工作树快照**，包括 `raymarching/src/`（原始 CUDA 实现：`raymarching.cu`、`raymarching.h`、`pcg32.h`、`bindings.cpp`）、`raymarching/src_sdaa/`（对应的 SDAA 迁移实现：`raymarching.scpp`、`raymarching.h`、`bindings.cpp`，与 `src/` 逐文件对应，是一组完整的 CUDA→SDAA 迁移前后对照）、`src/`（模型本体：`network/`、`renderer/`、`dataset/`、`utils/`）、`configs/`、`train.py`、`test.py`、`env_test.py`。溯源信息见 `artifacts/repos/PICT_smoke/PROVENANCE.md`。`technique-pict-smoke-cuda-sdaa-model-migration` 页面中记录的迁移接入点（`TORCH_SDAA_AUTOLOAD`/`USE_SDAA`）可直接对照此处的 `raymarching.cu` vs `raymarching.scpp` 核实具体迁移手法。

## 完整内容分卷（part 子页）

| Part | 原始文件 | 主题 | 行数 | 页面 |
|------|---------|------|------|------|
| p01 | `README.md` | SDAA 迁移与训练指南（中文）：环境安装、数据集获取、raymarching 扩展的 SDAA 构建、启动训练 | 74 | `doc-pict-smoke-docs-p01` |
| p02 | `readme_en.md` | 原始学术项目说明（英文）：项目/论文/视频链接、原始 CUDA 环境搭建、训练/测试命令、SIGGRAPH 2024 引用信息 | 83 | `doc-pict-smoke-docs-p02` |

## 源码目录一览（完整内容见 artifacts/repos/PICT_smoke/）

以下目录未在本索引页结构化拆分，但完整包含在 `artifacts/repos/PICT_smoke/` 的逐字快照中：

| 目录/文件 | 文件数 | 说明 |
|---|---|---|
| `raymarching/src/` | 4 | 原始 CUDA 实现：`raymarching.cu`（63,623 字节）、`raymarching.h`、`pcg32.h`、`bindings.cpp`——这是本仓库中体量最大、信息密度最高的部分。 |
| `raymarching/src_sdaa/` | 3 | 对应的 SDAA 迁移实现：`raymarching.scpp`（104,054 字节）、`raymarching.h`、`bindings.cpp`——与 `src/` 逐文件对应，构成一组完整的 CUDA→SDAA 迁移前后对照。 |
| `raymarching/` 根 | 3 | `__init__.py`、`backend.py`、`raymarching.py`（PyTorch 扩展 Python 封装层） |
| `src/` | 15 | 模型本体：`network/`（hybrid_model、lagrangian_field、neus_field、siren_basic）、`renderer/`（occupancy_grid、render_ray）、`dataset/`、`utils/` |
| `configs/` | 4 | 训练配置文件（`car.txt`/`cyl.txt`/`game.txt`/`scalar.txt`） |
| 根目录脚本 | 3 | `train.py`、`test.py`、`env_test.py` |

`raymarching/src/` 与 `raymarching/src_sdaa/` 这一对目录是一次真实的、逐文件对应的 CUDA 自定义算子到 SDAA `.scpp` 的迁移案例，是本知识库中体量最大的单个迁移参考（源文件超过 60KB/100KB），可在 `artifacts/repos/PICT_smoke/raymarching/` 下直接对照阅读。
