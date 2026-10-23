# SDAA Kernel Optimization Catalog

本目录按优先级驱动 `teco-kernel-optimizer` 的方法选择。每轮优化必须从 P1 开始向下扫描，并把命中的 `id` 写入 `iterv{i}/methods.json`。除非当前 kernel 结构已经根本改变，`ineffective_methods` 中的方法不得重复选择。

## Selection Rules

- 先消除不该执行的计算，再优化必须执行的指令。
- 优先使用硬件能力替代软件循环：DMA stride 优先于标量搬运，SIMD 向量操作优先于逐元素标量循环。
- 所有 SIMD 主循环都必须使用 `aligned = size & ~15`，主循环条件为 `i < aligned`，尾循环范围为 `[aligned, size)`。
- 每个方法必须记录触发证据、跳过原因、硬件约束检查和预期 benchmark 变化。
- 组合方法时必须检查 SPM/LDM buffer 边界、DMA outstanding 数量、同步依赖和 causal/decode 分支正确性。

## Combining Rules

- `latency.causal_block_early_skip` 可与 DMA、SIMD、matmul tile 和 softmax 方法组合，通常优先放在循环顶部。
- `memory.strided_dma_bulk_transfer` 与 `memory.dma_double_buffer_kv` 可组合，但必须重新检查 DMA 队列压力和 wait/sync 位置。
- `memory.spm_buffer_reuse` 只在 buffer 生命周期互斥且最大尺寸覆盖较小复用方时启用。
- `compute.matmul_block_config_align` 应先确定 BM/BN/BK，再评估 SPM 复用、双缓冲和 loop unroll。
- `algorithm.online_softmax_fp32` 是 attention 类 kernel 的数值约束方法；不要为了局部速度牺牲跨 block 重缩放正确性。
- `latency.decode_q1_specialization` 应作为 q_seq_len=1 的专用路径，不应破坏 prefill 或通用路径。

## P1 - Highest Priority

### latency.causal_block_early_skip

- Axis: `latency`
- Trigger: causal mask attention 中存在 KV block 循环，且部分 block 对当前 Q tile 完全不可见。
- Change: 在 KV block 循环顶部用 Q/KV block 边界判断整块是否被 mask；完全被 mask 的 block 直接 `continue`，跳过无效 GEMM、softmax、V GEMM 和 store 相关工作。
- Skip condition: 非 causal 场景；mask 不是块级可判定；跳过会改变 dropout、统计或 side-effect 语义。
- Constraints: block 边界必须与真实 sequence offset、cache offset、page/block table 一致；partial mask block 仍需走正常路径。
- Expected effect: 对 causal/prefill 或带长 KV cache 的场景通常是最高收益方向，因为它减少计算总量而不是只降低单指令成本。

### memory.strided_dma_bulk_transfer

- Axis: `memory`
- Trigger: 代码中出现串行 DMA、小块循环 DMA、标量 transpose、gather/scatter 或逐元素 layout 转换。
- Change: 将可表达为二维/固定步长访问的加载、转置、gather/scatter 改为 `memcpy_stride` 或等价 stride DMA 批量搬运；把多次串行 DMA 合并成批量 strided DMA。
- Skip condition: 地址不规则且 stride 无法静态或低成本计算；搬运粒度太小导致 DMA setup 成本高于收益；存在未满足的对齐约束。
- Constraints: 检查 DMA 4B 最小对齐、推荐 16B/64B/128B 对齐、源/目的 stride、边界、队列深度和 wait 位置。
- Expected effect: 用硬件 DMA 引擎替代软件标量循环，尤其适合 transpose 和 cache layout 整理。

### compute.simd_vectorized_bulk_ops

- Axis: `compute`
- Trigger: 内存初始化、fill、elementwise、reduction 局部累加、mask 写入或 scaling 使用逐元素标量循环。
- Change: 使用 `floatv16` 或 `halfv16` 批量处理，每批 16 元素；主循环处理 aligned 部分，尾部用标量循环。
- Skip condition: 数据布局无法连续读取 16 元素；类型转换或掩码语义无法向量化；向量化会引入未对齐越界访问。
- Constraints: 主循环必须是 `for (i = 0; i < aligned; i += 16)`，其中 `aligned = size & ~15`；尾循环必须从 `aligned` 到 `size`。
- Expected effect: 对 fill、初始化、softmax 预处理、reduction 局部步骤和简单 elementwise 通常有稳定收益。

