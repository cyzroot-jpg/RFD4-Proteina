---
id: doc-teco-al-docs
title: "Teco-AL 项目文档集"
type: source-doc
source_category: public-repo-doc
product_version: "v1.0.0 / commit 17c5cd6"
published_at: "2024-04-02"
created_at: "2024-04-02"
captured_at: "2026-07-10"
author: "Tecorigin/teco-al (Gitee)"
doc_kind: repo-documentation
source_repo: "https://gitee.com/tecorigin/teco-al"
source_branch: "develop"
source_commit: "17c5cd66f0ca86d74e5f9c37d507656febfb8897"
license: "BSD-3-Clause"
source_file: "doc/, README.md"
raw_text: "sources/docs/raw-teco-al/"
architectures: [sdaa, teco-t1]
tags: [teco-al, operator-development, ual, interface, accelerated-library, gemm, conv, algo-dispatch]
languages: [sdaa-c, cpp, zh-cn]
confidence: verified
---

# Teco-AL 项目文档集

> Teco-AL（Teco-Accelerated Libraries，太初加速库）是 Tecorigin 面向 SDAA 平台开源的统一算子库仓库（`interface/`+`ual/` 分层实现），采用与 Teco-Ops 相同的分层架构，历史上作为"算子开发赛题"仓库运营（README 中明确标注"赛题"字样），BSD-3-Clause 协议，公开托管于 Gitee。本页是该仓库 `doc/` 目录与根 `README.md` 的**结构化索引**；仓库完整源码（`interface/`、`ual/`、`custom_ops/`、`test/`、`samples/`、`SDAAC_examples/` 等全部内容）已作为逐字快照收录于 `artifacts/repos/teco-al/`（见下方"完整源码快照"一节）。

这是 Teco-AL 项目文档集的**索引页**。完整正文按原始文件切分在下方 `part` 子页中（共 19 部分），每个 part 保留原文全部内容。原始 markdown 全文存于 `raw_text` 目录下，可逐文件追溯。

## 文档元信息

- 来源仓库：`https://gitee.com/tecorigin/teco-al`（公开仓库，非私有）
- 采集分支：`develop`（仓库默认分支；仓库另有 `custom_ops` 分支，未采集）
- 采集 commit：`17c5cd66f0ca86d74e5f9c37d507656febfb8897`
- 发布版本：v1.0.0（README"发版记录"章节标注为首次正式发布版本）
- 协议：BSD-3-Clause（见仓库 `LICENSE`），版权声明见仓库 `NOTICE`（太初（无锡）电子科技有限公司）
- 本页采集范围：`doc/` 目录（含 `doc/op_docs/`、`doc/tutorial/`）与仓库根 `README.md` 的结构化拆分
- 原始全文：`sources/docs/raw-teco-al/`（逐文件保留，未做任何改写）

## 完整源码快照

`artifacts/repos/teco-al/` 收录了本仓库在采集 commit 下的**完整工作树快照**（不含 `.git` 历史），包括本页未结构化拆分的 `interface/`、`ual/`（`args/`/`ops/`/`kernel/`/`com/`，含 `com/rt.h`）、`custom_ops/`、`test/`（tecotest 框架，含 `test/frame_work/tecotest/thirdparty/` 下的 protobuf 3.21.8、googletest 1.12.1 vendored 源码）、`samples/`、`SDAAC_examples/`、`thirdparty/`（含编译产物 `libtecoaccuracy.a`）、`tools/`、`cmake/` 等全部内容。溯源信息见 `artifacts/repos/teco-al/PROVENANCE.md`。

## 完整内容分卷（part 子页）

