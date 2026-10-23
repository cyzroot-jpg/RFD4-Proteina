---
id: source-teco-ops-agent-ops-sdaa-op-design-references-source-docs-t1-dma-rma-36b2de05
title: "teco-ops-agent ops: sdaa-op-design/references/source-docs/T1-DMA-RMA访存优化方法论.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-design
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-design/references/source-docs/T1-DMA-RMA访存优化方法论.md
relative_source_path: sdaa-op-design/references/source-docs/T1-DMA-RMA访存优化方法论.md
captured_at: 2026-08-04
---

# T1-DMA-RMA访存优化方法论

本文基于 [teco-T1.md](teco-T1.md) 中的硬件描述、访存实验结论和示意图整理，目标是把 T1 上 DMA/RMA 访存优化从“经验参数”沉淀为可执行的方法论。

核心结论：T1 的访存性能不是只由 HBM 峰值带宽决定，而是由以下五类资源共同约束：

1. HBM 的 Channel、Pseudo Channel、Bank、Row Buffer 并行度。
2. DMA engine 和 HBM Channel 的映射、128B 包粒度、PPU/MC 调度。
3. 32 个从核作为一个核组同时访问的全局地址分布。
4. Mesh 网络上的上网/下网方向、一级连接、路由路径冲突。
5. RMA 与 DMA 在同一从核连接、同一网络方向或同一路径上的带宽抢占。

因此优化的第一原则是：不要从单个从核的局部连续性判断访存好坏，而要从整个核组 32 个从核共同发出的访问集合来判断是否打满 Channel/Bank、是否跨 Row、是否造成 DMA/RMA 网络冲突。

## 1. T1 硬件抽象

### 1.1 计算与存储层级

T1 的一个核组可按如下层次理解：

| 层级 | 关键资源 | 对优化的影响 |
| --- | --- | --- |
| 从核/SPE | 32 个从核，每个从核有 LDM | 数据应尽量在本从核 LDM 内复用，减少跨核搬运 |
| LDM | 双 Bank、半双工特性 | 同一从核同时上网和下网会受 LDM 到网络连接限制 |
| DMA engine | 8 个 DMA engine，同列 4 个从核共享 1 个 engine | 列方向天然绑定 DMA 资源，行方向容易只用到少数 engine |
| Mesh 网络 | 256 bit，2.5GHz，包头+包身开销后可用约 64GB/s 双工 | DMA/RMA 上网后本质都走 Mesh，会互相抢带宽 |
| HBM/MC | 16 个并行 Channel，Channel 内 Bank 并行，Row 串行 | 地址布局决定能否打满 HBM |
| Host/PCIe/DDR | Host CPU 通过 PCIe 与设备交互 | 主机传输通常不是核内高性能路径，应批量化 |

相关架构图可参考：

- Mesh/DMA/RMA 总览：[drawing-04](images/teco-T1/drawing-04.png)
- DMA engine 与列绑定：[drawing-13](images/teco-T1/drawing-13.png)
- HBM/Channel/Bank 映射：[drawing-15](images/teco-T1/drawing-15.png)

### 1.2 Mesh 网络模型

Mesh 网络由 DMA engine、从核、路由和双工连线组成。

关键事实：

- Mesh 原始位宽为 256 bit，频率约 2.5GHz，原始双工带宽约 `2.5GHz * 256bit / 8 = 80GB/s`。
- 网络包包含包头和包身，按 1 个包头、4 个包身估算，有效用户带宽约 `80GB/s * 4 / 5 = 64GB/s`。
- 每个从核到网络的一级连接也是双工连接，每个方向理论上限约 64GB/s。
- DMA 数据一旦进入 Mesh，和 RMA 数据在网络上没有本质区别，会发生链路、路由和节点连接抢占。

对优化的含义：

- 同一从核同一方向的上网流量会冲突。例如 RMA put 从本核发出，同时 DMA put 也从本核上网，容易在从核到路由的一级连接处抢带宽。
- 同一从核同一方向的下网流量也会冲突。例如 DMA get 返回写入本核 LDM，同时 RMA 广播也向本核下发数据，会形成拥塞。
- 上行和下行理论上可双工并行，但 LDM/控制器/接口处仍可能存在隐式瓶颈，实测同时收发会低于单方向极限。
- 路由路径重叠会降低 RMA 性能，即使源和目的节点不同，也要考虑路径是否在 Mesh 中共线或交叉。

### 1.3 HBM 模型

HBM 的并行性来自多层级：

| 层级 | 文档中的关键参数 | 优化含义 |
| --- | --- | --- |
| 物理 Channel | 8 个，每个 128 bit | 物理通道独立，可并行 |
| Pseudo Channel | 每物理 Channel 拆为 2 个，共 16 个逻辑通道 | 访问应覆盖 16 个通道 |
| DMA/MC Channel | 16 个 Channel | 连续对齐 2KB 可覆盖全部 16 个 Channel |
| Bank | Channel 内约 16 个 Bank 并行 | Channel 内还要展开到 Bank |
| Row | 低 19 位处于同一 Row 范围 | 跨 Row 代价高，应控制核组同时访问窗口 |

HBM 的访存代价从低到高可概括为：

`Bank Group 切换 < Channel 切换 < Column 切换 < Bank 切换 < Row 切换`

因此优化目标不是简单追求单核连续，而是：

