# 共享知识库

跨 skill 复用的原始文档和通用模式放在这里，避免同一份 Markdown 在多个 `ops/<skill>/references/` 目录重复维护。

使用规则：

- 需要被多个 skill 消费的文档放在本目录。
- skill 的 `SKILL.md` 或 `references/*.md` 使用相对路径链接到本目录。
- 单个 skill 独有的蒸馏经验、检查表、脚本说明仍放在该 skill 自己的 `references/` 目录。
- 如果从外部源文档拷贝，记录来源路径和 hash。

当前共享文档：

| 文档 | 来源 | sha256 |
|------|------|--------|
| [SIMD使用手册-zh.md](SIMD使用手册-zh.md) | `/data/dnn/gupeng/swdnn_test_ops/docs/hardware/SIMD使用手册-zh.md` | `4a0ab0615d8eff8bdcc4a3d7d0619b91bbb750aeadcd87d6351fde81c2e10011` |
| [simd-dual-issue-pattern.md](simd-dual-issue-pattern.md) | 原 `sdaa-op-template` / `sdaa-op-design` 共享模板 | `744446d7427b4d25ec3b09a5d38691a98934c57af619697c5b62002726aad6d9` |
