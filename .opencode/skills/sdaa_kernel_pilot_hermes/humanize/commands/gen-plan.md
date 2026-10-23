---
description: "从草稿文档生成实施计划"
argument-hint: "--input <path/to/draft.md> --output <path/to/plan.md> [--auto-start-rlcr-if-converged] [--discussion|--direct]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-plan-io.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh:*)"
  - "Read"
  - "Glob"
  - "Grep"
  - "Task"
  - "Write"
  - "AskUserQuestion"
---

# 从草稿生成计划

请仔细阅读并执行以下内容。

## 硬性约束：计划生成期间禁止编码

本命令在规划阶段只能生成计划文档。在生成计划期间不得实施任务、修改仓库源代码或创建提交/PR。

允许的写入（在任何可选自动启动之前）仅限于：
- 计划输出文件（`--output`）
- 可选的翻译语言变体（仅在配置了 `ALT_PLAN_LANGUAGE` 时）

如果启用了 `--auto-start-rlcr-if-converged`，命令可以通过运行 `/humanize:start-rlcr-loop <output-plan-path>` 立即启动 RLCR 循环，但仅在 `discussion` 模式下且 `PLAN_CONVERGENCE_STATUS=converged` 且没有待处理的用户决策时。所有编码发生在后续命令/循环中，而非计划生成期间。

本命令将用户的草稿文档转换为结构良好的实施计划，包含明确的目标、验收标准（AC-X 格式）、路径边界和可行性建议。

## 工作流程概览

> **顺序执行约束**：以下所有阶段必须严格按顺序执行。不得跨不同阶段并行化工具调用。每个阶段必须完全完成后才能开始下一个。

1. **执行模式设置**：从命令参数解析可选行为
2. **加载项目配置**：解析 `alternative_plan_language` 和 `gen_plan_mode` 的合并 Humanize 配置默认值
3. **IO 验证**：验证输入和输出路径
4. **相关性检查**：验证草稿与仓库相关
5. **Codex 首轮分析**：在 Claude 合成计划详情之前使用一次规划 Codex
6. **Claude 候选计划（v1）**：Claude 从草稿 + Codex 发现构建初始计划
7. **迭代收敛循环**：Claude 和第二个 Codex 迭代挑战/优化计划合理性
8. **问题和分歧解决**：解决未解决的相反意见（或在已收敛、自动启动模式已启用且 `GEN_PLAN_MODE=discussion` 时跳过手动审查）
9. **最终计划生成**：生成带任务路由标签的收敛结构化 plan.md
10. **写入并完成**：写入输出文件，可选写入翻译语言变体，可选自动启动实施，并报告结果

---

## 阶段 0：执行模式设置

解析 `$ARGUMENTS` 并设置：
- 如果存在 `--auto-start-rlcr-if-converged`，则 `AUTO_START_RLCR_IF_CONVERGED=true`
- 否则 `AUTO_START_RLCR_IF_CONVERGED=false`
- 如果存在 `--discussion`，则 `GEN_PLAN_MODE_DISCUSSION=true`
- 如果存在 `--direct`，则 `GEN_PLAN_MODE_DIRECT=true`
- 如果同时存在 `--discussion` 和 `--direct`，报告错误"Cannot use --discussion and --direct together"并停止

`AUTO_START_RLCR_IF_CONVERGED=true` 允许跳过手动计划审查并立即开始实施（通过调用 `/humanize:start-rlcr-loop <output-plan-path>`），但仅在 `GEN_PLAN_MODE=discussion`、计划已收敛且没有待处理的用户决策时。在 `direct` 模式下此条件永远不满足。

---

## 阶段 0.5：加载项目配置

设置执行模式标志后，使用 `${CLAUDE_PLUGIN_ROOT}/scripts/lib/config-loader.sh` 解析配置。复用该行为；不要直接读取 `.humanize/config.json`。

### 配置合并语义

