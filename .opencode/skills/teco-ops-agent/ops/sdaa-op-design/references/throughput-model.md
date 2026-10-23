# 吞吐建模与瓶颈分析（§2b）

## 目标

设计阶段不再只做单层 roofline，而是做 **T1 分层性能模型**：

```text
T_compute_group = max(T_ace, T_simd)
T_total ≈ T_fill + Iter * max(T_dma, T_rma, T_compute_group, T_writeback, T_sync) + T_drain
```

其中：

- `T_dma`：HBM <-> LDM 搬运
- `T_rma`：核间广播 / 环传 / 归约
- `T_ace`：ACE west/north/feed/compute
- `T_simd`：SIMD epilogue / partial reduce / cast / pack / scalar-vector assist
- `T_writeback`：ACE / SIMD / DMA 结果产出
- `T_sync`：显式同步和等待

## 建模顺序

### 1. 理想上界

先把硬件上界写成常量表：

- `ace_peak_tflops`
- `dma_read_gbps`
- `dma_write_gbps`
- `rma_p2p_gbps`
- `rma_row_bcast_gbps`
- `rma_col_bcast_gbps`
- `ldm_bank_gbps`
- `ace_west_gbps`
- `ace_north_gbps`
- `ace_writeback_gbps`

### 2. traffic model

对给定 shape 和 tile，估算：

- `hbm_read_bytes`
- `hbm_write_bytes`
- `rma_bytes`
- `compute_flops`

### 3. stage time model

用上界常量换算各阶段时间：

```text
T_dma       = HBM_bytes / BW_dma_eff
T_rma       = RMA_bytes / BW_rma_eff
T_ace       = max(T_west, T_north, T_compute)
P0_cycles   = vector_compute_issue_cycles + convert/select/pack issue cycles
P1_cycles   = local_ldm_load_store_issue_cycles + branch/control issue cycles
T_simd      = (max(P0_cycles, P1_cycles) + fill/drain/tail_cycles) / spe_clock
T_compute_group = max(T_ace, T_simd)
T_writeback = writeback_bytes / BW_writeback_eff
```

SIMD 不能把 load、op、store 拍数简单相加。P0 计算管线与 P1 访存/控制管线可双发射，软件流水排布成立时按
`max(P0_cycles, P1_cycles)` 估算暴露时间；load-use、op-store 间距、unroll fill/drain 和 tail/mask 作为额外 cycles 加入。

常用指令口径：

- `VADDS/VFMULS/VMAS`：P0，约 5 拍延迟，稳态按 1 issue/cycle。
- `VFCVTSH/VFCVTHS`：P0，约 2 拍延迟。
- `VLDW/VFLDH`：P1，本地 LDM load 至少 5 拍延迟，稳态按 1 issue/cycle。
- `VSTW/VFSTH`：P1，本地 LDM store 至少 4 拍延迟，稳态按 1 issue/cycle。

### 4. constraint discounts

再加入真实折扣：

- DMA shape 折扣：`bsize / stride / per_dma_size / engine mapping`
- RMA 折扣：广播 fan-in、环传深度、同步损失
- ACE 折扣：小 K、west stride、写回路径
- SIMD 折扣：P0/P1 双发射、load-use 间距、向量指令拍数、软件流水展开、tail/mask
- LDM 折扣：bank conflict、端口竞争
- 流水折扣：fill/drain、wait 点放置、bubble

## bottleneck_type 的判定

- `compute`：`T_compute_group=max(T_ace,T_simd)` 主导
- `memory`：`T_dma` 或 `T_writeback` 主导
- `latency`：小 shape 下 fill/drain/sync 主导
- `mixed`：至少两段接近，且 overlap 后都显著可见

## 设计文档必须填写的字段

```json
{
  "model_type": "layered_t1",
  "hardware_caps": {
    "ace_peak_tflops": 75.0,
    "dma_read_gbps": 313.0,
    "dma_write_gbps": 270.0,
    "rma_p2p_gbps": 53.0,
    "rma_row_bcast_gbps": 188.0,
    "rma_col_bcast_gbps": 278.0,
    "ldm_bank_gbps": 140.0,
    "ace_west_gbps": 80.0,
    "ace_north_gbps": 80.0,
    "ace_writeback_gbps": 27.0
  },
  "traffic_model": {
    "hbm_read_bytes": 123456,
    "hbm_write_bytes": 32768,
    "rma_bytes": 65536,
    "compute_flops": 4194304
  },
  "stage_time_model_us": {
    "dma": 3.3,
    "rma": 1.4,
    "ace": 0.6,
    "simd": 0.2,
    "compute_group": 0.6,
    "writeback": 0.3,
    "sync": 0.2
  },
  "constraint_discounts": [
    "dma_b uses 8KB sweet spot",
    "c writeback reshaped to avoid 64B stores",
    "bank0 carries west+rma, bank1 carries north+writeback+dma"
  ],
  "upper_bound_tflops": 68.0,
  "bottleneck_type": "memory"
}
```

## 特别说明

- 设计阶段的 `upper_bound_tflops` 是 **理论可实现上界**，不是实测值。
- 如果是 `ideal_search` 模式，要解释最优 shape 为何最优，而不是只报一组数字。
- 对 GEMM/Linear，禁止只写 `AI = FLOPs / HBM bytes` 这一级分析。
