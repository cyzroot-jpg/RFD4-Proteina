---
description: "优化带注释的实施计划并生成 QA 台账"
argument-hint: "--input <path/to/annotated-plan.md> [--output <path/to/refined-plan.md>] [--qa-dir <path/to/qa-dir>] [--alt-language <language-or-code>] [--discussion|--direct]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-refine-plan-io.sh:*)"
  - "Read"
  - "Glob"
  - "Grep"
  - "Write"
  - "Edit"
  - "AskUserQuestion"
hide-from-slash-command-tool: "true"
---

# 优化带注释的计划

请仔细阅读并执行以下内容。

## 硬性约束：仅限计划优化

本命令只能优化计划产物。不得实施仓库代码、修改与计划输出无关的源文件、自动启动 RLCR 或创建新的计划模式。

允许的写入仅限于：
- 优化后的计划输出文件（`--output`，或就地模式下的 `--input`）
- `--qa-dir` 下的 QA 文档
- 优化计划和 QA 文档的可选翻译语言变体

优化后的计划必须复用现有的 `gen-plan` 模式。不要发明新的顶级部分。保持必需部分完整，保留存在的可选部分，并保留任何 `--- Original Design Draft Start ---` 附录或其他非注释内容，除非注释明确要求在此处进行计划级更改。

## 工作流程概览

> **顺序执行约束**：严格按顺序执行阶段。不得跨阶段并行化工作。在进入下一个之前完成每个阶段。

1. **执行模式设置**：解析 CLI 参数并派生输出路径
2. **加载项目配置**：使用 `config-loader.sh` 语义解析 `alternative_plan_language` 和模式默认值
3. **IO 验证**：运行 `validate-refine-plan-io.sh`
4. **注释提取**：扫描带注释的计划并提取有效注释块（`CMT:`/`ENDCMT`、`<cmt>`/`</cmt>`、`<comment>`/`</comment>`）
5. **注释分类**：对每个提取的注释进行分类以供下游处理
6. **注释处理**：回答问题、应用请求的计划编辑并执行定向研究
7. **计划优化**：生成无注释的优化计划，同时保留 `gen-plan` 结构
8. **QA 生成**：用注释台账和结果填充 QA 模板
9. **原子写入**：将优化计划、QA 文档和可选变体作为一个事务提交

---

## 阶段 0：执行模式设置

解析 `$ARGUMENTS` 并设置以下变量：

- 从 `--input` 获取 `INPUT_FILE`（必填）
- 从 `--output` 获取 `OUTPUT_FILE`
- 从 `--qa-dir` 获取 `QA_DIR`
- 从 `--alt-language` 获取 `CLI_ALT_LANGUAGE_RAW`
- 如果存在 `--discussion`，则 `REFINE_PLAN_MODE_DISCUSSION=true`
- 如果存在 `--direct`，则 `REFINE_PLAN_MODE_DIRECT=true`

参数规则：

1. `--input <path>` 是必需的。
2. `--output <path>` 是可选的。如果省略，设置 `OUTPUT_FILE=INPUT_FILE` 以就地模式。
3. `--qa-dir <path>` 是可选的。如果省略，设置 `QA_DIR=.humanize/plan_qa`。
4. `--alt-language <language-or-code>` 是可选的。如果存在但没有值，报告 `Invalid arguments: --alt-language requires a value` 并停止。
5. `--discussion` 和 `--direct` 互斥。如果同时存在，报告 `Cannot use --discussion and --direct together` 并停止。

派生路径：

1. 当 `OUTPUT_FILE` 等于 `INPUT_FILE` 时计算 `IN_PLACE_MODE=true`；否则 `false`。
2. 从输入基本名称（而非输出基本名称）计算 `QA_FILE`：
   - `plan.md` 变为 `<QA_DIR>/plan-qa.md`
   - `docs/my-plan.md` 变为 `<QA_DIR>/my-plan-qa.md`
   - `plan` 变为 `<QA_DIR>/plan-qa.md`
3. 将 `--alt-language` 排除在验证器调用之外，因为 `validate-refine-plan-io.sh` 不接受它。仅传递：
   - `--input`
   - 提供时的 `--output`
   - 提供时的 `--qa-dir`
   - 提供时的 `--discussion` 或 `--direct`

v1 的范围规则：

- 不引入 `--language` 或 `--qa-output`
- 不添加新的配置键
- 优化后不自动启动 RLCR

---

## 阶段 0.5：加载项目配置

遵循 `${CLAUDE_PLUGIN_ROOT}/scripts/lib/config-loader.sh` 中定义的相同优先级和合并语义解析配置。复用该行为；不要发明单独的 refine-plan 配置模型。

