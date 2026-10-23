#!/usr/bin/env python3
"""Interactive operator requirement collection — produces requirement.json."""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT.parents[1] / "teco-ops"

OP_RE = re.compile(r"^[a-z][a-z0-9_]*$")
VALID_COMPUTATION_TYPES = {"elementwise", "reduction", "normalization", "matmul", "custom"}
VALID_DTYPES = {"float16", "float32", "bfloat16", "int8", "int32"}

SHAPE_DEFAULTS: dict[str, dict[str, Any]] = {
    "elementwise": {
        "keys": ["N", "H", "W", "C"],
        "meanings": {"N": "batch", "H": "rows", "W": "cols", "C": "channels"},
        "smoke": {"N": 8192, "H": 2, "W": 2, "C": 1024},
        "default": {"N": 4096, "H": 2, "W": 2, "C": 1024},
    },
    "matmul": {
        "keys": ["M", "N", "K"],
        "meanings": {"M": "rows of A / rows of C", "N": "cols of B / cols of C", "K": "inner dim"},
        "smoke": {"M": 64, "N": 32, "K": 128},
        "default": {"M": 512, "N": 256, "K": 8192},
    },
    "normalization": {
        "keys": ["N", "H", "W", "C"],
        "meanings": {"N": "batch", "H": "rows", "W": "cols", "C": "hidden dim"},
        "smoke": {"N": 4, "H": 4, "W": 8, "C": 8192},
        "default": {"N": 8, "H": 8, "W": 16, "C": 8192},
    },
}

GOLDEN_DEFAULTS: dict[str, dict[str, Any]] = {
    "normalization": {"atol": 0.003, "rtol": 0.02},
    "matmul": {"atol": 0.5, "rtol": 0.02},
    "default": {"atol": 1e-5, "rtol": 0.03},
}


def _prompt(prompt_text: str, default: str = "") -> str:
    if default:
        prompt_text = f"{prompt_text} [{default}]"
    return input(f"{prompt_text}: ").strip() or default


def _prompt_int(prompt_text: str, default: int | None = None) -> int:
    d = str(default) if default is not None else ""
    while True:
        val = _prompt(prompt_text, d)
        try:
            return int(val)
        except ValueError:
            print(f"  Please enter an integer, got: {val}")


def _prompt_choice(prompt_text: str, choices: list[str], default: str = "") -> str:
    while True:
        val = _prompt(prompt_text, default)
        if val in choices:
            return val
        print(f"  Please choose from: {', '.join(choices)}")


def _prompt_float(prompt_text: str, default: float | None = None) -> float:
    d = str(default) if default is not None else ""
    while True:
        val = _prompt(prompt_text, d)
        try:
            return float(val)
        except ValueError:
            print(f"  Please enter a number, got: {val}")


def _prompt_yn(prompt_text: str, default: bool = True) -> bool:
    yn = "Y/n" if default else "y/N"
    val = _prompt(f"{prompt_text} ({yn})", "Y" if default else "N")
    return val.lower() in ("y", "yes")


