# 按硬件特性索引

| 硬件特性 | 页面 |
|---|---|
| SPA/SPE 拓扑 | `hw-teco-ops-hardware-model` |
| SU（标量运算） | `hw-teco-ops-hardware-model` |
| SREG（标量寄存器） | `hw-teco-ops-hardware-model` |
| VPU/VREG（向量运算/寄存器） | `hw-teco-ops-hardware-model` |
| FU（矩阵乘等运算功能单元） | `hw-teco-ops-hardware-model` |
| SPM（片上存储，堆/栈/local） | `hw-teco-ops-hardware-model`, `technique-teco-ops-interface-ual-layering`（235KB 上限） |
| Global 存储空间 | `hw-teco-ops-hardware-model` |
| SPMD 编程范式 / threadIdx / threadDim | `hw-teco-ops-hardware-model`, `kernel-teco-ops-flatten-rays` |

| 矩阵乘法加速单元（应用视角） | `kernel-teco-al-gemm`, `kernel-teco-al-conv-forward` | Hgemm/ConvolutionForward 中矩阵乘法单元的分块/广播/重排接入方式（应用层描述，非寄存器级细节）。 |
| SPM 235KB 上限 | `technique-teco-ops-interface-ual-layering`, `doc-teco-al-docs-p01` | `rt_spm_malloc()`/`rt_spm_free()` 封装，接口占用 128B，实际上限 240512B。 |

For details beyond the bundled hardware pages and TecoLIBRT manual, inspect the
relevant upstream source or official manual and record the coverage gap. Do not
substitute another local wiki.
