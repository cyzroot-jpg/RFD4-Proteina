# 优化 viz-dashboard：合并到 `humanize monitor` 作为 Web 视图

## 目标描述

优化 `feat/viz-dashboard` 分支，使 RLCR 可视化成为叠加在现有 `humanize monitor` 数据源之上的 Web 视图，支持多个并发实时 RLCR 循环并提供实时流式日志输出，将入口从 Claude 中移出（不再使用 `/humanize:viz` 斜杠命令）进入新的 `humanize monitor web` CLI 子命令，通过显式的网络绑定和认证控制将仪表板暴露给在线（浏览器）访问，并保留跨会话历史浏览功能。

仪表板必须消费 `humanize monitor rlcr|skill|codex|gemini` 已读取的相同文件和事件；它不得引入并行采集管线（不得仅为仪表板添加新的钩子）。单服务器单项目模型替代现有的服务器全局项目切换器，以消除跨客户端状态变更的缺陷。远程访问默认为安全模式（仅 localhost），需要显式令牌才能将数据或操作暴露到网络。

## 验收标准

遵循 TDD 理念，每项标准都包含正向和反向测试以进行确定性验证。

- AC-1：CLI 入口从 Claude 命令迁移到 `humanize monitor web`。
  - 正向测试（预期通过）：
    - `humanize monitor web --project <p>` 启动仪表板服务器并打印绑定的 URL。
    - `humanize monitor rlcr`、`humanize monitor skill`、`humanize monitor codex`、`humanize monitor gemini` 的行为与此次变更前完全一致（通过用法文本和退出行为的快照测试验证）。
    - `humanize monitor`（无子命令）打印包含 `web` 以及 `rlcr|skill|codex|gemini` 的用法信息。
  - 反向测试（预期失败/被拒绝）：
    - Claude 斜杠命令 `/humanize:viz` 不再注册（`commands/viz.md` 已移除）；尝试通过 Claude 调用该命令无法解析。
    - `humanize monitor unknownsub` 以非零退出码退出并显示用法信息；它不会静默回退到默认行为。

- AC-2：数据源复用 —— 无并行采集管线。
  - 正向测试：
    - 在活跃 RLCR 循环运行时，`viz/server/parser.py` 从 `.humanize/rlcr/<session>/{state.md,goal-tracker.md,round-*-summary.md,round-*-review-result.md}` 读取会话元数据，并从 `~/.cache/humanize/<sanitized-project>/<session>/round-*-codex-{run,review}.log` 读取流式字节数据。
    - 拦截文件打开操作的测试显示仪表板从与 RLCR 监控器相同的路径读取数据（与 `scripts/humanize.sh` 缓存查找逻辑（第 284-368 行附近）进行一致性测试）。
  - 反向测试：
    - 对 `hooks/` 进行 grep 搜索，未发现新增的 `*-viz-*.sh` 或仅服务于仪表板的钩子脚本。
    - 对 `viz/` 进行 grep 搜索，未发现写入 `.humanize/rlcr/` 的路径（仪表板是会话状态的读取者，而非写入者）。

- AC-3：多循环并发视图枚举所有会话，而非仅最新的。
  - 正向测试：
    - 当同一项目中有两个并发活跃的 RLCR 循环时，主页同时渲染两个会话卡片，每个卡片显示会话 ID、状态、当前轮次/最大轮次、当前阶段以及独立更新的实时日志面板。
    - 会话枚举覆盖 `.humanize/rlcr/` 下的所有目录，分为"活跃"（存在 state.md）和"历史"（存在终端 `*-state.md`）两类。
  - 反向测试：
    - 仪表板不会自动切换到最新会话（`scripts/lib/monitor-common.sh` 中 `monitor_find_latest_session` 的单会话行为不得泄露到 Web 视图中）。
    - 在另一个会话运行时添加新的活跃会话，不会在 UI 中移除或隐藏现有会话。

- AC-4：实时日志延迟预算 —— 追加内容在 2 秒内在浏览器中可见（硬性要求）。
  - 正向测试：
    - 自动化测试向活跃的 `round-*-codex-run.log` 追加 N 字节；浏览器端流客户端在 2 秒内接收到这些字节（在测试框架上进行端到端测量）。
    - 流式协议先发送初始快照，然后发送字节偏移追加事件（快照 + 偏移量尾随）。
    - 底层日志的截断/轮转触发文档化的重新同步路径（例如检测到文件大小缩小，从偏移量 0 的快照重新开始）。
  - 反向测试：
    - 活跃日志路径不得使用在每次更新时重新获取完整文件内容的轮询循环。
    - 在正常负载下测量的追加到渲染的中位延迟不得超过 2.0 秒；此断言失败将导致 CI 失败。

- AC-5：跨会话/历史浏览已保留。
  - 正向测试：
    - 存储在 `.humanize/rlcr/` 中的先前 Claude 会话的已完成会话列在"历史"部分，并可单独浏览。
    - 结束活跃循环会将该会话卡片从"活跃"转换为"历史"，而不会将其从视图中移除。
  - 反向测试：
    - 已完成的会话在其终端 `*-state.md` 出现后不会从仪表板中消失。
    - 在活跃视图和历史视图之间切换不会清空另一个列表。