1. Source `${CLAUDE_PLUGIN_ROOT}/scripts/lib/config-loader.sh`.
2. Call `load_merged_config "${CLAUDE_PLUGIN_ROOT}" "${PROJECT_ROOT}"` to obtain `MERGED_CONFIG_JSON`, where `PROJECT_ROOT` is the repository root where the command was invoked.
3. `load_merged_config` merges these layers in order:
   - Required default config: `${CLAUDE_PLUGIN_ROOT}/config/default_config.json`
   - Optional user config: `${XDG_CONFIG_HOME:-$HOME/.config}/humanize/config.json`
   - Optional project config: `${HUMANIZE_CONFIG:-$PROJECT_ROOT/.humanize/config.json}`
4. 后续层覆盖前面的层。格式错误的可选 JSON 对象作为警告并被忽略。格式错误的必需默认配置、缺少 `jq` 或任何其他致命的 `load_merged_config` 失败都是配置错误，必须停止命令。

### 需要提取的值

使用 `get_config_value` 对 `MERGED_CONFIG_JSON` 读取：

- 从 `alternative_plan_language` 获取 `CONFIG_ALT_LANGUAGE_RAW`
- 从 `gen_plan_mode` 获取 `CONFIG_GEN_PLAN_MODE_RAW`
- 从 `chinese_plan` 获取 `CONFIG_CHINESE_PLAN_RAW`（仅旧版回退）

同时检测 `alternative_plan_language` 是否明确存在于 `MERGED_CONFIG_JSON` 中，以便空字符串仍算作显式覆盖：

- 当 `MERGED_CONFIG_JSON` 包含 `alternative_plan_language` 键时，`HAS_ALT_LANGUAGE_KEY=true`
- 否则 `HAS_ALT_LANGUAGE_KEY=false`

### 替代语言解析

1. 使用以下优先级解析有效的 `alternative_plan_language` 值：
   - 合并配置中的 `alternative_plan_language`，当 `HAS_ALT_LANGUAGE_KEY=true` 时（即使值为空字符串）
   - 已弃用的合并配置中的 `chinese_plan`，仅当 `HAS_ALT_LANGUAGE_KEY=false` 时
   - 默认禁用状态
2. 已弃用 `chinese_plan` 的向后兼容：
   - 如果 `HAS_ALT_LANGUAGE_KEY=true` 且 `CONFIG_CHINESE_PLAN_RAW` 为 `true`，记录日志：`Warning: deprecated "chinese_plan" field ignored; "alternative_plan_language" takes precedence. Remove "chinese_plan" from your humanize config.`
   - 如果 `HAS_ALT_LANGUAGE_KEY=false` 且 `CONFIG_CHINESE_PLAN_RAW` 为 `true`，将有效的 `alternative_plan_language` 视为 `"Chinese"`。记录日志：`Warning: deprecated "chinese_plan" field detected. Replace it with "alternative_plan_language": "Chinese" in your humanize config.`
   - 否则将有效的 `alternative_plan_language` 视为禁用。
3. 使用下面的内置映射表从有效的 `alternative_plan_language` 值解析 `ALT_PLAN_LANGUAGE` 和 `ALT_PLAN_LANG_CODE`。匹配**不区分大小写**。

   | Language   | Code | Suffix |
   |------------|------|--------|
   | Chinese    | zh   | `_zh`  |
   | Korean     | ko   | `_ko`  |
   | Japanese   | ja   | `_ja`  |
   | Spanish    | es   | `_es`  |
   | French     | fr   | `_fr`  |
   | German     | de   | `_de`  |
   | Portuguese | pt   | `_pt`  |
   | Russian    | ru   | `_ru`  |
   | Arabic     | ar   | `_ar`  |

   匹配接受语言名称（例如 `"Chinese"`）和 ISO 639-1 代码（例如 `"zh"`），均不区分大小写。匹配前修剪前导/尾随空格。

   - 如果值为空或不存在：设置 `ALT_PLAN_LANGUAGE=""` 和 `ALT_PLAN_LANG_CODE=""`（禁用）。
   - 如果值为 `"English"` 或 `"en"`（不区分大小写）：设置 `ALT_PLAN_LANGUAGE=""` 和 `ALT_PLAN_LANG_CODE=""`（无操作；计划已经是英文）。
   - 如果值匹配表中的语言名称或代码：设置 `ALT_PLAN_LANGUAGE` 为匹配的语言名称，`ALT_PLAN_LANG_CODE` 为对应的代码。
   - 如果值不匹配表中的任何语言名称或代码：设置 `ALT_PLAN_LANGUAGE=""` 和 `ALT_PLAN_LANG_CODE=""`（禁用）。记录日志：`Warning: unsupported alternative_plan_language "<value>". Supported values: Chinese (zh), Korean (ko), Japanese (ja), Spanish (es), French (fr), German (de), Portuguese (pt), Russian (ru), Arabic (ar). Translation variant will not be generated.`
