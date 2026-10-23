---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-pattern-extraction-checklist-4e1ea25f
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/pattern-extraction-checklist.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/pattern-extraction-checklist.md
relative_source_path: sdaa-op-learning-validation/references/pattern-extraction-checklist.md
captured_at: 2026-08-04
---

# 模式抽取清单

抽取模式时回答这些问题，不能只列 API 名。

## 人工引导抽取边界

如果用户在会话中指定了本轮优化方向，抽取范围必须收窄到该方向。不要顺手总结整个算子。

必须先记录：

- 本轮 pattern 名称，例如 `rma/row-ring-b-panel`。
- 参考代码位置，精确到文件和函数/行附近。
- 本轮只允许迁移的规则。
- 本轮禁止迁移的样本细节。
- 验证状态：初始必须是 `draft_from_source`。

示例：

```text
本轮只学习 B row-ring：
- 可以抽取 dst core 公式、ping/pong buffer ownership、reply/wait 顺序。
- 不抽取 C reduce、workspace、ACE loop 切段、完整 pipeline。
```

## 分类归档

长期经验按主题归档，不按源码文件归档：

- `dma/`：packed load、stride load/store、C writeback、workspace read/write。
- `rma/`：row/col ring、relay、reduce-scatter、reply/wait ping-pong。
- `ace/`：fp16/fp32 mainloop、north/west layout、writeback。
- `simd/`：reduce、epilogue、cast/activation、P0/P1 交错。
- `ldm/`：buffer planning、ownership、bank pressure、ping/pong/triple buffer。
- `workspace/`：split-K partial C、packed workspace layout。
- `pipeline/`：fill/steady/drain、stage overlap、wait/sync placement。
- `gemm/`：M/N/K 分块分核、split-K、固定 A 扫 N、组合数据流。

## DMA / RMA staging

- 哪些 buffer 是 producer，哪些是 consumer？
- `iget/iput/rma_iput/rma_iget` 在哪一轮发起？
- wait 点卡住的是哪个消费者？有没有提前 wait 阻塞独立 stage？
- reply 是否 `volatile`，是否在复用前清零？
- RMA 远端 reply 是否使用 `__rt_remote_rply`，是否避免栈变量？
- DMA/RMA 上行、下行是否与同轮其它流量冲突？

## ACE 主循环

- `rt_ace_config_kernel` 在哪里做？
- north 数据在 LDM 中是否连续 32x32？
- west `Loadstride` 是否按 rt 口径使用 `K / 32 - 1`？
- `Accumflag`、`Lastflag`、`Northflag` 如何随 K 循环变化？
- `rt_ace_writeback` 的 `Ysize` 是否是行数，不是字节？
- `Precisionflag=1` 时 C LDM 是否按 `rows * 32 * sizeof(float)` 分配？
- 是否禁止生成 `ACE_PREC`？

## SIMD / EBOX

- SIMD 是主计算，还是 epilogue/cast/scale/reduce/pack？
- P0 compute 与 P1 load/store 是否交错？
- 是否有 8x 展开或等效软件流水？
- SIMD 读写的 LDM bank 是否避开 ACE/DMA 热点？
- SIMD 能否和 ACE 当前 tile 并行，还是依赖 ACE writeback 后才能开始？

## Pipeline

- fill、steady、drain 各有哪些 stage？
- steady state 主导阶段是谁：DMA GET、DMA PUT、RMA、ACE、SIMD、sync？
- 双缓冲覆盖哪些资源：DMA、RMA、SIMD、ACE？
- 拆小 tile 是为了制造 overlap，还是导致 wait/sync/issue delay 暴露？
- 如果不双缓冲，为什么不值得？

## Runtime parameters

仅在 target 分支已经确认并读完命中实现后确定 runtime probe 参数清单。不要在真实分支未知时
预设打印项，也不要把其它分支的参数混入当前学习结论。

- 哪些参数是 host wrapper 运行时选择的？例如 tile、pad、workspace size、dispatch 分支和 reject/accept 条件。
- 哪些参数是 device kernel 入口收到的？例如 shape、stride、alpha/beta、alignment、workspace 指针、tile 参数。
- 哪些参数是 kernel 内派生的？例如 `M2/N2/K2`、block 数、loop 数、ACE loop 切段、buffer/sub-buffer size。
- 哪些路径是运行时条件选择的？例如首个 K panel 读 C 还是 beta 初始化，中间 panel 写 workspace 还是最后 panel 写 C。
- 打印证据是否覆盖 target shape？如果只来自 smoke/mid，只能说明局部路径。
- 打印是否受单 SPE、首轮/末轮、宏或环境变量控制，验证后是否移除或默认关闭？

## 可迁移性判断

标记每条模式的迁移等级：

- `required`：生成同类算子必须遵守。
- `shape-dependent`：只在特定 M/N/K 或 dtype 下成立。
- `optimization`：正确性不依赖，但影响性能。
- `do-not-copy`：样本细节，不能迁移。

同时标记验证状态：

- `draft_from_source`
- `human_reviewed`
- `verified_by_stage`
- `promoted`
- `needs_revalidation`
- `superseded`
- `deprecated`

只有 `verified_by_stage` 或 `promoted` 可以作为默认实现规则；其它状态只能作为候选假设。

## 输出要求

每个 pattern 草稿至少包含：

- 状态
- 类型
- 问题
- 适用场景
- 不适用场景
- 实现规则
- 伪代码
- 常见坑
- 验证
- 来源沿革
- 相关模式