1. Channel 打满。
2. Bank 尽量并行。
3. Row 尽量少切换。
4. 请求粒度与 DMA/PPU 粒度匹配。

## 2. T1 访存粒度与地址规律

### 2.1 必须记住的粒度

| 粒度 | 数值 | 含义 |
| --- | --- | --- |
| HBM 最小有效粒度 | 32B | DRAM 预取/Burst 相关粒度，地址应至少 32B 对齐 |
| DMA/PPU 包粒度 | 128B | DMA 会拆成 128B 包，4B 和 128B 请求在 PPU 视角成本接近 |
| 单 Channel DMA 粒度 | 128B | 地址按 128B 分散到 Channel |
| 全 16 Channel 覆盖 | 2KB | `128B * 16`，连续对齐 2KB 可覆盖 16 个 Channel |
| 同 Row 地址窗口 | 512KB | 低 19 位处于同一行，核组同时访问尽量不超过该窗口 |
| 建议核组窗口下限 | 256KB | 使用低 18 位地址空间，避免 Channel/Bank 没打满 |
| 传统 DMA 单核优选 | 8KB 到 16KB | 32 核合计 256KB 到 512KB |
| 双缓冲读写优选 | 4KB 或 8KB | 实测单核单次总量 4/8KB 时双缓冲带宽较高 |
| DMA 队列长度 | 约 11 | 读写共用队列，同时 outstanding 总数最好不超过 11 |

### 2.2 Channel 映射

文档给出的 Channel 映射公式为：

```text
channel = (address / 128B) % 16
```

这意味着：

- 连续 128B 块会轮转落到 16 个 Channel。
- 连续对齐 2KB 的访问集合刚好覆盖所有 16 个 Channel。
- 如果 32 个从核共同访问的地址集合中存在空洞，就会浪费部分 Channel。
- 如果多个 DMA engine 的地址映射到相同 Channel，可能造成 Channel 冲突或交叉开关冲突。

### 2.3 128B 对齐是 DMA 的基本线

DMA 进入 PPU 后按 128B 包处理，且 PPU/DMA 不会替用户合并请求。

典型低效模式：

```text
core0 访问 base + 0,   64B
core1 访问 base + 64,  64B
```

虽然两个请求合起来是连续 128B，但硬件不会合并成一个 128B 请求，带宽可能只有理想情况的一半。

推荐模式：

```text
每个 DMA 请求都尽量按 128B 对齐、128B 整数倍发起。
多个从核的访问集合在核组视角上连续覆盖 2KB、256KB、512KB 等关键窗口。
```

### 2.4 Row 约束决定 tile 上限

HBM Bank 内访问按 Row Buffer 工作。访问同一 Row 内不同列成本较低，切换 Row 需要 close/open，代价明显更高。

文档结论是低 19 位可视作同一 Row 相关窗口，因此：

- 32 个从核同时访问的地址范围应尽量控制在 512KB 内。
- 平均到 32 个从核，单核访问量不要长期超过 16KB。
- 为了至少使用低 18 位空间、打满 Channel/Bank，核组访问窗口最好不低于 256KB。
- 平均到 32 个从核，单核访问量至少应接近 8KB。

所以传统连续 DMA 的甜点区间是：

```text
单核 8KB 到 16KB
核组 256KB 到 512KB
```

如果是 300GB/s 级别的专门访存模式，单核单次总量可在 `4KB、8KB、16KB、32KB、64KB、128KB` 中实测选择，但选择大 tile 时必须重新检查 Row 切换和网络拥塞。

## 3. 核组视角的数据划分原则

### 3.1 周期划分优先于块划分

块划分的表面特征是单个从核访问连续地址：

```text
core0: A[0:8KB]
core1: A[8KB:16KB]
core2: A[16KB:24KB]
...
```

这看起来对单核友好，但从核组同一时刻发出的请求可能不是连续覆盖 HBM Channel/Bank 的理想集合，尤其当每个从核独立推进时，容易出现 Channel 未打满或跨 Row。

周期划分的目标是让 32 个从核在同一时间片共同覆盖连续地址：

```text
time t:
core0: A[0 * 128B]
core1: A[1 * 128B]
core2: A[2 * 128B]
...
core31: A[31 * 128B]

time t + 1:
core0: A[32 * 128B]
core1: A[33 * 128B]
...
```

这样单个从核看到的是跨步访问，但核组看到的是连续访问。T1 上应以后者作为优化目标。

### 3.2 跨步接口不等于低效

接口层面的“跨步”不一定代表 HBM 视角不连续。判断标准是：

```text
某个从核跨过的中间地址，是否被其他从核在同一时间片访问。
```

如果中间空洞被其他从核填满，则核组访问仍然连续，反而可能优于每核各自连续的块划分。

推荐做法：

- 用跨步 DMA 让每个从核访问自己的周期位置。
- 让 32 个从核的请求共同拼成连续的 2KB、256KB 或 512KB 地址窗口。
- 如果无法保证空洞被其他从核填满，至少让单个核组访问的连续地址块不小于 1KB，减少 DMA Channel 空转。

### 3.3 从“每核地址”升级到“核组访问矩阵”

设计 DMA/RMA 前先写出访问矩阵：

```text
addr[core_id][request_id]
```

然后检查每个 `request_id` 对应的 32 个地址集合：

