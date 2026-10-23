#!/usr/bin/env python3
"""Export every measured RFD4-Proteina metric to one long-format table.

Reads the per-example CSVs produced by the official inline/offline metric
pipeline and writes:
  - linshi/pc_report/all_measured_metrics_by_task.md
  - linshi/pc_report/all_measured_metrics_by_task.csv

Only values already computed by the official metric code are exported. Missing
or inapplicable values stay as NaN and are labelled as such; nothing is imputed.
"""

from __future__ import annotations

import math
from pathlib import Path

import pandas as pd

REPO = Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "linshi" / "pc_report"
MODEL = "RFD4-Proteina (HF bundle a06e2509)"

SOURCES = [
    {
        "task": "Unconditional monomer",
        "dataset": "monomer-short",
        "run": "eval_monomer (offline)",
        "path": REPO / "linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv",
        "filter": lambda e: e.startswith("monomer-short"),
        "design_map": lambda e: e.replace("_generated", ""),
    },
    {
        "task": "Unconditional monomer",
        "dataset": "monomer-medium",
        "run": "eval_monomer (offline)",
        "path": REPO / "linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv",
        "filter": lambda e: e.startswith("monomer-medium"),
        "design_map": lambda e: e.replace("_generated", ""),
    },
    {
        "task": "Unconditional monomer",
        "dataset": "monomer-long",
        "run": "eval_monomer (offline)",
        "path": REPO / "linshi/work/eval_monomer/evaluation_metrics/per_example_metrics.csv",
        "filter": lambda e: e.startswith("monomer-long"),
        "design_map": lambda e: e.replace("_generated", ""),
    },
    {
        "task": "Indexed motif scaffolding",
        "dataset": "1BCF_AA (motif_indexed)",
        "run": "gen_motif_indexed (inline)",
        "path": REPO / "linshi/work/gen_motif_indexed/inference_metrics/per_example_metrics.csv",
        "design_map": lambda e: e,
    },
    {
        "task": "Protein binder",
        "dataset": "PD-L1 / 5o45_cropped",
        "run": "eval_ppi_design2 (offline, 2 reps)",
        "path": REPO / "linshi/work/eval_ppi_design2/evaluation_metrics/per_example_metrics.csv",
        "design_map": lambda e: e,
    },
    {
        "task": "Protein binder",
        "dataset": "PD-L1 / 5o45_cropped",
        "run": "gen_ppi_metrics (inline, 1 rep)",
        "path": REPO / "linshi/work/gen_ppi_metrics/inference_metrics/per_example_metrics.csv",
        "design_map": lambda e: e,
    },
]

