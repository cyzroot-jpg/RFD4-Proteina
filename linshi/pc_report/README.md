# RFD4-Proteina SDAA 评测主报告

## 1. 实验设置

| 项目 | 值 |
| --- | --- |
| 模型 | RFD4-Proteina (nvidia/RFD4-Proteina) |
| 权重 revision | `a06e2509c7033b010fc43614e9fd840303588502` |
| 平台 | Teco SDAA，单设备（32 logical devices 可用） |
| 精度 | `bf16-mixed`（官方默认） |
| 采样 | `recycle_strategy=thinking_medium`（60 steps，180 trunk passes） |
| compile | 关闭（`compile_lengths=null`，官方 eager 路径） |
| batch size | 1 |
| 评测入口 | 官方 `rfd4-evaluate` / 官方 inline metrics |
| 评测指标 | 官方 `configs/metrics/all_metrics.yaml`，按官方 `metrics_tags` 启用 |
| Oracle | 不可用（无 AF3/OF3 apptainer），未计算 scRMSD/pLDDT/ipTM/ipAE/pass rate |
| Rosetta | 不可用（无 PyRosetta 容器），developability 使用官方 `sequence_developability` 子集 |

任务与预算：

| 任务 | 数据集 | 输入 | replicates |
| --- | --- | --- | --- |
| Unconditional monomer | monomer-short / medium / long | `data/benchmarks/monomer/*.cif.zst` | 1 each |
| Indexed motif scaffolding | 1BCF_AA | `data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst` | 2 |
| Protein binder (PD-L1) | 5o45_cropped | `docs/examples/inputs/5o45_cropped.cif.zst` + `linshi/work/binder.yaml` | 2 (design) / 1 (inline interface) |

> 官方 unconditional 协议为 50 replicates/输入，motif 为 100 replicates/输入。本次为
> 单机 SDAA 可完成的最小评测预算，统计量不代表官方 pass rate；所有指标定义与计算
> 仍使用官方实现。

## 2. 主结果：结构与序列质量指标

### 2.1 Unconditional monomer

**Table 1. Monomer design metrics.** 每行是一个数据集的设计结果；`Average` 是三个数据集的平均。`↓` 表示越小越好。

| 模型 | 数据集 | n_res | bad_bond_frac ↓ | clash_frac ↓ | helix | sheet | loop | n_SSE | GRAVY | instability ↓ |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| RFD4-Proteina (SDAA) | monomer-short | 100 | 0.0000 | 0.0000 | 0.4100 | 0.2600 | 0.3300 | 13 | -0.6540 | 84.3400 |
| RFD4-Proteina (SDAA) | monomer-medium | 150 | 0.0000 | 0.0000 | 0.8400 | 0.0000 | 0.1600 | 15 | -0.5073 | 61.1653 |
| RFD4-Proteina (SDAA) | monomer-long | 250 | 0.0000 | 0.0000 | 0.8280 | 0.0000 | 0.1720 | 23 | -0.2404 | 48.6724 |
| **RFD4-Proteina (SDAA)** | **Average** | **166.7** | **0.0000** | **0.0000** | **0.6927** | **0.0867** | **0.2207** | **17.0** | **-0.4672** | **64.7259** |

### 2.2 Indexed motif scaffolding (1BCF_AA)

**Table 2. Motif scaffolding metrics.** `motif_RMSD` 是设计内部 motif 区域全原子 RMSD，越小越好。

| 模型 | 设计 | n_res | motif_RMSD (Å) ↓ | bad_bond_frac ↓ | clash_frac ↓ | helix | sheet | loop | n_SSE |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| RFD4-Proteina (SDAA) | 1BCF_AA_rep0 | 131 | 0.1643 | 0.0000 | 0.0000 | 0.8702 | 0.0000 | 0.1298 | 9 |
| RFD4-Proteina (SDAA) | 1BCF_AA_rep1 | 124 | 0.1566 | 0.0000 | 0.0000 | 0.8629 | 0.0000 | 0.1371 | 9 |
| **RFD4-Proteina (SDAA)** | **Average** | **127.5** | **0.1605** | **0.0000** | **0.0000** | **0.8666** | **0.0000** | **0.1334** | **9** |

### 2.3 Protein binder (PD-L1, 5o45)

**Table 3. Binder design metrics.** `helix/sheet/loop/n_SSE` 同时给出全体（target + binder）和设计链（COI，binder）两套。

