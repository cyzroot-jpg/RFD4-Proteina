#!/usr/bin/env python3
"""Audit (and filter) degenerate "target-copy" designs in a finished run.

A design is flagged degenerate when its chain of interest is a copy of the target
chain in the same complex (sequence identity >= 0.9 and CA RMSD < 1.0 A).
This is a model-level failure mode, not a platform difference; including such
designs inflates A-class interface metrics (e.g. H-bond counts).

Outputs (in <run_root>):
  degenerate_audit.csv   per-design identity/CA-RMSD/flag
  degenerate_audit.md    copy rate and metric means with/without degenerate
  <task>/inference_metrics/per_example_metrics_genuine.csv  (filtered copy)

usage:
  python run_sdaa/audit_degenerate.py <run_root> [--tasks ...]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
TASKS = ["monomer-short", "monomer-medium", "monomer-long", "motif-1BCF", "ppi-pdl1"]
METRICS = [
    ("sequence_developability.gravy", "gravy"),
    ("sequence_developability.instability_index", "instability"),
    ("interchain_interactions.hbond_atom_pair_count_coi", "hbond"),
    ("interchain_interactions.saltbridge_residue_pair_count_coi", "salt"),
    ("interchain_interactions.hydrophobic_atom_pair_count_coi", "hydrophobic"),
]


def _helpers():
    spec = importlib.util.spec_from_file_location("cd", HERE / "experiments" / "compare_designs.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _key(name: str) -> str:
    for suf in (".cif.zst", ".cif"):
        if name.endswith(suf):
            name = name[: -len(suf)]
    return re.sub(r"_job\d+$", "", name.removesuffix("_generated"))


def _audit_one(helpers, path: Path) -> dict:
    aa, coi = helpers._load(path)
    chains = sorted(set(str(x) for x in (aa.chain_iid if "chain_iid" in aa.get_annotation_categories()
                                         else aa.chain_id).tolist()))
    targets = [c for c in chains if c != coi]
    if not targets:
        return {"key": _key(path.name), "applicable": False}
    order_c, seq_c, coords_c = helpers._residues(aa, coi)
    order_t, seq_t, coords_t = helpers._residues(aa, targets[0])
    pairs, _ = helpers._alignment_pairs(seq_c, seq_t)
    ident = sum(1 for i, j in pairs if seq_c[i] == seq_t[j]) / max(len(pairs), 1)
    ca, cb = [], []
    for i, j in pairs:
        if "CA" in coords_c[order_c[i]] and "CA" in coords_t[order_t[j]]:
            ca.append(coords_c[order_c[i]]["CA"])
            cb.append(coords_t[order_t[j]]["CA"])
    rmsd = float("nan")
    if len(ca) >= 3:
        ca, cb = np.array(ca), np.array(cb)
        m, t = ca - ca.mean(0), cb - cb.mean(0)
        u, _, vt = np.linalg.svd(m.T @ t)
        d = np.sign(np.linalg.det(u @ vt))
        rmsd = float(np.sqrt(np.mean(np.sum((m @ (u @ np.diag([1, 1, d]) @ vt) - t) ** 2, axis=1))))
    return {"key": _key(path.name), "applicable": True, "target_id": ident,
            "target_ca_rmsd": rmsd, "degenerate": bool(ident >= 0.9 and rmsd < 1.0),
            "binder_len": len(seq_c), "target_len": len(seq_t)}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run_root", type=Path)
    ap.add_argument("--tasks", nargs="*", default=TASKS)
    args = ap.parse_args(argv)
    root = args.run_root.resolve()
    helpers = _helpers()

    rows, lines = [], ["# Degenerate design audit", "", f"- root: `{root}`", ""]
    for task in args.tasks:
        samples = root / task / "inference_samples"
        if not samples.is_dir():
            continue
        cis = sorted(samples.glob("**/*_generated.cif"))
        if not cis:
            continue
        info = [_audit_one(helpers, p) for p in cis]
        df = pd.DataFrame(info)
        if "applicable" not in df or not df["applicable"].any():
            lines.append(f"- `{task}`: single-chain or no target, audit not applicable.")
            continue
        df["task"] = task
        rows.append(df)
        n = len(df)
        n_bad = int(df["degenerate"].sum())
        lines.append(f"## {task}")
        lines.append("")
        lines.append(f"- designs: {n}, degenerate target copies: **{n_bad}** "
                     f"({n_bad / n:.0%})")
        lines.append("")
        lines.append("| design | binder len | target identity | CA RMSD (Å) | degenerate |")
        lines.append("| --- | ---: | ---: | ---: | --- |")
        for _, r in df.sort_values("key").iterrows():
            lines.append(f"| {r['key']} | {int(r['binder_len'])} | {r['target_id']:.3f} | "
                         f"{r['target_ca_rmsd']:.3f} | {'Y' if r['degenerate'] else 'N'} |")

        mpath = root / task / "inference_metrics" / "per_example_metrics.csv"
        if mpath.exists():
            m = pd.read_csv(mpath)
            m["key"] = m["example_id"].astype(str).map(_key) if "example_id" in m else None
            merged = m.merge(df[["key", "degenerate"]], on="key", how="left")
            if "degenerate" in merged:
                merged["degenerate"] = merged["degenerate"].fillna(False)
                merged[~merged["degenerate"]].drop(columns=["degenerate", "key"]).to_csv(
                    mpath.with_name("per_example_metrics_genuine.csv"), index=False)
                lines += ["", "| metric | all | genuine | Δ |", "| --- | ---: | ---: | ---: |"]
                for col, short in METRICS:
                    if col not in merged:
                        continue
                    v = pd.to_numeric(merged[col], errors="coerce")
                    allm, genm = float(v.mean()), float(v[~merged["degenerate"]].mean())
                    lines.append(f"| {short} | {allm:.4f} | {genm:.4f} | {genm - allm:+.4f} |")
        lines.append("")

    if rows:
        pd.concat(rows).to_csv(root / "degenerate_audit.csv", index=False)
    (root / "degenerate_audit.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {root}/degenerate_audit.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(__import__("sys").argv[1:]))