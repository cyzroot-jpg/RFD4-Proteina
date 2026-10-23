# Pattern: Online Softmax Partial State 树形合并

## 状态

verified_by_stage

## 类型

composite

## 问题

decode attention 的 query 数很少时，按 query 分核无法占满芯片。若沿 KV 或 topk 维做 split-K，
每个 SPE 只能看到局部 score，不能直接对局部 softmax 输出做普通求和。传统 offline 路径还可能
重复 gather KV，并分别执行 max、sum 和 O 的跨核规约，导致访存与同步链较长。

## 适用场景

- query 任务数少，单个 attention 任务需要沿 KV、topk 或连续 tile 维拆到多个 SPE。
- 每个 split 能独立完成局部 QK、online softmax 和 SV，并保留未归一化 O。
- 每个 split 能导出同一组 head 对应的 `local_max`、`local_sum` 和 `local_O`。
- 核组内可以用 RMA 传递 partial state，并保证 peer buffer 在各 SPE 上具有相同 LDM offset。
- 当前已验证范围为 T1、FP16 输入输出、FP32 max/sum、`q_seq=1`、
  `q_head=16/8/4`、`qk_dim=v_dim=512`。验证点包括`kv_seq=65536,topk=512`，以及
  `kv_seq=2048,topk=128/144/640`。

## 不适用场景

- split 之间不能保持相同 head、输出维度或 accumulator 语义。
- 局部 O 已经除以各自的 local sum，却没有保留可逆的缩放状态。
- 核组通信成本超过重复 gather 和 offline reduce 的成本。
- peer buffer 的远端地址不能由相同 LDM offset 表达。
- query 任务已经足够多，`core_tile=1` 的 query 并行能占满芯片；此时不应引入跨核 merge。
- 当前证据不覆盖 BF16、`topk=2048`、多 KV head 或 64/128-token tile。

## 核心思路

每个 split 只遍历自己的 KV tile，输出未归一化 partial `{max,sum,O}`；树形合并时先取共同 max，
按指数差同时重缩放两侧 sum 和 O，最后仅由 root 执行一次 `O / sum`。

## 实现规则

- 局部阶段初始化 `max=-inf`、`sum=0`、`O=0`，并在本 split 内执行 QK、online softmax 和 SV。
- 局部 O 必须保持未最终归一化；不能先除 local sum 再做普通向量相加。
- 合并状态 A、B 时：
  - `m = max(m_a, m_b)`；
  - `scale_a = sum_a > 0 ? exp(m_a - m) : 0`；
  - `scale_b = sum_b > 0 ? exp(m_b - m) : 0`；
  - `sum = sum_a * scale_a + sum_b * scale_b`；
  - `O = O_a * scale_a + O_b * scale_b`。
- 空 split 使用中性状态，不访问越界 index；它可以保留在同步和树形拓扑中。
- 使用`active_core_num = min(total_tiles, core_tile)`限制实际 RMA participant；inactive SPE仍按相同
  顺序分配 LDM 并参加全阵列同步，但不发送中性 max/sum/O payload。
- 所有 SPE 按相同顺序分配 local 与 peer max、sum、O buffer，保证 RMA 远端地址一致。
- 每轮树形 merge 前清零 `__rt_local_rply` 与 `__rt_remote_rply`，发送方等待 local reply，
  接收方等待 remote reply，轮末执行全阵列同步后再复用 peer buffer。
- 只有任务核组 root 做最终归一化和 HBM 写回；若最终 merge 已把两侧 O 加载到 FP32 SIMD
  寄存器，可把两侧 scale 同时除以 merged sum，在同一轮 FMA/pack 中完成归一化。
- query 并行与 split-K 路径应使用编译期 specialization 隔离，避免 merge helper 扩大 prefill 热函数。

## 关键参数与资源预算

