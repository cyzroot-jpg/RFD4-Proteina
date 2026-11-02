#!/usr/bin/env python3
"""Compare two fidelity dumps produced by fidelity_probe.py.

usage:
  python run_sdaa/experiments/compare_fidelity.py <dump_a_dir> <dump_b_dir> [--out csv]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch


def _rel(a: torch.Tensor, b: torch.Tensor) -> tuple[float, float, float, float]:
    a = a.float().numpy()
    b = b.float().numpy()
    if a.shape != b.shape:
        return float("nan"), float("nan"), float("nan"), 0.0
    finite = np.isfinite(a) & np.isfinite(b)
    if not finite.any():
        return 0.0, 0.0, 0.0, 1.0
    diff = np.abs(a[finite] - b[finite])
    denom = np.abs(b[finite]).mean()
    max_abs = float(diff.max())
    mean_abs = float(diff.mean())
    rel = float(mean_abs / denom) if denom > 0 else float("inf")
    return max_abs, mean_abs, rel, float(1 - finite.mean())


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("a", type=Path)
    ap.add_argument("b", type=Path)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args(argv)

    files = sorted({p.name for p in args.a.glob("call*.pt")} & {p.name for p in args.b.glob("call*.pt")})
    if not files:
        print("no matching call*.pt files", file=sys.stderr)
        return 1

    rows = []
    for name in files:
        da = torch.load(args.a / name, map_location="cpu")
        db = torch.load(args.b / name, map_location="cpu")
        keys = sorted(set(da["out"]) & set(db["out"]))
        for key in keys:
            max_abs, mean_abs, rel, nonfinite = _rel(da["out"][key], db["out"][key])
            rows.append({"call": name, "key": key, "group": "out",
                         "max_abs": max_abs, "mean_abs": mean_abs, "rel": rel, "nonfinite": nonfinite,
                         "shape_a": tuple(da["out"][key].shape), "shape_b": tuple(db["out"][key].shape)})
        bkeys = sorted(set(da["batch"]) & set(db["batch"]))
        for key in bkeys:
            max_abs, mean_abs, rel, nonfinite = _rel(da["batch"][key], db["batch"][key])
            rows.append({"call": name, "key": key, "group": "batch",
                         "max_abs": max_abs, "mean_abs": mean_abs, "rel": rel, "nonfinite": nonfinite,
                         "shape_a": tuple(da["batch"][key].shape), "shape_b": tuple(db["batch"][key].shape)})

    df = pd.DataFrame(rows)
    if args.out:
        df.to_csv(args.out, index=False)
    print(f"{len(df)} tensors compared from {len(files)} call file(s)")
    cols = ["call", "group", "key", "rel", "max_abs", "mean_abs", "nonfinite"]
    out = df[df["group"] == "out"].sort_values("rel", ascending=False)
    print("\n== trunk outputs (top 15 by relative error) ==")
    print(out[cols].head(15).to_string(index=False, float_format=lambda x: f"{x:.3e}"))
    print("\n== summary ==")
    print(out.groupby("call")["rel"].agg(["median", "max"]).to_string())
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))