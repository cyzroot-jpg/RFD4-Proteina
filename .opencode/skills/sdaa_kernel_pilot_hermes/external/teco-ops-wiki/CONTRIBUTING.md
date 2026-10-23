# 向 teco-ops-wiki 添加新内容

本指南说明如何向本知识库新增页面或更新源码快照。权威 schema 见
[`references/schema.md`](references/schema.md) 与 [`data/schemas.yaml`](data/schemas.yaml),
取值枚举见 [`data/tags.yaml`](data/tags.yaml),同义词见 [`data/aliases.yaml`](data/aliases.yaml)。
校验工具为 [`scripts/validate.py`](scripts/validate.py)。

新增内容分两类：

1. **策展页 / 来源页**：放在 `wiki/`、`sources/`、`docs/` 下，带 YAML frontmatter，走
   `validate.py` 校验。
2. **源码快照**：放在 `artifacts/repos/<project>/` 下，**不走** schema 校验，只需更新对应目录的
   `PROVENANCE.md`。

---

## 一、确定页面类型

`type` 字段（frontmatter 里写短形式）决定 id 前缀、放置目录与必填字段。下表以
`validate.py` 实际强制的内容为准。

| `type` 值 | id 前缀 | 放置目录 | 必填 frontmatter 字段 |
|---|---|---|---|
| `hardware` | `hw-` | `wiki/hardware/` | id, title, type, architectures, tags, confidence, sources |
| `technique` | `technique-` | `wiki/techniques/` | id, title, type, architectures, tags, confidence, reproducibility, sources |
| `pattern` | `pattern-` | `wiki/patterns/` | id, title, type, symptoms, candidate_techniques, sources |
| `kernel` | `kernel-` | `wiki/kernels/` | id, title, type, architectures, kernel_types, confidence, sources |
| `source-doc` | `doc-` | `sources/docs/` | id, title, type, source_category, product_version, published_at, captured_at |
| `source-doc-part` | `doc-*-pNN` | `sources/docs/<doc>/` | id, title, type, parent_doc, raw_text, raw_line_range |
| `source-repo` | `source-` | `sources/repos/` | id, title, type, project, local_root, captured_at |
| `source-op` | `source-` | `sources/ops/` | id, title, type, project, op_name, layer, local_paths, captured_at |
| `source-local` | `source-local-` | `sources/` | id, title, source_category, path, captured_at |

> 注：`references/schema.md` 里用 `wiki-hardware`/`wiki-technique` 等长名描述类型，但
> frontmatter 的 `type:` 字段与 `validate.py` 一致，使用短形式（`hardware`、`technique`、
> `pattern`、`kernel`）。现有页面均按短形式书写，请保持一致。

---

## 二、写 frontmatter（以新增 technique 页为例）

文件放 `wiki/techniques/<slug>.md`，文件名 slug 与 id 后缀一致：

```markdown
---
id: technique-teco-ops-<slug>
title: "你的标题"
type: technique
architectures: [sdaa, teco-t1]
tags: [dma, double-diagonal-broadcast]
confidence: verified
reproducibility: runnable
sources: [source-teco-ops-rms-norm]
---

# 正文标题

正文内容……
```

### 字段取值约束

枚举值必须取自 `data/tags.yaml` 与 `data/schemas.yaml`，不可自造：

- **`architectures`**：`data/tags.yaml` 的 `architectures`（如 `sdaa`、`teco-t1`、`spa`）。
- **`tags`**：`data/tags.yaml` 的 `hardware_features` 与 `techniques`（如 `dma`、`spm`、
  `ace-double-buffering`、`simd-vectorization`）。
- **`kernel_types`**：`data/tags.yaml` 的 `kernel_types`（如 `gemm`、`reduction`、`elementwise`）。
- **`languages`**：`data/tags.yaml` 的 `languages`（如 `sdaa-c`、`sdaa-cpp`、`python`）。
- **`confidence`**：`verified` / `source-reported` / `inferred` / `experimental`。
- **`reproducibility`**：`concept` / `pseudocode` / `snippet` / `runnable` / `benchmarked`。
- **`source_category`**：`data/tags.yaml` 的 `source_category`（如 `official-doc`、
  `profiler-report`、`local-note`）。

### 各类型特有字段

