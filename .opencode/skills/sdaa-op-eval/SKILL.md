---
name: sdaa-op-eval
description: SDAA 算子性能与精度评估技能。性能用 teco-ops 原生 C++ 测试框架 demo 的 [Average Hardware Time]（warm_repeat/perf_repeat，ALL PASSED 判定正确性）；精度用 tecovllm-modelzoo 的 epi_eval 在真实 vLLM 服务上评测 accuracy（OneGenomeRice/RiceBenchmark，基线 0.9120±0.01），并确保服务加载被测 libteco_ops.so。提供一键脚本 bench_op.sh / install_lib.sh / verify_serve.sh / eval_accuracy.sh 与判定标准。触发关键词：性能测试、hardware time、精度评估、accuracy、评测、验收、Average Hardware Time、ALL PASSED、precision test。
argument-hint: "[评估目标] [算子名/仓库路径/服务端口]"
---

# SDAA 算子性能与精度评估

对 SDAA/TECO 算子（teco-ops）做两类验收评估，**两者缺一不可**：

1. **性能** —— teco-ops 原生 C++ 测试框架的 `[Average Hardware Time]`
2. **精度** —— 真实 vLLM 服务跑模型评测的 `accuracy`，服务必须加载被测 kernel 的 `libteco_ops.so`

> ⚠️ 只做过 demo 性能测试的算子不代表服务端可用：SPM 堆大小、加载路径差异可能导致服务端崩溃/退化，**必须用精度评测兜底**（本会话已踩过此坑：测试环境全过、服务端 `spm malloc failed` → 精度从 0.91x 崩到 0.24x）。

---

## 一、性能评估（Hardware Time）

用 teco-ops **原生测试框架**（`README.md` / `doc/README_OP.md` 官方路径）：

```bash
# 1) 构建算子库
cd <teco-ops 仓库根>
source /opt/tecoai/setvars.sh
bash build.sh --build teco                    # -> build/teco/lib/libteco_ops.so

# 2) 构建测试框架
cd test && source env.sh && bash build.sh --arch teco -f "<op>"
#   ⚠️ test/env.sh 的 TECOAL_TECOTEST_PROJECT 是 demo 定位 Python golden 的必需环境变量

# 3) 运行 case
./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
    --case_path=zoo/teco/<op>/test_case/<case>.prototxt
```

**可信指标**：`[Average Hardware Time  ]: <ms>`（仅 kernel 硬件执行时间）。忽略 Interface/Launch Time。
**正确性判定**：demo 打印 `ALL PASSED` 且 `max_error` ≤ prototxt 内 `test_param.error_threshold`（本项目用 DIFF1/1e-4）。两者同时满足才算有效。

行为约定：`--warm_repeat=3` 预热、`--perf_repeat=50` 重复取平均；`--case_path` 支持任意 prototxt（可测多 shape）。

### 一键脚本
```bash
bash .opencode/skills/sdaa-op-eval/scripts/bench_op.sh <repo_root> <op> <case_ids...>
# 例：bench_op.sh /path/to/teco-ops-juzhenjisuan flash_attention 0 1 2 3 4 5
#     bench_op.sh /path/to/teco-ops-juzhenjisuan reshape_and_cache case_0 case_1 case_2
```
输出：每 case 的 `Average Hardware Time (ms)`、`Speedup vs baseline`（可传 `BASELINE_MS_<case>` 环境变量）+ `PASS/FAIL`。

---

## 二、精度评估（accuracy）

用 tecovllm-modelzoo 官方 CI 评测（`tools/ci_pipline/epi_eval.py`，`run_ci.py` 对 OneGenomeRice 同路径）。

### 2.1 前置：服务必须加载被测 lib（关键）
1. 重建并安装 lib 到 **vLLM TP worker 实际加载的位置**：
   ```bash
   bash .opencode/skills/sdaa-op-eval/scripts/install_lib.sh <repo_root> [site_packages_tecoops]
   # 默认安装到 api/tecoops/libteco_ops.so 与 /home/py312/lib/python3.12/site-packages/tecoops/
   # 脚本会打印 md5 供核对
   ```