1. 是否 128B 对齐。
2. 是否覆盖足够多的 Channel。
3. 是否存在 128B 粒度空洞。
4. 是否整体落在 256KB 到 512KB 窗口。
5. 是否让同列从核集中抢同一个 DMA engine。
6. 是否会和同阶段 RMA 走同方向、同路径。

只有这个矩阵是健康的，单个从核内部的循环优化才有意义。

## 4. DMA 优化方法

### 4.1 DMA 资源模型

T1 DMA 的几个硬约束：

- 共有 8 个 DMA engine。
- 同一列 4 个从核共享 1 个 DMA engine。
- 每个 DMA engine 同一时刻最多使用约 2 个 HBM Channel。
- 4 到 5 个 DMA engine 可接近打满 HBM，但要达到理论极限需要 8 个 engine 共同工作并映射到不同 HBM Channel。
- DMA 与 RMA 返回/发送路径可能共享从核到 Mesh 的一级连接。
- DMA 请求进入 PPU 后按 128B 包处理。

### 4.2 DMA 目标形态

高性能 DMA 的目标形态是：

```text
base 地址 128B 对齐
bsize = 128B 或 128B 的整数倍
核组同一轮访问覆盖 16 个 Channel
核组同一 tile 总窗口 256KB 到 512KB
单核单次搬运 8KB 到 16KB，或双缓冲场景优先测试 4KB/8KB
outstanding DMA get + put 总数 <= 11
```

### 4.3 推荐的 DMA 设计流程

1. 先确定全局数据布局是否能 128B 对齐。
2. 以 128B 为基本 DMA 块，构造核组级连续访问。
3. 用 `channel = (addr / 128B) % 16` 检查 Channel 分布。
4. 控制每轮核组访问窗口在 256KB 到 512KB。
5. 选择单核 tile：先测 4KB、8KB、16KB，传统模式优先 8KB/16KB，双缓冲优先 4KB/8KB。
6. 对同列 4 个从核的 DMA 发起节奏做错峰，避免同一 DMA engine 瞬时过载。
7. outstanding 请求总数控制在 11 以内，读写合计计数。
8. 用双缓冲把 DMA get、计算、DMA put 分阶段流水化。

### 4.4 奇偶交错 DMA engine 编号

文档指出，为避免交叉开关冲突，应把 DMA engine 按奇偶交错方式重新编号：

```text
0, 2, 4, 6, 1, 3, 5, 7
```

推荐含义：

- 数据划分时不要简单按逻辑列 `0,1,2,3,4,5,6,7` 顺序绑定地址块。
- 让相邻地址块优先分配给物理上更不容易冲突的 engine 顺序。
- 对矩阵行/列 tile 做列向分片时，按奇偶交错顺序安排 DMA 主发起列。

### 4.5 跨步 DMA 模板

当目标是让 32 个从核共同连续覆盖 HBM，可以使用如下抽象模板：

```text
bsize = 128B
group_cores = 32

for tile in tiles:
    for k in local_blocks:
        core_id 访问:
            base + tile_offset + (k * group_cores + core_id) * bsize
```

如果需要按 8 个 DMA engine 分组，可把 `core_id` 映射成：

```text
engine_order = [0, 2, 4, 6, 1, 3, 5, 7]
row_id = core_id / 8
logical_col = core_id % 8
physical_col = engine_order[logical_col]
```

具体代码中要结合实际 threadIdx 到物理行列的映射确认，但核心目标不变：核组同一轮请求在 HBM 地址上连续，DMA engine 在物理上分散。

### 4.6 DMA 队列控制

文档实验显示 DMA 队列长度约为 11，第 12 个连续请求发起拍数明显升高，而且读写共用队列。

推荐策略：

- 每个从核或每组从核维护 DMA outstanding 预算。
- `dma_get + dma_put` 合计不要超过 11。
- 如果使用双缓冲，常见形态是少量 get 预取、当前 buffer 计算、少量 put 写回，而不是一次性发几十个 DMA 再统一等待。
- 小块 DMA 可能因流水线表现出较高带宽波动，调参时不要只看单次结果，要看稳定区间。

### 4.7 DMA 常见反模式

| 反模式 | 问题 | 替代方案 |
| --- | --- | --- |
| 每核连续块划分 | 核组视角地址不连续，Channel/Bank 可能打不满 | 周期划分/跨步划分 |
| 64B + 64B 期待硬件合并 | PPU/DMA 不合并请求，浪费 128B 包 | 每请求 128B 对齐、128B 整倍数 |
| 单列集中发 DMA | 只压一个 DMA engine | 多列分摊，必要时奇偶交错 |
| 一次发几十个 DMA | 超过约 11 队列深度后发起开销升高 | 分批流水，控制 outstanding |
| tile 太小 | Channel/Bank 覆盖不足，启动开销占比高 | 单核优先 4KB/8KB/16KB 测试 |
| tile 太大 | 可能跨 Row，Row open/close 代价上升 | 核组窗口控制在 512KB 内 |

## 5. RMA 优化方法

### 5.1 RMA 资源模型

RMA 基于核间 2D Mesh 网络，主要用于同核组内从核之间通信。

关键事实：

- RMA 是全双工模式。
- 每个节点每个方向一级连接理论上限约 64GB/s。
- 点对点 RMA 在无节点冲突、无线路冲突时实测可接近 63GB/s。
- RMA 广播通常只能达到一级连接极限吞吐的约 80%。
- 节点同时发送和接收时，即使无线路冲突，实测也会下降到约 53GB/s。
- 有线路冲突时可能下降到约 31GB/s。
- 某些场景下 `rma_get` 性能低于 `rma_put`，优先考虑 `rma_put`。

