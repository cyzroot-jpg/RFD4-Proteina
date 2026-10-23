# Humanize 使用指南

Humanize 插件的详细使用文档。安装说明请参阅 [Install for Claude Code](install-for-claude.md)。

## 工作原理

Humanize 创建一个包含两个阶段的迭代反馈循环：

1. **实现阶段**：Claude 按照你的计划进行开发，Codex 审查摘要直到 COMPLETE
2. **审查阶段**：`codex review --base <branch>` 使用 `[P0-9]` 严重性标记检查代码质量

该循环持续进行，直到所有验收标准都满足或没有遗留问题为止。

## 以终为始

在 RLCR 循环开始任何工作之前，Humanize 会运行一个**计划理解测验** -- 一个简短的预检，验证你是否真正理解了即将执行的计划。

### 为什么需要这个

在 AI 辅助开发中，代价最高的失败不是 bug，而是在一个你从未真正阅读过的计划上运行 40 轮 RLCR 循环。我们称之为**愿望式编码**：把生成的计划当作许愿池 -- 抛进去，然后祈祷好运，稍后再回来看。

问题在于结构层面。RLCR 循环是一个放大器：它会忠实地执行你给它的任何计划。如果计划是错误的，循环会更快、更大规模地把它变成错误的。如果计划是正确的但你不理解它，当 Codex 提出问题时你就无法纠正方向，循环就会偏离轨道。

在执行之前理解你的计划不是可有可无的开销。它是你能做的最高杠杆的事情，以确保循环成功。

### 测验如何工作

当你运行 `start-rlcr-loop` 时，一个独立的 agent 会分析计划并生成两道关于计划技术实现细节的选择题：

1. **哪些组件在变化以及如何变化？** -- 测试你是否了解核心机制。
2. **各个部分如何连接？** -- 测试你是否理解正在修改的架构。

如果你两道都答对了，循环会立即继续。如果你答错了一道或两道，Humanize 会解释计划的实际内容并提供选择：继续，或者停下来重新审视。

测验是建议性的，不是门槛。你始终可以选择继续。但那个摩擦的时刻 -- 读问题然后意识到你不知道答案的那两秒 -- 才是整个重点。

### 跳过测验

- `--skip-quiz` -- 仅跳过测验。RLCR 循环的其余部分正常运行。
- `--yolo` -- 跳过测验并且让 Claude 直接回答 Codex 的开放问题（`--claude-answer-codex`）。这是为已经审查过计划并希望完全移交控制权的用户提供的全自动模式。
- 通过 `gen-plan --auto-start-rlcr-if-converged` 启动的计划会自动跳过测验，因为 gen-plan 的收敛讨论已经验证了用户的理解。

## 典型规划流程

1. 生成初始实现计划：
   ```bash
   /humanize:gen-plan --input draft.md --output docs/plan.md
   ```
2. 如果计划带有注释批注，则进行精炼并生成 QA 账本：
   ```bash
   /humanize:refine-plan --input docs/plan.md
   ```
3. 在精炼后的计划上启动 RLCR 循环：
   ```bash
   /humanize:start-rlcr-loop docs/plan.md
   ```

## 命令

| 命令 | 用途 |
|---------|---------|
| `/gen-idea <idea-or-path>` | 生成基于仓库的创意草稿，包含 N 个并行方向 |
| `/explore-idea <draft-or-directions.json>` | 启动有限并行原型工作器并综合生成两层报告 |
| `/start-rlcr-loop <plan.md>` | 启动带有 Codex 审查的迭代开发 |
| `/cancel-rlcr-loop` | 取消活跃的循环 |
| `/gen-plan --input <draft.md> --output <plan.md>` | 从草稿生成结构化计划 |
| `/refine-plan --input <annotated-plan.md>` | 精炼带批注的计划并生成 QA 账本 |
| `/ask-codex [question]` | 与 Codex 的一次性咨询 |

## 命令参考

### gen-idea

```
/humanize:gen-idea <idea-text-or-path> [--n <int>] [--output <path>]
```

使用定向多样性探索生成基于仓库的创意草稿。一个主导 agent 选取 N 个正交方向，N 个并行 Explore 子 agent 使用仓库中的客观证据开发每个方向，然后主导 agent 综合生成一个包含一个主要方向和 N-1 个替代方案的草稿。

**输出：**
- 草稿文件：`.humanize/ideas/<slug>-<timestamp>.md`（或 `--output` 路径）
- 配套 JSON：`<draft-path-without-.md>.directions.json` -- 所有方向提案的无损记录，用作 `explore-idea` 的输入