- 每个 SPE 需要 local 与 peer 两份 O，以及 local 与 peer 两份 max/sum 状态。
- 已验证实例的 O 为 `q_head * v_dim * sizeof(half)`；q_head=16、v_dim=512 时每份为 16 KiB。
- 树形轮数为 `ceil(log2(core_tile))`；每轮传输 max、sum 和 O 三类 payload。
- `topk=512`、tile=32 时有16个有效 participant；其余 SPE只保持相同 LDM offset和同步协议。
- `topk=128/144/640`、tile=32时有效 participant分别为4/5/20；最后一个非完整 tile仍需同时
  约束 indices/KV 访问和 softmax score mask。
- tile 变大可减少有效 SPE 数和 RMA participant，但会增加 ACE 行 padding 或单核工作量；必须把
  32/64/128-token tile 与有效 SPE 数一起实测，不能只按“核更多”或“padding 更少”单独判断。

## 架构与数据流

```text
HBM indices/KV
      │
      ├─ SPE 0: gather tile 0  -> QK -> online softmax -> SV -> {m0,s0,O0}
      ├─ SPE 1: gather tile 1  -> QK -> online softmax -> SV -> {m1,s1,O1}
      ├─ ...
      └─ empty: no gather      -> neutral state                {-inf,0,0}

树形 RMA：stride 1 -> 2 -> 4 -> ...
      │
root {m,s,O} -> O/s -> HBM output
```

局部阶段把一次 KV gather 同时供 QK 与 SV 消费；merge 阶段只传 partial state，不再传 KV 或全量 score。

## 从朴素实现到优化实现

- 朴素 decode：第一次 gather 做 QK，跨核规约 max/sum并形成概率，再次 gather 做 SV，最后规约 O。
- 优化 decode：每个 split 单次 gather 后完成局部 QK-softmax-SV，只对 `{max,sum,O}` 做树形 merge。
- 删除的是第二次 KV gather、独立 max/sum 规约链和普通 partial O sum reduce；新增的是 partial state
  指数缩放和树形 RMA。

## 选型决策

- query 数不足且 KV/topk 足够长时，优先评估本模式。
- 先计算 `total_tiles`、`core_tile` 和 `active_core_num`；只让有效 participant 传输 partial state，
  inactive SPE继续满足 LDM offset和barrier协议。
- 若 O 很大导致 peer buffer 超出 LDM，考虑分 chunk merge，但必须保持每个 chunk 使用同一 max/sum。
- 连续 O payload 不要仅为制造 overlap 在 merge epilogue 中拆成多笔 RMA；只有 producer 分块 ready
  或 layout 天然 chunked 时才值得单独验证。
- 若 query 数恢复到可占满芯片，切回 `core_tile=1` 的无 RMA 路径。
- offline 实现必须保留为不支持 shape、dtype 或资源超限时的 fallback。

## 组合依赖与归因

- 组件：split-K 任务映射、active participant、单次 KV gather 的局部 QK-softmax-SV、
  partial max/sum/O 数学合并、同偏移 peer buffer 与树形 RMA、root merge-normalize融合。
- 依赖：split-K 产生局部 softmax 状态，因此数学合并不可省；单次 gather 只有在 QK 与 SV 同 tile
  消费时成立；RMA 只有在 peer buffer offset 与 reply 生命周期一致时正确。
- 对比矩阵：同一 FP16 decode shape 下，offline baseline 的 q_head=16/8/4 为
  67.690/48.600/39.530 us，完整组合为 54.010/37.840/28.940 us。
- active-16 单点把55.190/38.710/30.050 us降到52.120/37.440/29.700 us；最终
  merge-normalize融合进一步降到50.920/36.820/29.320 us。
- 把完整 O payload拆成4笔 RMA 的消融回退0.59%～2.01%，说明请求粒度必须与 producer ready
  时点和自然 layout共同选择。

## 伪代码

```cpp
Partial local = run_local_fused_attention(tile_begin, tile_count);
int active_core_num = min(total_tiles, core_tile);

if (tile_count == 0) {
    local.max = -INFINITY;
    local.sum = 0.0f;
    clear(local.output);
}

for (int stride = 1; stride < active_core_num; stride *= 2) {
    reset_rma_replies();
    sync_array();

    if (is_sender(stride)) {
        rma_put(local.max, peer.max);
        rma_put(local.sum, peer.sum);
        rma_put(local.output, peer.output);
        wait_local_replies(3);
    } else if (is_receiver(stride)) {
        wait_remote_replies(3);
        local = merge_with_common_max(local, peer);
    }

    sync_array();
}

if (is_final_root_merge()) {
    merge_normalize_and_store(local.output, peer.output, local.sum, peer.sum);
}
```

