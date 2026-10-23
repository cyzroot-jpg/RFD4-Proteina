#!/usr/bin/env python3
"""Global state manager for the optimization loop (teco-ops native tests).

Subcommands:
  init               create run_YYYYMMDD_HHMMSS/, copy the teco-ops tree
                     into run_dir/tree/, run preflight to resolve the target
                     .scpp + prototxt case, seed state.json
  update             after a successful iteration, merge methods into
                     selected / effective / ineffective / implementation_failed
                     lists using attribution data
  set-baseline-metric  called by run_iteration.py seed-baseline
  show               pretty-print current state (debug)

state.json schema (paths stored absolute unless noted):
{
  "run_dir": str,
  "baseline_tree": str,           // abs path to original teco-ops
  "tree": str,                    // abs path to working copy (run_dir/tree)
  "op": str | null,
  "target_kernel": str,           // relpath inside tree
  "case_path": str | null,        // prototxt path relative to tree/test
  "best_file": str,               // relpath inside working tree
  "best_metric_ms": float | null,
  "env": {...},
  "iterations_total": int,
  "branches": int,
  "noise_threshold_pct": float,
  "selected_methods":   [ {id, name, axis, iter} ],
  "effective_methods":  [ {id, name, axis, iter, attribution_ms} ],
  "ineffective_methods":[ {id, name, axis, iter} ],
  "implementation_failed_methods": [ {id, name, axis, iter, note} ],
  "history": [ per-iteration records ],
  "frontier": [ {iter, branch, kernel, ms, methods} ]
}

No ref_file, no dims — correctness + timing come from the teco-ops demo case.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import shutil
import sys
from pathlib import Path

# Import preflight as a module (same directory) to resolve target + case.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import preflight  # noqa: E402


# ---------------------------------------------------------------------------
# IO helpers
# ---------------------------------------------------------------------------

def _read(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write(path: str, payload: dict) -> None:
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)


def _ignore_build_dir(path: str, names: list[str]) -> set[str]:
    """Don't copy build artifacts when cloning the teco-ops tree."""
    ignored = set()
    if "build" in names:
        ignored.add("build")
    return ignored


# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------

def cmd_init(args: argparse.Namespace) -> None:
    baseline_tree = os.path.abspath(args.baseline)
    if not os.path.isdir(baseline_tree):
        sys.exit(f"baseline tree not found: {baseline_tree}")

    # 1. preflight to resolve target .scpp + prototxt case (and validate tree)
    rep = preflight.run(baseline_tree, args.op, args.target, args.case)
    if not rep["ok"]:
        sys.exit("preflight failed:\n" + json.dumps(rep, indent=2, ensure_ascii=False))
    target_kernel_rel = rep["target"]["relpath"]
    case_path = rep["target"].get("case_path")
    build_target = rep["target"].get("build_target")
    preflight_warnings = rep.get("warnings", [])

    # 2. create run dir next to the tree
    ts = _dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = os.path.join(os.path.dirname(baseline_tree.rstrip("/")), f"run_{ts}")
    os.makedirs(run_dir, exist_ok=False)

    # 3. copy the entire tree into run_dir/tree/ (working copy the loop mutates)
    working_tree = os.path.join(run_dir, "tree")
    shutil.copytree(baseline_tree, working_tree, ignore=_ignore_build_dir)

    # 4. seed state.json
    env = {}
    if args.env and os.path.isfile(args.env):
        env = _read(args.env)

    state = {
        "run_dir": run_dir,
        "baseline_tree": baseline_tree,
        "tree": working_tree,
        "op": args.op,
        "target_kernel": target_kernel_rel,
        "case_path": case_path,
        "build_target": build_target,
        "best_file": target_kernel_rel,   # relpath inside working tree
        "best_metric_ms": None,
        "env": env,
        "iterations_total": int(args.iterations),
        "branches": int(args.branches),
        "noise_threshold_pct": float(args.noise_threshold_pct),
        "preflight_warnings": preflight_warnings,
        "selected_methods": [],
        "effective_methods": [],
        "ineffective_methods": [],
        "implementation_failed_methods": [],
        "history": [],
        "frontier": [],
        "created_at": ts,
    }
    state_path = os.path.join(run_dir, "state.json")
    _write(state_path, state)

    # 5. create iterv{1..N} skeletons
    for i in range(1, state["iterations_total"] + 1):
        os.makedirs(os.path.join(run_dir, f"iterv{i}"), exist_ok=True)

    print(json.dumps({
        "run_dir": run_dir,
        "state": state_path,
        "tree": working_tree,
        "target_kernel": target_kernel_rel,
        "case_path": case_path,
        "build_target": build_target,
        "preflight_warnings": preflight_warnings,
    }, indent=2))


# ---------------------------------------------------------------------------
# update  (v2: uses attribution only)
# ---------------------------------------------------------------------------

def _method_key(m: dict) -> str:
    if "id" in m and m["id"]:
        return str(m["id"]).strip().lower()
    return f"{str(m.get('name','')).strip().lower()}::{str(m.get('axis','')).strip().lower()}"


def _merge_unique(bag: list[dict], new_items: list[dict]) -> list[dict]:
    seen = {_method_key(m) for m in bag}
    for m in new_items:
        k = _method_key(m)
        if k not in seen:
            bag.append(m)
            seen.add(k)
    return bag


