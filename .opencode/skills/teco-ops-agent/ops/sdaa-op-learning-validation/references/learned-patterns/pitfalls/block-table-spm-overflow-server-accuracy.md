# Pattern: block_table 整行拷入 SPM 导致服务端精度崩坏

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

flash attention kernel 把整个 `block_table[b, :]` 用 `memcpy` 拷入 SPM（LDM）。测试环境
`block_table_dim` 很小（几十），demo 全 PASS；但 vLLM 服务端 `max_seq_len` 很大时
`block_table_dim = max_seq_len / block_size` 可达数万（如 32768）。`rt_spm_malloc(dim*4)`
直接分配到 128KB+ 或接近 LDM 上限，kernel 在 `__safe_spm_malloc` 检查处提前 return，
所有输出保持初始值（如 detokenizer 全等 token），服务端 accuracy 从 ~0.91 崩到 ~0.24。

## 适用场景

- flash attention / paged-KV kernel 使用 `block_table_dim`（每 seq 的块表列数）。
- kernel 把 block_table 整行复制到 LDM 后按 `kb` 索引。
- 服务端 `max_model_len` 大（1M 级）导致 `block_table_dim` 巨大。
- demo case 的 `block_table_dim` 远小于服务端真实值。

## 不适用场景

- block_table 列数已知且很小（固定上限），SPM 总有足够余量。
- kernel 始终按需从 HBM 读取 block id，不整体拷贝。

## 核心思路

丢弃 LDM 内的整行 block_table；KV 循环里直接按需读 HBM：
`block_id = args.block_table[b * args.block_table_dim + kb]`。
LDM 只保留 qbuf/ktmp/kbuf/vbuf/outc/o_accum 等 tile buffer。

## 实现规则

- 删除 `ldm_block_table` 的 `rt_spm_malloc` 与每 batch 的 `memcpy`。
- 每处需要 block id 的地方（K 预取、V 加载、prologue）都改为全局直接读取。
- 保持 `b * block_table_dim` 的行偏移不变。
- 读取次数 = 每 KV 迭代 2 次 4B 全局读，L2 命中，开销可忽略。

## 伪代码

```cpp
// before (BAD): 整行拷入 SPM，dim 大时溢出
int *l = rt_spm_malloc(args.block_table_dim * sizeof(int));
memcpy(l, args.block_table + b * args.block_table_dim, args.block_table_dim * 4);
...

// after (GOOD): 按需读 HBM
int bid = args.block_table[b * args.block_table_dim + kb];
```

## 常见坑

- 只修 `memcpy` 大小但仍保留 SPM buffer：`rt_spm_malloc(dim*4)` 本身就可能失败。
- 用 `max_block_num` 作为维度假设，忽略了服务端 `block_table_dim` 独立更大。
- demo 全 PASS 就以为服务端安全；必须做精度评测兜底。
- 忘记更新所有 `ldm_block_table[kb]` 引用（prologue/prefetch/V），残留引用导致编译或故障。

## 验证

- 目标算子：`flash_attention`（teco_slave_flash_attention_half）。
- demo 全 case PASS；服务端 accuracy：修复前 0.2429（Failed=0 但输出全等），修复后 0.9187（基线 0.9120，PASS）。
- 服务端关键证据：`q=(16,4,64) kc=(71001,2,32,64) blk=(1,32768)` → block_table_dim=32768。

## 来源沿革

- v2-16 session 服务端精度崩坏排查。

## 相关模式

- `pitfalls/next-qk-before-current-sv`
- `pipeline/ab-dma-double-buffer-ace-gemm`
- 测试环境与服务的 SPM 差异是已知坑（sdaa-op-eval lessons）。