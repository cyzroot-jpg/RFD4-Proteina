#!/usr/bin/env python3
"""PPI A-class attribution: per-design deltas, degeneracy, and leave-one-out.

Inputs: the two design sets (CIFs) and two metric CSVs computed on the SAME host
with the same code (so metric implementation cannot explain any difference).
Outputs: a per-design table and a summary of what drives the mean difference.

usage:
  python run_sdaa/experiments/analyze_ppi_aclass.py \
    --sdaa-designs <dir> --cuda-designs <dir> \
    --sdaa-metrics <csv> --cuda-metrics <csv> --out <dir>
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
METRICS = [
    ("sequence_developability.gravy", "gravy"),
    ("sequence_developability.instability_index", "instability"),
    ("interchain_interactions.hbond_atom_pair_count_coi", "hbond"),
    ("interchain_interactions.saltbridge_residue_pair_count_coi", "salt"),
    ("interchain_interactions.hydrophobic_atom_pair_count_coi", "hydrophobic"),
]


def _helpers():
    spec = importlib.util.spec_from_file_location("cd", HERE / "compare_designs.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _rep(text: str) -> str | None:
    m = re.search(r"rep(\d+)", text)
    return f"rep{m.group(1)}" if m else None


def _design_info(helpers, cis, key):
    aa, coi = helpers._load(cis)
    order_c, seq_c, coords_c = helpers._residues(aa, coi)
    chains = sorted(set(str(x) for x in (aa.chain_iid if "chain_iid" in aa.get_annotation_categories()
                                         else aa.chain_id).tolist()))
    targets = [c for c in chains if c != coi]
    info = {"key": key, "binder_len": len(seq_c)}
    if not targets:
        return info
    target = targets[0]
    order_t, seq_t, coords_t = helpers._residues(aa, target)
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
        cm, cb0 = ca.mean(0), cb.mean(0)
        m, t = ca - cm, cb - cb0
        u, _, vt = np.linalg.svd(m.T @ t)
        d = np.sign(np.linalg.det(u @ vt))
        rot = u @ np.diag([1, 1, d]) @ vt
        rmsd = float(np.sqrt(np.mean(np.sum((m @ rot - t) ** 2, axis=1))))
    info.update({"target_id": ident, "target_ca_rmsd": rmsd,
                 "degenerate": bool(ident >= 0.9 and rmsd < 1.0)})
    return info


def _load_metrics(path: Path, label: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df = df[df["designed_structure_path"].astype(str).str.contains("_generated")]
    df["key"] = df["designed_structure_path"].map(_rep)
    keep = ["key"] + [c for c, _ in METRICS if c in df.columns]
    out = df[keep].copy()
    return out.add_prefix(f"{label}__").rename(columns={f"{label}__key": "key"})


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sdaa-designs", type=Path, required=True)
    ap.add_argument("--cuda-designs", type=Path, required=True)
    ap.add_argument("--sdaa-metrics", type=Path, required=True)
    ap.add_argument("--cuda-metrics", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(argv)

    helpers = _helpers()
    sets = {
        "sdaa": helpers._collect(args.sdaa_designs),
        "cuda": helpers._collect(args.cuda_designs),
    }
    rows = []
    for label in ("sdaa", "cuda"):
        for key, path in sets[label].items():
            info = _design_info(helpers, path, key)
            info["source"] = label
            info["rep"] = _rep(key)
            rows.append(info)
    raw = pd.DataFrame(rows)
    wide = raw.pivot(index="rep", columns="source",
                     values=["binder_len", "target_id", "target_ca_rmsd", "degenerate"])
    wide.columns = [f"{field}_{src}" for field, src in wide.columns]
    wide = wide.reset_index()

    ma = _load_metrics(args.sdaa_metrics, "sdaa")
    mb = _load_metrics(args.cuda_metrics, "cuda")
    metrics = ma.merge(mb, on="key")

    out = metrics.rename(columns={"key": "rep"}).merge(wide, on="rep", how="left")
    for col, short in METRICS:
        a, b = f"sdaa__{col}", f"cuda__{col}"
        if a in metrics and b in metrics:
            out[f"{short}_sdaa"] = metrics[a]
            out[f"{short}_cuda"] = metrics[b]
            out[f"{short}_delta"] = metrics[a] - metrics[b]

    args.out.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.out / "ppi_aclass.csv", index=False)

    lines = ["# PPI A-class attribution", "",
             "| rep | len S/C | deg S/C | GRAVY S/C (Δ) | instability S/C (Δ) | H-bond S/C (Δ) | salt S/C (Δ) |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for _, r in out.iterrows():
        def cell(name, fmt="{:.3f}"):
            a, b, d = r.get(f"{name}_sdaa"), r.get(f"{name}_cuda"), r.get(f"{name}_delta")
            if pd.isna(a) or pd.isna(b):
                return "-"
            return f"{fmt.format(a)} / {fmt.format(b)} ({d:+.3f})"
        lines.append(f"| {r['rep']} | {int(r['binder_len_sdaa'])} / {int(r['binder_len_cuda'])} | "
                     f"{'Y' if r['degenerate_sdaa'] else 'N'} / {'Y' if r['degenerate_cuda'] else 'N'} | "
                     f"{cell('gravy')} | {cell('instability', '{:.1f}')} | "
                     f"{cell('hbond', '{:.0f}')} | {cell('salt', '{:.0f}')} |")

    lines += ["", "## What drives the mean difference", ""]
    clean = out[~(out["degenerate_sdaa"] | out["degenerate_cuda"])]
    for short in ("gravy", "instability", "hbond", "salt"):
        col = f"{short}_delta"
        if col not in out:
            continue
        d = out[col].dropna()
        dc = clean[col].dropna()
        pos = int((d > 0).sum())
        neg = int((d < 0).sum())
        lines.append(f"- **{short}**: all n={len(d)}, mean Δ={d.mean():+.3f}, "
                     f"direction +/{pos} -/{neg}; excluding degenerate n={len(dc)}, mean Δ={dc.mean():+.3f}")
        if len(dc) >= 2:
            loo = [dc.drop(idx).mean() for idx in dc.index]
            lines.append(f"  - leave-one-out mean range: [{min(loo):+.3f}, {max(loo):+.3f}]")
    lines += ["", "| rep | Δ GRAVY | Δ instability |", "| --- | ---: | ---: |"]
    for _, r in out.iterrows():
        lines.append(f"| {r['rep']} | {r.get('gravy_delta', float('nan')):+.3f} | "
                     f"{r.get('instability_delta', float('nan')):+.1f} |")
    (args.out / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/summary.md and ppi_aclass.csv")
    print(out[["rep", "binder_len_sdaa", "binder_len_cuda", "degenerate_sdaa", "degenerate_cuda"]].to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))