- AC-6：远程可达 + 所有数据接口的访问控制。
  - 正向测试：
    - 使用默认标志时，服务器仅绑定到 `127.0.0.1`。
    - 使用 `--host 0.0.0.0`（或任何非 localhost 主机）时，启动需要非空的 `--auth-token`（或等效的环境变量）；否则进程以非零退出码退出并显示明确错误。
    - 在远程模式下，每个端点（会话列表、会话详情、每会话日志 SSE 流、控制端点）都需要有效令牌；缺失/无效的令牌返回 401。
  - 反向测试：
    - 使用 `--host 0.0.0.0` 且不提供令牌启动服务器不会启动；它会报错退出。
    - 对 `/api/sessions/<id>` 或每会话 SSE 流的未认证远程请求被拒绝并返回 401，而非提供服务。
    - 在 `humanize monitor web` 的任何路径下，服务器默认不绑定到 `0.0.0.0`。

- AC-7：会话定向取消已构建并测试（依据 DEC-2 = 构建会话范围取消）。
  - 正向测试：
    - 一个新的会话范围取消 shell 辅助脚本（位于 `scripts/cancel-rlcr-loop.sh` 旁）接受会话 ID 并仅取消该会话。
    - 仪表板取消 UI 调用每会话 API；取消会话 A 不影响会话 B。
  - 反向测试：
    - 调用每会话取消端点时未指定会话 ID 返回 400，而非执行项目范围的取消。
    - 仪表板不会在没有会话 ID 的情况下直接调用现有的项目全局 `scripts/cancel-rlcr-loop.sh`。

- AC-8：多实例/项目隔离清理（依据 DEC-3 = CLI 固定单项目）。
  - 正向测试：
    - `viz/scripts/viz-start.sh`（或其替代方案）使用每项目的 tmux 会话名称，因此启动第二个项目的仪表板不会终止第一个。
    - 每项目端口文件 `.humanize/viz.port` 也是按项目隔离的，不会冲突。
    - 服务器绑定到启动时通过 `--project` 选择的单个项目；没有运行时项目切换端点。
  - 反向测试：
    - `viz/server/app.py` 不再暴露 `/api/projects/switch`（或返回 410/501 并附带弃用消息）。
    - `viz/static/js/app.js` 和 `viz/static/js/actions.js` 不再渲染或连接项目切换器 / "+ Add" UI；测试对这些处理程序进行 grep 并断言其已被移除。
    - 在 `--project B` 实例已运行时启动 `humanize monitor web --project A` 不会终止 project-B 的服务器。

- AC-9：测试覆盖矩阵。
  - 正向测试（测试套件必须包含并通过）：
    - 两个并发活跃的 RLCR 会话独立渲染和流式传输。
    - 具有 `.humanize/rlcr/<session>` 元数据但尚无缓存日志（启动竞争）的会话渲染时不崩溃，并在日志出现后恢复。
    - 缓存日志截断/轮转触发文档化的重新同步，而非静默停滞。
    - 远程模式认证强制：缺失/无效令牌在每个数据和控制端点返回 401。
    - 项目隔离：启动第二个 `humanize monitor web --project <other>` 不影响第一个。
    - 向后兼容：`humanize monitor rlcr|skill|codex|gemini` 的输出不变（快照测试）。
    - 缓存路径/会话映射与 `scripts/humanize.sh`（第 284-368 行附近的真相来源）的一致性测试。
  - 反向测试：
    - 测试不会写入用户真实的 `~/.humanize` 或 `~/.cache/humanize`；所有 fixture 位于 tmp 目录或仓库的 `tests/` fixture 树下。
    - 没有测试依赖对公共互联网的网络访问。

- AC-10：代码风格合规。
  - 正向测试：
    - 对 `viz/`、`scripts/` 以及变更的 `commands/`/`hooks/` 文件进行 grep 搜索，查找字面子串 `AC-`、`Milestone`、`Step `、`Phase `（带尾部空格），在实现代码或注释中返回零匹配（计划/文档文件中的匹配不计）。
  - 反向测试：
    - 添加包含任何这些工作流标记的新代码会导致风格检查失败。

## 路径边界

路径边界定义了实现质量和选择的可接受范围。

### 上界（最大可接受范围）

实现提供：
- 一个 RLCR 专用的 Python 辅助模块（例如 `viz/server/rlcr_sources.py`），负责会话枚举和缓存日志路径发现，并与 `scripts/humanize.sh`（第 284-368 行附近）进行一致性测试。
- 一份冻结的单页事件协议契约文档（T2 架构审查的输出），固定了快照+字节偏移语义、截断/轮转处理以及每会话 vs 项目通道范围。
- 通过 HTTP(S) 的每会话 SSE 流，每个流携带初始快照，后跟由文件路径 + 字节偏移标识的追加事件。
- 通过查询参数在 SSE 流上和通过 `Authorization` 头在标准 HTTP 端点上进行 Bearer 令牌认证；flask_sock WebSocket 仅保留用于 localhost 绑定部署。
- 会话定向取消：一个新的 `scripts/cancel-rlcr-session.sh`（或等效命名）辅助脚本加上每会话 API 端点，经过完整测试。
- 多循环 UI 网格始终同时显示每个活跃会话，带有内联展开详情的每会话日志面板（无需整页导航即可查看实时日志）。
- 每服务器单项目的 CLI 模型：`humanize monitor web --project <path>`。`/api/projects/switch` 端点以及 `viz/static/js/app.js` 和 `viz/static/js/actions.js` 中的 `+ Add` / Switch UI 元素已完全移除。
- 每项目的 tmux 会话命名和每项目端口文件用于可选的 `--daemon` 模式（依据 DEC-1）。
- 两种远程部署模式的文档（SSH 隧道示例在前，局域网绑定示例在后），加上说明 `/humanize:viz` 移除的升级说明。
- 按 AC-9 的完整测试矩阵。

