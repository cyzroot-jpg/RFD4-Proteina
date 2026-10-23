# Pattern: Online Softmax Tile Microkernel

## 状态

verified_by_stage

## 类型

composite

## 问题

attention kernel 里的 online softmax 如果每个 tile 都用标量 lane reduction、每次 running max 不变也重扫输出 accumulator、并且先写 fp32 概率再交给后续 ACE 转 half，就会形成明显的 SIMD/LDM 串行瓶颈。

## 适用场景

- kernel 按固定 tile 处理 score，例如每个 head 一次处理 32 个 logits。
- 每行/head 维护 running max 和 running sum。
- score 在 softmax 前以 fp32 vector 形式驻留 LDM。
- 下一阶段以 half 概率作为 ACE 输入，例如 `P @ V`。
- 热路径 tile 宽度是 32 的倍数，或者有 mask/tail 处理。

## 不适用场景

- 概率消费者必须使用 fp32，不能接受 half。
- running max/sum 必须按另一种不兼容格式导出。
- 同一轮 attempt 还在修改输出 accumulator 的 dtype/layout，需要保持归因清楚。
- score 数量太小，SIMD setup 成本无法摊薄。

## 核心思路

用 SIMD tree reduction 做 tile max/sum；当 running max 没变时跳过 old-O rescale；如果后续 ACE 消费 half P，就在 softmax 内直接把 exp 结果 pack 成 half。

## 实现规则

- 将 32 个 score 加载成两个 `floatv16`。
- 用 `simd_concat`/`simd_max` 做 tree max，避免 32 lane 标量循环。
- 计算 `new_max = max(old_max, tile_max)`。
- 如果 `old_max` 有效且 `new_max > old_max`，计算 `corr = exp(old_max - new_max)`，更新 `run_sum *= corr`，并 rescale 输出 accumulator。
- 如果 `new_max == old_max`，完全跳过输出 accumulator 的 rescale。
- 使用 fast vector exp table 计算 `exp(score - new_max)`。
- 用 SIMD tree reduction 计算 tile sum。
- 如果下一阶段消费 half P，在当前阶段直接把 exp vector 转成 half 并写入 half P tile，避免先写 fp32 P 再二次转换。
- tile sum 计算完成后，再更新每行/head 的 running max/sum。

## 组合依赖与归因

- 组件：SIMD tree max/sum、running max 不变时跳过 old-O rescale、P-half pack fusion。
- 依赖：tree reduce 缩短标量热路径；条件 rescale 减少无效 O 扫描；P-half pack 只有在后续 ACE 消费 half P 时成立。
- 对比矩阵：基线为 `534.030 ms`；v5 加入向量树归约和条件缩放后为 `347.817 ms`；v7b 再加入半精度概率打包后为 `342.650 ms`。
- 归因：v5 内两个组件未做独立 ablation，因此只把 v5 作为组合 microkernel 证据，不宣称各自独立收益。
- 消融计划：在目标分支稳定时分别关闭 conditional rescale skip 和 tree reduce，补齐组件级归因。

## 伪代码

### 1. 模板化 2×floatv16 tree-reduce（`reduce_32<IS_MAX>`）

任何需要将 32 个 float（分布在两个 `floatv16` 寄存器中）归约为单个标量 max 或 sum 的场景，都可以直接复用这段代码：

```cpp
template <bool IS_MAX>
__device__ __always_inline float reduce_32(floatv16 p0, floatv16 p1) {
    float buf[16] __attribute__((aligned(64)));
    // Level 1: 高低 8 元素半交换，16→8
    floatv16 a0 = simd_concat(p0, p0, (void *)0x20);
    floatv16 a1 = simd_concat(p1, p1, (void *)0x20);
    if constexpr (IS_MAX) {
        p0 = simd_max(a0, p0); p1 = simd_max(a1, p1);
    } else {
        p0 = a0 + p0; p1 = a1 + p1;
    }
    // Level 2: 合并两个 8→4
    p0 = simd_concat(p0, p1, (void *)0x20);
    p1 = simd_concat(p0, p0, (void *)0x10);
    if constexpr (IS_MAX) { p0 = simd_max(p0, p1); }
    else                  { p0 = p0 + p1; }
    // Level 3: 4→2
    p1 = simd_concat(p0, p0, (void *)0x08);
    if constexpr (IS_MAX) { p0 = simd_max(p0, p1); }
    else                  { p0 = p0 + p1; }
    SIMD_STORE(p0, buf);
    // 收尾：从 scramble 后的 buf 位置取最终值
    if constexpr (IS_MAX) {
        float max_val = buf[0];
        if (buf[1] > max_val) max_val = buf[1];
        if (buf[8] > max_val) max_val = buf[8];
        if (buf[9] > max_val) max_val = buf[9];
        return max_val;
    } else {
        return buf[0] + buf[1] + buf[8] + buf[9];
    }
}
```

