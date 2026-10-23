---
description: "启动带 Codex 审查的迭代循环"
argument-hint: "[path/to/plan.md | --plan-file path/to/plan.md] [--max N] [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [--track-plan-file] [--push-every-round] [--base-branch BRANCH] [--full-review-round N] [--skip-impl] [--claude-answer-codex] [--agent-teams] [--yolo] [--skip-quiz] [--privacy] [--no-privacy] [--strict-success]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh:*)"
  - "Read"
  - "Task"
  - "AskUserQuestion"
---

# 启动 RLCR 循环

## 计划合规性预检查

在运行设置脚本之前，验证计划文件的合规性。这是一种防错机制，用于尽早捕获明显错误的计划文件。

**跳过整个预检查的条件**（满足任一即可）：
- `$ARGUMENTS` 包含 `--skip-impl`（没有计划文件需要验证）
- `$ARGUMENTS` 包含 `-h` 或 `--help`（仅显示帮助）

### 从参数中提取计划文件路径

解析 `$ARGUMENTS` 以查找计划文件路径：
- 如果存在 `--plan-file <path>`，使用 `<path>`
- 否则，使用第一个位置参数（第一个不以 `--` 开头且不是已知标志值的参数，如 `--max`、`--codex-model`、`--codex-timeout`、`--base-branch`、`--full-review-round`、`--plan-file`）
- 如果无法确定计划文件路径，跳过预检查，让设置脚本处理错误

### 基本路径安全检查

仅在提取的路径满足以下所有条件时继续预检查：
- 是相对路径（不以正斜杠开头）
- 不包含父目录遍历（双点路径组件）
- 仅包含安全路径字符：字母、数字、连字符、下划线、点和正斜杠

如果任何条件失败，跳过预检查，让设置脚本处理路径验证。

### 读取并验证计划内容

1. 使用 Read 工具读取计划文件。如果文件不存在或无法读取，跳过预检查，让设置脚本处理错误。

2. 使用 Task 工具调用 `humanize:plan-compliance-checker` agent（sonnet 模型）：
   ```
   Task 工具参数：
   - model: "sonnet"
   - prompt: 包含计划文件内容并要求 agent：
     1. 探索仓库结构（README、CLAUDE.md、主要文件）
     2. 检查计划内容是否与此仓库相关
     3. 检查计划是否包含分支切换指令
     4. 精确返回以下之一：`PASS: <summary>`、`FAIL_RELEVANCE: <reason>` 或 `FAIL_BRANCH_SWITCH: <details>`
   ```

3. **解析结果**（失败即关闭）：
   - 如果输出包含 `PASS`：继续到下面的设置脚本
   - 如果输出包含 `FAIL_RELEVANCE`：报告"计划合规性检查失败：该计划似乎与此仓库无关。"显示原因。**停止命令。**
   - 如果输出包含 `FAIL_BRANCH_SWITCH`：报告"计划合规性检查失败：该计划包含分支切换指令，与 RLCR 不兼容。RLCR 循环要求工作分支在所有轮次中保持不变。"显示详情。**停止命令。**
   - 如果输出不包含以上任何内容（格式错误）：报告"计划合规性检查产生了意外输出，无法继续。"**停止命令。**

---

## 计划理解测验

在运行设置脚本之前，验证用户是否真正理解计划将做什么。这是一个建议性检查——它永远不会阻塞循环，但会捕获那些盲目接受生成计划而没有阅读的"一厢情愿"用户。

**跳过整个测验的条件**（满足任一即可）：
- `$ARGUMENTS` 包含 `--skip-impl`（没有计划可以测验）
- `$ARGUMENTS` 包含 `--yolo`（用户明确选择退出所有预检查）
- `$ARGUMENTS` 包含 `--skip-quiz`（用户明确选择退出测验）
- `$ARGUMENTS` 包含 `-h` 或 `--help`（仅显示帮助）
- 没有可用的计划内容（由于无法确定计划文件路径而跳过了合规性预检查）

### 运行测验 agent

