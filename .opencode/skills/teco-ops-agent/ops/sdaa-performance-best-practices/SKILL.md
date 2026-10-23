---
name: sdaa-performance-best-practices
description: SDAA/Teco T1 算子性能优化最佳实践总入口。按机制层与算子族路由已验证经验、架构方法论、LIBRT/TecoKERNEL/SATE API 规则和验证工具；用于查询或实施 DMA/RMA/ACE/SIMD/LDM/SATE/pipeline/GEMM/attention/softmax 等优化经验、整理性能优化方案、选择后续 attempt 方向。
---

# SDAA 性能优化最佳实践入口

本 skill 是性能优化知识的路由层，不重复维护 API 手册、架构手册或长期 pattern 正文。

核心原则：

- 先查已验证经验，再做新假设。
- 机制层优先：先按 `dma/rma/ace/simd/ldm/workspace/pipeline` 定位，再按 `gemm/attention/softmax` 等算子族组合。
- 未验证思路只能作为候选 attempt，不能直接写成长期最佳实践。
- 需要改代码或沉淀经验时，切到 `sdaa-op-learning-validation` 的 attempt 流程。

## 查询流程

1. 识别用户问题属于哪类：机制优化、算子族优化、API 用法、架构建模、实现验证。
2. 先检索长期经验库：

```bash
rg -n "<op_family>|<mechanism>|<api>|<dtype>|<shape>|<layout>" \
  ops/sdaa-op-learning-validation/references/learned-patterns
```

3. 按命中内容读取对应 pattern；优先采用 `verified_by_stage` 和 `promoted`，谨慎使用 `draft_from_source`。
4. 如果长期库没有命中，再按下面的路由读取对应 skill 或 reference。
5. 如果要实施优化，必须把目标、允许改动、禁止改动、验证 shape、验收标准落到学习/验证任务中。

## 机制层路由

| 问题类型 | 优先读取 | 说明 |
|---------|---------|------|
| 算子设计、分块、分核、双缓冲、LDM 预算、流水图 | `../sdaa-op-design/SKILL.md` | 写设计文档或判断方案是否物理一致 |
| 学习参考实现、做单点/组合 attempt、沉淀 pattern | `../sdaa-op-learning-validation/SKILL.md` | 所有代码优化验证与长期经验写入都走这里 |

## 领域层路由

| 算子族 / 场景 | 先查关键词 | 典型关注点 |
|--------------|-----------|-----------|
| GEMM / MatMul / GEMMEX | 先读 `../sdaa-op-learning-validation/references/learned-patterns/gemm/README.md`，再查 `gemm ace splitK rma C reduce A reuse B ring` | ACE tile、A/B 搬运、C reduce、workspace、RMA ring、双缓冲 |
| Attention / MLA | 先读 `../sdaa-op-learning-validation/references/learned-patterns/attention/README.md`，再查 `attention softmax QK SV BV online pipeline ace writeback` | QK/SV ACE、online softmax、updateO、有效行转置、QK/SV/访存/SIMD 流水 |
| Sparse Attention / Sparse MLA | 先读 `../sdaa-op-learning-validation/references/learned-patterns/sparse-attention/README.md`，并继承 Attention 路由 | topk/indices gather、invalid、partial state merge、稀疏流水 |
| SATE 算子 | `sate layout tensor gemm_write DoubleBuffer lmem copy_stride` | SATE layout、LDM record/replay、SATE gemm、裸 rt 混用边界、pipeline YAML 验证 |
| Softmax / Reduction / Norm | `softmax reduce simd online max sum update` | 状态常驻、分段 online softmax、规约树、SIMD 双发射 |
| Elementwise / Epilogue | `simd epilogue cast activation store` | 融合计算、减少 LDM 读写、tail、P0/P1 交错 |
| 数据搬运密集算子 | `dma ldm stride packed gather double buffer` | stride/packed 选择、双缓冲、LDM 常驻、bank 压力 |

如果领域层没有已验证组合 pattern，不要新建领域结论；先把经验归入机制层，等组合方案验证稳定后再提升为领域层。

## 实施优化时的边界

当用户要求“继续优化”“尝试某个方向”“参考某 kernel 写法”时：

1. 用本 skill 先完成经验检索和路由。
2. 用 `sdaa-op-learning-validation` 记录本轮 attempt：
   - `goal`
   - `reference`
   - `allowed_changes`
   - `forbidden_changes`
   - `verify_shapes`
   - `acceptance`
3. 默认优先 isolated；若多个机制存在明确 producer/consumer、ownership、资源或 wait 窗口依赖，可以建立 combination attempt，并写清 components、dependencies、comparison matrix 和 ablation。
4. 不能因为单点无收益就删除候选；应标记为 `neutral_enabler`、`negative_alone` 或 `positive_in_bundle`，判断是否需要组合后才显现收益。

## 与长期知识库的关系

长期知识库位于：

```text
ops/sdaa-op-learning-validation/references/learned-patterns/
```

写入规则：

- 成功经验必须有验证证据，状态为 `verified_by_stage` 或 `promoted`。
- 失败、回退、无收益但有排坑价值的经验进入 `pitfalls/`。
- 文档标题和正文必须使用中文；技术标识、路径、函数名、命令可以保留英文。
- 写入后运行：

```bash
python3 ops/sdaa-op-learning-validation/scripts/validate_learned_patterns.py
```
