#!/usr/bin/env python3
"""Query TECO / SDAA device info via teco-smi.

Usage:
    python3 device_info.py --json
    python3 device_info.py --list
    python3 device_info.py --idle
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any


DEFAULT_SETVARS = "/opt/tecoai/setvars.sh"


def _find_setvars() -> str | None:
    for candidate in (
        os.environ.get("TECOAI_SETVARS"),
        DEFAULT_SETVARS,
        os.path.join(os.environ.get("TECOAI_ROOT", ""), "setvars.sh") or None,
        os.path.join(os.environ.get("SDAA_HOME", ""), "setvars.sh") or None,
    ):
        if candidate and os.path.isfile(candidate):
            return candidate
    return None


def _run_teco_smi_query() -> str:
    setvars = _find_setvars()
    prefix = f"source {setvars} && " if setvars else ""
    cmd = (
        f"{prefix}teco-smi "
        "--query-device=clocks.spe,clocks.max.spe,memory.total,count,name,driver_version "
        "--format=csv,noheader"
    )
    proc = subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "teco-smi query failed")
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    if not lines:
        raise RuntimeError("teco-smi returned no data")
    return lines[0]


def _parse_mhz(value: str) -> int | None:
    value = value.strip()
    if not value or value.upper() == "N/A":
        return None
    return int(value.replace("MHz", "").strip())


def _parse_mb(value: str) -> int | None:
    value = value.strip()
    if not value or value.upper() == "N/A":
        return None
    return int(value.replace("MB", "").strip())


def query_device_info() -> dict[str, Any]:
    line = _run_teco_smi_query()
    fields = [field.strip() for field in line.split(",")]
    if len(fields) < 6:
        raise RuntimeError(f"unexpected teco-smi format: {line}")

    spe_mhz = _parse_mhz(fields[0])
    spe_max_mhz = _parse_mhz(fields[1])
    mem_mb = _parse_mb(fields[2])

    return {
        "spe_clock_hz": spe_mhz * 1_000_000 if spe_mhz else None,
        "spe_clock_max_hz": spe_max_mhz * 1_000_000 if spe_max_mhz else None,
        "spe_clock_mhz": spe_mhz,
        "spe_clock_max_mhz": spe_max_mhz,
        "memory_total_mb": mem_mb,
        "device_count": int(fields[3]),
        "device_name": fields[4],
        "driver_version": fields[5],
        "arch": "UAL_TECO100",
        "chip": "T1",
    }


def query_idle_indices() -> list[int]:
    """Best-effort idle device detection for gid:auto."""
    setvars = _find_setvars()
    prefix = f"source {setvars} && " if setvars else ""
    cmd = (
        f"{prefix}teco-smi "
        "--query-gpu=index,utilization.gpu "
        "--format=csv,noheader,nounits"
    )
    proc = subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if proc.returncode != 0:
        count = query_device_info().get("device_count", 1) or 1
        return list(range(count))

    idle: list[int] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            idx = int(parts[0])
            util = float(parts[1])
        except ValueError:
            continue
        if util <= 1.0:
            idle.append(idx)
    if not idle:
        count = query_device_info().get("device_count", 1) or 1
        return list(range(count))
    return idle


def main() -> int:
    parser = argparse.ArgumentParser(description="Query TECO device info via teco-smi")
    parser.add_argument("--json", action="store_true", help="Print full device info as JSON")
    parser.add_argument("--list", action="store_true", help="Print visible device indices")
    parser.add_argument("--idle", action="store_true", help="Print idle device indices (gid:auto)")
    args = parser.parse_args()

    try:
        if args.idle:
            print(json.dumps(query_idle_indices()))
            return 0
        if args.list:
            info = query_device_info()
            count = int(info.get("device_count") or 0)
            print(json.dumps(list(range(count))))
            return 0
        info = query_device_info()
        print(json.dumps(info, ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:  # noqa: BLE001 - CLI tool
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
