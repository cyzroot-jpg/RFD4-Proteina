---
description: "通过定向群集探索生成基于仓库的想法草稿"
argument-hint: "<idea-text-or-path> [--n <int>] [--output <path>]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-idea-io.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-directions-json.sh:*)"
  - "Bash(rm:*)"
  - "Read"
  - "Glob"
  - "Grep"
  - "Task"
  - "Write"
---

# 从松散输入生成想法草稿

请仔细阅读并执行以下内容。

## 硬性约束：仅草稿输出

本命令在生成草稿期间不得实现功能、修改源代码或创建提交。允许的写入仅限于输出草稿文件和阶段 4 生成的配套 `directions.json` 产物；允许验证脚本为默认 `.humanize/ideas/` 路径创建前置目录。`rm` 仅在配套 JSON 验证失败时用于删除这两个刚写入的文件（无部分输出清理）。所有探索子代理以只读方式运行。

本命令将松散的想法转换为适合作为 `/humanize:gen-plan` 输入的基于仓库的草稿。它应用定向多样性探索：一个主导者选择 N 个正交方向，N 个并行 `Explore` 子代理分别开发每个方向，主导者合成一个包含一个主要方向和 N-1 个替代方向的草稿。每个方向都携带来自仓库的客观证据。

## 工作流程概览

> **顺序执行约束**：所有阶段必须严格按顺序执行。每个阶段必须完全完成后才能进入下一个。

1. 解析输入
2. IO 验证
3. 方向生成
4. 并行探索
5. 合成、写入草稿并写入配套 JSON

---

## 阶段 0：解析输入

从 `$ARGUMENTS` 提取：
- 第一个位置参数：内联想法文本或 `.md` 文件路径（必填）。
- `--n <int>`：方向数量。默认为 6。
- `--output <path>`：目标草稿路径。默认由验证脚本解析。

不要在此处解释或重写想法文本。将 `$ARGUMENTS` 原封不动地传递到阶段 1。

---

## 阶段 1：IO 验证

