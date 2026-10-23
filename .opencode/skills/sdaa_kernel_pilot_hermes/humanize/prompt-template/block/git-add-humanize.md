# Git Add 被阻止：.humanize 保护

`.humanize/` 目录包含不应提交的本地循环状态。
此目录已列在 `.gitignore` 中。

您的命令被阻止，因为它会将 .humanize 文件添加到版本控制中。

## 允许的命令

使用具体的文件路径而不是宽泛的模式：

    git add <specific-file>
    git add src/
    git add -p  # patch mode

## 被阻止的命令

当 .humanize 存在时，以下命令会被阻止：

    git add .humanize      # 直接引用
    git add -A             # 添加所有文件，包括 .humanize
    git add --all          # 添加所有文件，包括 .humanize
    git add .              # 如果未被 gitignore 忽略，可能包含 .humanize
    git add -f .           # 强制绕过 gitignore

## 将 .humanize 添加到 .gitignore

如果需要将 `.humanize*` 添加到 `.gitignore`，请按照以下步骤操作：

1. 编辑 `.gitignore` 以追加 `.humanize*`
2. 运行：`git add .gitignore`
3. 运行：`git commit -m "Add humanize local folder into gitignore"`

重要提示：提交消息不得包含字面字符串 ".humanize"，以避免触发此保护机制。
