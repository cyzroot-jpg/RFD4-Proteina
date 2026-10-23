#!/usr/bin/env python3
"""PyTorch golden reference utilities for swdnn_test_ops operators."""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import numpy as np

try:
    import torch
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyTorch is required: pip install torch") from exc


GoldenFn = Callable[[torch.Tensor, dict[str, Any]], torch.Tensor]


def torch_golden_device() -> torch.device:
    """Return the default device for PyTorch golden generation.

    TORCH_GOLDEN_DEVICE=auto prefers cuda:0 and falls back to cpu.
    Explicit values such as cpu, cuda, cuda:1 are honored.
    """
    requested = os.environ.get("TORCH_GOLDEN_DEVICE", "auto").strip().lower()
    if requested in {"", "auto"}:
        return torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
    if requested == "cuda":
        requested = "cuda:0"
    device = torch.device(requested)
    if device.type == "cuda" and not torch.cuda.is_available():
        raise RuntimeError(
            f"TORCH_GOLDEN_DEVICE={requested} requested, but torch.cuda is unavailable"
        )
    return device


def setup_torch_golden(seed: int) -> torch.device:
    device = torch_golden_device()
    torch.manual_seed(seed)
    if device.type == "cuda":
        torch.cuda.manual_seed_all(seed)
        torch.backends.cuda.matmul.allow_tf32 = False
        torch.backends.cudnn.allow_tf32 = False
    return device


@dataclass
class CompareResult:
    passed: bool
    total: int
    faults: int
    success_rate: float
    max_abs_err: float
    max_rel_err: float
    atol: float
    rtol: float
    worst_index: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "total": self.total,
            "faults": self.faults,
            "success_rate": self.success_rate,
            "max_abs_err": self.max_abs_err,
            "max_rel_err": self.max_rel_err,
            "atol": self.atol,
            "rtol": self.rtol,
            "worst_index": self.worst_index,
        }


def data_dir(build_dir: Path, op: str) -> Path:
    return build_dir / "torch_golden" / op


def meta_path(data: Path) -> Path:
    return data / "meta.json"


def save_meta(data: Path, meta: dict[str, Any]) -> None:
    data.mkdir(parents=True, exist_ok=True)
    meta_path(data).write_text(json.dumps(meta, indent=2), encoding="utf-8")


def load_meta(data: Path) -> dict[str, Any]:
    return json.loads(meta_path(data).read_text(encoding="utf-8"))


def save_tensor_f32(path: Path, tensor: torch.Tensor) -> None:
    arr = tensor.detach().cpu().to(torch.float32).contiguous().numpy()
    path.parent.mkdir(parents=True, exist_ok=True)
    arr.tofile(path)


def save_tensor_f16(path: Path, tensor: torch.Tensor) -> None:
    arr = tensor.detach().cpu().to(torch.float16).contiguous().numpy()
    path.parent.mkdir(parents=True, exist_ok=True)
    np.asarray(arr, dtype=np.float16).tofile(path)


def load_tensor_f32(path: Path, numel: int) -> torch.Tensor:
    arr = np.fromfile(path, dtype=np.float32, count=numel)
    if arr.size != numel:
        raise RuntimeError(f"{path}: expected {numel} floats, got {arr.size}")
    return torch.from_numpy(arr.copy())


def load_tensor_f16(path: Path, numel: int) -> torch.Tensor:
    arr = np.fromfile(path, dtype=np.float16, count=numel)
    if arr.size != numel:
        raise RuntimeError(f"{path}: expected {numel} half values, got {arr.size}")
    return torch.from_numpy(arr.copy()).to(torch.float16)


def compare_tensors(
    actual: torch.Tensor,
    expected: torch.Tensor,
    *,
    atol: float,
    rtol: float,
) -> CompareResult:
    a = actual.detach().cpu().to(torch.float32).reshape(-1)
    e = expected.detach().cpu().to(torch.float32).reshape(-1)
    if a.numel() != e.numel():
        raise ValueError(f"shape mismatch: actual {a.numel()} vs expected {e.numel()}")

    diff = (a - e).abs()
    denom = e.abs().clamp_min(1e-12)
    rel = diff / denom
    bad = (diff > atol) & (rel > rtol)
    faults = int(bad.sum().item())
    total = int(a.numel())
    success_rate = 0.0 if total == 0 else (total - faults) / total
    worst_index = int(diff.argmax().item()) if total else None
    max_abs = float(diff.max().item()) if total else 0.0
    max_rel = float(rel.max().item()) if total else 0.0
    return CompareResult(
        passed=faults == 0,
        total=total,
        faults=faults,
        success_rate=success_rate,
        max_abs_err=max_abs,
        max_rel_err=max_rel,
        atol=atol,
        rtol=rtol,
        worst_index=worst_index,
    )


def golden_elewise_affine(x: torch.Tensor, meta: dict[str, Any]) -> torch.Tensor:
    alpha = float(meta["alpha"])
    beta = float(meta["beta"])
    return x * alpha + beta


def golden_reduce_stub(x: torch.Tensor, meta: dict[str, Any]) -> torch.Tensor:
    """Placeholder: replace in per-op script with torch op matching device semantics."""
    rows = int(meta["rows"])
    cols = int(meta["cols"])
    view = x.view(rows, cols)
    return view.reshape(-1)


def default_golden(family: str) -> GoldenFn:
    if family == "elewise":
        return golden_elewise_affine
    return golden_reduce_stub


