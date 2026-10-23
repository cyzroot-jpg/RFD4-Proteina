# 按算子类型索引

| 算子类型 | 页面 |
|---|---|
| Gather/scatter/索引重排（如 flatten_rays） | `kernel-teco-ops-flatten-rays`, `hw-teco-ops-hardware-model` |
| 新算子开发（通用流程） | `technique-teco-ops-interface-ual-layering`, `doc-teco-ops-docs-p04` |
| 需暴露为 PyTorch 接口的算子 | `technique-teco-ops-python-torch-binding` |
| 需在推理引擎中使用的算子 | `technique-teco-ops-plugin-relay-registration` |
| half/低精度算子 | `pattern-teco-ops-precision-pitfalls` |
| GEMM / matmul | `kernel-teco-al-gemm`, `technique-teco-al-algo-branch-benchmarking` |
| 卷积（1x1，可转矩阵乘） | `kernel-teco-al-conv-forward` |
| 卷积（一般核，R≠1/S≠1） | `doc-teco-al-docs-p07`（性能优化章节留空，需自行设计） |
| Elementwise（add/scale/unary/activation） | `kernel-teco-al-add-tensor`, `doc-teco-al-docs-p08`, `doc-teco-al-docs-p09`, `doc-teco-al-docs-p15`, `doc-teco-al-docs-p18` |
| Reduction（argmax/unique） | `doc-teco-al-docs-p10`, `doc-teco-al-docs-p19` |
| Scatter/Gather/Index（scatter_nd_add/scatter_out/index_put/masked_fill/masked_select） | `doc-teco-al-docs-p11`, `doc-teco-al-docs-p13`, `doc-teco-al-docs-p14`, `doc-teco-al-docs-p16`, `doc-teco-al-docs-p17` |
| 整模型迁移（含自定义 CUDA 扩展，如 raymarching） | `technique-pict-smoke-cuda-sdaa-model-migration`, `doc-pict-smoke-docs` |
