---
id: local-learned-pattern-root-readme
title: Learned Patterns
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/README.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/README.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- index
confidence: source-reported
captured_at: '2026-08-04'
---

# Learned Patterns

这里存放带可移植验证证据的算子实现经验。它不是 API 手册、源码摘抄或原始实验日志。

## 分类

```text
dma/          HBM-LDM 访存模式：packed load、stride load/store、C writeback、workspace read/write
rma/          核间通信模式：row/col ring、relay、reduce-scatter、reply/wait
ace/          ACE GEMM 主循环、north/west layout、writeback buffer
simd/         SIMD reduce、epilogue、cast/activation、P0/P1 交错
ldm/          LDM buffer 规划、ownership、bank pressure、ping/pong/triple buffer
workspace/   split-K partial C、packed workspace layout
pipeline/    fill/steady/drain、stage overlap、wait/sync placement
gemm/README.md               GEMM / GEMMEX / MatMul 领域路由索引
gemm/*.md                    GEMM 领域组合模式：M/N/K 分块分核、split-K、固定 A 扫 N、完整数据流
attention/README.md         Attention / MLA 领域路由索引，不复制机制 pattern 正文
sparse-attention/README.md  Sparse Attention / Sparse MLA 增量路由索引
pitfalls/     跨 pattern 的常见坑和排查规则
```

`gemm/` 是领域组合层，不重复 `dma/rma/ace` 的接口细节；它引用机制层 pattern，说明这些机制如何组合成 GEMM 方案。

### 分类规则

长期库采用“机制层优先，领域层承载组合”的分类方式。

- 优先放入机制层：`dma/`、`rma/`、`ace/`、`simd/`、`ldm/`、`workspace/`、`pipeline/`。如果经验本质是在讲某个硬件机制、buffer ownership、wait 点或局部 microkernel，就不要新建领域目录。
- 只有当一个经验需要多个机制组合，并且已在某个算子族上验证为稳定方案时，才放入领域层，例如 `gemm/`。
- `pitfalls/` 只放失败、回退、反例和排查规则；正确但性能无提升的尝试也应优先进入 `pitfalls/` 或过程记录。
- 不使用笼统的 `common/` 目录。通用经验按本质放到 `dma/ldm/pipeline/simd/pitfalls` 等机制层。
- 允许建立 `attention/README.md`、`sparse-attention/README.md` 这类领域路由索引，用于把算子族信号映射到机制 pattern；索引不保存重复正文，也不作为独立验证结论。
- 暂不默认把 attention 经验正文放入 `attention/` 或 `sparse-attention/`。正文仍优先进入 `simd/`、`pipeline/`、`dma/`；等多个机制形成已验证稳定组合后，再新增领域 composite pattern。
- `domain-routes.json` 是 UserPromptSubmit Preflight 的机器可读路由表；领域 README 与其中的 index/pattern 映射必须同步维护。

### 新增算子族路由

算子族到机制 pattern 的映射需要判断语义、shape 和 evidence 适用范围，因此当前采用**人工登记、自动消费**，不自动生成路由内容。新增 convolution、normalization、MoE 等算子族时：

1. 新建 `<family>/README.md`，列出触发信号、开发前检查顺序、领域边界和对应机制 pattern。
2. 在 `domain-routes.json` 增加 route：至少填写 `label`、`index`、`triggers` 和 `patterns`；需要复用公共领域时填写 `inherits`。
3. 不需要修改 `new_op_preflight.py`。脚本会自动识别“任意 domain route + 优化/实现/开发/修改等代码动作词”。
4. 同步更新 `sdaa-performance-best-practices/SKILL.md` 的领域层路由表，保证人工查询与 hook 一致。
5. 运行 `validate_learned_patterns.py`，再用一条不含“算子/kernel”的代码请求验证自动触发，例如“继续优化 gemm”或“implement matmul”。同时验证“测试 matmul”“benchmark gemm”等纯测试请求不触发本 Preflight。

禁止只按目录名自动收集全部 pattern：领域索引必须排除虽然关键词相似、但 shape、dtype、资源或数据流不适用的经验。

纯测试请求不需要先消费实现 pattern 和 code-style，应交给 `kernel-bench`。如果请求同时明确要求“测试并优化/修改实现”，其中的优化或修改动作仍会触发本 Preflight。

## 文件要求

每个 pattern 文件必须包含：

- 状态
- 类型
- 问题
- 适用场景
- 不适用场景
- 核心思路
- 实现规则
- 伪代码
- 常见坑
- 验证
- 来源沿革
- 相关模式

可选但推荐的章节：

- 优化目标：说明该 pattern 期望改善的瓶颈和指标。
- 架构与数据流：用简图或文字写清 GM/HBM、LDM、RMA、ACE、SIMD 等阶段如何流动。
- 关键参数与资源预算：写明 tile、buffer 数量、LDM/workspace 占用、对齐约束。
- 从朴素实现到优化实现：对比 naive 与 optimized 的数据流、wait 点或循环结构。
- 选型决策：说明什么场景优先用、什么场景要降级或换方案。
- 自检清单：给实现者提交前逐项检查 ownership、reply/wait、tail、精度和 benchmark。