**选项：**
- `--n <int>` -- 并行方向数量（默认：6）
- `--output <path>` -- 草稿的自定义输出路径（必须以 `.md` 结尾）

### explore-idea

```
/humanize:explore-idea <draft.md | draft.directions.json> [--directions ids] [--concurrency N] [--max-worker-iterations N] [--worker-timeout-min N] [--codex-timeout-min N]
```

启动有限并行原型工作器 -- 每个选定方向一个 -- 每个都在隔离的 git worktree 中运行。所有工作器完成后，综合生成探索报告和可直接用于规划的最终创意：
- **第 1 层**：最佳产品方向（按用户价值、证据、战略适配度排名）
- **第 2 层**最具实现准备度的原型（按结果排名：任务状态、Codex 判定、测试、提交）

**选项：**
- `--directions <ids>` -- 逗号分隔的 `direction_id` 或 `source_index` 值（默认：按显示顺序取前 6 个）
- `--concurrency <N>` -- 并行工作器数量（默认：6，最大：10）
- `--max-worker-iterations <N>` -- 每个工作器的迭代上限（默认：2，最大：3）
- `--worker-timeout-min <N>` -- 工作器超时时间，单位为分钟（默认：60，最大：60）
- `--codex-timeout-min <N>` -- Codex 调用超时时间，单位为分钟（默认：20，最大：20）

**运行产物**存储在 `.humanize/explore/<RUN_ID>/` 中：
- `manifest.json` -- 协调器状态和每个工作器的元数据
- `dispatch-prompts/` -- 发送给每个工作器的确切提示
- `worker-results.jsonl` -- 机器可读的结果行
- `explore-report.md` -- 包含两层排名、采用路径和清理指导的审计报告
- `final-idea.md` -- 可直接用于 `/humanize:gen-plan` 的综合产物

默认后续操作：
```bash
/humanize:gen-plan --input .humanize/explore/<run-id>/final-idea.md --output docs/plan.md
/humanize:start-rlcr-loop docs/plan.md
```

### start-rlcr-loop

```
/humanize:start-rlcr-loop [path/to/plan.md | --plan-file path/to/plan.md] [OPTIONS]

OPTIONS:
  --plan-file <path>     显式指定计划文件路径（替代位置参数）
  --max <N>              自动停止前的最大迭代次数（默认：84）
  --strict-success       超过最大迭代和停滞停止门槛后继续运行
  --codex-model <MODEL:EFFORT>
                         Codex 模型和推理力度（默认来自配置，回退 gpt-5.5:high）
  --codex-timeout <SECONDS>
                         每次 Codex 审查的超时时间，单位为秒（默认：5400）
  --track-plan-file      指示计划文件应被 git 跟踪（必须是干净的）
  --push-every-round     每轮结束后要求 git push（默认：提交保留在本地）
  --base-branch <BRANCH> 代码审查阶段的基础分支（默认：自动检测）
                         优先级：用户输入 > 远程默认 > main > master
  --full-review-round <N>
                         全面对齐检查轮次间隔（默认：5，最小：2）
                         全面对齐检查在第 N-1、2N-1、3N-1 等轮次执行
  --skip-impl            跳过实现阶段，直接进入代码审查
                         使用此标志时计划文件是可选的
  --claude-answer-codex  当 Codex 发现开放问题时，让 Claude 直接回答
                         而不是通过 AskUserQuestion 询问用户
  --agent-teams          启用 Claude Code Agent Teams 模式进行并行开发。
                         需要设置 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 环境变量。
                         Claude 作为团队领导，在团队成员之间分配任务。
  --yolo                 跳过计划理解测验并让 Claude 直接回答 Codex 开放
                         问题。等同于 --skip-quiz --claude-answer-codex。
  --skip-quiz            仅跳过计划理解测验（不改变其他行为）。
  -h, --help             显示帮助信息
```

### gen-plan

```
/humanize:gen-plan --input <path/to/draft.md> --output <path/to/plan.md> [OPTIONS]

OPTIONS:
  --input   输入草稿文件路径（必需）
  --output  输出计划文件路径（必需）
  --auto-start-rlcr-if-converged
             当计划收敛时自动启动 RLCR 循环
             （仅限讨论模式；在 --direct 模式下忽略）
  --discussion  使用讨论模式（迭代 Claude/Codex 收敛轮次）
  --direct      使用直接模式（跳过收敛轮次，立即生成计划）
  -h, --help    显示帮助信息
```