1. 复用上面合规性预检查中已经读取的计划内容（不要重新读取文件）。

2. 使用 Task 工具调用 `humanize:plan-understanding-quiz` agent（opus 模型）：
   ```
   Task 工具参数：
   - model: "opus"
   - prompt: 包含计划文件内容并要求 agent：
     1. 探索仓库结构以获取上下文
     2. 分析计划的技术实现细节
     3. 生成 2 个选择题（各 4 个选项）和一个计划摘要
     4. 返回结构化格式：QUESTION_1、OPTION_1A-D、ANSWER_1、QUESTION_2、OPTION_2A-D、ANSWER_2、PLAN_SUMMARY
   ```

3. **解析结果**：从 agent 输出中提取所有 13 个字段（QUESTION_1、OPTION_1A 到 OPTION_1D、ANSWER_1、QUESTION_2、OPTION_2A 到 OPTION_2D、ANSWER_2、PLAN_SUMMARY）。如果输出格式错误（任何字段缺失或 ANSWER 不是 A/B/C/D），警告："计划理解测验不可用，跳过继续。"并继续到下面的设置部分。

### 提问并评估

4. 使用 AskUserQuestion 将 QUESTION_1 作为选择题呈现，包含 4 个选项（OPTION_1A 到 OPTION_1D）。将用户的选择与 ANSWER_1 比较：
   - 如果用户选择了正确答案，标记 QUESTION_1 为 **PASS**
   - 否则，标记为 **WRONG**

5. 使用 AskUserQuestion 将 QUESTION_2 作为选择题呈现，包含 4 个选项（OPTION_2A 到 OPTION_2D）。使用相同标准将用户的选择与 ANSWER_2 比较。

### 决定是否继续

6. **如果两个问题都 PASS**：简要确认（"你对计划的理解看起来很扎实。继续设置。"）并继续到下面的设置部分。

7. **如果一个或两个问题 WRONG**：向用户显示 PLAN_SUMMARY 以帮助他们理解计划的作用以及他们答错的问题的正确答案。然后使用 AskUserQuestion 提问："你想继续 RLCR 循环，还是先停下来更仔细地审查计划？"选项如下：
   - "继续 RLCR 循环"
   - "先停下来审查计划"

   - 如果用户选择 **"继续 RLCR 循环"**：继续到下面的设置部分。
   - 如果用户选择 **"先停下来审查计划"**：报告"已停止。请审查计划文件并在准备好时重新运行 start-rlcr-loop。"**停止命令。**

---

## 设置

