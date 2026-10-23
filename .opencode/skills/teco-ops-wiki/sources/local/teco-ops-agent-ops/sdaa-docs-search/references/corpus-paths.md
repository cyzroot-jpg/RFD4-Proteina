---
id: source-teco-ops-agent-ops-sdaa-docs-search-references-corpus-paths-729628e5
title: "teco-ops-agent ops: sdaa-docs-search/references/corpus-paths.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-docs-search
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-docs-search/references/corpus-paths.md
relative_source_path: sdaa-docs-search/references/corpus-paths.md
captured_at: 2026-08-04
---

# 本地检索语料路径

> 索引由 `scripts/build_index.py` 扫描；路径不存在时自动跳过。

## 1. 固定路径（相对可选外部 workspace root）

| 类别 | 路径 | 说明 |
|------|------|------|
| Skill references | `teco-ops-agent/ops/**/references/**` | 已整理的平台/API 文档 |
| Project docs | `teco-ops-agent/docs/**` | 项目文档、代码规范、跨 skill 共享知识库 |
| teco-ops 源码 | `teco-ops/teco/**` | interface + UAL 算子开发 API 和 kernel 结构 |
| teco-ops 公共头 | `teco-ops/common/**` | 公共工具和类型 |
| teco-ops thirdparty | `teco-ops/thirdparty/**` | 当前算子工程依赖 |
| 平台知识库 | `sdaa-kernel-poilot/knowledge/*.md` | T1、DMA、ACE 等 |
| 硬件模型 | `optest-agent/docs/*.md` | SPA/SPE/DMA 模型 |

## 2. 环境相关路径

| 路径 | 条件 |
|------|------|
| `/opt/tecoai/include/**` | `source /opt/tecoai/setvars.sh` 后可用 |
| `$TECOAI_HOME/include/**` | 若环境变量已设置 |

## 3. 索引字段

每条记录包含：

- `path`：绝对路径
- `line`：行号（1-based）
- `text`：匹配行原文（截断至 500 字符）
- `source`：`skill-ref` | `project-doc` | `knowledge` | `header` | `optest-doc`

## 4. 更新方式

```bash
# 在 teco-ops-agent 根目录
python3 ops/sdaa-docs-search/scripts/build_index.py

# 指定额外根目录（按本机实际 workspace 设置）
python3 ops/sdaa-docs-search/scripts/build_index.py --root <workspace-root>
```

索引默认写入：`ops/sdaa-docs-search/.index/docs_index.json`（已加入 `.gitignore` 建议，可提交空目录占位）。

## 5. 降级策略

| 情况 | 行为 |
|------|------|
| `teco-ops` 工作树缺失 | 仅索引 skill references + knowledge md |
| `/opt/tecoai` 不可用 | 跳过 SDK 头文件，不影响 md 检索 |
| 索引未构建 | `search_docs.py` 提示先运行 `build_index.py` |

## 6. 在线扩展（Codex MCP）

在线检索通过 Codex MCP 配置，无需自研 client：

- `docs-center` → `http://docs.tecorigin.net/mcp`
- `knowledge-graph` → `http://ai.tecorigin.net/mcp`

配置说明见 [mcp-online-search.md](mcp-online-search.md)。

## 7. 后续本地扩展

- `teco-ops/test/zoo/teco/**` 测试样例和 prototxt case
- 与 `agent-ask --with-docs` 自动注入本地 Top-K
