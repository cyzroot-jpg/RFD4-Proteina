#!/usr/bin/env python3
"""Benchmark kernel execution time using rt_time_cycle().

Instruments a .swcu kernel with cycle counters, compiles, runs, and reports
the maximum execution cycles across all SPEs.
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
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parents[1]
DEFAULT_DEMO_ROOT = REPO_ROOT / "swdnn_test_ops"
DEVICE_INFO_SCRIPT = REPO_ROOT / "ops" / "sdaa-env-check" / "scripts" / "device_info.py"


def get_spe_clock_hz() -> int:
    """Get SPE clock frequency from device_info.py."""
    try:
        result = subprocess.run(
            [sys.executable, str(DEVICE_INFO_SCRIPT), "--json"],
            capture_output=True, text=True, check=True, timeout=15
        )
        info = json.loads(result.stdout)
        return int(info.get("spe_clock_hz", 2500000000))
    except Exception:
        return 2500000000


def backup_swcu(swcu_path: Path) -> Path:
    backup_path = swcu_path.with_suffix(swcu_path.suffix + ".bench_bak")
    backup_path.write_text(swcu_path.read_text(encoding="utf-8"))
    return backup_path


def restore_swcu(swcu_path: Path, backup_path: Path) -> None:
    if backup_path.is_file():
        swcu_path.write_text(backup_path.read_text(encoding="utf-8"))
        backup_path.unlink()


def find_matching_brace(source: str, open_brace: int) -> int:
    depth = 0
    for pos in range(open_brace, len(source)):
        char = source[pos]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return pos
    raise ValueError("cannot find matching brace")


def find_global_body(source: str, op: str) -> tuple[int, int, int, int]:
    signature = re.compile(
        rf"__global__\s+void\s+teco_slave_{re.escape(op)}\s*\(",
        re.MULTILINE,
    )
    match = signature.search(source)
    if not match:
        raise ValueError(f"cannot find __global__ teco_slave_{op}")
    paren_depth = 0
    close_paren = -1
    for pos in range(match.end() - 1, len(source)):
        char = source[pos]
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
            if paren_depth == 0:
                close_paren = pos
                break
    if close_paren < 0:
        raise ValueError(f"cannot parse teco_slave_{op} parameter list")
    open_brace = source.find("{", close_paren)
    if open_brace < 0:
        raise ValueError(f"cannot find teco_slave_{op} body")
    close_brace = find_matching_brace(source, open_brace)
    return match.start(), close_paren, open_brace, close_brace


def instrument_kernel(source: str, op: str) -> str:
    """Insert cycle timing instrumentation into kernel source."""
    _, _, open_brace, close_brace = find_global_body(source, op)
    body = source[open_brace + 1:close_brace]

    start_code = (
        '\n'
        '    /* BENCH: cycle start */\n'
        '    asm volatile("memb");\n'
        '    long __bench_t = rt_time_cycle();\n'
    )
    early_ret = (
        r'(if\s*\(\s*tid\s*>=\s*slave_core_num\s*\)\s*\{\s*return;\s*\}\s*)'
        r'|(if\s*\(\s*tid\s*>=\s*slave_core_num\s*\)\s*return;\s*)'
    )
    match = re.search(early_ret, body)
    if match:
        insert_start = open_brace + 1 + match.end()
    else:
        insert_start = open_brace + 1

    source = source[:insert_start] + start_code + source[insert_start:]
    close_brace += len(start_code)

    end_code = (
        '\n'
        '    /* BENCH: cycle end */\n'
        '    asm volatile("memb");\n'
        '    long __bench_t_elapsed = rt_time_cycle() - __bench_t;\n'
        '    if (tid == 0) {\n'
        '        printf("[BENCH] max_cycles=%ld (SPE 0)\\n", __bench_t_elapsed);\n'
        '    }\n'
    )
    source = source[:close_brace] + end_code + source[close_brace:]

    print(f"[bench] instrumentation: teco_slave_{op} direct rt_time_cycle printf")
    return source


def build_and_run(demo_root: Path, op: str, build_dir_name: str) -> subprocess.CompletedProcess:
    build_dir = demo_root / build_dir_name
    env = os.environ.copy()
    env["BUILD_DIR"] = str(build_dir)
    env["LD_LIBRARY_PATH"] = str(build_dir) + os.pathsep + env.get("LD_LIBRARY_PATH", "")

    torch_data = build_dir / "torch_golden" / op
    env["SDAA_TORCH_DATA_DIR"] = str(torch_data)

    if not (torch_data / "a.bin").is_file():
        print("[bench] preparing golden data...")
        subprocess.run(
            [sys.executable, str(demo_root / "src" / op / f"{op}_torch_golden.py"),
             "--prepare", "--build-dir", str(build_dir)],
            cwd=demo_root, check=True, timeout=60
        )

    run = subprocess.run(
        ["bash", "run.sh", op],
        cwd=demo_root,
        env=env,
        text=True,
        capture_output=True,
        timeout=120,
    )
    return run


def parse_bench_output(output: str) -> dict | None:
    for line in output.splitlines():
        m = re.search(r'\[BENCH\]\s+max_cycles=(\d+)\s+\(SPE\s+(\d+)\)', line)
        if m:
            return {"max_cycles": int(m.group(1)), "max_spe": int(m.group(2))}
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark kernel execution cycles")
    parser.add_argument("--op", required=True, help="Operator name")
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--build-dir", default="")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).expanduser().resolve()
    op = args.op
    swcu_path = demo_root / "src" / op / f"{op}.swcu"
    build_dir_name = args.build_dir or f"build_{op}"

    if not swcu_path.is_file():
        print(f"error: {swcu_path} not found", file=sys.stderr)
        return 1

    spe_clock_hz = get_spe_clock_hz()
    spe_clock_mhz = spe_clock_hz / 1_000_000

    backup = backup_swcu(swcu_path)
    print(f"[bench] backed up {swcu_path} → {backup}")

    try:
        source = swcu_path.read_text(encoding="utf-8")
        instrumented = instrument_kernel(source, op)
        swcu_path.write_text(instrumented, encoding="utf-8")

        print(f"[bench] building and running {op}...")
        run = build_and_run(demo_root, op, build_dir_name)

        if run.returncode != 0:
            print(f"[bench] build/run failed (rc={run.returncode})")
            print(run.stderr[-3000:] if run.stderr else run.stdout[-3000:])
            return 1

        bench = parse_bench_output(run.stdout)
        if bench is None:
            print("[bench] no [BENCH] output found in kernel stdout")
            print(run.stdout[-2000:])
            return 1

        max_cycles = bench["max_cycles"]
        time_us = max_cycles / spe_clock_mhz
        time_ms = time_us / 1000

        report = {
            "op": op,
            "spe_clock_mhz": spe_clock_mhz,
            "max_cycles": max_cycles,
            "max_spe": bench["max_spe"],
            "time_us": round(time_us, 2),
            "time_ms": round(time_ms, 3),
        }

        if args.json:
            print(json.dumps(report, indent=2))
        else:
            print(f"\n{'='*50}")
            print(f"  op           : {op}")
            print(f"  spe_clock    : {spe_clock_mhz:.0f} MHz")
            print(f"  max_cycles   : {max_cycles} (SPE {bench['max_spe']})")
            print(f"  time         : {time_us:.2f} us ({time_ms:.3f} ms)")
            print(f"{'='*50}")

        return 0

    except Exception as exc:
        print(f"[bench] error: {exc}", file=sys.stderr)
        import traceback; traceback.print_exc()
        return 1

    finally:
        restore_swcu(swcu_path, backup)
        print(f"[bench] restored {swcu_path}")


if __name__ == "__main__":
    raise SystemExit(main())