gen-plan 命令将粗略的草稿文档转换为结构化的实现计划。

工作流程：
1. 验证输入/输出路径
2. 检查草稿是否与仓库相关
3. 分析草稿的清晰度、一致性、完整性和功能性
4. 与用户交互解决发现的任何问题
5. 生成带有验收标准的结构化 plan.md
6. 如果满足 `--auto-start-rlcr-if-converged` 条件，可选启动 `/humanize:start-rlcr-loop`

如果审查者后来在生成的计划上添加了批注块，请在开始或恢复实现之前运行
`/humanize:refine-plan --input <plan.md>`。

### refine-plan

```
/humanize:refine-plan --input <path/to/annotated-plan.md> [OPTIONS]

OPTIONS:
  --input <path>        带批注的计划文件路径（必需）
  --output <path>       精炼计划输出文件路径
                        默认就地精炼 --input 指定的文件
  --qa-dir <path>       QA 文档输出目录
                        默认：.humanize/plan_qa
  --alt-language <LANG>
                        生成翻译后的计划和 QA 变体
                        支持的语言：zh, ko, ja, es, fr, de, pt, ru, ar
                        也接受完整的语言名称；en/English 无效
  --discussion          用于模糊注释分类的交互模式
  --direct              非交互模式；采用最小安全假设
  -h, --help            显示帮助信息
```

refine-plan 命令读取带批注的 `gen-plan` 文档，处理内嵌的审查注释，
从最终计划中移除这些注释块，并写入一个 QA 账本记录每条注释的处理方式。

**使用示例：**

```bash
# 就地精炼计划并将 QA 输出写入默认目录
/humanize:refine-plan --input docs/plan.md

# 将精炼后的计划写入新文件，并将 QA 输出存储在自定义目录中
/humanize:refine-plan --input docs/plan.annotated.md --output docs/plan.refined.md --qa-dir docs/plan-qa

# 以直接模式运行并生成翻译变体
/humanize:refine-plan --input docs/plan.md --direct --alt-language zh
```

**批注注释块格式：**

`refine-plan` 支持三种注释格式用于审查者批注。所有格式都支持内联和
多行注释块：

**经典格式（CMT:/ENDCMT）：**
```markdown
Text before CMT: clarify why AC-3 is split here ENDCMT text after
```

```markdown
CMT:
Please investigate whether this task should depend on task4 or task5.
If the dependency is unclear, add a pending decision instead of guessing.
ENDCMT
```

**短标签格式（<cmt></cmt>）：**
```markdown
Text before <cmt>clarify why AC-3 is split here</cmt> text after
```

```markdown
<cmt>
Please investigate whether this task should depend on task4 or task5.
If the dependency is unclear, add a pending decision instead of guessing.
</cmt>
```

**长标签格式（<comment></comment>）：**
```markdown
Text before <comment>clarify why AC-3 is split here</comment> text after
```

```markdown
<comment>
Please investigate whether this task should depend on task4 or task5.
If the dependency is unclear, add a pending decision instead of guessing.
</comment>
```

规则：
- 输入文件中必须存在至少一个非空注释块。
- 围栏代码块或 HTML 注释内的注释标记会被忽略。
- 空注释块会被移除但不会创建 QA 账本条目。
- 输入计划仍须遵循 `gen-plan` 的章节结构。
- 三种格式可以在同一文件中混合使用。

**QA 输出结构：**

对于名为 `plan.md` 的输入计划，默认 QA 输出路径为 `.humanize/plan_qa/plan-qa.md`。
生成的 QA 文档包括：

- `## Summary`：整体精炼结果和注释计数
- `## Comment Ledger`：每个原始 `CMT-N` 块的一行记录，包含分类、位置、摘录和处置方式
- `## Answers`：对问题类注释的回复以及任何澄清性编辑
- `## Research Findings`：为 `research_request` 类注释执行的仓库调研
- `## Plan Changes Applied`：为 `change_request` 类注释所做的更改和交叉引用更新
- `## Remaining Decisions`：仍需用户输入的未解决事项或依赖假设的决策
- `## Refinement Metadata`：输入/输出路径、QA 路径、分类计数、修改的章节、收敛状态和日期

账本中的处置值为 `answered`、`applied`、`researched`、`deferred` 或
`resolved`。

