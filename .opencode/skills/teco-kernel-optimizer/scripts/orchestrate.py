#!/usr/bin/env python3
"""End-to-end orchestrator (v2 — benchmark-driven, branch-and-select).

Subcommands:
  setup       Steps 0-2: env check, preflight, init, seed baseline
  open-iter   Prepare an iteration work area for Claude to write branch kernels,
              methods.json, and analysis.md
  close-iter  Steps 3c-3f: branch explore → optional ablate → update
  finalize    Step 4: emit summary.md
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def _run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    print(f"[run] {' '.join(cmd)}", file=sys.stderr)
    return subprocess.run(cmd, text=True, **kw)


def _read(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _query_wiki_for_iter(state: dict, run_dir: str, iteration: int) -> str:
    """Create itervN/wiki_queries.json if absent and return its path."""
    iter_dir = os.path.join(run_dir, f"iterv{iteration}")
    wiki_output = os.path.join(iter_dir, "wiki_queries.json")
    if not os.path.isfile(wiki_output):
        print(f"[open-iter] Querying teco-ops-wiki before iteration {iteration}...", file=sys.stderr)
        wiki_cmd = [
            sys.executable, str(SCRIPT_DIR / "query_wiki.py"),
            "--op", state.get("op") or Path(state.get("target_kernel", "teco_ops")).stem,
            "--iter", str(iteration),
            "--out", wiki_output,
        ]
        wiki_result = _run(wiki_cmd)
        if wiki_result.returncode != 0:
            print("[open-iter] WARNING: Wiki query failed, but continuing", file=sys.stderr)
        else:
            print(f"[open-iter] Wiki query completed, results saved to {wiki_output}", file=sys.stderr)
    else:
        print(f"[open-iter] Wiki query already exists for iteration {iteration}", file=sys.stderr)
    return wiki_output


def _previous_artifacts(run_dir: str, iteration: int) -> dict:
    if iteration <= 1:
        return {}
    prev_dir = os.path.join(run_dir, f"iterv{iteration - 1}")
    names = ["analysis.md", "branch_results.json", "bench.json", "attribution.json"]
    return {name: os.path.join(prev_dir, name) for name in names if os.path.isfile(os.path.join(prev_dir, name))}


# ---------------------------------------------------------------------------
# setup  —  steps 0, 1, 2, and open-iter(1)
# ---------------------------------------------------------------------------

def cmd_setup(args):
    env_json = os.path.abspath(args.env_out or "./env.json")

    rc = _run([
        sys.executable, str(SCRIPT_DIR / "check_env.py"),
        "--out", env_json,
    ]).returncode
    if rc != 0:
        sys.exit(f"check_env failed rc={rc}")

    preflight_cmd = [
        sys.executable, str(SCRIPT_DIR / "preflight.py"),
        "--baseline", os.path.abspath(args.baseline),
    ]
    if args.op:
        preflight_cmd.extend(["--op", args.op])
    else:
        preflight_cmd.extend(["--target", args.target])
    if args.case:
        preflight_cmd.extend(["--case", args.case])
    rc = _run(preflight_cmd).returncode
    if rc != 0:
        sys.exit("preflight failed — fix baseline tree or target above, then retry")

    init_cmd = [
        sys.executable, str(SCRIPT_DIR / "state.py"), "init",
        "--baseline", os.path.abspath(args.baseline),
        "--iterations", str(args.iterations),
        "--branches", str(args.branches),
        "--env", env_json,
        "--noise-threshold-pct", str(args.noise_threshold_pct),
    ]
    if args.op:
        init_cmd.extend(["--op", args.op])
    else:
        init_cmd.extend(["--target", args.target])
    if args.case:
        init_cmd.extend(["--case", args.case])
    init = _run(init_cmd, capture_output=True)
    if init.returncode != 0:
        sys.stderr.write(init.stderr or "")
        sys.exit("state init failed")
    sys.stderr.write(init.stderr or "")

    init_info = {}
    try:
        init_info = json.loads(init.stdout or "{}")
    except json.JSONDecodeError:
        for line in reversed((init.stdout or "").splitlines()):
            line = line.strip()
            if line.startswith("{") and line.endswith("}"):
                try:
                    init_info = json.loads(line)
                    break
                except json.JSONDecodeError:
                    continue
    run_dir = init_info.get("run_dir")
    state_path = init_info.get("state")
    if not run_dir or not state_path:
        sys.exit(f"could not parse state init output:\n{init.stdout}")

    rc = _run([
        sys.executable, str(SCRIPT_DIR / "run_iteration.py"), "seed-baseline",
        "--state", state_path,
        "--benchmark", os.path.abspath(args.benchmark),
        "--warmup", str(args.warmup),
        "--repeat", str(args.repeat),
    ]).returncode
    if rc != 0:
        sys.exit("baseline seed failed")

    state = _read(state_path)
    iter_dir = os.path.join(run_dir, "iterv1")
    branches_dir = os.path.join(iter_dir, "branches")
    for b in range(1, state.get("branches", 4) + 1):
        os.makedirs(os.path.join(branches_dir, f"b{b}"), exist_ok=True)
    wiki_output = _query_wiki_for_iter(state, run_dir, 1)

    print(json.dumps({
        "run_dir": run_dir,
        "state": state_path,
        "env": env_json,
        "wiki_queries": wiki_output,
        "next_step": (
            f"Claude MUST now read {wiki_output}, state.json, and the current best .scpp. "
            "Then write iterv1/analysis.md and iterv1/methods.json BEFORE branch kernels. "
            "After the plan is written, write "
            f"iterv1/branches/b{{1..{state.get('branches', 4)}}}/kernel.scpp, "
            "After that, run: orchestrate.py close-iter --run-dir <run_dir> --iter 1"
        ),
    }, indent=2))


# ---------------------------------------------------------------------------
# open-iter  —  profile + roofline for iteration N (if not done by setup)
# ---------------------------------------------------------------------------

def cmd_open_iter(args):
    state_path = os.path.join(args.run_dir, "state.json")
    if not os.path.isfile(state_path):
        sys.exit(f"state.json missing: {state_path}")

    state = _read(state_path)
    iter_dir = os.path.join(args.run_dir, f"iterv{args.iter}")
    branches_dir = os.path.join(iter_dir, "branches")
    num_branches = state.get("branches", 4)
    for b in range(1, num_branches + 1):
        os.makedirs(os.path.join(branches_dir, f"b{b}"), exist_ok=True)

    # MANDATORY: Query wiki before starting iteration.
    wiki_output = _query_wiki_for_iter(state, args.run_dir, args.iter)
    prev = _previous_artifacts(args.run_dir, args.iter)
    current_best = os.path.join(state["tree"], state["best_file"])

    print(json.dumps({
        "iter": args.iter,
        "branches_dir": branches_dir,
        "num_branches": num_branches,
        "wiki_queries": wiki_output,
        "state": state_path,
        "current_best": current_best,
        "previous_artifacts": prev,
        "next_step": (
            f"Claude MUST first read {wiki_output}, {state_path}, and {current_best}. "
            "If this is not iter 1, Claude MUST also read previous_artifacts above. "
            f"Then write iterv{args.iter}/analysis.md with the new evidence-based plan "
            f"and iterv{args.iter}/methods.json BEFORE generating branch kernels. "
            f"Only after that, write {num_branches} branch kernels under "
            f"iterv{args.iter}/branches/b{{1..{num_branches}}}/kernel.scpp. "
            f"Then run: orchestrate.py close-iter --run-dir {args.run_dir} --iter {args.iter}"
        ),
    }, indent=2))


# ---------------------------------------------------------------------------
# close-iter  —  branch explore → ncu champion → ablate → sass → update
# ---------------------------------------------------------------------------

def cmd_close_iter(args):
    state_path = os.path.join(args.run_dir, "state.json")
    if not os.path.isfile(state_path):
        sys.exit(f"state.json missing: {state_path}")

    state = _read(state_path)
    iter_dir = os.path.join(args.run_dir, f"iterv{args.iter}")
    wiki_queries = os.path.join(iter_dir, "wiki_queries.json")
    analysis_md = os.path.join(iter_dir, "analysis.md")
    methods_json = os.path.join(iter_dir, "methods.json")
    if not os.path.isfile(wiki_queries):
        sys.exit(
            f"wiki_queries.json missing at {wiki_queries}; run open-iter and read it before close-iter"
        )
    if not os.path.isfile(analysis_md):
        sys.exit(
            f"analysis.md missing at {analysis_md}; write the evidence-based iteration plan before branch exploration"
        )
    if not os.path.isfile(methods_json):
        sys.exit(f"methods.json missing at {methods_json}")

    missing_branches = []
    for b in range(1, state.get("branches", 4) + 1):
        kernel = os.path.join(iter_dir, "branches", f"b{b}", "kernel.scpp")
        if not os.path.isfile(kernel):
            missing_branches.append(kernel)
    if missing_branches:
        sys.exit(
            "branch kernel(s) missing; generate candidates after analysis.md:\n"
            + "\n".join(missing_branches)
        )

    if not args.skip_plan_validate:
        rc = _run([
            sys.executable, str(SCRIPT_DIR / "validate_iteration_plan.py"),
            "--state", state_path,
            "--iter", str(args.iter),
        ]).returncode
        if rc != 0:
            sys.exit("iteration plan validation failed")

    branch_result = _run([
        sys.executable, str(SCRIPT_DIR / "branch_explore.py"),
        "--state", state_path,
        "--iter", str(args.iter),
        "--benchmark", os.path.abspath(args.benchmark),
        "--warmup", str(args.warmup),
        "--repeat", str(args.repeat),
    ], capture_output=True)
    sys.stderr.write(branch_result.stderr or "")

    if branch_result.returncode == 2:
        print(json.dumps({
            "iter": args.iter,
            "status": "all_branches_failed",
            "guidance": "Claude should fix the kernels and retry close-iter.",
        }, indent=2))
        sys.exit(2)
    if branch_result.returncode != 0:
        sys.exit(f"branch_explore failed rc={branch_result.returncode}")

    kernel = os.path.join(iter_dir, "kernel.scpp")
    if not os.path.isfile(kernel):
        sys.exit("No champion kernel found after branch_explore")

    bench_json = os.path.join(iter_dir, "bench.json")
    if not os.path.isfile(bench_json):
        sys.exit("bench.json missing for champion")

    bench = _read(bench_json)
    passed = bool(bench.get("correctness", {}).get("passed", False))
    if not passed:
        print(json.dumps({
            "iter": args.iter,
            "status": "validation_failed",
            "bench_json": bench_json,
            "guidance": "Claude should fix the kernel and re-run close-iter.",
        }, indent=2))
        sys.exit(2)

    attribution_path = os.path.join(iter_dir, "attribution.json")
    ablation_dir = os.path.join(iter_dir, "ablations")
    if os.path.isdir(ablation_dir):
        rc = _run([
            sys.executable, str(SCRIPT_DIR / "ablate.py"),
            "--state", state_path,
            "--iter", str(args.iter),
            "--benchmark", os.path.abspath(args.benchmark),
        ]).returncode
        if rc != 0:
            sys.exit("ablation failed")

    update_cmd = [
        sys.executable, str(SCRIPT_DIR / "state.py"), "update",
        "--state", state_path,
        "--iter", str(args.iter),
        "--kernel", kernel,
        "--bench", bench_json,
        "--methods-json", methods_json,
        "--retries", str(args.retries),
    ]
    if os.path.isfile(attribution_path):
        update_cmd.extend(["--attribution", attribution_path])

    rc = _run(update_cmd).returncode
    if rc != 0:
        sys.exit("state update failed")

    state = _read(state_path)
    next_iter = args.iter + 1
    if next_iter <= state["iterations_total"]:
        next_iter_dir = os.path.join(state["run_dir"], f"iterv{next_iter}")
        next_branches_dir = os.path.join(next_iter_dir, "branches")
        for b in range(1, state.get("branches", 4) + 1):
            os.makedirs(os.path.join(next_branches_dir, f"b{b}"), exist_ok=True)

    print(json.dumps({
        "iter": args.iter,
        "status": "closed",
        "best_ms": state.get("best_metric_ms"),
        "next_iter": next_iter if next_iter <= state["iterations_total"] else None,
        "state": state_path,
    }, indent=2))


# ---------------------------------------------------------------------------
# finalize  —  step 4
# ---------------------------------------------------------------------------

def cmd_finalize(args):
    state_path = os.path.join(args.run_dir, "state.json")
    summary_path = os.path.join(args.run_dir, "summary.md")
    rc = _run([
        sys.executable, str(SCRIPT_DIR / "summarize.py"),
        "--state", state_path,
        "--out", summary_path,
    ]).returncode
    if rc != 0:
        sys.exit("summarize failed")
    print(json.dumps({"summary": summary_path}, indent=2))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    _default_bench = str(SCRIPT_DIR / "benchmark.py")

    ps = sub.add_parser("setup")
    ps.add_argument("--baseline", required=True)
    grp = ps.add_mutually_exclusive_group(required=True)
    grp.add_argument("--op")
    grp.add_argument("--target")
    ps.add_argument("--benchmark", default=_default_bench)
    ps.add_argument("--case", default=None, help="prototxt case path relative to teco-ops/test")
    ps.add_argument("--iterations", type=int, default=3)
    ps.add_argument("--branches", type=int, default=4)
    ps.add_argument("--noise-threshold-pct", type=float, default=2.0)
    ps.add_argument("--env-out", type=str, default="")
    ps.add_argument("--warmup", type=int, default=3)
    ps.add_argument("--repeat", type=int, default=50)
    ps.set_defaults(func=cmd_setup)

    po = sub.add_parser("open-iter")
    po.add_argument("--run-dir", required=True)
    po.add_argument("--iter", type=int, required=True)
    po.add_argument("--benchmark", default=_default_bench)
    po.set_defaults(func=cmd_open_iter)

    pc = sub.add_parser("close-iter")
    pc.add_argument("--run-dir", required=True)
    pc.add_argument("--iter", type=int, required=True)
    pc.add_argument("--benchmark", default=_default_bench)
    pc.add_argument("--warmup", type=int, default=3)
    pc.add_argument("--repeat", type=int, default=50)
    pc.add_argument("--retries", type=int, default=0)
    pc.add_argument("--skip-plan-validate", action="store_true",
                    help="Bypass evidence-based plan validation before benchmarking")
    pc.set_defaults(func=cmd_close_iter)

    pf = sub.add_parser("finalize")
    pf.add_argument("--run-dir", required=True)
    pf.set_defaults(func=cmd_finalize)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