def cmd_update(args: argparse.Namespace) -> None:
    state = _read(args.state)
    bench = _read(args.bench)
    methods = _read(args.methods_json)

    if not isinstance(methods, dict) or "methods" not in methods:
        sys.exit("methods-json must contain a top-level 'methods' list")
    methods_list = methods["methods"]

    validation_passed = bool(bench.get("correctness", {}).get("passed", True))
    new_ms = None
    ref_ms = None
    if bench.get("kernel"):
        new_ms = bench["kernel"].get("average_ms")
    if bench.get("reference"):
        ref_ms = bench["reference"].get("average_ms")

    # Load attribution if provided
    attribution_data = {}
    if args.attribution and os.path.isfile(args.attribution):
        attr = _read(args.attribution)
        for a in attr.get("attributions", []):
            attribution_data[a["method_id"]] = a

    # Decide improvement
    best_before = state.get("best_metric_ms")
    threshold = 1.0 - (state.get("noise_threshold_pct", 2.0) / 100.0)
    improved = False
    speedup_vs_best_before = None
    if validation_passed and new_ms and new_ms > 0:
        if best_before is None:
            improved = True
        else:
            speedup_vs_best_before = best_before / new_ms
            improved = new_ms < best_before * threshold

    # Annotate each method
    for m in methods_list:
        m.setdefault("id", _method_key(m))
        m["iter"] = int(args.iter)

    # Always: add to selected
    _merge_unique(state["selected_methods"], methods_list)

    # Classify each method based on attribution + correctness
    for m in methods_list:
        mid = m["id"]
        attr_info = attribution_data.get(mid, {})
        contributed = attr_info.get("contributed", None)
        attr_ms = attr_info.get("attribution_ms", None)

        m_entry = dict(m)

        if not validation_passed:
            m_entry["note"] = "champion failed correctness validation"
            state["implementation_failed_methods"].append(m_entry)
        elif contributed is True or contributed is None:
            if improved:
                if attr_ms is not None:
                    m_entry["attribution_ms"] = attr_ms
                if speedup_vs_best_before is not None:
                    m_entry["speedup_vs_best_before"] = speedup_vs_best_before
                state["effective_methods"].append(m_entry)
            else:
                state["ineffective_methods"].append(m_entry)
        elif contributed is False:
            m_entry["note"] = f"attribution_ms={attr_ms}"
            state["ineffective_methods"].append(m_entry)

    # Update best: champion .scpp becomes the new best (stored as relpath in tree)
    if validation_passed and improved:
        state["best_file"] = state["target_kernel"]
        state["best_metric_ms"] = new_ms

    # Load frontier from branch_results if available
    iter_dir = os.path.join(state["run_dir"], f"iterv{args.iter}")
    branch_results_path = os.path.join(iter_dir, "branch_results.json")
    if os.path.isfile(branch_results_path):
        br = _read(branch_results_path)
        for fe in br.get("frontier", []):
            fe["methods"] = [m["id"] for m in methods_list]
            state["frontier"].append(fe)

    status = (
        "improved" if (validation_passed and improved)
        else "regressed" if validation_passed
        else "failed_validation"
    )
    state["history"].append({
        "iter": int(args.iter),
        "methods": [m["id"] for m in methods_list],
        "method_names": [m.get("name") for m in methods_list],
        "ms": new_ms,
        "ref_ms": ref_ms,
        "speedup_vs_ref": (ref_ms / new_ms) if (ref_ms and new_ms and new_ms > 0) else None,
        "speedup_vs_best_before": speedup_vs_best_before,
        "validation_passed": validation_passed,
        "status": status,
        "retries": int(args.retries),
    })

    _write(args.state, state)
    print(json.dumps({
        "iter": args.iter,
        "status": status,
        "new_ms": new_ms,
        "best_ms": state["best_metric_ms"],
        "improved": improved,
        "speedup_vs_best_before": speedup_vs_best_before,
    }, indent=2))


# ---------------------------------------------------------------------------
# seed baseline metric
# ---------------------------------------------------------------------------

def cmd_set_baseline_metric(args: argparse.Namespace) -> None:
    state = _read(args.state)
    bench = _read(args.bench)
    if not bench.get("correctness", {}).get("passed", True):
        sys.exit("Baseline failed correctness validation — cannot proceed.")
    ms = bench.get("kernel", {}).get("average_ms")
    if ms is None:
        sys.exit("Baseline bench has no kernel timing.")
    state["best_metric_ms"] = ms
    _write(args.state, state)
    print(json.dumps({"baseline_ms": ms}, indent=2))


def cmd_show(args: argparse.Namespace) -> None:
    state = _read(args.state)
    print(json.dumps(state, indent=2))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("init")
    pi.add_argument("--baseline", required=True,
                    help="Path to teco-ops tree (directory)")
    grp = pi.add_mutually_exclusive_group(required=True)
    grp.add_argument("--op", help="Op/test build target")
    grp.add_argument("--target", help="Relative path to target .scpp inside the tree")
    pi.add_argument("--case", default=None, help="prototxt case path relative to teco-ops/test")
    pi.add_argument("--iterations", type=int, default=3)
    pi.add_argument("--branches", type=int, default=4)
    pi.add_argument("--env", type=str, default="")
    pi.add_argument("--noise-threshold-pct", type=float, default=2.0)
    pi.set_defaults(func=cmd_init)

    pu = sub.add_parser("update")
    pu.add_argument("--state", required=True)
    pu.add_argument("--iter", required=True, type=int)
    pu.add_argument("--kernel", required=True)
    pu.add_argument("--bench", required=True)
    pu.add_argument("--methods-json", required=True)
    pu.add_argument("--attribution", type=str, default=None,
                    help="Path to attribution.json from ablation step")
    pu.add_argument("--retries", type=int, default=0)
    pu.set_defaults(func=cmd_update)

    pb = sub.add_parser("set-baseline-metric")
    pb.add_argument("--state", required=True)
    pb.add_argument("--bench", required=True)
    pb.set_defaults(func=cmd_set_baseline_metric)

    ps = sub.add_parser("show")
    ps.add_argument("--state", required=True)
    ps.set_defaults(func=cmd_show)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
