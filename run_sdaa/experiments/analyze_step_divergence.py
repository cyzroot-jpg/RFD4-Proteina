#!/usr/bin/env python3
"""Step-wise divergence: compare the two fidelity dumps call by call.

For every trunk call it reports:
  - sequence argmax agreement (if `sequence.logits` is present)
  - relative / cosine difference of the velocity tensors (bb_ca.v, local_latents.v)

usage:
  python run_sdaa/experiments/analyze_step_divergence.py <dir_a> <dir_b> [--out csv]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch


def _idx(path: Path) -> int:
    m = re.search(r"call(\d+)\.pt", path.name)
    return int(m.group(1)) if m else -1


def _cos(a: torch.Tensor, b: torch.Tensor) -> float:
    a = a.float().flatten()
    b = b.float().flatten()
    if a.numel() != b.numel() or a.numel() == 0:
        return float("nan")
    denom = a.norm() * b.norm()
    return float((a @ b) / denom) if denom > 0 else float("nan")


def _rel(a: torch.Tensor, b: torch.Tensor) -> float:
    a = a.float()
    b = b.float()
    if a.shape != b.shape:
        return float("nan")
    denom = b.norm()
    return float((a - b).norm() / denom) if denom > 0 else float("nan")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("a", type=Path)
    ap.add_argument("b", type=Path)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args(argv)

    files_a = {_idx(p): p for p in args.a.glob("call*.pt")}
    files_b = {_idx(p): p for p in args.b.glob("call*.pt")}
    steps = sorted(set(files_a) & set(files_b))
    if not steps:
        print("no matching call*.pt", file=__import__("sys").stderr)
        return 1

    rows = []
    for step in steps:
        da = torch.load(files_a[step], map_location="cpu")["out"]
        db = torch.load(files_b[step], map_location="cpu")["out"]
        row = {"step": step}
        key_a = next((k for k in da if k.endswith("sequence.logits")), None)
        key_b = next((k for k in db if k.endswith("sequence.logits")), None)
        if key_a and key_b:
            sa = da[key_a].argmax(dim=-1).float()
            sb = db[key_b].argmax(dim=-1).float()
            if sa.shape == sb.shape:
                row["seq_agreement"] = float((sa == sb).float().mean())
        for suffix in ("bb_ca.v", "local_latents.v"):
            ka = next((k for k in da if k == suffix or k.endswith("." + suffix)), None)
            kb = next((k for k in db if k == suffix or k.endswith("." + suffix)), None)
            if ka and kb:
                tag = suffix.replace(".", "_")
                row[f"{tag}_rel"] = _rel(da[ka], db[kb])
                row[f"{tag}_cos"] = _cos(da[ka], db[kb])
        rows.append(row)

    df = pd.DataFrame(rows)
    if args.out:
        df.to_csv(args.out, index=False)
    cols = [c for c in ["step", "seq_agreement", "bb_ca_v_rel", "bb_ca_v_cos",
                        "local_latents_v_rel", "local_latents_v_cos"] if c in df]
    print(df[cols].to_string(index=False, float_format=lambda x: f"{x:.4f}"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))