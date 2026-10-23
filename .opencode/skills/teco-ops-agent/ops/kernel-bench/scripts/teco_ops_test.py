#!/usr/bin/env python3
"""Build and run teco-ops C++ operator tests.

The teco-ops project validates both correctness and performance through its
test framework:

    bash build.sh --build teco
    cd test && source env.sh && sh build.sh --arch teco
    ./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
      --case_path=zoo/teco/<op>/test_case/case_0.prototxt
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT.parents[1] / "teco-ops"


def run_shell(cmd: str, cwd: Path, timeout: int) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", "-lc", cmd],
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def default_case_path(demo_root: Path, op: str) -> str:
    case_dir = demo_root / "test" / "zoo" / "teco" / op / "test_case"
    candidates = [
        case_dir / "case_0.prototxt",
        case_dir / "0.prototxt",
    ]
    candidates.extend(sorted(case_dir.glob("*.prototxt")))
    for path in candidates:
        if path.is_file():
            return str(path.relative_to(demo_root / "test"))
    return f"zoo/teco/{op}/test_case/case_0.prototxt"


def parse_perf(output: str) -> dict:
    metrics: dict[str, float] = {}
    patterns = {
        "time_ms": r"(?:time|latency|cost)[^0-9]{0,16}([0-9]+(?:\.[0-9]+)?)\s*ms",
        "time_us": r"(?:time|latency|cost)[^0-9]{0,16}([0-9]+(?:\.[0-9]+)?)\s*us",
        "tflops": r"([0-9]+(?:\.[0-9]+)?)\s*(?:TFLOPS|TFlops|tflops)",
        "gbps": r"([0-9]+(?:\.[0-9]+)?)\s*(?:GB/s|GBPS|gbps)",
    }
    for name, pattern in patterns.items():
        matches = re.findall(pattern, output)
        if matches:
            metrics[name] = float(matches[-1])
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="Run teco-ops correctness/performance test")
    parser.add_argument("--op", required=True)
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--case-path", default="")
    parser.add_argument("--gid", default="0")
    parser.add_argument("--perf-repeat", type=int, default=50)
    parser.add_argument("--warm-repeat", type=int, default=3)
    parser.add_argument("--gtest-repeat", type=int, default=1)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).expanduser().resolve()
    test_root = demo_root / "test"
    case_path = args.case_path or default_case_path(demo_root, args.op)

    report: dict = {
        "backend": "teco_ops",
        "op": args.op,
        "demo_root": str(demo_root),
        "case_path": case_path,
        "commands": [],
    }

    if not (demo_root / "build.sh").is_file() or not test_root.is_dir():
        report["error"] = f"not a teco-ops tree: {demo_root}"
        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        else:
            print(report["error"], file=sys.stderr)
        return 1

    if not args.skip_build:
        build_lib_cmd = "bash build.sh --build teco"
        proc = run_shell(build_lib_cmd, demo_root, timeout=600)
        report["commands"].append({
            "cmd": build_lib_cmd,
            "cwd": str(demo_root),
            "returncode": proc.returncode,
            "stdout_tail": proc.stdout[-4000:],
            "stderr_tail": proc.stderr[-4000:],
        })
        if proc.returncode != 0:
            if args.json:
                print(json.dumps(report, ensure_ascii=False, indent=2))
            else:
                print(proc.stderr or proc.stdout, file=sys.stderr)
            return proc.returncode

        build_test_cmd = "source env.sh && sh build.sh --arch teco"
        proc = run_shell(build_test_cmd, test_root, timeout=600)
        report["commands"].append({
            "cmd": build_test_cmd,
            "cwd": str(test_root),
            "returncode": proc.returncode,
            "stdout_tail": proc.stdout[-4000:],
            "stderr_tail": proc.stderr[-4000:],
        })
        if proc.returncode != 0:
            if args.json:
                print(json.dumps(report, ensure_ascii=False, indent=2))
            else:
                print(proc.stderr or proc.stdout, file=sys.stderr)
            return proc.returncode

    if args.build_only:
        report["correctness"] = {"passed": True, "skipped": True}
        report["delivery"] = {"delivery_status": "pass"}
        if args.json:
            print(json.dumps(report, ensure_ascii=False, indent=2))
        else:
            print(f"teco_ops_test: build OK (op={args.op})")
        return 0

    demo_cmd = (
        f"./build/demo --gid={args.gid} --perf_repeat={args.perf_repeat} "
        f"--warm_repeat={args.warm_repeat} --gtest_repeat={args.gtest_repeat} "
        f"--case_path={case_path}"
    )
    env = os.environ.copy()
    proc = subprocess.run(
        ["bash", "-lc", f"source env.sh && {demo_cmd}"],
        cwd=test_root,
        text=True,
        capture_output=True,
        timeout=600,
        check=False,
        env=env,
    )
    output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    metrics = parse_perf(output)
    report["commands"].append({
        "cmd": f"source env.sh && {demo_cmd}",
        "cwd": str(test_root),
        "returncode": proc.returncode,
        "stdout_tail": proc.stdout[-6000:],
        "stderr_tail": proc.stderr[-6000:],
    })
    report["correctness"] = {"passed": proc.returncode == 0}
    report["delivery"] = {
        "delivery_status": "pass" if proc.returncode == 0 else "incomplete",
    }
    report["performance"] = {
        "perf_repeat": args.perf_repeat,
        "warm_repeat": args.warm_repeat,
        "metrics": metrics,
    }

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        status = "PASS" if proc.returncode == 0 else "FAIL"
        print(f"teco_ops_test: {status} (op={args.op}, case={case_path})")
        if metrics:
            print("metrics:", json.dumps(metrics, ensure_ascii=False))
        if proc.returncode != 0:
            print(output[-3000:], file=sys.stderr)

    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
