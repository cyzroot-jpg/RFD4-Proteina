---
id: technique-teco-ops-interface-ual-layering
title: "Teco-Ops interface+ual 分层算子开发"
type: technique
architectures: [sdaa, teco-t1]
tags: [teco-ops, interface, ual, run-op, branch-dispatch, spm]
confidence: verified
reproducibility: snippet
related: [hw-teco-ops-hardware-model, kernel-teco-ops-flatten-rays, pattern-teco-ops-precision-pitfalls]
sources: [doc-teco-ops-docs-p04, doc-teco-ops-docs-p01]
aliases: ["interface层", "ual层", "RUN_OP", "分支派发"]
---

# Teco-Ops interface+ual 分层算子开发

Teco-Ops 新增算子遵循 interface（用户 API）+ ual（统一算子库）两层架构，与内部 teco-al 项目设计一致。

## 分层职责

- **Interface 层**：面向用户的 C API 入口（`teco/interface/include/tecoops.h` 声明，`teco/interface/ops/` 实现）。核心是 `tecoopsHandle_t` 句柄（管理 `spe_num`、`stream`），通过 `RUN_OP(OpType, args, patch_args, handle)` 宏一步完成 `Op.find()`（分支选择）+ `Op.run()`（kernel 执行）分发。
- **UAL 层**：核心实现层，包含三个子目录：
  - `ual/args/`：`Args`（运行参数）+ `PatchArgs`（分支选择参数：`data_type` + `algo`）结构体。
  - `ual/ops/`：`Op` 类，继承 `BaseOp<MyOpOp, MyOpType>`，`findImpl()` 依据 `data_type`/`algo` 选择具体 kernel 实现（`findMyOpBranch()`），`setInstance()` 绑定选中的 kernel 函数指针。
  - `ual/kernel/`：`.scpp` 文件，`__global__` 核函数，真正的设备端计算逻辑。

## 调用链路

```
tecoopsMyOp(handle, ...)                    # Interface 层用户 API
  → 组装 Args + PatchArgs
  → RUN_OP(MyOpOp, arg, patch_arg, handle)
    → MyOpOp::find(&patch_arg)  → findMyOpBranch()   # UAL ops 层：分支选择
    → MyOpOp::run(&arg, stream) → RUN_KERNEL(...)     # UAL kernel 层：设备计算
```

## 新增一个算子的九个步骤

1. `teco/interface/include/tecoops.h` 声明 C API。
2. `teco/interface/ops/` 实现接口（参数组装 + `RUN_OP` 分发）。
3. `teco/ual/args/` 定义 `Args`/`PatchArgs`。
4. `teco/ual/ops/` 实现 `Op` 类（`find()` 分支选择）。
5. `teco/ual/kernel/` 实现 `.scpp` 设备端 kernel。
6. 如需额外参数，在 `test/test_proto/tecokernel/<op>.proto` 定义并注册到 `tecokernel.proto`。
7. 在 `test/zoo/teco/<op>/` 编写继承 `TecoExecutor` 的测试类（`paramParse`/`paramGeneration`/`compute`/`cpuCompute`）。
8. 编写 `.prototxt` 测试用例（张量 shape/dtype + `tecokernel_param`）。
9. `bash build.sh --build teco` 构建算子库，`test/` 下 `sh build.sh --arch teco` 构建测试，`./build/demo --gid=0` 运行。

## 关键约束

- SPM 内存申请总量不超过 **235KB**；推荐使用仓库封装的 `rt_spm_malloc()`/`rt_spm_free()`（接口封装占 128B，实际上限 240512B），超量申请会报错。
- 每个 PR 只对应一个算子（`doc-teco-ops-docs-p01`），commit 消息格式为 `[type](algo<num>)：<subject>`。
- 建议同步编写算子设计文档（参考 `kernel-teco-ops-flatten-rays` 的模板结构）。

## KernelPilot 使用建议

若 K/R/W 任务面向 Teco-Ops 生态的新算子开发（而非已有算子调优），本页给出的九步流程可直接映射为 workspace 中的实现顺序；每一步对应的产出文件路径可作为 attempt ledger 的检查项。
