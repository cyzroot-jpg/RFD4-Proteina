# 草案：优化 viz-dashboard — 合并到 `humanize monitor` 作为 Web 视图

## 背景

`feat/viz-dashboard` 分支当前引入了一个 `/humanize:viz` Claude
斜杠命令和一个本地可视化仪表板。虽然该仪表板确实显示了一些数据，
但对 *实时、动态运行的 RLCR 循环* 的可视化目前还不够清晰：
随着循环的推进，状态、每轮进度和流式日志输出难以跟踪。

另外，Humanize 已经提供了一项 CLI 端监控功能，用户可以在另一个终端中运行（不是在 Claude Code 内部）：

```bash
source <path/to/humanize>/scripts/humanize.sh   # or add to .bashrc / .zshrc

humanize monitor rlcr        # RLCR loop
humanize monitor skill       # All skill invocations (codex + gemini)
humanize monitor codex       # Codex invocations only
humanize monitor gemini      # Gemini invocations only
```

该监控功能已经捕获实时状态（RLCR 轮次、skill / Codex / Gemini 调用、日志输出）。
Web 仪表板无需自行构建采集管线 —— 它应该直接消费 `humanize monitor` 已经提供的数据。

## 目标

优化 viz-dashboard 分支，使其满足以下要求：

1. 仪表板成为叠加在现有 `humanize monitor` 数据源之上的 **Web 视图**，
   而非一个独立的采集层。
2. 仪表板能够 **同时展示多个实时 RLCR 循环**，每个循环具有独立的
   状态和流式日志输出。
3. 入口从 Claude 中移出（不再使用 `/humanize:viz` 斜杠命令），
   进入 `humanize monitor` CLI 命令，作为一个新的在线查看子命令。
4. 新功能面向 **在线/远程浏览器访问**，而非要求用户必须在运行
   Claude 的同一台机器上查看的本地查看器。
5. 保留现有 viz-dashboard 分支中的实用功能 —— 尤其是 **跨会话查询**
   （浏览不同 Claude 会话/对话中的历史循环记录）。

## 非目标

- 重新实现监控采集管线（`humanize monitor rlcr/skill/codex/gemini`）。
  仪表板消费该管线，而非替代它。
- 继续将 `/humanize:viz` 作为 Claude 斜杠命令发布。
- 添加在 commit 1b575fe 中已明确移除的图表面板或功能
  （"multi-project switcher + restart + remove chart panels"）。

## 必需行为

1. **CLI 入口统一**
   - 移除 `commands/viz.md` 及任何 `/humanize:viz` Claude 命令界面。
   - 添加一个新的 `humanize monitor` 子命令（名称在规划阶段确定，
     例如 `humanize monitor web` 或 `humanize monitor dashboard`），
     用于启动 Web 仪表板服务器。
   - 其他 `humanize monitor rlcr|skill|codex|gemini` 子命令必须
     保持不变地继续工作（终端实时跟踪）。

2. **实时多循环视图**
   - Web 仪表板必须能够同时显示 2 个以上并发运行的 RLCR 循环，
     每个循环具有：
     - 当前状态（running、paused、converged、stopped 等）
     - 当前轮次/阶段
     - 实时流式日志输出，近乎实时更新

3. **复用现有监控数据**
   - 仪表板的数据来源必须与 `humanize monitor rlcr/skill/codex/gemini`
     已读取的文件/事件相同。它不得添加并行采集机制（不得仅为仪表板添加新的钩子）。

4. **在线/远程可访问**
   - 仪表板必须能够通过网络从浏览器访问，而非仅限于运行 Claude 的
     机器上的 `localhost`。具体的绑定/认证设计在规划阶段确定。

5. **跨会话历史**
   - 必须保留现有 viz-dashboard 分支中的跨会话查询功能
     （浏览不同 Claude 会话/对话中的历史循环记录）。

## 分支清理

在实现开始之前，分支 `feat/viz-dashboard` 必须变基到最新的
`upstream/dev`（humania-org/humanize）。分支分叉后，`upstream/dev`
上已合入了多个相关变更，包括：

- `Add ask-gemini skill and tool-filtered monitor subcommands`（引入了
  仪表板必须复用的 `humanize monitor skill|codex|gemini` 子命令）
- `Remove PR loop feature entirely`（viz-dashboard 分支仍通过
  `commands/cancel-pr-loop.md`、`commands/start-pr-loop.md`、
  `hooks/pr-loop-stop-hook.sh` 引用了 PR 循环概念）
- 多项监控/钩子修复

因此，该变基既是正确性的前提条件（仪表板消费新的监控子命令），
也是清理步骤（必须移除 PR 循环相关引用）。

## 范围外（本计划不涉及）

- 对 RLCR 语义、钩子或 skill 行为的更改。
- 认证提供者、身份系统或多用户账户模型 —— 基本的远程访问保护在范围内，
  但完整的 IAM 不在范围内。
