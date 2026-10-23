# Backend: teco-ops

默认 backend。用于 Teco-Ops 仓库中的 interface + ual 分层算子优化，当前验收命令以
`skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` 为准。

## 适用场景

- `teco/interface/ops/<op>.cpp` C API 封装
- `teco/ual/args/<op>_args.h` 参数结构体
- `teco/ual/ops/<op>/` 分支派发
- `teco/ual/kernel/<op>/*.scpp` 设备端 kernel
- `test/zoo/teco/<op>/` C++ optest 测例
- `python_api_test/test_<op>.py` Python API 对拍

## 验证方式

以 `reshape_and_cache` 为当前默认优化对象时，测试命令统一记录在：

```text
skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md
```

| 检查项 | 命令来源 | 通过标准 |
|--------|----------|----------|
| Python 精度 | `skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` | `python python_api_test/test_reshape_and_cache.py` 通过 |
| C++ 精度 | `skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` | `case_0/1/2` optest 精度通过 |
| 性能 | `skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` | `case_0/1/2` optest 性能命令完成，并记录优化前后 device time |

## stage_result JSON 字段

建议字段：

```json
{
  "correctness": {
    "python_api": "pass",
    "optest": "pass"
  },
  "delivery": {
    "test_commands": "pass"
  },
  "perf_before": {
    "case_0_ms": 590.0,
    "case_1_ms": 515.0,
    "case_2_ms": 514.0
  },
  "perf_after": {
    "case_0_ms": 0.0,
    "case_1_ms": 0.0,
    "case_2_ms": 0.0
  }
}
```

## 抽取词汇

- Teco-Ops 框架：`RUN_OP` / `BaseOp` / `tecoopsReshapeAndCache` / `optest`
- 访存：`memcpy` / `sdaaMemcpy` / `sdaaMemset` / `HBM`
- Kernel 组织：`threadIdx` / `CORE_NUM`
- SIMD：`SIMD_LOAD` / `SIMD_STORE` / `simd_load` / `simd_store`
- 可选底层机制：`rt_dma_*` / `rt_rma_*` / `rt_ace_*`

## 脚本参数

```bash
python3 .../init_learning_task.py --backend teco-ops --demo-root ./teco-ops ...
python3 .../validate_learned_patterns.py
python3 .../promote_design_facts.py --backend teco-ops --demo-root ./teco-ops ...
```

不传 `--backend` 时默认使用本 backend。

## 配置文件

路径可通过未跟踪的 `configs/backend_config.local.json` 覆盖（可选）：

```json
{ "backends": { "teco-ops": { "demo_root": "custom/path" } } }
```

`demo_root` 可用绝对路径或相对于 skill 仓库根目录的相对路径。不配置则使用默认值 `teco-ops`。