4. 从合并配置解析 `CONFIG_GEN_PLAN_MODE_RAW`：
   - 有效值：`"discussion"` 或 `"direct"`（不区分大小写）。
   - 无效或不存在的值：视为不存在（回退到默认值），如果值存在但无效则记录警告。
5. 使用以下优先级（从高到低）解析 `GEN_PLAN_MODE`，CLI 标志优先于合并配置：
   - CLI 标志：如果 `GEN_PLAN_MODE_DISCUSSION=true`，设置 `GEN_PLAN_MODE=discussion`；如果 `GEN_PLAN_MODE_DIRECT=true`，设置 `GEN_PLAN_MODE=direct`
   - 合并配置的 `gen_plan_mode` 字段（如果有效）
   - 默认：`discussion`
6. 格式错误的可选用户或项目配置文件应由 `load_merged_config` 报告为警告，不得停止执行。在这些情况下，当没有更高优先级的值可用时，继续使用剩余的有效层和相同的有效默认值（`ALT_PLAN_LANGUAGE=""`、`ALT_PLAN_LANG_CODE=""` 和 `GEN_PLAN_MODE=discussion`）。

`ALT_PLAN_LANGUAGE` 和 `ALT_PLAN_LANG_CODE` 控制是否在阶段 8 写入输出文件的翻译语言变体。当 `ALT_PLAN_LANGUAGE` 非空时，生成带有 `_<ALT_PLAN_LANG_CODE>` 后缀的变体文件。

---

## 阶段 1：IO 验证

使用提供的参数执行验证脚本：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-plan-io.sh" $ARGUMENTS
```

**处理退出码：**
- 退出码 0：继续阶段 2。从标准输出解析 `TEMPLATE_FILE:` 行以获取模板路径。
- 退出码 1：报告"输入文件未找到"并停止
- 退出码 2：报告"输入文件为空"并停止
- 退出码 3：报告"输出目录不存在 - 请创建它"并停止
- 退出码 4：报告"输出文件已存在 - 请选择其他路径"并停止
- 退出码 5：报告"没有输出目录的写入权限"并停止
- 退出码 6：报告"参数无效"并显示用法，然后停止
- 退出码 7：报告"计划模板文件未找到 - 插件配置错误"并停止

**注意：** 验证脚本无副作用。它不会创建输出文件。

---

## 阶段 2：相关性检查

IO 验证通过后，检查草稿是否与此仓库相关。

> **注意**：不要在此检查上花费太多时间。只要草稿与当前项目不是完全无关 — 不像船舶设计和蛋糕配方之间的差异 — 就通过。

1. 读取输入草稿文件以获取其内容
2. 使用 Task 工具调用 `humanize:draft-relevance-checker` 代理（haiku 模型）：
   ```
   Task 工具参数：
   - model: "haiku"
   - prompt: 包含草稿内容并要求代理：
     1. 探索仓库结构（README、CLAUDE.md、主要文件）
     2. 分析草稿内容是否与此仓库相关
     3. 返回 `RELEVANT: <reason>` 或 `NOT_RELEVANT: <reason>`
   ```

3. **如果为 NOT_RELEVANT**：
   - 报告："草稿内容似乎与此仓库无关。"
   - 显示相关性检查的原因
   - 停止命令

4. **如果为 RELEVANT**：通过复制模板并追加草稿来创建输出计划文件：
   ```bash
   cp "$TEMPLATE_FILE" "$OUTPUT_FILE" && echo "" >> "$OUTPUT_FILE" && echo "--- Original Design Draft Start ---" >> "$OUTPUT_FILE" && echo "" >> "$OUTPUT_FILE" && cat "$INPUT_FILE" >> "$OUTPUT_FILE" && echo "" >> "$OUTPUT_FILE" && echo "--- Original Design Draft End ---" >> "$OUTPUT_FILE"
   ```
   然后继续阶段 3。

---

## 阶段 3：Codex 首轮分析

相关性检查后，在 Claude 合成计划之前调用 Codex。

此 Codex 轮次是 Claude 合成计划详情之前的首次规划分析。

1. 运行：
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" "<structured prompt>"
   ```
