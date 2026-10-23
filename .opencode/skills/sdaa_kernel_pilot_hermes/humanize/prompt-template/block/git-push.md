# Git Push 被阻止

当前提交应保持在本地 - 无需推送到远程。
循环将在本地处理提交，直到完成。

如果需要推送，请在启动循环时使用 `--push-every-round`：
```
/humanize:start-rlcr-loop plan.md --push-every-round
```
