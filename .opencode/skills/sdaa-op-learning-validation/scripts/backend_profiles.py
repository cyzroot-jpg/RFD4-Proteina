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
    "teco-ops": {
        "description": (
            "Teco-Ops interface + ual operator development. "
            "Validation commands are documented in "
            "skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md."
        ),
        "default_demo_root": str(REPO_ROOT / "teco-ops"),
        "stage_result_path_re": (
            r"teco-ops/op_learning/[^\s`)'\"]+"
            r"/stage_results/[A-Za-z0-9_.-]+\.json"
        ),
        "acceptance_text": {
            "smoke": [
                "`skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` 中的 Python API 精度对拍通过。",
                "对应 C++ optest 精度 case 通过。",
            ],
            "mid": [
                "`skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` 中的 Python API 精度对拍通过。",
                "相关 C++ optest 精度 case 通过。",
            ],
            "target": [
                "`skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md` 中的 Python API 精度对拍通过。",
                "C++ optest `case_0/1/2` 精度通过。",
                "C++ optest `case_0/1/2` 性能命令完成，并记录优化前后 device time。",
            ],
        },
        "success_check": "teco_ops_accuracy",
        "success_field_paths": [
            ("correctness", "python_api"),
            ("correctness", "optest"),
        ],
        "success_required_value": "pass",
        "delivery_check": "teco_ops_test_commands",
        "delivery_field_paths": [("delivery", "test_commands")],
        "delivery_pass_value": "pass",
        "delivery_command_keywords": [
            "skills/sdaa-op-learning-validation/references/demos/reshape_and_cache_test_commands.md",
            "test_reshape_and_cache.py",
            "case_0.prototxt",
        ],
        "benchmark_keywords": ["perf_repeat", "warm_repeat", "./build/demo"],
        "perf_time_fields": ("time_ms", "device_time_ms", "hardware_time_ms", "cycles"),
        "perf_throughput_fields": ("bandwidth_gbps", "effective_bandwidth_gbps"),
        "extraction_vocab": {
            "dma": ["memcpy", "sdaaMemcpy", "sdaaMemset", "HBM"],
            "rma": ["rt_rma_put", "rt_rma_iput", "rt_rma_iget"],
            "ace": ["rt_ace_config_kernel", "rt_ace_cal", "rt_ace_writeback"],
            "simd": ["SIMD_LOAD", "SIMD_STORE", "simd_load", "simd_store"],
            "sync": ["threadIdx", "CORE_NUM", "rt_synchronize"],
            "teco_ops": ["RUN_OP", "BaseOp", "tecoopsReshapeAndCache", "optest"],
        },
    },
}

DEFAULT_BACKEND = "teco-ops"


def _load_config_file(path: Path) -> dict[str, Any]:
    """Load one backend config file, returning its override mapping.

    The config file is optional. When present it lets users override
    ``default_demo_root`` (and future fields) per backend without editing
    source code.  Example::

        {
          "backends": {
            "teco-ops": { "demo_root": "/custom/path/to/repo" }
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