2. 结构化提示必须包含：
   - 仓库上下文（项目目的、相关文件）
   - 原始草稿内容
   - 明确请求批判假设、识别缺失需求并提出更强的计划方向
3. 要求 Codex 输出遵循以下格式：
   - `CORE_RISKS:` 最高风险假设和潜在失败模式
   - `MISSING_REQUIREMENTS:` 可能遗漏的需求或边缘情况
   - `TECHNICAL_GAPS:` 可行性或架构差距
   - `ALTERNATIVE_DIRECTIONS:` 可行的替代方案及其权衡
   - `QUESTIONS_FOR_USER:` 需要明确人工决策的问题
   - `CANDIDATE_CRITERIA:` 候选验收标准建议
4. 将此输出保留为 **Codex Analysis v1** 并输入 Claude 规划。
5. 从此分析中记录简洁的规划摘要。

### Codex 可用性处理

如果 `ask-codex.sh` 失败（缺少 Codex CLI、超时或运行时错误），使用 AskUserQuestion 让用户选择：
- 使用更新的 Codex 设置/环境重试
- 继续仅 Claude 规划（明确说明计划输出中交叉审查置信度降低）

---

## 阶段 4：Claude 候选计划（v1）

使用草稿内容 + Codex Analysis v1 生成初始候选计划和问题映射。

深入分析草稿中的潜在问题。使用 Explore 代理调查代码库。

与候选计划 v1 一起，准备涵盖范围、边界、依赖和已知风险的简洁实施摘要。

### 分析维度

1. **清晰度**：草稿的意图和目标是否表达清楚？
   - 目标是否明确定义？
   - 范围是否清晰？
   - 术语和概念是否明确？

2. **一致性**：草稿是否自相矛盾？
   - 需求是否内部一致？
   - 不同部分是否相互对齐？

3. **完整性**：是否有遗漏的考虑？
   - 使用 Explore 代理调查草稿可能影响的代码库部分
   - 识别未提及的依赖、副作用或相关组件
   - 检查草稿是否忽略了重要的边缘情况

4. **功能性**：设计是否有根本缺陷？
   - 提议的方法是否真的可行？
   - 是否有未解决的技术限制？
   - 设计是否会对现有功能产生负面影响？

### 探索策略

使用 `subagent_type: "Explore"` 的 Task 工具进行调查：
- 草稿中提到的组件
- 相关文件和目录
- 现有模式和惯例
- 依赖和集成

---

## 阶段 5：迭代收敛循环（Claude <-> 第二个 Codex）

如果 `GEN_PLAN_MODE=direct`，跳过此整个阶段。计划直接从候选计划 v1（阶段 4）进入阶段 6，不经过收敛轮次。由于没有收敛轮次或二轮审查发生，设置 `PLAN_CONVERGENCE_STATUS=partially_converged` 和 `HUMAN_REVIEW_REQUIRED=true`（direct 模式不得满足 `--auto-start-rlcr-if-converged` 条件）。

Claude 候选计划 v1 就绪后，使用第二个 Codex 轮次运行迭代挑战/优化轮次。

### 收敛轮次步骤

1. **第二个 Codex 合理性审查**
   - 运行：
     ```bash
     "${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" "<review current candidate plan>"
     ```
   - 提示必须包含当前候选计划、先前的分歧和未解决的项目
   - 要求输出格式：
     - `AGREE:` 被接受为合理的要点
     - `DISAGREE:` 被认为不合理的要点及原因
     - `REQUIRED_CHANGES:` 收敛前必须修复的项目
     - `OPTIONAL_IMPROVEMENTS:` 非阻塞的改进
     - `UNRESOLVED:` 需要用户决策的相反意见
2. **Claude 修订**
   - Claude 更新候选计划以解决 `REQUIRED_CHANGES`
   - Claude 记录接受/拒绝的建议及理由
