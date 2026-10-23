---
id: local-learned-pattern-pipeline-ace-writeback-simd-update-overlap
title: ACE 写回与 SIMD 更新重叠
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/pipeline/ace-writeback-simd-update-overlap.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/pipeline/ace-writeback-simd-update-overlap.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- pipeline
- ace
- writeback
- simd
- update
- overlap
- optimization
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: optimization
---

# Pattern: ACE 写回与 SIMD 更新重叠

## 状态

verified_by_stage

## 类型

optimization

## 问题

ACE 写回是异步的，但很多 kernel 在 `rt_ace_writeback` 后马上等待，然后才做 SIMD 后处理。这样会把 `ACE 计算/写回 -> SIMD 更新` 串成一条同步链。只要 SIMD 更新消费的是上一份写回 buffer，就应该把它塞进下一份 ACE/writeback 的等待窗口里。

## 适用场景

- ACE 输出可以按独立 chunk 处理，例如 attention 的 `P @ V` head-dim chunk，或 GEMM epilogue chunk。
- 输出更新是针对上一份 ACE 写回 buffer 的 SIMD 工作。
- LDM 或栈上 LDM 分配能放下两份写回 buffer。
- 下一份 ACE chunk 使用的 transpose/permute 输入 buffer 不会被提前覆盖；要么也做 ping-pong，要么能证明 ACE 已经消费完。
- chunk 粒度仍然足够大，不能为了制造 overlap 把 ACE 任务切得太小。本次验证的 sparse MLA 使用 full `q_per_kv` rows 和 128-column chunk。
- writeback 发出后存在独立的 tile 级检查、下一阶段 producer 启动或上一 buffer 的 SIMD 消费工作。

## 不适用场景

- writeback issue 和 wait 之间没有可放进去的独立 SIMD 工作。
- 下一份 ACE chunk 会覆盖还在被 in-flight ACE 使用的输入 transpose buffer。
- 为了制造更多 chunk 而切 ACE 的 M/head 维度；本次 sparse MLA 验证里，按 head-row 切 SV 曾经退化。
- reply slot 或 buffer 在 delayed wait 前会被其他阶段复用。
- fill/steady/drain 的 buffer ownership 没有写清楚。

## 核心思路

对 ACE 输出 buffer 做 ping-pong，在第一次消费上一份输出时才 wait，这样 chunk N 的 SIMD update 可以覆盖 chunk N+1 的 ACE/writeback。

## 实现规则

- 分配两份 ACE 输出 buffer，例如 `c_ace[2]`。
- 如果下一份 ACE chunk 需要 transformed input buffer，也要分配两份 transform buffer，或者明确证明单 buffer 不会被 in-flight ACE 再读。
- 每份 ACE 输出 buffer 绑定一个独立的 `volatile int` reply。
- steady-state 顺序：
  - 准备/permute 下一份输入到 `input_buf[tag]`；
  - 对下一份 chunk issue ACE load；
  - 设置 `reply[tag] = 0`；
  - issue `rt_ace_writeback(c_ace[tag], ..., &reply[tag], precision_flag)`；
  - 只有在 SIMD 即将读取上一份 `c_ace[tag ^ 1]` 时才 wait；
  - 对上一份 chunk 做 SIMD update；
  - 翻转 `tag`。
- 循环结束后 drain 最后一份 in-flight `c_ace`。
- 不要把无关 DMA wait 提前，除非它能解锁真实计算。单纯提前 wait 可能减少原本自然存在的 overlap。
- tile 级 invalid-index 预检查可放在 QK writeback issue 与 wait 之间；检查应只做一次，不能移入每个 head 的 softmax load。
- 下一 tile QK 只能在当前 tile 最后一份 SV writeback 已经发出后介入，再用当前最后一份 SIMD accumulate 覆盖；
  不要把下一 QK 前移到当前 SV ACE body 之前。

## 伪代码

```cpp
int tag = 0;

for (int chunk = 0; chunk < chunks; ++chunk) {
    prepare_next_input(input_buf[tag], chunk);

    wait_buffer_reusable(reply[tag]);
    issue_ace_for_chunk(input_buf[tag]);
    reply[tag] = 0;
    rt_ace_writeback(c_ace[tag], c_nums, (void *)&reply[tag], precision);

    if (chunk > 0) {
        int prev = tag ^ 1;
        wait_writeback(reply[prev]);
        simd_update_from_ace_out(output, c_ace[prev], chunk - 1);
    }

    tag ^= 1;
}

int last = tag ^ 1;
wait_writeback(reply[last]);
simd_update_from_ace_out(output, c_ace[last], chunks - 1);
```

## 常见坑

- 只延迟 `c_ace` 的 wait，但没有保护下一份 ACE 输入 transpose buffer 的 ownership。
- 加了 ping-pong 输出 buffer，却没有足够的独立 SIMD update 工作，最后只增加 LDM/寄存器压力。
- 拆 ACE 的 M/head 维度来制造更多 chunk，导致小 ACE issue/writeback 开销变大并退化。
- 误以为“把 wait 后移”本身就是优化。收益来自 wait 前插入了真实有用工作。
- 把 tile 级 validity 检查下沉到每个 head，造成同一批 index 重复扫描。
- 下一 QK 虽然 producer ready，却在当前 SV 前抢占共享 ACE，导致 recurrence 变长。

## 验证

- 验证 stage：`v7c_sv_writeback_accumulate_overlap`
- 目标算子：`flash_mla_sparse`
- shape：DS4 sparse MLA prefill，`q_head=16/8/4`，`q_seq=8192/65536`，`topk=512`，`qk_dim=v_dim=512`
- 正确性：smoke 2/2 pass，tile sweep 3/3 pass，8192 all-head accuracy+perf 3/3 pass
- 性能：q_seq=65536 q_head=16 从 `342.650 ms` 降到 `295.557 ms`；q_head=8 从 `271.468 ms` 降到 `239.515 ms`；q_head=4 从 `232.452 ms` 降到 `210.081 ms`
- evidence: pipeline-v7c-ace-writeback-simd-overlap
- 补充 stage：`v12_precheck_invalid_in_qk_writeback_window`，64k q_head=16从288.848 ms降到287.721 ms。
- 补充 stage：`v13_start_next_qk_before_sv_drain`，64k q_head=16从287.721 ms降到286.498 ms。
- evidence: pipeline-v12-invalid-precheck-qk-writeback
- evidence: pipeline-v13-next-qk-in-sv-drain

## 来源沿革

- 参考 sparse MLA 实现的 `sv_ace_half_a` 和 flash decoding 的 `updateO` 模式。
- 原始 stage 已蒸馏到 evidence `pipeline-v7c-ace-writeback-simd-overlap`、
  `pipeline-v12-invalid-precheck-qk-writeback` 和 `pipeline-v13-next-qk-in-sv-drain`。

## 相关模式

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `simd/online-softmax-tile-microkernel`
- `dma/gather-validity-flag-reuse`
- `pitfalls/next-qk-before-current-sv`
- `ace/`
- `ldm/`
