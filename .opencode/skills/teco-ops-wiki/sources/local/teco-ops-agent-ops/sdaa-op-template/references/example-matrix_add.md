---
id: source-teco-ops-agent-ops-sdaa-op-template-references-example-matrix-add-d7675bb6
title: "teco-ops-agent ops: sdaa-op-template/references/example-matrix_add.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-template
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-template/references/example-matrix_add.md
relative_source_path: sdaa-op-template/references/example-matrix_add.md
captured_at: 2026-08-04
---

# 样例：matrix_add（PyTorch golden）

## golden()

```python
def golden(x, m):
    # 二元：prepare 时另写 b.bin，或 x 为拼接；示例一元占位
    return x + x  # 替换为 torch 语义：a + b
```

## 验收

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op matrix_add --scope-cmake --restore-cmake
```

不再使用 `cpu_matrix_add_forward` / `compare_data_f32`。
