#!/usr/bin/env python3
"""Micro-benchmark per-operator numerical differences between backends.

Each op runs on the current device (SDAA or CUDA) with identical inputs generated
from a fixed NumPy seed, plus a float64 CPU reference. Run on both hosts and diff
the JSON files to get a per-op error budget.

usage:
  python run_sdaa/experiments/op_bench.py --out ops_sdaa.json
  python run_sdaa/experiments/op_bench.py --compare ops_sdaa.json ops_cuda.json
"""

from __future__ import annotations

import argparse
import json
import sys

import numpy as np
import torch
import torch.nn.functional as F


def _t(shape, seed, dtype, device="cpu"):
    arr = np.random.default_rng(seed).standard_normal(shape).astype(np.float32)
    return torch.from_numpy(arr).to(device=device, dtype=dtype)


def _err(out: torch.Tensor, ref: torch.Tensor) -> dict:
    a = out.detach().float().cpu().double()
    b = ref.detach().double().cpu()
    if a.shape != b.shape:
        return {"err_shape_mismatch": 1.0}
    finite = torch.isfinite(a) & torch.isfinite(b)
    if not finite.any():
        return {"err_abs_mean": 0.0, "err_abs_max": 0.0, "err_rel_l2": 0.0}
    d = (a[finite] - b[finite]).abs()
    denom = torch.linalg.vector_norm(b[finite])
    rel = torch.linalg.vector_norm(a[finite] - b[finite]) / denom if denom > 0 else torch.tensor(0.0)
    return {"err_abs_mean": float(d.mean()), "err_abs_max": float(d.max()),
            "err_rel_l2": float(rel)}


def _stats(t: torch.Tensor) -> dict:
    x = t.detach().float().cpu()
    finite = torch.isfinite(x)
    y = x[finite]
    return {
        "l2": float(torch.linalg.vector_norm(y)),
        "abs_mean": float(y.abs().mean()),
        "mean": float(y.mean()),
        "std": float(y.std(unbiased=False)),
        "numel": int(x.numel()),
    }


def _ops(device, dtype):
    q = _t((2, 8, 128, 32), 11, dtype, device)
    k = _t((2, 8, 128, 32), 12, dtype, device)
    v = _t((2, 8, 128, 32), 13, dtype, device)
    bias = _t((2, 8, 128, 128), 14, torch.float32, device)
    a = _t((64, 384), 21, dtype, device)
    b = _t((384, 384), 22, dtype, device)
    x = _t((2, 128, 384), 31, dtype, device)
    w = _t((384,), 32, dtype, device)
    bb = _t((384,), 33, dtype, device)
    sm = _t((2, 8, 128, 128), 41, dtype, device)

    bias_t = bias.to(dtype)

    def attention_einsum():
        scale = q.shape[-1] ** -0.5
        sim = torch.einsum("bhid,bhjd->bhij", q, k) * scale + bias_t
        p = torch.softmax(sim, dim=-1)
        return torch.einsum("bhij,bhjd->bhid", p, v)

    def attention_sdpa():
        return F.scaled_dot_product_attention(q, k, v, attn_mask=bias_t)

    return {
        "matmul": lambda: a @ b,
        "softmax": lambda: torch.softmax(sm.float(), dim=-1),
        "rmsnorm": lambda: F.rms_norm(x.float(), (384,), w.float(), 1e-6),
        "layernorm": lambda: F.layer_norm(x.float(), (384,), w.float(), bb.float(), 1e-5),
        "sigmoid": lambda: torch.sigmoid(x),
        "gelu": lambda: F.gelu(x),
        "attention_einsum": attention_einsum,
        "attention_sdpa": attention_sdpa,
    }


def run(device: str) -> dict:
    results = {}
    for dtype in (torch.bfloat16, torch.float32):
        tag = str(dtype).replace("torch.", "")
        for name, fn in _ops(device, dtype).items():
            key = f"{name}.{tag}"
            try:
                out = fn()
                st = _stats(out)
                # float64 CPU reference from the same seeds
                cpu_fn = _ops("cpu", torch.float64)[name]
                ref = cpu_fn()
                st.update(_err(out, ref))
                st["cpu64_l2"] = float(torch.linalg.vector_norm(ref.float()))
                st["rel_to_cpu64"] = abs(st["l2"] - ref.float().norm().item()) / max(ref.float().norm().item(), 1e-12)
                results[key] = st
            except Exception as exc:  # noqa: BLE001
                results[key] = {"error": f"{type(exc).__name__}: {exc}"}
    return results


def compare(path_a, path_b) -> int:
    a = json.loads(__import__("pathlib").Path(path_a).read_text())
    b = json.loads(__import__("pathlib").Path(path_b).read_text())
    a = a.get("ops", a)
    b = b.get("ops", b)
    rows = []
    for key in sorted(set(a) & set(b)):
        if "error" in a[key] or "error" in b[key]:
            rows.append((key, float("nan"), a[key].get("error", ""), b[key].get("error", "")))
            continue
        rel = abs(a[key]["l2"] - b[key]["l2"]) / max(abs(b[key]["l2"]), 1e-12)
        rows.append((key, rel, a[key]["rel_to_cpu64"], b[key]["rel_to_cpu64"]))
    rows.sort(key=lambda r: (r[1] != r[1], -(r[1] if r[1] == r[1] else 0)))
    print(f"{'op':28s} {'rel_l2(a,b)':>12s} {'a abs_mean / max':>26s} {'b abs_mean / max':>26s}")
    for key, rel, ra, rb in rows:
        ea = a[key].get("err_abs_mean", float("nan"))
        xa = a[key].get("err_abs_max", float("nan"))
        eb = b[key].get("err_abs_mean", float("nan"))
        xb = b[key].get("err_abs_max", float("nan"))
        print(f"{key:28s} {rel:12.3e} {ea:12.3e}/{xa:12.3e} {eb:12.3e}/{xb:12.3e}")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out")
    ap.add_argument("--compare", nargs=2)
    args = ap.parse_args(argv)
    if args.compare:
        return compare(*args.compare)

    import rfproteina  # noqa: F401  (activates the SDAA compat shim when needed)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    results = run(device)
    text = json.dumps({"device": device, "ops": results}, indent=2)
    if args.out:
        __import__("pathlib").Path(args.out).write_text(text)
        print(f"wrote {args.out} ({device}, {len(results)} ops)")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))