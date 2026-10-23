---
name: teco-ops-wiki
description: Query the public Tecorigin teco-ops operator source, native correctness and SDPTI benchmark workflow, interface/UAL architecture, operator design documents, SDAA hardware guidance, and related public TECO examples. Use for teco-ops implementation or performance decisions; this is KernelPilot's only wiki, with the current teco-ops main snapshot under artifacts/repos/teco-ops.
argument-hint: "[natural-language-question] | [--tag proto --type technique] | [page-id]"
allowed-tools: "Bash Read Grep Glob"
---

# teco-ops-wiki

This is KernelPilot's exclusive wiki for TECO operator work. It covers the
public Teco-Ops, Teco-AL, and PICT_smoke repositories plus the authorized
manuals bundled here. Do not fall back to another local wiki. When a question
is outside the captured evidence, report the gap and inspect the relevant
upstream source directly.

## 查询流程

在本 skill 根目录下运行：

```bash
python3 scripts/query.py "算子提交规范 commit PR 格式" --compact
python3 scripts/query.py "interface ual RUN_OP 分支派发" --compact
python3 scripts/query.py "PyTorch 绑定 torch_ext" --compact
python3 scripts/query.py "Plugin TVM Relay 自定义算子" --compact
python3 scripts/query.py "half 精度 溢出 下溢" --compact
python3 scripts/query.py "gemm 分块 广播 双缓冲" --compact
python3 scripts/query.py "conv2gemm 卷积转矩阵乘" --compact
python3 scripts/query.py "TORCH_SDAA_AUTOLOAD cuda_migrate" --compact
python3 scripts/query.py "TecoPyTorch torch.sdaa AMP DDP" --compact
python3 scripts/query.py --tag spmd --compact
python3 scripts/get_page.py doc-teco-ops-docs --follow-sources
python3 scripts/get_page.py doc-teco-al-docs --follow-sources
python3 scripts/get_page.py doc-pict-smoke-docs --follow-sources
python3 scripts/get_page.py doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0 --follow-sources
python3 scripts/get_page.py kernel-teco-ops-flatten-rays --follow-sources
python3 scripts/get_page.py technique-teco-ops-native-testing --follow-sources
python3 scripts/get_page.py source-teco-ops-rms-norm
python3 scripts/get_page.py kernel-teco-al-gemm --follow-sources
python3 scripts/get_page.py technique-pict-smoke-cuda-sdaa-model-migration
```

问题较宽泛时先读 `references/primer.md`。新增页面或判断证据质量时读 `references/schema.md`。

## 完整源码快照（artifacts/repos/）

三个仓库均已完整收录为逐字快照（不经过 `query.py`/`get_page.py`，直接用文件系统工具查看）：

```bash
ls artifacts/repos/                       # teco-ops/ teco-al/ PICT_smoke/
cat artifacts/repos/teco-al/PROVENANCE.md # 来源、分支、commit、协议
grep -rn "TECOAL_ALGO" artifacts/repos/teco-al/ual/ops/gemm/
diff artifacts/repos/PICT_smoke/raymarching/src/raymarching.cu artifacts/repos/PICT_smoke/raymarching/src_sdaa/raymarching.scpp
```

结构化页面（`sources/docs/*`）与策展页面（`wiki/*`）提到的具体源文件路径都可以在这里直接核实真实代码。

## Teco-Ops project evidence

The nine original `doc/` documents remain available as structured pages under
`sources/docs/teco-ops-docs*`. The latest source snapshot also includes the new
`causal_conv1d`, `flash_attention`, `reshape_and_cache`, and `rms_norm` design
documents. Use the `source-teco-ops-*` pages to locate exact implementation,
test, and design-document paths at commit
`ac7eb023faa0c84bdd8d9959561a59d44105da6e`.

| 主题 | 索引 page id |
|------|-------------|
| 算子提交规范（PR.md） | `doc-teco-ops-docs-p01` |
| 常见问题（QA.md） | `doc-teco-ops-docs-p02` |
| SDAA C 程序调试手册（README_DEBUG.md） | `doc-teco-ops-docs-p03` |
| 算子开发指南（README_OP.md） | `doc-teco-ops-docs-p04` |
| Plugin 自定义算子接口（README_PLUGIN.md） | `doc-teco-ops-docs-p05` |
| PyTorch 扩展绑定（README_PYTHON.md） | `doc-teco-ops-docs-p06` |
| 算子开发硬件相关知识（teco-ops-hardware.md） | `doc-teco-ops-docs-p07` |
| 算子设计文档模板（op_docs/doc_template.md） | `doc-teco-ops-docs-p08` |
| flatten_rays 设计文档范例（op_docs/flatten_rays.md） | `doc-teco-ops-docs-p09` |

| Current operator | Source page |
|---|---|
| causal_conv1d | `source-teco-ops-causal-conv1d` |
| flash_attention | `source-teco-ops-flash-attention` |
| flatten_rays | `source-teco-ops-flatten-rays` |
| memset | `source-teco-ops-memset` |
| morton3D_invert | `source-teco-ops-morton3d-invert` |
| reduce_variance | `source-teco-ops-reduce-variance` |
| reshape_and_cache | `source-teco-ops-reshape-and-cache` |
| rms_norm | `source-teco-ops-rms-norm` |

