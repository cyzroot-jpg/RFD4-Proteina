---
id: source-teco-ops-agent-ops-sdaa-op-template-references-pytorch-tolerance-4afba9b9
title: "teco-ops-agent ops: sdaa-op-template/references/pytorch-tolerance.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/pytorch-tolerance.md
relative_source_path: sdaa-op-template/references/pytorch-tolerance.md
captured_at: 2026-08-04
---

# PyTorch 容差与 compare 规则

精度验证**仅**通过 `torch_golden_lib.compare_tensors` / `<op>_torch_golden.py --compare`。

## 默认容差（`meta.json`）

| 族 | atol | rtol |
|----|------|------|
| elewise | 1e-5 | 1e-4 |
| reduce | 1e-5 | 3e-2 |

判定（与旧 `test_data.h` 量级对齐，便于迁移）：

```text
fail if |a-b| > atol AND |a-b|/max(|b|, 1e-12) > rtol
```

在 `<op>_torch_golden.py` 的 `meta()` 中覆盖 `atol` / `rtol`。

## fp16 device

推荐在 `golden()` 内用 float32 计算，compare 前双方均为 float32；或在 meta 中放宽 `rtol`（如 3e-2）。

## 误读输出

| 现象 | 含义 |
|------|------|
| `device=0 ref=小正数` | kernel/DMA/SPE 问题，**不是**调 rtol |
| `success_rate 0.91` + 大量 0 | 行/SPE 未覆盖 |
| compare 前无 `device_out.bin` | 未设 `SDAA_TORCH_DATA_DIR` 或未跑 `torch_verify.py` |

## 禁止

- 在 C++ demo 使用 `compare_data_*`
- 手写 `cpu_*_forward` 作为权威 golden
- 无 PyTorch 时宣称 L3 PASS
