# Agent 运行评测指南（CPU / CUDA / SDAA）

目标：让 agent 在任意受支持平台上，用同一条命令形状完成生成与官方指标评测，
并输出同构的结果目录，便于横向比较。

## 0. 平台识别

```bash
# SDAA
command -v teco-smi && teco-smi | head -20
python -c "import torch, torch_sdaa; print('sdaa', torch.sdaa.device_count())"

# CUDA
command -v nvidia-smi && nvidia-smi -L

# CPU
python -c "import torch; print('cuda', torch.cuda.is_available())"
```

本仓库的 SDAA 兼容层在 `import rfproteina` 时自动检测：
- 有真实 CUDA 设备：不启用 SDAA。
- 无 CUDA、有 `torch_sdaa`：自动启用 CUDA→SDAA 迁移。
- 设置 `RFPROTEINA_DISABLE_SDAA=1`：强制 CPU（在 SDAA 机器上也可用）。

## 1. 环境准备

### SDAA（本机已验证）

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh      # 读取 .env.local
export PYTHONPATH=src
```

`.env.local` 至少包含：

```bash
DATA_PATH=/data01/tuyilist/cyz/rfd4_assets/data_path
HF_HOME=/data01/tuyilist/cyz/rfd4_assets
HF_HUB_CACHE=/data01/tuyilist/cyz/rfd4_assets/hf_cache
HF_HUB_OFFLINE=1
```

本机权重已缓存；否则先 `bash scripts/download_assets.sh "$DATA_PATH" --skip-of3`。

### CUDA

```bash
cd /path/to/RFD4-Proteina
bash setup.sh --native            # 或按 README 使用 uv/pip
source .venv/bin/activate
```

### CPU

```bash
bash setup.sh --native
source .venv/bin/activate
export RFPROTEINA_DISABLE_SDAA=1
```

CPU 上把 `precision=32`，并把 `hardware.accelerator=cpu`。CPU 只适合烟测，
不适合大规模生成。

## 2. 权重选择

优先使用官方 HF bundle（与 CUDA 评测一致）：

```bash
CKPT=nvidia/RFD4-Proteina
REV=a06e2509c7033b010fc43614e9fd840303588502
```

离线环境把 `CKPT` 指向本地 snapshot 目录：

```bash
CKPT=/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
```

## 3. 生成

统一命令形状：

```bash
PYTHONPATH=src python3 -m rfproteina.generate \
  inference_experiment=quickstart \
  inputs=<INPUT> \
  num_replicates=<N> \
  out_dir=<OUT_DIR> \
  hf_ckpt_path=<CKPT> \
  hardware.accelerator=<gpu|cpu> \
  [generation.args.nsteps=<S>] \
  [generation.n_recycle_schedule=<SCHEDULE>]
```

说明：

- `quickstart` 只关闭 compile 预热、默认不含 metrics group；不会改采样步数/recycle。
- 官方默认 `recycle_strategy=thinking_medium`（60 steps，180 trunk passes）。
- SDAA 上建议 `compile_lengths=null`（quickstart 已设置）。
- CPU 上额外加 `precision=32`。
- 多卡并行：SDAA 用 `SDAA_VISIBLE_DEVICES=<i>`，CUDA 用
  `CUDA_VISIBLE_DEVICES=<i>`。
- 需要 inline 指标（motif RMSD、hotspot、interchain）时，用：

```bash
PYTHONPATH=src python3 -m rfproteina.generate \
  inference_experiment=inference_on_user_inputs \
  compile_lengths=null \
  inputs=<INPUT> num_replicates=<N> out_dir=<OUT_DIR> \
  hf_ckpt_path=<CKPT> \
  metrics_tags='[design,3d_coordinate_conditioning]'
```

## 4. 官方指标评测

```bash
PYTHONPATH=src python3 -m rfproteina.evaluate \
  inputs=<OUT_DIR>/inference_samples \
  metrics_tags='[design,developability]' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta \
  out_dir=<EVAL_DIR>
```

- `metrics_tags` 必须使用官方 tag；不要自造指标。
- 有 PyRosetta 容器时可去掉 `metrics/inline_metrics=...` 覆盖，改用完整
  `developability_metrics`。
- 有 AF3/OF3 运行时且需要 scRMSD/pLDDT/ipTM/pass rate 时，把
  `unconditional_refolding` / `ppi_refolding` / `motif_scaffold_refolding`
  加入 tags，并设置 `AF3_IMAGE` / `AF3_MODEL_DIR` / `AF3_JAX_CACHE_DIR`。
- 离线评测默认不保存输入注释，因此 motif RMSD/hotspot/interchain 建议在生成时
  inline 计算（见上）。

## 5. 输出目录约定（三平台一致）

```
<OUT_DIR>/
  inference_samples/<example_id>/<example_id>_generated.cif
  inference_metrics/
    per_example_metrics.csv
    resource_usage.json          # wall time, samples/s, peak device memory, RSS, CPU%
    resource_usage_batches.csv

<EVAL_DIR>/
  evaluation_samples/
  evaluation_metrics/
    per_example_metrics.csv
    resource_usage.json
```

`resource_usage.json` 字段（三平台相同）：

| 字段 | 含义 |
| --- | --- |
| `wall_time_s` | 墙钟时间 |
| `cpu_time_s` | 进程 CPU 时间（user+sys） |
| `cpu_utilization_percent` | 进程 CPU 占用 / 核数 |
| `process_max_rss_bytes` | 进程峰值 RSS |
| `device_peak_memory_bytes` | 设备峰值分配显存（CPU 上为 null） |
| `num_examples` / `examples_per_second` | 样本数与吞吐 |

## 6. 结果核对清单

- 生成了预期数量的 `*_generated.cif`。
- `per_example_metrics.csv` 中包含所需指标列，不是只有 metadata。
- `pre_oracle_pass` 只有在提供 oracle 时才有意义；无 oracle 时不要把它当作
  pass rate。
- 报告里同时写清：数据集、replicates、tags、是否使用 oracle、是否使用
  no-rosetta developability 子集。

## 7. 本次实测命令

```bash
# SDAA，monomer
SDAA_VISIBLE_DEVICES=0 bash linshi/work/run_gen.sh \
  ./linshi/work/gen_default/short \
  data/benchmarks/monomer/monomer-short.cif.zst

# SDAA，官方指标
bash linshi/work/run_eval.sh \
  ./linshi/work/eval_short_design \
  ./linshi/work/gen_default/short/inference_samples \
  "metrics_tags=[design]"
```