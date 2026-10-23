# Pattern: FP16 widen-compute-narrow for elementwise+reduce

## 状态

verified_by_stage

## 类型

optimization

## 问题

访存受限（AI < 2）的 elementwise + reduce 算子在 FP32 IO 下受 HBM 带宽限制。将 IO 改为 FP16 可以减半数据搬运量，但需要在 LDM 内扩展到 FP32 进行计算以保证精度。

## 适用场景

- 算子瓶颈在 HBM 带宽（arithmetic intensity < 2）
- 输入可以容忍 FP16 精度（推理场景、非梯度计算）
- 累加器必须保持 FP32 以避免大 N 求和精度损失
- 算子是 elementwise + reduce 模式（非 ACE-eligible）

## 不适用场景

- 计算密集型算子（GEMM、ACE 路径）
- 输入本身已是 FP32 且无法转换
- 需要 FP32 IO 精度的训练反向传播
- 算子瓶颈不在带宽而在计算或同步

## 核心思路

IO 使用 FP16 减半 HBM 搬运量；LDM 内通过 `simd_vfcvths` 将 `halfv16` 扩展到 `floatv16`；全程用 FP32 完成乘加、clamp、累加；最终标量输出保持 FP32。

对 broadcast-reduce 模式，额外优化：
- 局部化 broadcast 维度：每个 SPE 只加载自己负责行的 targets
- 使用整行作为 chunk：消除 chunk 循环开销，减少 DMA 启动次数

## 实现规则

- LDM buffer 使用 `uint16_t*` 或 `half_t*`，DMA 字节数按 `sizeof(uint16_t)` 计算
- SIMD 热循环：`simd_load(halfv16, ptr)` → `simd_vfcvths(halfv16)` → `floatv16` 计算
- 累加器使用 `floatv16`，最终标量归约用 FP32 水平求和
- **4x `floatv16` unroll** 适配 P0/P1 双发射（8x 会增加寄存器压力导致回退）
- `halfv16` 映射到 512-bit 向量寄存器，`simd_load` 要求 64B 对齐
- FP16→FP32 转换（`simd_vfcvths`）走 P0 管线，与 P1 的 `simd_load` 可以双发射
- **broadcast target**：用 `simd_vcpyfs(target_f32)` 广播到向量，避免每 chunk 加载 targets 向量
- **整行 chunk**：在 LDM 预算允许下使用整行作为 chunk（D=32768），消除 chunk 循环开销

## 伪代码

```cpp
// LDM buffers (FP16)
uint16_t *pred_ping = (uint16_t *)rt_ldm_malloc(D * sizeof(uint16_t));
uint16_t *pred_pong = (uint16_t *)rt_ldm_malloc(D * sizeof(uint16_t));
uint16_t *local_targ = (uint16_t *)rt_ldm_malloc(ROWS_PER_SPE * sizeof(uint16_t));

// DMA (half the bytes vs FP32)
rt_dma_iget(local_targ, targ_hbm + row_start, local_targ_bytes, &reply);
rt_dma_iget(pred_ping, pred_hbm + row_start * D, row_bytes, &reply);

// SIMD compute with broadcast target
const half_t *pred_h = (const half_t *)pred_ping;
floatv16 one_vec = simd_vcpyfs(1.0f);
floatv16 zero_vec = simd_vcpyfs(0.0f);
float target_f32 = half_to_float_device(local_targ[row_idx]);
floatv16 targ_vec = simd_vcpyfs(target_f32);
floatv16 acc0 = simd_vcpyfs(0.0f);
// ... acc1, acc2, acc3

for (int i = 0; i <= vec_len - 64; i += 64) {
    halfv16 ph0, ph1, ph2, ph3;
    simd_load(ph0, pred_h + i);       // P1
    simd_load(ph1, pred_h + i + 16);  // P1
    simd_load(ph2, pred_h + i + 32);  // P1
    simd_load(ph3, pred_h + i + 48);  // P1

    floatv16 pf0 = simd_vfcvths(ph0); // P0: widen fp16→fp32
    floatv16 pf1 = simd_vfcvths(ph1); // P0
    floatv16 pf2 = simd_vfcvths(ph2); // P0
    floatv16 pf3 = simd_vfcvths(ph3); // P0

    floatv16 prod0 = simd_vfmuls(pf0, targ_vec);  // P0
    floatv16 prod1 = simd_vfmuls(pf1, targ_vec);  // P0
    floatv16 prod2 = simd_vfmuls(pf2, targ_vec);  // P0
    floatv16 prod3 = simd_vfmuls(pf3, targ_vec);  // P0
    
    floatv16 diff0 = simd_vfsubs(one_vec, prod0);  // P0
    floatv16 diff1 = simd_vfsubs(one_vec, prod1);  // P0
    floatv16 diff2 = simd_vfsubs(one_vec, prod2);  // P0
    floatv16 diff3 = simd_vfsubs(one_vec, prod3);  // P0
    
    floatv16 loss0 = simd_max(zero_vec, diff0);  // P0
    floatv16 loss1 = simd_max(zero_vec, diff1);  // P0
    floatv16 loss2 = simd_max(zero_vec, diff2);  // P0
    floatv16 loss3 = simd_max(zero_vec, diff3);  // P0
    
    acc0 = acc0 + loss0;  // P0
    acc1 = acc1 + loss1;  // P0
    acc2 = acc2 + loss2;  // P0
    acc3 = acc3 + loss3;  // P0
}
```