## Teco-AL 项目文档集（完整结构化）

`doc/` 目录与根 `README.md` 已整理为 19 份分卷页：索引页 `sources/docs/teco-al-docs.md`（`doc-teco-al-docs`），正文在 `sources/docs/teco-al-docs/p*.md`（`doc-teco-al-docs-p*`），原文全文存于 `sources/docs/raw-teco-al/*.txt`。

| 主题 | 索引 page id |
|------|-------------|
| 仓库总览、目录结构、贡献指南（README.md） | `doc-teco-al-docs-p01` |
| 开发指南：核心概念（句柄/张量/描述符/工作空间） | `doc-teco-al-docs-p02` |
| 编程规范 | `doc-teco-al-docs-p03` |
| 算子设计文档模板 | `doc-teco-al-docs-p04` |
| **AddTensor**（完整讲解范例，含真实性能数据） | `doc-teco-al-docs-p05` |
| **Hgemm**（完整讲解范例，含真实性能数据） | `doc-teco-al-docs-p06` |
| **ConvolutionForward**（完整讲解范例，含真实性能数据） | `doc-teco-al-docs-p07` |
| ActivationForward / ActivationBackward | `doc-teco-al-docs-p08` / `p09` |
| Argmax / IndexPut / LogicalNotTensor | `doc-teco-al-docs-p10` / `p11` / `p12` |
| MaskedFill / MaskedSelect / ScaleTensor | `doc-teco-al-docs-p13` / `p14` / `p15` |
| ScatterNdAdd / ScatterOut / UnaryOps / Unique | `doc-teco-al-docs-p16` / `p17` / `p18` / `p19` |

## PICT_smoke 项目文档集

| 主题 | 索引 page id |
|------|-------------|
| SDAA 迁移与训练指南（README.md，中文） | `doc-pict-smoke-docs-p01` |
| 原始学术项目说明（readme_en.md，英文，SIGGRAPH 2024） | `doc-pict-smoke-docs-p02` |

## Bundled official manuals

| 文档 | 索引 page id |
|------|-------------|
| SDAA C 编程指南 v3.1.0 | `doc-sdaa-c-programming-guide-v3-1-0` |
| 性能优化手册 SDAA C 篇 v2.0.2 | `doc-perf-optimization-sdaa-c-v2-0-2` |
| 性能优化手册 算子篇 v1.1.0 | `doc-perf-optimization-operator-v1-1-0` |
| SDAA C 零基础入门 v1.1.0 | `doc-sdaa-c-getting-started-v1-1-0` |
| TecoLIBRT 用户手册 v1.2.0 | `doc-tecolibrt-user-manual-v1-2-0` |
| TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0` |

## 策展 wiki 页面

| 主题 | Page ID |
|---|---|
| 硬件与编程模型速览（SPA/SPE/SPMD） | `hw-teco-ops-hardware-model` |
| interface+ual 分层算子开发 | `technique-teco-ops-interface-ual-layering` |
| PyTorch 扩展绑定 | `technique-teco-ops-python-torch-binding` |
| Plugin/TVM Relay IR 注册 | `technique-teco-ops-plugin-relay-registration` |
| 精度问题三类模式 | `pattern-teco-ops-precision-pitfalls` |
| flatten_rays 范例解析 | `kernel-teco-ops-flatten-rays` |
| Teco-AL 分支递进式性能优化方法论 | `technique-teco-al-algo-branch-benchmarking` |
| Hgemm 分块+广播+重排+双缓冲解析 | `kernel-teco-al-gemm` |
| ConvolutionForward conv2gemm 解析 | `kernel-teco-al-conv-forward` |
| AddTensor 分块+双缓冲入门案例 | `kernel-teco-al-add-tensor` |
| PICT_smoke 模型级 CUDA→SDAA 自动迁移模式 | `technique-pict-smoke-cuda-sdaa-model-migration` |
| teco-ops native correctness and SDPTI benchmark | `technique-teco-ops-native-testing` |

## 证据规则

1. 回答时引用 page id 和路径。
2. 沿 `sources:` 追溯到 `sources/docs/raw-teco-ops/`、`sources/docs/raw-teco-al/` 或 `sources/docs/raw/` 下的原始文本。
3. 官方手册与两仓库 `doc/` 目录内容均可按 `verified` 使用（均为已发布的官方/公开仓库材料）。
4. If a question is outside this knowledge base, state the coverage gap and
   inspect the upstream repository source directly. Do not substitute another
   local wiki.

## KernelPilot 集成

Teco-Ops/Teco-AL 相关任务在 KernelPilot 中应遵循：

1. Recover K/R/W and the exact teco-ops revision.
2. Query the matching `source-teco-ops-*` page, the interface/UAL page, and
   `technique-teco-ops-native-testing`.
3. Verify proposed changes against the captured source and relevant manuals.
4. Use the repository's native correctness test and SDPTI-backed Average
   Hardware Time with 3 warm-ups and 50 repeats.
5. Record every decision-changing page ID in the attempt ledger.