### 下界（最小可接受范围）

实现提供：
- 对现有 `viz/server/parser.py` 和 `viz/server/watcher.py` 的扩展，使其额外摄取缓存轮次日志（`codex-run.log`、`codex-review.log`、gemini 变体（如存在））并发出带字节偏移的追加事件。
- 在 `viz/server/app.py` 中新增的每会话 SSE 端点，支持 T2 契约文档中约定的快照+偏移协议，包括文档化的截断重新同步路径。
- 在 `scripts/humanize.sh` 中新增的 `humanize monitor web` 分发条目（与 `rlcr|skill|codex|gemini` 并列），默认在前台运行仪表板；可选的 `--daemon` 标志使用每项目 tmux 名称和端口文件启动现有的 tmux 托管服务器。
- `viz/server/app.py` 中的 `--host`、`--port`、`--auth-token` 标志（并由 `humanize monitor web` 转发）；服务器默认绑定到 `127.0.0.1`；非 localhost 绑定需要非空令牌；未认证的远程请求在每个数据和控制端点上都被拒绝，而不仅仅是变更操作。
- 移除服务器全局项目切换：`/api/projects/switch` 以及 `viz/static/js/app.js` 和 `viz/static/js/actions.js` 中的 `+ Add` / Switch UI 流程被移除。`viz-projects.json` 在 v1 中不再被服务器修改。
- 移除 `/humanize:viz`：`commands/viz.md` 和 `skills/humanize-viz/SKILL.md` 被删除；在 `README.md`（或等效文件）中添加简短的升级说明，引导用户使用 `humanize monitor web`。
- 会话定向取消辅助脚本和每会话取消 API（依据 DEC-2 = 构建会话范围取消）。
- AC-9 中的所有测试均已存在并在 CI 中通过。
- 文档：至少包含 SSH 隧道部署模式。

### 允许的选择

- 可以使用：
  - 现有的 Flask + flask_sock 技术栈（保留用于 localhost）加上用于每会话日志流的新 SSE 端点。
  - 复用或从 `scripts/humanize.sh` 提取辅助逻辑用于 RLCR 专用的缓存路径发现（仅限 RLCR —— 不要合并 skill-monitor 缓存规则）。
  - 每会话字节偏移、文件路径键控的事件流。
  - `python -m venv`（当前 `viz-start.sh` 模型）或系统 python 用于前台 CLI 调用。
  - 令牌来源：CLI 标志 `--auth-token <value>`、环境变量 `HUMANIZE_VIZ_TOKEN` 或位于 `${XDG_CONFIG_HOME:-$HOME/.config}/humanize/viz-token` 的令牌文件。
- 不可以使用：
  - 仅为捕获仪表板数据而添加的新 Claude 钩子。
  - 默认网络绑定到 `0.0.0.0`（必须是可选加入）。
  - v1 中的 OAuth / OIDC / 外部 IAM 提供者。
  - 将 RLCR 会话模型与 skill 调用模型混为一谈的跨语言共享 "monitor-core" 库。
  - WebSocket 作为日志流的远程模式传输（浏览器 WS 无法设置 `Authorization` 头；远程流必须按 DEC-4 使用 SSE）。flask_sock WS 可保留用于 localhost 绑定使用。
  - 将项目全局取消路径连接到每会话 UI 而不向用户发出明确警告（依据 DEC-2，仪表板必须使用会话范围的取消辅助脚本）。

> **关于确定性设计的说明**：DEC-1、DEC-2、DEC-3 和 DEC-4 已由用户决策确定（记录在 `## 待决用户决策` 下）。上述路径边界已经反映了这些选择，对这四个要点不留替代解释的空间。

## 可行性提示与建议

> **说明**：本节仅供参考和理解。这些是概念性建议，而非规范性要求。

### 概念方法

一条可行的路径：

1. 分支清理作为并行预检轨道。将 `feat/viz-dashboard` 变基到 `upstream/dev`（当前领先 9 个提交）。冲突预计较小，因为分支已包含上游提交 338b4dd（PR 循环移除）和 016caca（监控拆分）。
2. 添加一个小型的 RLCR 专用 Python 模块（例如 `viz/server/rlcr_sources.py`），负责：
   - 列出 `.humanize/rlcr/<project>/` 下的所有会话目录，
   - 将每个会话映射到其在 `~/.cache/humanize/<sanitized-project>/<session>/` 下的缓存日志目录，
   - 返回每会话的实时日志文件路径（`round-N-codex-run.log`、`round-N-codex-review.log`、gemini 变体）。
   用一致性测试覆盖该模块，将其输出与 `scripts/humanize.sh`（第 284-368 行附近）中的发现逻辑进行比较。
