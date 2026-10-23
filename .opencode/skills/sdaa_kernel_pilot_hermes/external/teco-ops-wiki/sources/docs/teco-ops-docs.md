---
id: doc-teco-ops-docs
title: "Teco-Ops 项目文档集"
type: source-doc
source_category: public-repo-doc
product_version: "commit d90ddf5"
published_at: "2026-06-29"
created_at: "2026-06-29"
captured_at: "2026-07-03"
author: "Tecorigin/teco-ops (GitHub)"
doc_kind: repo-documentation
source_repo: "https://github.com/Tecorigin/teco-ops"
source_commit: "d90ddf51f09374ea082f8b4f9dbf96190384b1f6"
license: "BSD-3-Clause"
source_file: "doc/"
raw_text: "sources/docs/raw-teco-ops/"
architectures: [sdaa, teco-t1]
tags: [teco-ops, operator-development, ual, interface, pytorch-binding, plugin, debug, testing, proto]
languages: [sdaa-c, cpp, python, zh-cn]
confidence: verified
---

# Teco-Ops 项目文档集

> Teco-Ops 是 Tecorigin 面向 SDAA / 太初 T1 的开源外部生态算子仓库（`teco/` interface+ual 分层实现、`api/` PyTorch 绑定、`test/` 测试框架），BSD-3-Clause 协议。本页是该仓库 `doc/` 目录下全部文档的**结构化索引**；仓库完整源码（`teco/`、`cuda/`、`api/`、`test/` 等全部内容）已作为逐字快照收录于 `artifacts/repos/teco-ops/`（见下方"完整源码快照"一节）。

这是 Teco-Ops 项目文档集的**索引页**。完整正文按原始文件切分在下方 `part` 子页中（共 9 部分），每个 part 保留原文全部内容。原始 markdown 全文存于 `raw_text` 目录下，可逐文件追溯。

## 文档元信息

- 来源仓库：`https://github.com/Tecorigin/teco-ops`
- 采集 commit：`d90ddf51f09374ea082f8b4f9dbf96190384b1f6`（2026-06-29）
- 协议：BSD-3-Clause
- 本页采集范围：`doc/` 目录（含 `doc/op_docs/`）的结构化拆分
- 原始全文：`sources/docs/raw-teco-ops/`（逐文件保留，未做任何改写）

## 完整源码快照

`artifacts/repos/teco-ops/` 收录了本仓库在采集 commit 下的**完整工作树快照**（不含 `.git` 历史），包括本页未结构化拆分的 `teco/`（interface+ual 算子实现）、`cuda/`（CUDA 基线实现）、`api/`（PyTorch 绑定实现）、`test/`（测试框架与用例）、`plugin_test/`、`python_api_test/`、`common/`、`examples/`、`tools/` 等全部内容。溯源信息见 `artifacts/repos/teco-ops/PROVENANCE.md`。

## 完整内容分卷（part 子页）

| Part | 原始文件 | 主题 | 行数 | 页面 |
|------|---------|------|------|------|
| p01 | `doc/PR.md` | 算子提交规范（commit 格式、PR 规范、代码风格、cpplint） | 79 | `doc-teco-ops-docs-p01` |
| p02 | `doc/QA.md` | 常见问题（proto 参数配置、Executor/Parser/MetaTensor 测试框架） | 183 | `doc-teco-ops-docs-p02` |
| p03 | `doc/README_DEBUG.md` | SDAA C 程序调试手册（printf、TecoGDB、abort、assert、精度问题） | 264 | `doc-teco-ops-docs-p03` |
| p04 | `doc/README_OP.md` | 算子开发指南（interface+ual 分层架构，添加新算子完整流程） | 595 | `doc-teco-ops-docs-p04` |
| p05 | `doc/README_PLUGIN.md` | Plugin 自定义算子接口（Teco-Inference / TVM Relay IR 注册） | 399 | `doc-teco-ops-docs-p05` |
| p06 | `doc/README_PYTHON.md` | PyTorch 扩展绑定（torch_ext.cpp、setup.py 构建） | 202 | `doc-teco-ops-docs-p06` |
| p07 | `doc/teco-ops-hardware.md` | 算子开发硬件相关知识（异构计算、SPMD、Kernel 函数、存储空间、数据传输） | 238 | `doc-teco-ops-docs-p07` |
| p08 | `doc/op_docs/doc_template.md` | 算子设计文档模板 | 80 | `doc-teco-ops-docs-p08` |
| p09 | `doc/op_docs/flatten_rays.md` | flatten_rays 算子设计文档（填写示例） | 131 | `doc-teco-ops-docs-p09` |

## 文档集目录（原文）

  - PR.md：算子提交规范（commit 消息格式、PR 规范、代码风格、代码格式化、cpplint 检查）
  - QA.md：如何补充算子 proto 参数、prototxt 参数与测试代码 input/output 的关系
  - README_DEBUG.md：打印运行时日志、TecoGDB 调试工具、终止设备端程序、断言、常见精度问题（half 精度、整型溢出、数据下溢）
  - README_OP.md：开发前准备、常用概念、分层架构设计、添加新算子九步流程、Proto 参数说明、Executor 类说明
  - README_PLUGIN.md：Plugin 架构概述、环境要求、开发流程（属性结构体/AbstractPluginOp/注册）、构建步骤、Python 端使用、ComputeContext/OpAttr 接口参考
  - README_PYTHON.md：添加新算子绑定、构建、清理构建、使用示例、常见问题
  - teco-ops-hardware.md：异构计算、硬件架构（SU/SREG/VPU/VREG/FU/SPM）、SPMD、Kernel 函数、存储空间、数据传输
  - op_docs/doc_template.md：算子设计文档模板（计算原理、功能实现、性能优化、分支派发、文件结构、使用示例）
  - op_docs/flatten_rays.md：flatten_rays 算子设计文档填写示例

## 说明

本索引页与其 9 个 part 子页覆盖 Teco-Ops 仓库 `doc/` 目录下的开发者文档，用于说明算子提交规范、调试手段、interface+ual 分层开发流程、PyTorch/Plugin 绑定方式和测试框架用法。算子的实际源码实现（`teco/interface/`、`teco/ual/`、`cuda/`）、Python 绑定实现细节（`api/`）与测试用例数据（`test/`）请直接查阅 `artifacts/repos/teco-ops/`（完整快照，见上）。原文中引用的示意图（`doc/images/*.png`、`doc/op_docs/pics/*.png`、`doc/prototxt-example.png`）在结构化 part 页中未重复收录，但在 `artifacts/repos/teco-ops/doc/` 下的完整快照中保留原始图片文件。
