---
id: source-teco-ops-agent-ops-sdaa-op-template-skill-48b87656
title: "teco-ops-agent ops: sdaa-op-template/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/SKILL.md
relative_source_path: sdaa-op-template/SKILL.md
captured_at: 2026-08-04
---

---
name: sdaa-op-template
description: teco-ops 算子落地与强制验收。默认按 teco-ops interface + UAL + test/zoo/teco 布局实现新算子，并通过 teco_ops_test.py 调用 teco-ops C++ 测试框架完成正确性和性能验收。旧 swdnn_test_ops 单 .swcu 脚本仅作历史兼容，不是默认交付路径。触发：脚手架、精度验收、算子落地、禁止复用旧算子。
---

# SDAA 算子落地（teco-ops）

默认算子工作树是 `../../teco-ops`。新算子必须落在 teco-ops 的 interface + UAL 分层工程中，并使用 teco-ops 自带 C++ 测试框架完成正确性和性能验收。

> 强制流程：[mandatory-delivery-flow.md](references/mandatory-delivery-flow.md)
> teco-ops 官方流程：`../../teco-ops/README.md` 与 `../../teco-ops/doc/README_OP.md`

## 任务完成定义（Agent 强制）

| 阶段 | 工具 / 产物 | 通过 |
|------|-------------|------|
| 设计 | `validate_design.py` | `valid: true` |
| 落地 | teco-ops interface + UAL + test 文件 | `<op>` 自己的新增文件存在 |
| 实现 | `.cpp` / `.h` / `.hpp` / `.scpp` | 无 `TODO`，无 `<op_name>` 占位 |
| 正确性 | `teco_ops_test.py` | demo returncode 为 0 |
| 性能 | `teco_ops_test.py --perf-repeat 50 --warm-repeat 3` | 命令成功并记录性能输出 |

**禁止**：只完成设计即结束；**禁止**用已有算子替代用户请求的 `<op>`；**禁止**把旧 `swdnn_test_ops` 单 `.swcu` 流程当作默认交付。

## 实现前置：性能最佳实践入口

新算子落地和 kernel 实现前，必须确认设计阶段已经读取 `../sdaa-performance-best-practices/SKILL.md`，并通过该入口检索、路由和消费：

```text
ops/sdaa-op-learning-validation/references/learned-patterns/
```

- 按 op family、执行单元（ACE/SIMD）、DMA/LDM/pipeline/RMA/workspace 检索。
- SATE 算子还必须确认 Layout/Tensor、LDM、SATE gemm、DoubleBuffer 和裸 rt 混用边界。
- 命中的 `verified_by_stage` / `promoted` pattern 应反映到实现方案或明确标注不适用。
- learned-patterns 不是复制旧算子的许可；交付物仍必须来自本次 teco-ops 新算子落地。

## 禁止复用已有算子

- **不得**搜索 `../../teco-ops/teco/` 或 `../../teco-ops/test/zoo/teco/` 找「类似实现」作为交付物
- **不得** copy 旧算子目录冒充新算子
- **不得**只改 prototxt 或 executor 指向已有算子
- **允许**只读参考 teco-ops 官方 `doc/README_OP.md`、接口宏/API 文档、SDAA C 手册和本 skill 的历史模板说明

交付必须是 **用户指定 `<op>`** 在 teco-ops interface + UAL + test 布局中的新增实现。

## teco-ops 文件布局

按 teco-ops `doc/README_OP.md` 添加新算子时，至少覆盖以下位置：

```text
../../teco-ops/
  teco/interface/include/tecoops.h          # 声明 tecoops<Op> C API
  teco/interface/ops/<op>.cpp               # 参数组装 + RUN_OP 分发
  teco/ual/args/<op>_args.h                 # Args / PatchArgs
  teco/ual/ops/<op>/<op>.hpp                # Op 类
  teco/ual/ops/<op>/find_<op>.h
  teco/ual/ops/<op>/find_<op>.cpp           # 分支选择
  teco/ual/kernel/<op>/<op>.h
  teco/ual/kernel/<op>/<op>.scpp            # SDAA C kernel
  test/test_proto/tecokernel/<op>.proto     # 如有算子参数
  test/zoo/teco/<op>/<op>.h
  test/zoo/teco/<op>/<op>.cpp               # TecoExecutor 正确性参考
  test/zoo/teco/<op>/test_case/*.prototxt
```

