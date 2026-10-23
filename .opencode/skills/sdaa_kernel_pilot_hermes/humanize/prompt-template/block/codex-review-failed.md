# Codex 审查失败

Codex 审查过程未能产生输出。

**退出代码**：{{CODEX_EXIT_CODE}}
**审查结果文件**：{{REVIEW_RESULT_FILE}}（未创建）

**调试文件**：
- 命令：{{CODEX_CMD_FILE}}
- 标准输出：{{CODEX_STDOUT_FILE}}
- 标准错误：{{CODEX_STDERR_FILE}}

**标准错误（最后 50 行）**：
```
{{STDERR_CONTENT}}
```

请检查调试文件以获取更多详细信息。系统将在您退出时尝试再次审查。
