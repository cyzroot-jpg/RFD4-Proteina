# 示例：locked-shape GEMM 设计

## 目标

给定：

```text
M = 4096
N = 4096
K = 6144
dtype = fp16 -> fp32
```

希望在设计阶段得到一份一代芯片上的首版设计。

> `--auto-design` 已移除：本示例只展示 locked-shape 初始化方式，不再触发旧的
> PVC family 搜索或自动候选生成；后续 `throughput_model`、`tiling_strategy`、
> `core_partition_strategy`、`ldm_planning`、`pipeline_layout` 需要人工补齐并通过 strict 校验。

## 初始化

```bash
python3 ops/sdaa-op-design/scripts/init_design.py \
  --op gemm_fp16_locked \
  --computation-type matmul \
  --summary "fp16 GEMM locked-shape design" \
  --patch '{"parameters":{"shape_mode":"locked","shape_keys":["M","N","K"],"locked_shapes":{"M":4096,"N":4096,"K":6144},"shapes":{"smoke":{"M":64,"N":32,"K":128},"default":{"M":4096,"N":4096,"K":6144}}}}'
```

## 结果特征

完整设计需要补齐：

- `throughput_model`
  包含 `hardware_caps`、`traffic_model`、`stage_time_model_us`
- `tiling_strategy`
  给出 `M1/N1/K1/M2/N2/K2`
- `core_partition_strategy`
  给出 `grid_shape`、通信模式和 loader 分配说明
- `ldm_planning`
  给出一份首版 steady-state LDM 规划
- `pipeline_layout`
  给出 panel steady-state 的重叠关系

## 口径

这是 **设计阶段首版方案**，目标是：

- 先找到一个闭合、可解释、有硬约束的候选方案
- 不是替代后续真机 benchmark

后续应继续：

1. 根据实现细节修正 bank / sync / wait 点
2. 用真机数据校准 `constraint_discounts`
3. 再决定是否需要 split-K、ring 或更复杂的 3D 方案
