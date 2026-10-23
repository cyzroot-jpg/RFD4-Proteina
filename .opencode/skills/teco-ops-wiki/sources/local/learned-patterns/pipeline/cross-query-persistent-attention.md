---
id: local-learned-pattern-pipeline-cross-query-persistent-attention
title: Attention 跨 Query 持久流水
type: source-local
source_category: local-learned-pattern
path: ../sdaa-op-learning-validation/references/learned-patterns/pipeline/cross-query-persistent-attention.md
source_path: ../sdaa-op-learning-validation/references/learned-patterns/pipeline/cross-query-persistent-attention.md
architectures:
- sdaa
- teco-t1
tags:
- learned-patterns
- local-source
- pipeline
- cross
- query
- persistent
- attention
- composite
confidence: source-reported
captured_at: '2026-08-04'
pattern_status: verified_by_stage
pattern_type: composite
---

# Pattern: Attention 跨 Query 持久流水

## 状态

verified_by_stage

## 类型

composite

## 问题

长序列 prefill 常让每个 SPE 连续处理大量互不依赖的 query。如果每处理一批 query 都重新分配
LDM、初始化查表数据、完整等待输出 DMA 并执行阵列同步，就会在 query 边界反复产生
fill/drain 开销，tile 内部流水再充分也无法掩盖这些开销。

## 适用场景

- 多个 query 之间没有数据依赖，每个 SPE 可按固定步长连续处理 query。
- 单个 query 内已有 QK、online softmax、SV 和 KV 双缓冲流水。
- 输出 accumulator 可以提供 query 级 ping/pong buffer。
- Q transpose 完成后，原始 Q LDM buffer 不再被当前 query 使用。
- 阈值验证范围为 T1、FP16 sparse MLA prefill、`q_seq>=512 && q_seq%32==0`、
  `q_head=16/8/4`、`kv_head=1`、`topk=512`、`kv_seq=q_seq`、`qk_dim=v_dim=512`、
  `N_BLOCK=32`，验证点包括512/640/768/1024/1536/2048/4096/8192/65536。
- 生产 shape 另验证了`q_seq=kv_seq=2048`、`topk=128/144/640`、`q_head=16/8/4`；
  当前接口支持域可以比算法阈值证据更窄。

## 不适用场景

- query 之间存在因果依赖，下一 query 输入依赖当前输出。
- LDM 无法容纳第二份输出 accumulator，且没有可证明安全的死亡空间。
- 下一 query QK 会抢占当前 query SV 使用的同一 ACE；这种前移可能延长关键路径。
- query 数量很少，持久循环和额外 ownership 状态无法摊薄。
- query tail 不能保证所有 SPE 的循环次数和同步语义安全，且没有单独 tail 路径。

## 核心思路

把 query 循环留在同一次 device slice 内，让 LDM 和只读表跨 query 常驻；下一 Q DMA 使用已经
死亡的 `ldm_q`，输出 DMA 使用双 `c_ldm`，所有 wait 推迟到对应 buffer 的第一消费或首次复用点。

## 实现规则

- 32 SPE 独立处理时，每个 SPE 使用 `q_token_idx = tid + round * 32`。
- LDM 分配、exp table 初始化和 reply 数组基础初始化只在持久 slice 入口执行一次。
- 当前 Q 完成 scale 和 transpose 后，`ldm_q` ownership 转交给下一 query Q DMA。
- 下一 query 进入 Q scale 前等待 Q DMA reply；不要在 DMA issue 后立即等待。
- 使用 `c_ldm[2]`。query `r` 的输出 DMA 发出后，`c_ldm[r & 1]`归 DMA 所有；仅在
  query `r+2`准备清零并复用该 buffer 时等待对应 reply。
- 当前 query 的 QK、online softmax 和 SV 数学保持不变，query 级流水不能修改 tile 内结果布局。
- 下一 query QK 不在当前 query SV body 前执行。共享 ACE 时，当前 SV保持优先级。
- fill 阶段只处理首个 query 的输入；steady 阶段维持 Q 预取和输出 ping/pong；drain 阶段等待
  最后两份输出 reply，并只执行一次必要的阵列同步。
- query tail 不能覆盖完整 SPE 组时，应证明独立 SPE 无跨核依赖，或回退到原 slice 分发。
- host 应校验完整 online 支持域；device 入口只在该契约内选择 prefill/decode，不重复维护另一份
  topk/head/dim白名单，也不能把 online 输入静默回退到 offline slice。