- `pattern`：`symptoms`（取自 `data/tags.yaml` 的 `symptoms`）、`candidate_techniques`
  （指向 technique 页 id 列表）。
- `kernel`：`kernel_types`（必填）；可加 `languages`、`related`（指向相关页 id）。
- `source-doc-part`：`parent_doc` 指向所属 `source-doc` 索引页 id，`raw_text` 指向
  `sources/docs/raw-*/` 下的原始文本路径，`raw_line_range` 标注行范围。

---

## 三、范围契约（必须满足）

摘自 [`references/schema.md`](references/schema.md) 的“范围契约”：

1. **来源限定**：内容只能来自三个公开仓库——Teco-Ops
   (`https://github.com/Tecorigin/teco-ops`)、Teco-AL
   (`https://gitee.com/tecorigin/teco-al`)、PICT_smoke
   (`https://github.com/Tecorigin/PICT_smoke`)——或已获授权收录的官方手册
   （SDAA C 编程指南、两份性能优化手册、SDAA C 入门、TecoLIBRT 用户手册、TecoPyTorch 用户手册）。
2. **不引用内部仓**：不收录 `tecoal`/`sdcops`/`tecocustom`/`tecolmk` 等 gerrit 仓库或其余
   官方手册的内容。
3. **不收录图片**：仅保留文字/公式/代码说明（`artifacts/repos/` 下的完整快照除外）。
4. **`sources:` 必须可解析**：每个 `sources:` 里的 id 必须能在本 wiki 内解析到对应页面。
   `validate.py` 会逐条校验，引用了不存在的 id 会报错。
   `source-doc-part` 的 `parent_doc` 同样必须指向已存在的索引页 id。

---

## 四、可发现性：tags 与 aliases

写好页面后，希望它被 `query.py` 用更多说法命中时，在 [`data/aliases.yaml`](data/aliases.yaml)
给相关枚举补同义词。例如：

```yaml
dma:
  - DMA engine
  - dma_get
  - dma_put
```

`query.py` 会同时匹配枚举值与别名。无需为新页单独注册——只要 frontmatter 的
`tags`/`architectures`/`kernel_types` 用了枚举，页面的正文与 id 已可被全文检索。

---

## 五、校验与确认

在本 skill 根目录下运行：

```bash
python3 scripts/validate.py
```

`validate.py` 扫描 `wiki/`、`sources/`、`docs/` 下的所有 `.md`（**不扫** `artifacts/`），检查：

- 每页有 YAML frontmatter 且 `id` 非空；
- `id` 全局唯一（重复报错并指出冲突文件）；
- 按 `type` 校验必填字段存在且非空；
- `wiki/` 与 `docs/` 页面的每个 `sources:` id 都能解析到已存在页面；
- `source-doc-part` 的 `parent_doc` 能解析到。

校验通过后，确认新页可被检索与追溯：

```bash
python3 scripts/query.py "你的主题关键词" --compact
python3 scripts/get_page.py <新页-id> --follow-sources
```

---

## 六、更新源码快照（`artifacts/repos/`）

完整源码快照**不受** schema/范围契约约束，`validate.py` 不扫描 `artifacts/`。新增或更新快照时：

1. 在 `artifacts/repos/<project>/` 下放入或更新对应仓库的逐字快照。
2. 更新该目录的 `PROVENANCE.md`，记录上游仓库、分支、commit 与采集日期。

> 需要核实快照来源时，查看 `artifacts/repos/<project>/PROVENANCE.md`。当前 teco-ops 快照跟踪
> 上游 `main` commit `ac7eb023faa0c84bdd8d9959561a59d44105da6e`。

---

## 检查清单

新增一个策展/来源页前，逐条确认：

- [ ] `type` 用短形式（`technique`/`kernel`/`pattern`/`hardware`/`source-*`），id 前缀匹配。
- [ ] 文件放在对应类型的目录下，文件名 slug 与 id 后缀一致。
- [ ] 必填字段齐全（见第一节表格），枚举取自 `data/tags.yaml`，`confidence`/`reproducibility`
      取自 `data/schemas.yaml`。
- [ ] 每个 `sources:` id、`parent_doc`、`related` 都能在本 wiki 内解析到。
- [ ] 内容来源限于三个公开仓库或已授权官方手册，无内部仓内容，无图片。
- [ ] `python3 scripts/validate.py` 通过，`query.py` 能查到新页。
