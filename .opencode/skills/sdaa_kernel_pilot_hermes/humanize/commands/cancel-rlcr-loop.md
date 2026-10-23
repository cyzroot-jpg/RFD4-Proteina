---
description: "取消活跃的 RLCR 循环"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cancel-rlcr-loop.sh)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cancel-rlcr-loop.sh --force)", "AskUserQuestion"]
disable-model-invocation: true
---

# 取消 RLCR 循环

要取消活跃的循环：

1. 运行取消脚本：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-rlcr-loop.sh"
```

2. 检查输出的第一行：
   - **NO_LOOP** 或 **NO_ACTIVE_LOOP**：提示"未找到活跃的 RLCR 循环。"
   - **CANCELLED**：报告输出中的取消消息
   - **CANCELLED_METHODOLOGY_ANALYSIS**：报告输出中的取消消息
   - **CANCELLED_FINALIZE**：报告输出中的取消消息
   - **FINALIZE_NEEDS_CONFIRM**：循环处于 Finalize 阶段。继续执行步骤 3

3. **如果为 FINALIZE_NEEDS_CONFIRM**：
   - 使用 AskUserQuestion 确认取消，选项如下：
     - 问题："循环当前处于 Finalize 阶段。此阶段完成后，循环将结束，不会返回 Codex 审查。您确定要立即取消吗？"
     - 标题："取消？"
     - 选项：
       1. 标签："是，立即取消"，描述："立即取消循环，finalize-state.md 将被重命名为 cancel-state.md"
       2. 标签："否，让它完成"，描述："继续执行 Finalize 阶段，循环将正常完成"
   - **如果用户选择"是，立即取消"**：
     - 运行：`"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-rlcr-loop.sh" --force`
     - 报告输出中的取消消息
   - **如果用户选择"否，让它完成"**：
     - 报告："已了解。Finalize 阶段将继续执行。完成后，循环将正常结束。"

**核心原则**：脚本处理所有取消逻辑。如果最新循环目录中存在 `state.md`（普通循环）、`methodology-analysis-state.md`（方法论分析阶段）或 `finalize-state.md`（Finalize 阶段），则循环处于活跃状态。

包含摘要、审查结果和状态信息的循环目录将被保留以供参考。