运行：
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-idea-io.sh" $ARGUMENTS
```

处理退出码：
- `0`：解析标准输出以提取 `INPUT_MODE`、`OUTPUT_FILE`、`DIRECTIONS_JSON_FILE`、`SLUG`、`TEMPLATE_FILE`、`N`（每个出现在自己的 `KEY: value` 行上）。当 `INPUT_MODE` 为 `file` 时，标准输出还包含 `IDEA_BODY_FILE: <path>` 行；也需要提取。继续阶段 2。（`SLUG` 是信息性的 — 脚本已将其纳入 `OUTPUT_FILE`，因此后续阶段不需要直接使用 `SLUG`。）
- `1`：报告"缺少或空的想法输入"并停止。
- `2`：报告"输入看起来像文件路径但缺失、不可读或不是 `.md`"并停止。
- `3`：报告"输出目录不存在 — 请创建它或选择不同的路径"并停止。
- `4`：报告"输出文件已存在 — 请选择不同的路径"并停止。
- `5`：报告"没有输出目录的写入权限"并停止。
- `6`：报告"参数无效 — 输出路径必须具有 `.md` 后缀"并附带标准输出使用文本，然后停止。
- `7`：报告"模板文件缺失 — 插件配置错误"并停止。
- `8`：报告"配套的 directions.json 已存在 — 请选择不同的输出路径或删除现有的配套文件"并停止。

在 `VALIDATION_SUCCESS` 之前，标准输出可能包含一个或多个以 `WARNING:` 开头的行（例如，当内联想法少于 10 个字符时出现 `WARNING: short idea (<N> chars); proceeding`）。在最终报告中向用户显示这些警告，但正常继续阶段 2。`WARNING:` 行是信息性的，不是错误。

根据 `INPUT_MODE` 将想法主体获取到内存中作为 `IDEA_BODY`：
- `inline`：标准输出在成功输出的末尾包含一个哨兵块；提取 `=== IDEA_BODY_BEGIN ===` 和 `=== IDEA_BODY_END ===` 行之间的所有文本（不包括标记行）。脚本在最后一行主体之后发出尾随换行符。
- `file`：使用 `Read` 工具读取 `IDEA_BODY_FILE` 的完整内容。

在内存中保留逐字节相同的内容供后续阶段使用。内联模式下不会在磁盘上创建临时文件 — 标准输出哨兵块是权威来源。

---

## 阶段 2：方向生成

生成恰好 `N` 个正交方向用于探索想法。

### 需要收集的上下文

在生成方向之前，读取（路径相对于项目根目录，即 `$(git rev-parse --show-toplevel)`）：
- 项目根目录的 `README.md`。
- 项目根目录的 `CLAUDE.md`（如果存在）。
- `.claude/CLAUDE.md`（如果存在）。
- 通过 `Glob` 使用模式 `*` 获取顶级目录列表（一级，无递归）。

此上下文将方向定位在实际仓库中，而非通用头脑风暴。

### 生成规则

生成恰好 `N` 个方向条目。每个条目包含：
- `name`：2-5 个词的简短标签。
- `rationale`：一句话解释为什么此角度与其他方向不同。

硬性约束：**正交性**。两个近乎重复的方向违背了定向多样性的前提。在返回之前：
- 如果两个方向感觉像重复的，将其中一个替换为真正不同的角度。
- 如果一个方向退化为"只是把 X 做得更好"而没有角度区分，则替换它。
- 不要发出仅仅用不同措辞重述想法的方向。

### 重试和降级

- 如果第一轮返回少于 `N` 个条目，使用明确的"你必须生成 `N` 个正交方向"指令重新生成一次。
- 如果第二轮仍然返回少于 `N` 个但至少 2 个，则以减少的数量继续并向用户发出警告：`Warning: direction generation returned <count> of <N> requested directions; proceeding with reduced count.`
- 如果产生的方向少于 2 个，则以错误停止：`direction generation degraded; retry.`

将最终方向列表存储为 `DIRECTIONS`（有序；索引 0..len-1）。

---

## 阶段 3：并行探索

在**单个 Task 工具消息**中调度所有方向，每个方向包含一个 Task 调用。这是 W2S 并行群集步骤。

### 子代理调用

对于 `DIRECTIONS` 中的每个方向，启动一个 `Explore` 子代理。每个调用提示必须包含：

1. 阶段 1 中捕获的想法主体（`IDEA_BODY`）的逐字副本。
2. 分配的方向（名称 + 理由）。
3. 以下指令块（在子代理提示中逐字复制）：

> 在当前仓库中探索此方向。收集客观证据：
> - 值得扩展的现有模式的具体仓库路径。
> - 代码库或相邻工具中的现有技术或先例。
> - 可从代码阅读中发现的可衡量考虑因素（大致复杂度、LOC 范围、性能影响）。
>
> 只读。不要写入任何文件。
>
> 如果此方向不存在具体证据，请在 OBJECTIVE_EVIDENCE 中报告一次字面字符串 `exploratory, no concrete precedent` 并停止进一步探索。禁止编造引用。
>
> 返回一个结构化提案，包含以下字段：
> - `APPROACH_SUMMARY`：具体的设计描述（要构建什么、核心机制、受影响的组件）。
> - `OBJECTIVE_EVIDENCE`：仓库路径、现有技术或 `exploratory, no concrete precedent` 哨兵的项目符号列表。
> - `KNOWN_RISKS`：简短的项目符号列表。
> - `CONFIDENCE`：`high`、`medium`、`low` 之一。

### 收集和降级

收集所有子代理响应。对于每个响应：
- 解析四个必需字段。如果缺少字段，将该提案标记为降级并丢弃。
- 如果存活的提案少于 2 个，则以错误停止：`exploration phase degraded; retry.`
- 否则继续使用存活的提案。

将每个存活的提案与其原始方向关联（以便阶段 4 可以用原始方向名称标记它）。在阶段 4 中对丢弃后的替代方案进行编号时，将存活者按顺序重新编号为 Alt-1..Alt-K（其中 K 是存活的非主要方向的数量）。不要保留已丢弃提案的间隔。

---

## 阶段 4：合成和写入

### 步骤 4.1：选择主要方向

审查所有存活的提案。根据以下标准选择最强的作为主要方向：
1. 证据密度 — 更多具体的仓库引用优先于较少的。
2. 与现有仓库模式的契合度 — 扩展模式优先于引入不熟悉的范式。
3. 实施范围 — 在质量相当的情况下，优先选择较小的范围。
4. 声明的 `CONFIDENCE` — `high` > `medium` > `low` 作为决胜因素。

将选定的方向记录为 `PRIMARY`；其余存活的方向成为 Alt-1..Alt-K 列表（其中 K 是非主要存活者的数量，K ≤ N-1），按其原始方向顺序编号，不为已丢弃的提案保留间隔。

### 步骤 4.2：推断标题

生成一个 4-10 个词的标题大写标题，捕捉主要方向，而非逐字使用原始输入措辞。例如：想法 `add undo/redo` 配合主要方向 `command-pattern history` 生成标题 `Command-Pattern Undo Stack For The Editor`。

### 步骤 4.3：填充模板

读取位于 `TEMPLATE_FILE` 的模板文件（来自阶段 1 标准输出）。

通过替换占位符在内存中生成最终草稿内容：
- `<TITLE>` — 推断的标题。
- `<ORIGINAL_IDEA>` — 阶段 1 中捕获的 `IDEA_BODY` 的逐字节相同值。保留换行符、尾随换行符和所有格式。不要转述或重新缩进。
- `<PRIMARY_NAME>` — 主要方向的简短名称。
- `<PRIMARY_RATIONALE>` — 主要方向的理由（来自阶段 2）。
- `<PRIMARY_APPROACH_SUMMARY>` — 主要提案的 `APPROACH_SUMMARY`。
- `<PRIMARY_OBJECTIVE_EVIDENCE>` — 主要提案的 `OBJECTIVE_EVIDENCE`，渲染为项目符号列表。如果子代理仅返回字面哨兵 `exploratory, no concrete precedent`，则将其渲染为单个项目符号：`- exploratory, no concrete precedent`。
- `<PRIMARY_KNOWN_RISKS>` — 主要提案的 `KNOWN_RISKS`，渲染为项目符号列表。
- `<ALTERNATIVES>` — 对于每个非主要存活者在其 Alt 索引 `i`（从 1 开始，按步骤 4.1 顺序），发出：

  ```markdown
  ### Alt-<i>: <name>
  - 摘要：<从 APPROACH_SUMMARY 派生的一段摘要>
  - 客观证据：
    - <来自 OBJECTIVE_EVIDENCE 的项目符号>
    - ...
  - 未选为主要的原因：<一句话说明与 PRIMARY 的权衡>
  ```

  用一个空行分隔连续的 Alt 条目。

- `<SYNTHESIS_NOTES>` — 一段描述替代方案中的哪些元素可以在用户选择不同方向时融入主要方向的文字。这是主导者自己的合成笔记，不是子代理输出。

### 步骤 4.4：写入草稿文件

使用 `Write` 工具将最终内容写入 `OUTPUT_FILE`。单次写入；无渐进编辑。

### 步骤 4.5：构建并写入配套 JSON

使用阶段 3 中所有存活的方向提案在内存中构建配套 `directions.json`，然后将其写入 `DIRECTIONS_JSON_FILE`（来自阶段 1 标准输出）。

**JSON 结构（模式版本 1）：**

```json
{
  "schema_version": 1,
  "title": "<TITLE from Step 4.2>",
  "original_idea": "<IDEA_BODY verbatim>",
  "synthesis_notes": "<SYNTHESIS_NOTES from Step 4.3>",
  "metadata": {
    "n_requested": <N>,
    "n_returned": <count of surviving directions>,
    "timestamp": "<YYYYMMDD-HHmmss>",
    "draft_path": "<OUTPUT_FILE>"
  },
  "directions": [
    {
      "direction_id": "dir-<NN>-<dir-slug>",
      "dir_slug": "<lowercase-alphanumeric-hyphen slug derived from direction name>",
      "source_index": <original 0-based index from DIRECTIONS list>,
      "display_order": <0 for primary, 1..K for alternatives in sequential order>,
      "is_primary": <true for PRIMARY, false otherwise>,
      "name": "<direction name>",
      "rationale": "<direction rationale from Phase 2>",
      "raw_phase3_response": "<exact raw subagent response text for this direction>",
      "approach_summary": "<APPROACH_SUMMARY from subagent>",
      "objective_evidence": ["<bullet item>", ...],
      "known_risks": ["<bullet item>", ...],
      "confidence": "<high|medium|low>"
    }
  ]
}
```

**字段派生规则：**
- `direction_id`：`"dir-" + 零填充的 source_index（2 位数字）+ "-" + dir_slug`。示例：`"dir-00-command-history"`。
- `dir_slug`：从方向名称派生 — 小写，将非字母数字字符替换为连字符，折叠连续连字符，去除前导/尾随连字符。必须匹配 `^[a-z0-9-]+$`。
- `dir_slug` 冲突处理：如果两个方向名称 slugify 为相同的值，按原始 `source_index` 顺序追加 `-2`、`-3` 等，直到每个 `dir_slug` 都唯一。
- `source_index`：此方向在阶段 2 原始 `DIRECTIONS` 列表中的从 0 开始的索引（在任何降级丢弃之前）。
- `display_order`：主要方向为 0，替代方案按顺序从 1 到 K。
- `is_primary`：恰好一个方向（PRIMARY）为 `true`，所有其他为 `false`。
- `objective_evidence`：子代理 `OBJECTIVE_EVIDENCE` 字段中的每个项目符号项作为字符串数组元素。
- `known_risks`：子代理 `KNOWN_RISKS` 字段中的每个项目符号项作为字符串数组元素。
- `metadata.n_returned` 必须等于 `directions.length`。

写入 `DIRECTIONS_JSON_FILE` 后，验证它：
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directions-json.sh" "$DIRECTIONS_JSON_FILE"
```