# metric_key -> (Chinese description, unit)
DESCRIPTIONS = {
    "amino_acid_composition.n_generated_unknown_residues": ("生成的非标准/未知残基数", "count"),
    "amino_acid_composition.n_standard_residues": ("标准氨基酸残基数", "count"),
    "amino_acid_composition.ala_fraction": ("ALA 比例", "fraction"),
    "amino_acid_composition.val_fraction": ("VAL 比例", "fraction"),
    "amino_acid_composition.gly_fraction": ("GLY 比例", "fraction"),
    "bond_length_metrics.bond_length.frac_unreasonable": ("异常键长比例（总体）", "fraction"),
    "bond_length_metrics.bond_length.frac_unreasonable.within_residue": ("残基内异常键长比例", "fraction"),
    "bond_length_metrics.bond_length.frac_unreasonable.between_residue.within_chain": (
        "链内残基间异常键长比例",
        "fraction",
    ),
    "bond_length_metrics.bond_length.frac_unreasonable.between_chain.polymer_polymer": (
        "链间 polymer–polymer 异常键长比例",
        "fraction",
    ),
    "bond_length_metrics.bond_length.frac_unreasonable.between_chain.nonpolymer_to_polymer": (
        "非聚合物–聚合物异常键长比例",
        "fraction",
    ),
    "clash_metrics.frac_atoms_clashing_1p5A": ("1.5 Å 原子冲突比例（总体）", "fraction"),
    "clash_metrics.frac_atoms_clashing_intra_residue_polymer_1p5A": ("残基内 polymer 冲突比例", "fraction"),
    "clash_metrics.frac_atoms_clashing_intra_residue_ligand_1p5A": ("残基内 ligand 冲突比例", "fraction"),
    "clash_metrics.frac_atoms_clashing_inter_residue_polymer_polymer_1p5A": (
        "残基间 polymer–polymer 冲突比例",
        "fraction",
    ),
    "clash_metrics.frac_atoms_clashing_inter_residue_polymer_ligand_1p5A": (
        "残基间 polymer–ligand 冲突比例",
        "fraction",
    ),
    "clash_metrics.frac_atoms_clashing_inter_residue_ligand_ligand_1p5A": (
        "残基间 ligand–ligand 冲突比例",
        "fraction",
    ),
    "sequence_adherence.sequence_adherence": ("序列条件依从性", "fraction"),
    "sequence_adherence.n_violations": ("序列条件违例数", "count"),
    "sequence_probability_adherence.zero_adherence": ("概率 0 约束依从性", "fraction"),
    "sequence_probability_adherence.one_adherence": ("概率 1 约束依从性", "fraction"),
    "sequence_probability_adherence.n_zero_conditions": ("概率 0 条件数", "count"),
    "sequence_probability_adherence.n_zero_violations": ("概率 0 违例数", "count"),
    "sequence_probability_adherence.n_one_conditions": ("概率 1 条件数", "count"),
    "sequence_probability_adherence.n_one_violations": ("概率 1 违例数", "count"),
    "sse_distribution.helix_fraction": ("helix 比例（全体）", "fraction"),
    "sse_distribution.sheet_fraction": ("sheet 比例（全体）", "fraction"),
    "sse_distribution.loop_fraction": ("loop 比例（全体）", "fraction"),
    "sse_distribution.num_ss_elements": ("连续 SSE 元素数（全体）", "count"),
    "sse_distribution.helix_fraction_coi": ("helix 比例（设计链 COI）", "fraction"),
    "sse_distribution.sheet_fraction_coi": ("sheet 比例（设计链 COI）", "fraction"),
    "sse_distribution.loop_fraction_coi": ("loop 比例（设计链 COI）", "fraction"),
    "sse_distribution.num_ss_elements_coi": ("连续 SSE 元素数（设计链 COI）", "count"),
    "sequence_developability.gravy": ("GRAVY 亲疏水指数", "index"),
    "sequence_developability.instability_index": ("Guruprasad 不稳定指数", "index"),
    "developability.pass": ("developability pass 标志（缺 Rosetta 时为 0）", "0/1"),
    "developability.all_metrics_present": ("developability 指标是否齐全", "0/1"),
    "design_motif_allatom_rmsd.rmsd": ("设计内部 motif 全原子 RMSD", "Å"),
    "hotspot_obedience.hotspot_obedience": ("hotspot 满足比例", "fraction"),
    "interchain_interactions.hbond_atom_count_coi": ("链间 H-bond 原子数", "count"),
    "interchain_interactions.hbond_atom_pair_count_coi": ("链间 H-bond 原子对数", "count"),
    "interchain_interactions.pistack_residue_count_coi": ("链间 π-stacking 残基数", "count"),
    "interchain_interactions.pistack_residue_pair_count_coi": ("链间 π-stacking 残基对数", "count"),
    "interchain_interactions.pication_residue_count_coi": ("链间 π-cation 残基数", "count"),
    "interchain_interactions.pication_residue_pair_count_coi": ("链间 π-cation 残基对数", "count"),
    "interchain_interactions.saltbridge_residue_count_coi": ("链间盐桥残基数", "count"),
    "interchain_interactions.saltbridge_residue_pair_count_coi": ("链间盐桥残基对数", "count"),
    "interchain_interactions.hydrophobic_atom_count_coi": ("链间疏水接触原子数", "count"),
    "interchain_interactions.hydrophobic_atom_pair_count_coi": ("链间疏水接触原子对数", "count"),
    "interchain_interactions.metal_coord_atom_count_coi": ("链间金属配位原子数", "count"),
    "interchain_interactions.metal_coord_atom_pair_count_coi": ("链间金属配位原子对数", "count"),
    "pre_oracle_pass": ("pre-oracle 过滤是否通过（不是最终 pass）", "0/1"),
}

