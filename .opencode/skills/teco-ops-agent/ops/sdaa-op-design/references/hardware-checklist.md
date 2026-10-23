# T1 硬件一致性检查清单

设计文档生成或评审时，除 schema 字段完整外，还必须逐项检查以下硬件一致性。若某项不适用，要写明原因。

## 1. 建模口径

- SPE 频率使用 2.36GHz；ACE 使用 1.18GHz。
- DMA GET 使用 256GB/s，DMA PUT 使用 331GB/s，读写阶段分开计时。
- 如果引用 2.5GHz 文档数据，已按 `2.36/2.5=0.944` 缩放。
- 理论上界和目标效率有折扣来源说明，不只填峰值。

## 2. DMA 与全局访存

- 每个主要 tensor 的 global 访问模式已标注：连续、stride、gather/scatter 或重排后访问。
- 对可重排输入，优先评估 stride DMA；不要默认连续 DMA 更快。
- DMA 基本传输块按 128B 包效率设计；64B 或更小块已解释损耗。
- stride DMA 候选检查了 `bsize=128B/256B`、`stride=1024B/2048B`、DMA 引擎顺序 `{0,2,4,6,1,3,5,7}` 等形态。
- 核组访问矩阵覆盖 32 SPE，说明每个 PAIU/DMA 引擎负责的数据量。
- DMA outstanding 的 get+put 队列深度不超过 11，双缓冲不会把队列打满。

## 3. LDM 与 Bank

- `usable_budget_bytes` 不超过约 235KB，且小于 256KB 物理容量。
- A/B/C/临时 buffer/双缓冲/stage buffer/栈余量都进入 LDM 预算。
- 左右两个 128KB bank 的容量和读写压力分别列出。
- 双缓冲开启时，说明哪个 bank 承载 DMA、哪个 bank 承载 compute，以及是否会同 bank 争用。

## 4. ACE

- GEMM/Linear 的 `M/N/K` 分块满足 ACE 32 粒度；K 维按 32 对齐或有尾部方案。
- west 方向单次行数不超过 128。
- north/west load、`rt_ace_load_west`、writeback 的顺序已写入 pipeline。
- writeback dtype 与数值精度风险已说明；half writeback 不能在需要 fp32 结果时默认启用。
- 若使用 ACE_WEST_STRIDE 或特殊 LDM 布局，说明 API 侧 stride 语义和数据排布来源。

## 5. SIMD / EBOX

- SIMD load/store 满足 64B 对齐；尾部路径明确。
- 热循环有 P0 compute / P1 load-store 交错安排。
- `floatv16`/`shortv32` 等向量宽度与展开倍数匹配，不让展开破坏寄存器或 LDM 压力。
- half/bfloat16 输入的累计精度已说明，规约类默认用 fp32 累加。
- sqrt/div/exp/log 等高成本指令在 stage time 中有折扣或替代方案。

## 6. RMA / 通信

- 通信方向写清：行/列/对角线、上/下、东/西、发送端/接收端。
- 优先评估 `rma_put`；如果使用 get 或广播，说明原因。
- 已检查 DMA GET 向下、DMA PUT 向上、RMA PUT 向上、RMA broadcast 接收方向是否冲突。
- 行广播未直接用单 DMA 引擎热点；若必须使用，写明数据量和同步代价。
- reduce-scatter、ring-P2P 或双对角线策略有同步点和稳态阶段说明。

## 7. Pipeline 与同步

- fill / steady / drain 三段时间可解释。
- steady state 主导阶段明确：DMA GET、DMA PUT、ACE/SIMD、RMA、sync 中哪一个主导。
- 双缓冲 overlap 写清楚 producer/consumer、wait point 和失效条件；范围覆盖 DMA、RMA、SIMD、ACE，不只写 DMA ping-pong。
- 若 SIMD 与 ACE 可并行，说明 SIMD epilogue/规约/cast/pack 与 ACE 主计算的交错排布；若不可并行，说明依赖或 LDM bank 冲突。
- 若访存性能足够而 tile 被拆小，说明拆小带来的 overlap 收益、额外同步/issue delay 代价和 LDM buffer 增量。
- 每轮同步次数和同步粒度不会抵消 tile 放大带来的收益。

## 8. 输出门禁

设计通过前必须能回答：

- 这个方案为什么符合当前 T1 实机口径。
- 为什么选这个 tile、分核和数据布局。
- stride DMA、LDM bank、ACE/SIMD、RMA 路径中哪一项最可能限制性能。
- 如果性能低于模型，首先要 profile 哪三个计数或阶段。
