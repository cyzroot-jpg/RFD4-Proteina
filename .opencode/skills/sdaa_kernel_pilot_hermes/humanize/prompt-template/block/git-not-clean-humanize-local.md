
**特殊情况 - 检测到 .humanize 目录**：
`.humanize/` 目录由 humanize:start-rlcr-loop 创建，不应被提交。
请将其添加到 .gitignore：
```bash
echo '.humanize*' >> .gitignore
git add .gitignore
```