## P2 - Strong Candidates

### compute.aligned_simd_tail_loop

- Axis: `compute`
- Trigger: SIMD 主循环使用 `i < size`，或尾循环错误使用 `i < size % 16` 之类条件。
- Change: 统一改为 `aligned = size & ~15`；SIMD 主循环范围 `[0, aligned)`；标量尾循环范围 `[aligned, size)`。
- Skip condition: 没有 SIMD 循环；size 已保证是 16 的整数倍且有明确断言。
- Constraints: 不得在 SIMD load/store 中访问 `[size, aligned + 15]` 之外的数据；mask tail 与 scalar tail 二选一，优先使用简单 scalar tail 保正确性。
- Expected effect: 主要修复性能和正确性风险；也让后续向量化方法可组合。

### algorithm.online_softmax_fp32

- Axis: `compute`
- Trigger: attention/softmax 跨 KV block 累积，存在每块局部 softmax 后再合并、FP16 sum、或重新扫描全量 score 的实现。
- Change: 使用 FP32 accumulator 跨 block 维护每行 `m` 和 `l`，每个 KV block 更新 row max 与 row sum，并按新旧 max 关系重缩放输出累加器。
- Skip condition: softmax 不跨 block；已有等价 online softmax；精度需求或接口明确使用其他算法。
- Constraints: `m`、`l` 和输出 accumulator 必须保持 FP32；masked block 不得污染 `m/l`；causal early-skip 后 partial block 仍要正确参与重缩放。
- Expected effect: 保持精度同时减少额外 pass 和中间存储，是 attention 类 kernel 的基础算法优化。

### compute.matmul_block_config_align

- Axis: `compute`
- Trigger: GEMM/attention QK/V matmul tile 与硬件 `MatmulBlockConfig` 不匹配，尤其未利用 `M128_N32` 类配置。
- Change: 根据硬件 matmul block 配置选择 BM/BN/BK，使 GEMM tile 与 ACE/矩阵加速器的 M/N/K 方向对齐。
- Skip condition: kernel 不使用 ACE/matmul 加速；shape 太小导致对齐 tile 带来过多空算；已有生产实现证明当前 tile 更优。
- Constraints: 检查 K 方向倍数、LDM/SPM 容量、accumulator 大小、core partition、tail tile 和 causal/decode 分支。
- Expected effect: 提升矩阵加速器利用率，减少 tile mismatch 带来的低效计算。

### memory.dma_double_buffer_kv

- Axis: `memory`
- Trigger: attention/GEMM 类 KV block 循环中，当前 block DMA 加载完成后才开始计算，下一个 block 未提前 prefetch。
- Change: 使用双缓冲在计算当前 KV block 时预取下一个 KV block；在 buffer index 间 ping-pong，并把 wait 放在消费前。
- Skip condition: 工作集太小，DMA 不在瓶颈；SPM/LDM 容量不足以容纳双份 K/V tile；已有异步 pipeline。
- Constraints: 检查 DMA queue budget、buffer 生命周期、同步顺序、tail block、early-skip 对 prefetch 顺序的影响。
- Expected effect: 隐藏 DMA latency，适合 KV cache 长、每块计算量足以覆盖搬运延迟的场景。

## P3 - Shape-Specific And Capacity Optimizations

### memory.spm_buffer_reuse

- Axis: `memory`
- Trigger: SPM/LDM 占用限制 tile size 或阻止双缓冲，且存在生命周期互斥的临时 buffer。
- Change: 复用临时 buffer，例如 `vbuf` 复用 `kbuf`，`outO` 复用 `outc`，降低峰值 SPM 占用。
- Skip condition: buffer 生命周期重叠；复用方大小超过被复用 buffer；地址别名会破坏后续读取。
- Constraints: 必须列出每个 buffer 的 byte size、alignment、生产点和最后消费点；复用范围内不得越界。
- Expected effect: 释放 SPM 以支持更大 tile、双缓冲或更多 accumulator。

### compute.v_gemm_unroll_head128