3. **收敛评估**
   - 更新每轮收敛矩阵：
     - 主题
     - Claude 立场
     - 第二个 Codex 立场
     - 解决状态（`resolved`、`needs_user_decision`、`deferred`）
     - 轮次间增量

### 循环终止规则

重复收敛轮次直到以下之一为真：
- 没有 `REQUIRED_CHANGES` 且没有高影响的 `DISAGREE`
- 连续两轮未产生实质性计划变更
- 达到最大 3 轮

如果达到最大轮次时仍有未解决的相反意见，将它们明确携带到用户决策阶段。

明确设置收敛状态：
- 当满足收敛条件时 `PLAN_CONVERGENCE_STATUS=converged`
- 否则 `PLAN_CONVERGENCE_STATUS=partially_converged`

---

## 阶段 6：问题和分歧解决

> **关键**：草稿文档包含最有价值的人工输入。在问题解决期间，绝不丢弃或覆盖任何原始草稿内容。所有澄清应被视为补充草稿的增量添加，而非替换。同时跟踪原始草稿陈述和澄清后的信息。

### 步骤 1：手动审查门控

决定是否可以跳过手动审查：
- 如果 `GEN_PLAN_MODE=direct`，设置 `HUMAN_REVIEW_REQUIRED=true`
- 否则如果 `AUTO_START_RLCR_IF_CONVERGED=true` **且** `PLAN_CONVERGENCE_STATUS=converged`，设置 `HUMAN_REVIEW_REQUIRED=false`
- 否则设置 `HUMAN_REVIEW_REQUIRED=true`

如果 `HUMAN_REVIEW_REQUIRED=false`，跳过步骤 2-4 直接继续阶段 7。

### 步骤 1.5：整合待处理的用户决策（无条件运行）

在继续之前（无论 `HUMAN_REVIEW_REQUIRED`），将先前阶段中所有面向用户的问题整合到计划的 `## Pending User Decisions` 部分：

1. 从 Codex Analysis v1（阶段 3）提取 `QUESTIONS_FOR_USER` 项目
2. 从最终收敛矩阵（阶段 5）提取状态为 `needs_user_decision` 的项目 — 使用最后一轮的状态，而非中间轮次
3. 去重：如果同一主题出现在两个来源中，合并为一个条目
4. 对于每个收集的项目，检查它是否在阶段 4-5 计划优化期间得到实质性解决（即 Claude 处理了它且第二个 Codex 在后续轮次中同意）。仅删除有明确解决证据的项目。
5. 将所有剩余未解决的项目写入计划的 `## Pending User Decisions` 部分。使用 `DEC-N` 标识符。设置 `Decision Status` 为 `PENDING`。
   - 对于 Claude 与 Codex 的分歧：填写 `Claude Position`、`Codex Position` 和 `Tradeoff Summary`
   - 对于开放问题（无对立立场）：设置 `Claude Position` 为 Claude 的暂定答案（如有），`Codex Position` 为 `N/A - open question`，`Tradeoff Summary` 为问题的上下文

这确保：
- 当 `HUMAN_REVIEW_REQUIRED=true`：项目对步骤 2-4 用户解决可见
- 当 `HUMAN_REVIEW_REQUIRED=false`：项目通过阶段 8 步骤 5 的 `PENDING` 检查阻止自动启动

### 步骤 2：解决分析问题（需要手动审查时）

如果在 Codex 优先分析、Claude 分析或收敛循环期间发现任何问题，使用 AskUserQuestion 与用户澄清。

对于每个有问题的问题类别，呈现：
- 问题是什么
- 为什么重要
- 解决方案选项（如适用）

继续此对话直到所有重要问题被解决或被用户确认。

### 步骤 3：确认量化指标（需要手动审查时）

所有分析问题解决后，检查草稿中的任何量化指标或数值阈值，例如：
- 性能目标："低于 15GB/s"、"低于 100ms 延迟"
- 大小约束："低于 300KB"、"最大 1MB"
- 数量限制："超过 10 个文件"、"至少 5 次重试"
- 百分比目标："95% 覆盖率"、"减少 50%"