### 5.2 RMA 模式选择

| 通信需求 | 首选模式 | 原因 |
| --- | --- | --- |
| 一对一传输 | `rma_put` 点对点 | 带宽最高，路径可控 |
| 同列数据共享 | 轮询/分阶段点对点 put | 文档中点对点高于列广播 |
| 列广播 | 普通列广播或跨步列广播 | 能利用 8 个 DMA engine，数据量足够时带宽较好 |
| 行广播 | 对角线行广播或双对角线行广播 | 普通行广播可能只用 1 个 DMA engine |
| 全广播 | 谨慎使用 | 容易产生节点/路径拥塞 |

### 5.3 点对点优先原则

如果通信拓扑可以表达为若干一对一传输，优先用 `rma_put` 点对点，而不是广播。

原因：

- 点对点可接近 Mesh 一级连接极限。
- 路径更容易排布和错峰。
- 广播有额外仲裁与复制开销，吞吐通常低于点对点。
- 广播会让更多节点同时下网，容易与 DMA get 返回冲突。

### 5.4 行广播优化

普通行广播的问题是可能只利用一个 DMA engine，带宽低。

优化路径：

1. 使用对角线从核进行行广播，使不同列参与广播。
2. 如果对角线仍未利用全部 DMA engine，把每行广播数据切成两份。
3. 由两列不同从核分别广播，即双对角线行广播。
4. 目标是让 8 个 DMA engine 都参与，带宽接近列广播。

适用场景：

- 行方向有共享数据。
- 数据量足够大，广播启动开销可被摊薄。
- 可以接受把一行数据拆成多个片段后在接收端拼接或分别使用。

### 5.5 列广播优化

列广播天然更容易利用 8 个 DMA engine，但仍要注意数据粒度。

文档实验结论：

- 普通列广播在核组访问总量 `128 * 8K` 时带宽约 182GB/s，低于普通 `dma_get` 的约 230GB/s。
- 模仿 DMA 访存模式做跨步列广播，固定 `stride = 7 * bsize`，`bsize = 256B` 时性能最优。
- 单次跨步列广播中，每列广播数据量不小于 8KB 时，整体带宽明显高于普通列广播。

推荐策略：

```text
列广播优先测试:
bsize = 256B
stride = 7 * bsize
每列数据量 >= 8KB
```

### 5.6 RMA 路径冲突规避

做 RMA 排程时，至少检查三类冲突：

| 冲突类型 | 例子 | 处理 |
| --- | --- | --- |
| 节点发送冲突 | 一个从核同时向多个目的 put | 分批、树形或轮询 |
| 节点收发冲突 | 一个从核同时接收和发送 | 拆阶段，减少同周期双向压力 |
| 路由路径冲突 | 多条 RMA 流经过同一 Mesh 链路 | 选择对角线源、错峰、改变传输顺序 |

RMA 不应只按通信图设计，还要按物理 Mesh 路径设计。相邻通信未必最优，对角线或分组通信有时更能均衡链路。

## 6. DMA 与 RMA 协同优化

### 6.1 判断是否能并行

DMA 与 RMA 能否并行，不能简单回答“能”或“不能”，要看方向和路径。

可并行的典型情况：

- RMA 从本核上网，DMA get 数据从网络下网到本核，方向相反，理论上双工不冲突。
- DMA put 从本核上网，RMA 数据从网络下网到本核，方向相反，理论上双工不冲突。
- DMA/RMA 发生在不同列、不同路由路径，并且目的节点不重叠。

容易冲突的情况：

- RMA put 和 DMA put 都从同一从核上网。
- RMA 广播下发和 DMA get 返回都向同一从核下网。
- 多个 RMA 广播与 DMA 返回共享同一列/同一路由。
- 同列 4 个从核同时压同一个 DMA engine，同时还进行 RMA 下发。

### 6.2 分阶段流水模板

推荐把 kernel 主循环拆成 4 个阶段，并用双缓冲重叠：

```text
阶段 A: DMA get 预取 tile[n + 1] 到 LDM buffer[next]
阶段 B: 计算 tile[n]，使用 LDM buffer[curr]
阶段 C: RMA put/广播 tile[n] 中需要跨核共享的中间数据
阶段 D: DMA put 写回 tile[n - 1] 的结果
```

排程原则：

- DMA get 尽量与计算重叠。
- DMA put 尽量与不使用同一上网方向的 RMA 阶段错开。
- RMA 广播尽量不要和大规模 DMA get 返回同时打到同一批从核。
- 如果 RMA 是点对点 put，可按路由路径分批，让不同批次使用不同链路。
- DMA outstanding 预算仍然按 get+put 合计不超过 11 控制。

### 6.3 LDM 双缓冲与 ACE/SIMD 协同

虽然本文重点是 DMA/RMA，但访存优化必须服务计算流水：

- SIMD 寄存器宽 512 bit，完全流水时每周期需要较高 LDM 带宽。
- ACE 西向理想带宽约 80GB/s，北向等效带宽在典型 128 行场景下约 20GB/s。
- ACE 累加器有两个 8KB 缓冲区，可通过 writeback 与计算双缓冲。

因此 LDM buffer 规划建议：