## 关键参数与资源预算

- query 步长通常等于活跃 SPE 数；已验证值为 32。
- 额外主要 LDM 为第二份 `c_ldm`：head16/8/4、`v_dim=512`时分别为16KB/8KB/4KB。
- 下一 Q 复用现有 `ldm_q`，不要求第二份 Q buffer。
- 每份异步输出需要独立 reply；Q 预取使用一份跨 round 持久 reply。
- 必须把额外输出 buffer与SV栈上 `local_tb/c_ace`共同纳入最大 LDM 预算。

## 架构与数据流

```text
fill query r:
    Q_r DMA -> transpose -> QK/softmax/SV

steady:
    transpose Q_r 完成
        └─ DMA Q_{r+1} -> ldm_q
    QK/softmax/SV_r
    output DMA O_r <- c_ldm[r&1]
        ||
    QK/softmax/SV_{r+1} -> c_ldm[(r+1)&1]

reuse:
    wait output_reply[r&1] only before query r+2 clears c_ldm[r&1]

drain:
    wait remaining output replies -> one final synchronization
```

DMA 可以与 ACE/SIMD 重叠；ACE 与 ACE、SIMD 与 SIMD 仍共享各自执行资源，不能把异步 issue
误解为同资源并行。

## 从朴素实现到优化实现

- 朴素实现每批 query 都执行 `lmem_reset`、exp table 初始化、完整输出等待和阵列 barrier。
- 优化实现只在 kernel 入口初始化一次，并在 SPE 内循环处理全部 query。
- 朴素输出在 `rt_dma_iput` 后立即等待；优化输出等到同一 `c_ldm`两轮后将被复用时才等待。
- 朴素下一 Q 在下一轮开始才加载；优化实现于当前 Q transpose 后立即预取到死亡的`ldm_q`。

## 选型决策

- `q_seq / active_spe`较大时优先尝试，query round 越多，重复初始化和barrier越值得消除。
- benchmark 已证明`q_seq>=512 && q_seq%32==0`时16个均衡round可作为候选下界；这描述算法
  适用证据，不等于当前产品接口必须开放全部 shape。非32倍数query不能仅按总query数外推。
- 先完成持久循环和output ping/pong，再评估下一 Q预取；后者可能只是小幅附加收益。
- 不要同时前移下一 QK；应单独验证共享 ACE 的优先级和关键路径。
- 若第二份输出 buffer导致LDM溢出，先尝试死亡空间复用或缩小支持的head范围，再考虑放弃。

## 组合依赖与归因

- 组件：持久 query 循环、一次性初始化、双输出 buffer、延迟 output wait、下一 Q预取。
- 依赖：持久循环提供跨 round 生命周期；双输出 buffer提供异步DMA ownership；死亡的`ldm_q`
  提供无额外LDM的下一 Q staging。
- baseline：head16/8/4为257.334/208.378/199.277 ms。
- 完整组合：231.564/183.701/175.972 ms，分别提升10.01%/11.84%/11.69%。
- 消融：关闭下一 Q预取后为232.265/183.711/176.177 ms；主要收益来自持久循环、一次性初始化
  和output ping/pong，Q预取在head16约贡献0.3%，head8/4近似中性。
- 8K扩展：旧单轮slice为31.987/25.788/24.694 ms，persistent为
  28.838/22.910/21.906 ms，分别提升9.84%/11.16%/11.29%；每个SPE只有256个query round时
  仍能稳定摊薄边界开销。
- 2K扩展：旧单轮slice为8.823/6.712/6.087 ms，persistent为8.012/6.038/5.473 ms，
  提升9.19%/10.05%/10.08%；每个SPE 64个round仍稳定受益。
- round阈值sweep：q_seq=512/640/768/1024/1536对应16/20/24/32/48 rounds；严格回切A/B中
  head16/8/4分别稳定提升8.47%～14.47%。最小已验证正向点为q_seq=512：
  1995.58/1572.45/1374.63 us降到1823.88/1409.82/1246.44 us，提升
  8.60%/10.34%/9.33%。
- 结构化dispatch新点：q_seq=4096不在旧白名单中，旧slice为19.314/15.015/13.000 ms，
  persistent为16.004/12.071/10.984 ms，head16/8/4提升17.13%/19.60%/15.51%；
  证明round条件可以替代生产序列长度枚举。
