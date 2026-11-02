#!/usr/bin/env python3
"""PPI conditioning check: is the fixed target chain identical on both platforms?

If the target (non-COI) backbone coordinates and conditioning annotations match
exactly, then the PPI A-class differences must come from the generated binder
(sequence/trajectory), not from a different target representation.

usage:
  python run_sdaa/experiments/analyze_ppi_conditioning.py \
    --a <sdaa ppi inference_samples> --b <cuda ppi inference_samples> --out <dir>
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import sys
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
BACKBONE = {"N", "CA", "C", "O"}


def _helpers():
    spec = importlib.util.spec_from_file_location("cd", HERE / "compare_designs.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _chains(aa):
    cats = aa.get_annotation_categories()
    if "chain_iid" in cats:
        return [str(x) for x in aa.chain_iid.tolist()]
    return [str(x) for x in aa.chain_id.tolist()]


def _residue_atoms(aa, chain_id, atoms=None):
    cats = aa.get_annotation_categories()
    ids = [str(x) for x in (aa.chain_iid if "chain_iid" in cats else aa.chain_id).tolist()]
    sel = np.array(ids) == chain_id
    out = {}
    for rid, name, xyz in zip(aa.res_id[sel], aa.atom_name[sel], aa.coord[sel]):
        if atoms is not None and str(name) not in atoms:
            continue
        out.setdefault((str(rid), str(name)), np.asarray(xyz, dtype=np.float64))
    return out


def _residue_seq(aa, chain_id):
    cats = aa.get_annotation_categories()
    ids = [str(x) for x in (aa.chain_iid if "chain_iid" in cats else aa.chain_id).tolist()]
    sel = np.array(ids) == chain_id
    from Bio.Data.PDBData import protein_letters_3to1_extended as m
    seq = []
    seen = set()
    for rid, rn in zip(aa.res_id[sel], aa.res_name[sel]):
        key = str(rid)
        if key not in seen:
            seen.add(key)
            seq.append(m.get(str(rn), "X"))
    return "".join(seq)


def _identity(a: str, b: str, helpers) -> float:
    pairs, _ = helpers._alignment_pairs(a, b)
    if not pairs:
        return float("nan")
    return sum(1 for i, j in pairs if a[i] == b[j]) / len(pairs)


def _rmsd_direct(ra, rb):
    common = sorted(set(ra) & set(rb))
    if not common:
        return float("nan"), 0
    d = np.array([ra[k] - rb[k] for k in common])
    return float(np.sqrt((d ** 2).sum(axis=1).mean())), len(common)


def _conditions(aa, chain_id):
    cats = aa.get_annotation_categories()
    ids = [str(x) for x in (aa.chain_iid if "chain_iid" in cats else aa.chain_id).tolist()]
    chain_mask = np.array(ids) == chain_id
    out = {}
    for c in cats:
        if not c.startswith("condition_"):
            continue
        try:
            v = aa.get_annotation(c)
        except Exception:
            continue
        arr = np.asarray(v)
        arr = arr[chain_mask]
        flat = arr.reshape(max(len(arr), 1), -1)
        if flat.dtype.kind in "biufc":
            out[c] = round(float(np.nansum(flat)), 6)
        elif flat.dtype == object:
            out[c] = hashlib.sha1(str(flat).encode()).hexdigest()[:12]
        else:
            out[c] = hashlib.sha1(np.ascontiguousarray(flat).tobytes()).hexdigest()[:12]
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--a", type=Path, required=True)
    ap.add_argument("--b", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--a-name", default="a")
    ap.add_argument("--b-name", default="b")
    args = ap.parse_args(argv)

    helpers = _helpers()
    set_a, set_b = helpers._collect(args.a), helpers._collect(args.b)
    if set(set_a) != set(set_b):
        print("design key mismatch", file=sys.stderr)
        return 2

    rows = []
    for key in sorted(set_a):
        aa_a, coi_a = helpers._load(set_a[key])
        aa_b, coi_b = helpers._load(set_b[key])
        chains_a = sorted(set(_chains(aa_a)))
        targets_a = [c for c in chains_a if c != coi_a]
        targets_b = [c for c in sorted(set(_chains(aa_b))) if c != coi_b]
        target = targets_a[0] if targets_a else None
        row = {"key": key, "coi_a": coi_a, "coi_b": coi_b,
               "targets_a": ",".join(targets_a), "targets_b": ",".join(targets_b)}
        if target and target in targets_b:
            ra = _residue_atoms(aa_a, target, atoms=BACKBONE)
            rb = _residue_atoms(aa_b, target, atoms=BACKBONE)
            rmsd, n_atoms = _rmsd_direct(ra, rb)
            row.update({"target_atoms": n_atoms, "target_backbone_rmsd": rmsd,
                        "target_identity": _identity(_residue_seq(aa_a, target),
                                                     _residue_seq(aa_b, target), helpers)})
            ca_a, ca_b = _residue_seq(aa_a, target), _residue_seq(aa_b, target)
            row["target_len_a"], row["target_len_b"] = len(ca_a), len(ca_b)
        cond_a = _conditions(aa_a, target) if target else {}
        cond_b = _conditions(aa_b, target) if target else {}
        keys_c = sorted(set(cond_a) | set(cond_b))
        diffs = [k for k in keys_c if cond_a.get(k) != cond_b.get(k)]
        row["condition_mask_diffs"] = ";".join(f"{k}:{cond_a.get(k)}!={cond_b.get(k)}" for k in diffs)
        rows.append(row)

    df = pd.DataFrame(rows)
    args.out.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.out / "ppi_conditioning.csv", index=False)

    lines = ["# PPI conditioning check", "",
             f"- A: `{args.a}`", f"- B: `{args.b}`", "",
             "| key | target | atoms | target bb RMSD (Å) | target identity | condition diffs |",
             "| --- | --- | ---: | ---: | ---: | --- |"]
    for _, r in df.sort_values("key").iterrows():
        lines.append(f"| {r['key']} | {r.get('targets_a', '?')} | {r.get('target_atoms', '')} | "
                     f"{r.get('target_backbone_rmsd', float('nan')):.3e} | "
                     f"{r.get('target_identity', float('nan')):.4f} | "
                     f"{r.get('condition_mask_diffs', '')} |")
    (args.out / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out}/summary.md")
    cols = [c for c in ["key", "target_backbone_rmsd", "target_identity",
                        "target_atoms", "condition_mask_diffs"] if c in df]
    print(df[cols].to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))