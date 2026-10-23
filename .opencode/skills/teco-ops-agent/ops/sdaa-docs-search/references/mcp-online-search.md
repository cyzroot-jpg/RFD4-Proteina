# 在线文档检索（Codex MCP）

> 本地 `search_docs.py` 未命中时，通过 Codex 内置 MCP 查询太初在线文档与知识库。  
> Codex 使用 **`.toml`** 配置格式（非 JSON）。

## 1. MCP 服务

| 服务名 | URL | 用途 |
|--------|-----|------|
| `docs-center` | `http://docs.tecorigin.net/mcp` | 官方文档中心（TecoLIBRT / TecoKERNEL / SDAA 手册） |
| `knowledge-graph` | `http://ai.tecorigin.net/mcp` | 知识图谱 / 关联检索 |

传输协议：`streamable_http`

## 2. Codex 配置示例

在 `~/.codex/config.toml` 中追加：

```toml
[mcp_servers.docs-center]
transport = "streamable_http"
url = "http://docs.tecorigin.net/mcp"

[mcp_servers.knowledge-graph]
transport = "streamable_http"
url = "http://ai.tecorigin.net/mcp"
```

仓库内可复制模板：

```bash
# 查看示例（勿直接覆盖已有 config）
cat teco-ops-agent/configs/codex_mcp.example.toml
```

合并到本机配置后，重启 `codex` CLI 使 MCP 生效。

验证：

```bash
codex mcp list
codex mcp get docs-center
codex mcp get knowledge-graph
```

期望输出：`Status enabled`，`transport: streamable_http`。

### 已验证 MCP 工具（2026-06-16）

**docs-center**（FastMCP）

| 工具 | 用途 |
|------|------|
| `search_doc` | 模糊检索文档（如 `rt_dma_get`） |
| `list_doc` | 列出已发布文档 |
| `get_doc_tree` | 获取文档章节目录 |
| `get_doc_html_content` | 获取章节 HTML 正文 |

**knowledge-graph**（LightRAG）

| 工具 | 用途 |
|------|------|
| `query_lightrag_data` | **推荐**：原始检索结果，较快 |
| `query_lightrag_with_llm` | 经 LLM 生成的问答，较慢 |
| `get_lightrag_server_info` | 查看服务配置 |

### Codex Agent 中使用

启动 `codex` 后可直接提问，例如：

- 「用 docs-center 的 search_doc 查 rt_dma_get 官方说明」
- 「用 knowledge-graph 的 query_lightrag_data 查 TecoLIBRT DMA 访存优化」

> **注意**：`codex exec` 非交互模式需本机已设置 `OPENAI_API_KEY`（与 `auth.json` 中 key 一致），否则 LLM 调用会失败；MCP 服务本身无需该 key。

## 3. 检索优先级（修订）

```
1. 本地 search_docs.py（skill references / 头文件 / knowledge md）
2. 本地 references 精读
         ↓ 本地未命中或需官方最新说明
3. Codex MCP → docs-center（API 手册、Release Note）
4. Codex MCP → knowledge-graph（概念关联、跨文档跳转）
```

## 4. Agent 使用方式

在 **Codex / Cursor Agent** 中（已配置 MCP 后）：

- 直接提问：「用 docs-center 查 `rt_dma_iget` 官方说明」
- 本地 + 在线组合：「先 search_docs 查本地，没有再查 docs-center」

`run_cli.py agent-ask` **当前不自动调用 MCP**（仅本地 skills + LLM）；在线检索需在 Codex Agent 会话中使用 MCP 工具。

## 5. 网络要求

| 端点 | 要求 |
|------|------|
| `docs.tecorigin.net` | 内网或 VPN |
| `ai.tecorigin.net` | 内网或 VPN |

离线环境仅使用本地 `build_index.py` + `search_docs.py`。

## 6. 与其他 skill 分工

| 层级 | 载体 | 内容 |
|------|------|------|
| 本地全文 | `search_docs.py` | 头文件行级匹配 |
| 官方权威 | MCP `docs-center` | 在线手册完整章节 |
| 关联探索 | MCP `knowledge-graph` | 跨文档概念链 |
| 经验沉淀 | `learned-patterns` | DMA/RMA/SIMD/ACE 已验证经验 |

## 7. 故障排查

| 现象 | 处理 |
|------|------|
| MCP 工具不可见 | 检查 `config.toml` 段落名是否为 `[mcp_servers.<name>]` |
| 连接超时 | 确认内网/VPN；`curl -I http://docs.tecorigin.net/mcp` |
| 与 model_provider 冲突 | MCP 段独立于 `[model_providers.*]`，可共存 |
| 仍走旧计划 search_online.py | 已废弃；统一用 Codex MCP，无需自研 HTTP client |
