#!/usr/bin/env python3
"""Preflight validation for a teco-ops working tree.

The optimizer now uses the teco-ops native C++ test framework for both
correctness and performance. A valid baseline tree must contain:
  - teco/
  - test/
  - build.sh

The target is a kernel .scpp inside teco/ual/kernel/. The test case is a
prototxt under test/zoo/teco/<op>/test_case/.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

OP_KERNELS = {
    "reshape_and_cache": "teco/ual/kernel/reshape_and_cache/reshape_and_cache_fp16.scpp",
    "reshape_and_cache_flash": "teco/ual/kernel/reshape_and_cache/reshape_and_cache_fp16.scpp",
    "flash_attention": "teco/ual/kernel/flash_attention/flash_attention.scpp",
    "flash_attn_varlen_func": "teco/ual/kernel/flash_attention/flash_attention.scpp",
}

OP_BUILD_TARGETS = {
    "reshape_and_cache": "reshape_and_cache",
    "reshape_and_cache_flash": "reshape_and_cache",
    "flash_attention": "flash_attention",
    "flash_attn_varlen_func": "flash_attention",
}


def _default_case(op: str | None) -> str | None:
    if not op:
        return None
    build_target = OP_BUILD_TARGETS.get(op, op)
    return f"zoo/teco/{build_target}/test_case/case_0.prototxt"


def _resolve_target(bpath: Path, op: str | None, target: str | None) -> Path | None:
    if target:
        return (bpath / target) if not os.path.isabs(target) else Path(target)
    if op and op in OP_KERNELS:
        return bpath / OP_KERNELS[op]
    return None


def run(baseline: str, op: str | None, target: str | None, case: str | None = None) -> dict:
    report: dict = {
        "ok": True,
        "baseline": {},
        "target": {},
        "warnings": [],
        "errors": [],
    }

    bpath = Path(baseline)
    if not bpath.is_dir():
        report["ok"] = False
        report["errors"].append(f"baseline is not a directory: {baseline}")
        return report

    missing = [name for name in ("teco", "test", "build.sh") if not (bpath / name).exists()]
    if missing:
        report["ok"] = False
        report["errors"].append(
            f"baseline does not look like a teco-ops tree — missing: {missing}"
        )
        return report

    report["baseline"] = {
        "path": str(bpath.resolve()),
        "type": "teco-ops",
        "has_teco_dir": True,
        "has_test_dir": True,
    }

    target_kernel = _resolve_target(bpath, op, target)
    if target_kernel is None:
        report["ok"] = False
        report["errors"].append(
            f"unknown --op `{op}`; known ops: {sorted(OP_KERNELS)} or pass --target <rel_path.scpp>"
        )
        return report

    if target and not op and not case:
        report["ok"] = False
        report["errors"].append("target-only mode requires --case <prototxt> relative to teco-ops/test")
        return report

    if not target_kernel.is_file():
        report["ok"] = False
        report["errors"].append(f"target .scpp not found: {target_kernel}")
        return report

    rel = os.path.relpath(target_kernel, bpath)
    case_path = case or _default_case(op)
    if case_path:
        case_file = bpath / "test" / case_path
        if not case_file.is_file():
            report["warnings"].append(
                f"test case not found at default path: test/{case_path}; pass --case if this op uses another case"
            )

    report["target"] = {
        "path": str(target_kernel),
        "relpath": rel,
        "target_kernel": rel,
        "case_path": case_path,
        "build_target": OP_BUILD_TARGETS.get(op or "", op),
        "op": op,
        "type": "teco-ops-kernel",
    }
    return report


def main() -> None:
    p = argparse.ArgumentParser(description="Preflight: validate teco-ops tree + target .scpp")
    p.add_argument("--baseline", required=True, help="Path to teco-ops tree")
    grp = p.add_mutually_exclusive_group(required=True)
    grp.add_argument("--op", help="Op/test build target")
    grp.add_argument("--target", help="Relative path to the target .scpp inside the teco-ops tree")
    p.add_argument("--case", default=None, help="prototxt case path relative to teco-ops/test")
    p.add_argument("--out", default="", help="Optional path to write the report as JSON")
    args = p.parse_args()

    rep = run(os.path.abspath(args.baseline), args.op, args.target, args.case)
    payload = json.dumps(rep, indent=2, ensure_ascii=False)
    print(payload)
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(payload)

    sys.exit(0 if rep["ok"] else 1)


if __name__ == "__main__":
    main()
