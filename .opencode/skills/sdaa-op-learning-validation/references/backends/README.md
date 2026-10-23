# Backend Profiles

每个 backend 定义一套验证体系：如何判定正确性、如何判定交付/流水线通过、如何采集性能、
抽取模式时关注哪些 API 词汇。学习方法论（attempt loop、pattern extraction、learned-patterns gate）
是 backend 无关的，backend 只参数化验证绑定层。

## 已有 backend

| Backend | 接口风格 | 验证方式 | 文档 |
|---------|----------|----------|------|
| `teco-ops` | interface + ual | `skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` | [teco-ops.md](teco-ops.md) |

## 脚本使用

```bash
# 初始化学习任务时指定 backend
python3 .../init_learning_task.py --backend teco-ops ...

# 验证 learned-patterns
python3 .../validate_learned_patterns.py

# 提升阶段结果时指定 backend
python3 .../promote_design_facts.py --backend teco-ops ...
```

不传 `--backend` 时默认使用 `teco-ops`。

## 路径配置

`demo_root` 支持绝对路径和相对路径（相对于 skill 仓库根目录）。
禁止把个人绝对路径提交到仓库配置或 learned-patterns。

## 如何新增 backend

1. 在 `scripts/backend_profiles.py` 的 `BACKENDS` 字典中新增一个条目。
2. 在本目录新增 `<backend_name>.md` 人类可读文档。
3. 如果该 backend 有独特的 API 词汇，在 profile 的 `extraction_vocab` 中登记。
4. 运行 `python3 .../validate_learned_patterns.py` 确认不破坏现有校验。

## 设计原则

- **方法论不变**：attempt loop、failure 分类、状态门禁、pattern 模板对所有 backend 通用。
- **验证参数化**：正确性/交付/性能的判定方式和字段名由 backend profile 定义。
- **知识库统一**：所有 backend 的经验沉淀到同一个 `learned-patterns/` 目录，按硬件机制分类
  （`dma/`、`rma/`、`ace/`、`simd/`、`ldm/`、`pipeline/`），不按 backend 分类。
- **SATE 与 rt 共存**：SATE 底层调用 rt，所以 SATE 算子的 ACE/DMA/RMA 经验和 rt 算子的
  经验进同一个目录，不分裂知识库。
