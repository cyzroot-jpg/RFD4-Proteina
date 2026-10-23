# 本次评测的指标覆盖：测了什么、没测什么、为什么

## 0. 先说结论

- **不影响模型的正常工作。** Oracle（AF3/OF3 refold）只用于**生成之后的评测**，以及可选的 refold reward search；模型前向、采样、结构生成、序列生成都不依赖它。
- 本次已经完整跑通：**SDAA 推理 → 结构输出 → 官方 pre-oracle 设计指标**。
- 本次没有跑通：**oracle → refold metrics → pass criteria → FoldSeek clustered pass rate**。
  原因是本机没有 oracle 运行时（apptainer + AF3/OF3 镜像/权重）且没有 NVIDIA GPU，不是模型或适配代码的问题。
- 因此本次结果应表述为“**生成 + pre-oracle 设计指标评测**”，不能表述为“官方 benchmark pass rate 复现”。

---

## 1. 已评测的指标（全部来自官方指标实现）

评测入口：官方 `rfd4-evaluate`（`src/rfproteina/evaluate.py`）+ 官方 inline metrics
（`inference_on_user_inputs` + `metrics_tags`）。指标定义见
`configs/metrics/all_metrics.yaml` 和 `docs/reference/metrics.md`。

### 1.1 三个任务都测的通用设计指标

| 指标 key | 官方 tag | 含义 | 本次结果 |
| --- | --- | --- | --- |
| `amino_acid_composition` | 始终 | UNK 数、标准残基数、ALA/VAL/GLY 比例 | 所有设计 `n_generated_unknown_residues=0`；`n_standard_residues` 等于设计长度 |
| `bond_length_metrics` | `design` | 键长不合理的键比例（元素相关阈值） | 所有设计 `0.0000`（键表非空，已复核） |
| `clash_metrics` | `design` | 1.5 Å 内非键原子冲突比例，按 5 类细分 | 所有设计 `0.0000` |
| `sequence_adherence` | `design` | 序列条件残基的生成一致性 | monomer 为 `NaN`（无条件）；motif/PPI 为 `1.0`，`n_violations=0` |
| `sequence_probability_adherence` | `design` | 概率 0/1 序列约束的依从性 | motif/PPI `zero_adherence=1.0`、`one_adherence=1.0` |
| `sse_distribution` | `design` | P-SEA 的 helix/sheet/loop 比例与连续 SSE 数 | 见下方任务表 |
| `pre_oracle_pass` | 由 pre-oracle filters 产生 | 是否通过 **pre-oracle** 过滤（不是最终 pass） | 所有设计 `1.0` |

### 1.2 Unconditional monomer 额外指标

| 指标 key | 官方 tag | 含义 | 本次结果 |
| --- | --- | --- | --- |
| `sequence_developability` | `developability` | GRAVY 与 Guruprasad instability index | short/medium/long 的 GRAVY = -0.654/-0.507/-0.240；instability = 84.34/61.17/48.67 |

### 1.3 Motif scaffolding 额外指标

| 指标 key | 官方 tag | 含义 | 本次结果 |
| --- | --- | --- | --- |
| `design_motif_allatom_rmsd` | `3d_coordinate_conditioning` | 设计内部 motif 区域全原子 RMSD（自一致性，不是 refold 后 RMSD） | 1BCF_AA rep0 `0.1643 Å`，rep1 `0.1566 Å` |

### 1.4 PPI binder 额外指标

| 指标 key | 官方 tag | 含义 | 本次结果 |
| --- | --- | --- | --- |
| `hotspot_obedience` | `hotspot_conditioning` | hotspot 原子 4.5 Å 内有 binder 原子的比例 | `1.0000` |
| `interchain_interactions` | `interchain_interactions` | 链间 H-bond、π-stacking、π-cation、salt bridge、hydrophobic、metal 的依从性与计数 | H-bond 5 atoms / 6 pairs；salt bridge 3 res / 4 pairs；hydrophobic 10 atoms / 11 pairs；π-stacking、π-cation、metal 为 0 |

### 1.5 任务级结果汇总

