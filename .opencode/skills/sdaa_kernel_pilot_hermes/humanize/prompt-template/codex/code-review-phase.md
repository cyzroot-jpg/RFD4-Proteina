# 代码审查阶段 - 第 {{REVIEW_ROUND}} 轮

此文件记录代码审查调用，用于审计目的。
兼容性说明：Codex 0.130.0 在使用 `--base` 时会拒绝 `[PROMPT]` 输入（包括 `-` stdin）。Humanize 在使用 `--base` 时不得传递提示输入；此文件仅用于审计。

## 审查配置

- **基础分支**: {{BASE_BRANCH}}
- **审查轮次**: {{REVIEW_ROUND}}
- **时间戳**: {{TIMESTAMP}}

## 此阶段的功能

1. 运行 `codex review --base {{BASE_BRANCH}}` 执行自动化代码审查
2. 扫描输出中的 `[P0-9]` 严重性标记以识别问题
3. 如果发现问题：将修复提示返回给 Claude 进行修复
4. 如果没有问题：进入完成阶段

## 预期输出格式

Codex 审查以以下格式输出问题：
```
- [P0] Critical issue description - /path/to/file.py:line-range
  Detailed explanation of the issue.

- [P1] High priority issue - /path/to/file.py:line-range
  Detailed explanation.
```

## 生成的文件

- `round-{{REVIEW_ROUND}}-review-prompt.md` - 此审计文件
- `round-{{REVIEW_ROUND}}-review-result.md` - 审查输出（位于循环目录中）
- `round-{{REVIEW_ROUND}}-codex-review.cmd` - 命令调用（位于缓存中）
- `round-{{REVIEW_ROUND}}-codex-review.out` - 标准输出捕获（位于缓存中）
- `round-{{REVIEW_ROUND}}-codex-review.log` - 标准错误捕获（位于缓存中）
