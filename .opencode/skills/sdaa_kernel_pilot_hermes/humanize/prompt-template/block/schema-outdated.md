# 状态架构过时

状态文件缺少必需字段：`{{FIELD_NAME}}`

这表明会话是使用旧版本的 humanize 启动的。

**选项：**
1. 取消会话：`/humanize:cancel-rlcr-loop`
2. 将 humanize 插件更新到版本 1.1.2+
3. 使用更新后的插件重新启动

会话将以 'unexpected' 状态终止，以保留状态信息。
