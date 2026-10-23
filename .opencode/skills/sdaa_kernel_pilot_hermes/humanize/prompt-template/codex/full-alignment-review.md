# 全面目标对齐检查 - 第 {{CURRENT_ROUND}} 轮

这是一个**强制性检查点**（按可配置的间隔执行）。你必须进行全面的目标对齐审计。

## 原始实施计划

**重要**：Claude 正在实施的原始计划位于：
@{{PLAN_FILE}}

你必须在进行审查之前先阅读此计划文件，以了解工作的完整范围。

---
## Claude 的工作总结
<!-- CLAUDE's WORK SUMMARY START -->
{{SUMMARY_CONTENT}}
<!-- CLAUDE's WORK SUMMARY  END  -->
---

{{COMMIT_HISTORY_SECTION}}

## 第1部分：目标跟踪器审计（强制）

阅读 @{{GOAL_TRACKER_FILE}} 并验证：

### 1.1 验收标准状态
针对不可变部分中的每个验收标准：
| AC | 状态 | 证据（如已满足） | 阻塞项（如未满足） | 理由（如已延期） |
|----|--------|-------------------|---------------------|----------------------------|
| AC-1 | MET / PARTIAL / NOT MET / DEFERRED | ... | ... | ... |
| ... | ... | ... | ... | ... |

### 1.2 遗漏项检测
将原始计划（@{{PLAN_FILE}}）与当前目标跟踪器进行比较：
- 是否有任务既不在"进行中"、"已完成"也不在"已延期"中？
- 是否有任务在摘要中标记为"已完成"但未经验证？
- 列出发现的任何遗漏项。

### 1.3 延期项审计
针对"明确延期"中的每个项目：
- 延期理由是否仍然有效？
- 根据当前进展是否应该取消延期？
- 是否与最终目标相矛盾？

### 1.4 目标完成摘要
```
Acceptance Criteria: X/Y met (Z deferred)
Active Tasks: N remaining
Estimated remaining rounds: ?
Critical blockers: [list if any]
```

## 第2部分：主线漂移审计（强制）

判断近期轮次是否仍在服务于原始计划：
- 当前轮次的主线目标是否清晰且单一？
- Claude 是在推进主线验收标准，还是主要在处理侧边问题？
- 哪些发现是真正的**阻塞性侧边问题**，哪些仅仅是**排队中的侧边问题**？

包含简短的漂移摘要：
```
Mainline Progress Verdict: ADVANCED / STALLED / REGRESSED
Blocking Side Issues: N
Queued Side Issues: N
```

`Mainline Progress Verdict` 行是强制性的。如果你遗漏了它，Humanize 停止钩子将阻止该轮次并要求重新运行审查。

## 第3部分：实施审查

- 对实施进行深入的批判性审查
- 验证 Claude 的声明是否与现实一致
- 识别任何差距、缺陷或未完成的工作
- 参考 @{{DOCS_PATH}} 获取设计文档

## 第4部分：{{GOAL_TRACKER_UPDATE_SECTION}}

## 第5部分：进展停滞检查（全面对齐轮次强制执行）

为实施 @{{PLAN_FILE}} 中的原始计划，我们已经完成了 **{{COMPLETED_ITERATIONS}} 次迭代**（第 0 轮到第 {{CURRENT_ROUND}} 轮）。

项目的 `.humanize/rlcr/{{LOOP_TIMESTAMP}}/` 目录包含每轮迭代的历史记录：
- 轮次输入提示：`round-N-prompt.md`
- 轮次输出摘要：`round-N-summary.md`
- 轮次审查提示：`round-N-review-prompt.md`
- 轮次审查结果：`round-N-review-result.md`

**如何访问历史文件**：使用以下文件路径阅读历史审查结果和摘要：
- `@.humanize/rlcr/{{LOOP_TIMESTAMP}}/round-{{PREV_ROUND}}-review-result.md`（上一轮）
- `@.humanize/rlcr/{{LOOP_TIMESTAMP}}/round-{{PREV_PREV_ROUND}}-review-result.md`（两轮前）
- `@.humanize/rlcr/{{LOOP_TIMESTAMP}}/round-{{PREV_ROUND}}-summary.md`（上一轮摘要）

**你的任务**：审查历史审查结果，特别是**近期轮次**的开发进展和审查结果，以确定开发是否已停滞。

**停滞迹象**（断路器触发条件）：
- 相同问题在多个轮次中反复出现
- 多个轮次中验收标准没有实质性进展
- Claude 反复犯同样的错误
- 循环讨论无法解决
- 尽管持续迭代但没有新的代码变更
- Codex 反复给出相似的反馈而 Claude 未予处理

**如果开发正在停滞**，请在审查输出 @{{REVIEW_RESULT_FILE}} 的最后一行写入 **STOP**（单独一个词占一行）来替代 COMPLETE。

## 第6部分：输出要求

- 如果发现问题或任何验收标准未满足（包括已延期的验收标准），请将你的发现写入 @{{REVIEW_RESULT_FILE}}
- 包含 Claude 需要处理的具体行动项，分类为：
  - 主线差距
  - 阻塞性侧边问题
  - 排队中的侧边问题
- **如果开发正在停滞**（参见第4部分），请在最后一行写入 "STOP"
- **关键要求**：只有当原始计划中的所有验收标准都完全满足且没有延期时，才在最后一行写入 "COMPLETE"
  - 延期项被视为未完成 - 如果有任何验收标准被延期，请勿输出 COMPLETE
  - COMPLETE 的唯一条件是：原始计划的所有任务都已完成，所有验收标准都已满足，不允许延期
