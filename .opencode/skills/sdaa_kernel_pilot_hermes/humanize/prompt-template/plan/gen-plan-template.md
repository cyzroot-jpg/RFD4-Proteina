# <Plan Title>

## 目标描述
<清晰、直接地描述需要完成的内容>

## 验收标准

遵循 TDD 哲学，每个标准都包含用于确定性验证的正向和反向测试。

- AC-1: <First criterion>
  - 正向测试（预期通过）：
    - <Test case that should succeed when criterion is met>
    - <Another success case>
  - 反向测试（预期失败）：
    - <Test case that should fail/be rejected when working correctly>
    - <Another failure/rejection case>
  - AC-1.1: <Sub-criterion if needed>
    - 正向: <...>
    - 反向: <...>
- AC-2: <Second criterion>
  - 正向测试: <...>
  - 反向测试: <...>
...

## 路径边界

路径边界定义了实施质量和选择的可接受范围。

### 上界（最大可接受范围）
<对最全面可接受实施的正面描述>
<这代表在不过度工程化的情况下完成目标>
示例："The implementation includes X, Y, and Z features with full test coverage"

### 下界（最小可接受范围）
<对最小可行实施的正面描述>
<这代表仍然满足所有验收标准的最少工作量>
示例："The implementation includes core feature X with basic validation"

### 允许的选择
<对实施决策可接受的选项>
- 可以使用: <technologies, approaches, patterns that are allowed>
- 不可使用: <technologies, approaches, patterns that are prohibited>

> **关于确定性设计的说明**：如果草案指定了没有选择空间的高度确定性设计（例如"必须使用 JSON 格式"、"必须使用算法 X"），则路径边界应反映此狭窄约束。在这种情况下，上下界可能收敛到同一点，"允许的选择"应明确说明选择已按草案规范固定。

## 可行性提示和建议

> **注意**：此部分仅供参考和理解。这些是概念性建议，而非规范性要求。

### 概念方法
<Text description, pseudocode, or diagrams showing ONE possible implementation path>

### 相关参考
<Code paths and concepts that might be useful>
- <path/to/relevant/component> - <brief description>

## 依赖和顺序

### 里程碑
1. <Milestone 1>: <Description>
   - Phase A: <...>
   - Phase B: <...>
2. <Milestone 2>: <Description>
   - Step 1: <...>
   - Step 2: <...>

<描述组件之间的相对依赖关系，而非时间估计>

## 任务分解

每个任务必须包含恰好一个路由标签：
- `coding`：由 Claude 实施
- `analyze`：通过 Codex 执行（`/humanize:ask-codex`）

| Task ID | Description | Target AC | Tag (`coding`/`analyze`) | Depends On |
|---------|-------------|-----------|----------------------------|------------|
| task1 | <...> | AC-1 | coding | - |
| task2 | <...> | AC-2 | analyze | task1 |

## Claude-Codex 协商

### 共识
- <Point both sides agree on>

### 已解决的分歧
- <Topic>: Claude vs Codex summary, chosen resolution, and rationale

### 收敛状态
- 最终状态: `converged` 或 `partially_converged`

## 待用户决策

- DEC-1: <Decision topic>
  - Claude 立场: <...>
  - Codex 立场: <...>
  - 权衡摘要: <...>
  - 决策状态: `PENDING` 或 `<User's final decision>`

## 实施说明

### 代码风格要求
- 实施代码和注释不得包含计划特定术语，如 "AC-"、"Milestone"、"Step"、"Phase" 或类似的工作流标记
- 这些术语仅用于计划文档，不用于生成的代码库
- 在代码中使用描述性的、领域适当的命名

## 输出文件约定

此模板用于生成主输出文件（例如 `plan.md`）。

### 翻译语言变体

当 `alternative_plan_language` 通过合并配置加载解析为支持的语言名称时，主文件之后还会写入输出文件的翻译变体。Humanize 按以下顺序从合并层加载配置：默认配置、可选用户配置，然后是可选项目配置；`alternative_plan_language` 可以在任何层设置。变体文件名通过在文件扩展名之前插入 `_<code>`（来自内置映射表的 ISO 639-1 代码）来构建：

- `plan.md` 变为 `plan_<code>.md`（例如中文为 `plan_zh.md`，韩文为 `plan_ko.md`）
- `docs/my-plan.md` 变为 `docs/my-plan_<code>.md`
- `output`（无扩展名）变为 `output_<code>`

翻译变体文件包含主计划文件当前内容的完整翻译，使用配置的语言。所有标识符（`AC-*`、任务 ID、文件路径、API 名称、命令标志）保持不变，因为它们是语言中性的。

当 `alternative_plan_language` 为空、不存在、设置为 `"English"` 或设置为不支持的语言时，不会写入翻译变体。当不存在项目配置文件时，Humanize 不会自动创建 `.humanize/config.json`。
