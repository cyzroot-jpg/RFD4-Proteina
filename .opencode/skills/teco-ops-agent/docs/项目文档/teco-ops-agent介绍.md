# teco-ops-agent 介绍

## 定位

`teco-ops-agent` 是面向 **SDAA / TECO T1** 的算子开发 Agent 工程。它不是独立服务，也不训练模型；核心是：

- `ops/` 下的一组可被 Codex / Cursor / Claude Code 调用的 skills
- `AGENTS.md` / `CLAUDE.md` 中的强制流程约束
- `run_cli.py` 和 `teco_ops_agent/` 提供的本机 LLM 调用入口
- `teco-ops` sibling 仓库作为真实算子工程落点

目标是把“提出新算子需求”到“拿到通过 L3 精度验收的 `.swcu` 实现”的流程标准化。

## 工作流

新算子开发主链路：

```text
环境检查
  -> 性能最佳实践入口 / learned-patterns 检索
  -> 需求采集
  -> 算子设计
  -> 脚手架生成
  -> kernel 实现
  -> PyTorch L3 精度验收
  -> 交付检查
  -> 性能测试（可选）
```

任务不能在设计阶段提前结束。只有 `validate_design.py` 和 teco-ops C++ 测试框架的正确性/性能验收都通过，才算完成。

## 核心能力

| 能力 | 对应模块 |
|------|----------|
| 环境门禁、设备与 SDK 检查 | `sdaa-env-check` |
| T1 架构、ACE、DMA/RMA、SIMD 方法论 | `sdaa-docs-search`、`sdaa-performance-best-practices` |
| 性能优化入口、机制/算子族/API 路由 | `sdaa-performance-best-practices` |
| 本地与在线文档检索 | `sdaa-docs-search`、Codex MCP |
| 需求采集与设计文档 | `sdaa-op-requirement`、`sdaa-op-design` |
| 单文件 `.swcu` 脚手架、编译、L3 验收 | `sdaa-op-template` |
| 单点优化学习、失败经验沉淀 | `sdaa-op-learning-validation` |
| kernel 周期和耗时测试 | `kernel-bench` |
| 仓库功能问题修复与功能支持记录 | `record-repo-change` |

## 边界

- 不把 `teco-ops/teco/` 里的已有算子复制成新交付物。
- 不用 Codex 沙箱内 `teco-smi` 失败直接判断宿主机无卡；设备验收以宿主机终端为准。
- `sdaa-op-learning-validation` 用于学习和验证优化模式，不替代正式新算子交付流程。

## 文档入口

| 文档 | 用途 |
|------|------|
| [README.md](../../README.md) | 仓库入口和最短路径 |
| [快速开始](快速开始.md) | Codex / Cursor / Claude Code 安装、配置、验证 |
| [项目现状总览](TECO%20Ops%20Agent项目现状总览.md) | 模块职责、流程图、样例、当前状态 |
| [代码规范](../code-style.md) | 生成或修改 C++ / `.swcu` 代码前必须阅读 |
| [共享知识库](../共享知识库/README.md) | 跨 skill 复用的公共技术文档 |
