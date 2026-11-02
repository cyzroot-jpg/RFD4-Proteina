#!/usr/bin/env python3
"""Per-design comparison between two generated design sets (e.g. SDAA vs CUDA).

Pairs designs by file stem (``<key>_generated.cif``), extracts the designed
chain (chain of interest), and reports for every pair:

  - sequence identity (global alignment, aligned columns and min-length)
  - design-vs-design backbone RMSD after superposition on matched CA atoms
  - optional delta of per-design inline metrics from the two metric CSVs

This answers one question only: *did the two platforms generate the same
designs?* It needs no oracle.

usage:
    python run_sdaa/experiments/compare_designs.py \
        --a run_sdaa/results_aligned/sdaa/monomer-short/inference_samples \
        --b /path/to/cuda/monomer-short/inference_samples \
        --out run_sdaa/experiments/out/monomer-short \
        [--a-metrics <per_example_metrics.csv>] [--b-metrics <...>] \
        [--chain coi|all|<chain_id>]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from Bio import Align
from Bio.Data.PDBData import protein_letters_3to1_extended as THREE_TO_ONE

BACKBONE = ("N", "CA", "C", "O")


def _load(path: Path):
    import rfproteina  # noqa: F401  (activates the SDAA compat shim when needed)
    from atomworks.io.parser import parse
    from rfproteina.utils.parse_presets import STANDARD_ANNOTATIONS_ONLY
    from rfproteina.utils.chain import get_chain_of_interest

    aa = parse(path, config=STANDARD_ANNOTATIONS_ONLY)["assemblies"]["1"][0]
    coi, _ = get_chain_of_interest(aa)
    return aa, coi


def _residues(aa, chain: str):
    """Return residue order, one-letter sequence and per-residue atom coords."""
    cats = aa.get_annotation_categories()
    if chain == "all":
        sel = aa[aa.is_protein] if "is_protein" in cats else aa
    elif "chain_iid" in cats and chain in set(str(x) for x in aa.chain_iid.tolist()):
        sel = aa[aa.chain_iid == chain]
    else:
        sel = aa[aa.chain_id == chain]
    order: list[tuple[str, object]] = []
    seq: list[str] = []
    coords: dict[tuple[str, object], dict[str, np.ndarray]] = {}
    for ch, rid, rn, name, xyz in zip(
        sel.chain_id, sel.res_id, sel.res_name, sel.atom_name, sel.coord
    ):
        key = (str(ch), str(rid))
        if key not in coords:
            coords[key] = {}
            order.append(key)
            seq.append(THREE_TO_ONE.get(str(rn), "X"))
        coords[key][str(name)] = np.asarray(xyz, dtype=np.float64)
    return order, "".join(seq), coords


def _alignment_pairs(seq_a: str, seq_b: str):
    aligner = Align.PairwiseAligner()
    aligner.mode = "global"
    aligner.match_score = 2.0
    aligner.mismatch_score = -1.0
    aligner.open_gap_score = -2.0
    aligner.extend_gap_score = -0.5
    aln = aligner.align(seq_a, seq_b)[0]
    pairs = []
    for (a0, a1), (b0, b1) in zip(aln.aligned[0], aln.aligned[1]):
        for k in range(a1 - a0):
            pairs.append((int(a0 + k), int(b0 + k)))
    return pairs, int(aln.length)


def _kabsch(mobile: np.ndarray, target: np.ndarray):
    center_m = mobile.mean(axis=0)
    center_t = target.mean(axis=0)
    m = mobile - center_m
    t = target - center_t
    u, _, vt = np.linalg.svd(m.T @ t)
    d = np.sign(np.linalg.det(u @ vt))
    rot = u @ np.diag([1.0, 1.0, d]) @ vt
    return rot, center_m, center_t


def _rmsd(coords_a: dict, coords_b: dict, pairs, order_a, order_b):
    ca_a, ca_b = [], []
    matched = []
    for i, j in pairs:
        key_a, key_b = order_a[i], order_b[j]
        if "CA" in coords_a[key_a] and "CA" in coords_b[key_b]:
            ca_a.append(coords_a[key_a]["CA"])
            ca_b.append(coords_b[key_b]["CA"])
            matched.append((key_a, key_b))
    if len(ca_a) < 3:
        return float("nan"), float("nan"), len(matched), 0
    rot, ca, cb = _kabsch(np.asarray(ca_a), np.asarray(ca_b))
    ca_a = np.asarray(ca_a) - ca
    ca_b = np.asarray(ca_b) - cb
    ca_rmsd = float(np.sqrt(np.mean(np.sum((ca_a @ rot - ca_b) ** 2, axis=1))))

    diffs = []
    for key_a, key_b in matched:
        for name in BACKBONE:
            if name in coords_a[key_a] and name in coords_b[key_b]:
                va = (coords_a[key_a][name] - ca) @ rot
                vb = coords_b[key_b][name] - cb
                diffs.append(np.sum((va - vb) ** 2))
    bb_rmsd = float(np.sqrt(np.mean(diffs))) if diffs else float("nan")
    return bb_rmsd, ca_rmsd, len(matched), len(diffs)


def _key(path: Path) -> str:
    stem = path.name
    for suffix in (".cif.zst", ".cif", ".mmcif.zst", ".mmcif"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    return stem.removesuffix("_generated")


def _collect(root: Path) -> dict[str, Path]:
    files = list(root.glob("**/*_generated.cif")) + list(root.glob("**/*_generated.cif.zst"))
    out = {}
    for f in sorted(files):
        k = _key(f)
        if k in out:
            raise SystemExit(f"duplicate design key {k!r}: {out[k]} and {f}")
        out[k] = f
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--a", type=Path, required=True, help="design set A (e.g. SDAA)")
    ap.add_argument("--b", type=Path, required=True, help="design set B (e.g. CUDA)")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--chain", default="coi", help="coi (default) | all | <chain_id>")
    ap.add_argument("--a-metrics", type=Path, default=None)
    ap.add_argument("--b-metrics", type=Path, default=None)
    ap.add_argument("--a-name", default="a")
    ap.add_argument("--b-name", default="b")
    args = ap.parse_args(argv)

    set_a = _collect(args.a)
    set_b = _collect(args.b)
    keys = sorted(set_a)
    missing = sorted(set(set_a) - set(set_b))
    extra = sorted(set(set_b) - set(set_a))
    if missing or extra:
        print(f"ERROR: key mismatch; missing in {args.b_name}: {missing}; extra: {extra}", file=sys.stderr)
        return 2

    args.out.mkdir(parents=True, exist_ok=True)
    rows, cache = [], {}
    for key in keys:
        aa_a, coi_a = _load(set_a[key])
        aa_b, coi_b = _load(set_b[key])
        chain = coi_a if args.chain == "coi" else args.chain
        if chain == "coi":
            chain_a, chain_b = coi_a, coi_b
        else:
            chain_a = chain_b = chain
        order_a, seq_a, coords_a = _residues(aa_a, chain_a)
        order_b, seq_b, coords_b = _residues(aa_b, chain_b)
        pairs, aln_len = _alignment_pairs(seq_a, seq_b)
        matches = sum(1 for i, j in pairs if seq_a[i] == seq_b[j])
        bb, ca, n_res, n_atoms = _rmsd(coords_a, coords_b, pairs, order_a, order_b)
        cache[key] = dict(seq_a=seq_a, seq_b=seq_b)
        rows.append({
            "key": key,
            "chain_a": str(chain_a),
            "chain_b": str(chain_b),
            "len_a": len(seq_a),
            "len_b": len(seq_b),
            "aligned_columns": aln_len,
            "matched_residues": n_res,
            "identity_aligned": matches / max(aln_len, 1),
            "identity_minlength": matches / max(min(len(seq_a), len(seq_b)), 1),
            "backbone_rmsd": bb,
            "ca_rmsd": ca,
            "matched_backbone_atoms": n_atoms,
        })

    df = pd.DataFrame(rows)
    df.to_csv(args.out / "pairs.csv", index=False)

    if args.a_metrics and args.b_metrics:
        def load_metrics(path, label):
            m = pd.read_csv(path)
            m["key"] = m["example_id"].astype(str).str.replace(r"_generated$", "", regex=True)
            m["key"] = m["key"].str.replace(r"_job\d+$", "", regex=True)
            keep = ["key"] + [
                c for c in m.columns
                if c.startswith(("sse_distribution.", "sequence_developability.",
                                 "amino_acid_composition.n_standard_residues",
                                 "design_motif_allatom_rmsd.", "interchain_interactions."))
            ]
            return m[keep].add_prefix(f"{label}__")

        met = load_metrics(args.a_metrics, args.a_name).merge(
            load_metrics(args.b_metrics, args.b_name), on="key", how="outer"
        )
        df = df.merge(met, on="key", how="left")
        delta = {}
        for col in met.columns:
            if col.startswith(f"{args.a_name}__"):
                base = col[len(args.a_name) + 2:]
                other = f"{args.b_name}__{base}"
                if other in met.columns:
                    delta[f"delta__{base}"] = df[col] - df[other]
        if delta:
            df = pd.concat([df, pd.DataFrame(delta)], axis=1)
        df.to_csv(args.out / "pairs_with_metrics.csv", index=False)

    summary = {
        "n_pairs": int(len(df)),
        "median_identity": float(df["identity_aligned"].median()),
        "min_identity": float(df["identity_aligned"].min()),
        "frac_identity_ge_0.95": float((df["identity_aligned"] >= 0.95).mean()),
        "frac_identity_ge_0.99": float((df["identity_aligned"] >= 0.99).mean()),
        "median_backbone_rmsd": float(df["backbone_rmsd"].median()),
        "max_backbone_rmsd": float(df["backbone_rmsd"].max()),
        "a": str(args.a),
        "b": str(args.b),
    }
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2))

    lines = [
        f"# Design comparison: {args.a_name} vs {args.b_name}",
        "",
        f"- A: `{args.a}`",
        f"- B: `{args.b}`",
        f"- pairs: {summary['n_pairs']}",
        f"- identity (aligned columns): median {summary['median_identity']:.4f}, "
        f"min {summary['min_identity']:.4f}, ≥0.95: {summary['frac_identity_ge_0.95']:.1%}, "
        f"≥0.99: {summary['frac_identity_ge_0.99']:.1%}",
        f"- design backbone RMSD (Å): median {summary['median_backbone_rmsd']:.3f}, "
        f"max {summary['max_backbone_rmsd']:.3f}",
        "",
        "| key | len A | len B | identity | identity/min | backbone RMSD (Å) | CA RMSD (Å) |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for _, r in df.sort_values("key").iterrows():
        lines.append(
            f"| {r['key']} | {r['len_a']} | {r['len_b']} | {r['identity_aligned']:.4f} | "
            f"{r['identity_minlength']:.4f} | {r['backbone_rmsd']:.3f} | {r['ca_rmsd']:.3f} |"
        )
    (args.out / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/summary.md, pairs.csv, summary.json")
    print(json.dumps({k: summary[k] for k in ("n_pairs", "median_identity", "median_backbone_rmsd")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))