### 配置合并语义

使用与 `load_merged_config` 相同的层顺序：

1. 必需默认配置：`${CLAUDE_PLUGIN_ROOT}/config/default_config.json`
2. 可选用户配置：`${XDG_CONFIG_HOME:-$HOME/.config}/humanize/config.json`
3. 可选项目配置：`${HUMANIZE_CONFIG:-$PROJECT_ROOT/.humanize/config.json}`

后续层覆盖前面的层。格式错误的可选 JSON 对象视为警告并被忽略。格式错误的必需默认配置是致命配置错误。

### 需要提取的值

读取合并配置并解析：

- 从 `alternative_plan_language` 获取 `CONFIG_ALT_LANGUAGE_RAW`
- 从 `gen_plan_mode` 获取 `CONFIG_GEN_PLAN_MODE_RAW`

### 模式解析

使用以下优先级解析 `REFINE_PLAN_MODE`：

1. CLI `--discussion` => `discussion`
2. CLI `--direct` => `direct`
3. 有效的配置值 `gen_plan_mode`（`discussion` 或 `direct`，不区分大小写）
4. 默认 => `discussion`

如果 `gen_plan_mode` 存在但无效，记录警告并回退到下一条规则。

### 替代语言解析

使用以下优先级解析变体语言：

1. CLI `--alt-language`
2. 配置 `alternative_plan_language`
3. 无变体

使用此映射表不区分大小写地规范化值：

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

规范化规则：

1. 匹配前修剪前导和尾随空格。
2. 接受表中的完整语言名称或 ISO 代码。
3. 将 `English` / `en` 视为无操作：不生成翻译变体。
4. 如果 CLI 值不受支持，报告 `Unsupported --alt-language "<value>"` 并停止。
5. 如果配置值不受支持，记录警告并禁用变体生成。

设置：

- `ALT_PLAN_LANGUAGE` 为规范化的语言名称或空字符串
- `ALT_PLAN_LANG_CODE` 为规范化的代码或空字符串

不要依赖已弃用的 `chinese_plan`。`refine-plan` 仅使用 `alternative_plan_language`。

---

## 阶段 1：IO 验证

使用解析的参数（不包括 `--alt-language`）运行验证器：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-refine-plan-io.sh" <validated-arguments>
```

准确处理退出码：

- 退出码 0：继续阶段 2
- 退出码 1：报告 `Input file not found` 并停止
- 退出码 2：报告 `Input file is empty` 并停止
- 退出码 3：报告 `Input file has no comment blocks` 并停止
- 退出码 4：报告 `Input file is missing required gen-plan sections` 并停止
- 退出码 5：报告 `Output directory does not exist or is not writable - please fix it` 并停止
- 退出码 6：报告 `QA directory is not writable` 并停止
- 退出码 7：报告 `Invalid arguments` 并显示验证器用法，然后停止

验证说明：

1. `validate-refine-plan-io.sh` 可能会在 `QA_DIR` 不存在时创建它。将其视为预期设置，而非需要撤消的副作用。
2. 验证成功后，读取输入文件并将其确切内容保存为 `ORIGINAL_PLAN_TEXT`。
3. 暂时不要修改已验证的输入。所有写入仅在阶段 7 进行。

---

## 阶段 2：注释提取

使用等效于 POSIX `awk` 由 `bash` 包装的**有状态扫描器**提取注释，而非朴素的正则表达式扫描。扫描器行为必须与 Task 3 的发现匹配。

### 扫描器要求

在按文档顺序扫描已验证输入时跟踪以下状态：

- `IN_FENCE`，带有活动围栏标记（` ``` ` 或 ` ~~~ `）
- `IN_HTML_COMMENT`，用于 `<!-- ... -->`
- `IN_CMT_BLOCK`
- `NEAREST_HEADING`

提取规则：

1. 支持三种注释格式：
   - 经典：`CMT:` 作为开始标记，`ENDCMT` 作为结束标记
   - 短标签：`<cmt>` 作为开始标记，`</cmt>` 作为结束标记
   - 长标签：`<comment>` 作为开始标记，`</comment>` 作为结束标记
2. 所有格式支持内联和多行块：
   - 内联：`Text before CMT: comment text ENDCMT text after`
   - 内联：`Text before <cmt>comment text</cmt> text after`
   - 内联：`Text before <comment>comment text</comment> text after`
   - 多行：
     ```markdown
     CMT:
     comment text
     ENDCMT
     ```
     ```markdown
     <cmt>
     comment text
     </cmt>
     ```
     ```markdown
     <comment>
     comment text
     </comment>
     ```
