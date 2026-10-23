#!/usr/bin/env python3
"""SDAA operator benchmark driver for teco-ops.

The teco-ops README and doc/README_OP.md define one native correctness and
performance path:
  1. Build the operator library from the teco-ops root:
       bash build.sh --build teco
  2. Build the C++ test framework from test/:
       source env.sh && bash build.sh --arch teco [-f <op>]
  3. Run the demo with a prototxt case:
       ./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 \
         --gtest_repeat=1 --case_path=zoo/teco/<op>/test_case/case_0.prototxt

This script installs an optional candidate .scpp over the target kernel before
running that flow and emits the structured JSON consumed by the optimizer.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

SETVARS_SH = "/opt/tecoai/setvars.sh"

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


def _sourced_env() -> dict:
    env = dict(os.environ)
    if not os.path.isfile(SETVARS_SH):
        return env
    r = subprocess.run(
        ["bash", "-c", f"source {SETVARS_SH} >/dev/null 2>&1 && env"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore",
    )
    if r.returncode != 0:
        return env
    for line in r.stdout.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            env[k] = v
    return env


def _run(cmd: list[str], *, cwd: str | None = None, env: dict | None = None) -> subprocess.CompletedProcess:
    print(f"[sh] {' '.join(cmd)}", file=sys.stderr)
    r = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore",
    )
    if r.returncode != 0:
        if r.stdout:
            sys.stderr.write(r.stdout)
        if r.stderr:
            sys.stderr.write(r.stderr)
    return r


def _default_case(op_name: str) -> str:
    if not op_name:
        sys.exit("must pass --case when --op is not provided")
    build_target = OP_BUILD_TARGETS.get(op_name, op_name)
    return f"zoo/teco/{build_target}/test_case/case_0.prototxt"


def _resolve_target_kernel(tree: str, op_name: str | None, target_kernel: str | None) -> str:
    if target_kernel:
        candidate = target_kernel
    elif op_name and op_name in OP_KERNELS:
        candidate = OP_KERNELS[op_name]
    else:
        known = ", ".join(sorted(OP_KERNELS))
        sys.exit(f"unknown target kernel; pass --target or use --op with one of: {known}")

    if not os.path.isabs(candidate):
        candidate = os.path.join(tree, candidate)
    return os.path.abspath(candidate)


def _build_teco_ops(tree: str, env: dict) -> None:
    r = _run(["bash", "build.sh", "--build", "teco"], cwd=tree, env=env)
    if r.returncode != 0:
        sys.exit("teco-ops library build failed")


def _build_test_framework(tree: str, op_name: str | None, env: dict) -> None:
    test_dir = os.path.join(tree, "test")
    if not os.path.isdir(test_dir):
        sys.exit(f"teco-ops test directory not found: {test_dir}")

    build_target = OP_BUILD_TARGETS.get(op_name or "", op_name or "")
    cmd = "source env.sh && bash build.sh --arch teco"
    if build_target:
        cmd += f' -f "{build_target}"'
    r = _run(["bash", "-c", cmd], cwd=test_dir, env=env)
    if r.returncode != 0:
        sys.exit("teco-ops test framework build failed")


def _run_demo(tree: str, gid: int, case_path: str, warmup: int, repeat: int, env: dict) -> subprocess.CompletedProcess:
    test_dir = os.path.join(tree, "test")
    demo_path = os.path.join(test_dir, "build", "demo")
    if not os.path.isfile(demo_path):
        sys.exit(f"demo binary not found: {demo_path}")

    env = dict(env)
    # The teco-ops demo locates the Python golden-reference module via
    # TECOAL_TECOTEST_PROJECT (exported by test/env.sh). Set it explicitly so
    # reference generation/resolution does not depend on the caller's shell.
    env["TECOAL_TECOTEST_PROJECT"] = test_dir

    cmd = [
        "./build/demo",
        f"--gid={gid}",
        f"--perf_repeat={repeat}",
        f"--warm_repeat={warmup}",
        "--gtest_repeat=1",
        f"--case_path={case_path}",
    ]
    print(f"[run] {' '.join(cmd)}", file=sys.stderr)
    return subprocess.run(
        cmd,
        cwd=test_dir,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore",
        timeout=600,
    )


def _parse_stdout(stdout: str) -> tuple[float | None, float | None, bool | None]:
    hw_time_ms = None
    max_error = None
    passed = None

    for line in (stdout or "").splitlines():
        m = re.search(r"\[Average Hardware Time\s*\]:\s*([0-9eE.+-]+)", line)
        if m:
            hw_time_ms = float(m.group(1))
            continue

        m = re.search(r"max_error:\s*([0-9eE.+-]+)", line)
        if m:
            max_error = float(m.group(1))
            continue

        if "ALL PASSED" in line:
            passed = True
            continue
        if "FAILED" in line and "ALL" not in line:
            passed = False

    if hw_time_ms is not None and passed is None:
        passed = True
    return hw_time_ms, max_error, passed


def run(
    *,
    tree: str,
    kernel: str | None,
    hpps: list[str],
    op_name: str | None,
    target_kernel: str | None,
    case_path: str | None,
    gid: int,
    warmup: int,
    repeat: int,
    json_out: str,
) -> dict:
    tree = os.path.abspath(tree)
    if not os.path.isdir(os.path.join(tree, "teco")) or not os.path.isdir(os.path.join(tree, "test")):
        sys.exit(f"baseline must be a teco-ops tree with teco/ and test/: {tree}")

    target_kernel_path = _resolve_target_kernel(tree, op_name, target_kernel)
    if not os.path.isfile(target_kernel_path):
        sys.exit(f"target kernel not found: {target_kernel_path}")

    if kernel:
        kernel = os.path.abspath(kernel)
        if not os.path.isfile(kernel):
            sys.exit(f"kernel not found: {kernel}")
        if os.path.abspath(kernel) != os.path.abspath(target_kernel_path):
            print(f"[install] {kernel} -> {target_kernel_path}", file=sys.stderr)
            shutil.copy2(kernel, target_kernel_path)

    target_dir = os.path.dirname(target_kernel_path)
    for hpp in hpps:
        if not os.path.isfile(hpp):
            sys.exit(f"--hpp file not found: {hpp}")
        dest = os.path.join(target_dir, os.path.basename(hpp))
        if os.path.abspath(hpp) != os.path.abspath(dest):
            print(f"[install] {hpp} -> {dest}", file=sys.stderr)
            shutil.copy2(hpp, dest)

    case_path = case_path or _default_case(op_name or "")
    env = _sourced_env()
    _build_teco_ops(tree, env)
    _build_test_framework(tree, op_name, env)
    r = _run_demo(tree, gid, case_path, warmup, repeat, env)
    hw_time_ms, max_error, passed = _parse_stdout(r.stdout)

    ok = r.returncode == 0 and hw_time_ms is not None and passed is True
    result = {
        "solution_file": os.path.abspath(kernel) if kernel else None,
        "target_kernel": target_kernel_path,
        "tree": tree,
        "backend": "teco-ops",
        "op": op_name,
        "test_case": case_path,
        "gid": gid,
        "warmup": warmup,
        "repeat": repeat,
        "correctness": {
            "checked": True,
            "passed": passed,
            "max_error": max_error,
        },
        "kernel": {"average_ms": hw_time_ms},
        "reference": {"average_ms": None},
        "speedup_vs_reference": None,
        "exit_code": r.returncode,
        "error": None if ok else {
            "code": "bench_failed",
            "message": "teco-ops demo did not produce passing correctness and Average Hardware Time",
            "stdout_tail": (r.stdout or "")[-2000:],
            "stderr_tail": (r.stderr or "")[-2000:],
        },
    }

    if json_out:
        out_dir = os.path.dirname(json_out)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


def main() -> None:
    p = argparse.ArgumentParser(description="SDAA operator benchmark (teco-ops native test framework)")
    p.add_argument("--tree", required=True, help="Path to the teco-ops working tree")
    p.add_argument("--kernel", default=None, help="Candidate .scpp kernel to install before testing")
    p.add_argument("--op", default=None, help="Operator/test build target, e.g. reshape_and_cache or flash_attention")
    p.add_argument("--target", default=None, help="Target .scpp path inside the teco-ops tree")
    p.add_argument("--hpp", action="append", default=[], help="Sibling .hpp to install alongside the target kernel")
    p.add_argument("--case", default=None, help="prototxt case path relative to teco-ops/test")
    p.add_argument("--gid", type=int, default=0)
    p.add_argument("--warmup", type=int, default=3)
    p.add_argument("--repeat", type=int, default=50)
    p.add_argument("--json-out", default="", help="Write structured result as JSON")
    args = p.parse_args()

    run(
        tree=args.tree,
        kernel=args.kernel,
        hpps=args.hpp,
        op_name=args.op,
        target_kernel=args.target,
        case_path=args.case,
        gid=args.gid,
        warmup=args.warmup,
        repeat=args.repeat,
        json_out=args.json_out,
    )


if __name__ == "__main__":
    main()
