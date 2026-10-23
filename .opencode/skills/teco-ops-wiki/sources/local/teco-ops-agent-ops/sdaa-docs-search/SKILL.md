---
id: source-teco-ops-agent-ops-sdaa-docs-search-skill-ccc5ad93
title: "teco-ops-agent ops: sdaa-docs-search/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-docs-search
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-docs-search/SKILL.md
relative_source_path: sdaa-docs-search/SKILL.md
captured_at: 2026-08-04
---

---
name: sdaa-docs-search
description: SDAA 开发资源本地检索技能。通过本地头文件、平台文档与 skill references 索引定位 API 用法与硬件说明，优先查本地、缺失时再查在线（docs.tecorigin.net，需内网）。触发关键词：文档检索、API 查询、rt_dma、rt_rma、batch_、tecolibrt、tecokernel、本地搜索、docs-search。
---

# SDAA 开发资源检索

本地优先的文档与 API 检索能力，服务于算子设计、API 选型与 Tiling 决策。

## 检索优先级

```
1. thirdParty 头文件（API 签名）
2. 本地 references/*.md
         ↓ 本地未命中
3. Codex MCP docs-center（在线手册）
```

> **禁止**：用本 skill 在 `swdnn_test_ops/src/` 搜索「类似算子」作为用户新算子的交付物。算子交付走 `sdaa-op-design` + `scaffold_op --from-design`，已有 demo 仅可作只读 API 参考。

## 快速命令

```bash
SKILL_DIR="<本 skill 目录>"

# 构建 / 更新本地索引
python3 "$SKILL_DIR/scripts/build_index.py"

# 检索（文本输出）
python3 "$SKILL_DIR/scripts/search_docs.py" --query "rt_dma_get"

# 检索（JSON，供 agent 消费）
python3 "$SKILL_DIR/scripts/search_docs.py" --query "rt_dma_iget" --json --top 5
```

> `<SKILL_DIR>` 为安装目录，如 `teco-ops-agent/ops/sdaa-docs-search/` 或 `.codex/skills/sdaa-docs-search/`。

## 索引范围

详见 [corpus-paths.md](references/corpus-paths.md)。MVP 阶段索引：

- 本仓库 `ops/**/references/*.md`
- 工作区 `sdaa-kernel-poilot/knowledge/*.md`（若存在）
- `swdnn_test_ops/thirdParty/*/include/**/*.h`（若 submodule 存在）
- `/opt/tecoai/include`（若已 `source setvars.sh`）

## 与其他 skill 的衔接

| 场景 | 推荐路径 |
|------|----------|
| API 用法 | `search_docs` 检索本地 references |
| 在线手册 | Codex MCP `docs-center`（配置见 [mcp-online-search.md](references/mcp-online-search.md)） |

## 输出契约（`--json`）

```json
{
  "query": "rt_dma_get",
  "count": 3,
  "hits": [
    {
      "path": "/path/to/dma-api.md",
      "line": 12,
      "text": "| rt_dma_get | HBM→LDM 阻塞搬运 |",
      "source": "skill-ref"
    }
  ]
}
```

## 在线检索（Codex MCP）

本地未命中时，在 **Codex Agent** 中使用 MCP（需先配置 `~/.codex/config.toml`）：

```toml
[mcp_servers.docs-center]
transport = "streamable_http"
url = "http://docs.tecorigin.net/mcp"

[mcp_servers.knowledge-graph]
transport = "streamable_http"
url = "http://ai.tecorigin.net/mcp"
```

详见 [mcp-online-search.md](references/mcp-online-search.md)。模板文件：`teco-ops-agent/configs/codex_mcp.example.toml`。

## 参考资料

- [语料路径说明](references/corpus-paths.md)
- [MCP 在线检索](references/mcp-online-search.md)
- [API 索引 stub](references/api-index-stub.md)

## 范围边界

- **本地**：`build_index.py` + `search_docs.py`（`.md` / `.h` 全文索引）
- **在线**：Codex MCP（非自研 HTTP client）
- **不在范围**：网页抓取、Gerrit 代码搜索