- Axis: `compute`
- Trigger: attention V GEMM 的 `head_size == 128`，内层固定可分为 4 次 32 元素或等价 tile 迭代。
- Change: 将 V GEMM 固定循环展开为 4 次迭代，让编译器更容易优化寄存器分配、地址计算和指令调度。
- Skip condition: head_size 动态或不等于 128；展开导致寄存器压力明显上升；已有模板/宏完成等价展开。
- Constraints: 保持 tail/head_size 泛化路径；不要把 q_seq_len 或 KV block tail 假设硬编码到通用路径。
- Expected effect: 对常见 head_size=128 attention decode/prefill 路径降低 loop overhead 和地址计算成本。

### latency.decode_q1_specialization

- Axis: `latency`
- Trigger: decode 场景 `q_seq_len == 1` 与 prefill 共享通用 BM tile，导致大量无效计算和 SPM 占用。
- Change: 增加 decode 专用分支，`BM=1` 或等价单 query tile，减少无效 row 计算、临时 buffer 和 softmax 工作量。
- Skip condition: 该 kernel 只服务 prefill；dispatch 层已将 decode 路由到专用 kernel；分支判断成本超过收益。
- Constraints: 分支选择必须基于真实 q length；保持通用路径正确；检查 BM=1 下 vector/reduction 和 DMA tile 的 tail 逻辑。
- Expected effect: 对 decode q=1 场景通常显著降低 latency 和 SPM 压力。

### memory.transpose_gather_scatter_dma_stride

- Axis: `memory`
- Trigger: transpose、cache reorder、page gather/scatter 使用嵌套标量循环或按元素 DMA。
- Change: 把规则 stride 的二维搬运改写为 stride DMA；对不规则页表先按连续段聚合，再批量搬运。
- Skip condition: gather/scatter 完全随机且无法聚合；数据依赖要求逐元素计算；stride DMA API 不能表达目标布局。
- Constraints: 对齐、stride、extent、bank/channel 访问模式和 DMA completion 必须明确；边界 tile 需要单独处理。
- Expected effect: 减少 pipe 指令和标量 load/store 压力，尤其适合 transpose 优化。

## P4 - General Cleanup After Higher Priority Work

### memory.serial_dma_to_batched_dma

- Axis: `memory`
- Trigger: 循环内有多次相邻或固定间隔的小 DMA 请求，且没有利用批量搬运。
- Change: 合并为更大粒度 DMA 或 stride DMA，减少 DMA setup 和同步次数。
- Skip condition: 每次 DMA 地址依赖前一次计算结果；合并后超出 SPM buffer；会增加无效搬运过多。
- Constraints: 合并后仍需满足 alignment、capacity、queue depth 和 wait/sync 规则。
- Expected effect: 降低 DMA 管理开销，提高有效带宽。

### compute.scalar_reduction_to_vector_reduction

- Axis: `compute`
- Trigger: reduction 使用标量累加，尤其是 softmax max/sum、norm sum、block 内统计。
- Change: 使用 `floatv16` 局部向量归约，最后再水平规约到标量或行级 accumulator。
- Skip condition: reduction 维度很小；已有 ACE/SIMD 专用实现；向量化会破坏数值顺序要求。
- Constraints: FP32 accumulator 优先；tail 范围 `[aligned, size)`；注意 NaN/mask 语义。
- Expected effect: 提升 reduction 吞吐，减少标量循环时间。

## Attention-Specific Priority Reminder

对 causal attention，优化顺序应默认是：

1. `latency.causal_block_early_skip`: 让整块被 mask 的 KV block 根本不执行。
2. `memory.strided_dma_bulk_transfer` / `memory.transpose_gather_scatter_dma_stride`: 用 DMA stride 替代标量转置和搬运。
3. `compute.simd_vectorized_bulk_ops`: 用 SIMD 替代逐元素 fill、mask、reduction 和初始化。
4. `algorithm.online_softmax_fp32`: 用 FP32 `m/l` 保持跨 block softmax 精度。
5. `memory.dma_double_buffer_kv`: prefetch 下一个 KV block，与当前 block 计算重叠。
6. `latency.decode_q1_specialization`: q_seq_len=1 时使用 decode 专用分支。

最有效的优化通常不是让每条指令更快，而是让不该执行的计算根本不执行；其次是用 SDAA 硬件能力替代软件循环。
