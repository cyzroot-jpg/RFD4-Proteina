# RFD4-Proteina SDAA 适配：数据集、指标与权重综合报告

## 1. 平台与软件环境

| 项目 | 值 |
| --- | --- |
| 平台 | Teco SDAA (TECO_AICARD_01) |
| CPU 架构 | `loongarch64` |
| Python | 3.12.13 |
| PyTorch | 2.12.0 |
| Torch-SDAA | 3.3.0 |
| SDAA Driver / Runtime | 3.3.0 / 3.3.0 |
| SDAA 设备数 | 32 logical devices (每卡 4 个，单设备约 16 GB) |
| 项目 commit | `6fc44c060ef96d4c759bafeaa1eae1a66a5be67c` |

关键 Python 包（LoongArch 环境）：

| 包 | 版本 | 来源 |
| --- | --- | --- |
| atomworks | 3.0.4 | PyPI |
| biotite | 1.7.1 | 预装 LoongArch 构建（运行期由兼容层按 1.6.0 API 呈现） |
| biotraj | 1.2.2 | 本地 LoongArch wheel |
| rdkit | 2026.9.1 | `loongarch_packages` |
| openbabel | 0.1.dev6623 | `loongarch_packages` |
| numpy | 1.26.4 | LoongArch wheel（与 rdkit 构建 ABI 对齐） |
| scipy | 1.15.3 | LoongArch wheel |
| pandas | 2.3.3 | PyPI |
| lightning | 2.6.6 | PyPI |
| hydra-core | 1.3.7 | PyPI |
| transformers | 5.12.1 | PyPI |
| pyarrow | 23.0.1 | LoongArch wheel |

## 2. 模型权重

官方发布权重来自 Hugging Face：

- Repo: `nvidia/RFD4-Proteina`
- Revision: `a06e2509c7033b010fc43614e9fd840303588502`
- 文件：`config.json` + `model.safetensors`（约 1.74 GB，FP32，内含 autoencoder 配置与权重）
- 本地缓存（本次评测使用）：
  `/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502`

原项目 `configs/inference.yaml` 默认从 Hub 读取该 revision；本次通过
`hf_ckpt_path=<本地 snapshot 目录>` 指向同一份权重，避免评测时联网。

官方 native checkpoint（若使用 `hf_ckpt_path=null`）：

- Flow: `rfd4-proteina-flow-release-2026-10-19.ckpt`
- Autoencoder: `rfd4-proteina-ae-release-2026-10-19.ckpt`
- 预期路径：`$DATA_PATH/flow_checkpoints/` 与 `$DATA_PATH/ae_checkpoints/`

## 3. 数据集

本次评测使用官方仓库/官方 HF dataset 中自带的 benchmark 输入：

| 任务 | 数据集 | 路径 | 说明 |
| --- | --- | --- | --- |
| Unconditional monomer (100 aa) | `monomer-short` | `data/benchmarks/monomer/monomer-short.cif.zst` | 官方 unconditional 验证集之一 |
| Unconditional monomer (150 aa) | `monomer-medium` | `data/benchmarks/monomer/monomer-medium.cif.zst` | 同上 |
| Unconditional monomer (250 aa) | `monomer-long` | `data/benchmarks/monomer/monomer-long.cif.zst` | 同上 |
| Indexed motif scaffolding | `1BCF_AA` | `data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst` | 官方 motif scaffolding 验证集 |
| Protein binder (PD-L1) | `5o45_cropped` + `binder.yaml` | `docs/examples/inputs/5o45_cropped.cif.zst` | README/cookbook 官方 binder 示例 |

官方 unconditional 验证配置为
`configs/datasets/val/unconditional.yaml`，每个输入默认 50 replicates；motif indexed
配置为 `configs/datasets/val/motif_scaffolding/indexed_motif_scaffold_full.yaml`，默认
100 replicates。本次为在单机 SDAA 上完成可复现评测，使用 1–2 replicates（见性能报告），
这是预算缩减，不是指标定义变化。

## 4. 评测指标（全部来自官方配置）

官方评测入口：`rfd4-evaluate`（`src/rfproteina/evaluate.py`），指标组来自
`configs/metrics/all_metrics.yaml`，由 `metrics_tags` 控制启用。

### 4.1 本次可计算的官方面向设计指标

| 指标 key | 官方 tag | 含义 | 输出列 |
| --- | --- | --- | --- |
| `amino_acid_composition` | 始终 | 生成序列中 UNK 数、标准残基数、ALA/VAL/GLY 比例 | `n_generated_unknown_residues`, `n_standard_residues`, `ala_fraction`, `val_fraction`, `gly_fraction` |
| `bond_length_metrics` | `design` | 键长不合理的键比例（按元素相关阈值） | `bond_length.frac_unreasonable` 及分类细分 |
| `clash_metrics` | `design` | 1.5 Å 处原子空间冲突比例（按 polymer/ligand、intra/inter 细分） | `frac_atoms_clashing_1p5A` 等 |
| `sequence_adherence` | `design` | 序列条件残基的生成一致性；无条件生成时为 NaN | `sequence_adherence`, `n_violations` |
| `sse_distribution` | `design` | P-SEA 计算的 helix/sheet/loop 比例与连续 SSE 数 | `helix_fraction`, `sheet_fraction`, `loop_fraction`, `num_ss_elements` |
| `sequence_developability` | `developability` | 设计链的 GRAVY 与 Guruprasad instability index | `gravy`, `instability_index` |
| `hotspot_obedience` | `hotspot_conditioning` | hotspot 原子 4.5 Å 内有 binder 原子的比例 | `hotspot_obedience` |
| `interchain_interactions` | `interchain_interactions` | 链间 H-bond、π-stacking、π-cation、salt bridge、hydrophobic、metal 的依从性与计数 | `*_conditioning_adherence`, `*_count_coi` 等 |
| `design_motif_allatom_rmsd` | `3d_coordinate_conditioning` | 设计内部 motif 区域全原子 RMSD（自一致性） | `rmsd` |

