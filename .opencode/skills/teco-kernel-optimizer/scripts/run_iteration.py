#!/usr/bin/env python3
"""Run teco-ops benchmark.py for a given iteration or baseline seed step.

Subcommands:
  seed-baseline   Run benchmark.py on the working tree's target .scpp to
                  capture initial timing.
  benchmark       Run benchmark.py on iterv{i}/kernel.scpp (installed over
                  the target .scpp in the working tree).

Both write JSON under the appropriate directory. `benchmark` additionally
captures stderr so Claude can inspect it on validation failure.
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


def _read(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _sibling_hpps(kernel_path: str) -> list[str]:
    """Discover sibling .hpp files next to the branch kernel (if any)."""
    kdir = os.path.dirname(kernel_path)
    return sorted(glob.glob(os.path.join(kdir, "*.hpp")))


def _target_kernel_rel(state: dict) -> str:
    if not state.get("target_kernel"):
        raise SystemExit("state.json has no target_kernel")
    return state["target_kernel"]


def _iter_kernel(iter_dir: str) -> str:
    candidate = os.path.join(iter_dir, "kernel.scpp")
    if os.path.isfile(candidate):
        return candidate
    raise SystemExit(f"No kernel.scpp found under {iter_dir}.")


def _run_bench(
    *,
    benchmark_py: str,
    tree: str,
    kernel: str,
    target_kernel: str,
    op_name: str | None,
    case_path: str | None,
    hpps: list[str],
    json_out: str,
    stderr_out: str,
    warmup: int,
    repeat: int,
) -> int:
    cmd = [
        sys.executable, benchmark_py,
        "--tree", tree,
        "--kernel", kernel,
        "--target", target_kernel,
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
    print(f"[bench] {' '.join(cmd)}", file=sys.stderr)

    Path(json_out).parent.mkdir(parents=True, exist_ok=True)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    except OSError as e:
        with open(stderr_out, "w", encoding="utf-8") as f:
            f.write(f"Failed to exec benchmark: {e}\n")
        return -1

    with open(stderr_out, "w", encoding="utf-8") as f:
        f.write("---STDOUT---\n")
        f.write(r.stdout or "")
        f.write("\n---STDERR---\n")
        f.write(r.stderr or "")

    if not os.path.isfile(json_out):
        # Catastrophic — write a minimal JSON for downstream consumers
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump({
                "correctness": {"passed": False, "checked": True},
                "kernel": None,
                "reference": None,
                "error": {
                    "code": "benchmark_crashed",
                    "stage": "subprocess",
                    "message": (r.stderr or "")[-2000:],
                },
            }, f, indent=2)
    return r.returncode


def cmd_seed_baseline(args: argparse.Namespace) -> None:
    state = _read(args.state)
    run_dir = state["run_dir"]
    tree = state["tree"]
    target_kernel_abs = os.path.join(tree, _target_kernel_rel(state))
    out_dir = os.path.join(run_dir, "baseline")
    os.makedirs(out_dir, exist_ok=True)
    json_out = os.path.join(out_dir, "bench.json")
    stderr_out = os.path.join(out_dir, "bench.stderr.txt")

    # Seed: install the baseline .scpp over itself (no-op) to drive a clean bench.
    _run_bench(
        benchmark_py=os.path.abspath(args.benchmark),
        tree=tree,
        kernel=target_kernel_abs,
        target_kernel=target_kernel_abs,
        op_name=state.get("op"),
        case_path=state.get("case_path"),
        hpps=[],
        json_out=json_out,
        stderr_out=stderr_out,
        warmup=args.warmup,
        repeat=args.repeat,
    )

    # Push baseline ms into state via state.py CLI (keep one place that writes state)
    sibling = os.path.join(os.path.dirname(__file__), "state.py")
    rc = subprocess.call([
        sys.executable, sibling, "set-baseline-metric",
        "--state", args.state, "--bench", json_out,
    ])
    sys.exit(rc)


def cmd_benchmark(args: argparse.Namespace) -> None:
    state = _read(args.state)
    run_dir = state["run_dir"]
    tree = state["tree"]
    target_kernel_abs = os.path.join(tree, _target_kernel_rel(state))
    iter_dir = os.path.join(run_dir, f"iterv{args.iter}")
    kernel = _iter_kernel(iter_dir)

    hpps = _sibling_hpps(kernel)
    json_out = os.path.join(iter_dir, "bench.json")
    stderr_out = os.path.join(iter_dir, "bench.stderr.txt")
    _run_bench(
        benchmark_py=os.path.abspath(args.benchmark),
        tree=tree,
        kernel=kernel,
        target_kernel=target_kernel_abs,
        op_name=state.get("op"),
        case_path=state.get("case_path"),
        hpps=hpps,
        json_out=json_out,
        stderr_out=stderr_out,
        warmup=args.warmup,
        repeat=args.repeat,
    )
    # Return the result summary on stdout for the orchestrator to consume
    res = _read(json_out)
    summary = {
        "iter": args.iter,
        "kernel": kernel,
        "passed": bool(res.get("correctness", {}).get("passed", False)),
        "ms": (res.get("kernel") or {}).get("average_ms"),
        "ref_ms": (res.get("reference") or {}).get("average_ms"),
        "speedup_vs_ref": res.get("speedup_vs_reference"),
        "error": res.get("error"),
        "bench_json": json_out,
        "stderr_log": stderr_out,
    }
    print(json.dumps(summary, indent=2))


def main() -> None:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    ps = sub.add_parser("seed-baseline")
    ps.add_argument("--state", required=True)
    ps.add_argument("--benchmark", default=_BUNDLED_BENCHMARK,
                    help="Path to benchmark.py (default: bundled)")
    ps.add_argument("--warmup", type=int, default=3)
    ps.add_argument("--repeat", type=int, default=50)
    ps.set_defaults(func=cmd_seed_baseline)

    pb = sub.add_parser("benchmark")
    pb.add_argument("--state", required=True)
    pb.add_argument("--iter", type=int, required=True)
    pb.add_argument("--benchmark", default=_BUNDLED_BENCHMARK,
                    help="Path to benchmark.py (default: bundled)")
    pb.add_argument("--warmup", type=int, default=3)
    pb.add_argument("--repeat", type=int, default=50)
    pb.set_defaults(func=cmd_benchmark)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
