# Pattern: Persistent Query 在少量 Round 和 Tail 上的固定开销

## 状态

verified_by_failed_stage

## 类型

pitfall

## 问题

跨 query persistent pipeline 可以显著降低长 prefill 的重复初始化和同步，但不能仅凭正确性把它
覆盖到所有`q_seq>=active_spe`的shape。只有一两个query round时，双输出buffer、reply状态和drain
固定开销可能超过被删除的单轮边界开销；非整组tail还会让大多数SPE空等。

## 适用场景

- 每个SPE按`q = tid + round * active_spe`处理独立query。
- persistent版本包含双输出buffer、延迟wait和最终drain。
- 候选dispatch希望覆盖单round、两round或非整组query tail。
- 小shape性能仍属于算子接口的回归门禁。

## 不适用场景

- 每个SPE有足够多round，固定成本已被稳定摊薄。
- 小shape不属于支持范围，或已有更快的独立fallback。
- persistent实现能在编译期关闭第二输出buffer和跨round状态。

## 核心思路

Persistent是长序列优化，不是无条件的单轮slice替代品；dispatch必须按已验证round数或shape设置fallback。

## 实现规则

- 分别测试单round、两round、多round和非整组tail。
- 正确性测试必须包含只有一个SPE进入末轮的`active_spe+1` shape。
- invalid路径要独立测试，因为它增加单round串行工作，却不增加跨query overlap窗口。
- 删除旧slice前，必须证明small valid、small invalid和query tail均无稳定回退。
- 若小shape回退，保留旧slice或增加编译期small-round specialization，不要只用运行时空循环统一。

## 关键参数与资源预算

- 已验证`active_spe=32`。
- 双`c_ldm`在head16/8/4时额外占16/8/4KB。
- q_seq=32只有一个round；q_seq=33的第二round只有一个SPE有任务。
- q_seq=512对应每SPE 16个均衡round，已验证可稳定受益；3～15个均衡round的拐点尚未测定。

## 架构与数据流

```text
长序列：fill -> 多次 steady -> drain       固定成本可摊薄
q_seq=32：fill -> drain                    没有steady收益
q_seq=33：fill -> 仅1个SPE执行tail -> drain 其余SPE等待
```

## 从朴素实现到优化实现

- 候选实现把所有q_seq>=32的prefill统一到persistent路径。
- 2K与单round valid精度正确且性能正向，但small invalid和33-query tail稳定回退。
- 早期实现只保留2K/8K/64K精确shape；后续v12已用`q_seq>=512 && q_seq%32==0`
  结构条件替代枚举，小shape和非32倍数tail继续走fallback。

## 选型决策

- 多round生产shape优先persistent。
- 单round、两round和tail默认保留单轮slice，除非有独立benchmark证明更快。
- 可以按round数建立新阈值，但必须覆盖不同head、topk和invalid比例，不能从一个shape外推。

## 伪代码

```cpp
if (is_verified_persistent_shape(args)) {
    run_persistent_query_pipeline(args);
} else {
    run_single_round_slice_dispatch(args);
}
```

## 常见坑

- 看到q_seq大于SPE数就认为persistent一定更快。
- 只测32整除shape，没有测`32n+1`tail。
- small valid略快后直接删除fallback，遗漏invalid路径回退。
- 只验证精度，不比较fill/drain占比很高的小shape性能。

## 自检清单

- 每个SPE实际有多少round？
- 是否存在只有少数SPE进入末轮的tail？
- invalid路径是否单独benchmark？
- 双输出buffer和drain是否在单round仍必需？
- 删除fallback前是否完成严格回切A/B？

## 验证

- 目标算子：`flash_mla_sparse` N32 prefill。
- 失败stage：`v9a_prefill_n32_general_dispatch_coverage`。
- 通用persistent覆盖11个shape，精度11/11通过。
- q_seq=32 invalid：旧slice 105.62 us，persistent 112.74 us，回退6.74%。
- q_seq=33 valid：旧slice 150.34 us，persistent 177.09 us，回退17.79%。
- q_seq=2048 head16/8/4则提升9.19%/10.05%/10.08%，最终作为独立dispatch保留。
- q_seq=512、整32组、valid路径已提升8.60%/10.34%/9.33%，说明固定开销在16个均衡round时
  已能摊薄；这不推翻q_seq=33极不均衡tail反例，也不能外推到invalid-heavy输入。
- evidence: pipeline-v9a-persistent-small-round-overhead
- evidence: pipeline-v10-persistent-round-threshold-512
- evidence: pipeline-v12-structural-n32-query-dispatch

## 来源沿革

- 失败stage已蒸馏到evidence `pipeline-v9a-persistent-small-round-overhead`。
- 本结论描述round数与fill/drain关系，不推广具体模型shape常量。

## 相关模式

- `pipeline/cross-query-persistent-attention`
- `pitfalls/small-side-input-prefetch-contention`