| 任务 | 设计数 | n_res | bad_bond_frac | clash_frac | helix | sheet | loop | n_SSE | 其他 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| monomer-short | 1 | 100 | 0 | 0 | 0.410 | 0.260 | 0.330 | 13 | GRAVY -0.654, instability 84.34 |
| monomer-medium | 1 | 150 | 0 | 0 | 0.840 | 0 | 0.160 | 15 | GRAVY -0.507, instability 61.17 |
| monomer-long | 1 | 250 | 0 | 0 | 0.828 | 0 | 0.172 | 23 | GRAVY -0.240, instability 48.67 |
| motif 1BCF_AA | 2 | 131/124 | 0 | 0 | 0.870/0.863 | 0 | 0.130/0.137 | 9 | motif RMSD 0.164/0.157 Å |
| PPI PD-L1 | 2 + 1 inline | 169–209 | 0 | 0 | 0.28–0.39 (all) | 0.22–0.27 | 0.39–0.46 | 19–23 | COI helix 86–87%；hotspot 1.0；H-bond/salt bridge/hydrophobic 见上 |

### 1.6 性能记录（不是模型指标，但属于本次评测输出）

每个运行目录下：

- `inference_metrics/resource_usage.json`
- `inference_metrics/resource_usage_batches.csv`
- `evaluation_metrics/resource_usage.json`

记录的字段：`wall_time_s`、`cpu_time_s`、`cpu_utilization_percent`、
`process_max_rss_bytes`、`device_peak_memory_bytes`、`num_examples`、
`examples_per_second`。

---

## 2. 没有评测的指标

### 2.1 因缺少外部运行时（本机无法计算）

| 指标/组 | 官方配置 key / tag | 需要的依赖 | 为什么本机没有 |
| --- | --- | --- | --- |
| 全部 refolding metrics | `refolded_backbone_rmsd`、`refolded_target_aligned_binder_rmsd`、`refolded_target_backbone_aligned_binder_rmsd`、`refolded_motif_allatom_rmsd`、`refolded_motif_ca_rmsd`、`refolded_backbone_aligned_ligand_rmsd`、`max_ligand_centroid_distance`、`refolded_apo_holo_rmsd`；tag `unconditional_refolding` / `ppi_refolding` / `motif_scaffold_refolding` / `ame_refolding` / `sm_binder_refolding` / `dna_refolding` | AF3 / OpenFold3 / AF2 oracle | 本机没有 `apptainer`/`singularity`，也没有 AF3/OF3 镜像、权重、JAX 缓存；`scripts/download_assets.sh` 在无 apptainer 时跳过 OF3 |
| Oracle 置信度指标 | `oracle.*` / `oracle_ppi.*` / `oracle_dna.*` 的 `overall_plddt`、`plddt_coi`、`ptm_coi`、`iptm_coi`、`pae_coi`、`ipae_coi`、`min_ipae_coi`、`frac_under_1/1.5/2` | AF3 / OF3 | 同上 |
| 全部 pass criteria | `unconditional.pass`、`ppi.pass`、`antibody.pass`、`dna.pass`、`motif_scaffold.pass`、`internal_coords.pass`、`sm_binder.pass`、`ame.pass`、`ame_no_ligand.pass`、`disco.pass`、`developability.pass` | 上面的 oracle/refold 指标 + developability 指标 | 没有 oracle 指标，pass 无法判定；`developability.pass` 还缺 Rosetta 指标 |
| `rosetta_developability` | `developability` tag | PyRosetta apptainer（`$PYROSETTA_CONTAINER`） | 本机没有 PyRosetta 容器，也没有 apptainer |
| Clustered pass rate | `aggregate_metrics` + FoldSeek | FoldSeek 可执行文件 + `save_chain_of_interest=true` + pass 标签 | `which foldseek` 为空；没有 pass 标签，clustered pass 也无意义 |
| Search 变体结果 | `inference_beam_*` / `rfd4_proteina_high_search` | search 配置 + 可能的 refold reward | 本次只跑 one-shot；没有跑 beam/search |

### 2.2 因任务不适用（不是缺失，是本来就不该跑）

| 指标/组 | 官方 tag | 为什么没跑 |
| --- | --- | --- |
| `structure_prediction_lddt` | `structure_prediction` | 我们的任务是生成/设计，不是结构预测；需要 ground-truth 结构 |
| `antibody_contacts`、`cdr_torsion_naturalness` | `antibody` | 本次没有 antibody/nanobody 任务 |
| `posebusters_metrics`、`chiral_accuracy` | `small_molecule_only` / `has_small_molecule` | 本次没有小分子任务；PoseBusters 也未安装 |
| `rasa_adherence` | `rasa_conditioning` | 输入没有 RASA 条件 |
| `centroid_conditioning_adherence` | `centroid_conditioning` | 输入没有 centroid 条件 |
| `sse_accuracy` | `design` + 二级结构条件 | 输入没有 C_SEC 条件 |
| `contact_molecular_surface` | `cms` | 本次未启用该 tag；需要界面接触面积计算 |
| `sequence_similarity_to_input`、`ca_rmsd_to_input` | `partial_diffusion` | 本次没有跑 partial diffusion |
| `unindexed_insertion_mapping`、`design_unindexed_motif_allatom_rmsd` | `unindexed` | 本次 motif 是 indexed，不是 unindexed |
| `cath_metric` | `cath` | 未启用；需要 FoldSeek 或 CATH classifier |

