# 评测脚本说明

## 1. 是否官方提供

**是。** 项目官方提供评测入口：

- CLI：`rfd4-evaluate`（`pyproject.toml` 的 `[project.scripts]`）
- 实现：`src/rfproteina/evaluate.py`
- 配置：`configs/evaluate.yaml` + `configs/metrics/all_metrics.yaml`
- 文档：`docs/how-to/evaluate-with-metrics.md` 与
  `docs/how-to/advanced/offline-metrics.md`

本目录中的 `run_eval.sh` 只是对官方 CLI 的一层薄包装，用于固定本机
`PYTHONPATH`、`.env.local` 与 `HF_HUB_OFFLINE`，不改变评测逻辑。
生成脚本放在 `linshi/work/run_gen.sh` 与 `linshi/work/run_gen_metrics.sh`，
它们同样只是对官方 `rfproteina.generate` 的包装。

`summarize.py` 只做 CSV 聚合展示，不定义或重算任何指标。

## 2. 脚本用途

| 脚本 | 位置 | 用途 |
| --- | --- | --- |
| `run_eval.sh` | 本目录 | 对已有结构运行官方 `rfd4-evaluate` |
| `summarize.py` | 本目录 | 把多个 `per_example_metrics.csv` 汇总成 markdown 表 |
| `run_gen.sh` | `linshi/work/` | 用 `quickstart` 预设做生成（无 inline metrics） |
| `run_gen_metrics.sh` | `linshi/work/` | 用 `inference_on_user_inputs` + `compile_lengths=null` 生成，并组合官方 metrics group，用于需要输入注释的 inline 指标 |

## 3. 使用的指标

全部来自官方 `configs/metrics/all_metrics.yaml`，通过官方 `metrics_tags` 启用：

| 场景 | tags |
| --- | --- |
| Unconditional monomer | `[design, developability]`（离线） |
| Motif scaffolding | `[design, 3d_coordinate_conditioning]`（inline） |
| PPI binder | `[design, hotspot_conditioning, interchain_interactions]`（inline） |

本机没有 PyRosetta 容器，因此 developability 使用官方
`sequence_developability` 子集；对应配置
`configs/metrics/inline_metrics/all_inline_metrics_no_rosetta.yaml`，仅移除
`rosetta_developability`，其余官方指标不变。

本机没有 AF3/OF3 运行时，因此未启用 `*_refolding` tags；scRMSD、pLDDT、
ipTM/ipAE 与 pass rate 不在本次结果中。

## 4. 使用示例

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina

# 生成
SDAA_VISIBLE_DEVICES=0 bash linshi/work/run_gen.sh \
  ./linshi/work/gen_default/short \
  data/benchmarks/monomer/monomer-short.cif.zst

# 官方离线指标
bash linshi/eval_script/run_eval.sh \
  ./linshi/work/eval_short_design \
  ./linshi/work/gen_default/short/inference_samples \
  "metrics_tags=[design,developability]" \
  metrics/inline_metrics=all_inline_metrics_no_rosetta

# 汇总
python linshi/eval_script/summarize.py \
  linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv
```