对于找到的每个量化指标，使用 AskUserQuestion 与用户明确确认：
- 这是实施被视为成功必须达到的**硬性要求**？
- 还是描述一个**优化趋势/方向**，即使未达到精确数字，向目标的改进也是可接受的？

记录每个指标的用户答案，因为此区分显著影响计划中验收标准的编写方式。

---

### 步骤 4：解决未解决的 Claude/Codex 分歧（需要手动审查时）

对于每个标记为 `needs_user_decision` 的项目，明确要求用户做出决定。

对于每个未解决的分歧，呈现：
- 决策主题
- Claude 的立场
- Codex 的立场
- 各选项的权衡和风险
- 明确的建议（如果某个选项明显更安全）

如果用户未立即决定，将项目保留在计划中作为 `PENDING`，放在专门的用户决策部分下。

---

## 阶段 7：最终计划生成

深入思考并按以下规则生成 plan.md：

### 计划结构

```markdown
# <计划标题>

## Goal Description
<清晰、直接地描述需要完成的内容>

## Acceptance Criteria

遵循 TDD 理念，每个标准包含正向和反向测试以进行确定性验证。

- AC-1: <第一个标准>
  - Positive Tests (expected to PASS):
    - <标准满足时应成功的测试用例>
    - <另一个成功用例>
  - Negative Tests (expected to FAIL):
    - <正常工作时应失败/被拒绝的测试用例>
    - <另一个失败/拒绝用例>
  - AC-1.1: <需要时的子标准>
    - Positive: <...>
    - Negative: <...>
- AC-2: <第二个标准>
  - Positive Tests: <...>
  - Negative Tests: <...>
...

## Path Boundaries

路径边界定义实施质量和选择的可接受范围。

### Upper Bound (Maximum Acceptable Scope)
<最全面可接受实施的肯定性描述>
<这代表在不过度工程化的情况下完成目标>
示例："实施包含 X、Y 和 Z 功能，具有完整测试覆盖"

### Lower Bound (Minimum Acceptable Scope)
<最小可行实施的肯定性描述>
<这代表仍满足所有验收标准的最少工作量>
示例："实施包含核心功能 X，具有基本验证"

### Allowed Choices
<对实施决策可接受的选项>
- 可以使用：<允许的技术、方法、模式>
- 不可以使用：<禁止的技术、方法、模式>

> **关于确定性设计的说明**：如果草稿指定了高度确定性的设计且无选择（例如，"必须使用 JSON 格式"、"必须使用算法 X"），则路径边界应反映此狭窄约束。在这种情况下，上限和下限可能收敛到同一点，"Allowed Choices" 应明确说明选择按草稿规范固定。

## Feasibility Hints and Suggestions

> **注意**：本部分仅供参考和理解。这些是概念性建议，而非规定性要求。

### Conceptual Approach
<文本描述、伪代码或图表，展示一种可能的实施路径>

### Relevant References
<可能有用的代码路径和概念>
- <path/to/relevant/component> - <简要描述>

## Dependencies and Sequence

### Milestones
1. <里程碑 1>: <描述>
   - Phase A: <...>
   - Phase B: <...>
2. <里程碑 2>: <描述>
   - Step 1: <...>
   - Step 2: <...>

<描述组件之间的相对依赖关系，而非时间估计>

## Task Breakdown

每个任务必须包含恰好一个路由标签：
- `coding`：由 Claude 实施
- `analyze`：通过 Codex 执行（`/humanize:ask-codex`）

| Task ID | Description | Target AC | Tag (`coding`/`analyze`) | Depends On |
|---------|-------------|-----------|----------------------------|------------|
| task1 | <...> | AC-1 | coding | - |
| task2 | <...> | AC-2 | analyze | task1 |

## Claude-Codex Deliberation

### Agreements
- <双方同意的要点>

### Resolved Disagreements
- <主题>：Claude vs Codex 摘要、选择的解决方案和理由

### Convergence Status
- Final Status: `converged` 或 `partially_converged`

## Pending User Decisions

- DEC-1: <决策主题>
  - Claude Position: <...>
  - Codex Position: <...>
  - Tradeoff Summary: <...>
  - Decision Status: `PENDING` 或 `<用户的最终决定>`

## Implementation Notes

### Code Style Requirements
- 实施代码和注释不得包含计划特定术语，如 "AC-"、"Milestone"、"Step"、"Phase" 或类似工作流标记
- 这些术语仅用于计划文档，不用于生成的代码库
- 在代码中使用描述性的、领域适当的命名

## Output File Convention

此模板用于生成主输出文件（例如 `plan.md`）。

### Translated Language Variant

当 `alternative_plan_language` 通过合并配置加载解析为支持的语言名称时，主文件之后还会写入输出文件的翻译变体。Humanize 按以下顺序从合并层加载配置：默认配置、可选用户配置、然后可选项目配置；`alternative_plan_language` 可以在任何这些层中设置。变体文件名通过在文件扩展名之前插入 `_<code>`（来自内置映射表的 ISO 639-1 代码）来构建：

- `plan.md` 变为 `plan_<code>.md`（例如中文为 `plan_zh.md`，韩文为 `plan_ko.md`）
- `docs/my-plan.md` 变为 `docs/my-plan_<code>.md`
- `output`（无扩展名）变为 `output_<code>`

翻译变体文件包含主计划文件当前内容的完整翻译，使用配置的语言。所有标识符（`AC-*`、任务 ID、文件路径、API 名称、命令标志）保持不变，因为它们是语言中性的。

当 `alternative_plan_language` 为空、不存在、设置为 `"English"` 或设置为不支持的语言时，不写入翻译变体。当没有项目配置文件时，Humanize 不会自动创建 `.humanize/config.json`。
```

