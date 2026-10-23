# teco-ops-wiki Primer

回答较宽泛的 Teco-Ops / Teco-AL 算子开发问题前，先用这个 topic map 快速定位页面。

## Teco-Ops 项目文档（source-doc-part）

| 主题 | Page ID | 说明 |
|---|---|---|
| 算子提交规范 | `doc-teco-ops-docs-p01` | commit 消息格式、PR 规范（1 PR = 1 算子）、代码风格、cpplint 检查。 |
| 常见问题 | `doc-teco-ops-docs-p02` | proto 参数配置思路、Executor/Parser/MetaTensor 测试框架关系。 |
| 调试手册 | `doc-teco-ops-docs-p03` | printf 日志、TecoGDB、abort/assert、三类精度问题。 |
| 算子开发指南 | `doc-teco-ops-docs-p04` | interface+ual 分层架构、添加新算子九步流程、Proto 参数说明。 |
| Plugin 接口 | `doc-teco-ops-docs-p05` | Teco-Inference / TVM Relay IR 自定义算子注册。 |
| PyTorch 绑定 | `doc-teco-ops-docs-p06` | torch_ext.cpp 绑定步骤、setup.py 构建。 |
| 硬件相关知识 | `doc-teco-ops-docs-p07` | 异构计算、SU/SREG/VPU/VREG/FU/SPM、SPMD、存储与数据传输。 |
| 设计文档模板 | `doc-teco-ops-docs-p08` | 空白算子设计文档模板。 |
| flatten_rays 范例 | `doc-teco-ops-docs-p09` | 填写完整的算子设计文档范例。 |

## Teco-AL 项目文档（source-doc-part）

| 主题 | Page ID | 说明 |
|---|---|---|
| 仓库总览 | `doc-teco-al-docs-p01` | 目录结构、interface+ual 模块介绍、fork+PR 贡献流程、tecotest 测试步骤。 |
| 开发指南 | `doc-teco-al-docs-p02` | 代码风格/结构/逻辑分类，核心概念附录：句柄/张量/存储格式/描述符/工作空间。 |
| 编程规范 | `doc-teco-al-docs-p03` | Google C++ 风格、cpplint、format2google。 |
| 设计文档模板 | `doc-teco-al-docs-p04` | 空白算子设计文档模板。 |
| **AddTensor**（讲解示例） | `doc-teco-al-docs-p05` | elementwise 分块 + 双缓冲，6 级分支真实性能数据。 |
| **Hgemm**（讲解示例） | `doc-teco-al-docs-p06` | 分块 + 广播 + 重排 + 双缓冲，7 级分支真实性能数据。 |
| **ConvolutionForward**（讲解示例） | `doc-teco-al-docs-p07` | conv-to-gemm 等价转换 + 分块 + 广播 + 双缓冲，7 级分支真实性能数据。 |
| 12 个赛题算子参考 | `doc-teco-al-docs-p08` ~ `p19` | activation_forward/backward、arg_max、index_put、logical_not_tensor、masked_fill/select、scale_tensor、scatter_nd_add/out、unary_ops、unique；接口已定稿，性能优化章节留空。 |

## PICT_smoke 项目文档（source-doc-part）

| 主题 | Page ID | 说明 |
|---|---|---|
| SDAA 迁移与训练指南（中文） | `doc-pict-smoke-docs-p01` | 环境安装、数据集获取、raymarching 扩展的 `USE_SDAA=1` 构建、`TORCH_SDAA_AUTOLOAD` 启动训练。 |
| 原始学术项目说明（英文） | `doc-pict-smoke-docs-p02` | SIGGRAPH 2024 原始项目环境搭建、训练/测试命令、引用信息，附与中文版的三点迁移差异对比。 |

## 策展 wiki 页面

