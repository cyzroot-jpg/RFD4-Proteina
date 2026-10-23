# linshi — RFD4-Proteina SDAA 适配工作区

本目录是适配过程中的临时/评测工作区，不进入源码 patch。

| 子目录 | 内容 |
| --- | --- |
| `env/` | 平台、驱动、pip freeze、Boost 兼容链接 |
| `logs/` | 所有生成/评测任务日志 |
| `work/` | 生成结果、离线评测结果、运行脚本、spec |
| `eval_script/` | 官方评测入口的包装脚本、汇总脚本与说明 |
| `pc_report/` | 主评测报告（指标表 + 性能） |
| `zonghe_report/` | 数据集、指标、权重综合报告 |
| `change_report/` | 依赖、踩坑、代码改动报告 |
| `agent_guid/` | Agent 在 CPU/CUDA/SDAA 上运行评测的指南 |

源码改动与 patch 在仓库根目录的 `SDAA/patches/`。

## 关键结果目录

- `work/gen_default/{short,medium,long}`：unconditional monomer
- `work/gen_motif_indexed`：indexed motif scaffolding（2 reps，inline 指标）
- `work/gen_ppi`：PD-L1 binder（2 reps，离线 design 指标）
- `work/gen_ppi_metrics`：PD-L1 binder（1 rep，inline hotspot/interchain 指标）
- `work/eval_monomer`：3 个 monomer 的官方离线指标
- `work/eval_ppi_design2`：2 个 PPI 设计的官方离线 design 指标

## 快速复现

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src

# 生成
SDAA_VISIBLE_DEVICES=0 bash linshi/eval_script/run_gen.sh \
  ./linshi/work/gen_default/short \
  data/benchmarks/monomer/monomer-short.cif.zst

# 官方指标
bash linshi/eval_script/run_eval.sh \
  ./linshi/work/eval_short_design \
  ./linshi/work/gen_default/short/inference_samples \
  "metrics_tags=[design,developability]" \
  metrics/inline_metrics=all_inline_metrics_no_rosetta

# 汇总
python linshi/eval_script/summarize.py \
  linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv
```