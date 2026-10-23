#!/usr/bin/env python3
"""Re-render design.md from design.json and validate schema v3."""
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
    design_paths,
    list_incomplete_fields,
    normalize_design,
    render_design_md,
    resolve_design_path,
    validate_design,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and optionally refresh design.md")
    parser.add_argument("--op", required=True)
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--design", default="")
    parser.add_argument("--render-md", action="store_true", help="Rewrite design.md from design.json")
    parser.add_argument(
        "--draft",
        action="store_true",
        help="Schema-only validation (allow empty fields; for init draft)",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).expanduser().resolve()
    path = resolve_design_path(demo_root, args.op, args.design or None)
    strict = not args.draft

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        doc = normalize_design(raw)
        errors = validate_design(doc, strict=strict)
        incomplete = list_incomplete_fields(doc)
    except json.JSONDecodeError as exc:
        doc = {}
        errors = [f"invalid JSON: {exc}"]
        incomplete = []

    if args.render_md:
        if not strict:
            print("error: --render-md requires strict validation (omit --draft)", file=sys.stderr)
            return 2
        if errors:
            print("error: cannot render design.md until all fields are filled", file=sys.stderr)
        else:
            paths = design_paths(demo_root, args.op)
            doc["updated_at"] = date.today().isoformat()
            paths.md_path.write_text(render_design_md(doc), encoding="utf-8")
            path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"rendered {paths.md_path}")
            print(f"normalized {path}")

    payload = {
        "op": args.op,
        "path": str(path),
        "valid": not errors,
        "strict": strict,
        "errors": errors,
        "incomplete_fields": incomplete,
        "workflow_focus": doc.get("workflow", {}).get("current_focus"),
        "bottleneck_type": doc.get("throughput_model", {}).get("bottleneck_type"),
    }
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    elif errors:
        print("INVALID:")
        for err in errors:
            print(f"  - {err}")
    else:
        print(f"OK: {path}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
