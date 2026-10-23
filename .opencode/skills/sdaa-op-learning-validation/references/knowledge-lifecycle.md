# 知识生命周期

本 skill 把实验过程、可移植证据和长期规则分成三层。

## 过程层

位置：`<demo_root>/op_learning/<topic>/`。

保存 learning task、attempt、完整命令、失败日志和临时源码位置。它服务当前实验，可以包含本地路径，
但不能成为长期 pattern 的消费依赖。

## 证据层

位置：`references/evidence/pattern-evidence.json`。

保存 backend、硬件、版本、shape、正确性、流水线和同口径性能摘要。证据使用稳定 ID，外部来源使用
`backend://<backend>/<relative-path>`，禁止作者机器绝对路径。

## 知识层

位置：`references/learned-patterns/`。

只保留适用条件、规则、资源预算、fallback、伪代码、常见坑、验证范围和 evidence ID。使用者不应为了
理解或实现 pattern 而必须打开原始 `op_learning` 或原始源码。

## 晋级流程

```text
draft_from_source / human_reviewed
        只在过程层
              ↓ stage 验证 + evidence snapshot
verified_by_stage
              ↓ 两个独立实现上下文复用
promoted
              ↓ SDK/硬件/接口变化
needs_revalidation
              ↓ 被替代或被否定
superseded / deprecated
```

`verified_by_failed_stage` 只用于 `pitfalls/`。

## 删除与归档

- evidence snapshot 生成后，原始长日志可以归档。
- pattern 晋级为 `promoted` 后，可以删除原始源码路径和过程文档引用。
- 原始 `op_learning` 删除不影响 pattern 消费。
- 最小 evidence 被删除后，pattern 必须降级为 `needs_revalidation`。
- `superseded` 保留迁移目标；`deprecated` 保留失效原因，避免重复踩坑。
