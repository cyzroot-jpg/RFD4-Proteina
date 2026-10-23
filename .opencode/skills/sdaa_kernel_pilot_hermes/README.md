# KernelPilot Hermes：teco-ops 算子性能优化

本分支用于优化 [`Tecorigin/teco-ops`]
中的 SDAA 自定义算子。它保留 Humanize RLCR（Ralph Loop with Code Review）
迭代流程，由 Hermes 对每一轮修改进行审查，并且使用：

- `teco-ops` 自带的 C++ 测试框架做精度与性能验收；
- `teco-ops-wiki` 查询 SDAA 架构、TecoLIBRT API 和既有优化经验；
- `[Average Hardware Time]` 作为性能主指标。

## 1. 环境要求

推荐使用已经包含 SDAA 编译器和运行时的开发镜像。容器至少需要：

- Ubuntu 22.04 或兼容 Linux；
- 可用的 SDAA 设备节点；
- `/opt/tecoai/setvars.sh`；
- SDAA 编译器、运行时和 SDPTI；
- Bash、Git、CMake、Make、Python 3、Conda、`jq` 和 `rg`；
- 与容器 SDAA 运行时匹配的 PyTorch/Torch-SDAA 环境；
- 能访问 Hermes 所使用的 OpenAI 兼容 API。

宿主驱动与容器运行时必须兼容。如果测试输出包含
`driver api and driver versions are different`，同一轮基线和候选仍必须固定使用
同一个容器、同一张卡和同一套运行时，但正式结果还应记录这项环境风险。

## 2. 安装 Hermes

联网环境可使用 Hermes 官方安装器：

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hash -r
hermes --version
```

查看配置位置：

```bash
hermes config path
hermes config env-path
```

默认配置目录通常是：

```text
/root/.hermes/config.yaml
/root/.hermes/.env
/root/.hermes/skills/
```

## 3. 配置 Hermes 模型、API 和迭代预算

设置 Hermes 会话预算：

```bash
hermes config set agent.max_turns 9000
```

不要继续使用旧的 `.env` 配置 `HERMES_MAX_ITERATIONS`；Hermes 0.18 以
`config.yaml` 中的 `agent.max_turns` 为准。可以检查并删除冲突的旧值：

```bash
grep -n '^HERMES_MAX_ITERATIONS=' "$(hermes config env-path)" || true
```

### 3.1 OpenAI 兼容 API

运行交互式配置：

```bash
hermes setup model
hermes setup agent
```

也可以编辑 `$(hermes config path)`。使用自定义 OpenAI 兼容服务时，关键配置如下：

```yaml
model:
  provider: custom
  default: <model-name>
  base_url: https://<api-host>/v1
  api_key: <your-api-key>

agent:
  max_turns: 9000
  gateway_timeout: 3600

compression:
  enabled: true
  threshold: 0.5

session_reset:
  mode: none

hooks_auto_accept: true
```

注意：

- `base_url` 应包含服务要求的 `/v1` 前缀；
- 模型名必须与 API 网关实际暴露的名称完全一致；
- 不要将真实 API Key 提交到 Git；
- 配置文件建议执行 `chmod 600 ~/.hermes/config.yaml ~/.hermes/.env`；
- `agent.max_turns=9000` 会显著提高最坏情况下的 token 和执行时间，只应用于受控的
  长时间优化任务；
- `delegation.max_iterations` 是子代理自己的预算，与 `agent.max_turns` 不同。本流程
  默认不要求把子代理预算也提高到 9000。

检查配置：

```bash
hermes config check
hermes doctor
hermes config show
```

## 4. 安装 KernelPilot skills 和 hook

从 KernelPilot 根目录执行：

```bash
humanize/scripts/install-skills-hermes.sh
```

安装后应存在以下任务 skills：

```text
humanize-kernel-agent-loop
teco-ops-op-test
teco-ops-wiki
```

安装器还会注册 KernelPilot 的 Hermes `pre_verify` hook。最终配置中的关键部分应为：

```yaml
hooks:
  pre_verify:
    - command: bash /root/.hermes/skills/humanize/hooks/loop-hermes-pre-verify-hook.sh
      timeout: 3600
