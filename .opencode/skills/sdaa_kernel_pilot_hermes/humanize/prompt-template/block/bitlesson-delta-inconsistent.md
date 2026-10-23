# BitLesson Delta 不一致

您的 `## BitLesson Delta` 声明与预期的 BitLesson 状态不匹配。

请检查并修正：
- `Action: none` -> `Lesson ID(s): NONE`（或省略 Lesson IDs）
- `Action: add|update` -> 提供具体的 Lesson ID，并确保每个 ID 都存在于 `.humanize/bitlesson.md` 中
