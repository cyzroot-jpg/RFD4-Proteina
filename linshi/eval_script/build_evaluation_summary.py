#!/usr/bin/env python3
"""Build one self-contained summary of datasets, tasks, metrics and results.

Output: linshi/pc_report/evaluation_summary.md

Reads the official per-example CSVs; does not recompute or invent metrics.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "linshi/pc_report/evaluation_summary.md"

MONOMER = REPO / "linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv"
MOTIF = REPO / "linshi/work/gen_motif_indexed/inference_metrics/per_example_metrics.csv"
PPI_DESIGN = REPO / "linshi/work/eval_ppi_design2/evaluation_metrics/per_example_metrics.csv"
PPI_INLINE = REPO / "linshi/work/gen_ppi_metrics/inference_metrics/per_example_metrics.csv"


def read(path: Path) -> pd.DataFrame:
    return pd.read_csv(path)


def fmt(df: pd.DataFrame, int_cols: set[str] | None = None) -> str:
    """Render a DataFrame with counts as integers and floats to 4 decimals."""
    int_cols = int_cols or set()
    out = df.copy()
    for col in out.columns:
        if col in int_cols:
            mapped = out[col].map(lambda v: "N/A" if pd.isna(v) else str(int(round(float(v)))))
        else:
            mapped = out[col].map(
                lambda v: "N/A" if pd.isna(v) else (f"{v:.4f}" if isinstance(v, float) else str(v))
            )
        out[col] = mapped.astype(object)
    return out.to_markdown(index=False)


def main() -> None:
    mono = read(MONOMER)
    motif = read(MOTIF)
    ppi_design = read(PPI_DESIGN)
    ppi_inline = read(PPI_INLINE)

    lines: list[str] = []
    lines.append("# RFD4-Proteina SDAA 评测汇总：数据、任务、指标、结果\n")
    lines.append(
        "本文件把本次评测的数据集、任务、评测内容、指标和结果集中在一起。\n"
        "所有数值来自官方指标实现的 `per_example_metrics.csv`；`N/A` 表示原值为 NaN"
        "（该样本/配置下不适用或未启用），不是 0，也没有被替换。\n"
    )

    # ── 1. 基本信息 ────────────────────────────────────────────────────────
    lines.append("## 1. 基本信息\n")
    lines.append(
        "| 项目 | 值 |\n"
        "| --- | --- |\n"
        "| 平台 | Teco SDAA（LoongArch，Torch-SDAA 3.3.0，PyTorch 2.12.0） |\n"
        "| 模型 | RFD4-Proteina |\n"
        "| 权重 | `nvidia/RFD4-Proteina` revision `a06e2509c7033b010fc43614e9fd840303588502`（HF bundle，含 AE） |\n"
        "| 采样 | `thinking_medium`（60 steps，180 trunk passes） |\n"
        "| 精度 / batch | `bf16-mixed`，batch size 1 |\n"
        "| compile | 关闭（`compile_lengths=null`，eager） |\n"
        "| 评测入口 | 官方 `rfd4-evaluate` + 官方 inline metrics |\n"
        "| Oracle | 不可用（无 AF3/OF3），未计算 refold/pass/clustered 指标 |\n"
        "| Rosetta | 不可用（无 PyRosetta），developability 用官方 `sequence_developability` 子集 |\n"
    )

    # ── 2. 数据集与任务 ────────────────────────────────────────────────────
    lines.append("## 2. 数据集与任务\n")
    lines.append(
        "| 任务 | 数据集 | 输入路径 | 设计数 | 评测方式 | 本次评了什么 |\n"
        "| --- | --- | --- | ---: | --- | --- |\n"
        "| Unconditional monomer | monomer-short | `data/benchmarks/monomer/monomer-short.cif.zst` | 1 | 官方离线 `rfd4-evaluate` | 结构几何、SSE、AA 组成、sequence developability |\n"
        "| Unconditional monomer | monomer-medium | `data/benchmarks/monomer/monomer-medium.cif.zst` | 1 | 官方离线 `rfd4-evaluate` | 同上 |\n"
        "| Unconditional monomer | monomer-long | `data/benchmarks/monomer/monomer-long.cif.zst` | 1 | 官方离线 `rfd4-evaluate` | 同上 |\n"
        "| Indexed motif scaffolding | 1BCF_AA | `data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst` | 2 | 官方 inline metrics | 结构几何、SSE、motif 全原子 RMSD、序列依从性 |\n"
        "| Protein binder | PD-L1 / 5o45_cropped | `docs/examples/inputs/5o45_cropped.cif.zst` + `linshi/work/binder.yaml` | 2 + 1 inline | 官方离线 + inline | 结构几何、SSE、hotspot、链间相互作用 |\n"
    )

    # ── 3. 结果 ────────────────────────────────────────────────────────────
    lines.append("## 3. 结果\n")
    lines.append(
        "| 任务 | 设计数 | n_res | bad_bond | clash | 关键结果 |\n"
        "| --- | ---: | ---: | ---: | ---: | --- |\n"
        "| Unconditional monomer | 3 | 100–250 | 0 | 0 | helix 41%–84%；GRAVY -0.65…-0.24；instability 48.7–84.3 |\n"
        "| Indexed motif scaffolding | 2 | 124–131 | 0 | 0 | motif 全原子 RMSD 0.157–0.164 Å；helix 86%–87% |\n"
        "| Protein binder (PD-L1) | 2 + 1 inline | 169–209 | 0 | 0 | hotspot obedience 1.0；H-bond 5 atoms；salt bridge 3 res；hydrophobic 10 atoms |\n"
    )

    # 3.1 monomer
    lines.append("### 3.1 Unconditional monomer\n")
    mono_cols = [
        ("example_id", "设计"),
        ("amino_acid_composition.n_standard_residues", "n_res"),
        ("amino_acid_composition.n_generated_unknown_residues", "unknown"),
        ("amino_acid_composition.ala_fraction", "ALA"),
        ("amino_acid_composition.val_fraction", "VAL"),
        ("amino_acid_composition.gly_fraction", "GLY"),
        ("bond_length_metrics.bond_length.frac_unreasonable", "bad_bond"),
        ("clash_metrics.frac_atoms_clashing_1p5A", "clash"),
        ("sse_distribution.helix_fraction", "helix"),
        ("sse_distribution.sheet_fraction", "sheet"),
        ("sse_distribution.loop_fraction", "loop"),
        ("sse_distribution.num_ss_elements", "n_SSE"),
        ("sequence_developability.gravy", "GRAVY"),
        ("sequence_developability.instability_index", "instability"),
        ("sequence_adherence.sequence_adherence", "seq_adherence"),
        ("pre_oracle_pass", "pre_oracle_pass"),
    ]
    mono_show = mono[[c for c, _ in mono_cols]].rename(columns=dict(mono_cols))
    lines.append(fmt(mono_show, {"n_res", "unknown", "n_SSE", "pre_oracle_pass"}))
    lines.append(
        "\n`bad_bond` = `bond_length_metrics.bond_length.frac_unreasonable`；"
        "`clash` = `clash_metrics.frac_atoms_clashing_1p5A`；"
        "`pre_oracle_pass` 只表示通过 pre-oracle 过滤，不是最终 pass。\n"
        "\n完整分类（键长 within/between、clash 5 类、SSE COI、AA 组成等）见 "
        "`linshi/pc_report/all_measured_metrics_by_task.md` 的 monomer 部分。\n"
    )

    # 3.2 motif
    lines.append("### 3.2 Indexed motif scaffolding（1BCF_AA）\n")
    motif_cols = [
        ("example_id", "设计"),
        ("amino_acid_composition.n_standard_residues", "n_res"),
        ("design_motif_allatom_rmsd.rmsd", "motif_RMSD (Å)"),
        ("bond_length_metrics.bond_length.frac_unreasonable", "bad_bond"),
        ("clash_metrics.frac_atoms_clashing_1p5A", "clash"),
        ("sse_distribution.helix_fraction", "helix"),
        ("sse_distribution.sheet_fraction", "sheet"),
        ("sse_distribution.loop_fraction", "loop"),
        ("sse_distribution.num_ss_elements", "n_SSE"),
        ("sequence_adherence.sequence_adherence", "seq_adherence"),
        ("pre_oracle_pass", "pre_oracle_pass"),
    ]
    motif_show = motif[[c for c, _ in motif_cols]].rename(columns=dict(motif_cols))
    lines.append(fmt(motif_show, {"n_res", "n_SSE", "pre_oracle_pass"}))
    lines.append(
        "\n`motif_RMSD` 是设计内部 motif 区域全原子 RMSD（自一致性），不是 AF3 refold 后的 RMSD。"
        "两个设计都 <0.17 Å。\n"
    )

    # 3.3 PPI design
    lines.append("### 3.3 Protein binder（PD-L1）— 设计指标（2 reps）\n")
    ppi_cols = [
        ("example_id", "设计"),
        ("amino_acid_composition.n_standard_residues", "n_res"),
        ("bond_length_metrics.bond_length.frac_unreasonable", "bad_bond"),
        ("clash_metrics.frac_atoms_clashing_1p5A", "clash"),
        ("sse_distribution.helix_fraction", "helix_all"),
        ("sse_distribution.sheet_fraction", "sheet_all"),
        ("sse_distribution.loop_fraction", "loop_all"),
        ("sse_distribution.num_ss_elements", "n_SSE_all"),
        ("sse_distribution.helix_fraction_coi", "helix_COI"),
        ("sse_distribution.sheet_fraction_coi", "sheet_COI"),
        ("sse_distribution.loop_fraction_coi", "loop_COI"),
        ("sse_distribution.num_ss_elements_coi", "n_SSE_COI"),
        ("sequence_adherence.sequence_adherence", "seq_adherence"),
        ("pre_oracle_pass", "pre_oracle_pass"),
    ]
    ppi_show = ppi_design[[c for c, _ in ppi_cols]].rename(columns=dict(ppi_cols))
    lines.append(fmt(ppi_show, {"n_res", "n_SSE_all", "n_SSE_COI", "pre_oracle_pass"}))
    lines.append("\n")

    # 3.4 PPI interface
    lines.append("### 3.4 Protein binder（PD-L1）— 界面指标（inline，1 rep）\n")
    row = ppi_inline.iloc[0]
    interface = pd.DataFrame(
        [
            ("hotspot_obedience.hotspot_obedience", "hotspot 满足比例", row["hotspot_obedience.hotspot_obedience"]),
            ("interchain_interactions.hbond_atom_count_coi", "H-bond 原子数", row["interchain_interactions.hbond_atom_count_coi"]),
            ("interchain_interactions.hbond_atom_pair_count_coi", "H-bond 原子对数", row["interchain_interactions.hbond_atom_pair_count_coi"]),
            ("interchain_interactions.saltbridge_residue_count_coi", "盐桥残基数", row["interchain_interactions.saltbridge_residue_count_coi"]),
            ("interchain_interactions.saltbridge_residue_pair_count_coi", "盐桥残基对数", row["interchain_interactions.saltbridge_residue_pair_count_coi"]),
            ("interchain_interactions.hydrophobic_atom_count_coi", "疏水接触原子数", row["interchain_interactions.hydrophobic_atom_count_coi"]),
            ("interchain_interactions.hydrophobic_atom_pair_count_coi", "疏水接触原子对数", row["interchain_interactions.hydrophobic_atom_pair_count_coi"]),
            ("interchain_interactions.pistack_residue_pair_count_coi", "π-stacking 残基对数", row["interchain_interactions.pistack_residue_pair_count_coi"]),
            ("interchain_interactions.pication_residue_pair_count_coi", "π-cation 残基对数", row["interchain_interactions.pication_residue_pair_count_coi"]),
            ("interchain_interactions.metal_coord_atom_pair_count_coi", "金属配位原子对数", row["interchain_interactions.metal_coord_atom_pair_count_coi"]),
        ],
        columns=["指标 key", "指标名", "结果"],
    )
    lines.append(fmt(interface, {"H-bond 原子数", "H-bond 原子对数", "盐桥残基数", "盐桥残基对数", "疏水接触原子数", "疏水接触原子对数", "π-stacking 残基对数", "π-cation 残基对数", "金属配位原子对数"}))
    lines.append(
        "\n该 inline 设计：n_res=186，bad_bond=0，clash=0，"
        "hotspot obedience=1.0，说明 3 个指定 hotspot 全部被 binder 接触。\n"
    )

    # ── 4. 指标字典 ────────────────────────────────────────────────────────
    lines.append("## 4. 本次用到的指标及其含义\n")
    lines.append(
        "| 指标组 | 官方 tag | 含义 | 本次是否计算 |\n"
        "| --- | --- | --- | --- |\n"
        "| `amino_acid_composition` | 始终 | UNK 数、标准残基数、ALA/VAL/GLY 比例 | 是 |\n"
        "| `bond_length_metrics` | `design` | 键长不合理的键比例（元素阈值） | 是 |\n"
        "| `clash_metrics` | `design` | 1.5 Å 非键原子冲突比例 | 是 |\n"
        "| `sequence_adherence` | `design` | 序列条件依从性与违例数 | 是（monomer 为 N/A） |\n"
        "| `sequence_probability_adherence` | `design` | 概率 0/1 序列约束依从性 | 是 |\n"
        "| `sse_distribution` | `design` | helix/sheet/loop 比例与连续 SSE 数 | 是 |\n"
        "| `sequence_developability` | `developability` | GRAVY 与 instability index | 是（monomer） |\n"
        "| `design_motif_allatom_rmsd` | `3d_coordinate_conditioning` | 设计内部 motif 全原子 RMSD | 是（motif） |\n"
        "| `hotspot_obedience` | `hotspot_conditioning` | hotspot 被 binder 接触的比例 | 是（PPI） |\n"
        "| `interchain_interactions` | `interchain_interactions` | 链间 H-bond/盐桥/疏水/π/金属计数 | 是（PPI） |\n"
        "| `pre_oracle_pass` | 由 pre-oracle filters 产生 | 是否通过 pre-oracle 过滤 | 是 |\n"
        "| `refolded_*` / `oracle_*` / `*.pass` | `*_refolding` | refold RMSD、pLDDT、pTM/ipTM/ipAE、pass | 否（无 oracle） |\n"
        "| `rosetta_developability` | `developability` | Rosetta SAP / exposed hydrophobics | 否（无 PyRosetta） |\n"
    )

    # ── 5. 没测什么、为什么 ────────────────────────────────────────────────
    lines.append("## 5. 没测什么、为什么\n")
    lines.append(
        "| 没测的内容 | 原因 |\n"
        "| --- | --- |\n"
        "| `refolded_*`、`oracle_*`（pLDDT/pTM/ipTM/ipAE） | 本机无 apptainer、AF3/OF3 镜像/权重，且无 NVIDIA GPU |\n"
        "| `*.pass`、pass rate、clustered pass rate | 依赖 oracle/refold 指标；无 oracle 无法判定 |\n"
        "| `rosetta_developability` | 无 PyRosetta 容器 |\n"
        "| FoldSeek 聚类 | 无 FoldSeek，且没有 pass 标签 |\n"
        "| antibody / small molecule / RASA / centroid / partial diffusion / unindexed / CATH 等 | 本次没有对应任务或条件 |\n"
    )

    # ── 6. 原始文件 ────────────────────────────────────────────────────────
    lines.append("## 6. 原始结果文件\n")
    lines.append(
        "| 任务 | 文件 |\n"
        "| --- | --- |\n"
        "| Monomer | `linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv` |\n"
        "| Motif | `linshi/work/gen_motif_indexed/inference_metrics/per_example_metrics.csv` |\n"
        "| PPI design（2 reps） | `linshi/work/eval_ppi_design2/evaluation_metrics/per_example_metrics.csv` |\n"
        "| PPI inline（1 rep） | `linshi/work/gen_ppi_metrics/inference_metrics/per_example_metrics.csv` |\n"
        "| 全量逐指标 | `linshi/pc_report/all_measured_metrics_by_task.md` / `.csv` |\n"
        "| 性能记录 | 各运行目录下 `inference_metrics/resource_usage.json` |\n"
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()