# 已跟踪的 Humanize 状态被阻止

检测到 `.humanize/` 下有已跟踪或已暂存的文件。

这些文件是本地 Humanize 循环状态，必须保留在版本控制之外。

## 必需的修复

1. 从索引中移除 Humanize 状态：

       git rm --cached -r .humanize

2. 仅保留实际的项目文件在暂存区。
3. 在本地状态不再被跟踪后重试停止操作。

## 重要提示

- 不要在 Humanize 状态文件上使用 `git add -f`。
- 不要提交 RLCR 跟踪器、轮次摘要、合同或取消/完成标记。
