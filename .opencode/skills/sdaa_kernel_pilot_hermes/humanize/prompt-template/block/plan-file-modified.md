# 计划文件已修改

计划文件 `{{PLAN_FILE}}` 自会话开始以来已被修改。

**在活动会话期间禁止修改计划文件。**

如果需要更改计划：
1. 取消当前会话：`/humanize:cancel-rlcr-loop`
2. 更新计划文件
3. 启动新会话：`/humanize:start-rlcr-loop {{PLAN_FILE}}`

备份位于：`{{BACKUP_PATH}}`