如果 `--alt-language` 设置为支持的非英语语言，该命令还会通过在文件扩展名前插入 `_<code>` 来生成
翻译后的计划和 QA 变体，例如 `plan_zh.md` 和 `plan-qa_zh.md`。

### ask-codex

```
/humanize:ask-codex [OPTIONS] <question or task>

OPTIONS:
  --codex-model <MODEL:EFFORT>
                         Codex 模型和推理力度（默认来自配置，回退 gpt-5.5:high）
  --codex-timeout <SECONDS>
                         Codex 查询的超时时间，单位为秒（默认：3600）
  -h, --help             显示帮助信息
```

ask-codex 技能向 Codex 发送一次性问题或任务并内联返回响应。
与 RLCR 循环不同，这是没有迭代的单次咨询 -- 适用于
获取第二意见、审查设计或询问领域特定问题。

响应保存在 `.humanize/skill/<timestamp>/` 中，包含 `input.md`、`output.md`
和 `metadata.md` 以供参考。

## 配置

Humanize 使用 4 层配置层级（优先级从低到高）：
1. **插件默认值**：`config/default_config.json`
2. **用户配置**：`~/.config/humanize/config.json`
3. **项目配置**：`.humanize/config.json`
4. **CLI 标志**：命令行参数（如可用）

当前内置键：

| 键 | 默认值 | 说明 |
|-----|---------|-------------|
| `codex_model` | `gpt-5.5` | Codex 支持的审查和分析的共享默认模型 |
| `codex_effort` | `high` | 共享默认推理力度（`xhigh`、`high`、`medium`、`low`） |
| `bitlesson_model` | `haiku` | BitLesson 选择器 agent 使用的模型 |
| `provider_mode` | 未设置 | 可选的运行时模式提示，例如 `codex-only` |
| `agent_teams` | `false` | agent teams 工作流的项目级默认值 |
| `alternative_plan_language` | `""` | 可选的翻译计划变体语言；支持的值包括 `Chinese`、`Korean`、`Japanese`、`Spanish`、`French`、`German`、`Portuguese`、`Russian`、`Arabic` 或 ISO 代码如 `zh` |
| `gen_plan_mode` | `discussion` | 默认计划生成模式 |

### Codex 模型配置

所有使用 Codex 的功能（RLCR 循环、ask-codex）共享相同的模型配置：

| 键 | 默认值 | 说明 |
|-----|---------|-------------|
| `codex_model` | `gpt-5.5` | 用于 Codex 操作（审查、分析、查询）的模型 |
| `codex_effort` | `high` | 推理力度（`xhigh`、`high`、`medium`、`low`） |

要覆盖，请添加到 `.humanize/config.json`：

```json
{
  "codex_model": "gpt-5.2",
  "codex_effort": "xhigh",
  "bitlesson_model": "sonnet"
}
```

在 Codex 安装上，Humanize 还会在这些键未设置时，将 `${XDG_CONFIG_HOME:-~/.config}/humanize/config.json` 中的
`bitlesson_model` 和 `provider_mode: "codex-only"` 预设为 Codex/OpenAI 路径，以便 BitLesson 选择
保持在 Codex/OpenAI 路径上，无需探测 Claude。

Codex 模型按以下优先级解析：
1. CLI `--codex-model` 标志（最高优先级）
2. 功能特定默认值
3. 来自上述 4 层层级的配置默认值
4. 硬编码回退值（`gpt-5.5:high`）

**迁移说明**：如果你的 `.humanize/config.json` 包含旧版键
`loop_reviewer_model` 或 `loop_reviewer_effort`，它们会被静默忽略。
请使用 `codex_model` 和 `codex_effort` 替代。


## 监控

设置监控助手以进行实时进度跟踪：

```bash
# 添加到你的 .bashrc 或 .zshrc
source ~/.claude/plugins/cache/PolyArch/humanize/<LATEST.VERSION>/scripts/humanize.sh

# 终端监控器（每个终端一个项目）：
humanize monitor rlcr        # 最新的 RLCR 循环日志
humanize monitor skill       # 所有技能调用（codex + gemini）
humanize monitor codex       # 仅 ask-codex 技能调用
humanize monitor gemini      # 仅 ask-gemini 技能调用

# 浏览器仪表盘（同时查看多个循环，默认前台运行）：
humanize monitor web --project /path/to/project
```

进度数据存储在 `.humanize/rlcr/<timestamp>/` 中，每个循环会话一个目录。

