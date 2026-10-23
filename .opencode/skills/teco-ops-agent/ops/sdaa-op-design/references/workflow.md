# 算子设计流程（workflow v3）

## 目标

把 `sdaa-op-design` 从“通用文档模板”收紧成“一代芯片约束下的设计器”。

设计阶段的输出不只是章节填满，而是下面四件事同时成立：

1. 算子语义清楚：独立轴、归约轴、复用方向明确。
2. 性能模型闭合：`T_dma / T_rma / T_ace / T_writeback / T_sync` 能给出上界。
3. 分块与分核可落地：满足 LDM、DMA、ACE、RMA 约束。
4. 流水线自洽：双缓冲、bank 分配、wait/sync 点能解释稳态迭代时间。

## 流程顺序

```
算子定义 + 轴分析
        ↓
shape 建模（locked / ranged / ideal_search）
        ↓
分层吞吐建模（HBM / RMA / ACE / writeback / sync）
        ↓
分块搜索（可行域 → 候选 → 选型）
        ↓
分核搜索（网格 / loader / 通信 / 归约）
        ↓
双缓冲判定（值得做吗？）
        ↓
LDM + Bank 规划
        ↓
流水排布（fill / steady / drain）
        ↓
validate_design（严格 + 物理一致性）
```

## 三种输入模式

### 1. `locked`

用户给定完整 shape。

设计目标：

- 找到该 shape 下的最优或近最优方案。
- 输出 bottleneck、理论上界、推荐 tile、推荐分核。

### 2. `ranged`

用户给定 shape 范围。

设计目标：

- 找到一个对区间内多数 case 稳定的方案。
- 标出切换点，例如“小 K 走写回敏感方案，大 K 走 West 饱和方案”。

### 3. `ideal_search`

用户不给 shape，或者只锁定少数轴。

设计目标：

- 找出一代芯片上的理论甜点 shape。
- 说明甜点来自哪里：DMA 甜点、ACE 饱和点、RMA 可接受区、LDM 可行域。

## 迭代原则

- **先建上界，再做折扣**。
  先算理想 `min(各通路上界)`，再加 `shape / stride / bank / sync` 折扣。
- **先判瓶颈，再定 tile**。
  不允许先拍脑袋选 tile 再反推解释。
- **先判可行，再谈效率**。
  不允许忽略 LDM / bank / 通信约束，只因为某个 ACE 效率更高。
- **设计阶段优化目标是 `T_total`，不是单点指标**。
  例如 DMA 瓶颈时，`ACE_eff` 更高并不等于整体更快。

## 必须回答的问题

### operator_definition

- 哪些轴独立？
- 哪些轴归约？
- 哪些 tensor 在核间可复用？

### parameters

- 当前是 `locked`、`ranged` 还是 `ideal_search`？
- 真实要优化的轴是谁？

### throughput_model

- 理想上界由哪条通路决定？
- 真实折扣最大的两项是什么？

### tiling_strategy

- 候选 tile 是怎么搜出来的？
- 为什么排除其他 tile？

### core_partition_strategy

- 为什么是这个网格？
- loader / compute / reduce 角色如何分配？
- A/B/C 分别怎么走？

### double_buffer_strategy

- overlap 哪两段？
- 成立条件是什么？
- 如果不成立，为什么不用？

### ldm_planning

- usable budget 用多少？
- 两个 bank 怎么放？
- 哪条通路压在 bank0 / bank1？

### pipeline_layout

- steady-state iter 由哪一段决定？
- fill / drain 的 bubble 是多少？
- wait / sync 放在哪里？
