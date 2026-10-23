#!/usr/bin/env python3
"""Validate the normalized learning-validation stage result contract."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


ATTEMPT_TYPES = {"isolated", "enabler", "combination", "ablation"}
RESULT_CLASSIFICATIONS = {
    "positive_alone",
    "neutral_enabler",
    "negative_alone",
    "positive_in_bundle",
    "incompatible",
}
PASS_STATUSES = {"pass", "passed", "ok", "success", "succeeded"}
REQUIRED_FIELDS = {
    "schema_version",
    "backend",
    "topic",
    "stage",
    "target_op",
    "attempt_type",
    "hypothesis",
    "status",
    "allowed_changes",
    "forbidden_changes",
    "verified_shapes",
    "failures",
    "learned_rules",
    "result_classification",
}
COMBINATION_FIELDS = {
    "components",
    "dependencies",
    "baseline_stage",
    "comparison_matrix",
    "ablation_plan",
}
STRING_FIELDS = ("backend", "topic", "stage", "target_op", "hypothesis", "status")
STRING_LIST_FIELDS = (
    "components",
    "dependencies",
    "ablation_plan",
    "allowed_changes",
    "forbidden_changes",
    "verified_shapes",
    "learned_rules",
)
PERF_FIELDS = (
    ("time_ms", "ms", "lower_is_better"),
    ("cycles", "cycles", "lower_is_better"),
    ("max_cycles", "cycles", "lower_is_better"),
    ("tflops", "TFLOPS", "higher_is_better"),
    ("approx_tflops", "TFLOPS", "higher_is_better"),
)


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("stage result must be a JSON object")
    return payload


def nested_pass(payload: dict[str, Any], candidates: tuple[tuple[str, str], ...]) -> bool:
    for root, field in candidates:
        section = payload.get(root)
        if not isinstance(section, dict) or field not in section:
            continue
        value = section[field]
        if value is True:
            return True
        if isinstance(value, str) and value.lower() in PASS_STATUSES | {"true"}:
            return True
        if field == "success_rate":
            try:
                return float(value) == 1.0
            except (TypeError, ValueError):
                continue
    return False


def correctness_passed(payload: dict[str, Any]) -> bool:
    return nested_pass(
        payload,
        (
            ("correctness", "success_rate"),
            ("correctness", "pipeline_passed"),
            ("accuracy", "success_rate"),
            ("accuracy", "passed"),
            ("pipeline", "passed"),
        ),
    )


def delivery_passed(payload: dict[str, Any]) -> bool:
    return nested_pass(
        payload,
        (("delivery", "delivery_status"), ("pipeline", "passed")),
    )


def performance_snapshot(payload: dict[str, Any]) -> dict[str, Any] | None:
    before = payload.get("perf_before")
    after = payload.get("perf_after")
    if not isinstance(before, dict) or not isinstance(after, dict):
        return None
    for metric, unit, direction in PERF_FIELDS:
        if metric not in before or metric not in after:
            continue
        try:
            before_value = float(before[metric])
            after_value = float(after[metric])
        except (TypeError, ValueError):
            return None
        if not math.isfinite(before_value) or not math.isfinite(after_value):
            return None
        return {
            "metric": metric,
            "unit": unit,
            "before": before_value,
            "after": after_value,
            "direction": direction,
        }
    return None


def performance_improved(performance: dict[str, Any] | None) -> bool:
    if not performance:
        return False
    if performance["direction"] == "lower_is_better":
        return performance["after"] < performance["before"]
    return performance["after"] > performance["before"]


def validate(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    missing = sorted(REQUIRED_FIELDS - payload.keys())
    if missing:
        errors.append("missing fields: " + ", ".join(missing))
    if payload.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    for field in STRING_FIELDS:
        if field in payload and not isinstance(payload[field], str):
            errors.append(f"{field} must be a string")
        elif field in payload and not payload[field].strip():
            errors.append(f"{field} must not be empty")

    for field in ("goal", "failure_root_cause", "fix"):
        if field in payload and not isinstance(payload[field], str):
            errors.append(f"{field} must be a string")
    if "commands" in payload and not isinstance(payload["commands"], list):
        errors.append("commands must be a list")
    for field in ("correctness", "delivery", "pipeline"):
        if field in payload and not isinstance(payload[field], dict):
            errors.append(f"{field} must be an object")

    attempt_type = payload.get("attempt_type")
    if attempt_type not in ATTEMPT_TYPES:
        errors.append(f"invalid attempt_type: {attempt_type!r}")
    if attempt_type == "combination":
        combo_missing = sorted(COMBINATION_FIELDS - payload.keys())
        if combo_missing:
            errors.append("combination missing fields: " + ", ".join(combo_missing))
        for field in ("components", "dependencies", "comparison_matrix", "ablation_plan"):
            if field in payload and not isinstance(payload[field], list):
                errors.append(f"{field} must be a list")
            elif isinstance(payload.get(field), list) and not payload[field]:
                errors.append(f"combination {field} must not be empty")
        if not str(payload.get("baseline_stage", "")).strip():
            errors.append("combination baseline_stage must not be empty")
        matrix = payload.get("comparison_matrix")
        if isinstance(matrix, list):
            if len(matrix) < 2:
                errors.append("combination comparison_matrix must contain at least two variants")
            for idx, item in enumerate(matrix):
                if not isinstance(item, dict) or not str(item.get("variant", "")).strip():
                    errors.append(f"comparison_matrix[{idx}] must contain a non-empty variant")
                    continue
                for field in ("variant", "stage", "result"):
                    if field in item and not isinstance(item[field], str):
                        errors.append(f"comparison_matrix[{idx}].{field} must be a string")

    classification = payload.get("result_classification")
    if classification is not None and classification not in RESULT_CLASSIFICATIONS:
        errors.append(f"invalid result_classification: {classification!r}")

    for field in (*STRING_LIST_FIELDS, "failures"):
        if field in payload and not isinstance(payload[field], list):
            errors.append(f"{field} must be a list")

    for field in STRING_LIST_FIELDS:
        value = payload.get(field)
        if isinstance(value, list) and any(not isinstance(item, str) for item in value):
            errors.append(f"{field} items must be strings")

    verified_shapes = payload.get("verified_shapes")
    if isinstance(verified_shapes, list) and not verified_shapes:
        errors.append("verified_shapes must not be empty")

    if not str(payload.get("hypothesis", "")).strip():
        errors.append("hypothesis must not be empty")

    before = payload.get("perf_before")
    after = payload.get("perf_after")
    if (before is None) != (after is None):
        errors.append("perf_before and perf_after must be provided together")
    if before is not None and not isinstance(before, dict):
        errors.append("perf_before must be an object or null")
    if after is not None and not isinstance(after, dict):
        errors.append("perf_after must be an object or null")
    performance = performance_snapshot(payload)
    if isinstance(before, dict) and isinstance(after, dict) and performance is None:
        errors.append("perf_before/perf_after need one comparable finite metric")

    status = str(payload.get("status", "")).strip().lower()
    classification = payload.get("result_classification")
    if status in PASS_STATUSES:
        if not correctness_passed(payload):
            errors.append("passing stage requires correctness pass evidence")
        if not delivery_passed(payload):
            errors.append("passing stage requires delivery/pipeline pass evidence")
        if classification in {"negative_alone", "incompatible"}:
            errors.append(f"passing stage cannot use result_classification {classification!r}")
    else:
        failures = payload.get("failures")
        root_cause = str(payload.get("failure_root_cause", "")).strip()
        if isinstance(failures, list) and not failures and not root_cause:
            errors.append("non-passing stage requires failures or failure_root_cause")
        if classification in {"positive_alone", "positive_in_bundle"}:
            errors.append(f"non-passing stage cannot use result_classification {classification!r}")

    if classification in {"positive_alone", "positive_in_bundle"}:
        if not performance_improved(performance):
            errors.append(f"{classification} requires a comparable performance improvement")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        payload = load_json(args.path)
        errors = validate(payload)
    except ValueError as exc:
        errors = [str(exc)]

    result = {"valid": not errors, "path": str(args.path), "errors": errors}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif errors:
        print("stage-result validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
    else:
        print("stage-result validation passed")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