### 2.3 因样本不适用而显示 NaN/缺失（不是失败）

| 列 | 为什么 |
| --- | --- |
| `bond_length...between_chain.polymer_polymer` | monomer 只有一条链，没有链间键 |
| ligand 相关 clash / RMSD 列 | 样本没有配体 |
| `sequence_adherence.sequence_adherence` | monomer 是无条件生成，没有序列条件（官方也是 NaN） |
| `rosetta_developability.*` | 使用了 `all_inline_metrics_no_rosetta`，主动去掉了 Rosetta 指标 |
| 所有 `refolded_*` / `oracle_*` / `*.pass` | 没有 oracle，指标未启用 |

---

## 3. 为什么这不影响模型的正常工作

1. **模型前向不依赖 oracle。**
   `Proteina` / flow matcher / AE decoder 的生成路径只使用模型权重和条件输入；
   oracle 是评测/搜索阶段的外部进程。
2. **本次已用多任务验证生成路径。**
   monomer（100/150/250 aa）、motif（131/124 aa）、PPI（186 aa）都产出了完整结构，
   且官方 design 指标正常（0 bad bond、0 clash、motif RMSD <0.17 Å、hotspot 1.0）。
3. **oracle 是显式可选依赖。**
   项目文档把 refolding 单独成章，`setup.sh` 询问是否安装 AF2/AF3 环境，
   `download_assets.sh` 在无 apptainer 时跳过 OF3。这说明官方也把它当作
   主模型环境之外的独立运行时。
4. **唯一受影响的“工作流”是 refold reward search。**
   如果你用 `ppi_refolding`/`unconditional_refolding` 等作为 search reward，
   没有 oracle 就跑不了；用 interchain/clash 等结构 reward 不受影响。
5. **训练不受影响。**
   训练不调用 refolding oracle（本次没有跑训练，但依赖关系如此）。

---

## 4. 如果要补齐，需要什么

### 4.1 补齐 oracle 链

在有 NVIDIA GPU 的节点上：

```bash
# 1) 安装 apptainer
# 2) 下载 OpenFold3 或配置 AF3
bash scripts/download_assets.sh "$DATA_PATH"      # 无 --skip-of3
# 3) 设置
export AF3_IMAGE=/path/to/of3.sif
export AF3_MODEL_DIR=$DATA_PATH/openfold3/weights
export AF3_JAX_CACHE_DIR=$DATA_PATH/openfold3/jax_cache

# 4) 生成时启用 refolding tag（或用 rfd4-evaluate 对已有结构补评）
rfd4-evaluate inputs=./runs/monomer-short/inference_samples \
  metrics_tags='[design,unconditional_refolding]' \
  out_dir=./eval/monomer-short
```

### 4.2 补齐 Rosetta developability

提供 PyRosetta apptainer，设置 `PYROSETTA_CONTAINER`，然后不要用
`all_inline_metrics_no_rosetta`。

### 4.3 补齐 clustered pass rate

安装 FoldSeek，生成时 `save_chain_of_interest=true`，再用
`rfproteina.inference_utils.foldseek` / `aggregate_metrics` 做聚类。

### 4.4 补齐官方 benchmark 规模

官方 Figure 2 使用 PPI 24 targets、SM 77、MCSA 37、DNA 3，每 target 200 attempts。
在 SDAA 上按当前 eager 速度（100 aa ≈ 464 s/design）需要数千 GPU-hour；
建议在 CUDA 节点补齐 oracle，或只对 SDAA 生成的结构做离线 refold。

---

## 5. 相关文件

- 已评测指标 CSV：`linshi/work/eval_monomer/`、`linshi/work/eval_ppi_design2/`、
  `linshi/work/gen_motif_indexed/inference_metrics/`、
  `linshi/work/gen_ppi_metrics/inference_metrics/`
- 主报告：`linshi/pc_report/README.md`
- 官方指标定义：`docs/reference/metrics.md`、`configs/metrics/all_metrics.yaml`
- Oracle 文档：`docs/how-to/refolding.md`
- Agent 运行指南：`linshi/agent_guid/README.md`