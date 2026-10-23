---
name: humanize-rlcr
description: 通过复用现有的 stop-hook 逻辑，在 skill 模式下启动带有等效 hook 执行的 RLCR（Ralph-Loop with Codex Review）。
type: flow
---

# Humanize RLCR 循环（Hook 等效模式）

在没有原生 hook 的环境中使用此流程运行 RLCR。
不要手动重新实现审查逻辑。始终调用 RLCR stop gate 包装器：

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/rlcr-stop-gate.sh"
```

该包装器执行 `hooks/loop-codex-stop-hook.sh`，因此 skill 模式行为与 hook 模式行为保持一致。

## 运行时根路径

安装程序会为该 skill 注入绝对运行时根路径：

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

以下所有命令均假设 `{{HUMANIZE_RUNTIME_ROOT}}`。

## 必需序列

### 1. 设置

使用设置脚本启动循环：

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-rlcr-loop.sh" $ARGUMENTS
```

如果设置以非零状态退出，停止并报告错误。

### 2. 工作轮次

每轮执行：

1. 从 `.humanize/rlcr/<timestamp>/round-<N>-prompt.md` 读取当前循环提示（finalize 阶段读取 `finalize` 提示文件）。
2. 实现所需更改。
3. 提交更改。
4. 写入所需的摘要文件：
   - 常规阶段：`.humanize/rlcr/<timestamp>/round-<N>-summary.md`
   - Finalize 阶段：`.humanize/rlcr/<timestamp>/finalize-summary.md`
5. 运行门控命令：

```bash
GATE_CMD=("{{HUMANIZE_RUNTIME_ROOT}}/scripts/rlcr-stop-gate.sh")
[[ -n "${CLAUDE_SESSION_ID:-}" ]] && GATE_CMD+=(--session-id "$CLAUDE_SESSION_ID")
[[ -n "${CLAUDE_TRANSCRIPT_PATH:-}" ]] && GATE_CMD+=(--transcript-path "$CLAUDE_TRANSCRIPT_PATH")
"${GATE_CMD[@]}"
GATE_EXIT=$?
```

6. 处理门控结果：
   - `0`：允许循环退出（完成）。
   - `10`：被 RLCR 逻辑阻塞。严格按照返回的指示执行，继续下一轮。
   - `20`：基础设施错误（包装器/hook/运行时）。报告错误，不要伪造完成状态。

## 执行的约束

通过路由到 stop-hook 逻辑，该 skill 强制执行：

- state/schema 验证（`current_round`、`max_iterations`、`review_started`、`base_branch` 等）
- 分支一致性检查
- 计划文件完整性检查（适用时）
- 未完成的 Task/Todo 阻塞
- 退出前的 git-clean 要求
- `--push-every-round` 的未推送提交阻塞
- 摘要存在性检查
- 最大迭代处理
- 全面对齐轮次（`--full-review-round`）
- 严格的 `COMPLETE`/`STOP` 标记处理
- 审查阶段转换守卫（`.review-phase-started` 标记）
- 基于 `[P0-9]` 标记的代码审查门控
- Codex 审查失败或输出为空时的硬阻塞
- 当 `ask_codex_question=true` 时的开放问题处理

## 关键规则

1. 永远不要手动编辑 `state.md` 或 `finalize-state.md`。
2. 永远不要通过手动声明完成来跳过被阻塞的 hook 结果。
3. 永远不要运行临时的 `codex exec` / `codex review` 来替代 hook 管理的阶段转换。
4. 始终使用循环生成的文件（`round-*-prompt.md`、`round-*-review-result.md`）作为事实来源。

## 选项

通过 `setup-rlcr-loop.sh` 传递这些选项：

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `path/to/plan.md` | 计划文件路径 | 除非 `--skip-impl` 否则必需 |
| `--plan-file <path>` | 显式计划路径 | - |
| `--track-plan-file` | 强制跟踪计划不可变性 | false |
| `--max N` | 最大迭代次数 | 84 |
| `--codex-model MODEL:EFFORT` | `codex exec` 使用的 Codex 模型和推理强度 | gpt-5.5:high |
| `--codex-timeout SECONDS` | Codex 超时时间 | 5400 |
| `--base-branch BRANCH` | 审查阶段的基础分支 | 自动检测 |
| `--full-review-round N` | 全面对齐检查间隔 | 5 |
| `--skip-impl` | 直接从审查路径开始 | false |
| `--push-every-round` | 每轮要求推送 | false |
| `--claude-answer-codex` | 让 Claude 直接回答开放问题 | false |
| `--agent-teams` | 启用 agent teams 模式 | false |
| `--yolo` | 跳过测验并启用 --claude-answer-codex | false |
| `--skip-quiz` | 跳过计划理解测验（skill 模式下隐含） | false |

审查阶段 `codex review` 使用 `gpt-5.5:high` 运行。

## 用法

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
