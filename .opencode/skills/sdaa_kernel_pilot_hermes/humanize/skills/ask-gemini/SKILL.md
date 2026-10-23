---
name: ask-gemini
description: 以独立专家身份咨询 Gemini，具备深度网络研究能力。将问题或任务发送给 Gemini CLI 并返回基于研究的响应。
argument-hint: "[--gemini-model MODEL] [--gemini-timeout SECONDS] [question or task]"
allowed-tools: "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-gemini.sh:*)"
---

# 咨询 Gemini

将问题或任务发送给 Gemini 并返回基于研究的响应。Gemini 始终被指示通过 Google Search 进行网络研究，使其非常适合需要最新互联网信息的深度研究任务。

## 使用方法

不要将自由格式的用户文本不加引号地传递给 shell。问题或任务可能包含空格或 shell 元字符，例如 `(`、`)`、`;`、`#`、`*` 或 `[`。

如果用户仅提供了问题或任务，执行：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-gemini.sh" "$ARGUMENTS"
```

如果用户提供了 `--gemini-model` 或 `--gemini-timeout` 等标志，请重新构造命令，使这些标志作为独立的 shell 参数，其余的自由格式问题作为一个带引号的最终参数传递。

示例：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-gemini.sh" --gemini-model gemini-2.5-pro "What are the latest Rust async runtime benchmarks?"
```

切勿运行以下不安全形式：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ask-gemini.sh" $ARGUMENTS
```

因为 shell 会重新解析问题文本，可能在 `ask-gemini.sh` 启动之前就失败。

## 解读输出

- 脚本将 Gemini 的响应输出到 **stdout**，将状态信息输出到 **stderr**
- 仔细阅读 stdout 输出，并将 Gemini 的响应整合到你的回答中
- Gemini 的响应基于网络来源的研究；在可用时转发来源引用
- 如果脚本以非零代码退出，向用户报告错误

## 错误处理

| 退出代码 | 含义 |
|-----------|---------|
| 0 | 成功 - Gemini 响应在 stdout 中 |
| 1 | 验证错误（缺少 gemini、问题为空、标志无效） |
| 124 | 超时 - 建议使用更大的 `--gemini-timeout` 值 |
| 其他 | Gemini 进程错误 - 报告退出代码和任何 stderr 输出 |

## 备注

- 响应保存到 `.humanize/skill/<timestamp>/output.md` 供参考
- 默认模型为 `gemini-3.1-pro-preview`，超时时间为 3600 秒
- Gemini 始终被指示执行 Google Search 以获取最新信息
