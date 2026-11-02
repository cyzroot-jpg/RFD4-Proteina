# Plan A：让 SDAA 与 CUDA 走同一条数值路径

目标：把两边的差异压到最小。做法是把 CUDA 的融合注意力换成 SDAA 的物化 einsum，
并统一三角乘和确定性设置，其它参数完全不变。

| 项目 | 设置 |
| --- | --- |
| 注意力 | `RFPROTEINA_ABLATE=force_einsum`（CUDA 侧生效；SDAA 本来就是）
| 三角乘 | `nn.tri_mult_backend=torch` |
| 确定性 | `torch_deterministic=true` |
| 精度 / seed / 采样 | 与主实验一致：`bf16-mixed`、`seed=1234`、thinking_medium、eager |
| 输入 / replicates / tags | 与主实验一致（官方 benchmark 输入、8/6/4/8/6） |

预期：monomer-short 的 design identity 从 **0.68 → ~0.89**、design RMSD 从 **1.16 → ~0.12 Å**；
不会到 1.0（剩余为 tecoblas vs cuBLAS）。motif/PPI 不保证改善。

---

## SDAA 侧（已由本机后台运行）

```bash
# 5 个任务并行，每个占一张物理卡（DEVICE 是卡槽：1..5 -> 物理卡 1..5）
OUT_ROOT=$PWD/run_sdaa/results_planA/sdaa TORCH_SDAA_ALIGN_NV_DEVICE=a100 \
  bash run_sdaa/experiments/run_plan_a.sh <task>
```

产物：`run_sdaa/results_planA/sdaa/<task>/{inference_samples,inference_metrics,generate.log,run_info.txt}`。

跑完打包给 CUDA：

```bash
mkdir -p /tmp/planA
tar czf /tmp/planA/sdaa_planA_designs.tgz -C run_sdaa/results_planA/sdaa \
  monomer-short/inference_samples monomer-medium/inference_samples monomer-long/inference_samples \
  motif-1BCF/inference_samples ppi-pdl1/inference_samples
```

---

## CUDA 侧（明天执行）

```bash
# 1) 同步脚本（排除 out/）
rsync -av --exclude '__pycache__' --exclude 'out/' \
  /data01/tuyilist/cyz/RFD4-Proteina/run_sdaa/experiments/ \
  <cuda-host>:/path/to/RFD4-Proteina/run_sdaa/experiments/

# 2) 同步 SDAA Plan A 设计
rsync -av /tmp/planA/sdaa_planA_designs.tgz \
  <cuda-host>:/path/to/RFD4-Proteina/run_sdaa/

# 3) CUDA 上解包并运行（一条命令完成生成 + 双边 refold + 对比）
cd /path/to/RFD4-Proteina && source .venv/bin/activate && export PYTHONPATH=src
export AF3_IMAGE=... AF3_MODEL_DIR=... AF3_JAX_CACHE_DIR=...

mkdir -p run_sdaa/results_planA/sdaa
tar xzf run_sdaa/sdaa_planA_designs.tgz -C run_sdaa/results_planA/sdaa

SDAA_ROOT=$PWD/run_sdaa/results_planA/sdaa \
OUT_ROOT=$PWD/run_sdaa/results_planA/cuda \
ORACLE=of3 \
  bash run_sdaa/experiments/run_plan_a_cuda.sh
```

脚本会：

1. 用 Plan A 生成 CUDA 的 5 个任务（若已存在则跳过）；
2. 用同一个 oracle refold **CUDA 设计**和 **SDAA 设计**；
3. 跑 E1（identity / design RMSD）；
4. 跑 A/B 类指标对比；
5. 额外与默认路径的 SDAA（`run_sdaa/results_aligned/sdaa`）对比 A 类。

---

## 产物与判读

```text
run_sdaa/results_planA/
├── sdaa/<task>/          # SDAA Plan A 设计 + A 类指标
├── cuda/<task>/          # CUDA Plan A 设计 + A 类指标
│   └── evaluation/       # CUDA 设计的 refold（B 类）
├── sdaa_eval/<task>/     # SDAA 设计的 refold（B 类，同一 oracle）
├── compare/
│   ├── E1/               # identity / design RMSD
│   ├── metrics/          # A/B 均值对比（compare.md、metrics_compare.csv）
│   └── vs_default_sdaa/  # CUDA Plan A vs 默认 SDAA 的 A 类
└── logs/
```

判读：

| 结果 | 含义 |
| --- | --- |
| E1 identity 接近 1、design RMSD → 0 | Plan A 基本消除了设计差异 |
| identity ~0.89、RMSD ~0.12 Å | 注意力已对齐，剩余是 BLAS 差异（预期） |
| identify 仍 ~0.68 | Plan A 未生效（检查 CUDA 日志里是否有 `[ablate] forced explicit einsum attention`） |
| B 类 `metrics_compare.csv` 差异落在 oracle 2σ 内 | B 类差异主要来自设计不同 |
| PPI 仍差 | 符合预期：PPI 不是 attention 驱动，且含退化设计/抽样 |

---

## 回传

把 `run_sdaa/results_planA/compare/`（`E1/`、`metrics/`、`vs_default_sdaa/`）和
`run_sdaa/results_planA/cuda/<task>/inference_metrics/per_example_metrics.csv` 回传即可。

## 成本

- CUDA：生成约几分钟，refold 约 30–60 分钟（取决于 oracle）；
- SDAA：5 任务并行约 2–3 小时（已后台执行）。