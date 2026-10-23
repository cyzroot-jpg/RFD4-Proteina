---
name: humanize-gen-plan
description: 从草稿文档生成结构化的实施计划。验证输入、检查相关性、分析问题，并生成包含验收标准的完整 plan.md。
type: flow
user-invocable: false
disable-model-invocation: true
---

# Humanize 生成计划

将粗略的草稿文档转换为结构良好的实施计划，包含清晰的目标、验收标准（AC-X 格式）、路径边界和可行性建议。

安装程序会使用绝对运行时根路径注入此技能：

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

```mermaid
flowchart TD
    BEGIN([开始]) --> VALIDATE[验证输入/输出路径<br/>运行: {{HUMANIZE_RUNTIME_ROOT}}/scripts/validate-gen-plan-io.sh --input &lt;draft&gt; --output &lt;plan&gt;]
    VALIDATE --> CHECK{验证通过？}
    CHECK -->|否| REPORT_ERROR[报告验证错误<br/>停止]
    REPORT_ERROR --> END_FAIL([结束])
    CHECK -->|是| READ_DRAFT[读取输入草稿文件]
    READ_DRAFT --> CHECK_RELEVANCE{草稿是否与<br/>此仓库相关？}
    CHECK_RELEVANCE -->|否| REPORT_IRRELEVANT[报告：草稿与仓库无关<br/>停止]
    REPORT_IRRELEVANT --> END_FAIL
    CHECK_RELEVANCE -->|是| ANALYZE[分析草稿：<br/>- 清晰性<br/>- 一致性<br/>- 完整性<br/>- 功能性]
    ANALYZE --> HAS_ISSUES{发现问题？}
    HAS_ISSUES -->|是| RESOLVE[与用户沟通解决问题<br/>通过 AskUserQuestion]
    RESOLVE --> ANALYZE
    HAS_ISSUES -->|否| CHECK_METRICS{是否有量化<br/>指标？}
    CHECK_METRICS -->|是| CONFIRM_METRICS[与用户确认指标：<br/>硬性要求还是趋势？]
    CONFIRM_METRICS --> GEN_PLAN
    CHECK_METRICS -->|否| GEN_PLAN[生成结构化计划：<br/>- 目标描述<br/>- 包含 TDD 测试的验收标准<br/>- 路径边界<br/>- 可行性提示<br/>- 依赖与里程碑]
    GEN_PLAN --> WRITE[将计划写入输出文件<br/>使用 Edit 工具保留草稿]
    WRITE --> REVIEW[审查完整计划<br/>检查不一致之处]
    REVIEW --> INCONSISTENT{存在不一致？}
    INCONSISTENT -->|是| FIX[修复不一致]
    FIX --> REVIEW
    INCONSISTENT -->|否| CHECK_LANG{多种语言？}
    CHECK_LANG -->|是| UNIFY[要求用户统一语言]
    UNIFY --> REPORT_SUCCESS
    CHECK_LANG -->|否| REPORT_SUCCESS[报告成功：<br/>- 计划路径<br/>- AC 数量<br/>- 语言已统一？]
    REPORT_SUCCESS --> END_SUCCESS([结束])
```

## 输入要求

**必需参数：**
- `--input <path/to/draft.md>` - 草稿文档
- `--output <path/to/plan.md>` - 计划写入位置

## 计划结构输出

生成的计划包含：

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
- Can use: allowed technologies
- Cannot use: prohibited technologies

## Dependencies and Sequence

### Milestones
1. Milestone 1: Description
   - Phase A: ...
   - Phase B: ...

## Implementation Notes
- Code should NOT contain plan terminology
```

## 验证退出代码

| 退出代码 | 含义 |
|-----------|---------|
| 0 | 成功 - 继续 |
| 1 | 输入文件未找到 |
| 2 | 输入文件为空 |
| 3 | 输出目录不存在 |
| 4 | 输出文件已存在 |
| 5 | 无写入权限 |
| 6 | 参数无效 |
| 7 | 计划模板文件未找到 |

## 使用方法

```bash
# 启动流程
/flow:humanize-gen-plan

# 流程将询问：
# - 输入草稿文件路径
# - 输出计划文件路径
```

或仅使用技能（不自动执行）：

```bash
/skill:humanize-gen-plan
```
