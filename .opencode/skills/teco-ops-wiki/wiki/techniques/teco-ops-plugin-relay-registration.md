---
id: technique-teco-ops-plugin-relay-registration
title: "Teco-Ops Plugin 自定义算子接口（TVM Relay IR）"
type: technique
architectures: [sdaa, teco-t1]
tags: [teco-ops, plugin, tvm, relay-ir, teco-inference, onnx]
confidence: verified
reproducibility: runnable
related: [technique-teco-ops-interface-ual-layering, technique-teco-ops-python-torch-binding]
sources: [doc-teco-ops-docs-p05]
aliases: ["AbstractPluginOp", "Teco-Inference Plugin", "自定义算子接口"]
---

# Teco-Ops Plugin 自定义算子接口（TVM Relay IR）

面向 Teco-Inference 推理场景的自定义算子注册路径，与 `technique-teco-ops-python-torch-binding` 是并行的两条不同暴露方式：训练/脚本场景走 PyTorch 扩展，推理场景走 TVM Relay IR + Plugin。

## 架构

1. **C++ 端**（`teco/plugin/<OpName>/plugin_<op_name>.cc`）：实现 `AbstractPluginOp` 子类，覆写 `InferOutputShape`（据输入 shape + 属性推导输出 shape）和 `Enqueue`（通过 `ComputeContext` 取输入指针/属性/流，调用 interface 层算子）。
2. **Python 端**：`tvm.plugin.plugins.register_op()` 注册算子元信息，用 ONNX `helper` 构建含自定义算子节点的模型（须指定 `domain="my_custom_ops"` 并加 `helper.make_opsetid("my_custom_ops", 1)`），再经 `tvm.relay.frontend.from_onnx` → `dyn.to_teco_infer_dyn` 转换为可被 `tecoinference.Engine` 加载的模型。
3. **注册宏**：`REGISTER_PLUGIN_OP_IMPL(plugin_<op>, <Impl类>)` 绑定实现类；`PLUGIN_REGISTER_OP("plugin_<op>").Input(...).AttrType<...Attrs>().Register()` 声明输入/属性规格。所有注册代码必须放在 `TECO_INFER` 命名空间内。

## 产物与构建

启用 `WITH_INFERENCE_PLUGIN=ON` 产出两个独立库（与普通算子库 `libteco_ops.so` 分离构建）：

- `libteco_ops_plugin.so`：`tecocc` 编译算子核心实现。
- `libTecoInferPlugin.so`：`gcc`（非 `tecocc`，因需兼容 TVM C++ 头文件）编译 Plugin 层，链接 `libteco_ops_plugin.so` + `libsdaart.so` + `libTecoInferPluginUtil.so`。

```bash
export TECO_INFER_PLUGIN_UTIL_PATH=<tvm_package_path>   # 必需
WITH_TORCH=ON python setup.py build_ext --inplace
```

## ComputeContext / OpAttr 接口

| 接口 | 说明 |
|---|---|
| `ctx->GetInputDataPtr(name)` | 按名称取输入指针 |
| `ctx->GetOutputDataPtr(index)` | 按索引取输出指针 |
| `ctx->GetAttr(name, value)` | 取属性值写入变量 |
| `ctx->GetInputShape(name, shape_vec)` | 取输入 shape |
| `ctx->GetStream()` | 取 `sdaaStream_t` |
| `attr.GetAttr<T>(name)`（`OpAttr`，用于 `InferOutputShape`） | 取属性值，类型为 `T` |

## 常见故障

| 现象 | 原因 | 处理 |
|---|---|---|
| 构建失败：找不到 `libTecoInferPluginUtil.so` | 未设置 `TECO_INFER_PLUGIN_UTIL_PATH` | 导出该环境变量指向 TVM 包路径 |
| `ImportError` 找不到 Plugin 相关 .so | 未构建或 `LD_LIBRARY_PATH` 缺库路径 | 重新构建 + 设置 `LD_LIBRARY_PATH` |
| ONNX 模型转换失败 | 未先 `register_op()` 或缺 `my_custom_ops` opset | 检查注册顺序与 opset import |

## KernelPilot 使用建议

若 K/R/W 任务明确要求算子在 Teco-Inference 推理管线中可用（而非仅 PyTorch eager 调用），需在完成 interface+ual 实现后额外走本页的 Plugin 注册路径；两条暴露路径（PyTorch 扩展 vs Plugin）互不冲突，可以并存。