# Official metric group -> human-readable group name.
FAMILY_NAMES = {
    "amino_acid_composition": "Amino Acid Composition（氨基酸组成）",
    "bond_length_metrics": "Bond Length Metrics（键长指标）",
    "clash_metrics": "Clash Metrics（原子冲突指标）",
    "sequence_adherence": "Sequence Adherence（序列依从性）",
    "sequence_probability_adherence": "Sequence Probability Adherence（序列概率依从性）",
    "sse_distribution": "SSE Distribution（二级结构分布）",
    "sequence_developability": "Sequence Developability（序列可开发性）",
    "developability": "Developability Pass（可开发性判定）",
    "design_motif_allatom_rmsd": "Design Motif All-Atom RMSD（motif 全原子 RMSD）",
    "hotspot_obedience": "Hotspot Obedience（hotspot 满足度）",
    "interchain_interactions": "Interchain Interactions（链间相互作用）",
    "pre_oracle_pass": "Pre-oracle Pass（pre-oracle 过滤）",
}

# metric_key -> concise human-readable metric name.
NAMES = {
    "amino_acid_composition.n_generated_unknown_residues": "生成未知残基数",
    "amino_acid_composition.n_standard_residues": "标准残基数",
    "amino_acid_composition.ala_fraction": "ALA 比例",
    "amino_acid_composition.val_fraction": "VAL 比例",
    "amino_acid_composition.gly_fraction": "GLY 比例",
    "bond_length_metrics.bond_length.frac_unreasonable": "异常键长比例（总体）",
    "bond_length_metrics.bond_length.frac_unreasonable.within_residue": "异常键长比例（残基内）",
    "bond_length_metrics.bond_length.frac_unreasonable.between_residue.within_chain": "异常键长比例（链内残基间）",
    "bond_length_metrics.bond_length.frac_unreasonable.between_chain.polymer_polymer": "异常键长比例（链间 polymer–polymer）",
    "bond_length_metrics.bond_length.frac_unreasonable.between_chain.nonpolymer_to_polymer": "异常键长比例（非聚合物–聚合物）",
    "clash_metrics.frac_atoms_clashing_1p5A": "原子冲突比例（总体，1.5 Å）",
    "clash_metrics.frac_atoms_clashing_intra_residue_polymer_1p5A": "原子冲突比例（残基内 polymer）",
    "clash_metrics.frac_atoms_clashing_intra_residue_ligand_1p5A": "原子冲突比例（残基内 ligand）",
    "clash_metrics.frac_atoms_clashing_inter_residue_polymer_polymer_1p5A": "原子冲突比例（残基间 polymer–polymer）",
    "clash_metrics.frac_atoms_clashing_inter_residue_polymer_ligand_1p5A": "原子冲突比例（残基间 polymer–ligand）",
    "clash_metrics.frac_atoms_clashing_inter_residue_ligand_ligand_1p5A": "原子冲突比例（残基间 ligand–ligand）",
    "sequence_adherence.sequence_adherence": "序列条件依从性",
    "sequence_adherence.n_violations": "序列条件违例数",
    "sequence_probability_adherence.zero_adherence": "概率 0 约束依从性",
    "sequence_probability_adherence.one_adherence": "概率 1 约束依从性",
    "sequence_probability_adherence.n_zero_conditions": "概率 0 条件数",
    "sequence_probability_adherence.n_zero_violations": "概率 0 违例数",
    "sequence_probability_adherence.n_one_conditions": "概率 1 条件数",
    "sequence_probability_adherence.n_one_violations": "概率 1 违例数",
    "sse_distribution.helix_fraction": "螺旋比例（全体）",
    "sse_distribution.sheet_fraction": "折叠片比例（全体）",
    "sse_distribution.loop_fraction": "环比例（全体）",
    "sse_distribution.num_ss_elements": "二级结构元素数（全体）",
    "sse_distribution.helix_fraction_coi": "螺旋比例（设计链 COI）",
    "sse_distribution.sheet_fraction_coi": "折叠片比例（设计链 COI）",
    "sse_distribution.loop_fraction_coi": "环比例（设计链 COI）",
    "sse_distribution.num_ss_elements_coi": "二级结构元素数（设计链 COI）",
    "sequence_developability.gravy": "GRAVY 亲疏水指数",
    "sequence_developability.instability_index": "Guruprasad 不稳定指数",
    "developability.pass": "developability 通过标志",
    "developability.all_metrics_present": "developability 指标齐全标志",
    "design_motif_allatom_rmsd.rmsd": "motif 全原子 RMSD",
    "hotspot_obedience.hotspot_obedience": "hotspot 满足比例",
    "interchain_interactions.hbond_atom_count_coi": "链间 H-bond 原子数",
    "interchain_interactions.hbond_atom_pair_count_coi": "链间 H-bond 原子对数",
    "interchain_interactions.pistack_residue_count_coi": "链间 π-stacking 残基数",
    "interchain_interactions.pistack_residue_pair_count_coi": "链间 π-stacking 残基对数",
    "interchain_interactions.pication_residue_count_coi": "链间 π-cation 残基数",
    "interchain_interactions.pication_residue_pair_count_coi": "链间 π-cation 残基对数",
    "interchain_interactions.saltbridge_residue_count_coi": "链间盐桥残基数",
    "interchain_interactions.saltbridge_residue_pair_count_coi": "链间盐桥残基对数",
    "interchain_interactions.hydrophobic_atom_count_coi": "链间疏水接触原子数",
    "interchain_interactions.hydrophobic_atom_pair_count_coi": "链间疏水接触原子对数",
    "interchain_interactions.metal_coord_atom_count_coi": "链间金属配位原子数",
    "interchain_interactions.metal_coord_atom_pair_count_coi": "链间金属配位原子对数",
    "pre_oracle_pass": "pre-oracle 过滤通过标志",
}

