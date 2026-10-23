---
id: kernel-teco-ops-flatten-rays
title: "flatten_rays：Teco-Ops 算子设计文档范例解析"
type: kernel
architectures: [sdaa, teco-t1]
tags: [flatten-rays, tiling, spmd, worked-example, design-doc]
confidence: verified
kernel_types: [elementwise, gather-scatter, indexing]
languages: [sdaa-c, cpp, python]
related: [hw-teco-ops-hardware-model, technique-teco-ops-interface-ual-layering, technique-teco-ops-python-torch-binding, technique-teco-ops-plugin-relay-registration]
sources: [doc-teco-ops-docs-p09, doc-teco-ops-docs-p08, doc-teco-ops-docs-p07]
---

# flatten_rays：Teco-Ops 算子设计文档范例解析

`flatten_rays` 是 Teco-Ops 仓库中唯一填写完整的算子设计文档范例（`doc-teco-ops-docs-p09`），对照空白模板 `doc-teco-ops-docs-p08`，可作为新算子设计文档的写作参照，也是 `hw-teco-ops-hardware-model` 中 SPMD 切分公式的具体应用。

## 计算语义

输入 `rays: (N, 2)`，每行 `(offset, num_steps)`；输出 `res`，对每条光线 n，将 `res[offset .. offset+num_steps-1]` 填充为 `n`。

```
for n in [0, N):
    offset, num_steps = rays[n*2], rays[n*2+1]
    for i in [0, num_steps): res[offset + i] = n
```

## 接口设计

```c++
tecoopsStatus_t tecoopsFlattenRays(
    tecoopsHandle_t handle,
    const int *rays, uint32_t N, uint32_t M, int *res,
    tecoopsAlgo_t algo);
```

`M` 当前固定为 2（每条光线的字段数），预留但未使用——设计文档模板要求即使暂不使用的字段也需在参数表中说明「支持状况」，这里体现为「固定为2」。

## Tiling / 性能优化策略

直接套用 `hw-teco-ops-hardware-model` 给出的 SPMD 均分公式，将 N 条光线均分给各 SPE：

```
per_spe_num = (N + spe_num - 1) / spe_num
start = threadIdx * per_spe_num
end = MIN(start + per_spe_num, N)
for n in [start, end):
    offset, num_steps = rays[n*2], rays[n*2+1]
    for i in [0, num_steps): res[offset + i] = n
```

**要点**：切分维度是光线数 N（外层循环），而不是每条光线的写出长度 num_steps——因为 num_steps 在不同光线间可能极不均匀，若以写出元素总数切分则需要先做前缀和，反而增加复杂度；以 N 切分是用简单性换取足够好的负载均衡假设。这是本例区别于常规「按输出元素数均分」elementwise 算子的关键设计取舍。

## 分支派发

只有 `TECOOPS_ALGO_0`（`tecoKernelFlattenRaysInt`，单线程束并行实现）；`TECOOPS_ALGO_1`~`TECOOPS_ALGO_9` 保留但未实现——这是 Teco-Ops `algo` 分支派发机制（见 `technique-teco-ops-interface-ual-layering`）在只有单一实现时的最简形态。

## 三种暴露方式在本例中的体现

flatten_rays 是文档集中唯一同时展示了 interface+ual 实现、PyTorch 绑定（`technique-teco-ops-python-torch-binding`）和 Plugin/Relay 注册（`technique-teco-ops-plugin-relay-registration`）三层完整调用链路的算子：

```python
# PyTorch 扩展路径
tecoops.flatten_rays(rays, N, M, res)

# Plugin/Relay 推理路径（M 作为算子属性传入而非张量参数）
plugins.register_op(op_name="plugin_flatten_rays", inputs=["rays"], attrs={"M": "int"})
```

## KernelPilot 使用建议

新算子设计文档若拿不准怎么写「性能优化」章节，可直接对照本页的 tiling 小节结构（切分维度选择 + 理由 + 伪代码）；若怀疑结果错误，先查 `pattern-teco-ops-precision-pitfalls`（不过 flatten_rays 是纯整型索引写入，通常不触发那三类精度问题，更可能是切分边界 `start`/`end` 计算错误）。