hooks_auto_accept: true
```

这里有两个独立的 3600 秒超时：

- hook 配置中的 `timeout: 3600` 是 Hermes 执行 `pre_verify` shell hook 的上限；
- 启动 RLCR 时的 `--hermes-timeout 3600` 是每次 Hermes 审查请求的上限，
  `hermes-stop-gate.sh` 使用该轮状态中的值。

如果修改过 hook 脚本或 timeout，重新运行安装器以刷新
`~/.hermes/config.yaml` 和 shell-hook allowlist。

## 5. 健康检查

```bash
# 不调用模型 API。
humanize/scripts/hermes-health-check.sh \
  --project-root /work/kernelpilot \
  --skip-live

# 包含真实 API 请求。
humanize/scripts/hermes-health-check.sh \
  --project-root /work/kernelpilot \
  --live \
  --hermes-timeout 60
```

运行仓库契约测试：

```bash
cd /work/kernelpilot
bash humanize/tests/test-teco-performance-wiki.sh
bash humanize/tests/test-kernel-agent-loop-skill.sh
bash humanize/tests/test-hermes-hook-install.sh
```

## 6. Hermes 自动执行的优化与验收流程

本章描述 Hermes 在 RLCR 内部必须遵守的执行契约。正常使用时，只需按第 7 章启动 Hermes 并提交任务，不需要手动逐条运行本章命令。本章用于审计日志或故障复现。

### 6.1 自动构建目标算子

对基线和每个候选，Hermes 自动构建 teco-ops 算子库：

```bash
OP=memset

source /root/miniconda3/etc/profile.d/conda.sh
conda activate torch27_env_py310
source /opt/tecoai/setvars.sh

cd /work/teco-ops
bash build.sh --build teco
```

随后，Hermes 使用 `-f` 只构建目标算子的测试程序：

```bash
cd /work/teco-ops/test
source env.sh
bash build.sh --arch teco -f "$OP"
```

`-f "$OP"` 只过滤测试程序中的算子注册和相关测试源文件，可显著缩短单算子迭代的
测试构建时间。根目录的 `bash build.sh --build teco` 仍负责构建 teco-ops 算子库。

Hermes 必须检查构建日志中是否出现：

```text
BUILD_SPECIFIC_OP: memset
```

### 6.2 自动执行独立精度门禁

Hermes 对每个必需用例先以零预热、零性能重复运行。以下是 Hermes 自动执行的
等价命令，不是要求用户手动操作：

```bash
OP=memset
CASE=case_0

cd /work/teco-ops/test
./build/demo \
  --gid=0 \
  --warm_repeat=0 \
  --perf_repeat=0 \
  --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

Hermes 只有在以下条件同时满足时才判定精度通过：

- prototxt 成功解析；
- CPU/Python 参考实现成功生成结果；
- GoogleTest 显示通过；
- `Calculate Diffs` 的误差满足 prototxt 阈值；
- 输出包含 `ALL PASSED.`；
- 没有测试框架错误。

零重复精度命令仍可能打印 `Calculate Performance`、零硬件时间或 `inf` 带宽；这些
字段没有性能意义，禁止用于比较。

### 6.3 精度通过后自动执行性能测试

只有目标算子的全部必需精度用例通过后，Hermes 才自动运行性能测试：

