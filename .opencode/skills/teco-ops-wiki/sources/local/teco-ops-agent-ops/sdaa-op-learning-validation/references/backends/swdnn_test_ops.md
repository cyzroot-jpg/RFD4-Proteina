---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-backends-swdnn-test-ops-0f6aed66
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/backends/swdnn_test_ops.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/backends/swdnn_test_ops.md
relative_source_path: sdaa-op-learning-validation/references/backends/swdnn_test_ops.md
captured_at: 2026-08-04
---

# Backend: swdnn_test_ops

默认 backend。设备 kernel 使用 rt 接口（`rt_dma_*`、`rt_rma_*`、`rt_ace_*`）开发，
通过 `torch_verify.py`（L3 精度）和 `check_delivery.py`（交付检查）验证。

## 适用场景

- `swdnn_test_ops/src/<op>/<op>.swcu` 单文件算子
- 纯 rt 接口开发
- teco-ops-agent 脚手架流程（requirement -> design -> scaffold -> torch_verify -> check_delivery）

## 验证方式

| 检查项 | 脚本 / 字段 | 通过标准 |
|--------|-------------|----------|
| 正确性 | `torch_verify.py` | `success_rate == 1.0` |
| 交付 | `check_delivery.py --json` | `delivery_status == pass` |
| 性能 | `kernel-bench` / `bench_kernel.py` | `time_ms` 或 `cycles` 下降；`tflops` 上升 |

## stage_result JSON 字段

```json
{
  "correctness": {"success_rate": 1.0},
  "delivery": { "delivery_status": "pass" },
  "perf_before": { "time_ms": 1.23 },
  "perf_after": { "time_ms": 0.98 }
}
```

## 抽取词汇

- DMA：`rt_dma_iget` / `rt_dma_iput` / `rt_dma_wait_value`
- RMA：`rt_rma_put` / `rt_rma_iput` / `rt_rma_iget`
- ACE：`rt_ace_config_kernel` / `rt_ace_load_north` / `rt_ace_load_west` / `rt_ace_cal` / `rt_ace_write` / `rt_ace_writeback`
- SIMD：`SIMD_LOAD` / `SIMD_STORE` / `simd_load` / `simd_store`
- Sync：`rt_synchronized_array` / `rt_synchronize`

## 脚本参数

```bash
python3 .../init_learning_task.py --backend swdnn_test_ops --demo-root ./swdnn_test_ops ...
python3 .../validate_learned_patterns.py
python3 .../promote_design_facts.py --backend swdnn_test_ops --demo-root ./swdnn_test_ops ...
```

不传 `--backend` 时默认使用本 backend，向后兼容。

## 配置文件

路径可通过未跟踪的 `configs/backend_config.local.json` 覆盖（可选）：

```json
{ "backends": { "swdnn_test_ops": { "demo_root": "custom/path" } } }
```

`demo_root` 可用绝对路径或相对于仓库根目录的相对路径。不配置则使用默认值 `swdnn_test_ops`。
