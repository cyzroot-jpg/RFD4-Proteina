#!/usr/bin/env python3
"""Depth probe: record per-module output statistics for the first trunk call.

Run on SDAA and CUDA with identical commands, then diff with compare_layers.py.
This localizes the first module (in execution order) whose output already differs,
i.e. where the cross-backend numerical divergence starts.

usage:
  LAYER_PROBE_OUT=<dir> python run_sdaa/experiments/layer_probe.py <generate overrides...>

env:
  LAYER_PROBE_OUT       output dir (required)
  LAYER_PROBE_CALLS     number of trunk calls to record (default 1)
  LAYER_PROBE_FULL      regex of module names whose full tensors are saved (optional;
                        default: none, only statistics are stored)
"""

from __future__ import annotations

import os
import re
import sys
from typing import Any

import numpy as np
import torch


def _flatten(obj: Any, prefix: str = "", out: dict | None = None) -> dict:
    if out is None:
        out = {}
    if torch.is_tensor(obj):
        out[prefix or "tensor"] = obj
    elif isinstance(obj, dict):
        for key in sorted(obj, key=str):
            _flatten(obj[key], f"{prefix}.{key}" if prefix else str(key), out)
    elif isinstance(obj, (list, tuple)):
        for i, value in enumerate(obj):
            _flatten(value, f"{prefix}[{i}]", out)
    return out


def _stats(t: torch.Tensor) -> dict:
    x = t.detach().float()
    finite = torch.isfinite(x)
    if not finite.any():
        return {"numel": int(x.numel()), "nonfinite": 1.0}
    y = x[finite]
    return {
        "numel": int(x.numel()),
        "nonfinite": float(1 - finite.float().mean()),
        "mean": float(y.mean()),
        "std": float(y.std(unbiased=False)) if y.numel() > 1 else 0.0,
        "min": float(y.min()),
        "max": float(y.max()),
        "abs_mean": float(y.abs().mean()),
        "l2": float(torch.linalg.vector_norm(y)),
    }


def main(argv: list[str]) -> int:
    out_dir = os.environ.get("LAYER_PROBE_OUT")
    if not out_dir:
        print("LAYER_PROBE_OUT must be set", file=sys.stderr)
        return 2
    os.makedirs(out_dir, exist_ok=True)
    max_calls = int(os.environ.get("LAYER_PROBE_CALLS", "1"))
    at_call = int(os.environ.get("LAYER_PROBE_AT_CALL", "0"))
    full_pattern = os.environ.get("LAYER_PROBE_FULL")
    full_re = re.compile(full_pattern) if full_pattern else None

    import rfproteina  # noqa: F401
    from rfproteina.proteina import Proteina

    state = {"call": 0, "hooks": None}

    def install(model):
        records: list[dict] = []
        full_index: list[dict] = []
        handles = []

        def make_hook(name):
            def hook(module, inputs, output):
                for key, t in _flatten(output).items():
                    rec = {"name": name, "key": key, "order": len(records)}
                    rec.update(_stats(t))
                    records.append(rec)
                    if full_re is not None and full_re.search(name):
                        fname = f"t{len(records):05d}.npy"
                        np.save(os.path.join(out_dir, fname), t.detach().float().cpu().numpy())
                        full_index.append({"order": rec["order"], "name": name,
                                           "key": key, "file": fname})
            return hook

        for name, module in model.named_modules():
            handles.append(module.register_forward_hook(make_hook(name)))

        def save_and_remove():
            import csv
            with open(os.path.join(out_dir, "layers.csv"), "w", newline="") as fh:
                writer = csv.DictWriter(fh, fieldnames=list(records[0]) if records else ["name"])
                if records:
                    writer.writeheader()
                    writer.writerows(records)
            if full_index:
                import csv as _csv
                with open(os.path.join(out_dir, "full_index.csv"), "w", newline="") as fh:
                    writer = _csv.DictWriter(fh, fieldnames=["order", "name", "key", "file"])
                    writer.writeheader()
                    writer.writerows(full_index)
            for h in handles:
                h.remove()

        return records, save_and_remove

    original = Proteina.call_nn

    def patched(self, batch, n_recycle):
        if state["call"] == at_call and state["hooks"] is None:
            state["hooks"] = install(self.nn)
        result = original(self, batch, n_recycle)
        if state["call"] == at_call:
            records, finish = state["hooks"]
            finish()
            flat = _flatten(batch)
            np.savez(os.path.join(out_dir, "first_call_input.npz"),
                     **{k: v.detach().float().cpu().numpy() for k, v in flat.items()})
            state["hooks"] = ([], lambda: None)  # stop recording further calls
        state["call"] += 1
        return result

    Proteina.call_nn = patched
    from rfproteina.generate import main_hydra

    sys.argv[0] = "rfproteina.generate"
    main_hydra()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))