META_COLUMNS = {
    "example_id",
    "dataset_name",
    "task",
    "designed_structure_path",
    "output_base_dir",
    "metrics_tags",
    "designed_chain_path",
    "chain_of_interest",
    "ckpt_path",
    "ckpt_name",
    "seed",
    "input_cif_path",
}


def describe(key: str) -> tuple[str, str]:
    if key in DESCRIPTIONS:
        return DESCRIPTIONS[key]
    if key.startswith("generation.") or key.startswith("graph."):
        return ("生成配置元数据", "")
    # Fallback for any future key: keep the raw name visible.
    return ("官方指标输出", "")


def metric_name(key: str) -> str:
    """Return a concise human-readable name for a metric key."""
    if key in NAMES:
        return NAMES[key]
    return key


def metric_family(key: str) -> str:
    """Return the official metric group of a metric key."""
    family = key.split(".", 1)[0]
    return FAMILY_NAMES.get(family, family)


def format_value(value, unit: str) -> tuple[str, str]:
    if value is None:
        return "NaN", "NaN（无值）"
    if isinstance(value, float) and math.isnan(value):
        return "NaN", "NaN（不适用/未启用）"
    if isinstance(value, float):
        if unit in {"count", "0/1"} and abs(value - round(value)) < 1e-12:
            return f"{int(round(value))}", "computed"
        return f"{value:.4f}", "computed"
    return str(value), "computed"


def metric_columns(df: pd.DataFrame) -> list[str]:
    cols = []
    for col in df.columns:
        if col in META_COLUMNS:
            continue
        if col.startswith(("generation.", "graph.")):
            continue
        if col == "pre_oracle_pass" or "." in col:
            cols.append(col)
    return cols


