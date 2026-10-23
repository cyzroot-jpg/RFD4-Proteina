# 按技术索引

| 技术 | Page ID | 主要用途 |
|---|---|---|
| 硬件与编程模型速览 | `hw-teco-ops-hardware-model` | SPA/SPE/SU/SREG/VPU/VREG/FU/SPM 速查 + SPMD 切分公式。 |
| interface+ual 分层开发 | `technique-teco-ops-interface-ual-layering` | 新增算子的完整九步流程，`RUN_OP`/`find()`/`.scpp` kernel 调用链路。 |
| PyTorch 扩展绑定 | `technique-teco-ops-python-torch-binding` | `torch_ext.cpp` 包装 + `PYBIND11_MODULE` 注册，让算子可被 `import tecoops` 调用。 |
| Plugin/TVM Relay IR 注册 | `technique-teco-ops-plugin-relay-registration` | `AbstractPluginOp` 子类 + ONNX/Relay 转换，让算子进入 Teco-Inference 推理管线。 |
| Teco-AL 分支递进式性能优化方法论 | `technique-teco-al-algo-branch-benchmarking` | SingleThread→MultiThreads→DMA→SIMD→Matmul/Broadcast→DoubleBuffer 的通用优化路线模板，附三个算子的真实性能对照表。 |
| PICT_smoke 模型级 CUDA→SDAA 自动迁移模式 | `technique-pict-smoke-cuda-sdaa-model-migration` | 把一个现成 PyTorch+CUDA 扩展模型迁移到 SDAA：`USE_SDAA=1` 构建期切换 + `TORCH_SDAA_AUTOLOAD=cuda_migrate` 运行期自动重定向。 |