| Part | 原始文件 | 主题 | 行数 | 页面 |
|------|---------|------|------|------|
| p01 | `README.md` | 仓库总览、目录结构、分层架构、贡献指南（fork+PR、测试流程、CI 评测规则） | 416 | `doc-teco-al-docs-p01` |
| p02 | `doc/tutorial/dev_guide.md` | 开发指南：代码风格/结构/逻辑分类，核心概念附录（句柄/张量/存储格式/描述符/工作空间） | 167 | `doc-teco-al-docs-p02` |
| p03 | `doc/tutorial/code_style.md` | 编程规范（Google C++ 风格、cpplint、format2google） | 14 | `doc-teco-al-docs-p03` |
| p04 | `doc/op_docs/doc_template.md` | 算子设计文档模板 | 40 | `doc-teco-al-docs-p04` |
| p05 | `doc/op_docs/add_tensor.md` | AddTensor 设计文档（讲解示例：数据分块 + 双缓冲流水，含真实性能数据） | 97 | `doc-teco-al-docs-p05` |
| p06 | `doc/op_docs/gemm.md` | Hgemm 设计文档（讲解示例：分块 + 数据广播 + 数据重排 + 双缓冲，完整 7 级优化路线与真实性能数据） | 142 | `doc-teco-al-docs-p06` |
| p07 | `doc/op_docs/conv_forward.md` | ConvolutionForward 设计文档（讲解示例：conv-to-gemm 等价转换 + 分块 + 广播 + 双缓冲，含真实性能数据） | 157 | `doc-teco-al-docs-p07` |
| p08 | `doc/op_docs/activation_forward.md` | ActivationForward 设计文档（SiLU 激活正向） | 70 | `doc-teco-al-docs-p08` |
| p09 | `doc/op_docs/activation_backward.md` | ActivationBackward 设计文档（SiLU 激活反向梯度） | 81 | `doc-teco-al-docs-p09` |
| p10 | `doc/op_docs/arg_max.md` | Argmax 设计文档 | 59 | `doc-teco-al-docs-p10` |
| p11 | `doc/op_docs/index_put.md` | IndexPut 设计文档 | 99 | `doc-teco-al-docs-p11` |
| p12 | `doc/op_docs/logical_not_tensor.md` | LogicalNotTensor 设计文档 | 59 | `doc-teco-al-docs-p12` |
| p13 | `doc/op_docs/masked_fill.md` | MaskedFill 设计文档 | 68 | `doc-teco-al-docs-p13` |
| p14 | `doc/op_docs/masked_select.md` | MaskedSelect 设计文档 | 67 | `doc-teco-al-docs-p14` |
| p15 | `doc/op_docs/scale_tensor.md` | ScaleTensor 设计文档 | 58 | `doc-teco-al-docs-p15` |
| p16 | `doc/op_docs/scatter_nd_add.md` | ScatterNdAdd 设计文档 | 80 | `doc-teco-al-docs-p16` |
| p17 | `doc/op_docs/scatter_out.md` | ScatterOut 设计文档 | 122 | `doc-teco-al-docs-p17` |
| p18 | `doc/op_docs/unary_ops.md` | UnaryOps 设计文档 | 68 | `doc-teco-al-docs-p18` |
| p19 | `doc/op_docs/unique.md` | Unique 设计文档 | 82 | `doc-teco-al-docs-p19` |

## 算子支持现状（原文分类，见 README）

- **讲解示例**（含完整性能优化路线与真实性能数据）：`add_tensor`、`gemm`、`conv_forward`
- **设计文档模板**：`doc_template`
- **赛题算子参考**（接口设计已定稿，性能优化章节标注"赛题补充内容"待贡献者填写）：`activation_backward`、`activation_forward`、`arg_max`、`index_put`、`logical_not_tensor`、`masked_fill`、`masked_select`、`scale_tensor`、`scatter_nd_add`、`scatter_out`、`unary_ops`、`unique`

即：16 个算子设计文档中，3 个（add_tensor/gemm/conv_forward）是完整讲解范例，1 个是空白模板，其余 12 个只定稿了接口设计与类型限制，性能优化章节留空供贡献者在参赛开发时补充——这一状态在各 part 页的正文中均保持原样收录，不做臆测填充。

## 源码目录一览（完整内容见 artifacts/repos/teco-al/）

以下目录未在本索引页结构化拆分，但完整包含在 `artifacts/repos/teco-al/` 的逐字快照中：

| 目录 | 文件数（commit 17c5cd6 时点） | 说明 |
|---|---|---|
| `test/` | 3803 | tecotest 测试框架代码与 prototxt 测例数据（含 vendored `thirdparty/` 下的 protobuf/googletest 源码） |
| `SDAAC_examples/` | 200 | SDAA C 编程指南配套示例代码 |
| `ual/` | 102 | 核心计算层：`args/`（参数结构体）、`ops/`（分支派发）、`kernel/`（`.scpp` 设备端实现）、`com/`（含 `rt.h`） |
| `interface/` | 25 | 用户 API 层：`include/tecoal.h`、`common/`、`ops/*.cpp` |
| `tools/` | 12 | `format2google`、`pre-commit`、`commit_template` 等开发工具脚本 |
| `custom_ops/` | 10 | 面向非赛题初学者的通用算子开发环境 |
| `samples/` | 10 | 各算子与 CPU 校验的独立测试代码 |
| `thirdparty/` | 2 | 第三方依赖（含编译产物 `libtecoaccuracy.a`） |

例如 `kernel-teco-al-gemm` 页面描述的分块/广播/重排/双缓冲实现，其真实代码在 `artifacts/repos/teco-al/ual/kernel/gemm/`；`kernel-teco-al-add-tensor` 对应 `artifacts/repos/teco-al/ual/kernel/add_tensor/add_tensor_ft16.scpp`。各 part 页正文中提到的具体源码路径均可在该快照下直接打开对应文件核实。
