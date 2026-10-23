# SDAA 算子评估方法论（完整指令与判定标准）

本文件是 `sdaa-op-eval` skill 的详细方法参考，覆盖性能（`[Average Hardware Time]`）与精度（`accuracy`）两条评估路径的每一步。所有命令均在本项目环境中实测。

---

## 1. 环境要求

| 项 | 值 |
|---|---|
| TECO 工具链 | source `/opt/tecoai/setvars.sh`（提供 tecocc、SDAA runtime、`LD_LIBRARY_PATH=/opt/tecoai/lib64` 等） |
| Python | `/home/py312/bin/python3`；依赖 torch / numpy / requests / tqdm |
| 测试库依赖 | teco-ops 仓库 `build/teco/lib/libteco_ops.so`；demo 额外需要 torch lib |

仓库结构：
```
teco-ops-juzhenjisuan/          # 算子仓库（teco/ 的 .scpp 为被测目标）
├── build.sh                    # 构建 teco 算子库
├── teco/ual/kernel/<op>/       # 被测 kernel .scpp
└── test/                       # 原生 C++ 测试框架
    ├── build.sh
    └── zoo/teco/<op>/test_case/*.prototxt   # 每个 shape 一个 case
tecovllm-modelzoo-juzhenjisuan/ # 模型仓库（精度评测入口）
└── tools/ci_pipline/epi_eval.py
```

---

## 2. 性能评估（Hardware Time）——完整指令

### 2.1 构建算子库
```bash
cd teco-ops-juzhenjisuan
source /opt/tecoai/setvars.sh
bash build.sh --build teco
# 产物: build/teco/lib/libteco_ops.so
```

### 2.2 构建测试框架
```bash
cd test
source env.sh          # 导出 TECOAL_TECOTEST_PROJECT=$PWD，demo 定位 Python golden 必需
bash build.sh --arch teco -f "flash_attention;reshape_and_cache"
# 产物: test/build/demo
```

### 2.3 运行单个 case
```bash
cd test
./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
  --case_path=zoo/teco/flash_attention/test_case/1.prototxt
```

关键输出（采纳红色标注）：
```
[Average Interface Time  ]: 3.6901 (ms)    ← 忽略（含张量准备）
[Average Hardware Time   ]: 2.0317 (ms)    ← 采纳：kernel 纯硬件执行时间
[Average Launch Time     ]: 3.688 (ms)     ← 忽略
max_error: 1.89e-4                          ← 正确性指标（应 ≤ threshold）
...
ALL PASSED.                                 ← 正确性判定
```

### 2.4 判定规则
- **正确性**：`ALL PASSED` 且 `max_error` ≤ prototxt `test_param.error_threshold`（本仓库 case 为 DIFF1，阈值 1e-4 量级；proto 里同时有 error_thresholds 多档，demo 采用生效档）。
- **性能**：只记录 `[Average Hardware Time]`；`--warm_repeat=3` 预热、`--perf_repeat=50` 平均；同一 case 多次测量波动一般 <2%。
- **切换被测 kernel**：把候选 `.scpp` 覆盖安装到 `teco/ual/kernel/<op>/xxx.scpp` → 重跑 2.1/2.2/2.3。一次一座标（保持接口签名不变）。

### 2.5 候选 kernel 验证技巧（归因/剖析）
对候选同时跑"禁用子阶段"的对照版，可反推各阶段贡献（示例来自 flash_attention）：
- 移除 softmax 调用 → 差量 ≈ softmax 总成本
- 移除 K 转置（连续 memcpy 替代）→ 差量 ≈ 转置成本
- 移除 PV / QK matmul → 差量 ≈ 对应 matmul 成本
> 注意：这类"剥离诊断"的数值是**上界/近似**——剥离一个阶段会改变下游数据流与调度，切勿当作精确占比；结论要多次对照确认。

---

## 3. 精度评估（accuracy）——完整指令