如果验证失败，删除 `OUTPUT_FILE` 和 `DIRECTIONS_JSON_FILE` 并以错误停止：`companion JSON validation failed — this is a bug in the command; please report it`。

### 步骤 4.6：报告

向用户报告：
- 写入的草稿路径：`OUTPUT_FILE`
- 写入的配套 JSON 路径：`DIRECTIONS_JSON_FILE`
- 主要方向名称。
- 请求的 `N` 和实际方向数量（如果因降级而减少则注明）。
- 下一步提示：
  ```
  要将方向作为并行原型探索，请运行：/humanize:explore-idea <DIRECTIONS_JSON_FILE>
  要将此草稿转换为计划，请运行：/humanize:gen-plan --input <OUTPUT_FILE> --output <plan-path>
  ```

---

## 错误处理

- 阶段 1 验证错误以明确消息停止命令。无部分输出。
- 阶段 2 降级遵循上述重试一次 + 最少 2 个规则。
- 阶段 3 降级遵循上述丢弃并继续 + 最少 2 个规则。
- 绝不编造仓库引用或现有技术。子代理的 `exploratory, no concrete precedent` 哨兵在草稿中逐字保留。
- 如果任何阶段因错误停止，不要写入部分的 `OUTPUT_FILE` 或 `DIRECTIONS_JSON_FILE`。
- 如果在写入两个文件后配套 JSON 验证失败，删除两个文件并停止。