### 4.2 因外部运行时而未计算的官方指标

以下指标属于官方评测协议，但需要本机不存在的外部依赖，因此本次未计算，报告中明确标注：

| 指标/组 | 依赖 | 原因 |
| --- | --- | --- |
| `refolding_oracles` / `refolded_*_rmsd` / `*.pass` | AlphaFold 3 (OpenFold3) apptainer + 权重 + JAX 缓存 | 本机未安装 apptainer，也没有 AF3/OF3 运行时与权重 |
| `rosetta_developability` | PyRosetta apptainer (`$PYROSETTA_CONTAINER`) | 本机未提供 PyRosetta 容器 |

因此本次主表报告 **design / developability / hotspot / interchain / motif RMSD**
一类无需 refolding 的官方指标；scRMSD、pLDDT、ipTM/ipAE 与 pass rate 不能在本机给出。
这不是用自造指标替代官方指标。

## 5. 官方评测流程

```bash
# 生成（示例：unconditional monomer）
rfd4-generate inputs=data/benchmarks/monomer/monomer-short.cif.zst \
    num_replicates=1 out_dir=./runs/monomer-short

# 离线指标（官方 evaluate 入口）
rfd4-evaluate inputs=./runs/monomer-short/inference_samples \
    metrics_tags='[design,developability]' out_dir=./eval/monomer-short
```

对于需要输入结构才能计算的指标（motif RMSD、hotspot obedience、interchain
interactions），官方推荐在生成时直接传 `metrics_tags`，让指标在生成管线内计算；
本次对这些任务使用了该方式。原因：生成输出默认不保存 `_input.cif`，离线
`evaluate.py` 无法恢复条件注释。

## 6. 仓库中已有的官方评测结果

仓库自带一份**官方已审阅的 benchmark 结果表**，位于 `website/benchmarks/`（快照
2026-10-21，来源 `kierandidi/RFD4-Proteina-paper`）：

| 文件 | 内容 |
| --- | --- |
| `coverage.csv` | Figure 2 聚合结果：每个 model/protocol/benchmark 的 targets、attempts、passes、clusters、pass_percent、clustered_percent、solved、mean_seconds |
| `source_data.csv` | 逐 target/run 的原始结果（3073 行），含 pass/cluster、generation/AF3 GPU 秒、successes_per_gpu_hour 等 |
| `data.json` | 网站 explorer 数据：meta、模型说明、protocol、逐行结果 |
| `scatter.csv` / `target-labels.csv` | Figure 2 散点图与 target 标签 |
| `benchmark-notes.mjs` / `protocols.mjs` / `metrics.mjs` | benchmark 选择理由、protocol、指标定义 |
| `docs/_static/benchmark-success-rate.png` / `benchmark-figure.webp` | 论文/网站 benchmark 图 |

`coverage.csv` 中 RFD4-Proteina（high, one-shot）的 Figure 2 结果：

| benchmark | targets | attempts | passes | clusters | pass % | clustered % | solved |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| PPI backbone | 24 | 4800 | 926 | 510 | 19.29 | 10.63 | 22/24 |
| Small molecule (unfixed) | 77 | 15400 | 5280 | 2205 | 34.29 | 14.32 | 77/77 |
| MCSA fixed | 37 | 7400 | 1087 | 893 | 14.69 | 12.07 | 35/37 |
| DNA unfixed | 3 | 600 | 21 | 21 | 3.50 | 3.50 | 3/3 |

另外，`source_data.csv` 还包含 `ppi_all_atom`、`mcsa_unfixed`、`dna_fixed`、
`studio_figure_2c_fixed` 以及 low/medium/high/search 各档结果。

回归基线（不是 benchmark pass rate）：

- `tests/e2e/baselines/inference/cuda13/designed.cif.gz`：CUDA 13 / H200 对
  MCSA `M0664_2dhn` 的官方参考设计，RMSD 容差 0.20 Å。
- `tests/e2e/baselines/beam_search/metrics.json`：seed 42 的 motif RMSD
  `[0.1211, 0.1227]`。
- `tests/e2e/baselines/{ae,sota,lora}_training/losses.json`：训练 loss 基线。

注意：这些官方结果使用 AF3/OF3 oracle、官方完整 protocols 和 50–200 次
replicates；本次 SDAA 报告是 1–2 replicates、无 oracle 的缩减评测，**不能直接
把本次的 design 指标与上面的 pass% 对比**。可对比的是同一指标定义下的几何/序列
质量（如 bad bond、clash、motif RMSD），pass rate 需要先补齐 oracle。

## 7. 结果文件位置

- 生成结构与 `per_example_metrics.csv`：`linshi/work/gen_*`
- 离线评测：`linshi/work/eval_*`
- 性能记录：各运行目录下 `inference_metrics/resource_usage.json` 与
  `resource_usage_batches.csv`
- 主结果表：`linshi/pc_report/README.md`