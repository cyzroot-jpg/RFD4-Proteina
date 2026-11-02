#!/usr/bin/env python3
"""Dump the first trunk call(s) (inputs + outputs as flat tensors) for fidelity comparison.

Run the SAME command on SDAA and CUDA, then diff the dumps with compare_fidelity.py.
This is the per-op check: identical weights/inputs/noise should give identical trunk
outputs up to floating-point implementation differences.

usage:
  FIDELITY_OUT=<dir> python run_sdaa/experiments/fidelity_probe.py <normal generate overrides...>
env:
  FIDELITY_OUT   output directory (required)
  FIDELITY_CALLS number of trunk calls to dump (default 1)

Note: use a short run to keep this cheap, e.g.
  generation.n_recycle_schedule='[[20,2]]' generation.args.nsteps=20 num_replicates=1
"""

from __future__ import annotations

import os
import sys

import torch


def _flatten(obj, prefix: str = "", out: dict | None = None) -> dict:
    if out is None:
        out = {}
    if torch.is_tensor(obj):
        out[prefix] = obj.detach().cpu()
    elif isinstance(obj, dict):
        for key in sorted(obj, key=str):
            _flatten(obj[key], f"{prefix}.{key}" if prefix else str(key), out)
    elif isinstance(obj, (list, tuple)):
        for i, value in enumerate(obj):
            _flatten(value, f"{prefix}[{i}]", out)
    return out


def main(argv: list[str]) -> int:
    out_dir = os.environ.get("FIDELITY_OUT")
    if not out_dir:
        print("FIDELITY_OUT must be set", file=sys.stderr)
        return 2
    os.makedirs(out_dir, exist_ok=True)
    max_calls = int(os.environ.get("FIDELITY_CALLS", "1"))

    import rfproteina  # noqa: F401  (activates the SDAA compat shim when needed)

    import json
    probe_env = {
        "align_env": os.environ.get("TORCH_SDAA_ALIGN_NV_DEVICE"),
        "torch": torch.__version__,
    }
    try:
        import torch_sdaa
        probe_env["torch_sdaa"] = torch_sdaa.__version__
        probe_env["aligned"] = bool(torch.sdaa.random_align_nv_device())
    except Exception:
        probe_env["torch_sdaa"] = None
        probe_env["aligned"] = None
    if probe_env["torch_sdaa"] and not probe_env["aligned"]:
        print("WARNING: SDAA RNG is NOT aligned to CUDA; set TORCH_SDAA_ALIGN_NV_DEVICE=a100",
              file=sys.stderr)
    with open(os.path.join(out_dir, "probe_env.json"), "w") as fh:
        json.dump(probe_env, fh, indent=2)
    from rfproteina.proteina import Proteina

    state = {"n": 0}
    original = Proteina.call_nn

    def patched(self, batch, n_recycle):
        result = original(self, batch, n_recycle)
        if state["n"] < max_calls:
            payload = {
                "call_index": state["n"],
                "n_recycle": int(n_recycle),
                "batch": _flatten(batch),
                "out": _flatten(result),
            }
            torch.save(payload, os.path.join(out_dir, f"call{state['n']}.pt"))
        state["n"] += 1
        return result

    Proteina.call_nn = patched
    from rfproteina.generate import main_hydra

    sys.argv[0] = "rfproteina.generate"
    main_hydra()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))