2. 重启 vLLM，确认 worker 日志出现：
   `Using tecoops flash_attn_varlen_func via BlockAttention backend`
   （没有这行 = 没走被测内核，评测无效）

### 2.2 快速自检（服务与内核是否正常）
```bash
bash .opencode/skills/sdaa-op-eval/scripts/verify_serve.sh <host> <port>
```
- 等待 `/health` 200 → 查 `/v1/models`
- 发一次贪心 completion，**生成文本必须非空**；若为空/报 detokenizer `TypeError`，说明 kernel 溢出产生 NaN（如 no-max softmax 的 FP16 溢出），需先修 kernel。

### 2.3 跑评测
```bash
bash .opencode/skills/sdaa-op-eval/scripts/eval_accuracy.sh <modelzoo_root> <host> <port> [max_samples] [workers]
# 例：eval_accuracy.sh /path/to/tecovllm-modelzoo-juzhenjisuan 127.0.0.1 7777 200 32
```
底层命令（等价）：
```bash
python tools/ci_pipline/epi_eval.py --host <host> --port <port> --max-samples 200 --workers 32
```

**评测语义**（`epi_eval.py`）：
- 数据集 RiceBenchmark/Epigenetic_Marks_Prediction-Histone（10000 序列，取前 N）；
- 每序列 `prompt = seq[:-100]`，`temperature=0`（贪心）续写，取前 100bp 逐碱基比对；
- 指标 `overall_accuracy = 总匹配 / 总预测`；另输出 per-position 精度、mean/median、失败数（空/None 生成）；
- 结果存 `tools/ci_pipline/prec_logs/OneGenomeRice_<ts>/epi_eval_results.json`。

### 2.4 判定标准（本项目）
| 基线 | 容忍范围 | 实测示例 |
|---|---|---|
| **0.9120** | **[0.9020, 0.9220]**（±0.01） | 0.9163 / 0.9179 / 0.9185 → PASS（0 失败） |

---

## 三、完整交付流程（推荐顺序）

```bash
# 1. 正确性 + 性能（所有 case 都要 ALL PASSED）
bash .../bench_op.sh $REPO flash_attention 0 1 2 3 4 5
bash .../bench_op.sh $REPO reshape_and_cache case_0 case_1 case_2

# 2. 安装被测 lib 到服务
bash .../install_lib.sh $REPO

# 3. 重启 vLLM 服务（7777），确认日志 Using tecoops ... BlockAttention

# 4. 精度自检 + 评测
bash .../verify_serve.sh 127.0.0.1 7777
bash .../eval_accuracy.sh $MODELZOO 127.0.0.1 7777 200 32

# 5. 判定：性能达标 & accuracy ∈ [0.9020, 0.9220]
```

---

## 四、常见坑（详见 lessons/learned.md）

1. `TECOAL_TECOTEST_PROJECT` 缺失 → demo 无法定位 golden，所有 kernel 呈现相同错误码（表现为 max_error 恒定失败）。
2. 测试环境 SPM 堆 ≠ 服务端 SPM 堆：加双缓冲/大 LDM 的改动可能在服务端 `spm malloc failed`（kernel 早退 → 输出垃圾），**必须过精度评测**。
3. kernel 溢出 → vLLM 空输出 / detokenizer `TypeError: StreamInput must be an integer`（NaN token id）。
4. 检查服务用的是哪份 lib：TP worker 进程（非 API server 进程）加载 `site-packages/tecoops/libteco_ops.so`，改后必须重启整个 vLLM。
5. 并发的外部进程可能覆盖 repo 内核/lib/报告——改动后立刻 `md5sum` 核对并紧接验证。

## 五、文件布局

```
sdaa-op-eval/
├── SKILL.md                      # 本文件（入口）
├── references/
│   └── evaluation_methodology.md # 详细方法、命令全文、判定标准
├── scripts/
│   ├── bench_op.sh               # 性能一键（build+跑所有 case+输出表）
│   ├── install_lib.sh            # 重建+安装 lib（api/tecoops + site-packages）
│   ├── verify_serve.sh           # 服务健康+tecoops 确认+单次生成自检
│   └── eval_accuracy.sh          # 精度评测封装
└── lessons/
    └── learned.md                # 踩坑记录与诊断方法
```