```text
buffer0: 当前计算输入
buffer1: 下一 tile 的 DMA get 目标
buffer2: 上一 tile 的 DMA put 源，或 ACE writeback 目标
rma_buffer: 跨核共享数据暂存区，避免与 DMA buffer 复用同一热点 Bank
```

如果 LDM 空间紧张，优先保证：

1. 当前计算数据不被 DMA/RMA 覆盖。
2. DMA get 目标和 DMA put 源分离。
3. RMA 接收区和 SIMD/ACE 正在读取的数据分离。

## 7. 面向算子的访存设计套路

### 7.1 连续输入张量读取

适合场景：LayerNorm、Elementwise、Reduction 前的连续读。

推荐：

- 全局 base 128B 对齐。
- 以 128B 为最小搬运块。
- 周期划分到 32 个从核。
- 单核每轮 8KB 或 16KB。
- 核组窗口 256KB 或 512KB。
- DMA get 后在 LDM 内做多次计算复用，再 DMA put 写回。

### 7.2 矩阵按行/列读取

适合场景：GEMM、Attention、转置类访问。

推荐：

- 如果自然布局导致单核连续、核组不连续，改成跨步 DMA。
- 让 32 个从核同一轮覆盖连续 HBM 地址。
- 对 B 矩阵这类跨核复用数据，优先评估点对点 RMA put 轮询，而不是直接列广播。
- 行广播性能不理想时使用双对角线行广播。
- 列广播数据量不足 8KB/列时，不要期望广播带宽接近 DMA。

### 7.3 小块非连续读取

适合场景：Gather、索引选择、稀疏访问。

推荐：

- 尽量在上游重排数据，让 DMA 请求聚合成 128B。
- 无法重排时，把多个小元素在同一从核内凑成 128B 请求。
- 如果小块之间的空洞能被其他从核填满，可使用跨步 DMA。
- 如果核组视角仍然稀疏，应降低对 HBM 带宽的预期，重点优化计算/通信重叠。

### 7.4 跨核共享中间结果

适合场景：Reduction、归一化统计量、分块 GEMM partial sum。

推荐：

- 小数据量共享优先用点对点 RMA put 或分层 reduction。
- 大数据量同列共享可测试跨步列广播。
- 行共享避免普通行广播，优先对角线或双对角线。
- 对 reduction 类操作，减少全广播次数，采用树形归约 + 必要范围广播。

## 8. 调参优先级

建议按以下顺序调参，避免一开始陷入局部优化：

1. 检查全局数据 base 是否 128B 对齐。
2. 检查每个 DMA 请求是否为 128B 整数倍。
3. 画出 32 核同一轮访问矩阵，确认核组视角连续。
4. 用 `(addr / 128B) % 16` 检查 Channel 覆盖。
5. 把单核 tile 设为 8KB，测基线。
6. 测 4KB、8KB、16KB，确认是否双缓冲场景更适合 4KB/8KB。
7. 检查 outstanding DMA 总数是否超过 11。
8. 检查 DMA engine 是否只集中在少数列。
9. 对 engine 列顺序尝试 `0,2,4,6,1,3,5,7`。
10. 检查 RMA 是否与 DMA 同方向抢同一节点连接。
11. 将 RMA 广播改成点对点 put、对角线广播或双对角线广播。
12. 最后再做 SIMD/ACE 指令流水、寄存器和循环展开优化。

## 9. 性能诊断清单

当 DMA 带宽低时，按下面顺序排查：

- 是否 128B 对齐。
- 请求大小是否小于 128B 或不是 128B 整倍数。
- 核组同一轮地址是否有 128B 粒度空洞。
- 是否只覆盖少数 Channel。
- 单核 tile 是否低于 4KB 或远超 16KB。
- 核组窗口是否超过 512KB 导致 Row 切换。
- 是否只有 1 到 2 个 DMA engine 在工作。
- 同列 4 个从核是否同时挤压同一个 DMA engine。
- DMA get + put outstanding 是否超过 11。
- DMA 是否与 RMA 在同一方向抢从核一级连接。

当 RMA 带宽低时，按下面顺序排查：

- 是否使用了 `rma_get`，能否改为 `rma_put`。
- 是否广播可改为点对点或分阶段点对点。
- 源节点是否一发多收导致发送节点瓶颈。
- 目的节点是否同时接收多路数据导致下网瓶颈。
- 节点是否同时发送和接收。
- 多条 RMA 路径是否共享同一 Mesh 链路。
- 行广播是否只使用了一个 DMA engine。
- 列广播每列数据量是否不足 8KB。
- RMA 广播是否与 DMA get 返回同时下发到同一批从核。

当计算没有吃满时，按下面顺序排查：

- DMA get 是否能被计算隐藏。
- DMA put/writeback 是否和下一轮计算重叠。
- LDM buffer 是否发生 Bank/半双工冲突。
- SIMD load/store 与计算是否形成双发射。
- ACE writeback 是否使用双缓冲。
- RMA 接收区是否覆盖或阻塞当前计算输入。

## 10. 推荐参数表