`simd_concat` 的 `imm` 值含义：`0x20`=半交换，`0x10`=四分组交换，`0x08`=相邻对交换。
收尾取 `buf[0/1/8/9]` 是因为置换操作后最终候选值散落在这四个 lane。

### 2. Online softmax 完整伪代码

```cpp
// 每 tile 对每个 head 执行：
for (int h = 0; h < q_per_kv; ++h) {
    floatv16 p0 = load(scores + h * 32);
    floatv16 p1 = load(scores + h * 32 + 16);

    // 找到 tile 内 max，与 running_max 比较
    float tile_max = reduce_32<true>(p0, p1);
    float new_max = max(run_max[h], tile_max);

    // 若 running_max 更新，回退已累加的 O
    if (run_max[h] > -INFINITY && new_max > run_max[h]) {
        float corr = expf(run_max[h] - new_max);
        run_sum[h] *= corr;
        rescale_output_row_half(output[h], v_dim, corr);  // half O *= corr
    }

    // exp(score - new_max)，同时 pack 为 half 供后续 ACE 使用
    float tile_sum = exp_and_pack_to_half(p0, p1, new_max, exp_table,
                                          prob_half + h * 32);

    run_sum[h] += tile_sum;
    run_max[h] = new_max;
}
```

### 3. 最终 O /= run_sum 融合到最后一个 SV chunk accumulate

独立的 `finalize()` 全量扫描 O 成本为 `O(q_per_kv × v_dim)`。改为在最后一个 KV tile 的最后一次 SV chunk accumulate 中做 `O_chunk = (old_O + SV_out) / run_sum`，通过 `accumulate_sv_chunk<true>` 模板参数触发，省去 standalone pass。

```cpp
template <bool APPLY_FINAL_SCALE>
__device__ void accumulate_sv_chunk(half *c_ace, unsigned chunk_idx) {
    // ... 标准 SIMD accumulate ...
    if constexpr (APPLY_FINAL_SCALE) {
        floatv16 inv = simd_stretch(1.0f / run_sum[ik]);
        // O = (old_O + ACE_out) / run_sum
        for (int j = 0; j < 8; ++j)
            c_halfv[j] = simd_pseudo_vfcvtsh(simd_pseudo_vfcvths(c_halfv[j]) * inv);
    }
}
```

## 常见坑

- 每个 tile 都重扫输出 accumulator。对 sparse attention prefill 的 q_head=16，这一项会非常重。
- 只把 exp 改成 SIMD，但 max/sum 还保留标量 32-lane loop。
- 先把概率写成 fp32 到 LDM，后续 ACE helper 里再转 half，造成重复 LDM 流量和 SIMD 转换。
- 为了制造 overlap 去拆概率消费者的 ACE rows。本次 sparse MLA 验证里，SV head-row split 明显退化。
- 误以为 microkernel 优化后 pipeline 就完成了。它只是减少串行工作，QK/SV/DMA overlap 仍需要单独调度。

## 验证

- 验证 stage：`v5_softmax_microkernel_components`
- 后续融合 stage：`v7b_p_half_pack_fusion`
- 模板化 reduce + 代码清理：v14（commit `c998263a`，`gupeng/flash_mla_sparse`），消除 `reduce_max_32`/`reduce_sum_32` 重复
- 目标算子：`flash_mla_sparse`
- shape：DS4 sparse MLA prefill，`q_head=16/8/4`，`q_seq=8192/65536`，`topk=512`，`qk_dim=v_dim=512`
- 正确性：smoke 和 tile sweep pass；8192/64k all-head accuracy+perf pass
- 性能：v5 在 q_seq=65536 q_head=16 从 `534.030 ms` 降到 `347.817 ms`；v7b P-half pack 降到 `342.650 ms`；v8 final-divide 融合降到 `288.840 ms`；v13 跨 tile QK/SV overlap 降到 `286.498 ms`；v14 代码清理保持持平/微优
- evidence: simd-v5-online-softmax-microkernel
- evidence: simd-v7b-p-half-pack-fusion
- evidence: simd-v8-final-divide-last-sv

## 来源沿革

- commit `c998263a`的`reduce_32/online_softmax_update/accumulate_sv_chunk`实现。
- flash decoding 的`sclaeQK_getMax_softmax_updateSum`参考。
- 原始 stage 已蒸馏到 evidence `simd-v5-online-softmax-microkernel`、
  `simd-v7b-p-half-pack-fusion` 和 `simd-v8-final-divide-last-sv`。

## 相关模式

- `simd/vector-exp-table-lookup`：查表法向量 exp，本 pattern 中 `exp_and_pack_to_half` 的基础。
- `pipeline/ace-writeback-simd-update-overlap`
- `simd/c-quarter-reduce-fp32`
- `ace/`