3. 运行一次集中的架构审查咨询（T2，通过 `/humanize:ask-codex` 执行 `analyze` 任务），以冻结流式协议契约：快照+偏移语义、截断/轮转行为、每会话 vs 项目通道范围。输出一份后续代码引用的单页契约文档。
4. 扩展 `viz/server/parser.py` 以使用新的辅助模块并读取缓存轮次日志（在文件缺失/部分写入时优雅回退）。扩展 `viz/server/watcher.py` 以同时监视缓存日志目录并发出带 `(path, offset, len)` 的追加事件。
5. 在 `viz/server/app.py` 中添加按会话 ID 键控的每会话 SSE 端点；它先提供快照然后追加；通过检测文件大小缩小并从偏移量 0 重新开始的文档化重新同步事件来应对截断。
6. 在 `scripts/humanize.sh` 的 `rlcr|skill|codex|gemini` 旁添加 `humanize monitor web` 到分发中。默认前台运行；透传 `--host`、`--port`、`--auth-token`、`--project`、`--daemon`。`--daemon` 路径委托给重构后的 `viz/scripts/viz-start.sh`，使用每项目 tmux 名称和每项目端口文件。
7. 删除 `commands/viz.md` 和 `skills/humanize-viz/SKILL.md`；在 `README.md` 中添加一行说明引导用户使用 `humanize monitor web`。
8. 用 CLI 固定模型替换项目切换器后端：从 `viz/server/app.py` 中移除 `/api/projects/switch`；从 `viz/static/js/app.js` 和 `viz/static/js/actions.js` 中移除 switch / + Add UI。前端仅读取服务器启动时指定的项目。
9. 添加 `--host`、`--port`、`--auth-token`。默认 `--host=127.0.0.1`。如果主机是非 localhost，要求非空令牌。将认证中间件应用于所有数据和控制端点（会话列表、会话详情、SSE 流、取消/报告）。前端令牌传播：fetch 使用 `Authorization: Bearer <t>`；`EventSource` 使用 `?token=<t>` 查询参数。
10. 构建会话定向取消辅助脚本（例如 `scripts/cancel-rlcr-session.sh`）并连接 `POST /api/sessions/<id>/cancel` 路由。镜像现有项目全局脚本的安全惯例。
11. 多循环 UI：在主页上以网格形式渲染所有活跃会话，每个带有内联实时日志面板，展开时打开 SSE 流。历史会话列在下方。
12. 按 AC-9 构建测试矩阵。每个测试使用 tmp `.humanize/rlcr/` 和 tmp `~/.cache/humanize/` fixture 树。
13. 首先记录 SSH 隧道部署模式；其次添加局域网绑定示例。

### 相关参考

- `scripts/humanize.sh:1196` — `humanize` 分发器；此处添加 `monitor web`。
- `scripts/humanize.sh`（第 284-368 行附近）— 当前 RLCR 缓存日志发现逻辑；一致性测试的真相来源。
- `scripts/lib/monitor-common.sh` — 共享 shell 辅助脚本（设计为单会话）；仅用于终端监控器。
- `scripts/lib/monitor-skill.sh` — skill 缓存发现（与 RLCR 分离的模型）；刻意不合并到 RLCR 辅助模块中。
- `scripts/cancel-rlcr-loop.sh` — 现有的项目全局取消；新的会话范围辅助脚本位于其旁。
- `viz/server/parser.py` — RLCR 会话解析器；扩展为读取缓存日志。
- `viz/server/watcher.py` — watchdog 观察器；扩展为监视缓存日志目录并发出追加事件。
- `viz/server/app.py` — Flask 路由；增加 `--host/--port/--auth-token`、每会话 SSE、会话范围取消；移除 `/api/projects/switch`。
- `viz/scripts/viz-start.sh` — tmux 启动器；重构为每项目命名和 `--daemon` 模式。
- `viz/static/js/app.js` 和 `viz/static/js/actions.js` — UI；移除项目切换器；增加多会话网格 + 带令牌传播的每会话 SSE 客户端。
- `commands/viz.md`、`skills/humanize-viz/SKILL.md` — 已删除。
- `tests/test-viz.sh` — 扩展了 AC-9 矩阵。
- `README.md`、`docs/usage.md` — 增加了 monitor `web` 条目和远程部署指南。

## 依赖与顺序

### 里程碑

1. M0 分支清理（预检，并行轨道）：
   - 子步骤 A：获取 `upstream/dev`，列出领先的 9 个提交，变基 `feat/viz-dashboard`，解决冲突。
   - 子步骤 B：重新运行现有测试（`tests/test-viz.sh` 和任何监控冒烟测试）。
   - 此里程碑不是设计任务的硬性门槛；一旦冲突被机械解决，T1+ 即可继续。
2. M1 发现与摄取：
   - 子步骤 A：RLCR 专用的会话+缓存日志发现辅助模块（T1）。
   - 子步骤 B：解析器和监视器扩展以摄取缓存轮次日志（T3、T4）。
3. M2 流式协议冻结（架构门槛）：
   - 子步骤 A：架构审查（T2，analyze），产出关于快照+偏移语义、截断处理、通道范围的单页契约文档。
   - 此里程碑为依赖契约的 T3/T4/T5 实现细节设门槛。
4. M3 实时多循环流式传输：
   - 子步骤 A：每会话 SSE 端点（T5）。
   - 子步骤 B：带独立实时日志面板的多循环 UI（T6）。
