---
id: technique-pict-smoke-cuda-sdaa-model-migration
title: "PICT_smoke：模型级 CUDA→SDAA 自动迁移模式（TORCH_SDAA_AUTOLOAD + USE_SDAA）"
type: technique
architectures: [sdaa, teco-t1]
tags: [pict-smoke, cuda-migration, torch-sdaa-autoload, pytorch-extension, model-zoo, build-flag]
confidence: verified
reproducibility: snippet
related: [technique-teco-ops-python-torch-binding, technique-teco-ops-interface-ual-layering]
sources: [doc-pict-smoke-docs-p01, doc-pict-smoke-docs-p02, doc-pict-smoke-docs]
aliases: ["TORCH_SDAA_AUTOLOAD", "cuda_migrate", "USE_SDAA"]
---

# PICT_smoke：模型级 CUDA→SDAA 自动迁移模式

PICT_smoke（`doc-pict-smoke-docs`）是 Tecorigin ModelZoo 中一个完整模型（而非单个算子）的 CUDA→SDAA 迁移案例，与 `technique-teco-ops-interface-ual-layering`/`technique-teco-al-algo-branch-benchmarking` 描述的"从零设计一个新算子"不同——这里的问题是"已有一个基于 PyTorch + 自定义 CUDA 扩展的现成模型，如何以最小改动让它在 SDAA 上跑起来"。对照原始项目 README（`doc-pict-smoke-docs-p02`）与 Tecorigin 迁移版 README（`doc-pict-smoke-docs-p01`），可以提炼出两个关键接入点。

## 接入点一：构建期切换实现——`USE_SDAA=1`

原始项目通过标准 `pip install -e .` 编译 CUDA 扩展（`raymarching/setup.py` 走 `raymarching/src/` 下的 `raymarching.cu`）。迁移版本改为：

```bash
cd ./raymarching
USE_SDAA=1 pip3 install -v .
cp build/lib.linux-x86_64-3.10/_raymarching_mob.cpython-310-x86_64-linux-gnu.so ./
```

`USE_SDAA=1` 是传给 `setup.py` 的构建期环境变量开关，用于让同一个 `setup.py` 在构建时选择编译 `raymarching/src_sdaa/`（`.scpp` 实现）而非 `raymarching/src/`（`.cu` 实现）。这是"双实现目录 + 构建开关选择"模式——与 Teco-Ops/Teco-AL 的 `algo` 参数分支派发（运行时选择）不同，这里是**构建时**二选一，两套实现互斥编译，不会同时出现在最终产物里。

构建产物需要手动 `cp` 到扩展根目录，不同于原始 `pip install -e .`（可编辑安装会自动创建符号链接指向构建产物）——这是迁移时容易遗漏的一步：SDAA 构建路径下产物不会被自动发现，必须手动放置到 Python 能 import 到的位置。

## 接入点二：运行期自动迁移——`TORCH_SDAA_AUTOLOAD=cuda_migrate`

启动训练前需要设置：

```bash
export TORCH_SDAA_AUTOLOAD=cuda_migrate
python train.py --config configs/cyl.txt
```

这个环境变量是运行时钩子，让 PyTorch 在导入阶段自动把模型代码里对 CUDA 设备/API 的调用重定向到 SDAA（"自动迁移"，原文注释即为此意）。与需要逐行修改代码把 `.cuda()`/`device='cuda'` 替换成 SDAA 等价写法的手动迁移方式相比，这个开关的价值在于：模型本体代码（`src/network/`、`src/renderer/` 等，未随本知识库收录）可以保持基本不变，只有自定义 CUDA 扩展（raymarching）这一层需要显式提供 SDAA 实现并通过构建开关切换。

## 两个接入点的分工

| 层次 | 迁移手段 | 是否需要改代码 |
|---|---|---|
| 标准 PyTorch 算子调用（`.cuda()`、tensor 运算等） | `TORCH_SDAA_AUTOLOAD=cuda_migrate` 运行时自动重定向 | 否 |
| 自定义 CUDA 扩展（本例中的 raymarching） | 需要提供对应的 `.scpp` 实现 + `USE_SDAA=1` 构建期切换 | 是（扩展层） |

这个分工模式提示一个通用判断标准：把一个纯 PyTorch 模型迁移到 SDAA 时，工作量集中在"这个模型是否有自定义 CUDA 扩展（`torch.utils.cpp_extension`/CUDA kernel）"——标准算子调用大概率可以靠自动迁移钩子零改动跑通，自定义扩展则必须走 `technique-teco-ops-python-torch-binding` 一类的手工绑定路线，针对性地补齐 SDAA 实现。

## 局限与未验证部分

This page extracts integration points from the two README files. For detailed
SIMD, DMA, or ACE migration mechanics, inspect the upstream
`raymarching/src_sdaa/raymarching.scpp` source directly and record the evidence
gap; do not substitute another local wiki.
