# teco-ops-wiki Schema

## 页面类型

| 类型 | ID 前缀 | 用途 |
|---|---|---|
| `source-doc` | `doc-*` | 官方/外部文档的来源**索引页**：元信息、章节目录、分卷链接、`raw_text` 原文链接。 |
| `source-doc-part` | `doc-*-pNN` | 官方文档的**完整结构化分卷页**：正文按文件/章节切分，无损保留原文内容，经 `raw_text` 逐行可追溯。 |
| `wiki-hardware` | `hw-*` | 硬件与编程模型速览页面。 |
| `wiki-technique` | `technique-*` | 算子开发技术与流程（interface+ual、绑定、注册、模型迁移）。 |
| `wiki-pattern` | `pattern-*` | 症状 -> 诊断 -> 处理办法。 |
| `wiki-kernel` | `kernel-*` | 带证据的算子案例研究/范例解析。 |

This wiki does not currently use the `wiki-language`, `wiki-runtime`,
`wiki-compiler`, `wiki-migration`, `wiki-example`, `source-repo`, `source-op`, or
`source-local` types. The complete standalone schema is in `data/schemas.yaml`.

## 置信度

- `verified`：官方文档 + 实现或 profiler 证据共同支持。
- `source-reported`：由本地笔记、经验表或分析报告支持。
- `inferred`：从多个来源综合得出，但没有直接验证。
- `experimental`：合理但仍需复测、官方确认或更多 shape 覆盖。

本知识库中的全部 `sources/docs/` 与 `wiki/` 页面均标注为 `verified`，因为内容直接来自已发布的官方文档或公开仓库材料，未包含未经验证的本地实验数据。`artifacts/repos/` 下的完整源码快照不套用 schema/confidence 体系（它们是原始代码，不是 wiki 页面），仅通过 `PROVENANCE.md` 记录来源。

## 范围契约

一个页面若要新增到 `sources/docs/` 或 `wiki/`，必须满足：

1. 内容来源仅限于 Teco-Ops（`https://github.com/Tecorigin/teco-ops`）、Teco-AL（`https://gitee.com/tecorigin/teco-al`）、PICT_smoke（`https://github.com/Tecorigin/PICT_smoke`）三个公开仓库，或已获授权收录的官方手册（4 份 SDAA 系列手册 + TecoLIBRT 用户手册 + TecoPyTorch 用户手册）。
2. 不引用内部代码仓（`tecoal`/`sdcops`/`tecocustom`/`tecolmk` gerrit 仓库）或其余官方手册的内容。
3. 不收录图片资源，仅保留文字/公式/代码说明（`artifacts/repos/` 下的完整快照除外，其中保留原始图片文件）。
4. Every `sources:` id must resolve inside this wiki.

`artifacts/repos/<project>/` 下的完整源码快照不受上述"仅收录文档"限制——三个仓库现已完整收录，新增/更新快照时只需在对应目录下更新 `PROVENANCE.md` 记录来源 commit 与采集日期，不需要走 schema 校验（`validate.py` 只扫描 `wiki/`、`sources/`、`docs/`，不扫描 `artifacts/`）。