| 参数 | 默认建议 | 备注 |
| --- | --- | --- |
| DMA 基本块 | 128B | 与 PPU 包粒度匹配 |
| DMA 地址对齐 | 128B | 至少不要低于 32B 对齐 |
| 单核传统 DMA tile | 8KB 或 16KB | 对应核组 256KB 或 512KB |
| 单核双缓冲 tile | 4KB 或 8KB | 实测双缓冲读写较优 |
| 核组访问窗口 | 256KB 到 512KB | 打满 Channel/Bank 且避免跨 Row |
| 全 Channel 覆盖块 | 2KB | `128B * 16` |
| DMA outstanding | <= 11 | get+put 合计 |
| DMA engine 顺序 | 0,2,4,6,1,3,5,7 | 避免交叉开关冲突 |
| 列广播 bsize | 256B | 文档实验中较优 |
| 列广播 stride | `7 * bsize` | 跨步列广播实验配置 |
| 列广播数据量 | 每列 >= 8KB | 数据量不足时启动/拥塞开销明显 |
| RMA 点对点 | 优先 `rma_put` | 多数场景比 `rma_get` 和广播可控 |

## 11. 一句话方法论

T1 上 DMA/RMA 优化的本质是：

```text
用核组视角组织连续 128B 包，
让 16 个 HBM Channel 和 Bank 并行工作，
把单核 tile 控制在 4KB 到 16KB 的高效区间，
用不超过 11 个 outstanding DMA 做双缓冲流水，
用 rma_put 和对角线/双对角线广播规避 Mesh 路径冲突，
并把 DMA 与 RMA 的上网/下网方向错开。
```

只要一个方案同时满足“HBM 地址集合连续、DMA engine 分散、Mesh 路径不冲突、LDM buffer 可双缓冲”这四个条件，通常就具备接近 T1 高带宽区间的基础。

## 12. 理论分析补充

前面的章节给出了可执行规则，本节补充这些规则背后的理论模型。T1 的访存优化可以抽象成一个多级排队网络：

```text
LDM <-> SPE 一级连接 <-> Mesh/RMA 路由 <-> DMA engine <-> PPU/MC <-> HBM Channel/Bank/Row
```

任意一次数据搬运的有效带宽都受这条路径上最窄一级限制：

```text
BW_effective = min(
    BW_LDM_port,
    BW_SPE_mesh_link,
    BW_mesh_path,
    BW_DMA_engine,
    BW_PPU_MC,
    BW_HBM_channel_bank_row
) * efficiency
```

其中 `efficiency` 又由对齐、包利用率、Channel/Bank 覆盖率、Row 命中率、队列深度、冲突概率共同决定。优化的本质不是把某一个局部带宽做到最大，而是让多个层级的利用率同时接近最优，并避免某一级突然变成瓶颈。

### 12.1 HBM 带宽上界模型

文档给出的 HBM 理论带宽为：

```text
BW_HBM_peak = 1024 bit / 8 * 3.2GHz = 409.6GB/s
BW_HBM_sustained ~= 409.6GB/s * 80% = 327.68GB/s
```

这里的 80% 可以理解为 DRAM 时序、命令开销、Row open/close、仲裁和非满载访问造成的综合效率。实际 DMA 需要满足以下条件才可能接近该上界：

```text
channel_utilization ~= 1
bank_parallelism ~= 1
row_switch_penalty ~= low
packet_efficiency ~= 1
dma_engine_utilization ~= high
```

可以把实际 HBM 侧效率拆成：

```text
BW_HBM_actual =
    BW_HBM_peak
  * E_cmd
  * E_channel
  * E_bank
  * E_row
  * E_packet
```

各项含义：

| 因子 | 含义 | 典型退化原因 |
| --- | --- | --- |
| `E_cmd` | 命令/仲裁效率 | 请求过碎、队列断流 |
| `E_channel` | 16 个 Channel 覆盖率 | 地址空洞、映射集中 |
| `E_bank` | Channel 内 Bank 并行度 | stride 命中少数 Bank |
| `E_row` | Row Buffer 效率 | 核组窗口过大、频繁跨 Row |
| `E_packet` | 128B 包有效载荷 | 64B/小包访问、非对齐 |

因此当带宽从 300GB/s 附近掉到 150GB/s 附近时，不应只怀疑 HBM 峰值不够，而应逐项判断是 `E_channel`、`E_packet`、`E_row` 还是 Mesh/DMA engine 侧先掉了。

### 12.2 128B 包效率推导

DMA 进入 PPU 后以 128B 包为基本处理单位。若一次请求的有效载荷为 `payload`，且硬件不合并多个从核的小请求，则包效率近似为：

```text
E_packet = payload / ceil(payload / 128B) / 128B
```

例子：

| 请求大小 | PPU 包数 | 包效率 |
| --- | --- | --- |
| 4B | 1 | 3.125% |
| 32B | 1 | 25% |
| 64B | 1 | 50% |
| 128B | 1 | 100% |
| 192B | 2 | 75% |
| 256B | 2 | 100% |

这解释了为什么“两个从核各访问 64B 且地址连续”不能等价于“一个 128B 请求”。只要请求在 PPU 前没有被合并，就会形成两个 128B 包，各自只有 50% 有效载荷。

结论：

- 单请求小于 128B 时，带宽损失是确定性的。
- 128B 对齐只是下限，最好同时保证请求长度为 128B 整数倍。
- 如果算法天然是小粒度访问，应先在 LDM 或上游布局中聚合，再发 DMA。

### 12.3 Channel 覆盖率推导

Channel 映射为：

```text
channel = (address / 128B) % 16
```

对一个核组同一轮发起的地址集合：

```text
A = {addr_i | i in active_requests}
```