## 常见坑

- 把两个已归一化 partial O 直接相加，或者只合并 sum 而不按共同 max 重缩放 O。
- 空 split 仍读取第一个 index，造成越界访问或把旧 LDM 数据带入 merge。
- 只有发送方分配 peer buffer，导致目标 SPE 上远端 LDM offset 不一致。
- RMA reply 没有逐轮清零，或在上一轮接收完成前复用 peer buffer。
- 为 decode 加 merge helper 后让编译器把它内联进 prefill 热函数，造成无关回退。
- 只看到 16 个非空 tile 就把核组直接改成 16，却忽略全局 slice、同步范围和 task mapping 约束。
- 在完整 O ready 后才把一笔连续 RMA 拆成多笔请求，描述符/reply开销超过 SIMD overlap收益。

## 自检清单

- partial O 是否未归一化，并与对应 max/sum 同 ownership？
- 空 split 是否严格生成中性状态且不访问 indices？
- 所有 SPE 的 local/peer buffer 分配顺序和 offset 是否一致？
- 每轮 reply、sender/receiver、同步和 buffer release 是否闭合？
- root 是否唯一执行最终归一化和 HBM store？
- prefill specialization 是否通过回归，offline fallback 是否未修改？
- baseline 与 after 是否在同一时点、同一 dtype、shape 和计时口径下串行测量？

## 验证

- 首次验证：`flash_mla_sparse`，`v1_decode_fused_online_state_merge`。
- 硬件：T1。
- shape：FP16，`q_seq=1`，`kv_seq=65536`，`topk=512`，`qk_dim=v_dim=512`，
  `q_head=16/8/4`。
- 正确性：3/3 PASS；Diff1 为 0.000659/0.000616/0.000856，Diff2 为
  0.000693/0.000636/0.000957。
- 性能：q_head=16/8/4 分别从 67.690/48.600/39.530 us 降到
  54.010/37.840/28.940 us，耗时降低 20.21%/22.14%/26.79%。
- prefill 回归：smoke 2/2 PASS；8192与65536性能相对当前 revision 历史值约波动0.3%至0.8%。
- evidence: pipeline-v1-flash-mla-decode-online-state-merge
- active participant stage：`v2_fused_decode_active16_merge`，q_head=16/8/4从
  55.190/38.710/30.050 us降到52.120/37.440/29.700 us。
- evidence: pipeline-v2-active-core-partial-state-merge
- final merge-normalize stage：`v3a_final_merge_normalize_fusion`，进一步降到
  50.920/36.820/29.320 us。
- evidence: pipeline-v3a-final-merge-normalize-fusion
- 代码路径隔离stage：`v3c_prefill_decode_codepath_separation`，decode降到
  49.070/35.420/27.690 us，prefill无稳定回退。
- evidence: pipeline-v3c-hot-specialization-codepath-isolation
- 生产扩展：`v13_deepseekv4_flash_real_shapes`，`kv_seq=2048`、`topk=128/144/640`、
  q_head=16/8/4的decode 9/9 PASS，并相对旧路径提升16.65%～40.24%。
- evidence: sparse-attention-v13-fixed-tile-topk-tail

## 来源沿革

- 历史首版：revision `a422addb`，fused slice 实现。
- 当前专用实现：decode 专用实现。
- 当前入口：decode slice 入口。

## 相关模式

- `simd/online-softmax-tile-microkernel`
- `pipeline/ace-writeback-simd-update-overlap`
- `pipeline/hot-specialization-codepath-isolation`
- `pitfalls/chunked-rma-merge-request-overhead`
- `dma/pair-stride-gather`
- `rma/`
- `ldm/`
