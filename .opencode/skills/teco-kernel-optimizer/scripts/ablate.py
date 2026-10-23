#!/usr/bin/env python3
"""Single-method ablation for attribution.

For each method applied in the champion kernel, this script expects Claude
to have generated an ablated kernel (champion minus that one method) under
  iterv{i}/ablations/{method_id}/kernel.scpp
Optional sibling *.hpp files alongside each ablated kernel are auto-discovered.

This script benchmarks each ablated kernel and computes attribution:
  attribution(m) = ms_ablated(m) - ms_champion

Positive -> the method helped (removing it slowed things down).
Zero/Negative -> the method did not help or actually hurt.

Writes iterv{i}/attribution.json.

"""

from __future__ import annotations

import argparse
import glob
import json
import os
import subprocess
import sys
from pathlib import Path


_BUNDLED_BENCHMARK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "benchmark.py")


def _load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _sibling_hpps(kernel_path: str) -> list[str]:
    kdir = os.path.dirname(kernel_path)
    return sorted(glob.glob(os.path.join(kdir, "*.hpp")))


def _target_kernel_rel(state: dict) -> str:
    if not state.get("target_kernel"):
        raise SystemExit("state.json has no target_kernel")
    return state["target_kernel"]


def _method_kernel(method_dir: str) -> str | None:
    candidate = os.path.join(method_dir, "kernel.scpp")
    return candidate if os.path.isfile(candidate) else None


def _bench_kernel(
    benchmark_py: str,
    tree: str,
    kernel_path: str,
    target_kernel_abs: str,
    op_name: str | None,
    case_path: str | None,
    json_out: str,
    warmup: int = 3,
    repeat: int = 50,
) -> dict | None:
    """Run benchmark.py on a single kernel and return the parsed JSON result."""
    hpps = _sibling_hpps(kernel_path)
    cmd = [
        sys.executable, benchmark_py,
        "--tree", tree,
        "--kernel", kernel_path,
        "--target", target_kernel_abs,
        "--warmup", str(warmup),
        "--repeat", str(repeat),
        "--json-out", json_out,
    ]
    if op_name:
        cmd += ["--op", op_name]
    if case_path:
        cmd += ["--case", case_path]
    for hpp in hpps:
        cmd += ["--hpp", hpp]

    Path(json_out).parent.mkdir(parents=True, exist_ok=True)

    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True,
            encoding="utf-8", errors="ignore",
        )
    except OSError as e:
        print(f"[ablate] benchmark failed: {e}", file=sys.stderr)
        return None

    if os.path.isfile(json_out):
        return _load_json(json_out)
    return None


def run(state_path: str, iteration: int, benchmark_py: str = None) -> dict:
    state = _load_json(state_path)
    run_dir = state["run_dir"]
    tree = state["tree"]
    target_kernel_abs = os.path.join(tree, _target_kernel_rel(state))
    op_name = state.get("op")
    case_path = state.get("case_path")
    iter_dir = os.path.join(run_dir, f"iterv{iteration}")
    bench_py = benchmark_py or _BUNDLED_BENCHMARK

    # Load champion timing
    champion_bench = os.path.join(iter_dir, "bench.json")
    if not os.path.isfile(champion_bench):
        sys.exit(f"Champion bench.json not found at {champion_bench}")
    champion_data = _load_json(champion_bench)
    champion_ms = (champion_data.get("kernel") or {}).get("average_ms")
    if champion_ms is None:
        sys.exit("Champion has no timing data")

    # Load methods
    methods_path = os.path.join(iter_dir, "methods.json")
    if not os.path.isfile(methods_path):
        sys.exit(f"methods.json not found at {methods_path}")
    methods_data = _load_json(methods_path)
    methods_list = methods_data.get("methods", [])

    noise_threshold = state.get("noise_threshold_pct", 2.0)

    attributions = []
    ablation_dir = os.path.join(iter_dir, "ablations")

    for m in methods_list:
        mid = m.get("id", "unknown")
        method_dir = os.path.join(ablation_dir, mid.replace(".", "_"))

        ablated_kernel = _method_kernel(method_dir)

        if not ablated_kernel:
            # No ablated kernel provided — skip, assume neutral
            attributions.append({
                "method_id": mid,
                "ablated_kernel": None,
                "ablated_ms": None,
                "champion_ms": champion_ms,
                "attribution_ms": 0.0,
                "attribution_pct": 0.0,
                "contributed": False,
                "note": "no_ablated_kernel_provided",
            })
            continue

        ablated_json_out = os.path.join(method_dir, "bench.json")
        result = _bench_kernel(
            bench_py, tree, ablated_kernel, target_kernel_abs, op_name, case_path, ablated_json_out,
        )

        if result is None or not result.get("correctness", {}).get("passed", False):
            attributions.append({
                "method_id": mid,
                "ablated_kernel": ablated_kernel,
                "ablated_ms": None,
                "champion_ms": champion_ms,
                "attribution_ms": None,
                "attribution_pct": None,
                "contributed": True,
                "note": "ablated_kernel_failed_validation_method_essential",
            })
            continue

        ablated_ms = (result.get("kernel") or {}).get("average_ms")
        if ablated_ms is None:
            attributions.append({
                "method_id": mid,
                "ablated_kernel": ablated_kernel,
                "ablated_ms": None,
                "champion_ms": champion_ms,
                "attribution_ms": 0.0,
                "attribution_pct": 0.0,
                "contributed": False,
                "note": "no_timing_in_ablated_bench",
            })
            continue

        attr_ms = ablated_ms - champion_ms
        attr_pct = (attr_ms / champion_ms * 100) if champion_ms > 0 else 0.0
        contributed = attr_pct > noise_threshold

        attributions.append({
            "method_id": mid,
            "ablated_kernel": ablated_kernel,
            "ablated_ms": round(ablated_ms, 4),
            "champion_ms": round(champion_ms, 4),
            "attribution_ms": round(attr_ms, 4),
            "attribution_pct": round(attr_pct, 2),
            "contributed": contributed,
        })

    output = {
        "iter": iteration,
        "champion_ms": round(champion_ms, 4),
        "noise_threshold_pct": noise_threshold,
        "attributions": attributions,
    }

    out_path = os.path.join(iter_dir, "attribution.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(json.dumps(output, indent=2))
    return output


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--iter", type=int, required=True)
    p.add_argument("--benchmark", default=None)
    args = p.parse_args()
    run(args.state, args.iter, args.benchmark)


if __name__ == "__main__":
    main()
