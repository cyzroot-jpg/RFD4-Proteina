---
id: source-teco-ops-agent-ops-sdaa-op-template-references-migration-rules-3a930e5d
title: "teco-ops-agent ops: sdaa-op-template/references/migration_rules.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/migration_rules.md
relative_source_path: sdaa-op-template/references/migration_rules.md
captured_at: 2026-08-04
---

# 轻量化迁移规则（摘要）

> 原文：`swdnn_test_ops/MIGRATION_RULES.md`

## 精度

- **L3 仅 PyTorch**：`<op>_torch_golden.py` + `torch_verify.py`
- 禁止迁移 C++ `cpu_*_forward` / `compare_data_*` 作为验收标准

## 脚手架关系

`scaffold_op.py` 生成 kernel 桩 + torch golden 脚本。开发者：

1. 填 device kernel
2. 填 `golden()`（torch 算子）
3. `torch_verify.py --scope-cmake`

### 验收

| 层 | 标准 |
|----|------|
| L0 | `torch_verify.py --build-only` |
| L1/L2 | verify_sanity |
| L3 | torch compare passed |