```bash
./build/demo \
  --gid=0 \
  --warm_repeat=3 \
  --perf_repeat=50 \
  --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

性能命令会再次计算精度。如果该次运行出现精度失败、GoogleTest 失败或框架错误，
即使打印了性能数字也必须丢弃。

唯一主性能指标为：

```text
[Average Hardware Time  ]: <value> (ms)
```

数值越低越好。50 次测量会去掉最高 5 个和最低 5 个样本，再对中间 40 个取平均。
`Average Interface Time`、`Average Launch Time`、单次 `Kernel Detail`、编译耗时和
主机 wall-clock 时间都不能作为最终分数。

### 6.4 自动覆盖算子的全部用例

Hermes 不得只运行一个方便的 case。下面的脚本展示 skills 要求的等价控制逻辑：
先完成全部精度门禁，再开始任何性能测试。用户无需复制或手动执行该脚本。

```bash
set -eo pipefail

OP=memset
DEVICE_ID=0
TEST_ROOT=/work/teco-ops/test
RESULT_ROOT=/work/teco-ops/performance-results/$OP

cd "$TEST_ROOT"
mkdir -p "$RESULT_ROOT/correctness" "$RESULT_ROOT/performance"
mapfile -t CASE_PATHS < <(
  find "zoo/teco/${OP}/test_case" -maxdepth 1 -type f -name '*.prototxt' | sort
)

run_checked_case() {
  phase="$1"
  warm_repeat="$2"
  perf_repeat="$3"
  case_path="$4"
  case_name="$(basename "$case_path" .prototxt)"
  log="$RESULT_ROOT/$phase/${case_name}.log"

  ./build/demo \
    --gid="$DEVICE_ID" \
    --warm_repeat="$warm_repeat" \
    --perf_repeat="$perf_repeat" \
    --gtest_repeat=1 \
    --case_path="$case_path" 2>&1 | tee "$log"

  grep -q '^ALL PASSED\.$' "$log"
  ! grep -q '^\[  FAILED  \]' "$log"
}

# 任意精度用例失败都会停止，不会进入性能阶段。
for case_path in "${CASE_PATHS[@]}"; do
  run_checked_case correctness 0 0 "$case_path"
done

for case_path in "${CASE_PATHS[@]}"; do
  run_checked_case performance 3 50 "$case_path"
done
```

Hermes 不能只依赖 `./build/demo` 的进程退出码；部分框架失败可能仍返回 0。
Hermes 必须同时检查 `ALL PASSED.`、GoogleTest 摘要和比较结果。

### 6.5 自动查询 teco-ops-wiki

每轮实现候选前，Hermes 自动使用随 KernelPilot 安装的 `teco-ops-wiki`。以下命令
用于说明 skill 的查询接口，通常不需要用户手动运行：

```bash
python3 scripts/validate.py
python3 scripts/query.py \
  "memset DMA SPM alignment optimization" \
  --limit 5 \
  --compact
PAGE_ID='replace-with-query-result-page-id'
python3 scripts/get_page.py "$PAGE_ID" --follow-sources
```

每次采用 wiki 建议时，Hermes 必须在 ledger 中记录页面 ID、来源路径，以及该证据
改变了什么实现决策。如果 wiki 没有覆盖目标问题，Hermes 应记录证据缺口，再直接
检查当前 teco-ops 源码；不能临时切换到另一套 wiki。

## 7. 启动 Hermes 和 RLCR

本项目推荐直接在 Hermes 对话中启动 RLCR，不需要先在宿主 shell 中手动执行
`setup-rlcr-loop.sh`。Hermes 会在对话里完成 K/R/W 整理、计划生成、RLCR 初始化、
状态检查和后续优化。

### 7.1 确认启动条件

启动前确认：

1. `/work/teco-ops` 是目标仓库，并且位于独立优化分支；
2. 工作树没有与本次任务无关的修改；
3. `/work/kernelpilot` 已安装 Hermes skills 和 hook；
4. Hermes API 健康检查已经通过；
5. 目标算子、正确性参考和工作负载可以在当前 teco-ops 仓库中找到。

```bash
cd /work/teco-ops
git branch --show-current
git status --short
```

### 7.2 从 teco-ops 根目录启动 Hermes

```bash
cd /work/teco-ops

