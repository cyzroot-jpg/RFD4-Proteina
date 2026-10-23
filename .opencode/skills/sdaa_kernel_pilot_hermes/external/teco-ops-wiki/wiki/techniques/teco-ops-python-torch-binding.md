---
id: technique-teco-ops-python-torch-binding
title: "Teco-Ops PyTorch 扩展绑定"
type: technique
architectures: [sdaa, teco-t1]
tags: [teco-ops, pytorch, python-binding, torch-ext, pybind11]
confidence: verified
reproducibility: runnable
related: [technique-teco-ops-interface-ual-layering, technique-teco-ops-plugin-relay-registration]
sources: [doc-teco-ops-docs-p06]
aliases: ["torch_ext.cpp", "PyTorch扩展"]
---

# Teco-Ops PyTorch 扩展绑定

将已实现的 interface 层算子（见 `technique-teco-ops-interface-ual-layering`）暴露为可被 `import tecoops` 直接调用的 PyTorch Tensor 接口。

## 绑定三步骤

1. **包装函数**（`api/torch_ext.cpp`）：把 `torch::Tensor` 转成 interface 层裸指针，调用 C API。
   ```cpp
   void my_op_torch(torch::Tensor input, torch::Tensor output, int param) {
       tecoopsHandle_t handle = getGlobalHandle();
       tecoopsMyOp(handle, input.data_ptr<float>(), output.data_ptr<float>(), param, TECOOPS_ALGO_0);
   }
   ```
2. **注册**：在 `PYBIND11_MODULE(_torch_ext, m)` 中 `m.def("my_op", &my_op_torch, "my_op (SDAA)")`。
3. **暴露**：Python 包 `__init__.py` 中 `from _torch_ext import my_op`。

## 调用链路

`tecoops.flatten_rays → torch_ext.cpp → tecoopsFlattenRays(handle, ...) → RUN_OP → ual ops（分支选择） → ual kernel（设备计算）`。用户只接触 interface 层 API，算子实现细节由 ual 层管理，与 `technique-teco-ops-interface-ual-layering` 完全一致——PyTorch 绑定只是 interface 层之上的一层薄包装，不改变分层架构。

## 构建

```bash
pip install torch torch-sdaa
WITH_TORCH=ON python setup.py build_ext --inplace   # 本地开发模式
WITH_TORCH=ON python setup.py bdist_wheel            # 构建 wheel
```

**顺序约束**：必须先 `import torch` 再 `import tecoops`，否则 torch 库路径未设置会导致 `ImportError: libtorch.so`。若 `AttributeError: module 'tecoops' has no attribute 'xxx'`，说明构建时未启用 `WITH_TORCH=ON`。

## KernelPilot 使用建议

若 K/R/W 任务要求最终产出可被 PyTorch 直接调用的算子（而不只是 C API），在完成 ual 层实现后应参照本页補上 `api/torch_ext.cpp` 绑定，并在 benchmark 阶段直接用 `torch.tensor(..., device='sdaa')` 构造输入，贴近真实调用场景。
