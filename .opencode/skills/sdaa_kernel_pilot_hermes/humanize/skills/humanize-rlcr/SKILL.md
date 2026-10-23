---
name: humanize-rlcr
description: 使用 Hermes gate 启动 RLCR（Ralph-Loop with Hermes Review）。
type: flow
user-invocable: false
disable-model-invocation: true
---

# Humanize Hermes RLCR 循环

This Hermes KernelPilot variant uses Hermes Agent for both worker execution and
review gates. Do not fall back to Codex or Claude for review in this checkout.

将此流程用作 RLCR 的 Codex 入口点。Codex 安装的 Humanize 需要原生钩子支持，并自动安装 Humanize `Stop` 钩子。

## 运行时根目录

安装程序会使用绝对运行时根路径注入此技能：

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

以下所有命令均假设 `{{HUMANIZE_RUNTIME_ROOT}}`。

## 必需顺序

### 1. 设置

使用设置脚本启动循环：

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-rlcr-loop.sh" $ARGUMENTS
```

如果设置以非零退出，停止并报告错误。

### 2. 工作轮次

每个轮次：

1. 从 `.humanize/rlcr/<timestamp>/round-<N>-prompt.md` 读取当前循环提示（或在 finalize 阶段读取 `finalize` 提示文件）。
2. 实现所需更改。
3. 提交更改。
4. 编写所需的摘要文件：
   - 常规阶段：`.humanize/rlcr/<timestamp>/round-<N>-summary.md`
   - Finalize 阶段：`.humanize/rlcr/<timestamp>/finalize-summary.md`
5. 正常停止或退出。
6. 让原生 Humanize `Stop` 钩子自动运行。
7. 如果钩子阻止退出，严格遵循返回的指令并继续下一轮。

## 此流程强制执行的内容

原生 Stop 钩子路径强制执行：

- 状态/模式验证（`current_round`、`max_iterations`、`review_started`、`base_branch` 等）
- 分支一致性检查
- 计划文件完整性检查（适用时）
- 未完成 Task/Todo 阻塞
- 退出前 git-clean 要求
- `--push-every-round` 未推送提交阻塞
- 摘要存在性检查
- 最大迭代处理
- 全对齐轮次（`--full-review-round`）
- 严格的 `COMPLETE`/`STOP` 标记处理
- 审查阶段转换守卫（`.review-phase-started` 标记）
- 基于 `[P0-9]` 标记的代码审查门控
- codex 审查失败或空输出时的硬阻塞
- `ask_codex_question=true` 时的开放问题处理

## 关键规则

1. 切勿手动编辑 `state.md` 或 `finalize-state.md`。
2. 切勿通过手动声明完成来跳过被阻止的钩子结果。
3. 切勿运行临时 `codex exec` / `codex review` 来代替钩子管理的阶段转换。
4. 始终使用循环生成的文件（`round-*-prompt.md`、`round-*-review-result.md`）作为事实来源。

## 选项

通过 `setup-rlcr-loop.sh` 传递以下选项：

| 选项 | 描述 | 默认值 |
|--------|-------------|---------|
| `path/to/plan.md` | 计划文件路径 | 除非 `--skip-impl` 否则必需 |
| `--plan-file <path>` | 显式计划路径 | - |
| `--track-plan-file` | 强制跟踪计划不可变性 | false |
| `--max N` | 最大迭代次数 | 84 |
| `--codex-model MODEL:EFFORT` | `codex exec` 的 Codex 模型和努力程度 | gpt-5.5:high |
| `--codex-timeout SECONDS` | Codex 超时 | 5400 |
| `--base-branch BRANCH` | 审查阶段的基准分支 | 自动检测 |
| `--full-review-round N` | 全对齐间隔 | 5 |
| `--skip-impl` | 直接从审查路径开始 | false |
| `--push-every-round` | 每轮要求推送 | false |
| `--claude-answer-codex` | 让 Claude 直接回答开放问题 | false |
| `--agent-teams` | 启用代理团队模式 | false |
| `--yolo` | 跳过测验并启用 --claude-answer-codex | false |
| `--skip-quiz` | 仅跳过计划理解测验（技能模式下隐含） | false |
| `--strict-success` | 继续通过最大迭代和停滞 STOP 门控直到所有 AC 满足 | false |

审查阶段 `codex review` 使用 `gpt-5.5:high` 运行。

## 使用方法

```bash
# 使用计划文件启动
/flow:humanize-rlcr path/to/plan.md

# 仅审查模式
/flow:humanize-rlcr --skip-impl
```

## 取消

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/cancel-rlcr-loop.sh"
```
