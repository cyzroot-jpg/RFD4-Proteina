# Git 未清理

您正在尝试停止，但您有 **{{GIT_ISSUES}}**。
{{SPECIAL_NOTES}}
**必需的操作**：
0. 如果已安装 `code-simplifier` 插件，请在提交前使用它来审查和简化您的代码。通过以下方式调用：`/code-simplifier`、`@agent-code-simplifier` 或 `@code-simplifier:code-simplifier (agent)`
1. 检查未跟踪的文件 - 将构建产物添加到 `.gitignore`
2. 仅暂存实际更改，使用具体路径：`git add <files>`
3. 使用符合项目规范的描述性消息提交

**重要规则**：
- 在活动的 RLCR 循环期间，不要使用 `git add -A`、`git add --all` 或 `git add .`
- 永远不要暂存 `.humanize/` 或旧版 `.humanize-*` 循环产物
- 提交消息必须符合项目规范
- AI 工具（Claude、Codex 等）不得在提交中署名
- 不要包含 `Co-Authored-By: Claude` 或类似的 AI 署名

提交所有更改后，您可以再次尝试退出。
