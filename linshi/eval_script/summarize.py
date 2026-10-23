#!/usr/bin/env python3
"""Aggregate RFD4-Proteina per-example metric CSVs into a markdown table.

This reports values produced by the official metric implementation; it does not
define or recompute any metric. Usage:

    python summarize.py <csv> [<csv> ...]
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

# Columns shown when present. Aggregation is mean over designs; for fractions
# (clash/bond) the mean is the natural summary, and for counts we also show n.
COLUMNS = [
    "amino_acid_composition.n_standard_residues",
    "bond_length_metrics.bond_length.frac_unreasonable",
    "clash_metrics.frac_atoms_clashing_1p5A",
    "sse_distribution.helix_fraction",
    "sse_distribution.sheet_fraction",
    "sse_distribution.loop_fraction",
    "sse_distribution.num_ss_elements",
    "sequence_developability.gravy",
    "sequence_developability.instability_index",
    "hotspot_obedience.hotspot_obedience",
    "design_motif_allatom_rmsd.rmsd",
    "refolded_backbone_rmsd.rmsd",
]

SHORT = {
    "amino_acid_composition.n_standard_residues": "n_res",
    "bond_length_metrics.bond_length.frac_unreasonable": "bad_bond_frac",
    "clash_metrics.frac_atoms_clashing_1p5A": "clash_frac",
    "sse_distribution.helix_fraction": "helix",
    "sse_distribution.sheet_fraction": "sheet",
    "sse_distribution.loop_fraction": "loop",
    "sse_distribution.num_ss_elements": "n_sse",
    "sequence_developability.gravy": "gravy",
    "sequence_developability.instability_index": "instability",
    "hotspot_obedience.hotspot_obedience": "hotspot_obed",
    "design_motif_allatom_rmsd.rmsd": "motif_rmsd",
    "refolded_backbone_rmsd.rmsd": "scRMSD",
}


def main(paths: list[str]) -> int:
    frames = []
    for path in paths:
        p = Path(path)
        if not p.exists():
            print(f"missing: {p}", file=sys.stderr)
            continue
        df = pd.read_csv(p)
        df["_source"] = str(p)
        frames.append(df)
    if not frames:
        print("no CSV files found", file=sys.stderr)
        return 1
    df = pd.concat(frames, ignore_index=True, sort=False)
    present = [c for c in COLUMNS if c in df.columns]
    rows = []
    for source, group in df.groupby("_source", sort=True):
        row = {"source": source, "n": len(group)}
        for col in present:
            row[SHORT.get(col, col)] = group[col].mean()
        rows.append(row)
    out = pd.DataFrame(rows)
    print(out.to_markdown(index=False, floatfmt=".4f"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))