5. M4 CLI 整合：
   - 子步骤 A：将 `humanize monitor web` 添加到分发中（T8）。
   - 子步骤 B：每项目 tmux + 端口文件重构（T9）。
   - 子步骤 C：移除 `/humanize:viz`（T12）。
6. M5 远程访问 + 安全：
   - 子步骤 A：`--host/--port/--auth-token` + 所有接口的认证中间件（T11）。
   - 子步骤 B：移除服务器全局项目切换和前端切换器（T10）。
   - 子步骤 C：会话定向取消辅助脚本 + 端点（T7）。
7. M6 测试 + 文档：
   - 子步骤 A：按 AC-9 的测试矩阵（T13）。
   - 子步骤 B：文档：README 监控部分 + 远程部署指南（T14）。

相对依赖：M2 必须在 M1 的解析器/监视器工作和所有 M3 之前的流式传输形状决策之前完成。M5 的访问控制工作（T11）依赖于基本流式端点（M3）可用，以便在其上叠加认证。M6 测试依赖于 M3 + M4 + M5 功能完整。M0 是独立的，可以在冲突被机械解决之前与 M1 并行运行。

## 任务分解

每个任务包含一个路由标签：
- `coding`：由 Claude 实现
- `analyze`：通过 Codex 执行（`/humanize:ask-codex`）

| 任务 ID | 描述 | 目标 AC | 标签 | 依赖 |
|---------|------|---------|------|------|
| T0 | 预检（并行轨道）：将 `feat/viz-dashboard` 变基到 `upstream/dev`（9 个提交），解决冲突，重新运行现有测试。不是 T1+ 的硬性门槛。 | AC-9 | coding | - |
| T1 | RLCR 专用的会话 + 缓存日志发现辅助模块（例如 `viz/server/rlcr_sources.py`）；仅限 RLCR（不要合并 skill-monitor 缓存规则）；枚举 `.humanize/rlcr/` 下的所有会话。 | AC-2, AC-3 | coding | - |
| T2 | 架构审查：选择事件协议形状（快照 + 字节偏移尾随、截断/轮转行为、每会话 vs 项目通道）并确认传输方式（远程流使用 SSE + 保留 flskt_sock 仅用于 localhost）。输出：提交到 `docs/` 下的单页契约文档。 | AC-4 | analyze | T1 |
| T3 | 扩展 `viz/server/parser.py` 以摄取缓存轮次日志（`codex-run.log`、`codex-review.log`、gemini 变体）；在缺失或部分写入时优雅回退。 | AC-2, AC-4 | coding | T2 |
| T4 | 扩展 `viz/server/watcher.py` 以同时监视缓存日志目录；按 T2 契约发出每文件追加事件 `(path, offset, length)`。 | AC-4 | coding | T2 |
| T5 | 在 `viz/server/app.py` 中按 T2 契约添加每会话 SSE 端点；支持初始快照然后追加；处理轮转/截断重新同步。 | AC-4 | coding | T3, T4 |
| T6 | `viz/static/js/app.js` 中的多循环 UI：列出所有会话，分为活跃和历史两类，同时渲染每个活跃会话并带有独立的实时日志面板（活跃循环不回退到单会话详情视图）。 | AC-3, AC-5 | coding | T5 |
| T7 | 会话范围取消：新的 `scripts/cancel-rlcr-session.sh` 辅助脚本 + `POST /api/sessions/<id>/cancel` 路由 + UI 连接；不要委托给项目全局的 `scripts/cancel-rlcr-loop.sh`。 | AC-7 | coding | T5 |
| T8 | 在 `scripts/humanize.sh` 的 `rlcr|skill|codex|gemini` 旁添加 `humanize monitor web` 到分发中；默认前台运行；透传 `--host/--port/--auth-token/--project/--daemon`；保留现有子命令和用法文本。 | AC-1 | coding | - |
| T9 | 重构 `viz/scripts/viz-start.sh`：每项目 tmux 会话名称（不再使用全局 `humanize-viz`）；每项目端口文件；仅由 `humanize monitor web` 的 `--daemon` 路径调用。 | AC-8 | coding | T8 |
| T10 | 移除 `viz/server/app.py` 中的服务器全局项目变更：移除 `/api/projects/switch`（或转换为只读列表）；移除 `viz/static/js/app.js` 和 `viz/static/js/actions.js` 中的项目切换器 / + Add 流程；不从服务器修改 `viz-projects.json`。 | AC-5, AC-8 | coding | T8 |
| T11 | 向 `viz/server/app.py` 添加 `--host`、`--port`、`--auth-token` + 通过 `viz/scripts/viz-start.sh` 和 `humanize monitor web` 传播；默认 `--host=127.0.0.1`；拒绝无令牌的非本地启动；在远程模式下将所有数据/控制端点（会话列表、会话详情、SSE 流、取消）置于令牌保护之后；前端令牌传播：fetch 使用 `Authorization: Bearer` + SSE `EventSource` 使用 `?token=...`。 | AC-6 | coding | T5, T10 |
| T12 | 移除 `/humanize:viz`：删除 `commands/viz.md` 和 `skills/humanize-viz/SKILL.md`；在 `README.md` 中添加一行升级说明引导用户使用 `humanize monitor web`。 | AC-1 | coding | T8 |
| T13 | 按 AC-9 的测试矩阵：并发活跃循环、缺失缓存日志启动、日志轮转/截断恢复、每个端点的远程认证、项目隔离、监控向后兼容、每项目端口文件冲突避免、缓存路径/会话映射与 `scripts/humanize.sh` 的一致性测试。 | AC-9 | coding | T6, T7, T11 |
| T14 | 文档：README 监控部分更新；远程部署指南（SSH 隧道示例在前，局域网绑定示例在后）；`/humanize:viz` 移除的升级说明。 | AC-1, AC-6 | coding | T13 |