def main() -> None:
    rows: list[dict] = []
    for src in SOURCES:
        df = pd.read_csv(src["path"])
        if "example_id" not in df.columns:
            continue
        if "filter" in src:
            df = df[df["example_id"].astype(str).map(src["filter"])]
        for _, record in df.iterrows():
            design = src["design_map"](str(record["example_id"]))
            for col in metric_columns(pd.DataFrame([record])):
                desc, unit = describe(col)
                value, status = format_value(record[col], unit)
                rows.append(
                    {
                        "任务": src["task"],
                        "数据集": src["dataset"],
                        "模型": MODEL,
                        "运行": src["run"],
                        "设计": design,
                        "指标组": metric_family(col),
                        "指标名": metric_name(col),
                        "指标 key": col,
                        "指标含义": desc,
                        "结果": value,
                        "单位/备注": unit,
                        "状态": status,
                        "来源 CSV": str(src["path"].relative_to(REPO)),
                    }
                )

    out = pd.DataFrame(rows)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_DIR / "all_measured_metrics_by_task.csv", index=False)

    # Markdown: a short overview plus one table per task (keeps the tables readable).
    lines: list[str] = []
    lines.append("# 本次实测指标全表（按任务）\n")
    lines.append(
        "本文件由 `linshi/eval_script/export_all_metrics.py` 从官方指标输出的\n"
        "`per_example_metrics.csv` 自动生成。`NaN` 表示该指标在此样本/配置下不适用或未启用；\n"
        "没有填 0 代替，也没有重算指标。\n"
    )
    lines.append(f"- 模型：`{MODEL}`\n")
    lines.append("- 平台：Teco SDAA（LoongArch，Torch-SDAA 3.3.0，PyTorch 2.12.0）\n")
    lines.append("- 采样：`thinking_medium`（60 steps，180 trunk passes），eager，batch size 1\n")
    lines.append("- 评测入口：官方 `rfd4-evaluate` / 官方 inline metrics\n")
    lines.append(
        "- 未包含：AF3/OF3 refold、pLDDT/pTM/ipTM/ipAE、pass rate、clustered pass rate、"
        "Rosetta developability（原因见 `linshi/zonghe_report/metric_coverage.md`）\n"
    )

    lines.append(
        "\n## 怎么读\n\n"
        "- 一行 = 一个设计 × 一个指标。\n"
        "- `指标组` 是官方 metric group；`指标名` 是给人看的短名；`指标 key` 是官方 CSV/配置里的程序化名字；`指标含义` 是解释。\n"
        "- `结果` 是官方指标原始输出；`NaN` 表示该样本/配置下不适用或未启用，原因见最后一节。\n"
        "- `运行` 区分 offline / inline 以及 replicates；`设计` 是生成样本 ID。\n"
        "- 下面是按任务拆开的可读版本；`all_measured_metrics_by_task.csv` 是同一份数据的单表（适合筛选、排序、二次统计）。\n"
    )

    lines.append("\n## 总览\n")
    overview = (
        out.groupby(["任务", "数据集", "运行"], dropna=False)
        .agg(设计数=("设计", "nunique"), 指标数=("指标 key", "nunique"))
        .reset_index()
    )
    lines.append(overview.to_markdown(index=False))
    lines.append("\n")

    for task in out["任务"].drop_duplicates():
        lines.append(f"## {task}\n")
        subset = out[out["任务"] == task]
        # Drop the constant columns from the per-task table, keep them in the CSV.
        show = subset[
            [
                "数据集",
                "模型",
                "运行",
                "设计",
                "指标组",
                "指标名",
                "指标 key",
                "指标含义",
                "结果",
                "单位/备注",
                "状态",
            ]
        ]
        lines.append(show.to_markdown(index=False))
        lines.append("\n")

    lines.append("## 未评测的指标及原因\n")
    lines.append(
        "| 类别 | 指标 | 原因 |\n"
        "| --- | --- | --- |\n"
        "| Refolding / oracle | `refolded_*`、`oracle_*`、pLDDT/pTM/ipTM/ipAE | 本机无 apptainer、AF3/OF3 镜像与权重，且无 NVIDIA GPU |\n"
        "| Pass criteria | `*.pass`、pass rate、clustered pass rate | 依赖 oracle/refold 指标；无 oracle 无法判定 |\n"
        "| Rosetta developability | `rosetta_developability.sap_score`、`hydrophobic_exposure_sasa` | 无 PyRosetta 容器 |\n"
        "| Clustering | FoldSeek clustered pass rate | 无 FoldSeek，且无 pass 标签 |\n"
        "| 任务不适用 | antibody、small molecule、RASA、centroid、partial diffusion、unindexed、CATH 等 | 本次没有对应任务/条件 |\n"
    )

    (OUT_DIR / "all_measured_metrics_by_task.md").write_text("\n".join(lines))
    print(f"wrote {len(out)} rows")
    print(OUT_DIR / "all_measured_metrics_by_task.md")
    print(OUT_DIR / "all_measured_metrics_by_task.csv")


if __name__ == "__main__":
    main()