如果预检查通过（或被跳过），且测验通过（或被跳过或用户选择继续），执行设置脚本以初始化循环：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh" $ARGUMENTS
```

此命令启动一个迭代开发循环，其中：

1. 你使用任务标签路由执行实施计划
   - `coding` 任务：Claude 直接执行
   - `analyze` 任务：通过 `/humanize:ask-codex` 执行
2. 将你的工作总结写入指定的摘要文件
3. 当你尝试退出时，Codex 审查你的摘要
4. 如果 Codex 发现问题，你会收到反馈并继续
5. 如果 Codex 输出 "COMPLETE"，循环进入**审查阶段**
6. 在审查阶段，`codex review --base <branch>` 执行代码审查
7. 如果代码审查发现问题（`[P0-9]` 标记），你修复它们并继续
8. 当没有发现问题时，循环以 Finalize 阶段结束

## 什么是轮次

**一轮 = agent 认为整个计划已完成。** 轮次边界是 agent 写入摘要并尝试退出，触发 Codex 审查的时刻。这是基本语义：

- 一轮不是一个任务、一个里程碑、一个阶段或计划的一层。
- 如果计划有多个阶段或里程碑，它们都在写入轮次摘要之前在单轮内完成。
- 中间进度检查（例如，在开始下一阶段之前验证当前阶段）应使用手动 `ask-codex` 调用，而不是轮次边界。
- 仅当你认为计划中的所有任务都已完成时，才写入 `round-N-summary.md` 并尝试退出。

## Goal Tracker 系统

此循环使用 **Goal Tracker** 来防止迭代间的目标漂移：

### 结构
- **不可变部分**：终极目标和验收标准（在第 0 轮设置，永不更改）
- **可变部分**：活跃任务、已完成项目、已推迟项目、计划演进日志

### 关键特性
1. **验收标准**：每个任务映射到特定的 AC——不会有任何东西被"遗忘"
2. **任务标签路由**：每个任务应携带来自计划生成的 `coding` 或 `analyze` 标签
   - `coding -> Claude`，`analyze -> Codex`
3. **计划演进日志**：如果你发现计划需要更改，记录更改及理由
4. **显式推迟**：推迟的任务需要充分的理由和影响分析
5. **全面对齐检查**：在可配置的间隔（默认每 5 轮：第 4、9、14 轮等），Codex 进行全面的目标对齐审计。使用 `--full-review-round N` 自定义（最小值：2）

### 使用方法
1. **第 0 轮**：使用终极目标和验收标准初始化 Goal Tracker
2. **每轮**：更新任务状态、记录计划更改、记录发现的问题
3. **退出前**：确保 goal-tracker.md 准确反映当前状态

## 重要规则

1. **写摘要**：退出前始终将你的工作总结写入指定文件
2. **维护 Goal Tracker**：保持 goal-tracker.md 与你的进度同步更新
3. **彻底**：包含关于实现了什么、更改了哪些文件、添加了哪些测试的详细信息
4. **不要作弊**：不要尝试通过编辑状态文件或运行取消命令来退出循环
5. **信任过程**：Codex 的反馈有助于改进实现

## BitLesson 工作流（项目级别）

每个项目必须维护自己的 `.humanize/bitlesson.md` 文件。
如果缺失，`start-rlcr-loop` 会自动使用严格模板初始化它。

每轮要求：
1. 执行前读取 `.humanize/bitlesson.md`
2. 为每个任务/子任务运行 `bitlesson-selector`
3. 在实现过程中应用选定的课程 ID（或 `NONE`）
4. 在轮次摘要中包含 `## BitLesson Delta`，带 `Action: none|add|update`

如果问题在多轮后才解决，在 `.humanize/bitlesson.md` 中添加或更新精确的课程条目（具体问题 + 具体解决方案）。
默认情况下，空的 `.humanize/bitlesson.md` 不会阻塞 `Action: none`；使用 `--require-bitlesson-entry-for-none` 强制严格阻塞。

## 停止循环

- 达到最大迭代次数，除非启用了 `--strict-success`
- Codex 确认完成（"COMPLETE"），随后成功的代码审查（没有 `[P0-9]` 问题）
- 用户运行 `/humanize:cancel-rlcr-loop`

启用 `--strict-success` 时，最大迭代和停滞 STOP 检查会变为恢复提示而非终止退出。当优化循环必须持续到实际达到可接受目标时使用此选项。

## 两阶段系统

RLCR 循环在活跃循环内有两个阶段：

1. **实现阶段**：按任务标签工作（`coding -> Claude`，`analyze -> /humanize:ask-codex`），然后 Codex 审查你的摘要
2. **审查阶段**：在 COMPLETE 之后，`codex review` 使用 `[P0-9]` 严重性标记检查代码质量

`--base-branch` 选项指定代码审查比较的基础分支。如果未提供，它会自动检测：远程默认 > 本地 main > 本地 master。

## 跳过实现模式

使用 `--skip-impl` 跳过实现阶段，直接进入代码审查：

```bash
/humanize:start-rlcr-loop --skip-impl
```

在此模式下：
- 计划文件是可选的（不需要）
- 不需要初始化 goal tracker
- 当你尝试退出时立即开始代码审查
- 适用于在没有实施计划的情况下审查现有更改

当你想要：
- 审查在 RLCR 循环之外进行的代码更改
- 获取现有工作的代码质量反馈
- 为简单任务跳过实现跟踪开销时，这很有帮助
