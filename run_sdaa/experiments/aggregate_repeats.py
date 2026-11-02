#!/usr/bin/env python3
"""Aggregate repeated refolds (one directory per seed) into per-design variance.

usage:
    python run_sdaa/experiments/aggregate_repeats.py <repeats_root>
Outputs (inside <repeats_root>):
    repeats_per_design.csv   key, seed, metric, value
    repeats_stats.csv        key, metric, mean, std, min, max, n
    oracle_sigma.csv         metric, median_std, max_std  (for attribution)
    repeats_summary.md
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pandas as pd


def _key(value: str) -> str:
    name = Path(str(value)).name
    for suffix in (".cif.zst", ".cif", ".mmcif.zst", ".mmcif"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    name = re.sub(r"_job\d+$", "", name)
    return name.removesuffix("_generated")


def _metric_columns(df: pd.DataFrame) -> list[str]:
    return [
        c for c in df.columns
        if pd.api.types.is_numeric_dtype(df[c])
        and (c.startswith(("oracle", "refolded_")) or ".pass" in c)
    ]


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: aggregate_repeats.py <repeats_root>", file=sys.stderr)
        return 2
    root = Path(argv[0]).resolve()
    rows = []
    for seed_dir in sorted(root.glob("seed*")):
        seed = seed_dir.name.replace("seed", "")
        metric_dir = seed_dir / "evaluation_metrics"
        if not metric_dir.is_dir():
            continue
        files = list(metric_dir.glob("*per_example_metrics*.csv"))
        if not files:
            continue
        df = pd.read_csv(sorted(files)[-1])
        key_col = "designed_structure_path" if "designed_structure_path" in df.columns else "example_id"
        df["key"] = df[key_col].map(_key)
        for col in _metric_columns(df):
            for key, value in zip(df["key"], pd.to_numeric(df[col], errors="coerce")):
                if pd.notna(value):
                    rows.append({"key": key, "seed": seed, "metric": col, "value": float(value)})

    long = pd.DataFrame(rows)
    if long.empty:
        print("no repeated metrics found", file=sys.stderr)
        return 1
    long.to_csv(root / "repeats_per_design.csv", index=False)

    stats = (
        long.groupby(["key", "metric"])["value"]
        .agg(["mean", "std", "min", "max", "count"])
        .reset_index()
        .rename(columns={"count": "n"})
    )
    stats.to_csv(root / "repeats_stats.csv", index=False)

    sigma = (
        stats.groupby("metric")["std"]
        .agg(["median", "max", "count"])
        .reset_index()
        .rename(columns={"median": "median_std", "max": "max_std", "count": "n_designs"})
    )
    sigma.to_csv(root / "oracle_sigma.csv", index=False)

    lines = [
        "# Oracle repeat variance",
        "",
        f"- root: `{root}`",
        f"- seeds: {sorted(long['seed'].unique().tolist())}",
        f"- designs: {long['key'].nunique()}",
        "",
        "| metric | median std | max std | designs |",
        "| --- | ---: | ---: | ---: |",
    ]
    for _, r in sigma.sort_values("median_std", ascending=False).iterrows():
        lines.append(f"| {r['metric']} | {r['median_std']:.4f} | {r['max_std']:.4f} | {int(r['n_designs'])} |")
    (root / "repeats_summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {root}/repeats_stats.csv and oracle_sigma.csv ({long['key'].nunique()} designs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))