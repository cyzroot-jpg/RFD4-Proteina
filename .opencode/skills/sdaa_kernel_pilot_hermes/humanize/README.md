# Humanize

**当前版本：1.18.0**

> 源自 [GAAC (GitHub-as-a-Context)](https://github.com/SihaoLiu/gaac) 项目。

一个提供迭代开发与独立 AI 审查的 Claude Code 插件。通过持续反馈循环，自信地构建软件。

## 什么是 RLCR？

**RLCR** 是 **Ralph-Loop with Codex Review** 的缩写，灵感来源于官方的 ralph-loop 插件，并通过独立的 Codex 审查进行了增强。该名称也可理解为 **Reinforcement Learning with Code Review**（基于代码审查的强化学习）——体现了 AI 生成的代码通过外部审查反馈不断改进的迭代循环。

## 核心理念

- **迭代优于完美** —— 不期望一次输出完美结果，Humanize 利用持续反馈循环，在早期发现问题并逐步改进。
- **一次构建 + 一次审查** —— Claude 负责实现，Codex 独立审查。没有盲区。
- **Ralph 循环与群体模式** —— 迭代改进持续进行，直到所有验收标准满足。可选择通过 Agent Teams 进行并行化。
- **以终为始** —— 在循环开始之前，Humanize 会验证*你*是否理解即将执行的计划。人类必须始终是架构师。([详情](docs/usage.md#begin-with-the-end-in-mind))

## 工作原理

<p align="center">
  <img src="docs/images/rlcr-workflow.svg" alt="RLCR Workflow" width="680"/>
</p>

循环包含两个阶段：**实现阶段**（Claude 工作，Codex 审查摘要）和**代码审查阶段**（Codex 检查代码质量并标记严重程度）。问题会反馈到实现阶段，直到全部解决。


## 安装

从 KernelPilot 仓库根目录开始：

```bash
git clone https://github.com/BBuf/kernel-pilot.git
cd kernel-pilot
humanize/scripts/install-skills-claude.sh
```

需要 [codex CLI](https://github.com/openai/codex) 进行审查。完整的[安装指南](docs/install-for-claude.md)包含前置条件、单次会话 `--plugin-dir` 用法、上游纯 Humanize 安装以及替代配置选项。

## 快速开始

1. **从一个初步想法生成创意草案**（可选——如果已有草案可跳过）：
   ```bash
   /humanize:gen-idea "add undo/redo to the editor"
   ```
   输出保存到 `.humanize/ideas/<slug>-<timestamp>.md` 及配套的 `directions.json` 文件。传入 `.md` 路径可扩展现有粗略笔记。`--n` 控制探索该想法的并行方向数量（默认 6）。

2. **将各方向作为并行原型进行探索**（可选——如果想直接进入规划阶段可跳过）：
   ```bash
   /humanize:explore-idea .humanize/ideas/<slug>-<timestamp>.directions.json
   ```
   调度有限数量的并行原型工作者（每个方向一个），每个工作者在隔离的 git worktree 中运行。所有工作者完成后，会生成 `.humanize/explore/<run-id>/explore-report.md` 用于审计/排名详情，以及 `.humanize/explore/<run-id>/final-idea.md` 作为可供规划使用的综合结果。工作者 worktree 是可选的原型快速路径；默认的后续操作是从 `final-idea.md` 生成干净的计划。

3. **从草案或探索后的最终想法生成计划**：
   ```bash
   /humanize:gen-plan --input .humanize/explore/<run-id>/final-idea.md --output docs/plan.md
   ```

4. **在实现前优化带注释的计划**——当审查者添加评论时使用（`CMT:` ... `ENDCMT`、`<cmt>` ... `</cmt>` 或 `<comment>` ... `</comment>`）：
   ```bash
   /humanize:refine-plan --input docs/plan.md
   ```

5. **运行循环**：
   ```bash
   /humanize:start-rlcr-loop docs/plan.md
   ```

6. **咨询 Gemini** 进行深度网络研究（需要 Gemini CLI）：
   ```bash
   /humanize:ask-gemini What are the latest best practices for X?
   ```

7. **监控进度（在另一个终端中，而非 Claude Code 内部）**：
   ```bash
   source <path/to/humanize>/scripts/humanize.sh # 或者直接添加到你的 .bashrc 或 .zshrc 中
   humanize monitor rlcr       # RLCR 循环
   humanize monitor skill      # 所有技能调用（codex + gemini）
   humanize monitor codex      # 仅 Codex 调用
   humanize monitor gemini     # 仅 Gemini 调用
   humanize monitor web        # 当前项目的浏览器仪表盘
   ```

   `humanize monitor web` 子命令会启动一个针对项目的浏览器仪表盘，
   叠加在终端监控器所读取的相同数据源之上。默认在前台运行；
   传入 `--daemon` 可使用后台 tmux 启动器，
   传入 `--host` / `--port` / `--auth-token` 可配置远程访问。请注意：
   `/humanize:viz` 已被移除，取而代之的是 `humanize monitor web`。

## 监控仪表盘

<p align="center">
  <img src="docs/images/monitor.png" alt="Humanize Monitor" width="680"/>
</p>

## 文档

- [使用指南](docs/usage.md) —— 命令、选项、环境变量
- [Claude Code 安装指南](docs/install-for-claude.md) —— 完整安装说明
- [Codex 安装指南](docs/install-for-codex.md) —— Codex 技能运行时配置
- [配置](docs/usage.md#configuration) —— 共享配置层级与覆盖规则
- [Bitter Lesson 工作流](docs/bitlesson.md) —— 项目记忆、选择器路由与增量验证

## 许可证

MIT