def prepare_case(
    *,
    op: str,
    family: str,
    build_dir: Path,
    meta: dict[str, Any],
    seed: int,
    golden_fn: GoldenFn | None = None,
) -> Path:
    device = setup_torch_golden(seed)
    out = data_dir(build_dir, op)
    out.mkdir(parents=True, exist_ok=True)

    numel = int(meta["numel"])
    low = float(meta.get("rand_low", -1.0))
    high = float(meta.get("rand_high", 1.0))
    x = torch.empty(numel, dtype=torch.float32, device=device).uniform_(low, high)

    fn = golden_fn or default_golden(family)
    y_ref = fn(x, meta)

    save_tensor_f32(out / "x.bin", x)
    save_tensor_f32(out / "ref.bin", y_ref)
    save_meta(
        out,
        {
            **meta,
            "op": op,
            "family": family,
            "seed": seed,
            "dtype": "float32",
            "torch_device": str(device),
        },
    )
    return out


def compare_case(
    *,
    build_dir: Path,
    op: str,
    family: str,
    golden_fn: GoldenFn | None = None,
    atol: float | None = None,
    rtol: float | None = None,
) -> CompareResult:
    out = data_dir(build_dir, op)
    meta = load_meta(out)
    numel = int(meta["numel"])
    x = load_tensor_f32(out / "x.bin", numel)
    device_path = out / "device_out.bin"
    if not device_path.is_file():
        raise FileNotFoundError(f"missing device output: {device_path} (run device test with SDAA_TORCH_DATA_DIR)")

    y_dev = load_tensor_f32(device_path, numel)
    fn = golden_fn or default_golden(family)
    y_ref = fn(x, meta)

    if atol is None:
        atol = float(meta.get("atol", 1e-5))
    if rtol is None:
        rtol = float(meta.get("rtol", 1e-4 if family == "elewise" else 3e-2))

    result = compare_tensors(y_dev, y_ref, atol=atol, rtol=rtol)
    if not result.passed and result.worst_index is not None:
        i = result.worst_index
        print(
            f"[torch] worst index {i}: device={y_dev.reshape(-1)[i].item():.6g} "
            f"ref={y_ref.reshape(-1)[i].item():.6g}"
        )
    print(
        f"[torch] {op} success rate {result.success_rate:.4f}, "
        f"faultNum {result.faults}, max_abs={result.max_abs_err:.6g}, max_rel={result.max_rel_err:.6g}"
    )
    return result


NormGoldenFn = Callable[[torch.Tensor, torch.Tensor, float], tuple[torch.Tensor, torch.Tensor]]


def prepare_norm_fp16_case(
    *,
    op: str,
    build_dir: Path,
    meta: dict[str, Any],
    seed: int,
    golden_fn: NormGoldenFn,
) -> Path:
    device = setup_torch_golden(seed)
    out = data_dir(build_dir, op)
    out.mkdir(parents=True, exist_ok=True)

    rows = int(meta["rows"])
    cols = int(meta["cols"])
    eps = float(meta.get("eps", 1e-5))
    low = float(meta.get("rand_low", -0.8))
    high = float(meta.get("rand_high", 0.8))
    w_low = float(meta.get("weight_low", 0.5))
    w_high = float(meta.get("weight_high", 1.5))

    x = torch.empty((rows, cols), dtype=torch.float32, device=device).uniform_(low, high)
    w = torch.empty((cols,), dtype=torch.float32, device=device).uniform_(w_low, w_high)
    x_half = x.to(torch.float16).contiguous()
    w_half = w.to(torch.float16).contiguous()
    y_ref, inv_rms_ref = golden_fn(x_half, w_half, eps)

    save_tensor_f16(out / "x.bin", x_half)
    save_tensor_f16(out / "w.bin", w_half)
    save_tensor_f32(out / "ref.bin", y_ref)
    save_tensor_f32(out / "ref_inv_rms.bin", inv_rms_ref)
    save_meta(
        out,
        {
            **meta,
            "op": op,
            "family": "norm",
            "seed": seed,
            "dtype": "float16_io_fp32_acc",
            "torch_device": str(device),
        },
    )
    return out


def compare_norm_fp16_case(
    *,
    build_dir: Path,
    op: str,
    meta: dict[str, Any] | None = None,
) -> dict[str, Any]:
    out = data_dir(build_dir, op)
    stored = load_meta(out)
    m = {**stored, **(meta or {})}
    numel = int(m["numel"])
    rows = int(m["rows"])

    y_dev = load_tensor_f32(out / "device_out.bin", numel)
    y_ref = load_tensor_f32(out / "ref.bin", numel)
    inv_dev = load_tensor_f32(out / "device_inv_rms.bin", rows)
    inv_ref = load_tensor_f32(out / "ref_inv_rms.bin", rows)

    y_result = compare_tensors(
        y_dev,
        y_ref,
        atol=float(m.get("atol", 3e-3)),
        rtol=float(m.get("rtol", 2e-2)),
    )
    inv_result = compare_tensors(
        inv_dev,
        inv_ref,
        atol=float(m.get("inv_atol", 5e-4)),
        rtol=float(m.get("inv_rtol", 5e-3)),
    )
    passed = y_result.passed and inv_result.passed
    return {
        "passed": passed,
        "y": y_result.to_dict(),
        "inv_rms": inv_result.to_dict(),
        "success_rate": min(y_result.success_rate, inv_result.success_rate),
    }
