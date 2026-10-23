---
name: humanize
description: 基于 AI 审查的迭代开发。提供 RLCR（Ralph-Loop with Codex Review）用于实施规划和代码审查循环。
user-invocable: false
disable-model-invocation: true
---

# Humanize - 基于 AI 审查的迭代开发

Humanize 创建一个反馈循环，其中一个 AI 实施你的计划，另一个 AI 独立审查工作，通过持续精炼确保质量。

## 运行时根目录

安装程序会使用绝对运行时根路径注入此技能：

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

以下所有命令示例均使用 `{{HUMANIZE_RUNTIME_ROOT}}`。

## 核心理念

**迭代优于完美**：与其期望一次输出完美结果，Humanize 利用迭代反馈循环，其中：
- AI 实施你的计划
- 另一个 AI 独立审查进度
- 问题被及早发现和解决
- 工作持续进行直到所有验收标准满足

## 可用工作流

### 1. RLCR 循环 - 带审查的迭代开发

RLCR（Ralph-Loop with Codex Review）循环有两个阶段：

**阶段 1：实施**
- AI 按照实施计划工作
- AI 编写已完成工作的摘要
- Codex 审查摘要的完整性和正确性
- 如果发现问题 → 反馈循环继续
- 如果 Codex 输出 "COMPLETE" → 进入审查阶段

**阶段 2：代码审查**
- `codex review --base <branch>` 检查代码质量
- 问题用 `[P0-9]` 严重性标记
- 如果发现问题 → AI 修复并继续
- 如果没有问题 → 循环以 Finalize 阶段完成
- 在 Codex CLI `0.114.0+` 且启用 `codex_hooks` 时，Humanize 安装原生 `Stop` 钩子，退出门控自动运行

### 2. 生成计划 - 从草稿生成结构化计划

将粗略草稿文档转换为结构化实施计划，包含：
- 清晰的目标描述
- AC-X 格式的验收标准，包含 TDD 风格的正向/负向测试
- 路径边界（上界/下界、允许的选择）
- 可行性提示和概念方法
- 依赖和里程碑排序

## 命令参考

### 启动 RLCR 循环

```bash
# 使用计划文件
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-rlcr-loop.sh" path/to/plan.md

# 或无计划（仅审查模式）
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-rlcr-loop.sh" --skip-impl
```

每轮之后，编写所需摘要并正常停止/退出。Humanize 的原生 Codex `Stop` 钩子自动处理审查门控。

**常用选项：**
- `--max N` - 自动停止前的最大迭代次数（默认：84）
- `--codex-model MODEL:EFFORT` - `codex exec` 的 Codex 模型和推理努力程度（默认：gpt-5.5:high）
- 审查阶段 `codex review` 使用 `gpt-5.5:high`
- `--codex-timeout SECONDS` - 每次 Codex 审查的超时（默认：5400）
- `--base-branch BRANCH` - 代码审查的基准分支（未指定时自动检测）
- `--full-review-round N` - 全对齐检查间隔（默认：5）
- `--skip-impl` - 跳过实施阶段，直接进入代码审查
- `--track-plan-file` - 在 git 中跟踪时强制计划文件不可变
- `--push-every-round` - 每轮要求 git push
- `--claude-answer-codex` - 让 Claude 直接回答 Codex 开放问题（默认为 AskUserQuestion）
- `--agent-teams` - 启用代理团队模式
- `--yolo` - 跳过计划理解测验并启用 --claude-answer-codex
- `--skip-quiz` - 仅跳过计划理解测验
- `--privacy` - 无操作；方法论分析默认禁用
- `--no-privacy` - 在循环退出时启用方法论分析
- `--strict-success` - 继续通过最大迭代和停滞 STOP 门控直到验收标准实际满足

### 取消 RLCR 循环

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/cancel-rlcr-loop.sh"
# 或在 finalize 阶段强制取消
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/cancel-rlcr-loop.sh" --force
```

### 从草稿生成计划

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/validate-gen-plan-io.sh" --input path/to/draft.md --output path/to/plan.md
```

然后按照此技能中的工作流生成结构化计划内容。

### 咨询 Codex（一次性咨询）

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/ask-codex.sh" [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] "your question"
```

## 计划文件结构

良好的计划文件应包含：

```markdown
# Plan Title

## Goal Description
Clear description of what needs to be accomplished

## Acceptance Criteria

- AC-1: First criterion
  - Positive Tests (expected to PASS):
    - Test case that should succeed
  - Negative Tests (expected to FAIL):
    - Test case that should fail

## Path Boundaries

### Upper Bound (Maximum Scope)
Most comprehensive acceptable implementation

### Lower Bound (Minimum Scope)
Minimum viable implementation

### Allowed Choices
- Can use: technologies, approaches allowed
- Cannot use: prohibited technologies

## Dependencies and Sequence

### Milestones
1. Milestone 1: Description
   - Phase A: ...
   - Phase B: ...

## Implementation Notes
- Code should NOT contain plan terminology like "AC-", "Milestone", "Step"
```

## 目标追踪系统

RLCR 循环使用目标追踪器防止目标漂移：

- **不可变节**：最终目标和验收标准（在第 0 轮设定，永不更改）
- **可变节**：活跃任务、已完成项目、延迟项目、计划演进日志

### 关键原则

1. **验收标准**：每个任务映射到特定 AC
2. **计划演进日志**：记录任何计划变更及其理由
3. **显式延迟**：延迟的任务需要充分理由
4. **全对齐检查**：每 N 轮（默认：5），全面的目标对齐审计

## 重要规则

1. **编写摘要**：退出前始终将工作摘要写入指定文件
2. **维护目标追踪器**：保持 goal-tracker.md 与进度同步更新
3. **详尽**：包含实施细节、更改的文件、添加的测试
4. **不要作弊**：不要试图通过编辑状态文件或运行取消命令来退出
5. **使用 Codex 上的原生 Stop 钩子**：编写所需摘要后，正常停止/退出以便 Codex 运行 Humanize Stop 钩子
6. **信任流程**：外部审查有助于提高实施质量

## 前置条件

- `codex` - OpenAI Codex CLI（用于审查）


## 目录结构

Humanize 将所有数据存储在 `.humanize/` 中：

```
.humanize/
├── rlcr/           # RLCR 循环数据
│   └── <timestamp>/
│       ├── state.md
│       ├── goal-tracker.md
│       ├── round-N-summary.md
│       ├── round-N-review-result.md
│       ├── finalize-state.md
│       ├── finalize-summary.md
│       ├── methodology-analysis-state.md
│       ├── methodology-analysis-report.md
│       ├── methodology-analysis-done.md
│       └── complete-state.md
└── skill/          # 一次性技能结果
    └── <timestamp>/
        ├── input.md
        ├── output.md
        └── metadata.md
```

## 监控

使用监控脚本跟踪循环进度：

```bash
source "{{HUMANIZE_RUNTIME_ROOT}}/scripts/humanize.sh"
humanize monitor rlcr   # 监控 RLCR 循环
```

## 退出代码

### ask-codex.sh
- `0` - 成功
- `1` - 验证错误
- `124` - 超时

### validate-gen-plan-io.sh
- `0` - 成功
- `1` - 输入文件未找到
- `2` - 输入文件为空
- `3` - 输出目录不存在
- `4` - 输出文件已存在
- `5` - 无写入权限
- `6` - 参数无效
- `7` - 计划模板文件未找到