### 3.1 前置（关键）：服务必须加载被测 lib
1. 重建并安装：
   ```bash
   bash .opencode/skills/sdaa-op-eval/scripts/install_lib.sh <teco-ops 根> \
        /home/py312/lib/python3.12/site-packages/tecoops
   ```
   说明：vLLM 的 TP worker（非 API server 进程）通过 `import tecoops` 加载
   `site-packages/tecoops/libteco_ops.so`；`api/tecoops/` 是 demo 仓库内副本，同步更新以便核对 `md5sum`。
2. 重启 vLLM（完整 kill 掉 API server + EngineCore + Worker_TP*，再启动），
   确认启动日志：`Using tecoops flash_attn_varlen_func via BlockAttention backend`。
   - 若没有这行：说明走的是别的 attention 路径，评测无效。

### 3.2 服务自检（防"假通过/假失败"）
```bash
bash .../verify_serve.sh 127.0.0.1 7777
```
- health → /v1/models → 一次 `temperature=0` 贪心生成。
- **生成文本必须非空**。空输出 = kernel 产生 NaN（典型：detokenizer 报
  `TypeError: argument 'id': StreamInput must be an integer or a list of integers`，
  或服务日志 `spm malloc failed`）。

### 3.3 运行评测
```bash
cd tecovllm-modelzoo-juzhenjisuan
python tools/ci_pipline/epi_eval.py --host 127.0.0.1 --port 7777 --max-samples 200 --workers 32
```

**评测语义**（`epi_eval.py`）：
1. `ensure_dataset`：本地 `/nvmedata/application/juzh/RiceBenchmark/Epigenetic_Marks_Prediction-Histone/test.jsonl`（10000 序列，缺失则从 ModelScope 下载）。
2. `load_sequences(test_file, 200)`：取前 200 条。
3. `run_completion`：每序列 `prompt = seq[:-100]`（预测最后 100bp），32 worker 并发调
   `/v1/completions`，`temperature=0`、`max_tokens=100*2+10=210`；结果清洗为只含 A/C/G/T 并取前 100bp。
4. `compute_metrics`：逐位置匹配
   - `overall_accuracy = Σ命中碱基 / Σ预测碱基`
   - 另输出 mean/median/std/range、per-position accuracy、n_failed（空/None 生成计 0）。
5. 保存 `tools/ci_pipline/prec_logs/OneGenomeRice_<ts>/epi_eval_results.json`。

**命令行等价**：
```bash
bash .../eval_accuracy.sh <modelzoo 根> 127.0.0.1 7777 200 32 0.9120
```

### 3.4 判定标准
| 基线 | 允许范围 | 本项目 v4 实测（多次复测） |
|---|---|---|
| 0.9120 | [0.9020, 0.9220]（±0.01） | 0.9163 / 0.9179 / 0.9185 → PASS；0 失败样本 |

> 不会因为 `Failed: 0` 就放行低分：accuracy 必须落在区间内。
> 空文本在 `compute_metrics` 里按 0 分计（本技能对 `epi_eval.py` 做了该健壮化，避免 ZeroDivisionError）。

---

## 4. 完整验收流程（推荐顺序）

```bash
# A. 性能 + 正确性（被测 kernel 已写入仓库）
bash .../bench_op.sh $TECO_OPS flash_attention 0 1 2 3 4 5
bash .../bench_op.sh $TECO_OPS reshape_and_cache case_0 case_1 case_2

# B. 安装被测 lib 并重启服务
bash .../install_lib.sh $TECO_OPS
#   (kill 全部 vllm/Worker_TP*, 重启 vllm serve ... --port 7777)

# C. 精度验收
bash .../verify_serve.sh 127.0.0.1 7777
bash .../eval_accuracy.sh $MODELZOO 127.0.0.1 7777 200 32 0.9120
```

**通过条件**：所有 case `ALL PASSED` & 性能有提升（或符合预期）& `accuracy ∈ [0.9020, 0.9220]`。

---

## 5. 数据记录格式（建议存档）

```text
操作: <op>/<kernel.scpp>
基线: case_X = 3.56520 ms (原始仓库)
优化: case_0 = 0.71593 ms (2.12x), case_1 = 2.03170 ms (1.75x), ...
精度: accuracy = 0.9185 (基线 0.9120, +0.0065, PASS, failed=0)
方法: <简略列出本轮采用的优化手段>