3. 忽略围栏代码块内的注释标记。
4. 忽略 HTML 注释内的注释标记。
5. 在围栏代码和 HTML 注释之外遇到 Markdown 标题时更新 `NEAREST_HEADING`。
6. 从工作计划文本中移除内联注释块时保留周围的非注释文本。
7. 按文档顺序为非空块分配原始注释 ID，格式为 `CMT-1`、`CMT-2`、...
8. 如果块在修剪空白后为空，从工作计划文本中移除它但不创建台账项也不消耗 ID。

### 提取的元数据

对于每个非空注释块，捕获：

- `id`（`CMT-N`）
- `original_text`，注释标记之间的确切书写内容
- `normalized_text`，修剪周围空白
- `start_line`、`start_column`
- `end_line`、`end_column`
- `nearest_heading` 或尚无标题时的 `Preamble`
- QA 输出的 `location_label`
- `form` = `inline` 或 `multiline`
- 最近非注释源文本的 `context_excerpt`

### 解析错误

这些是致命提取错误：

1. 已在注释块内时遇到嵌套注释开始标记
2. 未在注释块内时遇到注释结束标记，或格式的结束标记不匹配
3. 仍在注释块内时到达文件末尾

每个致命解析错误必须报告：

- 错误类型
- 确切的行和列
- 最近的标题
- 简短的上下文摘录

可接受消息的示例：

- `Comment parse error: nested comment block at line 48, column 3 near "## Acceptance Criteria" (context: "<cmt>split AC-2...")`
- `Comment parse error: stray comment end marker at line 109, column 1 near "## Task Breakdown" (context: "</comment>")`
- `Comment parse error: missing end marker for block opened at line 72, column 5 near "## Dependencies and Sequence"`

### 阶段 2 的输出

生成：

- `EXTRACTED_COMMENTS`：注释记录的有序列表
- `PLAN_WITH_COMMENTS_REMOVED`：移除每个有效注释块并保留周围内联文本的原始计划文本

如果 `EXTRACTED_COMMENTS` 在移除无操作块后为空，报告 `No non-empty CMT blocks remain after parsing` 并停止。

---

## 阶段 3：注释分类

对每个提取的注释进行分类以供下游处理。

### 主要分类集

每个原始注释块必须恰好获得一个主要分类：

- `question`
- `change_request`
- `research_request`

### 启发式规则

首先使用这些启发式：

- `question`：询问为什么、如何、什么、解释、澄清，或说计划不清楚
- `change_request`：要求添加、移除、删除、重写、恢复、重命名、拆分、合并或以其他方式修改计划
- `research_request`：要求调查仓库、比较现有模式、确认当前行为，或在决定前收集证据

当同一原始块中出现多个意图时：

1. 保持原始台账 ID 不变（`CMT-N`）
2. 按文本顺序创建确定性处理子项：`CMT-N.1`、`CMT-N.2`、...
3. 为每个子项分配上述三种分类之一
4. 使用以下优先级为原始块分配 QA 台账的主导分类：
   - `research_request`
   - `change_request`
   - `question`

### 歧义处理

如果应用启发式后分类仍有歧义：

- 在 `discussion` 模式下：使用 `AskUserQuestion` 在继续之前确认分类
- 在 `direct` 模式下：选择最能驱动行动的解释并在 QA 文档中记录假设

示例：

- `Why do we need two config layers here?` => `question`
- `Delete task5 and fold its work into task4.` => `change_request`
- `Investigate how config loading works in this repo before deciding whether AC-3 should change.` => `research_request`，或如果块明显包含两种意图，则拆分为研究加后续更改子项

### 分类记录

对于每个原始注释块和任何子项，记录：

- `id`
- 适用时的 `parent_id`
- `classification`
- `classification_rationale`
- `needs_user_confirmation`（`true` 或 `false`）
- `resolved_via_discussion`（`true` 或 `false`）

---

## 阶段 4：注释处理

按文档顺序处理注释。当原始块有子项时，在移动到下一个原始块之前按顺序处理子项。

### `question`

默认行为：

1. 在 QA 文档中回答问题。
2. 仅在当前计划文本确实含糊或误导时应用最小的澄清性计划编辑。
3. 不要以问题为借口扩展范围、添加实施细节或重写不相关的部分。

轻度澄清的首选目标：

- `## Goal Description`
- `## Feasibility Hints and Suggestions`
- `## Dependencies and Sequence`
- `## Implementation Notes`

### `change_request`

默认行为：

1. 将请求的计划编辑直接应用到优化计划草稿。
2. 保持 `gen-plan` 结构完整。
3. 在所有受影响的部分传播更改，使计划保持内部一致。

