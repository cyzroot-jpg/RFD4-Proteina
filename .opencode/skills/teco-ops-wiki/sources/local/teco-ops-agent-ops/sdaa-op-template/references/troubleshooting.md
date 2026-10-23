---
id: source-teco-ops-agent-ops-sdaa-op-template-references-troubleshooting-af323937
title: "teco-ops-agent ops: sdaa-op-template/references/troubleshooting.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/troubleshooting.md
relative_source_path: sdaa-op-template/references/troubleshooting.md
captured_at: 2026-08-04
---

# 脚手架排障

## PyTorch / 精度

| 现象 | 处理 |
|------|------|
| `SDAA_TORCH_DATA_DIR unset` | 用 `torch_verify.py`，勿单独 `./run.sh` |
| `missing *_torch_golden.py` | `scaffold_op.py --patch-runsh` |
| `missing torch_load_f16` | `scaffold_op.py --upgrade-common` |
| compare FAIL，device=0 | SPE/DMA，见 device-parallel-patterns |
| `No module named torch` | `pip install torch numpy` |
| norm 只比 y 不比 inv_rms | 使用 `--family norm` 模板 + `compare_norm_fp16_case` |

## 编译 / 链接

| 现象 | 处理 |
|------|------|
| `Compatibility with CMake < 3.5` | `python3 ops/sdaa-op-template/scripts/cmake_baseline.py --demo-root ./swdnn_test_ops` |
| 链接用系统 `g++` 而非 `tecocc` | cmake baseline 会在 `project()` 前强制 `CMAKE_CXX_COMPILER` |
| `file format not recognized`（`.swcu.o`） | target `LINK_FLAGS` 含 `--sdaa-link`；见 cmake-link-compat.md |
| CMP0210 dev warning | 非阻塞；baseline 会设 `CMP0210 OLD` |
| 兄弟算子 .swcu 编译失败 | `torch_verify.py --scope-cmake --restore-cmake` |
| restore 后链接又坏 | scope 时已打 baseline；或单独跑 `cmake_baseline.py` |

## Agent 工作流建议

1. `sdaa-env-check`（**宿主机**，非沙箱）
2. `scaffold_op.py --family <elewise|reduce|norm> --smoke --patch-runsh --upgrade-common`
3. 实现 kernel；norm 参考 `example-rmsnorm_forward.md`
4. `torch_verify.py --scope-cmake --restore-cmake --json`（独立 `--build-dir` 推荐）

## 顺序

1. env-check + submodule  
2. scaffold + kernel + golden  
3. `torch_verify.py --build-only`  
4. `torch_verify.py` 全链路（宿主机）
