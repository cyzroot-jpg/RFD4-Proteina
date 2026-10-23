# TECO Ops Agent

面向 **SDAA / TECO T1** 的算子开发 Agent 工程。仓库把环境检查、架构/API 知识、性能最佳实践、算子需求采集、设计、脚手架、精度验收、性能测试和仓库功能变更记录封装成 `ops/` 下的一组 skills，供 Codex / Cursor / Claude Code 使用。

## 快速入口

```bash
chmod +x init.sh
./init.sh project codex      # 或 cursor / claude
test -d ../../teco-ops
python3 run_cli.py llm-plan
```

完整安装、MCP、Claude Code、Cursor 配置见：

- [快速开始](docs/项目文档/快速开始.md)

## 主流程

新算子开发按强制链路执行：

```text
环境检查
  -> 性能最佳实践入口 / learned-patterns 检索
  -> 需求采集 requirement.json
  -> 算子设计 design.json / design.md
  -> 在 teco-ops interface + UAL 布局中实现 kernel
  -> teco-ops C++ 测试框架精度验收
  -> teco-ops C++ 测试框架性能测试
```

涉及 skills：`sdaa-performance-best-practices`（性能入口与路由）。

关键约束写在 [AGENTS.md](AGENTS.md)。Claude Code 读取 [CLAUDE.md](CLAUDE.md)，该文件是指向 `AGENTS.md` 的软链接。

## 常用命令

| 命令 | 说明 |
|------|------|
| `python3 run_cli.py llm-plan` | 打印解析后的 provider / model / base_url |
| `python3 run_cli.py agent-ask "<prompt>"` | 先执行 skills，再调 LLM |
| `python3 run_cli.py agent-ask "<prompt>" --verbose` | 打印 skill 执行步骤 |
| `python3 run_cli.py llm-chat "<prompt>"` | 裸 API 调用，不执行 skills |
| `python3 ops/sdaa-docs-search/scripts/build_index.py` | 构建本地文档索引 |
| `python3 ops/sdaa-docs-search/scripts/search_docs.py --query "rt_dma_get" --json` | 检索本地 API / 知识库 |
| `python3 ops/kernel-bench/scripts/teco_ops_test.py --op <op> --demo-root ../../teco-ops --json` | 使用 teco-ops 测试框架验证正确性和性能 |

## 仓库结构

```text
teco-ops-agent/
  AGENTS.md                         # Codex / Cursor 主指令
  CLAUDE.md                         # 指向 AGENTS.md，供 Claude Code 读取
  .codex/config.toml                # 项目级 Codex hooks
  configs/                          # LLM / MCP / Claude settings 示例配置
  docs/
    项目文档/快速开始.md
    项目文档/TECO Ops Agent项目现状总览.md
    项目文档/teco-ops-agent介绍.md
    共享知识库/                    # 跨 skill 复用的公共 Markdown
    code-style.md
  ops/                              # Skills
  ../../teco-ops/                      # 默认算子工作树（外部 sibling 仓库）
  teco_ops_agent/                   # Python LLM 运行时
```

## 文档分工

| 文档 | 用途 |
|------|------|
| [快速开始](docs/项目文档/快速开始.md) | 安装、配置、验证，覆盖 Codex / Cursor / Claude Code |
| [项目现状总览](docs/项目文档/TECO%20Ops%20Agent项目现状总览.md) | 模块职责、skill 流转、样例、当前状态 |
| [teco-ops-agent 介绍](docs/项目文档/teco-ops-agent介绍.md) | 面向组内分享的高层介绍 |
| [代码规范](docs/code-style.md) | 生成或修改 `.swcu` / `.h` / `.hpp` / `.cpp` 前必须阅读 |
| [共享知识库](docs/共享知识库/README.md) | 多个 skill 共同引用的技术原文 |

## Codex Hooks

项目级 [.codex/config.toml](.codex/config.toml) 启用 `UserPromptSubmit` hook。用户请求新算子或 kernel 优化时，会自动提示读取：

- `ops/sdaa-performance-best-practices/SKILL.md`
- `ops/sdaa-op-learning-validation/references/learned-patterns/`
- `docs/code-style.md`

首次用 Codex 打开仓库时，如果界面提示 `Hooks need review`，需要确认允许执行本仓库 `.codex/config.toml` 中声明的 hook 命令；确认后 hook 才会运行。

## Skills 分层与关系总览

整个项目的 skills 分为围绕「新算子开发主流程」组织：

```text
                        ┌─────────────────────┐
                        │   sdaa-env-check    │  ← Step 0: 环境门禁
                        └─────────┬───────────┘
                                  │ 必须通过
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        主流程 (强制顺序)                              │
│                                                                     │
│  sdaa-op-requirement ──→ sdaa-op-design ──→ sdaa-op-template       │
│   (Step 2.5 需求采集)     (Step 3 设计)      (Step 4 teco-ops 落地) │
│                              │                    │                 │
│                              │                    └─ teco_ops_test  │
└──────────────────────────────┼──────────────────────────────────────┘
                               │ 设计前必须消费
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   sdaa-performance-best-practices                   │
│                   (性能优化知识路由总入口)                             │
│                                                                     │
│   路由到 ↓                                                          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ learned-patterns/                                             │   │
│  │ (gemm/attention/simd/dma/pipeline/pitfalls/...)               │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│              sdaa-op-learning-validation (学习验证)                   │
│                                                                     │
│  - 从已有算子抽取 pattern → 写入 learned-patterns/                   │
│  - 被 performance-best-practices 和 op-design 消费                   │
└─────────────────────────────────────────────────────────────────────┘

辅助 skills:
  - sdaa-docs-search: API 文档检索（贯穿全流程，仅查 API/手册）
  - kernel-bench: 精度通过后测 kernel 耗时
  - record-repo-change: 仓库自身 bug/功能修复记录（元技能）
  - gemm-performance-modeling: op-design 的子 skill（GEMM 理论建模）
```

### 按关系类型拆解

**主流程链（强制顺序依赖）**

- `sdaa-env-check` → 所有流程的前置门禁
- `sdaa-op-requirement` → `sdaa-op-design`（产出 `requirement.json` 供 `init_design.py --from-requirement` 消费）
- `sdaa-op-design` → `sdaa-op-template`（产出 `design.json` 指导 teco-ops interface + UAL 落地）
- `sdaa-op-template` → `kernel-bench`（teco-ops 正确性通过后才能测耗时）

**知识供给关系（设计/实现前必须消费）**

- `sdaa-performance-best-practices` 是路由中枢，按问题类型分发到：
  - `sdaa-op-design`（设计建模）
  - `learned-patterns/`（已验证的机制和领域经验）
- `sdaa-op-design` 强制在设计前读取 `sdaa-performance-best-practices` 并消费 `learned-patterns/`
- `sdaa-op-template` 在 kernel 实现前同样需要读取性能最佳实践

**经验沉淀闭环**

- `sdaa-op-learning-validation` 从已有算子抽取 pattern → 写入 `learned-patterns/`
- `sdaa-performance-best-practices` 和 `sdaa-op-design` 在设计/优化时消费这些 pattern
- 形成 **学习 → 沉淀 → 消费** 的闭环

**元技能**

- `sdaa-docs-search`：纯检索工具，贯穿全流程，但**禁止**用于搜索可交付算子
- `record-repo-change`：记录仓库自身的 bug 修复和功能支持，与算子开发流程正交
- `gemm-performance-modeling`：`sdaa-op-design` 的子 skill，专门做 GEMM 理论性能建模
