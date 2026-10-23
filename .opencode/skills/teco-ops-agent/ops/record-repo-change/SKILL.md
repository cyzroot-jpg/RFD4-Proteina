---
name: record-repo-change
description: 记录 teco-ops-agent 仓库自身的功能问题修复与功能支持。用于 hook、CLI、脚本、配置、安装、skill 流程或文档与实现不一致等仓库功能问题，在完成修复或功能落地并验证后，向 docs/问题记录 写入简短记录。不要用于算子 kernel、算子性能优化、普通文档排版或未验证猜测。触发：功能问题、bug 修复、hook 失败、CLI 异常、脚本报错、配置失效、功能支持、完成修复、问题复盘。
---

# 仓库问题与功能记录

只记录可复用的核心事实。每条记录控制在 6–10 行，不写完整排障时间线。
记录按月汇总到 `docs/问题记录/YYYY-MM.md`，在月文档内按完成顺序追加。

## 适用范围

- `teco-ops-agent` 自身的 hook、CLI、脚本、配置、安装和 skill 流程问题。
- 新增或补齐仓库级功能支持。
- 文档约定与实际实现不一致，并且已经完成实质修复。

以下内容不记录：

- 算子 kernel、精度、性能或数据流问题；使用 `sdaa-op-learning-validation`。
- 纯排版、错别字、注释调整和无行为变化的机械重构。
- 尚未确认根因或尚未验证完成的猜测。

## 工作流

1. 先完成修复或功能实现，并运行对应验证。
2. 在 `docs/问题记录/` 中检索是否已有同类记录，避免重复。
3. 将类型归为 `bugfix` 或 `feature`。
4. 用脚本生成一条短记录：

```bash
python3 ops/record-repo-change/scripts/record_change.py \
  --type bugfix \
  --title "Stop hook JSON 输出修复" \
  --problem "Stop hook 向 stdout 输出普通文本，Codex 无法解析。" \
  --solution "统一输出 Codex hook JSON，失败时返回 decision:block。" \
  --verification "21 个单测通过，真实 hook stdout 可被 json.loads 解析。" \
  --file .codex/config.toml \
  --file ops/sdaa-op-learning-validation/scripts/hooks/learned_patterns_guard.py
```

脚本会自动追加到当月文档，并生成月内递增编号 `CR-YYYYMM-NNN`。

## 核心方案文档

多数记录只写一句核心方案。确实需要保留设计细节、协议或迁移步骤时：

1. 在 `docs/问题记录/核心方案/` 新建 Markdown 文档。
2. 月度记录仍只保留一句摘要，并通过 `--solution-doc` 引用详细文档：

```bash
python3 ops/record-repo-change/scripts/record_change.py \
  --type feature \
  --title "示例功能支持" \
  --problem "一句话核心需求。" \
  --solution "一句话核心方案。" \
  --verification "实际验证结果。" \
  --solution-doc docs/问题记录/核心方案/example.md
```

没有实质性详细方案时，不创建核心方案文档。

## 记录要求

- 核心问题或需求：一句话说明为什么要改。
- 核心方案：一句话说明关键修复或支持方式。
- 验证：写实际执行过的测试或行为结果。
- 关联文件：只列最关键的文件，可省略。

修复或功能未验证时不要写“已完成”。最终回复前确认当月记录已经追加。
