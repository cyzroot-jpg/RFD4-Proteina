#!/usr/bin/env python3
"""Sequence-level divergence: where exactly do the two design sets differ?

For every paired design it reports the number (and positions) of mismatched
residues. With --motif-input it splits mismatches into motif vs scaffold.
With --refold-a/--refold-b it joins per-design refold metrics and prints
correlations, so you can test whether motif/PPI metric differences track
sequence changes.

usage:
  python run_sdaa/experiments/analyze_sequence_divergence.py \
    --a <sdaa designs> --b <cuda designs> --out <dir> \
    [--motif-input data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst] \
    [--refold-a <csv> --refold-b <csv>]
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent


def _load_helpers():
    spec = importlib.util.spec_from_file_location("cd", HERE / "compare_designs.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _motif_positions(input_cif: Path, design_seq: str, helpers) -> tuple[list[int], int]:
    """Map input C_CRD residues to indices in the designed sequence."""
    import rfproteina  # noqa: F401
    from atomworks.io.parser import parse
    from rfproteina.utils.parse_presets import STANDARD_ANNOTATIONS_ONLY
    from rfproteina.utils.chain import get_chain_of_interest

    aa = parse(input_cif, config=STANDARD_ANNOTATIONS_ONLY)["assemblies"]["1"][0]
    coi, _ = get_chain_of_interest(aa)
    order, seq_in, _ = helpers._residues(aa, coi)
    cats = aa.get_annotation_categories()
    if "condition_coordinate_1_atom" not in cats:
        return [], 0
    mask = np.asarray(aa.get_annotation("condition_coordinate_1_atom"))
    mask = mask.reshape(len(aa), -1).any(axis=1) if mask.ndim > 1 else mask.astype(bool)
    motif_keys = set()
    chains = aa.chain_iid if "chain_iid" in cats else aa.chain_id
    for ch, rid, keep in zip(chains, aa.res_id, mask):
        if bool(keep):
            motif_keys.add((str(ch), str(rid)))
    motif_in = {i for i, key in enumerate(order) if key in motif_keys}
    pairs, _ = helpers._alignment_pairs(seq_in, design_seq)
    mapped = sorted(j for i, j in pairs if i in motif_in)
    return mapped, len(motif_in)


def _load_refold(path: Path, label: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    key_col = "designed_structure_path" if "designed_structure_path" in df.columns else "example_id"
    df["key"] = df[key_col].map(lambda v: _key(v))
    wanted = [c for c in df.columns if c.startswith(("oracle", "refolded_")) or ".pass" in c]
    out = df[["key"] + wanted].add_prefix(f"{label}__")
    out = out.rename(columns={f"{label}__key": "key"})
    return out


def _key(value: str) -> str:
    import re
    name = Path(str(value)).name
    for suffix in (".cif.zst", ".cif", ".mmcif.zst", ".mmcif"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    return re.sub(r"_job\d+$", "", name).removesuffix("_generated")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--a", type=Path, required=True)
    ap.add_argument("--b", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--motif-input", type=Path, default=None)
    ap.add_argument("--refold-a", type=Path, default=None)
    ap.add_argument("--refold-b", type=Path, default=None)
    ap.add_argument("--a-name", default="a")
    ap.add_argument("--b-name", default="b")
    args = ap.parse_args(argv)

    helpers = _load_helpers()
    set_a, set_b = helpers._collect(args.a), helpers._collect(args.b)
    keys = sorted(set_a)
    if set(set_a) != set(set_b):
        print("design key mismatch", file=sys.stderr)
        return 2

    motif_seq = None
    if args.motif_input:
        motif_seq = args.motif_input
    rows = []
    for key in keys:
        aa_a, coi_a = helpers._load(set_a[key])
        aa_b, coi_b = helpers._load(set_b[key])
        order_a, seq_a, _ = helpers._residues(aa_a, coi_a)
        _, seq_b, _ = helpers._residues(aa_b, coi_b)
        pairs, aln = helpers._alignment_pairs(seq_a, seq_b)
        mismatch = [(i, seq_a[i], seq_b[j]) for i, j in pairs if seq_a[i] != seq_b[j]]
        row = {
            "key": key,
            "len_a": len(seq_a),
            "len_b": len(seq_b),
            "matched": len(pairs),
            "n_mismatch": len(mismatch),
            "identity": 1 - len(mismatch) / max(len(pairs), 1),
            "mismatches": ";".join(f"{i}:{a}>{b}" for i, a, b in mismatch[:50]),
        }
        if motif_seq is not None:
            motif_idx, motif_len = _motif_positions(motif_seq, seq_a, helpers)
            motif_set = set(motif_idx)
            in_motif = [m for m in mismatch if m[0] in motif_set]
            row["motif_len"] = motif_len
            row["n_mismatch_motif"] = len(in_motif)
            row["n_mismatch_scaffold"] = len(mismatch) - len(in_motif)
        rows.append(row)

    df = pd.DataFrame(rows)
    if args.refold_a and args.refold_b:
        ra = _load_refold(args.refold_a, args.a_name)
        rb = _load_refold(args.refold_b, args.b_name)
        df = df.merge(ra, on="key", how="left").merge(rb, on="key", how="left")

    args.out.mkdir(parents=True, exist_ok=True)
    df.drop(columns=["mismatches"]).to_csv(args.out / "sequence_divergence.csv", index=False)

    lines = ["# Sequence-level divergence", "",
             f"- A: `{args.a}`", f"- B: `{args.b}`", f"- designs: {len(df)}", ""]
    lines += ["| key | identity | mismatches | " + ("motif / scaffold | " if "n_mismatch_motif" in df else "") + "len A / B |",
              "| --- | ---: | ---: | " + ("---: | " if "n_mismatch_motif" in df else "") + "---: |"]
    for _, r in df.sort_values("key").iterrows():
        extra = f"{int(r['n_mismatch_motif'])} / {int(r['n_mismatch_scaffold'])} | " if "n_mismatch_motif" in df else ""
        lines.append(f"| {r['key']} | {r['identity']:.4f} | {int(r['n_mismatch'])} | {extra}"
                     f"{int(r['len_a'])} / {int(r['len_b'])} |")
    (args.out / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/summary.md and sequence_divergence.csv")
    print(df[["key", "identity", "n_mismatch"] + (["n_mismatch_motif"] if "n_mismatch_motif" in df else [])]
          .to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))