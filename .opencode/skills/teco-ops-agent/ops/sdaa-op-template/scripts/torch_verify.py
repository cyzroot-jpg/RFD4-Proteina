#!/usr/bin/env python3
"""Build and verify swdnn_test_ops operators with PyTorch golden only."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT / "swdnn_test_ops"
SCOPE_SCRIPT = SCRIPT_DIR / "scope_cmake_op.py"
CMAKE_BASELINE_SCRIPT = SCRIPT_DIR / "cmake_baseline.py"


def _cpu_golden_allowed(args: argparse.Namespace) -> bool:
    value = os.environ.get("TORCH_VERIFY_ALLOW_CPU_GOLDEN", "").strip().lower()
    return bool(args.allow_cpu_golden or value in {"1", "true", "yes", "on"})


def _load_torch_meta(torch_data: Path) -> dict:
    meta_path = torch_data / "meta.json"
    if not meta_path.is_file():
        return {}
    try:
        return json.loads(meta_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def _check_cuda_golden(torch_data: Path, args: argparse.Namespace) -> tuple[bool, str]:
    if _cpu_golden_allowed(args):
        return True, "cpu golden explicitly allowed"

    meta = _load_torch_meta(torch_data)
    torch_device = str(meta.get("torch_device", "")).lower()
    if torch_device.startswith("cuda"):
        return True, torch_device
    if torch_device:
        return False, (
            f"PyTorch golden used {torch_device}; CUDA golden is required by default. "
            "Run torch_verify in non-sandbox host environment, or pass "
            "--allow-cpu-golden for an explicit CPU-only validation."
        )
    return False, (
        "PyTorch golden meta.json does not record torch_device; use "
        "torch_golden_lib.setup_torch_golden(seed) and save torch_device, or pass "
        "--allow-cpu-golden for legacy CPU-only validation."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="PyTorch-only build + verify pipeline")
    parser.add_argument("--op", required=True)
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--build-dir", default="")
    parser.add_argument("--scope-cmake", action="store_true")
    parser.add_argument("--restore-cmake", action="store_true")
    parser.add_argument("--build-only", action="store_true", help="Compile only, skip device run and torch compare")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--compare-only", action="store_true")
    parser.add_argument(
        "--allow-cpu-golden",
        action="store_true",
        help="Allow PyTorch golden generated on CPU. Default requires CUDA golden.",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).resolve()
    if not demo_root.is_dir():
        raise SystemExit(f"demo root not found: {demo_root}")

    script_path = demo_root / "src" / args.op / f"{args.op}_torch_golden.py"
    if not script_path.is_file() and not args.build_only:
        raise SystemExit(f"missing {script_path} — run scaffold_op.py to generate torch golden script")

    scoped = False
    if args.scope_cmake and not args.compare_only:
        rc = subprocess.run(
            [sys.executable, str(SCOPE_SCRIPT), "--op", args.op, "--demo-root", str(demo_root)],
            check=False,
        )
        if rc.returncode != 0:
            return rc.returncode
        scoped = True
    elif not args.compare_only:
        baseline = subprocess.run(
            [sys.executable, str(CMAKE_BASELINE_SCRIPT), "--demo-root", str(demo_root)],
            check=False,
        )
        if baseline.returncode != 0:
            return baseline.returncode

    build_dir_name = args.build_dir or (f"build_{args.op}" if scoped else "build")
    build_dir = demo_root / build_dir_name
    torch_data = build_dir / "torch_golden" / args.op

    report: dict = {
        "op": args.op,
        "build_dir": str(build_dir),
        "torch_script": str(script_path),
        "verify_mode": "pytorch_only",
    }

    if not args.compare_only and not args.build_only:
        prep = subprocess.run(
            [sys.executable, str(script_path), "--prepare", "--build-dir", str(build_dir)],
            cwd=demo_root,
            text=True,
            capture_output=True,
        )
        report["prepare_returncode"] = prep.returncode
        report["prepare_stdout"] = prep.stdout
        if prep.returncode != 0:
            print(prep.stderr or prep.stdout, file=sys.stderr)
            if args.json:
                print(json.dumps(report, indent=2))
            return prep.returncode
        cuda_ok, cuda_detail = _check_cuda_golden(torch_data, args)
        report["torch_golden_device_check"] = {
            "pass": cuda_ok,
            "detail": cuda_detail,
        }
        if not cuda_ok:
            print(cuda_detail, file=sys.stderr)
            if args.restore_cmake and scoped:
                subprocess.run(
                    [sys.executable, str(SCOPE_SCRIPT), "--restore", "--demo-root", str(demo_root)],
                    check=False,
                )
            if args.json:
                print(json.dumps(report, indent=2))
            return 1

    if args.prepare_only:
        if args.json:
            print(json.dumps(report, indent=2))
        return 0

    env = os.environ.copy()
    env["BUILD_DIR"] = str(build_dir)
    lib_dir = str(build_dir)
    env["LD_LIBRARY_PATH"] = lib_dir + os.pathsep + env.get("LD_LIBRARY_PATH", "")
    if not args.build_only:
        env["SDAA_TORCH_DATA_DIR"] = str(torch_data)

    run = subprocess.run(
        ["bash", "run.sh", args.op],
        cwd=demo_root,
        env=env,
        text=True,
        capture_output=True,
    )
    report["build_returncode"] = run.returncode
    report["build_stdout"] = run.stdout[-4000:]
    report["build_stderr"] = run.stderr[-4000:]
    report["lib_built"] = (build_dir / "libswdnn_test.so").is_file()

    if run.returncode != 0:
        print(run.stderr or run.stdout, file=sys.stderr)
        if "file format not recognized" in (run.stderr or run.stdout):
            print(
                "hint: run scope_cmake with cmake baseline or "
                f"python3 {CMAKE_BASELINE_SCRIPT} --demo-root {demo_root}",
                file=sys.stderr,
            )
        if "Compatibility with CMake <" in (run.stderr or run.stdout):
            print(
                f"hint: python3 {CMAKE_BASELINE_SCRIPT} --demo-root {demo_root}",
                file=sys.stderr,
            )
        if args.restore_cmake and scoped:
            subprocess.run(
                [sys.executable, str(SCOPE_SCRIPT), "--restore", "--demo-root", str(demo_root)],
                check=False,
            )
        if args.json:
            print(json.dumps(report, indent=2))
        return run.returncode

    if args.build_only:
        if args.restore_cmake and scoped:
            subprocess.run(
                [sys.executable, str(SCOPE_SCRIPT), "--restore", "--demo-root", str(demo_root)],
                check=False,
            )
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            print(f"torch_verify: build OK (op={args.op})")
        return 0

    cmp_proc = subprocess.run(
        [sys.executable, str(script_path), "--compare", "--build-dir", str(build_dir), "--json"],
        cwd=demo_root,
        text=True,
        capture_output=True,
    )
    report["compare_returncode"] = cmp_proc.returncode
    report["compare_stdout"] = cmp_proc.stdout
    if cmp_proc.stdout.strip():
        try:
            report["compare_result"] = json.loads(cmp_proc.stdout)
        except json.JSONDecodeError:
            report["compare_result"] = None
            print(cmp_proc.stdout)
    if cmp_proc.stderr:
        print(cmp_proc.stderr, file=sys.stderr)

    if args.restore_cmake and scoped:
        subprocess.run(
            [sys.executable, str(SCOPE_SCRIPT), "--restore", "--demo-root", str(demo_root)],
            check=False,
        )

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        passed = cmp_proc.returncode == 0
        cr = report.get("compare_result") or {}
        rate = cr.get("success_rate")
        extra = f", success_rate={rate}" if rate is not None else ""
        print(f"torch_verify: {'PASS' if passed else 'FAIL'} (op={args.op}{extra})")

    return cmp_proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
