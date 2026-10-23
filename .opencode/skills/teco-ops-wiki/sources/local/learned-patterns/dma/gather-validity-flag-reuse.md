---
id: local-learned-pattern-dma-gather-validity-flag-reuse
title: Gather 有效性标记随 Buffer Ownership 复用
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/dma/gather-validity-flag-reuse.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/dma/gather-validity-flag-reuse.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- dma
- gather
- validity
- flag
- reuse
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: Gather 有效性标记随 Buffer Ownership 复用

## 状态

verified_by_stage

## 类型

optimization

## 问题

indexed gather 在发 DMA 请求时已经逐个检查 index 是否越界。若 consumer 在 score mask 或其他后处理前
再次扫描同一批 index，就会重复执行分支、LDM 读取和边界判断。双缓冲场景还容易把当前 tile 的有效性
标记与错误的 ping/pong 槽关联。

## 适用场景

- gather producer 必须检查每个 index，并能在填充目标 LDM buffer 时累计 `has_invalid`。
- consumer 只需要 tile 级“是否存在无效 index”判断，再按需执行精细 mask。
- KV、embedding、row gather 等数据使用 ping/pong buffer，标记可以与 buffer tag 同生命周期保存。
- 无效 index 的 fallback 已在 producer 中定义，例如目标槽清零。

## 不适用场景

- consumer 需要每个 lane 的完整 validity mask，而 producer 只保留一个布尔值。
- producer 与 consumer 使用不同 index 视图、不同边界或不同 tail 语义。
- buffer 在 consumer 使用标记前已被下一轮 gather 覆盖。
- 上游保证 index 全有效且接口有可信的显式 flag；此时可评估更直接的 specialization。

## 核心思路

把 gather 阶段产生的 tile 级 `has_invalid` 与对应 ping/pong 数据 buffer 绑定，consumer 复用该标记，
避免第二次完整 index 扫描。

## 实现规则

- producer 每次填充 buffer 槽前重置该槽的 validity 标记。
- 每遇到无效、tail 或越界 index，按既定 fallback 填充目标槽并设置 `has_invalid[tag]=true`。
- 标记数组与数据 buffer 使用相同 tag 翻转，wait 完成后 consumer 读取当前消费槽的标记。
- consumer 只有在 `has_invalid[tag]` 为真时执行逐 lane score mask 或其他修正。
- 标记 ownership 在 buffer 释放时结束；下一次复用该槽前必须重置。
- 保持 DMA 请求组织、地址、reply 计数和 wait 点不变，使本 attempt 只验证重复扫描删除。

## 关键参数与资源预算

- 每个 ping/pong 槽只增加一个布尔或小整数标记，不新增大块 LDM。
- 节省一次每 tile 的 index 扫描；收益随 tile 数和 query 数累积。
- 已验证实例每 tile 含 32 个 index，invalid smoke 使用20%无效比例覆盖修正路径。

## 架构与数据流

```text
indices -> gather producer -> KV buffer[tag]
             │                    │
             └-> has_invalid[tag] ┘ 同 ownership
                                  │
                     QK writeback / score consumer
                                  │
                    false: 跳过 mask
                    true : 执行逐 lane 修正
```

## 从朴素实现到优化实现

- 朴素实现：gather 扫描一次 index，consumer 再扫描一次相同 index。
- 优化实现：producer 顺手生成 tile 标记，consumer 只读取标记，必要时进入精细修正。
- 删除的是重复边界判断，不改变 invalid index 的数据与数学语义。

## 选型决策

- 只要 producer 已经不可避免地检查 index，本模式应作为低成本候选。
- 若 consumer 需要完整 mask，可把 mask 与 buffer 绑定，但要单独核算生成和存储成本。
- 多 buffer 或跨 tile lookahead 必须先画清 tag、announce、wait、consume 和 release 的状态机。
- 若 validity 判断能放入 ACE writeback 窗口，可与 pipeline window filling 组合，但要保持归因清楚。

## 伪代码

```cpp
void announce_gather(int tag, int tile) {
    has_invalid[tag] = false;
    for (int lane = 0; lane < TILE_SIZE; ++lane) {
        int index = indices[tile * TILE_SIZE + lane];
        if (!is_valid(index)) {
            clear_slot(buffer[tag], lane);
            has_invalid[tag] = true;
        } else {
            issue_dma(buffer[tag], lane, index, reply[tag]);
        }
    }
}

wait_gather(reply[current]);
if (has_invalid[current]) {
    apply_invalid_mask(current_tile);
}
```

## 常见坑

- 只保存一个全局标记，ping/pong 翻转后把下一 tile 的状态用于当前 tile。
- 无效 index 不发 DMA，但没有清零目标槽，consumer 读到旧数据。
- 标记在异步 gather 完成前被下一次 announce 重置。
- producer 和 consumer 对 tail 的判定范围不同。
- 为删除一次扫描顺手改 DMA batching，导致性能归因失真。

## 自检清单

- validity 标记是否与数据 buffer 使用相同 tag 和生命周期？
- 每次槽复用前是否重置标记？
- invalid、tail、全 valid 三条路径是否都覆盖？
- DMA reply 与 wait 是否完全保持原语义？
- consumer 是否只在标记为真时执行精细修正？

## 验证

- 验证 op/stage：`flash_mla_sparse_fused_slice`，`v6_reuse_dma_invalid_detection`。
- shape：prefill `q_seq=8192/65536`，`q_head=16/8/4`，`topk=512`，
  `qk_dim=v_dim=512`；另含20% invalid-index smoke。
- 正确性：valid smoke、invalid smoke和8192全头精度通过。
- 性能：8192 q_head=16/8/4 从32.437/25.849/24.627 ms 降到
  31.707/25.615/24.551 ms；65536从259.472/208.425/199.219 ms 降到
  253.467/206.903/198.948 ms。
- evidence: dma-v6-reuse-gather-invalid-detection

## 来源沿革

- revision 未记录，首次验证实现。
- 原始 stage 已蒸馏到 evidence `dma-v6-reuse-gather-invalid-detection`。

## 相关模式

- `dma/pair-stride-gather`
- `pipeline/ace-writeback-simd-update-overlap`
- `ldm/`
