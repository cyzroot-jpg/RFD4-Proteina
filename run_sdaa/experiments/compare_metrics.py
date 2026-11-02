#!/usr/bin/env python3
"""Compare A-class and B-class metrics between two run roots.

Each root is expected to contain, per task:
  <root>/<task>/inference_metrics/per_example_metrics.csv        (A class)
  <root>/<task>/evaluation/evaluation_metrics/per_example_metrics.csv  (B class, optional)

usage:
  python run_sdaa/experiments/compare_metrics.py \
    --a-root run_sdaa/results_aligned/sdaa \
    --b-root run_sdaa/results_planA/cuda \
    --out run_sdaa/experiments/out/planA/compare
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

TASKS = ["monomer-short", "monomer-medium", "monomer-long", "motif-1BCF", "ppi-pdl1"]
A_METRICS = [
    ("amino_acid_composition.n_standard_residues", "n_res"),
    ("bond_length_metrics.bond_length.frac_unreasonable", "bad_bond"),
    ("clash_metrics.frac_atoms_clashing_1p5A", "clash"),
    ("sse_distribution.helix_fraction", "helix"),
    ("sse_distribution.sheet_fraction", "sheet"),
    ("sse_distribution.loop_fraction", "loop"),
    ("sse_distribution.num_ss_elements", "n_SSE"),
    ("sequence_developability.gravy", "GRAVY"),
    ("sequence_developability.instability_index", "instability"),
    ("design_motif_allatom_rmsd.rmsd", "motif_rmsd"),
    ("hotspot_obedience.hotspot_obedience", "hotspot"),
    ("interchain_interactions.hbond_atom_pair_count_coi", "hbond_pairs"),
    ("interchain_interactions.saltbridge_residue_pair_count_coi", "salt_pairs"),
]


def _csv(root: Path, task: str, kind: str) -> Path | None:
    if kind == "a":
        base = root / task / "inference_metrics"
    else:
        base = root / task / "evaluation" / "evaluation_metrics"
    for name in ("per_example_metrics.csv", "per_example_metrics_job0.csv"):
        p = base / name
        if p.exists():
            return p
    return None


def _agg(df: pd.DataFrame, columns) -> dict:
    out = {}
    for col, short in columns:
        if col in df.columns:
            v = pd.to_numeric(df[col], errors="coerce")
            if v.notna().any():
                out[short] = float(v.mean())
    return out


def _b_columns(df: pd.DataFrame):
    cols = []
    for c in df.columns:
        if not pd.api.types.is_numeric_dtype(df[c]):
            continue
        if c.startswith("refolded_"):
            cols.append((c, c.replace("refolded_", "").replace(".rmsd", "")))
        elif c.endswith(".pass"):
            cols.append((c, c.replace(".pass", ".pass")))
        elif c.endswith(("overall_plddt", "plddt_coi", "overall_ptm", "ptm_coi",
                         "iptm_coi", "overall_iptm", "min_ipae_coi", "overall_pae")):
            cols.append((c, c.split(".")[-1] + "@" + c.split(".")[0]))
    return cols


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--a-root", type=Path, required=True)
    ap.add_argument("--b-root", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--a-eval-root", type=Path, default=None,
                    help="root for B-class CSVs (default: --a-root)")
    ap.add_argument("--b-eval-root", type=Path, default=None,
                    help="root for B-class CSVs (default: --b-root)")
    ap.add_argument("--a-name", default="sdaa")
    ap.add_argument("--b-name", default="cuda")
    ap.add_argument("--tasks", nargs="*", default=TASKS)
    args = ap.parse_args(argv)

    args.out.mkdir(parents=True, exist_ok=True)
    a_eval = args.a_eval_root or args.a_root
    b_eval = args.b_eval_root or args.b_root
    rows = []
    for task in args.tasks:
        pa, pb = _csv(args.a_root, task, "a"), _csv(args.b_root, task, "a")
        if pa is None or pb is None:
            print(f"skip {task}: missing A-class CSV")
            continue
        ab = pd.read_csv(pb)
        aa = pd.read_csv(pa)
        va, vb = _agg(aa, A_METRICS), _agg(ab, A_METRICS)
        for col, short in A_METRICS:
            if short in va and short in vb:
                rows.append({"task": task, "class": "A", "metric": short,
                             f"{args.a_name}": va[short], f"{args.b_name}": vb[short],
                             "delta": vb[short] - va[short]})
        ea, eb = _csv(a_eval, task, "b"), _csv(b_eval, task, "b")
        if ea and eb:
            da, db = pd.read_csv(ea), pd.read_csv(eb)
            common = [(c, s) for c, s in _b_columns(da) if c in db.columns]
            va, vb = _agg(da, common), _agg(db, common)
            for col, short in common:
                if short in va and short in vb:
                    rows.append({"task": task, "class": "B", "metric": short,
                                 f"{args.a_name}": va[short], f"{args.b_name}": vb[short],
                                 "delta": vb[short] - va[short]})

    df = pd.DataFrame(rows)
    df.to_csv(args.out / "metrics_compare.csv", index=False)
    lines = [f"# {args.a_name} vs {args.b_name} metric comparison", "",
             f"- A: `{args.a_root}`", f"- B: `{args.b_root}`", ""]
    for cls, title in (("A", "A class (pre-oracle)"), ("B", "B class (refold)")):
        sub = df[df["class"] == cls]
        if sub.empty:
            continue
        lines += [f"## {title}", "",
                  f"| task | metric | {args.a_name} | {args.b_name} | Δ ({args.b_name}−{args.a_name}) |",
                  "| --- | --- | ---: | ---: | ---: |"]
        for _, r in sub.iterrows():
            lines.append(f"| {r['task']} | {r['metric']} | {r[args.a_name]:.4f} | "
                         f"{r[args.b_name]:.4f} | {r['delta']:+.4f} |")
        lines.append("")
    (args.out / "compare.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/compare.md and metrics_compare.csv")
    print(df.to_string(index=False, float_format=lambda x: f"{x:.4f}"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))