### 生成规则

1. **术语**：使用 Milestone、Phase、Step、Section。绝不使用 Day、Week、Month、Year 或时间估计。

2. **无行号**：仅通过路径引用代码（例如 `src/utils/helpers.ts`），绝不使用行范围。

3. **无时间估计**：不要估计持续时间、工作量或代码行数。

4. **概念性而非规定性**：路径边界和建议指导而非强制。

5. **AC 格式**：所有验收标准必须使用 AC-X 或 AC-X.Y 格式。

6. **清晰的依赖**：显示什么依赖什么，而非何时发生。

7. **TDD 风格测试**：每个验收标准必须包含正向测试（预期通过）和反向测试（预期失败）。这遵循测试驱动开发理念并实现确定性验证。

8. **肯定性路径边界**：使用肯定性语言描述上限和下限（什么是可接受的），而非否定性语言（什么是不可接受的）。

9. **尊重确定性设计**：如果草稿指定了无选择的固定方法，通过缩小路径边界以匹配用户规范来在计划中反映这一点。

10. **代码风格约束**：生成的计划必须包含一个部分或说明，指示实施代码和注释不得包含计划特定的进度术语，如 "AC-"、"Milestone"、"Step"、"Phase" 或类似工作流标记。这些术语属于计划文档，不属于生成的代码库。

11. **草稿完整性要求**：生成的计划必须纳入输入草稿文档中的所有信息，不得遗漏。草稿代表最有价值的人工输入，必须完全保留。通过阶段 6 获得的任何澄清应增量添加到草稿的原始内容，绝不替换或丢失任何原始要求。最终计划必须是草稿信息加上所有澄清细节的超集。

12. **辩论可追溯性**：计划必须包含 Codex 优先发现、Claude/Codex 协议、已解决的分歧和未解决的决策。未解决的相反意见必须记录在 `## Pending User Decisions` 中以供用户明确决策。

13. **收敛要求**：计划必须在 `## Claude-Codex Deliberation` 中记录 Claude/Codex 协议、已解决的分歧和最终收敛状态。仅在满足收敛条件或达到最大轮次且有明确的携带决策时停止。

14. **任务标签要求**：计划必须包含 `## Task Breakdown`，每个任务必须标记为 `coding` 或 `analyze`（无未标记任务，无其他标签值）。

---

## 阶段 8：写入并完成

输出文件已包含计划模板结构和原始草稿内容（相关性检查后合并）。现在通过以下步骤完成计划：

### 步骤 1：更新计划内容

使用 **Edit 工具**（而非 Write）更新计划文件：
- 用实际计划内容替换模板占位符
- 保持原始草稿部分在文件底部完整
- 最终文件应同时包含结构化计划和原始草稿以供参考

### 步骤 2：全面审查

