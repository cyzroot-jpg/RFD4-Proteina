#!/usr/bin/env python3
"""Attribute per-design refold differences (SDAA vs CUDA) to design vs oracle noise.

Inputs (all optional except --out):
  --pairs    pairs.csv from compare_designs.py (identity / design backbone RMSD)
  --refold-a per-example metrics CSV from the SDAA refold (A)
  --refold-b per-example metrics CSV from the CUDA refold (B)
  --sigma    oracle_sigma.csv from aggregate_repeats.py (oracle std per metric)

For every metric present in both refold CSVs it reports the per-design delta
|A - B| and, when --sigma is given, compares it with the variance expected from
two independent oracle samples (std_diff = sqrt(2) * std_single).

usage:
  python run_sdaa/experiments/analyze_experiment.py --out <dir> \
    --pairs <pairs.csv> --refold-a <a.csv> --refold-b <b.csv> --sigma <oracle_sigma.csv>
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import spearmanr

TASKS = ["monomer-short", "monomer-medium", "monomer-long", "motif-1BCF", "ppi-pdl1"]


def _key(value: str) -> str:
    name = Path(str(value)).name
    for suffix in (".cif.zst", ".cif", ".mmcif.zst", ".mmcif"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    name = re.sub(r"_job\d+$", "", name)
    return name.removesuffix("_generated")


def _task(key: str) -> str:
    for t in TASKS:
        if key.startswith(t):
            return t
    return key.split("_")[0]


def _load_refold(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    key_col = "designed_structure_path" if "designed_structure_path" in df.columns else "example_id"
    df["key"] = df[key_col].map(_key)
    metrics = [
        c for c in df.columns
        if pd.api.types.is_numeric_dtype(df[c])
        and (c.startswith(("oracle", "refolded_")) or ".pass" in c)
    ]
    out = df[["key"] + metrics].copy()
    out["task"] = out["key"].map(_task)
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--pairs", type=Path)
    ap.add_argument("--refold-a", type=Path)
    ap.add_argument("--refold-b", type=Path)
    ap.add_argument("--sigma", type=Path)
    ap.add_argument("--a-name", default="sdaa")
    ap.add_argument("--b-name", default="cuda")
    args = ap.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)

    lines = [f"# Refold attribution: {args.a_name} vs {args.b_name}", ""]
    deltas = None
    if args.refold_a and args.refold_b:
        a = _load_refold(args.refold_a)
        b = _load_refold(args.refold_b)
        common = [c for c in a.columns if c in b.columns and c != "task"]
        merged = a.merge(b, on="key", suffixes=("_a", "_b"), how="inner")
        merged = merged.merge(a[["key", "task"]], on="key", how="left", suffixes=("", "_drop"))
        deltas = merged[["key", "task"]].copy()
        for metric in common:
            if metric == "key":
                continue
            va, vb = merged[f"{metric}_a"], merged[f"{metric}_b"]
            deltas[f"{metric}__a"] = va
            deltas[f"{metric}__b"] = vb
            deltas[f"{metric}__delta"] = va - vb
        deltas.to_csv(args.out / "refold_deltas.csv", index=False)
        lines += [f"- paired designs: {len(deltas)}", ""]

    pairs = None
    if args.pairs and args.pairs.exists():
        pairs = pd.read_csv(args.pairs)[["key", "identity_aligned", "backbone_rmsd"]]
        pairs["task"] = pairs["key"].map(_task)
        if deltas is not None:
            deltas = deltas.merge(pairs, on=["key", "task"], how="left")
            deltas.to_csv(args.out / "refold_deltas.csv", index=False)

    sigma = {}
    if args.sigma and args.sigma.exists():
        sdf = pd.read_csv(args.sigma)
        sigma = dict(zip(sdf["metric"], sdf["median_std"]))

    summary_rows = []
    if deltas is not None:
        metric_cols = [c for c in deltas.columns if c.endswith("__delta")]
        lines += ["| metric | median |Δ| | max |Δ| | 2σ_oracle | noise-consistent | ρ(identity, |Δ|) |",
                  "| --- | ---: | ---: | ---: | ---: | ---: |"]
        for col in metric_cols:
            metric = col[: -len("__delta")]
            d = deltas[col].abs().dropna()
            if d.empty:
                continue
            sigma_single = sigma.get(metric)
            threshold = 2 * np.sqrt(2) * sigma_single if sigma_single else np.nan
            frac = float((d <= threshold).mean()) if sigma_single else np.nan
            rho = np.nan
            if pairs is not None and "identity_aligned" in deltas.columns:
                sub = deltas[[col, "identity_aligned"]].dropna()
                if len(sub) >= 4 and sub["identity_aligned"].nunique() > 1 and sub[col].nunique() > 1:
                    rho = spearmanr(sub["identity_aligned"], sub[col].abs()).statistic
            summary_rows.append({
                "metric": metric,
                "median_abs_delta": float(d.median()),
                "max_abs_delta": float(d.max()),
                "two_sigma_oracle_diff": float(threshold) if sigma_single else np.nan,
                "frac_within_2sigma": frac,
                "spearman_identity_vs_abs_delta": float(rho) if not np.isnan(rho) else np.nan,
            })
            lines.append(
                f"| {metric} | {d.median():.4f} | {d.max():.4f} | "
                f"{'' if np.isnan(threshold) else f'{threshold:.4f}'} | "
                f"{'' if np.isnan(frac) else f'{frac:.1%}'} | "
                f"{'' if np.isnan(rho) else f'{rho:.2f}'} |"
            )
        pd.DataFrame(summary_rows).to_csv(args.out / "attribution_summary.csv", index=False)

    if pairs is not None:
        lines += ["", "## Design-level", "",
                  "| task | pairs | median identity | median design backbone RMSD (Å) |",
                  "| --- | ---: | ---: | ---: |"]
        for task, g in pairs.groupby("task"):
            lines.append(
                f"| {task} | {len(g)} | {g['identity_aligned'].median():.4f} | "
                f"{g['backbone_rmsd'].median():.3f} |"
            )

    lines += ["", "## How to read", "",
              "- `2σ_oracle` = `2 * sqrt(2) * median_std` from repeated refolds of the same CIFs:",
              "  the spread expected for two independent oracle samples of the same design.",
              "- `noise-consistent` high (≈100%) and identity ≈1 → the B-class difference is oracle noise.",
              "- low `noise-consistent` with low identity → the platforms generated different designs.",
              "- ρ(identity, |Δ|) strongly negative → larger metric differences where designs differ more."]
    (args.out / "attribution.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/attribution.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))