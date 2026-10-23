"""Lightweight inference resource instrumentation.

Records wall time, throughput, device memory and CPU usage without changing any
generation/evaluation behaviour. Works on CPU, CUDA and Teco SDAA (where the
CUDA -> SDAA migration makes ``torch.cuda`` resolve to the SDAA backend).

The callback writes, next to the run's other metrics:
  * ``<out_dir>/inference_metrics/resource_usage.json`` -- run-level summary
  * ``<out_dir>/inference_metrics/resource_usage_batches.csv`` -- per-batch rows
and the recorder used by non-Trainer scripts writes
``<out_dir>/evaluation_metrics/resource_usage.json`` with the same summary shape.
"""

from __future__ import annotations

import csv
import json
import os
import resource
import time
from pathlib import Path
from typing import Any

import torch

try:  # Lightning is optional for the standalone recorder.
    import lightning as L
except ImportError:  # pragma: no cover
    L = None


def _device_module():
    """Return the CUDA-like module for the active device (sdaa after migration)."""
    return torch.cuda


def _device_available() -> bool:
    try:
        return torch.cuda.is_available()
    except Exception:
        return False


def _reset_peak_memory() -> None:
    if _device_available():
        try:
            _device_module().reset_peak_memory_stats()
        except Exception:
            pass


def _peak_memory_bytes() -> int | None:
    if not _device_available():
        return None
    try:
        return int(_device_module().max_memory_allocated())
    except Exception:
        return None


def _reserved_memory_bytes() -> int | None:
    if not _device_available():
        return None
    try:
        return int(_device_module().memory_reserved())
    except Exception:
        return None


def _cpu_times() -> tuple[float, float]:
    """Return (process CPU seconds, wall seconds)."""
    usage = resource.getrusage(resource.RUSAGE_SELF)
    cpu_seconds = usage.ru_utime + usage.ru_stime
    return cpu_seconds, time.perf_counter()


def _max_rss_bytes() -> int:
    # ru_maxrss is KiB on Linux.
    return int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss) * 1024


def _cpu_utilization(cpu_seconds: float, wall_seconds: float) -> float | None:
    if wall_seconds <= 0:
        return None
    ncpu = os.cpu_count() or 1
    return 100.0 * cpu_seconds / wall_seconds / ncpu


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")


def _sync_if_available() -> None:
    if _device_available():
        try:
            _device_module().synchronize()
        except Exception:
            pass


class ResourceUsageRecorder:
    """Measure a single inference/evaluation call (non-Lightning entry points)."""

    def __init__(self, out_dir: str | Path, *, name: str = "resource_usage"):
        self.out_dir = Path(out_dir)
        self.name = name
        self._start_wall = 0.0
        self._start_cpu = 0.0
        self._n_examples = 0

    def __enter__(self) -> "ResourceUsageRecorder":
        _sync_if_available()
        _reset_peak_memory()
        self._start_cpu, self._start_wall = _cpu_times()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        _sync_if_available()
        end_cpu, end_wall = _cpu_times()
        wall = end_wall - self._start_wall
        cpu = end_cpu - self._start_cpu
        payload = {
            "status": "ok" if exc_type is None else f"error: {exc_type.__name__}",
            "wall_time_s": wall,
            "cpu_time_s": cpu,
            "cpu_utilization_percent": _cpu_utilization(cpu, wall),
            "process_max_rss_bytes": _max_rss_bytes(),
            "device_peak_memory_bytes": _peak_memory_bytes(),
            "device_reserved_memory_bytes": _reserved_memory_bytes(),
            "num_examples": self._n_examples or None,
        }
        if self._n_examples:
            payload["examples_per_second"] = self._n_examples / wall if wall > 0 else None
        _write_json(self.out_dir / f"{self.name}.json", payload)

    def set_num_examples(self, n: int) -> None:
        self._n_examples = int(n)


class ResourceMonitorCallback(L.Callback if L is not None else object):
    """Lightning callback recording the same metrics for generation validation."""

    def __init__(self, *, output_dir: str | Path | None = None, flush_every: int = 25):
        super().__init__()
        self.output_dir = Path(output_dir) if output_dir is not None else None
        self.flush_every = flush_every
        self._rows: list[dict[str, Any]] = []
        self._epoch_start_wall = 0.0
        self._epoch_start_cpu = 0.0
        self._batch_start_wall = 0.0
        self._batch_start_cpu = 0.0
        self._num_batches = 0
        self._num_examples = 0
        self._metrics_dir: Path | None = None

    def _resolve_metrics_dir(self, trainer) -> Path:
        if self.output_dir is not None:
            return self.output_dir / "inference_metrics"
        return Path(trainer.default_root_dir) / "inference_metrics"

    def on_validation_epoch_start(self, trainer, pl_module) -> None:
        _sync_if_available()
        _reset_peak_memory()
        self._metrics_dir = self._resolve_metrics_dir(trainer)
        self._rows = []
        self._num_batches = 0
        self._num_examples = 0
        self._epoch_start_cpu, self._epoch_start_wall = _cpu_times()

    def on_validation_batch_start(self, trainer, pl_module, batch, batch_idx, dataloader_idx=0) -> None:
        self._batch_start_cpu, self._batch_start_wall = _cpu_times()

    def on_validation_batch_end(self, trainer, pl_module, outputs, batch, batch_idx, dataloader_idx=0) -> None:
        _sync_if_available()
        now_cpu, now_wall = _cpu_times()
        batch_wall = now_wall - self._batch_start_wall
        batch_cpu = now_cpu - self._batch_start_cpu
        n = 1
        if isinstance(batch, dict):
            for value in batch.values():
                if torch.is_tensor(value) and value.ndim >= 1:
                    n = int(value.shape[0])
                    break
        self._num_batches += 1
        self._num_examples += n
        self._rows.append(
            {
                "batch_idx": int(batch_idx),
                "batch_wall_time_s": batch_wall,
                "batch_cpu_time_s": batch_cpu,
                "batch_cpu_utilization_percent": _cpu_utilization(batch_cpu, batch_wall),
                "device_peak_memory_bytes": _peak_memory_bytes(),
                "device_reserved_memory_bytes": _reserved_memory_bytes(),
                "num_examples": n,
            }
        )
        if trainer.is_global_zero and self._metrics_dir is not None and len(self._rows) % self.flush_every == 0:
            self._flush_rows()

    def _flush_rows(self) -> None:
        if self._metrics_dir is None or not self._rows:
            return
        path = self._metrics_dir / "resource_usage_batches.csv"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(self._rows[0]))
            writer.writeheader()
            writer.writerows(self._rows)

    def on_validation_epoch_end(self, trainer, pl_module) -> None:
        _sync_if_available()
        end_cpu, end_wall = _cpu_times()
        wall = end_wall - self._epoch_start_wall
        cpu = end_cpu - self._epoch_start_cpu
        if not trainer.is_global_zero or self._metrics_dir is None:
            return
        self._flush_rows()
        payload = {
            "status": "ok",
            "wall_time_s": wall,
            "cpu_time_s": cpu,
            "cpu_utilization_percent": _cpu_utilization(cpu, wall),
            "process_max_rss_bytes": _max_rss_bytes(),
            "device_peak_memory_bytes": _peak_memory_bytes(),
            "device_reserved_memory_bytes": _reserved_memory_bytes(),
            "num_batches": self._num_batches,
            "num_examples": self._num_examples,
            "examples_per_second": self._num_examples / wall if wall > 0 else None,
            "batches_per_second": self._num_batches / wall if wall > 0 else None,
        }
        _write_json(self._metrics_dir / "resource_usage.json", payload)