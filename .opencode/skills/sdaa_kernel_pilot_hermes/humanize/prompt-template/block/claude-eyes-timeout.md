# Claude Bot 未响应

Claude bot 在 **{{RETRY_COUNT}} 次重试**（总计 {{TOTAL_WAIT_SECONDS}} 秒）后仍未响应 'eyes' 表情。

**可能的原因**：
1. 远程仓库未配置 Claude bot
2. Claude bot 正在经历问题或停机
3. bot 对此仓库没有权限

**必需的操作**：
1. 验证 Claude bot 已安装在远程仓库上
2. 检查 bot 是否具有适当的权限
3. 确保 PR 处于 bot 可以响应的状态

**配置 Claude bot**：
访问仓库设置，确保 Claude GitHub App 已安装并有权访问此仓库。

正确配置 bot 后，发布新的触发评论以重新启动审查。
