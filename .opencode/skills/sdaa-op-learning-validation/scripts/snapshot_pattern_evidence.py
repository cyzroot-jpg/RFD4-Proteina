#!/usr/bin/env python3
"""Create or update a portable pattern-evidence snapshot from a stage result."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from validate_stage_result import (
    PASS_STATUSES,
    correctness_passed,
    delivery_passed,
    load_json,
    performance_improved,
    performance_snapshot,
    validate,
)


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REGISTRY_PATH = SKILL_DIR / "references" / "evidence" / "pattern-evidence.json"
MACHINE_PATH_RE = re.compile(r"(?<![A-Za-z0-9_])/(?:data|home|Users)/")
SOURCE_STAGE_RE = re.compile(
    r"^backend://(?P<backend>[a-z0-9][a-z0-9_.-]*)/"
    r"(?P<path>.+/stage_results/(?P<filename>[A-Za-z0-9_.-]+)\.json)$"
)


def validate_source_stage(source_stage: str, stage: dict[str, Any]) -> str | None:
    match = SOURCE_STAGE_RE.fullmatch(source_stage)
    if not match:
        return "--source-stage must use backend://<backend>/.../stage_results/<stage>.json"
    if match.group("backend") != stage["backend"]:
        return "--source-stage backend does not match stage_result.backend"
    if match.group("filename") != stage["stage"]:
        return "--source-stage filename does not match stage_result.stage"
    return None


def merge_evidence(
    registry: dict[str, Any],
    evidence_id: str,
    item: dict[str, Any],
    *,
    force: bool,
) -> str:
    if registry.get("schema_version") != 1:
        raise ValueError("evidence registry schema_version must be 1")
    evidence = registry.setdefault("evidence", {})
    if not isinstance(evidence, dict):
        raise ValueError("evidence registry is malformed")
    existing = evidence.get(evidence_id)
    if existing == item:
        return "unchanged"
    if existing is not None and not force:
        raise ValueError(f"evidence ID already exists: {evidence_id} (use --force to replace)")
    evidence[evidence_id] = item
    return "updated"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage-result", required=True, type=Path)
    parser.add_argument("--evidence-id", required=True)
    parser.add_argument("--hardware", default="T1")
    parser.add_argument("--source-revision", default="")
    parser.add_argument(
        "--source-stage",
        required=True,
        help=(
            "Portable logical source, e.g. "
            "backend://teco-ops/op_learning/.../stage_results/v1.json"
        ),
    )
    parser.add_argument("--notes", default="")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z0-9][a-z0-9_.-]*", args.evidence_id):
        raise SystemExit("invalid evidence ID")
    if MACHINE_PATH_RE.search(args.source_stage):
        raise SystemExit("--source-stage must not contain a machine absolute path")

    stage = load_json(args.stage_result)
    errors = validate(stage)
    if errors:
        raise SystemExit("invalid normalized stage result: " + "; ".join(errors))

    source_error = validate_source_stage(args.source_stage, stage)
    if source_error:
        raise SystemExit(source_error)

    correctness_ok = correctness_passed(stage)
    delivery_ok = delivery_passed(stage)
    performance = performance_snapshot(stage)
    status = str(stage["status"]).lower()
    if status in PASS_STATUSES and (not correctness_ok or not delivery_ok):
        raise SystemExit("passing stage evidence requires correctness and delivery/pipeline pass")
    if stage["result_classification"] in {"positive_alone", "positive_in_bundle"}:
        if not performance_improved(performance):
            raise SystemExit("positive evidence requires a comparable performance improvement")

    item = {
        "backend": stage["backend"],
        "hardware": args.hardware or None,
        "source_revision": args.source_revision or None,
        "topic": stage["topic"],
        "stage": stage["stage"],
        "target_op": stage["target_op"],
        "status": stage["status"],
        "attempt_type": stage["attempt_type"],
        "result_classification": stage["result_classification"],
        "correctness_passed": correctness_ok,
        "delivery_passed": delivery_ok,
        "verified_shapes": stage["verified_shapes"],
        "performance": performance,
        "source_stage": args.source_stage,
    }
    if args.notes:
        item["notes"] = args.notes

    registry = load_json(REGISTRY_PATH)
    try:
        action = merge_evidence(
            registry,
            args.evidence_id,
            item,
            force=args.force,
        )
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    rendered = json.dumps(registry, ensure_ascii=False, indent=2) + "\n"
    if args.dry_run:
        print(json.dumps({args.evidence_id: item}, ensure_ascii=False, indent=2))
    elif action == "unchanged":
        print(f"unchanged {REGISTRY_PATH}: {args.evidence_id}")
    else:
        REGISTRY_PATH.write_text(rendered, encoding="utf-8")
        print(f"updated {REGISTRY_PATH}: {args.evidence_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
