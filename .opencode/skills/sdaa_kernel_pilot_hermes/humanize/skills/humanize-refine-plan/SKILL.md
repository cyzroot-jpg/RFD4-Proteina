---
name: humanize-refine-plan
description: 将带注释的实施计划精炼为无注释计划和 QA 账本，同时保留 gen-plan 模式。
type: flow
user-invocable: false
---

# Humanize 精炼计划

将包含 `CMT:` / `ENDCMT` 块的带注释计划精炼为无注释计划加 QA 账本，同时保留 `gen-plan` 结构和收敛状态。

安装程序会使用绝对运行时根路径注入此技能：

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

```mermaid
flowchart TD
    BEGIN([开始]) --> SETUP[解析参数并推导路径<br/>解析模式、输出路径、QA 路径、备选语言]
    SETUP --> LOAD_CFG[加载合并配置<br/>复用 humanize 配置优先级和默认值]
    LOAD_CFG --> VALIDATE[验证 IO<br/>运行: {{HUMANIZE_RUNTIME_ROOT}}/scripts/validate-refine-plan-io.sh --input &lt;annotated-plan&gt; [--output ...] [--qa-dir ...] [--discussion|--direct]]
    VALIDATE --> VALID_OK{验证通过？}
    VALID_OK -->|否| REPORT_VALIDATION[报告验证错误<br/>停止]
    REPORT_VALIDATION --> END_FAIL([结束])
    VALID_OK --> EXTRACT[读取输入计划并使用有状态扫描器<br/>提取有效的 CMT:/ENDCMT 块]
    EXTRACT --> PARSE_OK{解析成功？}
    PARSE_OK -->|否| REPORT_PARSE[报告解析错误，包含<br/>行、列、标题、上下文<br/>停止]
    REPORT_PARSE --> END_FAIL
    PARSE_OK --> CLASSIFY[分类注释：<br/>question、change_request、research_request]
    CLASSIFY --> AMBIG{存在歧义注释？}
    AMBIG -->|是，讨论模式| ASK_USER[询问继续所需的<br/>最小用户问题]
    ASK_USER --> PROCESS
    AMBIG -->|否| PROCESS[按顺序处理注释：<br/>回答、精炼计划或进行有针对性的仓库研究]
    PROCESS --> REFINE[生成精炼计划文本<br/>保持必需的 gen-plan 节不变]
    REFINE --> PLAN_CHECK{计划仍然有效？<br/>无 CMT 标记、引用一致、<br/>路由标签有效}
    PLAN_CHECK -->|否，可修复| FIX[修复内部不一致]
    FIX --> PLAN_CHECK
    PLAN_CHECK -->|否，阻塞| REPORT_BLOCK[报告阻塞性不一致<br/>停止]
    REPORT_BLOCK --> END_FAIL
    PLAN_CHECK -->|是| QA[从 {{HUMANIZE_RUNTIME_ROOT}}/prompt-template/plan/refine-plan-qa-template.md<br/>填充 QA 文档]
    QA --> ALT_LANG{生成翻译变体？}
    ALT_LANG -->|是| VARIANTS[翻译精炼计划和 QA<br/>保持标识符不变]
    ALT_LANG -->|否| ATOMIC
    VARIANTS --> ATOMIC[通过临时文件原子写入<br/>精炼计划、QA 和变体]
    ATOMIC --> REPORT_SUCCESS[报告成功：<br/>路径、数量、模式、收敛状态]
    REPORT_SUCCESS --> END_SUCCESS([结束])
```

## 输入要求

**必需参数：**
- `--input <path/to/annotated-plan.md>` - 已遵循 `gen-plan` 模式且包含至少一个 `CMT:` / `ENDCMT` 块的输入计划

**可选参数：**
- `--output <path/to/refined-plan.md>` - 精炼计划的输出路径；默认为就地模式（`--input`）
- `--qa-dir <path/to/qa-dir>` - 生成的 QA 账本目录；默认为 `.humanize/plan_qa`
- `--alt-language <language-or-code>` - 计划和 QA 变体的可选翻译输出语言
- `--discussion` - 要求用户解决歧义分类或语言决策
- `--direct` - 使用最小安全假设解决歧义并记录在 QA 中

**参数规则：**
- `--discussion` 和 `--direct` 互斥
- 验证器不接受 `--alt-language`，因此不要将该标志传递给 `validate-refine-plan-io.sh`
- 如果省略 `--output`，就地精炼计划但仍单独写入 QA 文档

## 工作流保证

精炼流程必须：

- 保留 `gen-plan` 模式，而不是发明新的顶级节
- 从最终计划中移除所有已解决的 `CMT:` / `ENDCMT` 块
- 保持必需节不变：
  - `## Goal Description`
  - `## Acceptance Criteria`
  - `## Path Boundaries`
  - `## Feasibility Hints and Suggestions`
  - `## Dependencies and Sequence`
  - `## Task Breakdown`
  - `## Claude-Codex Deliberation`
  - `## Pending User Decisions`
  - `## Implementation Notes`
- 存在时保留可选节，包括原始设计草稿附录
- 保持任务路由标签限于 `coding` 或 `analyze`
- 从附带的 QA 模板生成 QA 账本
- 原子写入精炼计划、QA 文件和任何语言变体

## 分类与输出

每个提取的原始注释块接收一个主导分类：

- `question`
- `change_request`
- `research_request`

流程产出：

- 一个移除了注释块并应用了批准改进的精炼计划
- 一个 QA 账本，记录：
  - 每个原始 `CMT-N` 一行
  - 分类和处置
  - 问题的回答
  - 研究发现
  - 已应用的计划变更
  - 剩余决策
  - 精炼元数据和收敛状态

## 支持的备选语言

`--alt-language` 支持以下标准化值：

| 语言 | 代码 | 变体后缀 |
|----------|------|----------------|
| Chinese | `zh` | `_zh` |
| Korean | `ko` | `_ko` |
| Japanese | `ja` | `_ja` |
| Spanish | `es` | `_es` |
| French | `fr` | `_fr` |
| German | `de` | `_de` |
| Portuguese | `pt` | `_pt` |
| Russian | `ru` | `_ru` |
| Arabic | `ar` | `_ar` |

规则：

- 接受语言名称或 ISO 代码
- 将 `English` / `en` 视为无操作
- 在翻译变体中保持标识符不变
- 如果备选语言与主计划语言匹配，跳过变体生成

## 验证退出代码

| 退出代码 | 含义 |
|-----------|---------|
| 0 | 成功 - 继续 |
| 1 | 输入文件未找到 |
| 2 | 输入文件为空 |
| 3 | 输入文件没有 `CMT:` 块 |
| 4 | 输入文件缺少必需的 `gen-plan` 节 |
| 5 | 输出目录不存在或不可写 |
| 6 | QA 目录不可写 |
| 7 | 参数无效 |

## 使用方法

```bash
# 启动流程
/flow:humanize-refine-plan

# 流程将询问：
# - 输入带注释计划路径
# - 可选输出精炼计划路径
# - 可选 QA 目录
# - 可选执行模式和备选语言
```

或仅使用技能（不自动执行）：

```bash
/skill:humanize-refine-plan
```