hermes \
  --accept-hooks \
  --skills humanize-kernel-agent-loop,teco-ops-op-test,teco-ops-wiki
```

必须从 `/work/teco-ops` 启动，使 Hermes 将目标仓库本身作为优化工作区。

### 7.3 在 Hermes 对话中提交启动指令

将下面内容发送给 Hermes，并把 `memset` 替换为实际目标算子：

```text
请优化当前 teco-ops 仓库中的 memset 算子。

1. 读取 /work/kernelpilot/prompts/teco-ops-operator.md。
2. 使用 humanize-kernel-agent-loop、teco-ops-op-test 和 teco-ops-wiki。
3. 从当前仓库恢复并明确 K/R/W：
   - K 是目标算子的语义、API、dtype/layout 支持和实现文件；
   - R 是 test/zoo/teco/memset/ 下的原生参考实现、比较方法和误差阈值；
   - W 是该算子的全部必需 prototxt case，并标明主要性能 case。
4. 查询 teco-ops-wiki，记录使用的页面 ID、来源路径和它影响的实现决策。
5. 在 ledgers/memset-plan.md 编写符合 Humanize 要求的详细实施计划。
6. 在修改算子代码或采集候选性能之前，从当前 teco-ops 根目录执行：
   /work/kernelpilot/humanize/scripts/setup-rlcr-loop.sh \
     ledgers/memset-plan.md \
     --strict-success \
     --hermes-provider custom \
     --hermes-model <使用 ~/.hermes/config.yaml 中 model.default 的实际值> \
     --hermes-timeout 3600
7. 不要传 --max，保持 RLCR 默认优化轮数 84。
8. 初始化后检查 .humanize/rlcr/*/state.md；只有状态文件存在且参数正确，
   才能开始修改算子。
9. 每个候选先使用 -f memset 构建目标测试，再对全部必需 case 执行独立
   0/0 精度门禁；所有精度用例通过后才能执行 3/50 性能测试。
10. 只用 Average Hardware Time 比较性能，并将原始日志保存在
    performance-results/ 下。
11. 每轮只进行一个可测量的实现变化，写完 round summary 后运行 Hermes gate，
    根据审查结论继续下一轮，直到满足验收条件并获得 Hermes 批准。

请先完成 bootstrap 和 RLCR 初始化，不要在 RLCR 激活前修改算子实现。
```

`<使用 ~/.hermes/config.yaml 中 model.default 的实际值>` 必须由 Hermes 替换成真实
模型名，不能原样传给 shell。这里不传 `--max`，因此 RLCR 优化轮数保持默认 84；
Hermes 自身的 `agent.max_turns` 仍按前文配置为 9000。

### 7.4 在对话中确认 RLCR 已激活

Hermes 完成初始化后，应在同一对话中展示或检查：

```bash
find .humanize/rlcr -maxdepth 2 -name state.md -print
grep -E '^(current_round|max_iterations|hermes_provider|hermes_model|hermes_timeout|strict_success):' \
  .humanize/rlcr/*/state.md
