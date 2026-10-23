"""Backend profiles for multi-backend learning validation.

Each profile defines how the learning-validation scripts interpret
stage_result evidence, validation pass criteria, and API vocabulary.
This lets the same methodology (attempt loop, pattern extraction,
learned-patterns gate) work across different SDKs and build systems.

A backend profile defines:

- ``default_demo_root``: where ``op_learning/`` lives by default.
- ``stage_result_path_re``: regex to find stage_result JSON references
  inside learned-pattern markdown files.
- ``acceptance_text``: pass-criteria strings injected into
  ``learning_task.md`` templates (smoke / mid / target stages).
- ``success_check``: how to prove correctness from a stage_result JSON.
- ``delivery_check``: how to prove delivery / pipeline pass.
- ``benchmark_keywords``: substrings in the ``commands`` blob that
  indicate a benchmark was run.
- ``perf_time_fields`` / ``perf_throughput_fields``: JSON field names
  used for performance comparison.
- ``extraction_vocab``: API vocabulary for pattern-extraction checklist.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parents[1]
CONFIG_PATH = REPO_ROOT / "configs" / "backend_config.json"
LOCAL_CONFIG_PATH = REPO_ROOT / "configs" / "backend_config.local.json"

BACKENDS: dict[str, dict[str, Any]] = {
    "teco_ops": {
        "description": (
            "interface + UAL operator development in teco-ops. "
            "Device kernels live under teco/ual/kernel and tests live under "
            "test/zoo/teco. Validation uses teco-ops' C++ test framework "
            "via test/build/demo with prototxt case files."
        ),
        "default_demo_root": "../../teco-ops",
        "stage_result_path_re": (
            r"teco-ops/op_learning/[^\s`)'\"]+"
            r"/stage_results/[A-Za-z0-9_.-]+\.json"
        ),
        "acceptance_text": {
            "smoke": [
                "`bash build.sh --build teco` completes in teco-ops.",
                "`test/build/demo` returns 0 for the target prototxt case.",
            ],
            "mid": [
                "C++ test framework correctness pass for the target prototxt case.",
                "Operator library and test binary both build for TECO.",
            ],
            "target": [
                "C++ test framework correctness pass for the target prototxt case.",
                "`test/build/demo` runs with perf_repeat/warm_repeat and records performance output.",
            ],
        },
        "success_check": "teco_ops_demo",
        "success_field_paths": [
            ("correctness", "passed"),
            ("accuracy", "passed"),
        ],
        "success_required_value": True,
        "delivery_check": "teco_ops_layout",
        "delivery_field_paths": [("delivery", "delivery_status")],
        "delivery_pass_value": "pass",
        "delivery_command_keywords": ["test/build/demo", "case_path", "returncode"],
        "benchmark_keywords": ["perf_repeat", "warm_repeat", "test/build/demo"],
        "perf_time_fields": ("time_ms", "time_us", "cost_ms", "latency_ms"),
        "perf_throughput_fields": ("tflops", "gbps", "throughput"),
        "extraction_vocab": {
            "dma": ["rt_dma_iget", "rt_dma_iput", "rt_dma_wait_value"],
            "rma": ["rt_rma_put", "rt_rma_iput", "rt_rma_iget"],
            "ace": [
                "rt_ace_config_kernel",
                "rt_ace_load_north",
                "rt_ace_load_west",
                "rt_ace_cal",
                "rt_ace_write",
                "rt_ace_writeback",
            ],
            "simd": ["SIMD_LOAD", "SIMD_STORE", "simd_load", "simd_store"],
            "sync": ["rt_synchronized_array", "rt_synchronize"],
            "ual": ["RUN_OP", "BaseOp", "findImpl", "RUN_KERNEL"],
            "test": ["TecoExecutor", "cpuCompute", "compute", "prototxt"],
        },
    },
    "swdnn_test_ops": {
        "description": (
            "rt-based op development in swdnn_test_ops. "
            "Device kernels use rt_dma_*, rt_rma_*, rt_ace_* directly. "
            "Validation via torch_verify.py (L3 accuracy) + check_delivery.py."
        ),
        "default_demo_root": "swdnn_test_ops",
        "stage_result_path_re": (
            r"swdnn_test_ops/op_learning/[^\s`)'\"]+"
            r"/stage_results/[A-Za-z0-9_.-]+\.json"
        ),
        "acceptance_text": {
            "smoke": [
                "`torch_verify.py` reports `success_rate == 1.0`.",
                "`check_delivery.py --json` reports `delivery_status == pass`.",
            ],
            "mid": [
                "L3 precision pass (`success_rate == 1.0`).",
                "Delivery check pass (`delivery_status == pass`).",
            ],
            "target": [
                "L3 precision pass (`success_rate == 1.0`).",
                "Delivery check pass (`delivery_status == pass`).",
                "`kernel-bench` outputs device time and derived throughput.",
            ],
        },
        "success_check": "success_rate",
        "success_field_paths": [
            ("correctness", "success_rate"),
            ("accuracy", "success_rate"),
        ],
        "success_required_value": 1.0,
        "delivery_check": "check_delivery",
        "delivery_field_paths": [("delivery", "delivery_status")],
        "delivery_pass_value": "pass",
        "delivery_command_keywords": ["check_delivery.py", "pass"],
        "benchmark_keywords": ["bench_kernel.py", "benchmark"],
        "perf_time_fields": ("time_ms", "max_cycles", "cycles"),
        "perf_throughput_fields": ("tflops", "approx_tflops"),
        "extraction_vocab": {
            "dma": ["rt_dma_iget", "rt_dma_iput", "rt_dma_wait_value"],
            "rma": ["rt_rma_put", "rt_rma_iput", "rt_rma_iget"],
            "ace": [
                "rt_ace_config_kernel",
                "rt_ace_load_north",
                "rt_ace_load_west",
                "rt_ace_cal",
                "rt_ace_write",
                "rt_ace_writeback",
            ],
            "simd": ["SIMD_LOAD", "SIMD_STORE", "simd_load", "simd_store"],
            "sync": ["rt_synchronized_array", "rt_synchronize"],
        },
    },
}

DEFAULT_BACKEND = "teco_ops"


def _load_config_file(path: Path) -> dict[str, Any]:
    """Load one backend config file, returning its override mapping.

    The config file is optional. When present it lets users override
    ``default_demo_root`` (and future fields) per backend without editing
    source code.  Example::

        {
          "backends": {
            "swdnn_test_ops": { "demo_root": "/custom/path/to/repo" }
          }
        }

    ``demo_root`` may be absolute or relative to the repo root.
    """
    if not path.is_file():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    overrides = raw.get("backends", {})
    if not isinstance(overrides, dict):
        return {}
    return overrides


def _load_config() -> dict[str, Any]:
    """Merge tracked defaults and optional local overrides."""
    merged = _load_config_file(CONFIG_PATH)
    for backend_name, fields in _load_config_file(LOCAL_CONFIG_PATH).items():
        current = merged.setdefault(backend_name, {})
        if isinstance(current, dict) and isinstance(fields, dict):
            current.update(fields)
    return merged


def _apply_config_overrides() -> None:
    """Merge backend_config.json overrides into the BACKENDS table."""
    overrides = _load_config()
    for backend_name, fields in overrides.items():
        if backend_name not in BACKENDS or not isinstance(fields, dict):
            continue
        demo_root = fields.get("demo_root")
        if demo_root is None:
            continue
        p = Path(demo_root)
        if not p.is_absolute():
            p = REPO_ROOT / demo_root
        BACKENDS[backend_name]["default_demo_root"] = str(p)


_apply_config_overrides()


def get_backend(name: str | None, demo_root_override: str | None = None) -> dict[str, Any]:
    """Return the backend profile for *name*, falling back to default.
    """
    if name is None:
        name = DEFAULT_BACKEND
    if name not in BACKENDS:
        raise ValueError(
            f"unknown backend '{name}'; available: {', '.join(sorted(BACKENDS))}"
        )
    profile = dict(BACKENDS[name])
    if demo_root_override:
        profile["default_demo_root"] = str(
            Path(demo_root_override).expanduser().resolve()
        )

    return profile


def all_stage_result_path_res() -> list[tuple[str, str]]:
    """Return (backend_name, regex) pairs for all backends.

    Used by validators that scan markdown for stage_result references
    across potentially mixed-backend learned-patterns.
    """
    return [
        (name, profile["stage_result_path_re"])
        for name, profile in BACKENDS.items()
    ]
