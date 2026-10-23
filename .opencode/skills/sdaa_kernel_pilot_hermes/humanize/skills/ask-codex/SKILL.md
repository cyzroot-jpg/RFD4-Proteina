---
name: ask-codex
description: 以独立专家身份咨询 Codex。将问题或任务发送给 codex exec 并返回响应。
argument-hint: "[--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [question or task]"
allowed-tools: "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh:*)"
---

# 咨询 Codex

将问题或任务发送给 Codex 并返回响应。

## 使用方法

不要将自由格式的用户文本不加引号地传递给 shell。问题或任务可能包含空格或 shell 元字符，例如 `(`、`)`、`;`、`#`、`*` 或 `[`。

如果用户仅提供了问题或任务，执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" "$ARGUMENTS"
```

如果用户提供了 `--codex-model` 或 `--codex-timeout` 等标志，请重新构造命令，使这些标志作为独立的 shell 参数，其余的自由格式问题作为一个带引号的最终参数传递。

示例：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" --codex-model gpt-5.5:high "Review the following round summary (M4)..."
```

切勿运行以下不安全形式：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" $ARGUMENTS
```

因为 shell 会重新解析问题文本，可能在 `ask-codex.sh` 启动之前就失败。

## 解读输出

- 脚本将 Codex 的响应输出到 **stdout**，将状态信息输出到 **stderr**
- 仔细阅读 stdout 输出，并将 Codex 的响应整合到你的回答中
- 如果脚本以非零代码退出，向用户报告错误

## 错误处理

| 退出代码 | 含义 |
|-----------|---------|
| 0 | 成功 - Codex 响应在 stdout 中 |
| 1 | 验证错误（缺少 codex、问题为空、标志无效） |
| 124 | 超时 - 建议使用更大的 `--codex-timeout` 值 |
| 其他 | Codex 进程错误 - 报告退出代码和任何 stderr 输出 |

## 备注

- 响应保存到 `.humanize/skill/<timestamp>/output.md` 供参考
- 默认模型为 `gpt-5.5:high`，超时时间为 3600 秒
