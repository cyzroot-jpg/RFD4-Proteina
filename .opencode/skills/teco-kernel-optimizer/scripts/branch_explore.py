#!/usr/bin/env python3
"""Branch-and-Select: compile and benchmark K teco-ops candidate kernels.

All K branches share the same method combination (from methods.json) but
differ in hyperparameters (tile size, num_stages, num_warps, etc.).

Claude generates K kernels under iterv{i}/branches/b{1..K}/kernel.scpp.
Optional sibling *.hpp files alongside each kernel.scpp are passed to
benchmark.py via --hpp.

This script:
  1. Benchmarks each branch (installs .scpp + .hpp over the target in the
     working tree, rebuilds teco-ops, builds test/demo, runs the prototxt case).
  2. Selects champion = fastest valid kernel
  3. Copies champion to iterv{i}/kernel.scpp (+ sibling .hpp to iterv{i}/)
  4. Returns non-champions as frontier candidates in state

Writes iterv{i}/branch_results.json.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


_BUNDLED_BENCHMARK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "benchmark.py")
_BUNDLED_QUERY_WIKI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "query_wiki.py")


def _load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path: str, obj) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)


def _sibling_hpps(kernel_path: str) -> list[str]:
    kdir = os.path.dirname(kernel_path)
    return sorted(glob.glob(os.path.join(kdir, "*.hpp")))


def _target_kernel_rel(state: dict) -> str:
    if not state.get("target_kernel"):
        raise SystemExit("state.json has no target_kernel")
    return state["target_kernel"]


def _branch_kernel(branch_dir: str) -> str | None:
    candidate = os.path.join(branch_dir, "kernel.scpp")
    return candidate if os.path.isfile(candidate) else None


def _query_wiki_before_iteration(state: dict, iteration: int) -> dict:
    """Query teco-ops-wiki before starting iteration. Returns query result or error."""
    run_dir = state["run_dir"]
    op = state.get("op") or Path(state.get("target_kernel", "teco_ops")).stem
    iter_dir = os.path.join(run_dir, f"iterv{iteration}")
    wiki_output = os.path.join(iter_dir, "wiki_queries.json")

    # Check if wiki query already exists
    if os.path.isfile(wiki_output):
        print(f"[branch_explore] Wiki query already exists for iteration {iteration}", file=sys.stderr)
        return _load_json(wiki_output)

    # Run wiki query
    cmd = [
        sys.executable, _BUNDLED_QUERY_WIKI,
        "--op", op,
        "--iter", str(iteration),
        "--out", wiki_output,
    ]

    print(f"[branch_explore] Querying teco-ops-wiki before iteration {iteration}...", file=sys.stderr)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode != 0:
            print(f"[branch_explore] WARNING: Wiki query failed: {result.stderr}", file=sys.stderr)
            # Don't fail the iteration, just warn
            return {"success": False, "error": result.stderr}

        print(f"[branch_explore] Wiki query completed successfully", file=sys.stderr)
        if os.path.isfile(wiki_output):
            return _load_json(wiki_output)
        else:
            return {"success": False, "error": "wiki output file not created"}

    except subprocess.TimeoutExpired:
        print(f"[branch_explore] WARNING: Wiki query timed out", file=sys.stderr)
        return {"success": False, "error": "timeout"}
    except Exception as e:
        print(f"[branch_explore] WARNING: Wiki query failed: {e}", file=sys.stderr)
        return {"success": False, "error": str(e)}


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
) -> dict:
    """Run benchmark.py on a kernel. Returns parsed result or error dict."""
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
    stderr_out = json_out.replace(".json", ".stderr.txt")

    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True,
            encoding="utf-8", errors="ignore",
        )
    except OSError as e:
        return {"error": str(e), "passed": False}

    with open(stderr_out, "w", encoding="utf-8") as f:
        f.write("---STDOUT---\n")
        f.write(r.stdout or "")
        f.write("\n---STDERR---\n")
        f.write(r.stderr or "")

    if os.path.isfile(json_out):
        return _load_json(json_out)

    return {
        "error": "no_json_output",
        "stderr": (r.stderr or "")[-2000:],
        "passed": False,
    }


def run(state_path: str, iteration: int, benchmark_py: str = None,
        warmup: int = 10, repeat: int = 20) -> dict:
    state = _load_json(state_path)
    run_dir = state["run_dir"]
    tree = state["tree"]
    target_kernel_abs = os.path.join(tree, _target_kernel_rel(state))
    op_name = state.get("op")
    case_path = state.get("case_path")
    iter_dir = os.path.join(run_dir, f"iterv{iteration}")
    bench_py = benchmark_py or _BUNDLED_BENCHMARK
    branches_dir = os.path.join(iter_dir, "branches")
    num_branches = state.get("branches", 4)

    # MANDATORY: Query wiki before starting iteration
    wiki_result = _query_wiki_before_iteration(state, iteration)
    if not wiki_result.get("success", False):
        print(f"[branch_explore] WARNING: Wiki query did not succeed, but continuing with iteration", file=sys.stderr)

    analysis_path = os.path.join(iter_dir, "analysis.md")
    methods_path = os.path.join(iter_dir, "methods.json")
    if not os.path.isfile(analysis_path):
        sys.exit(
            f"analysis.md missing at {analysis_path}; write the evidence-based "
            "iteration plan after reading wiki_queries.json/state/previous results "
            "and before branch exploration"
        )
    if not os.path.isfile(methods_path):
        sys.exit(f"methods.json missing at {methods_path}; write methods before branch exploration")

    # Discover branches
    branch_dirs = []
    for i in range(1, num_branches + 1):
        bd = os.path.join(branches_dir, f"b{i}")
        if os.path.isdir(bd):
            kernel = _branch_kernel(bd)
            if kernel:
                branch_dirs.append({"index": i, "dir": bd, "kernel": kernel})

    if not branch_dirs:
        # Fallback: a single kernel directly in iter_dir
        candidate = _branch_kernel(iter_dir)
        if candidate:
            branch_dirs.append({"index": 0, "dir": iter_dir, "kernel": candidate})

    if not branch_dirs:
        sys.exit(f"No branch kernels found under {branches_dir}")

    print(f"[branch_explore] Found {len(branch_dirs)} branches", file=sys.stderr)

    # Benchmark all branches
    results = []
    for branch in branch_dirs:
        idx = branch["index"]
        kernel = branch["kernel"]
        json_out = os.path.join(branch["dir"], "bench.json")

        print(f"[branch {idx}] Benchmarking {os.path.basename(kernel)}...",
              file=sys.stderr)

        bench_result = _bench_kernel(
            bench_py, tree, kernel, target_kernel_abs, op_name, case_path, json_out, warmup, repeat,
        )

        passed = bool(bench_result.get("correctness", {}).get("passed", False))
        ms = None
        if bench_result.get("kernel"):
            ms = bench_result["kernel"].get("average_ms")

        results.append({
            "branch_index": idx,
            "kernel": kernel,
            "passed": passed,
            "ms": ms,
            "error": bench_result.get("error"),
        })

        status = "PASS" if passed else "FAIL"
        ms_str = f"{ms:.4f} ms" if ms else "N/A"
        print(f"[branch {idx}] {status}  {ms_str}", file=sys.stderr)

    # Select champion: fastest valid branch
    valid_results = [r for r in results if r["passed"] and r["ms"] is not None]

    if not valid_results:
        output = {
            "iter": iteration,
            "status": "all_branches_failed",
            "branches": results,
            "champion": None,
        }
        _write_json(os.path.join(iter_dir, "branch_results.json"), output)
        print(json.dumps(output, indent=2))
        sys.exit(2)

    champion = min(valid_results, key=lambda r: r["ms"])

    # Copy champion kernel to iterv{i}/kernel.scpp (+ sibling .hpp to iterv{i}/)
    champ_kernel = champion["kernel"]
    dest = os.path.join(iter_dir, "kernel.scpp")
    if os.path.abspath(champ_kernel) != os.path.abspath(dest):
        shutil.copy2(champ_kernel, dest)
    for hpp in _sibling_hpps(champ_kernel):
        shutil.copy2(hpp, os.path.join(iter_dir, os.path.basename(hpp)))

    # Also copy champion bench.json to iter_dir
    champ_bench = os.path.join(os.path.dirname(champ_kernel), "bench.json")
    dest_bench = os.path.join(iter_dir, "bench.json")
    if os.path.isfile(champ_bench) and os.path.abspath(champ_bench) != os.path.abspath(dest_bench):
        shutil.copy2(champ_bench, dest_bench)

    # Build frontier from non-champion valid results
    frontier_entries = []
    for r in valid_results:
        if r["branch_index"] != champion["branch_index"]:
            frontier_entries.append({
                "iter": iteration,
                "branch_index": r["branch_index"],
                "kernel": r["kernel"],
                "ms": r["ms"],
                "delta_from_champion": round(r["ms"] - champion["ms"], 4),
            })

    output = {
        "iter": iteration,
        "status": "champion_selected",
        "champion": {
            "branch_index": champion["branch_index"],
            "kernel": dest,
            "ms": champion["ms"],
        },
        "branches": results,
        "frontier": frontier_entries,
        "total_branches": len(branch_dirs),
        "valid_branches": len(valid_results),
    }

    _write_json(os.path.join(iter_dir, "branch_results.json"), output)
    print(json.dumps(output, indent=2))
    return output


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--iter", type=int, required=True)
    p.add_argument("--benchmark", default=None)
    p.add_argument("--warmup", type=int, default=3)
    p.add_argument("--repeat", type=int, default=50)
    args = p.parse_args()
    run(args.state, args.iter, args.benchmark, args.warmup, args.repeat)


if __name__ == "__main__":
    main()
