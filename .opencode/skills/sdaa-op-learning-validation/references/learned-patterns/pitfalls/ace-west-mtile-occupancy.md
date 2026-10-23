# Pattern: ACE west M tile 必须保留核心占用

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

把 ACE west 的 `M_TILE` 往硬件上限 128 增大，可能提升单 SPE 的 ACE row 利用率；但它也会减少独立 M block 数。在只按 M 分核的 kernel 中，这可能导致 SPE 空闲或 tail imbalance，即使 tile 能放进 LDM 且精度通过，性能仍会退化。

## 适用场景

- GEMM/Linear 使用 ACE west 输入，并且主要沿 M 维分配工作。
- 每个 SPE 独立消费一个或多个 M block。
- 候选 tile search 基于 ACE 偏好和 LDM 可行性增大 `M_TILE`。
- `M` 固定，并且 `ceil(M / M_TILE)` 可能小于 `slave_core_num`。

## 不适用场景

- kernel 使用 2D/3D grid、RMA sharing、split-K 或其他仍能让全部 SPE 保持忙碌的分工方式。
- M 足够大，即使增大 M tile 后仍能给每个 SPE 至少一个均衡 block。
- 优化目标是少量 SPE 上的小延迟，而不是完整 32-SPE 组吞吐。

## 核心思路

tile search 不能只看 ACE west 利用率和 LDM fit，还必须包含核心占用和负载均衡。

## 实现规则

- 对 M-only 分核，计算 `m_blocks = ceil(M / M_TILE)`。
- 优先选择 `m_blocks >= slave_core_num` 的候选。
- 优先选择 `M % M_TILE == 0`，或者 tail 能在 SPE 间均衡处理的候选。
- 如果 `M_TILE=128` 或其他大 tile 让 SPE 利用率不足，不要作为单点优化保留；应先重新设计 grid/data sharing。
- 记录被拒候选时，同时写明 LDM 可行性和 occupancy 原因。

## 伪代码

```cpp
for (int m_tile : {128, 112, 96, 80, 64}) {
    bool ldm_ok = ldm_bytes(m_tile) <= usable_ldm_bytes;
    int m_blocks = ceil_div(M, m_tile);
    bool occupancy_ok = m_blocks >= slave_core_num;
    bool balance_ok = (M % m_tile) == 0;
    if (ldm_ok && occupancy_ok && balance_ok) {
        return m_tile;
    }
}
```

## 常见坑

- **只按 LDM 选型**：选择最大 LDM-feasible M tile，却忽略 `m_blocks`。
- **只看精度**：L3 通过，但因为 SPE 空闲导致性能退化。
- **SPE0 计时歧义**：如果 benchmark 只打印 SPE0，tail 分配到 SPE0 与否会放大或隐藏 imbalance。

## 验证

- 失败 stage：`v7_west_mtile_80`
- 目标 op：`gemmex`
- Shape：`M=2048,N=2048,K=8192`
- 候选：`M_TILE=80`
- 正确性：L3 `success_rate=1.0`
- 性能：`166463136 cycles -> 170102778 cycles`，退化
- 根因：`ceil(2048/80)=26`，少于 32 个 SPE，并且存在 tail imbalance
- evidence: pitfall-v7-ace-west-mtile-occupancy

## 来源沿革

- 原始失败 stage 已蒸馏到 evidence `pitfall-v7-ace-west-mtile-occupancy`。

## 相关模式

- `pipeline/ab-dma-double-buffer-ace-gemm`
- `gemm/a-reuse-across-n`