## teco-ops 调用链

```text
tecoops<Op>(handle, ...)
  -> 组装 Args + PatchArgs
  -> RUN_OP(<Op>Op, args, patch_args, handle)
    -> <Op>Op::find(&patch_args)
    -> <Op>Op::run(&args, stream)
      -> RUN_KERNEL(instance, stream, args)
        -> teco/ual/kernel/<op>/<op>.scpp
```

## 实现规则

- 生成或修改 `.swcu` / `.scpp` / `.h` / `.hpp` / `.cpp` 前，必须先阅读项目级 [code-style.md](../../docs/code-style.md)。
- 设备 kernel 使用 teco-ops UAL 参数结构传参，不使用旧单 `.swcu` host test driver 作为默认路径。
- 使用 `rt_rma_iput` / `rt_rma_iget` 时必须遵守 [rma-safety-rules.md](references/rma-safety-rules.md) 的 reply、远端缓冲分区和 workspace 索引规则。
- SIMD 热循环必须评估软件流水和展开度；根据依赖距离、alignment、tail、寄存器压力和 benchmark 在候选中实测选型。
- `test/zoo/teco/<op>/<op>.cpp` 必须实现 CPU reference / parameter parse / `compute()`，prototxt case 必须覆盖目标 shape。

## 工作流

```bash
# 0. 设计严格通过（见 sdaa-op-design）
python3 ops/sdaa-op-design/scripts/validate_design.py --op my_op --render-md --json

# 1. 在 ../../teco-ops 按 interface + UAL + test/zoo/teco 布局新增 my_op 文件

# 2. L0 构建
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops --build-only --json

# 3. 正确性验收
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops \
  --case-path zoo/teco/my_op/test_case/case_0.prototxt --json

# 4. 性能验收（宣告完成前必跑）
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op my_op --demo-root ../../teco-ops \
  --case-path zoo/teco/my_op/test_case/case_0.prototxt \
  --perf-repeat 50 --warm-repeat 3 --gtest-repeat 1 --json
```

`teco_ops_test.py` 会执行 teco-ops 官方测试链：`bash build.sh --build teco`、`cd test && source env.sh && sh build.sh --arch teco`、再运行 `./build/demo --gid=0 ... --case_path=...`。

## 分层验收

| 层 | 工具 |
|----|------|
| L0 编译 | `teco_ops_test.py --build-only` |
| L3 正确性 | `teco_ops_test.py --case-path ... --json` |
| 性能 | `teco_ops_test.py --perf-repeat 50 --warm-repeat 3 --gtest-repeat 1 --json` |
| 落地门禁 | demo returncode 为 0，且报告 `delivery_status: pass` |

## 历史兼容脚本

以下脚本仍保留给旧 `swdnn_test_ops` 单 `.swcu` 工作树使用，但**不属于默认 teco-ops 交付路径**：

| 脚本 | 历史用途 |
|------|----------|
| `scripts/scaffold_op.py` | 从 `op_template.swcu` 生成旧单 `.swcu` |
| `scripts/torch_verify.py` | 旧 PyTorch golden 生成/对比 |
| `scripts/check_delivery.py` | 旧单 `.swcu` 全链路检查 |
| `scripts/scope_cmake_op.py` / `scripts/cmake_baseline.py` | 旧 CMake 辅助 |

## 参考

| 文档 | 内容 |
|------|------|
| [mandatory-delivery-flow.md](references/mandatory-delivery-flow.md) | teco-ops 强制落地流程 |
| [workflow-and-verification.md](references/workflow-and-verification.md) | teco-ops 验收步骤 |
| [rma-safety-rules.md](references/rma-safety-rules.md) | RMA reply、缓冲分区、partial workspace 安全规则 |
| `../../teco-ops/doc/README_OP.md` | teco-ops 官方算子开发指南 |
| `../../teco-ops/README.md` | teco-ops 构建与测试入口 |
