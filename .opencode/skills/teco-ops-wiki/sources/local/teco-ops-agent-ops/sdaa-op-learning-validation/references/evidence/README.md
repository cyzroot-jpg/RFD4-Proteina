---
id: source-teco-ops-agent-ops-sdaa-op-learning-validation-references-evidence-readme-77cb64d8
title: "teco-ops-agent ops: sdaa-op-learning-validation/references/evidence/README.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-op-learning-validation
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-op-learning-validation/references/evidence/README.md
relative_source_path: sdaa-op-learning-validation/references/evidence/README.md
captured_at: 2026-08-04
---

# 可移植验证证据

长期 pattern 不直接依赖 `<demo_root>/op_learning/`。完成 stage 后，把可复用的最小验证事实快照写入
`pattern-evidence.json`，pattern 只引用 evidence ID。

Evidence snapshot 保留：

- backend、硬件、SDK/源码版本（可获取时）。
- stage、目标 op、验证 shape。
- 正确性与交付/流水线结果。
- 性能指标、单位、before/after 和复测摘要。
- 原始 stage 的逻辑来源；外部仓库使用 `backend://<name>/<relative-path>`。

Evidence snapshot 不保留：

- `/data/...`、`/home/...` 等作者机器路径。
- 大段运行日志和临时命令。
- 必须打开原始源码才能理解的结论。

原始 `op_learning` 可按项目策略归档或删除；只要 pattern 仍声明 `verified_by_stage/promoted`，对应最小
evidence snapshot 就必须保留。

从规范化 stage result 生成快照：

```bash
python3 ops/sdaa-op-learning-validation/scripts/snapshot_pattern_evidence.py \
  --stage-result <demo_root>/op_learning/<topic>/stage_results/<stage>.json \
  --evidence-id <portable-id> \
  --source-stage backend://<backend>/op_learning/<topic>/stage_results/<stage>.json
```