## Claude-Codex 协商

### 共识

- 复用现有的 `humanize monitor` 数据源（`.humanize/rlcr/<session>/*` 文件加上 `~/.cache/humanize/<project>/<session>/round-*-codex-{run,review}.log`）是正确的架构；仪表板是读取者，而非并行采集管线。
- 将入口移入 `scripts/humanize.sh` 中的 `humanize monitor` 分发并移除 `/humanize:viz` 是对现有 CLI 形状的自然扩展，避免了孤立的斜杠命令接口。
- 考虑到当前 `viz/server/app.py` 中存在未认证的变更操作，使用 localhost 默认加上显式 `--host` + `--auth-token` 进行远程可选加入来收紧网络暴露是正确的基线。
- `viz/scripts/viz-start.sh` 中当前的全局 `humanize-viz` tmux 会话名称是一个真实的冲突缺陷；需要每项目命名。
- feat/viz-dashboard 分支已包含上游提交 338b4dd（PR 循环移除）和 016caca（监控拆分）。因此变基是漂移清理（9 个提交），而非缺失的前置条件。
- 流式协议必须支持快照 + 字节偏移追加 + 截断/轮转重新同步；"无全文件重新获取循环"从"永远仅追加"收紧为允许合法的快照/重新同步路径。

### 已解决的分歧

- 主题：变基是否应该成为整个计划的依赖根（M0/T0 作为硬性门槛）？
  - Claude（v1）：是，M0 优先，T0 阻塞所有其他任务。
  - Codex：否，分支清理已包含关键的上游提交；将 T0 设为硬性门槛会将不相关的上游漂移变成设计的阻塞项。
  - 决议：M0/T0 是并行预检轨道。一旦变基冲突被机械解决，T1+ 即可继续。记录在 M0 描述和 T0 的措辞中。

- 主题：是否应该有一个终端和 Web 监控器共同消费的单一共享 "monitor-core" 库？
  - Claude（v1）：是，提取一个共享模块以保持终端和 Web 同步。
  - Codex：否，shell `monitor-common.sh` 设计为单会话，Web 端是 Python；强制跨语言核心会混淆模型。
  - 决议：不要构建共享的跨语言核心。将终端辅助脚本保留在 shell 中；为 Web 端构建一个单独的小型 RLCR 专用 Python 辅助模块（`viz/server/rlcr_sources.py`），并通过与 `scripts/humanize.sh` 缓存逻辑的一致性测试进行验证。

- 主题：T2（提取共享缓存发现辅助模块）是否应该合并 `scripts/humanize.sh`（RLCR）和 `scripts/lib/monitor-skill.sh`（skill 调用）的逻辑？
  - Claude（v1）：是，将缓存发现模式整合到一个辅助模块中。
  - Codex：否，RLCR 会话缓存和 skill 调用缓存是相邻但不同的模型；合并会混淆它们。
  - 决议：T1 辅助模块仅限 RLCR。Skill-monitor 缓存规则保持独立。

- 主题：流式协议形状的架构审查应该在何时进行？
  - Claude（v1）：T13 最后，在监视器和端点代码之后。
  - Codex：反过来；它必须为监视器和端点设计设门槛。
  - 决议：T2 现在是一个 `analyze` 任务，在 T3/T4/T5 之前运行，输出一份单页契约文档。

- 主题：流式协议是否应该完全禁止全文件重新获取？
  - Claude（v1）：是，仅追加。
  - Codex：永远仅追加会破坏后加入的客户端和轮转恢复。
  - 决议：AC-4 措辞改为"快照 + 字节偏移追加 + 文档化重新同步"和"无在每次更新时重新获取完整文件内容的轮询循环"。两个意图均保留。

- 主题：移除 `/api/projects/switch` 是否足以修复多项目缺陷？
  - Claude（v1）：是。
  - Codex：否，`viz/static/js/app.js` 和 `viz/static/js/actions.js` 中的前端切换器 / + Add 流程仍然会被连接。
  - 决议：T10 扩展为同时移除前端切换器界面；AC-8 扩展为测试这些 UI 元素的缺失。

- 主题：远程认证是否需要覆盖读取端点，还是仅覆盖变更操作？
  - Claude（v2）：仅变更操作。
  - Codex：否，读取端点也提供会话数据；远程未认证必须在所有地方被阻止。
  - 决议：AC-6 扩展；T11 扩展为覆盖所有数据和控制接口，加上前端的令牌传播（fetch 使用 `Authorization`，SSE 使用 `?token=...`）。

- 主题：多循环 UI 中的取消语义。
  - Claude（v1/v2）：保留取消 + 报告。
  - Codex：现有的 `scripts/cancel-rlcr-loop.sh` 是项目全局的，不是会话定向的；要么构建会话范围路径，要么在 v1 中禁用取消。
  - 决议：用户选择 DEC-2 = 构建会话范围取消。T7 构建新的 `scripts/cancel-rlcr-session.sh` 辅助脚本加上每会话 API 并进行测试。

