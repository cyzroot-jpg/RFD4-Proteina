# Pattern: 下一轮 QK 抢占当前轮 SV 导致流水退化

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

Sparse Attention 的 QK 和 SV 共用单个 ACE 时，即使第三份 KV buffer 已让下一轮 K 提前就绪，把
`QK[n+1]` 移到 `SV[n]` 前执行仍可能显著退化。producer ready 只消除了 DMA wait，并没有消除
QK 与 SV 的 ACE 资源冲突。

## 适用场景

- 单个执行实体上的 QK 与 SV 共用同一 ACE 或矩阵计算单元。
- 流水顺序包含 `QK -> softmax -> SV`，softmax 使用独立 SIMD/EBOX。
- 候选方案希望用 `softmax[n]` 掩盖 `QK[n+1]`。
- 当前轮 `SV[n]` 是必须完成的关键消费者，下一轮 QK 只是 lookahead 工作。
- 已有双缓冲或三缓冲可以让下一轮 KV 在需要时 ready。

## 不适用场景

- QK 与 SV 使用真正独立、可并发的矩阵计算单元。
- 实测 softmax 工作能够完全覆盖 QK，并且提前 QK 不会推迟当前 SV。
- 当前轮 SV 不是关键路径，或者算法允许改变 QK/SV 的资源优先级。
- benchmark 已证明目标 shape 上 early-QK 更快。

## 核心思路

下一轮 producer ready 不等于下一轮 consumer 应立即执行；共享单 ACE 时，当前轮 SV 通常应保持优先级，
下一轮 QK 只适合放在当前 SV 的 writeback/accumulate drain 窗口。

## 实现规则

- 分开判断两件事：`KV[n+1]` 是否 ready，以及 `QK[n+1]` 是否应该现在占用 ACE。
- 三缓冲可以让 KV gather 提前，但不要因此默认把 QK 移到当前 SV 前。
- 优先保持以下调度：
  - tile 入口发射下一 KV DMA；
  - 当前 QK 完成后执行 softmax；
  - 当前 SV 保持 ACE 优先级；
  - 最后一份 SV writeback 发出后，用最后一次 SIMD accumulate 覆盖下一 QK。
- early-QK attempt 必须包含三种对照：基线、buffer-only、buffer + early-QK。
- buffer-only 接近基线而完整组合退化时，应归因于 ACE 优先级或 recurrence，而不是 LDM 容量。
- 性能退化后恢复已验证最快的调度，不保留仅用于证明 ownership 正确的三缓冲复杂度。

## 关键参数与资源预算

- 已验证 KV tile：`32 x 512 x fp16 = 32 KiB`。
- 第三份 KV buffer 增加 32 KiB LDM。
- `q_head=16` 时，可在 Q 转置完成后把约 16 KiB 的死亡 `ldm_q` 区复用为两份 SV transpose buffer。
- LDM alias 只能解决容量，不会增加 ACE 并发能力。

## 架构与数据流

基线：

```text
DMA KV[n+1] ────────────────┐
QK[n] -> softmax[n] -> SV[n] -> QK[n+1]
                       SIMD accumulate 覆盖 QK[n+1]
```

退化候选：

```text
KV[n+1] ready
QK[n] -> QK[n+1] -> SV[n]
          | softmax[n] |

QK[n+1] 与 softmax[n]只能部分重叠，并串行推迟了 SV[n]。
```

## 从朴素实现到优化实现

- 候选想法：三缓冲先让 `KV[n+1]` ready，再用 softmax 覆盖 `QK[n+1]`。
- 实测结果：DMA wait 不再是主要问题，但下一 QK 抢占当前 SV 的 ACE，整体 recurrence 变长。
- 推荐实现：保留当前 SV 优先级，在最后 SV drain 才启动下一 QK。

## 选型决策

- 发现下一 KV DMA wait 暴露时，可以先测第三 buffer 的 buffer-only 版本。
- buffer-only 没有稳定收益时，不要继续扩大三缓冲代码复杂度。
- 完整 early-QK 只有在硬件计数或 benchmark 证明 QK 被 SIMD 完全覆盖时才能保留。
- 如果未来存在独立 ACE、跨 SPE producer/consumer 或更长的独立 SIMD 阶段，应重新验证，不能直接套用本反例。

## 伪代码

```cpp
wait_current_qk();
softmax_current();
issue_sv_current();

issue_last_sv_writeback();
if (has_next_qk) {
    wait_next_kv_ready();
    issue_next_qk();
}
accumulate_last_sv_chunk();
```

## 常见坑

- 只确认下一 KV ready，就认为 early-QK 一定能与 softmax并行受益。
- 画流水图时把共享 ACE 的 QK 和 SV画成可并行阶段。
- 只跑完整组合，不做 triple-buffer tail-QK 消融，导致把退化错误归因于 LDM bank。
- 因为精度通过就保留三缓冲；性能尝试仍必须以目标 shape benchmark 为门禁。
- 物理合并循环后忽略 ACE 任务优先级，误以为越早发射下一轮工作越好。

## 自检清单

- QK 与 SV 是否共享同一 ACE？
- early-QK 是否会推迟当前 SV 的首次 ACE issue？
- softmax 的持续时间是否足以覆盖完整 QK 与 writeback？
- 是否分别测试了 buffer-only 和完整组合？
- 恢复版本是否重新编译并通过 valid/invalid 精度与性能复测？

## 验证

- 目标算子：`flash_mla_sparse_fused_slice`。
- 失败 stage：`v14_triple_kv_early_qk_preload`。
- Shape：`q_seq=8192`，`q_head=16/8/4`，`topk=512`，`qk_dim=v_dim=512`。
- 基线：`32.036/25.694/24.504 ms`。
- 三KV + early-QK：`36.764/27.820/25.320 ms`，回退 `14.76%/8.28%/3.33%`。
- 三KV + tail-QK 消融：`32.007/25.643/24.494 ms`，仅噪声级变化。
- 完整组合 valid smoke 2/2、invalid smoke 1/1、8192精度3/3通过；主实现最终回退。
- evidence: pipeline-v14-next-qk-before-current-sv
- 正向对照：`v13_start_next_qk_before_sv_drain`只在最后 SV drain 启动下一 QK，64k q_head=16
  从287.721 ms降到286.498 ms。
- evidence: pipeline-v13-next-qk-in-sv-drain

## 来源沿革

- 原始失败 stage 已蒸馏到 evidence `pipeline-v14-next-qk-before-current-sv`。
- 正向调度对照已蒸馏到 evidence `pipeline-v13-next-qk-in-sv-drain`。
- 本结论与同算子历史 early-QK attempt 的回退方向一致，本次额外排除了 producer 未 ready 和 LDM容量因素。

## 相关模式

- `pipeline/ace-writeback-simd-update-overlap`
- `dma/pair-stride-gather`
- `ldm/`
- `pipeline/`