```

启动状态至少应满足：

```text
current_round: 0
max_iterations: 84
hermes_timeout: 3600
strict_success: true
```

如果没有生成 `state.md`，或者配置值不正确，应要求 Hermes 修复初始化问题，不能
直接开始优化。

### 7.5 在同一 Hermes 对话中推进 RLCR

RLCR 激活后继续在当前对话中工作。每一轮必须按编号顺序执行：

1. 读取当前 `round-<N>-prompt.md`；
2. 查询并记录相关 teco-ops-wiki 证据；
3. 只实施一个可测量的候选变化；
4. 使用 `-f <目标算子>` 重新构建测试；
5. 对全部必需 case 执行独立 `0/0` 精度门禁；
6. 只有全部精度用例通过后才执行 `3/50` 性能测试；
7. 更新 ledger 和 `round-<N>-summary.md`；
8. 在前台运行 Hermes stop gate 并等待审查结果；
9. 根据 `COMPLETE` 或 `NEEDS_CHANGES` 进入完成阶段或下一轮。

不要仅凭测试进程退出码判断成功，也不要使用精度失败候选打印出的性能数字。

### 7.6 恢复中断的 Hermes 对话

如果终端断开，回到同一个 teco-ops 工作区并恢复最近会话：

```bash
cd /work/teco-ops
hermes --continue
```

恢复后先让 Hermes 读取当前 `.humanize/rlcr/*/state.md`、当前 round prompt 和已有
ledger，再继续该轮；不要重复创建新的 RLCR 状态目录。


## 8. 手动干预、查看状态和取消循环

正常流程由 Hermes 自动运行审查门禁。本章命令只用于故障排查、人工核验或明确需要
取消循环的场景，不是每轮都要求用户操作。

当前轮总结已经生成、但自动 gate 没有运行时，可手动执行：

```bash
/work/kernelpilot/humanize/scripts/hermes-stop-gate.sh \
  --project-root /work/teco-ops
```

查看循环状态：

```bash
find /work/teco-ops/.humanize/rlcr -maxdepth 2 \
  \( -name state.md -o -name '*review*.md' -o -name '*summary.md' \) \
  -print
```

取消循环：

```bash
cd /work/teco-ops
/work/kernelpilot/humanize/scripts/cancel-rlcr-loop.sh
```

## 9. Hermes 每轮必须保留的证据

以下证据由 Hermes 自动写入 ledger 和 `performance-results/`。用户通常只需在最终
报告中检查其完整性。基线和每个候选至少记录：

- teco-ops 完整提交 ID 和 diff；
- 目标算子、设备 ID、SDAA 驱动/Runtime/SDPTI 版本；
- 精确的构建命令和 `-f` 目标；
- 全部精度用例路径、误差阈值和通过/失败状态；
- 性能用例路径、3 次预热、50 次性能重复；
- 每个 case 的 `Average Hardware Time`；
- 次要的带宽和计算力指标；
- wiki 页面 ID 和决策影响；
- 原始 stdout/stderr 日志路径；
- 回归、失败候选和不支持场景。

最终报告必须逐 case 给出基线时间、最终时间和加速比，不能只报告跨 case 平均值。

## 10. 常见问题

### 10.1 `ModuleNotFoundError: No module named 'torch'`

没有激活 PyTorch/Torch-SDAA Conda 环境，或版本不匹配。重新激活环境后再运行测试。

### 10.2 `please source env.sh before build.sh`

测试构建前必须执行：

```bash
cd /work/teco-ops/test
source env.sh
```

### 10.3 `File not found: .../.prototxt`

通常是 `CASE` 变量为空或 shell 变量在远程命令中被提前展开。先检查：

```bash
printf 'OP=%s CASE=%s\n' "$OP" "$CASE"
test -f "zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

### 10.4 测试输出失败，但进程退出码是 0

不要只检查 `$?`。同时要求日志出现 `ALL PASSED.`，且不能出现 GoogleTest
`[  FAILED  ]` 或比较失败。

### 10.5 Hermes API 可用，但目标仓库健康检查失败

`hermes-health-check.sh --project-root` 指向的是 KernelPilot 根目录，不是 teco-ops：

```bash
cd /work/kernelpilot
humanize/scripts/hermes-health-check.sh --project-root /work/kernelpilot --live
```

### 10.6 hook 仍显示旧 timeout

重新安装 skills/hook：

```bash
cd /work/kernelpilot
humanize/scripts/install-skills-hermes.sh
```

然后检查：

```bash
hermes config show
```

`loop-hermes-pre-verify-hook.sh` 对应的 `timeout` 应为 3600。

### 10.7 性能有提升，但精度失败

候选无效。无论性能提升多少，都必须回退或继续修复，不能将该数字作为最终结果。