## 常见坑

- 用 FP16 做累加器。大 N 求和（如 B*D=1073741824 个元素）用 FP16 累加会导致严重精度损失。必须 widen 到 FP32 后累加。
- 忽略 `halfv16` 的 64B 对齐要求。`simd_load` 要求指针对齐到向量寄存器宽度（64B），LDM 分配通常满足，但 HBM 指针需要额外检查。
- 把 `simd_vfcvths` 和 `simd_vfcvtsh` 搞混。`vfcvths` 是 FP16→FP32（widen），`vfcvtsh` 是 FP32→FP16（narrow）。
- 忘记 DMA 字节数要按 FP16 元素大小计算（`num_elems * 2`，不是 `num_elems * 4`）。
- **盲目 8x unroll**：对只有 1 个 load 的 broadcast-reduce，8x 会增加寄存器压力导致回退。4x 是更好的选择。
- **simd_fnma 不一定更快**：`simd_fnma(pred, targ, one)` 不一定比 `simd_vfmuls + simd_vfsubs` 序列更快，实测可能回退。
- **预转换小标量数组**：将 targets 预转换到 FP32 增加 LDM 压力和启动开销，无收益。
- **三缓冲不一定更好**：对 DMA-bound kernel，三缓冲增加 LDM 压力但不一定提升性能。双缓冲通常足够。
- **微优化效果有限**：half 转换等微优化在整体性能中占比很小，代码变化可能导致编译器行为变化。

## 验证

- 验证 op/stage：`hinge_loss`，`v7_full_row_chunk`（champion）。
- Shape：`B=32768, D=32768`，`predictions/targets=fp16`，`output=fp32`。
- 正确性：`torch_verify.py` L3 通过，`success_rate=1.0`，`abs_diff=5.07e-06`。
- 交付：`check_delivery.py --op hinge_loss --json` → `delivery_status: pass`。
- 性能（device-side, kernel-bench）：
  - v1 (FP16 widen-compute-narrow): 20.20 ms, 47.67M cycles
  - v2 (+ targets localization): 19.49 ms, 45.99M cycles (3.5% over v1)
  - v3 (+ FMA + 8x unroll): 20.81 ms, 49.11M cycles (regressed)
  - v4 (+ larger chunk 16384): 18.57 ms, 43.83M cycles (8.1% over v1)
  - v5 (+ triple buffer + pre-convert): 20.89 ms, 49.29M cycles (regressed)
  - v6 (+ optimized half conversion): 21.00 ms, 49.55M cycles (regressed)
  - **v7 (+ full row chunk D=32768): 17.02 ms, 40.17M cycles (16.5% over v1, champion)**
- PyTorch 端到端计时（使用 SDAA events）：FP32 版本 130.0 ms，FP16 v7 版本 55.6 ms，加速比 2.34 倍
- HBM 读取：FP32 4.30 GB → FP16 2.15 GB（减半）
- 带宽利用率：49.4%（理论 8.40 ms，实际 17.02 ms）
- evidence: simd-v1-fp16-widen-compute-narrow

## 来源沿革

- hinge_loss FP32 baseline: `swdnn_test_ops/src/hinge_loss/hinge_loss.swcu`
- SIMD 手册：`docs/共享知识库/SIMD使用手册-zh.md`

## 相关模式

- `simd/c-quarter-reduce-fp32`（FP32 SIMD reduce 的 unroll 选型经验）
- `simd/xplutw-exp-8x-unroll-softmax`（SIMD unroll 与超越函数）