模板见：

```text
ops/sdaa-op-learning-validation/references/experience-template.md
ops/sdaa-op-learning-validation/references/knowledge-lifecycle.md
```

## 中文要求

- 长期知识库面向团队复用，章节标题和正文必须使用中文。
- 技术标识、路径、函数名、命令、dtype、shape、status 值可以保留英文或代码原文。
- `validate_learned_patterns.py` 会阻断英文旧标题，以及正文中的明显英文长句。
- Codex Stop hook `ops/sdaa-op-learning-validation/scripts/hooks/learned_patterns_guard.py` 会在修改长期 pattern 时自动运行该 validator。

## 类型与门禁

- `correctness_contract`：正确性、API、layout、ownership 或同步必须条件；不强制性能提升。
- `optimization`：性能优化；必须有同条件 baseline/after 和明确指标单位。
- `composite`：多个强依赖机制形成的组合方案；必须写 components、dependencies 和关键消融。
- `pitfall`：失败、回退、无收益或不兼容经验。

状态规则：

- `draft_from_source`、`human_reviewed` 只能留在 `<demo_root>/op_learning/`。
- `verified_by_stage` 至少有一个明确验证范围的仓库内 evidence。
- `promoted` 至少有两个独立算子、版本或实现上下文的 evidence。
- `needs_revalidation` 在环境变化或证据不完整时使用，禁止作为默认候选。
- `superseded` 表示被新 pattern 替代；必须写 `superseded_by`。
- `deprecated` 表示规则失效。
- `verified_by_failed_stage` 只允许放在 `pitfalls/`。

## 长期库写入门禁

`learned-patterns/` 是长期可消费知识库，不存放未验证候选。候选、source notes 和人工假设只能写入：

```text
<demo_root>/op_learning/<topic>/learned_patterns.md
```

`<demo_root>` 取决于 backend，详见
[backends/](../backends/README.md)。

长期 pattern 的硬条件：

- 必须引用 `references/evidence/pattern-evidence.json` 中存在的 evidence ID。
- pattern 和 evidence 都禁止作者机器绝对路径。
- `correctness_contract` evidence 要求正确性和交付/流水线通过。
- `optimization` evidence 还要求 before/after 使用同一 metric 与 unit，且性能提升。
- `composite` 还要记录组件依赖、comparison matrix 或关键 ablation。
- 原始 `<demo_root>/op_learning/**/stage_results/*.json` 只作为来源记录，可归档或删除，不是长期库运行依赖。

失败或回退经验只能放在 `pitfalls/`，状态使用 `verified_by_failed_stage` 或 `deprecated`，并引用仓库内失败 evidence。正确但性能无提升的实现可以作为 `neutral_enabler` 留在组合过程记录；只有证明其是组合必要组件后，才进入 composite pattern。

## 路径与保留策略

- 原始源码引用使用 `repo + commit + relative_path + symbol`，不得写 `/data/...` 或 `/home/...`。
- `verified_by_stage` 生成 evidence snapshot 后，原始长日志可归档。
- `promoted` 后可删除原始源码位置和过程文档引用，只保留 evidence、验证范围和来源版本。
- 删除最小 evidence 后必须降级为 `needs_revalidation`，不能继续声明 `verified_by_stage/promoted`。

## 与设计手册的边界

AscendC performance reference 这类资料更像“优化设计手册”：常见结构包括优化目标、架构概览、关键参数、naive/optimized 对照、注意事项、FAQ、选型决策和自检清单。SDAA `learned-patterns/` 的定位不同：它是**带验证证据的长期经验库**。

因此：

- 可以吸收设计手册的表达方式，尤其是数据流、参数预算、naive/optimized 对照和自检清单。
- 不能把未验证的设计假设直接写成 `verified_by_stage` pattern。
- 大篇幅 API 手册、完整源码、未验证候选仍应留在对应 skill reference、设计文档或 `<demo_root>/op_learning/<topic>/learned_patterns.md`。
- 长期 pattern 应保持可执行、可排坑、可复用，而不是只描述“理论上可以优化”。

提交或停止前运行：

```bash
python3 ops/sdaa-op-learning-validation/scripts/validate_stage_result.py \
  <demo_root>/op_learning/<topic>/stage_results/<stage>.json --json
python3 ops/sdaa-op-learning-validation/scripts/snapshot_pattern_evidence.py \
  --stage-result <stage-result.json> --evidence-id <id> \
  --source-stage backend://<backend>/op_learning/<topic>/stage_results/<stage>.json
python3 ops/sdaa-op-learning-validation/scripts/validate_learned_patterns.py
```

验证器只依赖仓库内 `pattern-evidence.json` 和 pattern 中的 evidence ID，不需要访问作者机器上的
backend 仓库。backend 的过程层路径约定详见 [backends/](../backends/README.md)。
