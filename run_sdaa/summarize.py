#!/usr/bin/env python3
"""Write summary.md / metrics.csv / checksums.sha256 for a pipeline run root.

All metric values come from the official metric CSVs; nothing is recomputed or
imputed. Missing metrics stay blank.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import pandas as pd

TASKS = ["monomer-short", "monomer-medium", "monomer-long", "motif-1BCF", "ppi-pdl1"]

METRICS = [
    ("amino_acid_composition.n_standard_residues", "n_res", "n_res"),
    ("bond_length_metrics.bond_length.frac_unreasonable", "bad_bond max", "max"),
    ("clash_metrics.frac_atoms_clashing_1p5A", "clash max", "max"),
    ("sse_distribution.helix_fraction", "helix", "mean"),
    ("sse_distribution.sheet_fraction", "sheet", "mean"),
    ("sse_distribution.loop_fraction", "loop", "mean"),
    ("sse_distribution.num_ss_elements", "n_SSE", "mean"),
    ("sequence_developability.gravy", "GRAVY", "mean"),
    ("sequence_developability.instability_index", "instability", "mean"),
    ("design_motif_allatom_rmsd.rmsd", "motif RMSD (Å)", "mean"),
    ("hotspot_obedience.hotspot_obedience", "hotspot", "mean"),
    ("interchain_interactions.hbond_atom_pair_count_coi", "H-bond pairs", "mean"),
    ("interchain_interactions.saltbridge_residue_pair_count_coi", "salt-bridge pairs", "mean"),
]


def read_env(root: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    path = root / "run_env.txt"
    if path.exists():
        for line in path.read_text().splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()
    return env


def per_example_csv(root: Path, task: str) -> Path | None:
    base = root / task / "inference_metrics"
    for name in ("per_example_metrics.csv", "per_example_metrics_job0.csv"):
        path = base / name
        if path.exists():
            return path
    return None


def load_rows(root: Path) -> dict[str, pd.DataFrame]:
    rows: dict[str, pd.DataFrame] = {}
    for task in TASKS:
        path = per_example_csv(root, task)
        if path is not None:
            rows[task] = pd.read_csv(path)
    return rows


def fmt(value: float, digits: int = 4) -> str:
    return "" if pd.isna(value) else f"{value:.{digits}f}"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: summarize.py <run_root>", file=sys.stderr)
        return 2
    root = Path(argv[0]).resolve()
    env = read_env(root)
    rows = load_rows(root)

    metric_lines = [
        f"# RFD4-Proteina full pipeline summary ({env.get('platform', 'unknown')})",
        "",
        "## Run information",
        "",
        "| item | value |",
        "| --- | --- |",
    ]
    for key in (
        "platform",
        "seed",
        "ckpt",
        "hf_ckpt_revision",
        "ckpt_model_safetensors_sha256",
        "git_commit",
        "git_dirty_src_configs",
        "python",
        "torch",
        "torch_sdaa",
        "foldseek",
        "apptainer",
        "out_root",
        "start",
        "end",
    ):
        if key in env:
            metric_lines.append(f"| {key} | `{env[key]}` |")

    metric_lines += ["", "## Metrics (official inline metrics)", ""]
    header = ["task", "n"] + [label for _, label, _ in METRICS]
    metric_lines.append("| " + " | ".join(header) + " |")
    metric_lines.append("| --- |" + " ---: |" * (len(header) - 1))
    flat_rows = []
    for task, df in rows.items():
        row = {"task": task, "n": len(df)}
        cells = [task, str(len(df))]
        for column, label, mode in METRICS:
            if column not in df.columns:
                row[label] = None
                cells.append("")
                continue
            values = pd.to_numeric(df[column], errors="coerce")
            if values.notna().sum() == 0:
                row[label] = None
                cells.append("")
                continue
            value = values.max() if mode == "max" else values.mean()
            row[label] = float(value)
            cells.append(fmt(value))
        flat_rows.append(row)
        metric_lines.append("| " + " | ".join(cells) + " |")

    metric_lines += [
        "",
        "Ranges where meaningful:",
        "",
        "| task | n_res | motif RMSD (Å) | hotspot |",
        "| --- | --- | --- | --- |",
    ]
    for task, df in rows.items():
        def rng(column: str) -> str:
            if column not in df.columns:
                return ""
            values = pd.to_numeric(df[column], errors="coerce").dropna()
            if values.empty:
                return ""
            return f"{values.mean():.2f} ({values.min():.2f}-{values.max():.2f})"

        metric_lines.append(
            f"| {task} | {rng('amino_acid_composition.n_standard_residues')} | "
            f"{rng('design_motif_allatom_rmsd.rmsd')} | {rng('hotspot_obedience.hotspot_obedience')} |"
        )

    metric_lines += ["", "## Performance", ""]
    metric_lines.append(
        "| task | designs | wall (s) | cpu time (s) | cpu util (%) | peak device (GB) | peak RSS (GB) | designs/s |"
    )
    metric_lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
    for task in TASKS:
        path = root / task / "inference_metrics" / "resource_usage.json"
        if not path.exists():
            continue
        usage = json.loads(path.read_text())
        metric_lines.append(
            "| {task} | {n} | {wall:.1f} | {cpu:.1f} | {util:.2f} | {dev:.2f} | {rss:.2f} | {dps:.4f} |".format(
                task=task,
                n=usage.get("num_examples", 0),
                wall=usage.get("wall_time_s", float("nan")),
                cpu=usage.get("cpu_time_s", float("nan")),
                util=usage.get("cpu_utilization_percent", float("nan")),
                dev=usage.get("device_peak_memory_bytes", 0) / 2**30,
                rss=usage.get("process_max_rss_bytes", 0) / 2**30,
                dps=usage.get("examples_per_second", float("nan")),
            )
        )

    metric_lines += ["", "## Output inventory", ""]
    for task in TASKS:
        samples = list((root / task / "inference_samples").glob("**/*_generated.cif"))
        evals = root / task / "evaluation" / "evaluation_metrics"
        metric_lines.append(
            f"- `{task}`: {len(samples)} generated CIF; inference_metrics="
            f"{(root / task / 'inference_metrics').is_dir()}; evaluation_metrics={evals.is_dir()}"
        )

    metric_lines += [
        "",
        "## Gaps",
        "",
        "- No AF3/OF3 on this host: no scRMSD / pLDDT / ipTM / ipAE / pass rate. Refolding is a CUDA-side step.",
        "- No PyRosetta: `rosetta_developability.*` absent; `developability.pass` incomplete.",
        "- No FoldSeek: no structural clustering / clustered pass rate.",
        "- PPI uses the official input `data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst`.",
        "",
    ]

    (root / "summary.md").write_text("\n".join(metric_lines))
    pd.DataFrame(flat_rows).to_csv(root / "metrics.csv", index=False)

    manifest = []
    for path in sorted(root.glob("**/*")):
        if not path.is_file():
            continue
        if path.name in {"checksums.sha256", "DONE", "FAILED"}:
            continue
        if path.suffix in {".cif", ".csv", ".json", ".log", ".txt", ".md", ".sha256", ".py", ".sh"}:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            manifest.append(f"{digest}  {path.relative_to(root)}")
    (root / "checksums.sha256").write_text("\n".join(manifest) + "\n")

    print(f"wrote {root / 'summary.md'}")
    print(f"wrote {root / 'metrics.csv'}")
    print(f"wrote {root / 'checksums.sha256'} ({len(manifest)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))