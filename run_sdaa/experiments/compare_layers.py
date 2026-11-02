#!/usr/bin/env python3
"""Compare two layer_probe.py dumps and find the first module that diverges.

usage:
  python run_sdaa/experiments/compare_layers.py <dir_a> <dir_b> \
      [--threshold 1e-3] [--out <csv>]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd


def _align(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["occ"] = df.groupby(["name", "key"]).cumcount()
    return df


def _rel(a, b, floor=1e-12):
    return float(abs(a - b) / max(abs(b), floor))


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("a", type=Path)
    ap.add_argument("b", type=Path)
    ap.add_argument("--threshold", type=float, default=1e-3)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args(argv)

    da = _align(pd.read_csv(args.a / "layers.csv"))
    db = _align(pd.read_csv(args.b / "layers.csv"))
    cols = ["name", "key", "occ", "order", "l2", "abs_mean", "std", "mean", "nonfinite"]
    da = da[cols].add_suffix("_a")
    db = db[cols].add_suffix("_b")
    merged = da.merge(db, left_on=["name_a", "key_a", "occ_a"],
                      right_on=["name_b", "key_b", "occ_b"], how="inner")
    merged["rel_l2"] = [_rel(a, b) for a, b in zip(merged["l2_a"], merged["l2_b"])]
    merged["rel_abs_mean"] = [_rel(a, b) for a, b in zip(merged["abs_mean_a"], merged["abs_mean_b"])]
    merged["rel_std"] = [_rel(a, b) for a, b in zip(merged["std_a"], merged["std_b"])]
    merged["rel_mean"] = [_rel(a, b) for a, b in zip(merged["mean_a"], merged["mean_b"])]
    merged["rel"] = merged[["rel_l2", "rel_abs_mean", "rel_std"]].max(axis=1)
    merged = merged.sort_values("order_a")

    if args.out:
        merged.to_csv(args.out, index=False)

    over = merged[merged["rel"] > args.threshold]
    print(f"modules compared: {len(merged)}")
    print(f"first {min(15, len(over))} with rel > {args.threshold:g}:")
    cols_show = ["order_a", "name_a", "key_a", "rel_l2", "rel_abs_mean", "rel_std"]
    if not over.empty:
        print(over[cols_show].head(15).to_string(index=False, float_format=lambda x: f"{x:.3e}"))
        first = over.iloc[0]
        print(f"\nFIRST DIVERGENT: order={int(first['order_a'])} name={first['name_a']} "
              f"key={first['key_a']} rel={first['rel']:.3e}")
    else:
        print("  none")

    print("\ntop 10 by relative error:")
    print(merged.sort_values("rel", ascending=False)[cols_show]
          .head(10).to_string(index=False, float_format=lambda x: f"{x:.3e}"))

    # inputs, if present
    ia, ib = args.a / "first_call_input.npz", args.b / "first_call_input.npz"
    if ia.exists() and ib.exists():
        za, zb = np.load(ia), np.load(ib)
        worst = []
        for k in sorted(set(za.files) & set(zb.files)):
            a, b = za[k].astype(np.float64), zb[k].astype(np.float64)
            if a.shape != b.shape:
                worst.append((k, float("inf")))
                continue
            denom = np.abs(b).mean() if b.size else 0.0
            worst.append((k, float(np.abs(a - b).mean() / denom) if denom > 0 else 0.0))
        worst.sort(key=lambda x: x[1], reverse=True)
        print("\ninput tensors (relative mean abs diff):")
        for k, v in worst[:10]:
            print(f"  {k}: {v:.3e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))