一致性义务：

- 验收标准仍匹配引用的任务
- Task Breakdown 仍指向现有的 AC
- 任务依赖仍引用现有的任务 ID 或 `-`
- 里程碑和排序仍与更改后的范围对齐
- `Claude-Codex Deliberation` 和 `Pending User Decisions` 反映新状态
- 任务路由标签仍为 `coding` 或 `analyze`

### `research_request`

默认行为：

1. 仅使用 `Read`、`Glob` 和 `Grep` 执行定向仓库研究。
2. 将研究严格限定在注释范围内。不要偏向实施工作。
3. 在 QA 文档中总结检查的文件和模式。
4. 如果证据支持明确的计划更新，将结论整合到优化计划中。
5. 如果研究缩小了问题但仍需要人工选择，在 `## Pending User Decisions` 中添加或更新 `DEC-N` 项，并在 QA 文档中记录相同的决策。

### 解决规则

1. 每个原始 `CMT-N` 必须以一种处置结束：
   - `answered`
   - `applied`
   - `researched`
   - `deferred`
   - `resolved`
2. 在 QA 文档中保留阶段 2 中捕获的原始注释文本。
3. 如果注释无法在没有用户输入的情况下完全解决：
   - 在 `discussion` 模式下，仅询问最少必要的问题
   - 在 `direct` 模式下，做出最小的安全假设，在 QA 中明确标记，并在假设实质性影响计划时添加待处理决策
4. 如果处理后仍有未解决的用户决策，计划收敛状态必须为 `partially_converged`
5. 如果所有注释都已完全解决且没有待处理决策，保留或设置收敛状态为 `converged`

---

## 阶段 5：生成优化计划

从 `PLAN_WITH_COMMENTS_REMOVED` 开始，应用阶段 4 中接受的优化并生成 `REFINED_PLAN_TEXT`。

### 结构保留规则

优化计划必须保留这些必需部分：

- `## Goal Description`
- `## Acceptance Criteria`
- `## Path Boundaries`
- `## Feasibility Hints and Suggestions`
- `## Dependencies and Sequence`
- `## Task Breakdown`
- `## Claude-Codex Deliberation`
- `## Pending User Decisions`
- `## Implementation Notes`

存在于输入中时必须保留的可选部分：

- `## Codex Team Workflow`
- `## Convergence Log`
- `--- Original Design Draft Start ---` 附录及其匹配的结束标记

### 优化规则

1. 从优化计划中移除每个已解决的注释标记和所有包含的注释文本。
2. 不添加任何新的顶级模式部分。
3. 保留 `AC-X` / `AC-X.Y` 格式。
4. 除非注释明确请求结构更改，否则保留任务 ID。
5. 如果任务 ID 或 AC ID 更改，在整个计划中一致地更新所有引用。
6. 保持任务路由标签限制为 `coding` 或 `analyze`。
7. 保持优化计划与输入计划相同的主语言。仅在输入含糊且 discussion 模式用户输入明确请求规范化时规范化混合语言内容。

### 主语言检测

在注释移除后确定输入计划的主语言。

规则：

1. 使用标题和正文的主导语言作为默认主语言。
2. 如果计划明显是混合语言且主导语言含糊：
   - 在 `discussion` 模式下，询问用户是保持当前混合还是规范化为主导语言
   - 在 `direct` 模式下，保持从标题和正文推断的主导语言；如果仍有平局，默认为英语
3. QA 文档必须使用与优化计划相同的主语言。
4. 如果 `ALT_PLAN_LANGUAGE` 解析为与主语言相同的语言，跳过变体生成。

### 阶段 6 之前的必需验证

在生成 QA 文档之前，验证：

1. 所有必需部分仍然存在
2. 没有注释标记残留
3. 每个引用的 `AC-*` 都存在
4. 每个任务依赖引用现有的任务 ID 或 `-`
5. 每个任务行恰好有一个有效的路由标签：`coding` 或 `analyze`
6. `## Pending User Decisions` 和 `### Convergence Status` 与实际未解决状态一致

如果验证问题可以通过调和计划来修复，在继续之前修复它。如果无法在不发明需求的情况下修复，停止并报告阻塞的不一致性。

---

## 阶段 6：生成 QA 文档

读取 `${CLAUDE_PLUGIN_ROOT}/prompt-template/plan/refine-plan-qa-template.md` 并完全填充它。QA 文档不是可选的。

### QA 内容要求

填充所有模板部分：

1. `## Summary`
2. `## Comment Ledger`
3. `## Answers`
4. `## Research Findings`
5. `## Plan Changes Applied`
6. `## Remaining Decisions`
7. `## Refinement Metadata`