定义该轮 Channel 覆盖数：

```text
C = count_unique((addr_i / 128B) % 16)
E_channel ~= C / 16
```

如果 32 个从核每个发起一个 128B 请求，理想情况是 32 个请求覆盖两个完整的 16 Channel 周期：

```text
addr_i = base + i * 128B
channel_i = i % 16
```

此时：

```text
C = 16
E_channel ~= 1
```

如果块划分导致同一时间只有少数从核在相邻地址上推进，或所有从核地址低位模式相同，就可能出现：

```text
C << 16
E_channel << 1
```

这就是“单核连续不等于核组连续”的理论原因。T1 DMA 性能主要由核组同一时间片的地址集合决定，而不是由每个从核自己的地址序列单独决定。

### 12.4 256KB 到 512KB 窗口推导

文档中给出两个经验边界：

```text
低 18 位地址空间 = 256KB
低 19 位地址空间 = 512KB
```

可以理解为：

- 使用至少 256KB 的核组窗口，才能让 Channel、Bank、Bank Group 的低位映射充分展开。
- 控制在 512KB 以内，尽量避免跨 Row 或显著增加 Row open/close。

平均到 32 个从核：

```text
256KB / 32 = 8KB
512KB / 32 = 16KB
```

因此得到传统 DMA 的单核 tile 甜点区间：

```text
8KB <= tile_per_core <= 16KB
```

如果 tile 小于 8KB，核组窗口可能不足以充分展开 Bank/Channel，启动和仲裁开销占比也更高。如果 tile 大于 16KB，虽然单次搬运更大，但更容易跨 Row，Row 切换开销可能抵消大块收益。

这不是说 4KB、32KB、64KB 一定差，而是说它们需要额外条件：

- 4KB 需要更好的流水重叠、更低延迟、更高请求并发来弥补窗口不足。
- 32KB 及以上需要确认 Row 切换没有成为主瓶颈，或访问模式仍能保持高 Row 命中。

### 12.5 DMA engine 上界模型

每个 DMA engine 同一时刻最多使用约 2 个 HBM Channel。理想情况下 8 个 engine 可覆盖：

```text
8 engines * 2 channels/engine = 16 channels
```

这正好对应 HBM 的 16 个逻辑 Channel。

如果只有 `N` 个 DMA engine 有效工作，则 Channel 侧上界近似为：

```text
C_max = min(16, 2 * N)
E_engine_channel <= C_max / 16
```

例如：

| 有效 DMA engine 数 | 理论最多覆盖 Channel | Channel 侧上界 |
| --- | --- | --- |
| 1 | 2 | 12.5% |
| 2 | 4 | 25% |
| 4 | 8 | 50% |
| 5 | 10 | 62.5% |
| 8 | 16 | 100% |

文档中提到 4 到 5 个 DMA 可把 HBM 带宽打满，说明实际硬件中 DMA engine 和 MC/PPU 之间还有额外调度、预取和队列效应，上表不是实测带宽公式，而是一个保守覆盖模型。它的价值在于解释为什么普通行广播只用一个 DMA engine 时会明显吃亏，以及为什么双对角线行广播能靠动员更多列来提升带宽。

### 12.6 Mesh/RMA 上界模型

Mesh 单链路原始双工带宽为：

```text
BW_mesh_raw = 2.5GHz * 256bit / 8 = 80GB/s
```

考虑包头开销后：

```text
BW_mesh_payload = 80GB/s * 4 / 5 = 64GB/s
```

RMA 点对点无冲突实测约 63GB/s，与该理论值吻合，因此可以把 64GB/s 视作单节点单方向一级连接的有效上界。

RMA 带宽可近似建模为：

```text
BW_RMA = min(
    BW_src_injection,
    BW_dst_ejection,
    min(BW_link_on_path),
    BW_LDM_interface
) * E_route * E_mode
```

其中：

- `BW_src_injection` 是源节点上网能力。
- `BW_dst_ejection` 是目的节点下网能力。
- `BW_link_on_path` 是路径中每条 Mesh 链路的可用带宽。
- `E_route` 由路径重叠、路由仲裁决定。
- `E_mode` 由点对点、行广播、列广播、全广播模式决定。

文档实测现象可由该模型解释：

| 场景 | 实测/现象 | 理论解释 |
| --- | --- | --- |
| 只发不收、无线路冲突 | 约 63GB/s | 接近单方向一级连接上界 |
| 同节点发送和接收、无线路冲突 | 约 53GB/s | 双工链路存在 LDM/控制器隐式共享瓶颈 |
| 有线路冲突 | 约 31GB/s | 多流共享 Mesh 链路，路径带宽被分摊 |
| 广播低于点对点 | 广播约为极限 80% 或更低 | 复制、仲裁、多目的下网增加开销 |

### 12.7 DMA/RMA 冲突矩阵

DMA 和 RMA 的并行性可以用“方向 + 节点 + 路径”三元组判断：

```text
flow = (node, direction, mesh_path)
direction in {up_to_mesh, down_from_mesh}
```

两条 flow 是否冲突：

| 条件 | 冲突风险 |
| --- | --- |
| 同 node、同 direction | 高 |
| 同 node、反 direction | 中，理论双工但可能有 LDM/控制器瓶颈 |
| 不同 node、路径共享链路 | 中到高，取决于重叠链路数量 |
| 不同 node、路径不重叠 | 低 |
| DMA get 返回与 RMA 广播下发到同一批节点 | 高 |
| DMA put 上网与 RMA put 从同一批节点发出 | 高 |

