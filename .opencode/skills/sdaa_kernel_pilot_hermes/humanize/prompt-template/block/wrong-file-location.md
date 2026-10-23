# 错误的文件位置

您正在尝试读取 `{{FILE_PATH}}`，但循环文件在 `{{ACTIVE_LOOP_DIR}}/` 中。

**当前轮次文件**：
- 提示：`{{ACTIVE_LOOP_DIR}}/round-{{CURRENT_ROUND}}-prompt.md`
- 摘要：`{{ACTIVE_LOOP_DIR}}/round-{{CURRENT_ROUND}}-summary.md`

如果需要此文件，请使用：`cat {{FILE_PATH}}`
