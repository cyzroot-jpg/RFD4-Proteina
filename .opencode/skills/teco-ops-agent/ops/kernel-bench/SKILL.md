---
name: kernel-bench
description: 测试 teco-ops 算子正确性和性能。默认通过 teco-ops C++ 测试框架运行 prototxt case，并用 perf_repeat/warm_repeat 采集性能。
---

# Kernel 测试

默认 backend 为 `teco_ops`，通过 teco-ops C++ 测试框架运行目标 prototxt case，覆盖正确性和性能。

## 触发

用户说「测耗时」「测性能」「benchmark」「kernel 执行时间」「测一下 kernel 跑了多久」「cycle 数」时调用。

## 前置条件

- teco-ops 算子库和测试工程可构建
- `test/zoo/teco/<op>/test_case/*.prototxt` 存在

## 执行

默认 backend 为 `teco_ops`，使用 teco-ops 自带的 C++ 测试框架同时覆盖正确性和性能：

```bash
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op <op> --demo-root ../../teco-ops --case-path zoo/teco/<op>/test_case/case_0.prototxt --json
```

旧的 `bench_kernel.py` 仅适用于 `swdnn_test_ops` 单 `.swcu` 测试树。

## 原理

1. 在 teco-ops 根目录执行 `bash build.sh --build teco`
2. 在 `test/` 目录执行 `source env.sh && sh build.sh --arch teco`
3. 运行 `./build/demo --gid=<gid> --perf_repeat=<N> --warm_repeat=<N> --case_path=<case>`
4. 通过 demo returncode 判定正确性，并从输出中提取常见性能字段

## 输出

```
{
  "backend": "teco_ops",
  "op": "flatten_rays",
  "correctness": {"passed": true},
  "performance": {"perf_repeat": 50, "warm_repeat": 3, "metrics": {}}
}
```

## 范围边界

- **包含**：teco-ops C++ 测试框架的正确性和重复性能测试
- **当前脚本输出**：构建命令、demo 命令、returncode、输出尾部和解析到的常见性能字段
- **不含**：DMA、RMA、ACE、SIMD 的分项 profiling