更新后，**读取完整的计划文件**并验证：
- 计划完整且全面
- 所有部分相互一致
- 结构化计划与原始草稿内容对齐
- Claude/Codex 分歧处理明确且正确反映
- 文档不同部分之间不存在矛盾

如果发现不一致，使用 Edit 工具修复。

### 步骤 3：语言统一

检查更新后的计划文件是否包含多种语言（例如混合英文和中文内容）。

如果检测到多种语言：
1. 使用 **AskUserQuestion** 询问用户：
   - 是否要统一语言
   - 使用哪种语言进行统一
2. 如果用户选择统一：
   - 将所有内容翻译为选定的语言
   - 确保含义和意图保持不变
   - 使用 Edit 工具应用翻译
3. 如果用户拒绝，保持文档不变

### 步骤 4：写入翻译语言变体（条件性）

如果 `ALT_PLAN_LANGUAGE` 非空（启用了翻译），写入输出文件的翻译变体。

**语言统一保护**：如果主计划文件在步骤 3（语言统一）中已统一为 `ALT_PLAN_LANGUAGE`，则跳过此步骤。记录日志：`Main plan file is already in <ALT_PLAN_LANGUAGE>; translated variant not needed.`

**文件名构建规则** - 在文件扩展名之前插入 `_<ALT_PLAN_LANG_CODE>`：
- `plan.md` 变为 `plan_<code>.md`（例如 `plan_zh.md`、`plan_ko.md`）
- `docs/my-plan.md` 变为 `docs/my-plan_<code>.md`
- `output`（无扩展名）变为 `output_<code>`

算法：
1. 在基本文件名中找到最后一个 `.`。
2. 如果找到 `.`，在其前面插入 `_<ALT_PLAN_LANG_CODE>`：`<stem>_<code>.<extension>`。
3. 如果未找到 `.`（无扩展名），在文件名后追加 `_<ALT_PLAN_LANG_CODE>`：`<filename>_<code>`。
4. 变体文件放置在与主输出文件相同的目录中。

**变体文件内容**：
- 将主计划文件的当前内容（步骤 3 语言统一后）翻译为 `ALT_PLAN_LANGUAGE`。中文默认使用简体中文。
- 部分标题、AC 标签、任务 ID、文件路径、API 名称和命令标志必须保持不变（标识符是语言中性的）。
- 变体文件是同一计划的翻译阅读视图；不得添加主文件中不存在的新信息。
- 底部的原始草稿部分应保持原样（不重新翻译）。

如果 `ALT_PLAN_LANGUAGE` 为空（默认），不要创建翻译变体文件。

### 步骤 5：可选直接工作启动

如果以下全部为真：
- `AUTO_START_RLCR_IF_CONVERGED=true`
- `PLAN_CONVERGENCE_STATUS=converged`
- `GEN_PLAN_MODE=discussion`
- 没有状态为 `PENDING` 的待处理决策

则通过运行立即开始工作：

```bash
/humanize:start-rlcr-loop --skip-quiz <output-plan-path>
```

传递 `--skip-quiz` 标志是因为用户已通过 gen-plan 收敛讨论证明了对计划的理解。

如果命令调用在此上下文中不可用，回退到设置脚本：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh" --skip-quiz --plan-file <output-plan-path>
```

如果自动启动尝试失败，报告失败原因并提供用户要运行的确切手动命令：

```bash
/humanize:start-rlcr-loop <output-plan-path>
```

### 步骤 6：报告结果

向用户报告：
- 生成的计划路径
- 包含内容的摘要
- 定义的验收标准数量
- 执行的收敛轮次数
- 未解决的用户决策数量（如有）
- 是否统一了语言（如适用）
- 是否尝试了直接工作启动及其结果

---

## 错误处理

如果在计划生成期间出现需要用户输入的问题：
- 使用 AskUserQuestion 澄清
- 在计划上下文中记录任何用户决策

如果启用了自动启动模式但未满足收敛条件：
- 解释为什么跳过了直接启动
- 告诉用户要么解决待处理决策，要么手动运行 `/humanize:start-rlcr-loop <plan.md>`

如果无法生成完整计划：
- 解释缺少什么信息
- 建议用户如何改进他们的草稿