### 浏览器仪表盘（`humanize monitor web`）

Web 仪表盘构建在终端监控器读取的相同 `.humanize/rlcr/<session>/`
元数据和 `~/.cache/humanize/<sanitized-project>/<session>/round-*-codex-{run,review}.log`
缓存日志之上。没有并行捕获管道；仪表盘是读取器，不是写入器。

生命周期（依据 DEC-1、DEC-3）：

- 默认前台运行（`humanize monitor web --project <path>`）。按
  Ctrl+C 停止。服务器在启动时由 CLI 固定到一个项目；
  要同时监控多个项目，请使用不同的 `--port` 值运行多个实例
  （每个项目一个）。
- `--daemon` 在每个项目的 tmux 会话（`humanize-viz-<8-hex>`）中运行相同的服务器；
  使用 `viz-stop.sh --project <path>` 或项目的 tmux kill 命令来停止它。

每个活跃会话的内联实时日志窗格会出现在主页上，由
`/api/sessions/<session_id>/logs/<basename>` 的 Server-Sent Events 驱动。多个循环
并行流式传输，无需离开主页。

### 远程浏览器访问

仪表盘默认绑定到 `127.0.0.1`。要通过网络暴露它，请提供 `--host` 和认证令牌。对于任何非回环地址，令牌是必需的；否则服务器拒绝启动。

支持令牌的端点对普通 fetch 请求使用 `Authorization: Bearer <tok>`，对 SSE 流使用 `?token=<tok>` 查询参数
（依据 DEC-4：浏览器无法在 EventSource 上设置任意请求头）。
远程模式下完全拒绝 WebSocket 传输。

#### 方式 1（推荐）：SSH 隧道

最安全的远程方式是将服务器绑定到 localhost 并通过 SSH 转发端口：

```bash
# 在服务器机器上：
humanize monitor web --project /path/to/project --port 18000

# 在你的笔记本上：
ssh -N -L 18000:localhost:18000 user@server.example.com
# 然后在本地浏览器中打开 http://localhost:18000。
```

无需令牌，因为服务器仍然绑定到回环地址。SSH 隧道提供认证和加密。

#### 方式 2：直接局域网绑定

对于 SSH 隧道不可行的可信网络部署：

```bash
# 生成强随机令牌（一次性）：
TOKEN="$(openssl rand -hex 32)"

# 启动仪表盘：
humanize monitor web \
    --project /path/to/project \
    --host 0.0.0.0 \
    --port 18000 \
    --auth-token "$TOKEN"

# 或者通过环境变量提供令牌，而不是 CLI：
HUMANIZE_VIZ_TOKEN="$TOKEN" humanize monitor web \
    --project /path/to/project --host 0.0.0.0 --port 18000
```

使用 `http://server:18000/?token=<TOKEN>` 打开仪表盘；
浏览器会将令牌缓存到 `sessionStorage` 中，并在后续 fetch 和 SSE 重连时自动传播。

## 取消

- **RLCR 循环**：`/humanize:cancel-rlcr-loop`

## 环境变量

### HUMANIZE_CODEX_BYPASS_SANDBOX

**警告：这是一个禁用安全保护的危险选项。仅在你理解其影响的情况下使用。**

- **用途**：控制 Codex 是否在沙箱保护下运行
- **默认值**：未设置（使用带沙箱保护的 `--full-auto`）
- **值**：
  - `true` 或 `1`：绕过 Codex 沙箱和审批（使用 `--dangerously-bypass-approvals-and-sandbox`）
  - 任何其他值或未设置：使用带沙箱的安全模式

**何时使用**：
- 没有 landlock 内核支持的 Linux 服务器（Codex 沙箱会失败的情况）
- 可信环境中的自动化 CI/CD 流水线
- 你拥有完全控制权的开发环境

**何时不应使用**：
- 公共或共享开发服务器
- 审查不受信任的代码或拉取请求时
- 生产系统
- 任何未经授权的系统访问可能造成损害的环境

**安全影响**：
- Codex 将拥有对你文件系统的不受限制的访问权限
- Codex 可以在没有审批提示的情况下执行任意命令
- 使用此模式时请仔细审查所有代码更改

**使用示例**：
```bash
# 在启动 Claude Code 之前导出
export HUMANIZE_CODEX_BYPASS_SANDBOX=true

# 或为单个会话设置
HUMANIZE_CODEX_BYPASS_SANDBOX=true claude --plugin-dir /path/to/humanize
```