| 主题 | Page ID | 适用场景 |
|---|---|---|
| 硬件与编程模型速览 | `hw-teco-ops-hardware-model` | 需要 SPA/SPE/SU/SREG/VPU/VREG/FU/SPM 速查表和 SPMD 切分公式时。 |
| interface+ual 分层开发 | `technique-teco-ops-interface-ual-layering` | 需要新增算子的完整九步流程与调用链路时。 |
| PyTorch 扩展绑定 | `technique-teco-ops-python-torch-binding` | 需要让算子可被 `import tecoops` 直接调用时。 |
| Plugin/TVM Relay 注册 | `technique-teco-ops-plugin-relay-registration` | 算子需要在 Teco-Inference 推理管线中使用时。 |
| 精度问题三类模式 | `pattern-teco-ops-precision-pitfalls` | 算子结果有偏差但不 crash，怀疑 half 截断/整型溢出/超越函数下溢时。 |
| flatten_rays 范例解析 | `kernel-teco-ops-flatten-rays` | 需要一个完整的 tiling + 三种暴露方式的参考实现时。 |
| Teco-AL 分支递进式性能优化方法论 | `technique-teco-al-algo-branch-benchmarking` | 需要"从单线程到双缓冲"的通用优化路线模板与真实性能对照表时。 |
| Hgemm 分块+广播+重排+双缓冲 | `kernel-teco-al-gemm` | 需要 GEMM 优化案例，含分块/广播/重排设计与 7 级分支真实性能数据时。 |
| ConvolutionForward conv2gemm | `kernel-teco-al-conv-forward` | 需要 1x1 卷积转矩阵乘的等价转换与真实性能数据时。 |
| AddTensor 分块+双缓冲入门案例 | `kernel-teco-al-add-tensor` | 需要理解"分块+双缓冲"最简骨架、不涉及矩阵乘/广播复杂度时。 |
| PICT_smoke 模型级 CUDA→SDAA 自动迁移模式 | `technique-pict-smoke-cuda-sdaa-model-migration` | 需要把一个现成的 PyTorch+CUDA 扩展模型（而非单个算子）迁移到 SDAA 时，了解 `TORCH_SDAA_AUTOLOAD`/`USE_SDAA` 两个接入点。 |

## 官方手册（完整结构化）

每份手册有索引页 `doc-*`（章节目录 + 分卷表 + 原文链接），完整正文在分卷页 `doc-*-p*` / `doc-*-g*`（`source-doc-part`），原文逐行存于 `sources/docs/raw/`。

| 主题 | 索引 Page ID | 用途 |
|---|---|---|
| SDAA C 语言/全部设备端 API | `doc-sdaa-c-programming-guide-v3-1-0` | 671 页权威指南：编程模型、语言规范、DMA/RMA/Broadcast/原子/matmul/transpose/SIMD 全部接口、编译调试、算子开发。 |
| 性能优化（SDAA C 篇） | `doc-perf-optimization-sdaa-c-v2-0-2` | 性能指标/采样、程序/线程/指令级并行、DMA/RMA/Broadcast 优化。 |
| 性能优化（算子篇） | `doc-perf-optimization-operator-v1-1-0` | 算子级优化方法论与案例。 |
| 入门 | `doc-sdaa-c-getting-started-v1-1-0` | 零基础教程。 |
| TecoLIBRT 用户手册 v1.2.0 | `doc-tecolibrt-user-manual-v1-2-0` | Runtime 层：SPM、ACE/matmul/sync、RMA/broadcast、DMA、reduce/check/print 等 7 卷完整接口。 |
| TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0` | TecoPyTorch 安装、环境变量、模型迁移、自定义 SDAA C 算子接入、AMP/DDP 训练、Compiler、精度/性能调测、API 参考和 FAQ。 |

## 常见问题快速路由

| 我想... | 先查 |
|---|---|
| 给 Teco-Ops 添加一个新算子 | `technique-teco-ops-interface-ual-layering` → `doc-teco-ops-docs-p04` |
| 给 Teco-AL 添加/优化一个算子 | `doc-teco-al-docs-p02`（开发指南）→ `technique-teco-al-algo-branch-benchmarking`（优化路线模板） |
| 写算子设计文档 | `kernel-teco-ops-flatten-rays` / `kernel-teco-al-gemm`（完整范例）+ 对应 `doc_template` 页 |
| 让算子能被 PyTorch 直接调用 | `technique-teco-ops-python-torch-binding` |
| 让算子能在推理引擎里跑 | `technique-teco-ops-plugin-relay-registration` |
| 排查结果偏差但不崩溃的 bug | `pattern-teco-ops-precision-pitfalls` |
| 补充测试用例的 proto 参数 | `doc-teco-ops-docs-p02` |
| 提交 PR 前自查 | `doc-teco-ops-docs-p01` / `doc-teco-al-docs-p01` |
| 理解 SPA/SPE/SPMD 基础概念 | `hw-teco-ops-hardware-model` |
| 需要一条 GEMM/卷积从慢到快的完整优化路线参考 | `technique-teco-al-algo-branch-benchmarking` → `kernel-teco-al-gemm` / `kernel-teco-al-conv-forward` |
| 把一个现成 PyTorch 模型（含自定义 CUDA 扩展）迁移到 SDAA | `technique-pict-smoke-cuda-sdaa-model-migration` |
| 查 TecoPyTorch 的安装、torch.sdaa API、AMP/DDP 或 FAQ | `doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0` |