- DeepSeekV4生产点：q_seq=2048、topk=128/144/640、head16/8/4精度9/9通过；topk=128/640
  相对旧slice提升13.14%～31.01%，topk=144尾块通过完整正确性契约。
- 小shape反例：q_seq=32 invalid和q_seq=33 tail分别回退6.74%和17.79%，因此persistent
  不能无条件替代单轮slice。

## 伪代码

```cpp
initialize_ldm_and_tables_once();
bool output_pending[2] = {false, false};

for (int round = 0, q = tid; q < q_seq; ++round, q += 32) {
    int tag = round & 1;
    if (output_pending[tag]) {
        wait(output_reply[tag]);
    }

    wait_prefetched_q_if_needed();
    scale_and_transpose_q();
    issue_next_q_dma_into_dead_ldm_q();
    run_existing_qk_softmax_sv();

    issue_output_dma(c_ldm[tag], output_reply[tag]);
    output_pending[tag] = true;
}

drain_output_replies();
```

## 常见坑

- 仍在每个 query 内执行 exp table 初始化，导致持久 slice 只减少函数调用，没有消除主要固定开销。
- 输出 DMA 未完成就清零或复用同一 `c_ldm`，产生偶发精度错误。
- Q transpose 尚未完成就覆盖 `ldm_q`。
- 为追求更多重叠把下一 query QK移到当前SV之前，反而抢占共享ACE。
- 只计算显式LDM tensor，遗漏内联SV函数的栈上LDM数组，导致head16运行时越界。
- 每轮仍保留全阵列barrier，使不同query之间继续完整drain。

## 自检清单

- 每个异步输出是否绑定独立buffer和reply？
- output wait是否位于首次复用点？
- `ldm_q`是否只在transpose完成后转交下一DMA？
- 最后两份output reply是否在drain阶段完成？
- 最大head下双`c_ldm`与SV栈预算是否通过编译和运行？
- 是否覆盖目标长序列、smoke和未命中dispatch的decode护栏？
- baseline、完整组合和关键消融是否使用同一shape和计时单位？

## 验证

- 验证算子/stage：`flash_mla_sparse`，`v5_prefill_n32_cross_query_pipeline`。
- 目标shape：`q_seq>=512 && q_seq%32==0`，`q_head=16/8/4`，`kv_head=1`，`kv_seq=q_seq`，
  `topk=512`，`qk_dim=v_dim=512`，FP16。
- 正确性：目标shape 3/3 PASS，prefill smoke 2/2 PASS，decode护栏3/3 PASS。
- 性能：257.334/208.378/199.277 ms降至231.564/183.701/175.972 ms。
- evidence: pipeline-v5-cross-query-persistent-attention
- 8K stage：`v8_prefill_n32_persistent_8192`，精度3/3通过，严格A/B提升
  9.84%/11.16%/11.29%，64K性能护栏无回退。
- evidence: pipeline-v8-cross-query-persistent-attention-8192
- 2K stage：`v9b_prefill_n32_persistent_2048`，精度3/3通过，提升
  9.19%/10.05%/10.08%，最终混合dispatch覆盖11/11通过。
- evidence: pipeline-v9b-cross-query-persistent-attention-2048
- round阈值stage：`v10_prefill_n32_round_threshold_sweep`，persistent精度15/15通过；
  q_seq=512～1536、head16/8/4严格A/B全部正向，最小已验证点为16 rounds。
- evidence: pipeline-v10-persistent-round-threshold-512
- 结构化dispatch stage：`v12_structural_n32_query_dispatch`，4K新shape精度3/3通过并提升
  15.51%～19.60%；阈值矩阵15/15和fallback矩阵11/11通过，64K无回退。
- evidence: pipeline-v12-structural-n32-query-dispatch
- 生产shape stage：`v13_deepseekv4_flash_real_shapes`，prefill 9/9 PASS。
- evidence: sparse-attention-v13-fixed-tile-topk-tail

## 来源沿革

- 参考 flash_mla_sparse fused pipeline 实现。
- 参考 flash_mla_sparse fused query pipeline 实现。

## 相关模式

- `pipeline/ace-writeback-simd-update-overlap`
- `pipeline/online-softmax-partial-state-tree-merge`
- `pitfalls/next-qk-before-current-sv`
- `simd/online-softmax-tile-microkernel`
- `dma/gather-validity-flag-reuse`
