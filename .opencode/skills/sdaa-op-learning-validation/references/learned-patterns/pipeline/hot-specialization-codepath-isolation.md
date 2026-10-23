# Pattern: 热特化代码路径隔离

## 状态

verified_by_stage

## 类型

optimization

## 问题

同一设备编译单元同时承载 prefill、decode 或其他数据流差异很大的大模板时，即使部分实例在运行时
不可达，残留分支、helper 和内联实例仍可能扩大热函数、改变代码布局并影响编译器优化。仅从 dispatch
可达性判断“不会执行”不足以证明它对性能没有影响。

## 适用场景

- 两个 specialization 的分核、同步、RMA、归一化或 buffer ownership 明显不同。
- 运行时 dispatch 已能把输入 shape 唯一映射到某个 specialization。
- 共享模板中存在只服务另一条路径的大 helper、模板分支或状态字段。
- 正确性已经稳定，可以对删除共享代码前后做同时间点性能复测。

## 不适用场景

- 两条路径的数据流高度一致，拆分只会复制大量共同逻辑。
- 尚未确认真实 dispatch，不能证明被删除实例对目标输入不可达。
- 性能变化来自 tile、数学、dtype 或访存数据流同时修改，无法归因到代码隔离。
- 编译器和链接器已经通过可核验的产物证明实例完全独立，且拆分没有代码布局收益。

## 核心思路

把数据流差异大的热 specialization 放入独立 class、helper 或编译路径，删除共享热模板中不属于当前
路径的分支与大函数，并用同条件 benchmark 判断代码体积和布局隔离是否产生真实收益。

## 实现规则

- 先确认 host/device dispatch 和目标 shape 命中的 specialization。
- 共享层只保留小而稳定的数学原语；大状态机、RMA merge 和路径专属 buffer 放入独立实现。
- 删除共享模板中的废弃模板参数、不可达分支、专属 normalize/merge helper 和无用实例。
- 不同时修改 QK/SV tile、数学公式、dtype、输出 layout 或 DMA/RMA 拓扑。
- 分离后必须复测另一条 specialization，避免代码移动破坏原路径精度或性能。
- 若代码只是暂时不可达但仍承担 fallback，先保留并明确 support contract，不要仅凭一次生产白名单删除。

## 关键参数与资源预算

- 本模式通常不改变 LDM、workspace 和 reply 数量。
- 主要指标是设备代码体积、内联边界、寄存器/栈使用和目标 shape 的 kernel 时间。
- 收益依赖编译器和当前 translation unit，SDK 或编译选项变化后需要重新验证。

## 架构与数据流

```text
共享大模板：prefill分支 + decode分支 + merge helper
                         │
                         └─ 热函数体积与布局互相影响

隔离后：prefill specialization      decode specialization
        仅保留prefill状态机          独立partial-state merge
```

本模式不改变硬件数据流，只改变编译边界和热代码布局，因此必须依靠严格 A/B 证明收益。

## 从朴素实现到优化实现

- 朴素实现用模板参数或运行时分支在一个大函数中覆盖多种 attention 模式。
- 优化实现把 decode merge/RMA 等专属逻辑移出 prefill 热模板，并删除废弃实例。
- 实际减少的是无关代码、内联候选和编译器分析面，不是运行时数学工作量。

## 选型决策

- 当不同模式的数据流和同步协议已经明显分叉时，优先评估隔离。
- 先做静态 reachability 和 diff 审计，再做性能 A/B；不可只凭代码更整洁宣称优化。
- 若删除路径仍是未验证 shape 的唯一 fallback，应先补 specialization 或收紧接口支持域。
- 同一算子的第二次死代码清理只作为补充证据，不自动把状态提升为 `promoted`。

## 伪代码

```cpp
if (is_prefill_shape(args)) {
    run_prefill_specialization(args);
} else if (is_decode_shape(args)) {
    run_decode_specialization(args);
}
```

两条 specialization 应分别拥有自己的大状态机，避免在共同热 helper 中保留路径专属模板分支。

## 常见坑

- 只删除 dispatch，不删除仍被实例化的大模板和 helper，编译布局影响仍然存在。
- 拆分时复制并修改共同数学逻辑，导致两条路径逐渐产生精度差异。
- 未跑另一条路径的回归，只看到目标路径加速就结束。
- 把一次编译器布局收益误写成硬件通用定律；该模式必须保留编译环境和验证范围。

## 自检清单

- 是否确认目标 shape 的真实 dispatch？
- 被移出的代码是否确实只服务另一条 specialization？
- tile、数学、dtype、DMA/RMA 数据流是否保持不变？
- 目标路径和被隔离路径是否都完成精度回归？
- 性能对照是否来自同一环境和同一时间点？

## 验证

- 验证算子/stage：`flash_mla_sparse`，`v3c_prefill_decode_codepath_separation`。
- 硬件：T1。
- decode shape：FP16，`q_seq=1`、`kv_seq=65536`、`topk=512`、
  `q_head=16/8/4`、`qk_dim=v_dim=512`。
- 结果：decode 从50.990/37.010/29.270 us降到49.070/35.420/27.690 us，
  降低3.77%/4.30%/5.40%；decode精度3/3 PASS。
- prefill smoke 2/2 PASS，64K性能变化约-0.14%至+0.07%，无稳定回退。
- evidence: pipeline-v3c-hot-specialization-codepath-isolation

## 来源沿革

- 参考 decode 与 prefill specialization 分离实现。
- 参考 prefill 通用实现。

## 相关模式

- `pipeline/online-softmax-partial-state-tree-merge`
- `pipeline/cross-query-persistent-attention`
- `pitfalls/chunked-rma-merge-request-overhead`