def collect_interactive(op: str) -> dict[str, Any]:
    """Interactive Q&A to collect operator requirements."""
    print("=" * 60)
    print("SDAA Operator Requirement Collection")
    print("=" * 60)
    print()

    # 1. OP name
    op = _prompt("Operator name (snake_case)", op)
    while not OP_RE.match(op):
        print(f"  Invalid op name '{op}': use snake_case [a-z][a-z0-9_]*")
        op = _prompt("Operator name (snake_case)")
    print()

    # 2. Computation type
    ctype_list = sorted(VALID_COMPUTATION_TYPES)
    ctype = _prompt_choice(f"Computation type ({'/'.join(ctype_list)})", ctype_list, "matmul")
    print()

    # 3. Shape keys
    defaults = SHAPE_DEFAULTS.get(ctype, {"keys": ["N", "H", "W", "C"]})
    default_keys_str = ",".join(defaults["keys"])
    keys_str = _prompt(f"Shape dimension keys (comma-separated)", default_keys_str)
    shape_keys = [k.strip() for k in keys_str.split(",") if k.strip()]
    print()

    # 4. Shape meanings
    shape_meanings: dict[str, str] = {}
    default_meanings = defaults.get("meanings", {})
    print("Shape key meanings (press Enter to accept default):")
    for key in shape_keys:
        meaning = _prompt(f"  {key}", default_meanings.get(key, ""))
        shape_meanings[key] = meaning or key
    print()

    # 5. Shapes (smoke + default)
    default_smoke = defaults.get("smoke", {})
    default_shapes = defaults.get("default", {})
    print("Smoke test shapes (small, for quick validation):")
    smoke = {}
    for key in shape_keys:
        smoke[key] = _prompt_int(f"  {key}", default_smoke.get(key, 2))
    print()
    print("Default shapes (production size):")
    prod = {}
    for key in shape_keys:
        prod[key] = _prompt_int(f"  {key}", default_shapes.get(key, 2))
    print()

    # 6. Dtypes
    dtype_list = sorted(VALID_DTYPES)
    dtype_io = _prompt_choice(f"Input dtype ({'/'.join(dtype_list)})", dtype_list, "float16")
    dtype_acc = _prompt_choice(f"Accumulation dtype ({'/'.join(dtype_list)})", dtype_list, "float32")
    print()

    # 7. Description
    description = _prompt("Function description", "Matrix multiply C = A * B")
    print()

    # 8. Formula
    formula = _prompt("Math formula", "C[i][j] = sum_k(A[i][k] * B[k][j])")
    print()

    # 9. IO tensors
    print("IO tensors (empty name to finish):")
    io_tensors: list[dict[str, Any]] = []
    while True:
        name = _prompt("  Tensor name (empty to finish)")
        if not name:
            break
        tensor_dtype = _prompt_choice(
            f"  {name} dtype ({'/'.join(dtype_list)})", dtype_list, dtype_io
        )
        shape_str = _prompt(f"  {name} shape (comma-separated keys, e.g. M,K)", ",".join(shape_keys))
        shape = [s.strip() for s in shape_str.split(",") if s.strip()]
        desc = _prompt(f"  {name} description", name)
        io_tensors.append({"name": name, "dtype": tensor_dtype, "shape": shape, "desc": desc})
        print()
    print()

    # 10. Golden
    gold_defaults = GOLDEN_DEFAULTS.get(ctype, GOLDEN_DEFAULTS["default"])
    print("Golden tolerance (for teco-ops C++ correctness reference):")
    atol = _prompt_float("  atol", gold_defaults["atol"])
    rtol = _prompt_float("  rtol", gold_defaults["rtol"])
    print()

    return {
        "schema_version": "1.0",
        "op": op,
        "computation_type": ctype,
        "description": description,
        "formula": formula,
        "shape_keys": shape_keys,
        "shape_meanings": shape_meanings,
        "shapes": {"smoke": smoke, "default": prod},
        "dtype_io": dtype_io,
        "dtype_acc": dtype_acc,
        "io_tensors": io_tensors,
        "golden": {"framework": "pytorch", "atol": atol, "rtol": rtol},
    }


def load_from_json(path: Path) -> dict[str, Any]:
    """Load requirement from a JSON file (non-interactive)."""
    req = json.loads(path.read_text(encoding="utf-8"))
    required = {"op", "computation_type", "shape_keys", "shapes", "dtype_io", "dtype_acc"}
    missing = required - set(req.keys())
    if missing:
        raise SystemExit(f"Missing required fields in {path}: {missing}")
    req.setdefault("schema_version", "1.0")
    req.setdefault("description", "")
    req.setdefault("formula", "")
    req.setdefault("shape_meanings", {})
    req.setdefault("io_tensors", [])
    req.setdefault("golden", {"framework": "pytorch", "atol": 1e-5, "rtol": 0.03})
    return req


def write_requirement(req: dict[str, Any], demo_root: Path) -> Path:
    """Write requirement.json to the standard location."""
    op = req["op"]
    req_dir = demo_root / "op_requirements" / op
    req_dir.mkdir(parents=True, exist_ok=True)
    req.setdefault("created_at", date.today().isoformat())
    out_path = req_dir / "requirement.json"
    out_path.write_text(json.dumps(req, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Interactive operator requirement collection"
    )
    parser.add_argument("--op", default="", help="Operator name (snake_case)")
    parser.add_argument(
        "--from-json",
        default="",
        help="Import from JSON file (non-interactive mode)",
    )
    parser.add_argument(
        "--demo-root",
        default=str(DEFAULT_DEMO_ROOT),
        help="Demo root directory",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON to stdout")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate only, do not write files",
    )
    args = parser.parse_args()

    demo_root = Path(args.demo_root).expanduser().resolve()

    if args.from_json:
        req_path = Path(args.from_json)
        if not req_path.is_file():
            print(f"error: {req_path} not found", file=sys.stderr)
            return 1
        req = load_from_json(req_path)
    else:
        req = collect_interactive(args.op)

    if args.dry_run:
        print(json.dumps(req, ensure_ascii=False, indent=2))
        return 0

    out_path = write_requirement(req, demo_root)
    print(f"Wrote {out_path}")
    print()
    print("Next step:")
    print(
        f"  python3 ops/sdaa-op-design/scripts/init_design.py "
        f"--op {req['op']} --computation-type {req['computation_type']} "
        f"--from-requirement"
    )

    if args.json:
        print(json.dumps({"status": "ok", "path": str(out_path)}, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
