# 方法论分析阶段

RLCR 循环已达到退出点。

**退出原因**：{{EXIT_REASON}} - {{EXIT_REASON_DESCRIPTION}}
**已完成轮次**：{{CURRENT_ROUND}} / {{MAX_ITERATIONS}}

在循环完全退出之前，请执行方法论改进分析。此分析旨在改进 Humanize 开发方法论本身——它与你刚刚工作的项目无关。

## 指令

### 1. 创建一个 Opus Agent 进行净化分析

使用 Agent 工具以 `model: "opus"` 创建一个分析 agent。给它以下任务：

**Agent 提示**：阅读 `{{LOOP_DIR}}` 中的开发记录：
- 所有匹配 `round-*-summary.md` 的文件
- 所有匹配 `round-*-review-result.md` 的文件

从**纯方法论角度**分析这些记录，并将你的发现写入 `{{LOOP_DIR}}/methodology-analysis-report.md`。

**关键净化规则** - 报告不得包含：
- 文件路径、目录路径或模块路径
- 函数名、变量名、类名或方法名
- 分支名称、提交哈希或 git 标识符
- 业务领域术语、产品名称或功能名称
- 任何类型的代码片段或代码片段
- 原始错误消息或堆栈跟踪
- 项目特定的 URL 或端点
- 任何可以识别特定项目的信息

**分析重点领域**：
- 迭代效率：轮次是否高效，还是重复了类似的工作？
- 反馈循环质量：审查者的反馈是否带来了有意义的改进？
- 停滞模式：是否有原地打转的迹象？
- 审查有效性：审查是否发现了真正的问题还是产生了误报？
- 计划与执行的对齐：执行是否遵循了计划还是偏离了？
- 轮次计数与进展比率：轮次数量是否与进展成比例？
- 沟通清晰度：摘要和审查是否清晰且可操作？

**输出格式**：编写一份包含方法论改进建议的结构化报告。每条建议应描述观察到的通用模式和对 RLCR 方法论的具体改进。如果未找到改进，请写一条简短说明，表明方法论在本次会话中运行良好。

### 2. 阅读分析报告

Agent 完成后，阅读 `{{LOOP_DIR}}/methodology-analysis-report.md`。所有后续面向用户的内容必须仅从此报告派生——不要直接引用原始开发记录。

### 3. 处理结果

**如果未找到改进**：简要告知用户方法论分析未发现重大改进建议。然后将完成说明写入 `{{LOOP_DIR}}/methodology-analysis-done.md` 并退出。

**如果找到改进**：

a) 向用户报告：
   - 退出原因的简要摘要（{{EXIT_REASON}}：{{EXIT_REASON_DESCRIPTION}}）
   - 报告中的方法论改进建议

b) 使用 `AskUserQuestion` 询问用户是否愿意通过打开 GitHub issue 来帮助改进 Humanize。强调：
   - 这完全是自愿的
   - 内容已完全净化（无项目特定信息）
   - 它有助于为每个人改进方法论

c) **如果用户拒绝**：感谢他们，将完成标记写入 `{{LOOP_DIR}}/methodology-analysis-done.md`，然后退出。

d) **如果用户同意**：
   - 从分析报告中起草 GitHub issue 标题和正文
   - 通过第二次 `AskUserQuestion` 展示草稿供用户审查和确认
   - 如果确认：运行 `gh issue create --repo PolyArch/humanize --title "..." --body "..."`
   - 如果 `gh` 不可用，请提供标题和正文，以便用户手动创建 issue
   - 将完成标记写入 `{{LOOP_DIR}}/methodology-analysis-done.md` 并退出

### 4. 完成标记

你必须在退出之前将有意义的内容写入 `{{LOOP_DIR}}/methodology-analysis-done.md`。此文件表示分析阶段已完成。简要总结所做的事情（例如，"分析完成，无建议"或"分析完成，已提交 issue"）即可。