| 模型 | 设计 | n_res | bad_bond_frac ↓ | clash_frac ↓ | helix (all) | sheet (all) | loop (all) | n_SSE (all) | helix (COI) | sheet (COI) | loop (COI) | n_SSE (COI) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| RFD4-Proteina (SDAA) | pdl1_binder_0 | 209 | 0.0000 | 0.0000 | 0.3876 | 0.2201 | 0.3923 | 23 | 0.8617 | 0.0000 | 0.1383 | 9 |
| RFD4-Proteina (SDAA) | pdl1_binder_1 | 169 | 0.0000 | 0.0000 | 0.2781 | 0.2663 | 0.4556 | 19 | 0.8704 | 0.0000 | 0.1296 | 5 |
| **RFD4-Proteina (SDAA)** | **Average** | **189** | **0.0000** | **0.0000** | **0.3329** | **0.2432** | **0.4239** | **21** | **0.8661** | **0.0000** | **0.1340** | **7** |

**Table 4. Binder interface metrics (inline, 1 design).** 这些是链间相互作用计数；`hotspot_obedience` 越高越好。

| 模型 | 设计 | hotspot_obedience ↑ | H-bond atoms | H-bond pairs | salt bridge residues | salt bridge pairs | hydrophobic atoms | hydrophobic pairs | π-stacking pairs | π-cation pairs | metal pairs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| RFD4-Proteina (SDAA) | pdl1_binder_0 (inline) | 1.0000 | 5 | 6 | 3 | 4 | 10 | 11 | 0 | 0 | 0 |

### 2.4 指标定义（哪些是指标）

| 表头 | 官方 key | 官方 tag | 含义 | 方向 |
| --- | --- | --- | --- | --- |
| `n_res` | `amino_acid_composition.n_standard_residues` | 始终 | 标准氨基酸残基数 | — |
| `bad_bond_frac` | `bond_length_metrics.bond_length.frac_unreasonable` | `design` | 异常键长比例 | ↓ |
| `clash_frac` | `clash_metrics.frac_atoms_clashing_1p5A` | `design` | 1.5 Å 内非键原子冲突比例 | ↓ |
| `helix` / `sheet` / `loop` | `sse_distribution.*_fraction` | `design` | 螺旋/片层/环区比例 | — |
| `n_SSE` | `sse_distribution.num_ss_elements` | `design` | 连续二级结构元素数 | — |
| `motif_RMSD` | `design_motif_allatom_rmsd.rmsd` | `3d_coordinate_conditioning` | 设计内部 motif 全原子 RMSD | ↓ |
| `GRAVY` | `sequence_developability.gravy` | `developability` | 亲疏水指数（越负越亲水） | — |
| `instability` | `sequence_developability.instability_index` | `developability` | Guruprasad 不稳定指数（<40 稳定） | ↓ |
| `hotspot_obedience` | `hotspot_obedience.hotspot_obedience` | `hotspot_conditioning` | hotspot 被 binder 接触的比例 | ↑ |
| `H-bond atoms/pairs` | `interchain_interactions.hbond_*_coi` | `interchain_interactions` | 链间氢键计数 | — |
| `salt bridge residues/pairs` | `interchain_interactions.saltbridge_*_coi` | `interchain_interactions` | 链间盐桥计数 | — |
| `hydrophobic atoms/pairs` | `interchain_interactions.hydrophobic_*_coi` | `interchain_interactions` | 链间疏水接触计数 | — |
| `π-stacking/π-cation/metal` | `interchain_interactions.*_coi` | `interchain_interactions` | 对应相互作用计数 | — |

### 2.5 为什么表里有很多 0 / NaN

这些 `0.0000` 是**指标实际计算出的值**，不是缺省占位符，也不是指标没跑：

| 列 | 0 的含义 | 验证 |
| --- | --- | --- |
| `bad_bond_frac` | 所有键长都在 AtomWorks 的元素相关合理阈值内 | 每个设计都解析出了完整键表：monomer-short 816、medium 1260、long 2048、motif 1101/1003、PPI 1512 条键；若没有键，`compute_bond_length_stats` 会返回空 dict，CSV 里根本不会有该列，而不是 0 |
| `clash_frac` | 没有非键原子对距离 < 1.5 Å | `compute_clash_stats` 用 CellList 在 1.5 Å 内搜索，并把成键对、以及两端都被固定的 CRD 对排除；输出为 0 表示搜索执行后无命中 |
| `n_generated_unknown_residues` | 生成残基全部是标准氨基酸 | `n_standard_residues` 等于设计长度（100/150/250/131/124/186 等） |
| `sheet` = 0 | 该设计确实是全 α 螺旋（helix + sheet + loop 三者和为 1） | medium/long/motif 的 helix 分别为 0.84/0.83/0.87，loop 为 0.16/0.17/0.13，不是缺失 |
| `hotspot_obedience` = 1 | 所有指定 hotspot 都被满足（这是“1.0”不是“0”） | 3 个 hotspot 均 <4.5 Å |