- 主题：实时日志流的认证传输（浏览器 WebSocket 无法设置 `Authorization` 头）。
  - Claude（v2）：通过 `--auth-token` 的 Bearer 令牌，传输方式未指定。
  - Codex：浏览器中的 WS 无法发送任意认证头；要么定义精确的 WS 认证握手，要么在远程模式下放弃 WS。
  - 决议：用户选择 DEC-4 = 远程流使用 SSE over HTTPS 加令牌查询参数；flask_sock WS 仅保留用于 localhost。

### 收敛状态

- 最终状态：`converged`
- 已执行的收敛轮次：3（第 1 轮发现 7 项必要变更；第 2 轮发现 5 项收紧项；第 3 轮未返回必要变更和高影响分歧）。

## 待决用户决策

规划期间提出的所有决策已由用户解决。无 `PENDING` 状态的决策。

- DEC-1：`humanize monitor web` 应该如何启动（生命周期）？
  - Claude 立场：前台默认 + 可选 `--daemon` 标志；匹配 CLI 监控用户体验并避免隐藏进程。
  - Codex 立场：前台或守护进程都有道理，但 v1 计划必须选择一个以避免 `viz/scripts/viz-start.sh` 的混合所有权。
  - 权衡摘要：前台 = 匹配 `humanize monitor rlcr` 用户体验，无孤儿 tmux 会话，更简单的测试框架。守护进程 = "始终在线"便利性，但需要管理隐藏进程和 tmux 名称冲突。
  - 决策状态：`前台默认 + --daemon 可选加入`（用户确认）。

- DEC-2：v1 多循环仪表板中的取消按钮策略？
  - Claude 立场：构建会话范围取消。
  - Codex 立场：要么构建会话范围路径，要么在 v1 中禁用取消；现有的 `scripts/cancel-rlcr-loop.sh` 是项目全局的，在多循环模式下不安全。
  - 权衡摘要：构建 = 正确的用户体验，更多工作（新 shell 辅助脚本 + API + 测试）。禁用 = 更小的 v1，推迟取消功能。保持全局 = 正确性缺陷。
  - 决策状态：`构建会话范围取消`（用户确认）。T7 构建 `scripts/cancel-rlcr-session.sh`。

- DEC-3：仪表板应如何处理多个项目？
  - Claude 立场：每服务器 CLI 固定单项目（`humanize monitor web --project <path>`）；多项目意味着运行多个进程。
  - Codex 立场：CLI 固定、每客户端状态或每项目独立实例都可以；歧义会阻塞 AC-5/AC-8。
  - 权衡摘要：CLI 固定 = 干净隔离，简单后端，消除服务器全局变更缺陷，牺牲服务器内切换器便利性。每客户端 = 复杂后端。服务器全局 = 当前缺陷。
  - 决策状态：`每服务器 CLI 固定单项目`（用户确认）。`/api/projects/switch` 已移除；前端切换器界面已移除。

- DEC-4：实时日志流的远程认证传输？
  - Claude 立场：Bearer 令牌；传输方式开放。
  - Codex 立场：浏览器 WebSocket 客户端无法设置 `Authorization` 头；选择 SSE 用于远程，或定义精确的 WS 握手。
  - 权衡摘要：SSE = 通过 HTTPS 上的查询参数令牌实现干净的浏览器认证，追加形状的流量匹配 SSE 优势，放弃双向控制。WS = 双向但认证需要自定义子协议/握手。
  - 决策状态：`远程流使用 SSE over HTTPS 加令牌查询参数；flask_sock WS 仅保留用于 localhost`（用户确认）。

- AC-4 延迟预算：硬性要求 vs 方向性目标？
  - Claude 立场：硬性要求（<=2s）以赋予"实时"精确含义。
  - Codex 立场：两者都有道理；计划必须记录选择。
  - 权衡摘要：硬性 = 严格 CI 断言，更尖锐的失败模式。方向性 = 更宽松的 SLA，负载下更容易通过。
  - 决策状态：`硬性要求（<=2s 端到端）`（用户确认）。AC-4 反向测试在正常负载下中位延迟超过 2.0 秒时导致 CI 失败。

## 实现说明

### 代码风格要求

- 实现代码和注释不得包含计划特定术语，如 "AC-"、"Milestone"、"Step"、"Phase" 或类似的工作流标记。这些仅属于计划文档。
- 在代码中使用描述性的、符合领域习惯的命名。例如，优先使用 `RLCRSessionEnumerator` / `cache_log_discovery` / `live_log_stream`，而非引用计划任务 ID 的名称。
- 所有实现、注释、测试和文档必须使用英文。代码或注释中不得包含 emoji 或 CJK 字符（依据 `.claude/CLAUDE.md` 中的项目规则）。
- 依据 `.claude/CLAUDE.md` 中的项目规则：`main` 上的任何提交都必须在 `.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json` 和 `README.md`（"Current Version" 行）中包含版本升级。对于 `feat/viz-dashboard` 上的提交，这三个文件中的分支 `version` 必须已经领先于 `main` 的版本。实现工作必须遵守该策略。

### 分支与变基说明

