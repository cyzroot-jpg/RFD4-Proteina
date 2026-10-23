# <TITLE>

## 运行上下文

- Run ID: <RUN_ID>
- Directions JSON: <DIRECTIONS_JSON_FILE>
- Explore Report: <REPORT_PATH>
- Final Idea: <FINAL_IDEA_PATH>

## 最终建议

<FINAL_RECOMMENDATION>

## 理由

<RATIONALE>

## 方法摘要

<APPROACH_SUMMARY>

## 客观证据

<OBJECTIVE_EVIDENCE>

## 探索结果

<EXPLORE_OUTCOMES>

## 约束条件

<CONSTRAINTS>

## 已知风险

<KNOWN_RISKS>

## 跨方向经验

<CROSS_DIRECTION_LEARNINGS>

## 建议的产品化流程

```bash
/humanize:gen-plan --input <FINAL_IDEA_PATH> --output <plan-path>
/humanize:start-rlcr-loop <plan-path>
```