因此能否重叠 DMA/RMA，不应只看 API 是否异步，而应画出每个阶段的 flow 集合：

```text
DMA_get:  HBM -> DMA -> Mesh -> SPE down
DMA_put:  SPE up -> Mesh -> DMA -> HBM
RMA_put:  SPE up -> Mesh path -> SPE down
RMA_bcast: SPE up -> Mesh tree/path -> many SPE down
```

如果两个阶段都主要占用 `SPE down`，就算一个是 DMA、一个是 RMA，也会冲突。反过来，如果一个主要上网、一个主要下网，且目的节点不同，就更适合重叠。

### 12.8 队列深度与流水线模型

DMA 队列长度约为 11，读写共用队列。可以把 DMA 发起和完成抽象成有限容量队列：

```text
Q_capacity = 11
Q_occupancy = outstanding_get + outstanding_put
```

当：

```text
Q_occupancy < Q_capacity
```

发起 DMA 的成本较低，硬件可以流水化处理。当：

```text
Q_occupancy >= Q_capacity
```

新请求需要等待队列空位，发起开销显著升高。

因此双缓冲不是“尽可能多发 DMA”，而是控制队列处于高但未满的状态：

```text
prefetch_depth + writeback_depth <= 11
```

一个可解释的流水效率模型是：

```text
T_tile = max(T_dma_get, T_compute, T_rma, T_dma_put) + T_sync + T_conflict
```

理想重叠时，tile 时间接近最长阶段；重叠失败时，变成：

```text
T_tile = T_dma_get + T_compute + T_rma + T_dma_put + T_sync
```

所以优化目标是：

1. 通过 tile 调整让 `T_dma_get`、`T_compute`、`T_dma_put` 尽量接近。
2. 通过方向错开降低 `T_conflict`。
3. 通过队列控制降低 `T_sync` 和队列阻塞。

### 12.9 广播与点对点的理论比较

假设一个源节点要把大小为 `S` 的数据发送给 `K` 个目的节点。

点对点轮询的总注入数据量：

```text
Traffic_inject_p2p = K * S
```

广播的源注入数据量理论上可低于 `K * S`，但会增加网络中间复制、路由仲裁和多目的下网压力：

```text
BW_bcast = min(BW_src, sum_path_capacity, sum_dst_ejection) * E_bcast
```

如果 `K` 较大且路径分布均匀，广播可能更有优势；但在 T1 文档的实测中，点对点 128KB 可到约 58GB/s，行/列广播约 34GB/s，说明广播模式的 `E_bcast` 和下网/仲裁开销在这些场景下占主导。

由此得到策略：

- 小规模共享、固定邻居通信：点对点 put 优先。
- 多目的、大块、路径均匀：测试广播。
- 行广播只用少数 engine 时：用对角线/双对角线人为提升 engine 并行度。
- 列广播数据不足 8KB/列时：广播启动和仲裁开销难以摊薄。

### 12.10 算子级理论设计模板

设计一个 T1 kernel 的访存时，可以按下面的理论模板推导，而不是直接试参：

1. 计算单 tile 数据量：

```text
bytes_per_core = input_bytes + output_bytes + rma_bytes
bytes_per_group = 32 * bytes_per_core
```

2. 检查 HBM 窗口：

```text
256KB <= dma_bytes_per_group <= 512KB
```

如果不满足，优先调整 tile 或改周期划分。

3. 检查 DMA 包效率：

```text
all dma_addr % 128B == 0
all dma_size % 128B == 0
```

4. 检查 Channel 覆盖：

```text
unique((dma_addr / 128B) % 16) == 16
```

5. 检查 DMA engine 覆盖：

```text
active_engines 接近 8
同列请求不过度集中
```

6. 检查 DMA/RMA flow 冲突：

```text
同阶段避免:
DMA_get_down 与 RMA_bcast_down 打到同一节点集合
DMA_put_up 与 RMA_put_up 来自同一节点集合
```

7. 估计 tile 时间：

```text
T_dma_get = bytes_get / BW_dma_get_expected
T_compute = ops / compute_throughput
T_rma = bytes_rma / BW_rma_expected
T_dma_put = bytes_put / BW_dma_put_expected
T_tile ~= max(...) + sync/conflict
```

8. 如果 `T_dma_get` 最大，优先优化 HBM/DMA 地址布局；如果 `T_rma` 最大，优先优化通信拓扑；如果 `T_compute` 最大，再做 SIMD/ACE 指令级优化。

### 12.11 理论结论

T1 上的访存理论可以归纳为三个层次：

1. HBM 层：用 128B 包、2KB Channel 周期、256KB 到 512KB 核组窗口，让 Channel/Bank 并行且少跨 Row。
2. DMA/Mesh 层：用 8 个 DMA engine、奇偶交错、队列深度控制，让 DMA 持续供给但不拥塞。
3. RMA/协同层：用 `rma_put`、路径错峰、对角线/双对角线广播，让核间通信避开节点和链路热点，并与 DMA 上下网方向错开。

如果只满足第一层，通常只能得到不错的 DMA 带宽；如果同时满足第二层，才可能接近 HBM 高带宽；如果第三层也满足，才能在真实算子中把 DMA、RMA 和计算稳定重叠起来。
