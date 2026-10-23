---
id: source-teco-ops-agent-ops-sdaa-op-template-references-workflow-and-verification-28b8ac13
title: "teco-ops-agent ops: sdaa-op-template/references/workflow-and-verification.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/workflow-and-verification.md
relative_source_path: sdaa-op-template/references/workflow-and-verification.md
captured_at: 2026-08-04
---

# 从落地到可运行（teco-ops 正确性和性能）

> **Agent 强制**：必须跑完 teco-ops C++ 正确性 case 和带 `perf_repeat/warm_repeat` 的性能验收，才可宣告完成。见 [mandatory-delivery-flow.md](mandatory-delivery-flow.md)。

## 0. 禁止行为

- 不得用 `teco-ops/teco/` 或 `teco-ops/test/zoo/teco/` 已有算子替代用户请求的新算子
- 不得在需求、设计或只新增空文件阶段结束任务
- 不得未跑 teco-ops C++ 测试框架就声称精度通过
- 不得把旧 `swdnn_test_ops` 的 `torch_verify.py` / `check_delivery.py` 当作默认 teco-ops 门禁

## 1. 落地

按 `../../teco-ops/doc/README_OP.md` 添加：

```text
teco/interface/include/tecoops.h
teco/interface/ops/<op>.cpp
teco/ual/args/<op>_args.h
teco/ual/ops/<op>/
teco/ual/kernel/<op>/
test/test_proto/tecokernel/<op>.proto      # 如有算子参数
test/zoo/teco/<op>/
test/zoo/teco/<op>/test_case/*.prototxt
```

## 2. 实现 kernel 和测试

- interface 层负责 C API、参数检查、Args / PatchArgs 组装和 `RUN_OP` 分发。
- UAL ops 层负责 `find()` 分支派发和 `RUN_KERNEL`。
- UAL kernel 层在 `.scpp` 中实现设备端计算。
- `test/zoo/teco/<op>/<op>.cpp` 负责参数解析、设备调用、CPU reference 和资源释放。
- prototxt case 必须覆盖目标 shape、dtype、layout 和算子参数。

## 3. 构建与正确性

```bash
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops --build-only --json

python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops \
  --case-path zoo/teco/my_op/test_case/case_0.prototxt --json
```

正确性通过标志：demo returncode 为 0，报告中 `correctness.passed` 为 `true`，`delivery.delivery_status` 为 `pass`。

## 4. 性能

```bash
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops \
  --case-path zoo/teco/my_op/test_case/case_0.prototxt \
  --perf-repeat 50 --warm-repeat 3 --gtest-repeat 1 --json
```

teco-ops 原生测试框架使用同一个 demo case 同时承担正确性和性能采样。测试失败时，该性能样本无效。

## 5. 检查清单

| 阶段 | 标志 |
|------|------|
| 需求 | `<demo_root>/op_requirements/<op>/requirement.json` |
| 设计严格 | `validate_design.py` -> `valid: true` |
| 落地 | teco-ops interface / UAL / test 文件存在 |
| kernel | 无 `TODO` 和 `<op_name>` |
| L0 | `teco_ops_test.py --build-only` returncode 为 0 |
| 正确性 | `teco_ops_test.py --case-path ...` returncode 为 0 |
| 性能 | `teco_ops_test.py --perf-repeat 50 --warm-repeat 3` 成功 |

## 6. 失败处理

- 编译失败：修 include、CMake、proto、interface/UAL 类型或链接项，再重跑 L0。
- 正确性失败：修 kernel、CPU reference、参数解析或 prototxt，重跑正确性。
- 性能缺失：确认命令包含 `--perf-repeat` / `--warm-repeat`，保留 demo 输出尾部供分析。