`NaN` 才是“该指标在此样本/配置下不适用或不可用”，例如：

- monomer 的 `bond_length...between_chain.polymer_polymer`：只有一条链，没有链间键；
- motif/PPI 的 `sequence_developability`：这些运行没有启用 `developability` tag；
- 所有 `refolded_*` / `*.pass`：没有 AF3/OF3 oracle，指标未启用；
- PPI 的 ligand 相关 clash 分类：没有配体。

逐设计的键数/原子数复核见 `linshi/pc_report/metric_sanity_check.txt`。另外做了一个敏感性验证：把 monomer-short 的坐标放大 2×，`bad_bond_frac` 变为 `1.0`；把坐标压缩到 0.2×，`clash_frac` 变为 `1.0`。说明这些列确实在计算，`0` 不是硬编码。结论：0 表示“检查通过、未发现问题”，是这批设计几何质量良好的表现；真正的缺失会表现为列不存在或 `NaN`。

## 3. 性能结果

所有运行：单 SDAA 设备、batch size 1、`bf16-mixed`、`thinking_medium`（60 steps /
180 trunk passes）、eager。时间为墙钟时间；显存为设备峰值分配。

| 任务 | n_res | designs | wall time (s) | s/design | device peak (GB) | process RSS (GB) | CPU util (%) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 100 | 1 | 463.6 | 463.6 | 1.87 | 4.36 | 0.66 |
| monomer-medium | 150 | 1 | 1004.3 | 1004.3 | 2.01 | 4.35 | 0.35 |
| monomer-long | 250 | 1 | 2709.2 | 2709.2 | 2.45 | 4.35 | 0.20 |
| motif 1BCF_AA | 124–131 | 2 | 1762.3 | 881.2 | 1.95 | 4.42 | 0.42 |
| PPI PD-L1 (inline) | 186 | 1 | 1530.1 | 1530.1 | 2.14 | 4.42 | 0.28 |
| PPI PD-L1 (2 reps) | 169–209 | 2 | 4248.2 | 2124.1 | 2.24 | 4.32 | 0.22 |

说明：
- 以上运行与其他任务并行，CPU 利用率与墙钟时间会受并发影响；`monomer-short` 的
  463.6 s 与单独运行的 472.9 s 接近，可作为 100 aa 单设计的稳定参考。
- `CPU util (%)` 为“进程 CPU 时间 / 墙钟 / 逻辑核数”，所以数值很小；绝对 CPU 时间
  见各 `resource_usage.json` 的 `cpu_time_s`。
- 20 steps / 20 trunk passes 的短烟测（100 aa）为 58.6 s，可用于快速冒烟。
- 默认 FP32 权重 + bf16 autocast，设备峰值显存仅约 1.9–2.5 GB，远低于单设备 16 GB。

## 4. 与官方指标协议的一致性

| 项目 | 官方 | 本次 | 说明 |
| --- | --- | --- | --- |
| 评测入口 | `rfd4-evaluate` / inline metrics | 同 | 直接调用官方实现 |
| 指标定义 | `configs/metrics/all_metrics.yaml` | 同 | tags 启用，未自造指标 |
| Monomer tags | `design, unconditional_refolding` | `design, developability` | 无 oracle，去掉 refolding |
| Motif tags | `design, 3d_coordinate_conditioning, motif_scaffold_refolding` | `design, 3d_coordinate_conditioning` | 无 oracle，保留 motif RMSD |
| PPI tags | `ppi_refolding, hotspot_conditioning` | `design, hotspot_conditioning, interchain_interactions` | 无 oracle，保留界面依从性 |
| Rosetta developability | `developability` 全组 | `sequence_developability` 子集 | 无 PyRosetta 容器 |
| Replicates | monomer 50 / motif 100 | 1–2 | 预算缩减 |

## 5. 结论

1. RFD4-Proteina 在 SDAA 上可以完成 unconditional monomer、indexed motif
   scaffolding 和 protein binder 三类任务的端到端生成。
2. 生成结构的官方设计指标正常：所有设计的异常键长比例与 1.5 Å 冲突比例均为 0，
   二级结构分布合理，motif 全原子 RMSD < 0.17 Å，PPI hotspot obedience = 1.0。
3. 由于缺少 AF3/OF3 与 PyRosetta 运行时，官方 refolding / pass-rate 指标无法在本机
   计算；这是本次评测的主要缺口，报告中未用自造指标替代。
4. 性能上，100 aa 单设计约 7.7 分钟（180 trunk passes，eager）；显存占用低，
   但吞吐显著低于 CUDA + compile + cuEquivariance 的官方配置。后续可通过
   SDAA SDPA/融合算子、`torch.compile` 支持与多卡并行提升。