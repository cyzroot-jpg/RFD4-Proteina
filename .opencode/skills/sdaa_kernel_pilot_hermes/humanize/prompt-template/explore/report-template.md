# explore-idea 探索报告

**Run ID:** <RUN_ID>
**Base Branch:** <BASE_BRANCH>
**Base Commit:** <BASE_COMMIT>
**Created At:** <CREATED_AT>
**Explore Report:** <REPORT_PATH>
**Final Idea:** <FINAL_IDEA_PATH>

---

## 摘要

<SUMMARY_PARAGRAPH>

---

## 第一层：最佳产品方向

*按用户价值、战略契合度、原始方向质量、证据和已知风险排名。此排名反映原始创意方向的质量，而非原型实施的成功程度。*

| 排名 | 方向 | 置信度 | 关键证据 | 已知风险 |
|------|-----------|------------|--------------|-------------|
<PRODUCT_DIRECTION_RANKING_ROWS>

### 理由

<PRODUCT_DIRECTION_RATIONALE>

---

## 第二层：最具实施就绪度的原型

*按原型结果排名：任务状态、Codex 裁决、测试结果、提交状态和迭代次数。*

| 排名 | 方向 | 状态 | Codex | 测试 | 提交 | 迭代次数 |
|------|-----------|--------|-------|-------|---------|------------|
<IMPLEMENTATION_RANKING_ROWS>

### 理由

<IMPLEMENTATION_RANKING_RATIONALE>

---

## Worker 结果

<WORKER_RESULT_ENTRIES>

---

## 采纳路径

### 推荐：从最终创意生成计划

使用计划就绪的最终创意综合作为默认的产品化路径。这将探索运行视为研究，从干净的计划开始实施，并将 worker 原型状态设为可选。

```bash
/humanize:gen-plan --input <FINAL_IDEA_PATH> --output <plan-path>
/humanize:start-rlcr-loop <plan-path>
```

### 原型快速路径：继续获胜分支

仅当排名最高的原型明显值得保留，并且你希望 RLCR 审查或完成变异的 worker worktree 状态时使用：

```bash
# Navigate to the winner's worktree
cd <WINNER_WORKTREE_PATH>

# Branch: <WINNER_BRANCH_NAME>
# Commit: <WINNER_COMMIT_SHA>

# Start RLCR loop from the prototype state
/humanize:start-rlcr-loop --skip-impl
```

### Cherry-Pick 原型

从原型分支 cherry-pick 特定提交：

```bash
git cherry-pick <COMMIT_SHA>
# Verify the base branch matches before cherry-picking.
```

### 丢弃未采纳的原型

移除你未采纳方向的 worktree 和分支：

```bash
<CLEANUP_COMMANDS>
```

---

## 所有 Worker 详情

<ALL_WORKER_DETAILS>

---

## 清理参考

所有探索运行的产物存储在：

```
.humanize/explore/<RUN_ID>/
  manifest.json           — coordinator state and per-worker metadata
  dispatch-prompts/       — exact prompts sent to each worker
  worker-results.jsonl    — machine-readable result rows
  explore-report.md       — audit, ranking, adoption, and cleanup report
  final-idea.md           — plan-ready synthesis artifact for gen-plan
```

要移除此运行的所有本地探索产物：
```bash
# Remove worktrees
<ALL_WORKTREE_REMOVE_COMMANDS>

# Remove branches
<ALL_BRANCH_DELETE_COMMANDS>

# Remove run directory (optional, for cleanup)
# rm -rf ".humanize/explore/<RUN_ID>"
```