- 实现在 `feat/viz-dashboard` 上开始（不是当前的 `feat/rlcr-integral-context` 分支）。
- T0 将 `feat/viz-dashboard` 变基到 `upstream/dev`（领先 9 个提交）。它是并行预检，不是设计任务的硬性门槛。
- `gen-plan` 本身不执行任何 git 操作。变基在实现循环开始时执行（`/humanize:start-rlcr-loop`）。

--- 原始设计草案开始 ---

# 草案：优化 viz-dashboard — 合并到 `humanize monitor` 作为 Web 视图

## 背景

`feat/viz-dashboard` 分支当前引入了一个 `/humanize:viz` Claude
斜杠命令和一个本地可视化仪表板。虽然该仪表板确实显示了一些数据，
但对 *实时、动态运行的 RLCR 循环* 的可视化目前还不够清晰：
随着循环的推进，状态、每轮进度和流式日志输出难以跟踪。

另外，Humanize 已经提供了一项 CLI 端监控功能，用户可以在另一个终端中运行（不是在 Claude Code 内部）：

```bash
source <path/to/humanize>/scripts/humanize.sh   # or add to .bashrc / .zshrc

humanize monitor rlcr        # RLCR loop
humanize monitor skill       # All skill invocations (codex + gemini)
humanize monitor codex       # Codex invocations only
humanize monitor gemini      # Gemini invocations only
```

该监控功能已经捕获实时状态（RLCR 轮次、skill / Codex / Gemini 调用、日志输出）。
Web 仪表板无需自行构建采集管线 —— 它应该直接消费 `humanize monitor` 已经提供的数据。

## 目标

优化 viz-dashboard 分支，使其满足以下要求：

1. 仪表板成为叠加在现有 `humanize monitor` 数据源之上的 **Web 视图**，
   而非一个独立的采集层。
2. 仪表板能够 **同时展示多个实时 RLCR 循环**，每个循环具有独立的
   状态和流式日志输出。
3. 入口从 Claude 中移出（不再使用 `/humanize:viz` 斜杠命令），
   进入 `humanize monitor` CLI 命令，作为一个新的在线查看子命令。
4. 新功能面向 **在线/远程浏览器访问**，而非要求用户必须在运行
   Claude 的同一台机器上查看的本地查看器。
5. 保留现有 viz-dashboard 分支中的实用功能 —— 尤其是 **跨会话查询**
   （浏览不同 Claude 会话/对话中的历史循环记录）。

## 非目标

- 重新实现监控采集管线（`humanize monitor rlcr/skill/codex/gemini`）。
  仪表板消费该管线，而非替代它。
- 继续将 `/humanize:viz` 作为 Claude 斜杠命令发布。
- 添加在 commit 1b575fe 中已明确移除的图表面板或功能
  （"multi-project switcher + restart + remove chart panels"）。

## 必需行为

1. **CLI 入口统一**
   - 移除 `commands/viz.md` 及任何 `/humanize:viz` Claude 命令界面。
   - 添加一个新的 `humanize monitor` 子命令（名称在规划阶段确定，
     例如 `humanize monitor web` 或 `humanize monitor dashboard`），
     用于启动 Web 仪表板服务器。
   - 其他 `humanize monitor rlcr|skill|codex|gemini` 子命令必须
     保持不变地继续工作（终端实时跟踪）。

2. **实时多循环视图**
   - Web 仪表板必须能够同时显示 2 个以上并发运行的 RLCR 循环，
     每个循环具有：
     - 当前状态（running、paused、converged、stopped 等）
     - 当前轮次/阶段
     - 实时流式日志输出，近乎实时更新

3. **复用现有监控数据**
   - 仪表板的数据来源必须与 `humanize monitor rlcr/skill/codex/gemini`
     已读取的文件/事件相同。它不得添加并行采集机制（不得仅为仪表板添加新的钩子）。

4. **在线/远程可访问**
   - 仪表板必须能够通过网络从浏览器访问，而非仅限于运行 Claude 的
     机器上的 `localhost`。具体的绑定/认证设计在规划阶段确定。

5. **跨会话历史**
   - 必须保留现有 viz-dashboard 分支中的跨会话查询功能
     （浏览不同 Claude 会话/对话中的历史循环记录）。

## 分支清理

在实现开始之前，分支 `feat/viz-dashboard` 必须变基到最新的
`upstream/dev`（humania-org/humanize）。分支分叉后，`upstream/dev`
上已合入了多个相关变更，包括：

- `Add ask-gemini skill and tool-filtered monitor subcommands`（引入了
  仪表板必须复用的 `humanize monitor skill|codex|gemini` 子命令）
- `Remove PR loop feature entirely`（viz-dashboard 分支仍通过
  `commands/cancel-pr-loop.md`、`commands/start-pr-loop.md`、
  `hooks/pr-loop-stop-hook.sh` 引用了 PR 循环概念）
- 多项监控/钩子修复

因此，该变基既是正确性的前提条件（仪表板消费新的监控子命令），
也是清理步骤（必须移除 PR 循环相关引用）。

## 范围外（本计划不涉及）

- 对 RLCR 语义、钩子或 skill 行为的更改。
- 认证提供者、身份系统或多用户账户模型 —— 基本的远程访问保护在范围内，
  但完整的 IAM 不在范围内。

--- 原始设计草案结束 ---
