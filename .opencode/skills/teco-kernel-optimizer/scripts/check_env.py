#!/usr/bin/env python3
"""Detect local SDAA / tecocc / Triton environment.

Writes a JSON snapshot consumed by later steps. Safe to run even if some
tools are missing — fields are simply null.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


def _run(cmd: list[str], timeout: int = 10) -> tuple[int, str, str]:
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            encoding="utf-8", errors="ignore",
        )
        return r.returncode, r.stdout or "", r.stderr or ""
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as e:
        return -1, "", str(e)


def _detect_sdaa_devices() -> list[dict]:
    """Probe SDAA devices via torch (preferred) and teco-smi (fallback)."""
    devices: list[dict] = []

    try:
        import torch  # noqa: F401
        # torch_sdaa registers the SDAA backend with torch
        try:
            import torch_sdaa  # noqa: F401
        except Exception:
            pass
        sdaa = getattr(torch, "sdaa", None)
        if sdaa is not None and sdaa.is_available():
            for i in range(sdaa.device_count()):
                props = sdaa.get_device_properties(i)
                devices.append({
                    "index": i,
                    "name": sdaa.get_device_name(i),
                    "total_memory_mb": getattr(props, "total_memory", 0) // (1024 * 1024),
                    "source": "torch.sdaa",
                })
    except Exception:
        pass

    if not devices:
        path = shutil.which("teco-smi")
        if path:
            rc, out, _ = _run([path], timeout=10)
            devices.append({
                "source": "teco-smi",
                "available": rc == 0,
                "raw": (out.strip()[:2000] if out else None),
            })

    if not devices:
        devices.append({"available": False, "source": None})
    return devices


def _detect_tecocc() -> dict:
    path = shutil.which("tecocc")
    if not path:
        return {"available": False, "path": None, "version": None}
    rc, out, _ = _run([path, "--version"])
    return {
        "available": True,
        "path": path,
        "version": out.strip() or None,
    }


def _detect_runtime() -> dict:
    """SDAA runtime/driver version via torch + torch_sdaa."""
    try:
        import torch
    except Exception as e:
        return {"available": False, "error": f"torch probe failed: {e}"}
    info: dict = {"available": True, "torch": torch.__version__}
    try:
        import torch_sdaa  # noqa: F401
        info["torch_sdaa"] = getattr(torch_sdaa, "__version__", "unknown")
    except Exception:
        info["torch_sdaa"] = None
    sdaa = getattr(torch, "sdaa", None)
    info["sdaa_runtime_available"] = bool(sdaa and sdaa.is_available())
    return info


def _detect_python_libs() -> dict:
    libs: dict = {}
    for name in ("torch", "triton", "torch_sdaa"):
        try:
            mod = __import__(name)
            libs[name] = {"available": True, "version": getattr(mod, "__version__", "unknown")}
        except Exception:
            libs[name] = {"available": False, "version": None}
    return libs


def collect_env() -> dict:
    devices = _detect_sdaa_devices()
    primary_name = None
    for d in devices:
        if d.get("name"):
            primary_name = d["name"]
            break
    return {
        "platform": sys.platform,
        "python": sys.version.split()[0],
        "sdaa_devices": devices,
        "primary_device": primary_name,
        "tecocc": _detect_tecocc(),
        "runtime": _detect_runtime(),
        "libs": _detect_python_libs(),
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--out", type=str, default="./env.json", help="Output JSON path")
    args = p.parse_args()

    env = collect_env()
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(env, f, indent=2, ensure_ascii=False)

    summary = {
        "device": env["primary_device"],
        "tecocc": env["tecocc"].get("version"),
        "torch": env["libs"].get("torch", {}).get("version"),
        "torch_sdaa": env["libs"].get("torch_sdaa", {}).get("version"),
        "triton": env["libs"].get("triton", {}).get("version"),
        "out": args.out,
    }
    print(json.dumps(summary, indent=2))

    if not env["libs"].get("torch_sdaa", {}).get("available"):
        print("torch_sdaa is unavailable. Activate the torch_sdaa environment with: conda activate teco-pytorch", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