### 台账规则

`Comment Ledger` 必须按文档顺序为阶段 2 中提取的每个原始 `CMT-N` 包含恰好一行。

每行必须包含：

- `CMT-ID`
- 主导分类
- 位置
- 原始文本摘录
- 最终处置

如果原始块被拆分为处理子项，为原始 ID 保留一行台账，并在详细部分中描述子项处理。

### 部分特定规则

- `Answers`：包含所有 `question` 项和对计划所做的任何澄清编辑
- `Research Findings`：包含所有 `research_request` 项、检查的文件或模式，以及对计划的影响
- `Plan Changes Applied`：包含所有 `change_request` 项和交叉引用更新
- `Remaining Decisions`：包含每个仍需要用户选择的未解决或假设较多的项目

语言规则：

1. 用与 `REFINED_PLAN_TEXT` 相同的主语言编写主 QA 文档
2. 保持标识符不变：`AC-*`、任务 ID、文件路径、API 名称、命令标志、配置键
3. 在围栏代码块内逐字保留原始注释文本

元数据规则：

1. 记录解析的输入路径、输出路径、QA 路径、日期和按分类的计数
2. 记录最终收敛状态为 `converged` 或 `partially_converged`
3. 记录优化期间修改的计划部分集

---

## 阶段 7：原子写入事务

在所有内容完全准备好之前不要写入任何最终输出。

### 范围内的文件

始终准备：

- `OUTPUT_FILE` 处的主优化计划
- `QA_FILE` 处的主 QA 文档

条件性准备：

- `OUTPUT_FILE` 处的计划变体，在扩展名前插入 `_<ALT_PLAN_LANG_CODE>`
- `QA_FILE` 处的 QA 变体，在扩展名前插入 `_<ALT_PLAN_LANG_CODE>`

变体的文件名构建规则：

1. 如果文件名有扩展名，在最后一个 `.` 之前插入 `_<code>`
2. 如果文件名没有扩展名，追加 `_<code>`

示例：

- `plan.md` -> `plan_zh.md`
- `feature-a-qa.md` -> `feature-a-qa_zh.md`
- `output` -> `output_zh`

### 变体内容规则

如果 `ALT_PLAN_LANGUAGE` 非空且与主语言不同：

1. 将主优化计划翻译为 `ALT_PLAN_LANGUAGE`
2. 将主 QA 文档翻译为 `ALT_PLAN_LANGUAGE`
3. 保持标识符不变
4. 中文默认使用简体中文

如果 `ALT_PLAN_LANGUAGE` 为空或等于主语言，不创建变体文件。

### 事务规则

1. 首先在内存中准备所有最终内容：
   - `REFINED_PLAN_TEXT`
   - `QA_TEXT`
   - 可选 `REFINED_PLAN_VARIANT_TEXT`
   - 可选 `QA_VARIANT_TEXT`
2. 将每个输出写入与其最终目标相同目录中的临时文件。
3. 使用等效的临时命名模式：
   - `.refine-plan-XXXXXX`
   - `.refine-qa-XXXXXX`
   - `.refine-plan-variant-XXXXXX`
   - `.refine-qa-variant-XXXXXX`
4. 如果任何临时写入或翻译步骤失败：
   - 删除所有临时文件
   - 保持现有最终输出不变
   - 报告失败
5. 仅在每个临时文件成功写入后才能替换最终输出。
6. 在替换主就地计划文件之前替换辅助输出，以便主计划最后更新。
7. 如果在替换任何目标后最终化失败，如果环境允许则从备份恢复；否则明确报告部分最终化风险。

成功条件：

- 主优化计划写入成功
- 主 QA 文档写入成功
- 每个请求的变体写入成功
- 没有残留的临时文件

### 最终报告

报告：

- 优化计划的路径
- QA 文档的路径
- 任何生成的变体的路径
- 处理的原始注释数量
- 按分类的计数
- 是否仍有待处理决策
- 最终收敛状态
- 优化是在 `discussion` 还是 `direct` 模式下运行

---

## 错误处理

如果发生阻塞问题：

- 报告失败的确切阶段
- 包含具体原因
- 包含解析错误的任何相关行/列/上下文细节
- 不要留下部分优化的计划产物

如果在 `discussion` 模式下需要用户决策：

- 仅询问继续所需的最窄问题
- 在 QA 文档中记录决策，当仍未解决时记录在 `## Pending User Decisions`

如果在 `direct` 模式下决策被延迟：

- 做出最小的安全假设
- 在 QA 文档中明确记录假设
- 当延迟项实质性影响实施方向时将计划标记为 `partially_converged`
