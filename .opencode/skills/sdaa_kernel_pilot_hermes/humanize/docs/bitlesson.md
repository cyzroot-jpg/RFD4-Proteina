# Bitter Lesson 工作流

BitLesson 是仓库中用于 RLCR 轮次的 Bitter Lesson 风格知识捕获系统。

## 配置

选择器从合并后的配置层级中读取 `bitlesson_model`：

1. `config/default_config.json`
2. `~/.config/humanize/config.json`
3. `.humanize/config.json`
4. 适用时的 CLI 标志

提供者路由是自动的：

- `gpt-*`、`o[N]-*`（例如 `o1-*`、`o3-*`、`o4-*`）路由到 Codex
- `claude-*`、`haiku`、`sonnet`、`opus` 路由到 Claude

如果配置的提供者二进制文件缺失，选择器会回退到默认的 Codex 模型，以使循环仍能继续进行。

在仅安装 Codex 的环境中，Humanize 会在用户配置中写入 `provider_mode: "codex-only"`。
当该模式存在时，选择器会在提供者解析之前强制将 BitLesson 选择指向 Codex/OpenAI 路径，
即使旧的默认值（如 `haiku`）原本会路由到 Claude。

## 工作流

每个项目将其 BitLesson 知识库保存在 `.humanize/bitlesson.md`。

当 `start-rlcr-loop` 开始时：

1. 如果文件尚不存在，则从 `templates/bitlesson.md` 初始化
2. 每个任务或子任务通过 `scripts/bitlesson-select.sh` 运行
3. 选定的 lesson ID 在实现过程中被应用，如果没有匹配项则记录 `NONE`
4. 停止门控会在每轮摘要中验证必需的 `## BitLesson Delta` 部分

## 摘要契约

必需的摘要格式：

```markdown
## BitLesson Delta
- Action: none|add|update
- Lesson ID(s): <IDs or NONE>
- Notes: <what changed and why>
```

验证规则是严格的：

- `Action: none` 必须使用 `Lesson ID(s): NONE` 或将该字段留空
- `Action: add` 和 `Action: update` 必须引用 `.humanize/bitlesson.md` 中存在的具体 `BL-YYYYMMDD-short-name` ID
- `--require-bitlesson-entry-for-none` 可用于阻止空知识库反复报告 `none`
