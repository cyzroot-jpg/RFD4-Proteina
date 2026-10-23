#!/usr/bin/env python3
"""Initialize operator design document (schema v3) under teco-ops/op_design/."""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT.parents[1] / "teco-ops"

sys.path.insert(0, str(SCRIPT_DIR))
from op_design_lib import (  # noqa: E402
    deep_merge,
    default_design,
    design_paths,
    normalize_design,
    render_design_md,
    validate_design,
    validate_op_name,
)

README_TEXT = """# Operator design documents (schema v3)

Workflow-driven design packages:

```
op_design/<op>/
  design.json
  design.md
```

Create:

```bash
python3 ops/sdaa-op-design/scripts/init_design.py \\
  --op my_op --computation-type normalization
```

Scaffold:

```bash
Follow teco-ops interface + UAL layout and add tests under test/zoo/teco/<op>.
```
"""


def ensure_readme(demo_root: Path) -> None:
    readme = demo_root / "op_design" / "README.md"
    if not readme.is_file():
        readme.parent.mkdir(parents=True, exist_ok=True)
        readme.write_text(README_TEXT, encoding="utf-8")


def parse_patch(value: str | None) -> dict:
    if not value:
        return {}
    path = Path(value)
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    return json.loads(value)


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize operator design (workflow v3)")
    parser.add_argument("--op", required=True)
    parser.add_argument(
        "--computation-type",
        choices=("elementwise", "reduction", "normalization", "matmul", "custom"),
        default="elementwise",
    )
    parser.add_argument("--title", default="")
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--summary", default="", help="operator_definition.summary")
    parser.add_argument("--formula", default="")
    parser.add_argument("--patch", default="", help="JSON file or inline JSON merge")
    parser.add_argument("--focus", default="", help="workflow.current_focus")
    parser.add_argument(
        "--from-requirement",
        default="",
        help="Path to requirement.json or op name to load from op_requirements/<op>/requirement.json",
    )
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    validate_op_name(args.op)
    demo_root = Path(args.demo_root).expanduser().resolve()
    if not demo_root.is_dir():
        raise SystemExit(f"demo root not found: {demo_root}")

    paths = design_paths(demo_root, args.op)
    if paths.json_path.is_file() and not args.force:
        raise SystemExit(f"design exists: {paths.json_path} (use --force)")

    doc = default_design(args.op, computation_type=args.computation_type, title=args.title)
    if args.summary:
        doc["operator_definition"]["summary"] = args.summary
    if args.formula:
        doc["operator_definition"]["formula"] = args.formula
    if args.focus:
        doc["workflow"]["current_focus"] = args.focus

    patch = parse_patch(args.patch)
    if patch:
        doc = deep_merge(doc, patch)

    if args.from_requirement:
        req_path = Path(args.from_requirement)
        if not req_path.is_file():
            req_path = demo_root / "op_requirements" / args.op / "requirement.json"
        if not req_path.is_file():
            raise SystemExit(f"requirement.json not found: {args.from_requirement}")
        req = json.loads(req_path.read_text(encoding="utf-8"))
        doc["requirement_path"] = str(req_path.resolve())
        doc["operator_definition"]["summary"] = req.get("description", doc["operator_definition"]["summary"])
        doc["operator_definition"]["formula"] = req.get("formula", doc["operator_definition"]["formula"])
        doc["operator_definition"]["io_tensors"] = req.get("io_tensors", doc["operator_definition"]["io_tensors"])
        doc["parameters"]["shapes"] = req.get("shapes", doc["parameters"]["shapes"])
        # Propagate default shapes to locked_shapes for locked-shape mode
        if req.get("shapes", {}).get("default"):
            doc["parameters"]["locked_shapes"] = dict(req["shapes"]["default"])
        doc["parameters"]["dtype_io"] = req.get("dtype_io", doc["parameters"]["dtype_io"])
        doc["parameters"]["dtype_acc"] = req.get("dtype_acc", doc["parameters"]["dtype_acc"])
        if req.get("shape_keys"):
            doc["parameters"]["shape_keys"] = req["shape_keys"]
        if req.get("golden"):
            doc["golden"].update(req["golden"])

    doc["updated_at"] = date.today().isoformat()
    doc = normalize_design(doc)
    errors = validate_design(doc, strict=False)
    if errors:
        raise SystemExit("validation failed:\n  - " + "\n  - ".join(errors))

    if args.dry_run:
        payload = {"op": args.op, "dry_run": True, "design": doc}
        print(json.dumps(payload, ensure_ascii=False, indent=2) if args.json else f"dry-run OK: {args.op}")
        return 0

    ensure_readme(demo_root)
    paths.op_dir.mkdir(parents=True, exist_ok=True)
    paths.json_path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    paths.md_path.write_text(render_design_md(doc), encoding="utf-8")
    print(f"wrote {paths.json_path}")
    print(f"wrote {paths.md_path}")

    if args.json:
        print(json.dumps({"op": args.op, "design_json": str(paths.json_path)}, indent=2))
    else:
        print(
            f"\nNext: edit design.md -> validate -> implement in teco-ops interface + UAL\n"
            f"  python3 {REPO_ROOT / 'ops/sdaa-op-design/scripts/validate_design.py'} --op {args.op}\n"
            f"  follow {REPO_ROOT / 'ops/sdaa-op-template/SKILL.md'}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
