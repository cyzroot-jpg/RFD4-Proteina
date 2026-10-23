# 按问题索引

| 症状 | 模式 | 候选页面 |
|---|---|---|
| 算子结果有偏差但不崩溃 | `pattern-teco-ops-precision-pitfalls` | `doc-teco-ops-docs-p03` |
| half 中间变量精度不足 | `pattern-teco-ops-precision-pitfalls` | `doc-teco-ops-docs-p03` |
| 极值输入下比较/maximum 结果错误 | `pattern-teco-ops-precision-pitfalls` | `doc-teco-ops-docs-p03` |
| 超越函数链式调用结果趋近 0 | `pattern-teco-ops-precision-pitfalls` | `doc-teco-ops-docs-p03` |
| 不知道新算子怎么接入分支派发 | `technique-teco-ops-interface-ual-layering` | `doc-teco-ops-docs-p04` |
| SPM 内存超量报错 | `technique-teco-ops-interface-ual-layering` | `doc-teco-ops-docs-p04`（235KB 上限） |
| 不会写算子设计文档 | `kernel-teco-ops-flatten-rays` | `doc-teco-ops-docs-p08`, `doc-teco-ops-docs-p09` |
| 测试用例 proto 参数不知道怎么填 | `doc-teco-ops-docs-p02` | — |
| 需要打印调试 SPE 运行时状态 | `doc-teco-ops-docs-p03` | — |
| 需要在设备端代码中终止程序 | `doc-teco-ops-docs-p03` | `abort`/`assert` |
| PyTorch 调用报 ImportError/AttributeError | `technique-teco-ops-python-torch-binding` | `doc-teco-ops-docs-p06` |
| Plugin 构建找不到 TVM 相关 .so | `technique-teco-ops-plugin-relay-registration` | `doc-teco-ops-docs-p05` |
| ONNX 自定义算子模型转换失败 | `technique-teco-ops-plugin-relay-registration` | `doc-teco-ops-docs-p05` |
| commit/PR 格式不确定 | `doc-teco-ops-docs-p01` | — |
| 不知道 GEMM/卷积优化该走哪条路线 | `technique-teco-al-algo-branch-benchmarking` | `kernel-teco-al-gemm`, `kernel-teco-al-conv-forward` |
| 优化到某一步后收益变小，不确定是否值得继续 | `technique-teco-al-algo-branch-benchmarking` | 边际递减规律与三个真实性能对照表 |
| 1x1 卷积性能差，想知道能否转成矩阵乘 | `kernel-teco-al-conv-forward` | conv-to-gemm 等价条件与分块/广播设计 |
| Teco-AL 提交 PR 前自查 | `doc-teco-al-docs-p01` | 常见问题章节（注释残留、SPM 超限、commit 格式、PR 变更文件数） |
| 现成 PyTorch 模型要迁移到 SDAA，不知道从哪下手 | `technique-pict-smoke-cuda-sdaa-model-migration` | 判断标准：模型是否有自定义 CUDA 扩展 |
| 模型能跑但自定义 CUDA 扩展（.so）加载失败 | `technique-pict-smoke-cuda-sdaa-model-migration` | 检查 `USE_SDAA=1` 构建与产物手动放置步骤 |
