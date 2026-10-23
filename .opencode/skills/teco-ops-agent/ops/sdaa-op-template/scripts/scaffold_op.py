#!/usr/bin/env python3
"""Scaffold swdnn_test_ops operator from op_template.swcu (single-file layout)."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parents[1]
DEFAULT_DEMO_ROOT = REPO_ROOT / "swdnn_test_ops"

OP_RE = re.compile(r"^[a-z][a-z0-9_]*$")
PLACEHOLDER_RE = re.compile(r"<op_name>")


def validate_op(op: str) -> None:
    if not OP_RE.match(op):
        raise SystemExit(f"invalid --op '{op}': use snake_case [a-z][a-z0-9_]*")


def load_design_shapes(demo_root: Path, op: str) -> dict | None:
    """Try to load design.json for shape info, return None if not found."""
    design_path = demo_root / "op_design" / op / "design.json"
    if not design_path.is_file():
        return None
    try:
        doc = json.loads(design_path.read_text(encoding="utf-8"))
        params = doc.get("parameters", {})
        shapes = params.get("shapes", {})
        io_tensors = doc.get("operator_definition", {}).get("io_tensors", [])
        return {
            "shapes": shapes,
            "dtype_io": params.get("dtype_io", "float32"),
            "dtype_acc": params.get("dtype_acc", "float32"),
            "io_tensors": io_tensors,
            "golden": doc.get("golden", {}),
            "op": doc["op"],
        }
    except (json.JSONDecodeError, KeyError):
        return None


def render_swcu(template_path: Path, op: str) -> str:
    """Replace <op_name> placeholders in template."""
    text = template_path.read_text(encoding="utf-8")
    text = PLACEHOLDER_RE.sub(op, text)
    return text


def runsh_snippet(op: str) -> str:
    test_func = f"{op}_test_kernel"
    return f"""    {op})
        TEST_FUNC="{test_func}"
        TEST_BIN="{op}"
        ;;"""


def patch_runsh(runsh: Path, op: str, dry_run: bool) -> bool:
    text = runsh.read_text(encoding="utf-8")
    if f'TEST_BIN="{op}"' in text or f"\n    {op})" in text:
        return False

    # New run.sh auto-detects .swcu files — no patch needed
    if "auto-detected from src/" in text:
        return False

    # Legacy run.sh with case statement
    case_block = runsh_snippet(op)
    marker = "    *)"
    if marker not in text:
        raise SystemExit(f"cannot find case default marker in {runsh}")
    if case_block.strip() not in text:
        text = text.replace(marker, case_block + "\n" + marker, 1)

    if dry_run:
        print(f"[dry-run] would patch {runsh}")
    else:
        runsh.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scaffold swdnn_test_ops operator from op_template.swcu"
    )
    parser.add_argument("--op", required=True, help="Operator name (snake_case)")
    parser.add_argument("--from-design", action="store_true",
                        help="Load design.json for shape info")
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT),
                        help="swdnn_test_ops root")
    parser.add_argument("--patch-runsh", action="store_true",
                        help="Insert run.sh case for the op")
    parser.add_argument("--template", default="",
                        help="Path to template .swcu.tpl (default: ops/sdaa-op-template/templates/op_template.swcu.tpl)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print actions without writing files")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite existing files")
    parser.add_argument("--json", action="store_true",
                        help="Emit JSON summary on stdout")
    args = parser.parse_args()

    validate_op(args.op)
    demo_root = Path(args.demo_root).expanduser().resolve()
    if not demo_root.is_dir():
        raise SystemExit(
            f"demo root not found: {demo_root} "
            f"(run: git submodule update --init --recursive swdnn_test_ops)"
        )

    template_path = Path(args.template) if args.template else (SKILL_DIR / "templates" / "op_template.swcu.tpl")
    if not template_path.is_file():
        raise SystemExit(f"template not found: {template_path}")

    # Optional: load design for shape info
    design_info = None
    if args.from_design:
        design_info = load_design_shapes(demo_root, args.op)
        if design_info is None:
            print(f"Warning: no design.json found for {args.op}, using template defaults",
                  file=sys.stderr)

    # Render and write .swcu
    content = render_swcu(template_path, args.op)
    op_dir = demo_root / "src" / args.op
    swcu_path = op_dir / f"{args.op}.swcu"

    if swcu_path.exists() and not args.force:
        raise SystemExit(f"refusing to overwrite existing file: {swcu_path} (use --force)")
    if args.dry_run:
        print(f"[dry-run] would write {swcu_path} ({len(content)} bytes)")
    else:
        op_dir.mkdir(parents=True, exist_ok=True)
        swcu_path.write_text(content, encoding="utf-8")
        print(f"wrote {swcu_path}")

    # Patch run.sh
    patched = False
    if args.patch_runsh:
        runsh = demo_root / "run.sh"
        if not runsh.is_file():
            raise SystemExit(f"run.sh not found: {runsh}")
        patched = patch_runsh(runsh, args.op, args.dry_run)

    report = {
        "op": args.op,
        "swcu": str(swcu_path),
        "test_kernel": f"{args.op}_test_kernel",
        "kernel_symbol": f"teco_slave_{args.op}",
        "runsh_test_bin": args.op,
        "runsh_patched": patched,
        "design_loaded": design_info is not None,
        "next_step": (
            f"python3 {SCRIPT_DIR / 'torch_verify.py'} --op {args.op} "
            f"--demo-root {demo_root} --scope-cmake --restore-cmake"
        ),
    }

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("\nNaming contract:")
        for k in ("kernel_symbol", "test_kernel", "runsh_test_bin"):
            print(f"  {k}: {report[k]}")
        print(f"\nNext: {report['next_step']}")
        if not args.patch_runsh:
            print("Tip: add --patch-runsh to update run.sh automatically")
        if design_info:
            shapes = design_info.get("shapes", {})
            print(f"Design shapes: {shapes}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())