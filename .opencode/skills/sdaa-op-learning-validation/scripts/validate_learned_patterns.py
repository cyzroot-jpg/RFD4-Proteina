#!/usr/bin/env python3
"""Validate portable long-term learned patterns and evidence snapshots."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[3]
PATTERN_ROOT = (
    REPO_ROOT / "ops" / "sdaa-op-learning-validation" / "references" / "learned-patterns"
)
EVIDENCE_REGISTRY_PATH = (
    REPO_ROOT
    / "ops"
    / "sdaa-op-learning-validation"
    / "references"
    / "evidence"
    / "pattern-evidence.json"
)
DOMAIN_ROUTES_PATH = PATTERN_ROOT / "domain-routes.json"

SUCCESS_STATUSES = {"verified_by_stage", "promoted"}
NON_DEFAULT_STATUSES = {"needs_revalidation", "superseded", "deprecated"}
FAILURE_STATUSES = {"verified_by_failed_stage"}
CANDIDATE_STATUSES = {"draft_from_source", "human_reviewed"}
KNOWN_STATUSES = SUCCESS_STATUSES | NON_DEFAULT_STATUSES | FAILURE_STATUSES | CANDIDATE_STATUSES
KNOWN_PATTERN_KINDS = {"correctness_contract", "optimization", "composite", "pitfall"}
EVIDENCE_ID_RE = re.compile(r"\bevidence:\s*([a-z0-9][a-z0-9_.-]*)\b")
SOURCE_STAGE_RE = re.compile(
    r"^backend://(?P<backend>[a-z0-9][a-z0-9_.-]*)/"
    r".+/stage_results/(?P<stage>[A-Za-z0-9_.-]+)\.json$"
)
MACHINE_ABSOLUTE_PATH_RE = re.compile(r"(?<![A-Za-z0-9_])/(?:data|home|Users)/[^\s`)'\"]+")
REQUIRED_CN_HEADINGS = [
    "## 状态",
    "## 类型",
    "## 问题",
    "## 适用场景",
    "## 不适用场景",
    "## 核心思路",
    "## 实现规则",
    "## 伪代码",
    "## 常见坑",
    "## 验证",
    "## 来源沿革",
    "## 相关模式",
]
LEGACY_EN_HEADINGS = [
    "## Status",
    "## Problem",
    "## Applies When",
    "## Do Not Use When",
    "## Core Idea",
    "## Implementation Rules",
    "## Scheduling Notes",
    "## Pseudocode",
    "## Common Pitfalls",
    "## Validation",
    "## Source Evidence",
    "## Related Patterns",
]
ASCII_WORD_RE = re.compile(r"[A-Za-z][A-Za-z0-9_/-]*")
CN_CHAR_RE = re.compile(r"[\u4e00-\u9fff]")
ALLOWED_ASCII_WORDS = {
    "A",
    "B",
    "C",
    "DMA",
    "RMA",
    "ACE",
    "SIMD",
    "SPE",
    "LDM",
    "HBM",
    "TFLOPS",
    "GEMM",
    "Linear",
    "NN",
    "K",
    "M",
    "N",
    "QK",
    "SV",
    "BV",
    "P0",
    "P1",
    "T1",
    "fp16",
    "fp32",
    "bf16",
    "half",
    "float",
    "tile",
    "tiles",
    "chunk",
    "chunks",
    "row",
    "rows",
    "col",
    "cols",
    "buffer",
    "buffers",
    "reply",
    "wait",
    "stage",
    "stages",
    "pipeline",
    "workspace",
    "shape",
    "dtype",
    "layout",
    "topk",
    "head",
    "score",
    "scores",
    "attention",
    "softmax",
    "online",
    "kernel",
    "pass",
    "passed",
    "cycles",
    "ms",
    "op",
    "backend",
}


class ValidationError(Exception):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:  # noqa: BLE001
        raise ValidationError(f"cannot read JSON `{path}`: {exc}") from exc
    if not isinstance(data, dict):
        raise ValidationError(f"`{path}` is not a JSON object")
    return data


def section_text(markdown: str, heading: str) -> str:
    lines = markdown.splitlines()
    start = None
    for idx, line in enumerate(lines):
        if line.strip().lower() == heading.lower():
            start = idx + 1
            break
    if start is None:
        return ""
    out = []
    for line in lines[start:]:
        if line.startswith("## ") and out:
            break
        out.append(line)
    return "\n".join(out).strip()


def pattern_status(markdown: str) -> str:
    status_block = section_text(markdown, "## 状态")
    if not status_block:
        status_block = section_text(markdown, "## Status")
    for line in status_block.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def pattern_kind(markdown: str) -> str:
    kind_block = section_text(markdown, "## 类型")
    for line in kind_block.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def load_evidence_registry() -> dict[str, dict[str, Any]]:
    payload = read_json(EVIDENCE_REGISTRY_PATH)
    if payload.get("schema_version") != 1:
        raise ValidationError(
            f"unsupported evidence registry schema_version in `{EVIDENCE_REGISTRY_PATH}`"
        )
    evidence = payload.get("evidence")
    if not isinstance(evidence, dict):
        raise ValidationError(f"`{EVIDENCE_REGISTRY_PATH}` missing evidence object")
    return evidence


def referenced_evidence_ids(markdown: str) -> list[str]:
    return list(dict.fromkeys(EVIDENCE_ID_RE.findall(markdown)))


def evidence_performance_improved(item: dict[str, Any]) -> bool:
    perf = item.get("performance")
    if not isinstance(perf, dict):
        return False
    try:
        before = float(perf["before"])
        after = float(perf["after"])
    except (KeyError, TypeError, ValueError):
        return False
    direction = perf.get("direction")
    if direction == "lower_is_better":
        return after < before
    if direction == "higher_is_better":
        return after > before
    return False


def evidence_is_failed_or_regressed(item: dict[str, Any]) -> bool:
    if str(item.get("status", "")).lower() not in {"pass", "passed", "ok", "success"}:
        return True
    perf = item.get("performance")
    if not isinstance(perf, dict):
        return False
    try:
        before = float(perf["before"])
        after = float(perf["after"])
    except (KeyError, TypeError, ValueError):
        return False
    direction = perf.get("direction")
    return (direction == "lower_is_better" and after >= before) or (
        direction == "higher_is_better" and after <= before
    )


def validate_evidence_item(
    evidence_id: str,
    item: dict[str, Any],
    *,
    require_performance: bool,
) -> list[str]:
    errors: list[str] = []
    if str(item.get("status", "")).lower() not in {"pass", "passed", "ok", "success", "succeeded"}:
        errors.append(f"evidence `{evidence_id}` is not a passing stage")
    source_stage = str(item.get("source_stage", ""))
    if MACHINE_ABSOLUTE_PATH_RE.search(source_stage):
        errors.append(f"evidence `{evidence_id}` contains machine absolute path `{source_stage}`")
    if not item.get("correctness_passed"):
        errors.append(f"evidence `{evidence_id}` missing correctness pass")
    if not item.get("delivery_passed"):
        errors.append(f"evidence `{evidence_id}` missing delivery/pipeline pass")
    if require_performance and not evidence_performance_improved(item):
        errors.append(f"evidence `{evidence_id}` missing comparable performance improvement")
    return errors


def validate_evidence_registry() -> list[str]:
    errors: list[str] = []
    try:
        registry = load_evidence_registry()
    except ValidationError as exc:
        return [str(exc)]

    required = {
        "backend",
        "stage",
        "target_op",
        "status",
        "correctness_passed",
        "delivery_passed",
        "verified_shapes",
        "source_stage",
    }
    for evidence_id, item in registry.items():
        if not re.fullmatch(r"[a-z0-9][a-z0-9_.-]*", evidence_id):
            errors.append(f"invalid evidence ID `{evidence_id}`")
        if not isinstance(item, dict):
            errors.append(f"evidence `{evidence_id}` is not an object")
            continue
        missing = sorted(required - item.keys())
        if missing:
            errors.append(f"evidence `{evidence_id}` missing fields: {', '.join(missing)}")
        source_stage = str(item.get("source_stage", ""))
        if MACHINE_ABSOLUTE_PATH_RE.search(source_stage):
            errors.append(f"evidence `{evidence_id}` contains machine absolute path `{source_stage}`")
        source_match = SOURCE_STAGE_RE.fullmatch(source_stage)
        if not source_match:
            errors.append(f"evidence `{evidence_id}` has non-portable source_stage `{source_stage}`")
        elif source_match.group("backend") != item.get("backend"):
            errors.append(f"evidence `{evidence_id}` source_stage backend mismatch")
        elif source_match.group("stage") != item.get("stage"):
            errors.append(f"evidence `{evidence_id}` source_stage stage mismatch")

        for field in ("backend", "stage", "target_op", "status"):
            if field in item and not str(item[field]).strip():
                errors.append(f"evidence `{evidence_id}` has empty {field}")
        for field in ("correctness_passed", "delivery_passed"):
            if field in item and not isinstance(item[field], bool):
                errors.append(f"evidence `{evidence_id}` {field} must be boolean")
        shapes = item.get("verified_shapes")
        if not isinstance(shapes, list) or not shapes:
            errors.append(f"evidence `{evidence_id}` verified_shapes must be a non-empty list")
        elif any(not isinstance(shape, str) or not shape.strip() for shape in shapes):
            errors.append(f"evidence `{evidence_id}` verified_shapes items must be non-empty strings")
        perf = item.get("performance")
        if perf is not None:
            if not isinstance(perf, dict):
                errors.append(f"evidence `{evidence_id}` performance must be object or null")
            else:
                perf_missing = {
                    "metric",
                    "unit",
                    "before",
                    "after",
                    "direction",
                } - perf.keys()
                if perf_missing:
                    errors.append(
                        f"evidence `{evidence_id}` performance missing fields: "
                        + ", ".join(sorted(perf_missing))
                    )
                else:
                    if perf.get("direction") not in {"lower_is_better", "higher_is_better"}:
                        errors.append(f"evidence `{evidence_id}` has invalid performance direction")
                    for field in ("before", "after"):
                        try:
                            value = float(perf[field])
                        except (TypeError, ValueError):
                            errors.append(f"evidence `{evidence_id}` performance {field} must be numeric")
                            continue
                        if not math.isfinite(value):
                            errors.append(f"evidence `{evidence_id}` performance {field} must be finite")
    return errors


def validate_domain_routes() -> list[str]:
    errors: list[str] = []
    try:
        payload = read_json(DOMAIN_ROUTES_PATH)
    except ValidationError as exc:
        return [str(exc)]
    if payload.get("schema_version") != 1:
        return [f"unsupported domain route schema_version in `{DOMAIN_ROUTES_PATH}`"]
    routes = payload.get("routes")
    if not isinstance(routes, dict) or not routes:
        return [f"`{DOMAIN_ROUTES_PATH}` missing non-empty routes object"]

    for name, route in routes.items():
        if not isinstance(name, str) or not name.strip():
            errors.append("domain route names must be non-empty strings")
            continue
        if not isinstance(route, dict):
            errors.append(f"domain route `{name}` must be an object")
            continue
        for field in ("triggers", "patterns", "inherits"):
            value = route.get(field, [])
            if not isinstance(value, list) or any(
                not isinstance(item, str) or not item.strip() for item in value
            ):
                errors.append(f"domain route `{name}` {field} must be a string list")
        index = route.get("index")
        if not isinstance(index, str) or not index.strip():
            errors.append(f"domain route `{name}` must define an index")
        else:
            index_path = PATTERN_ROOT / index
            if not index_path.is_file() or index_path.name != "README.md":
                errors.append(f"domain route `{name}` index does not exist: `{index}`")
        for relative in route.get("patterns", []):
            pattern_path = PATTERN_ROOT / relative
            if not pattern_path.is_file() or pattern_path.name == "README.md":
                errors.append(f"domain route `{name}` pattern does not exist: `{relative}`")
        for parent in route.get("inherits", []):
            if parent not in routes:
                errors.append(f"domain route `{name}` inherits unknown route `{parent}`")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited or name not in routes or not isinstance(routes[name], dict):
            return
        if name in visiting:
            errors.append(f"domain route inheritance cycle detected at `{name}`")
            return
        visiting.add(name)
        for parent in routes[name].get("inherits", []):
            visit(parent)
        visiting.remove(name)
        visited.add(name)

    for name in routes:
        visit(name)
    return errors


def is_code_fence(line: str) -> bool:
    return line.strip().startswith("```")


def strip_inline_code(line: str) -> str:
    return re.sub(r"`[^`]*`", "", line)


def is_evidence_or_code_like(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return True
    if stripped.startswith("#"):
        return True
    if stripped.startswith("|"):
        return True
    if re.search(r"[/\\][A-Za-z0-9_.-]+", stripped):
        return True
    if re.search(r"\b[A-Za-z_]\w*\([^)]*\)", stripped):
        return True
    if re.search(r"\b(?:rt_|simd_|SIMD_|sate::|std::|__)\w*", stripped):
        return True
    if re.search(r"\b[A-Za-z_]\w*\s*[=<>!]=?", stripped):
        return True
    return False


def english_word_count(line: str) -> int:
    words = ASCII_WORD_RE.findall(strip_inline_code(line))
    return sum(1 for word in words if word not in ALLOWED_ASCII_WORDS)


def validate_chinese_markdown(path: Path, markdown: str) -> list[str]:
    errors: list[str] = []
    for heading in LEGACY_EN_HEADINGS:
        if heading in markdown:
            errors.append(
                f"`{path.relative_to(REPO_ROOT)}` uses English heading `{heading}`; "
                "learned-patterns must use Chinese section headings."
            )
    if path.name != "README.md":
        for heading in REQUIRED_CN_HEADINGS:
            if heading not in markdown:
                errors.append(
                    f"`{path.relative_to(REPO_ROOT)}` missing Chinese heading `{heading}`"
                )

    in_code = False
    for lineno, line in enumerate(markdown.splitlines(), start=1):
        if is_code_fence(line):
            in_code = not in_code
            continue
        if in_code or is_evidence_or_code_like(line):
            continue
        if english_word_count(line) >= 8:
            errors.append(
                f"`{path.relative_to(REPO_ROOT)}:{lineno}` appears to contain a long English sentence; "
                "write learned-pattern prose in Chinese."
            )
    return errors


def validate_pattern(path: Path) -> list[str]:
    markdown = path.read_text(encoding="utf-8", errors="ignore")
    status = pattern_status(markdown)
    kind = pattern_kind(markdown)
    errors: list[str] = validate_chinese_markdown(path, markdown)

    rel_path = path.relative_to(REPO_ROOT)
    machine_paths = MACHINE_ABSOLUTE_PATH_RE.findall(markdown)
    for machine_path in machine_paths:
        errors.append(f"`{rel_path}` contains machine absolute path `{machine_path}`")

    if kind not in KNOWN_PATTERN_KINDS:
        errors.append(f"`{rel_path}` has unknown pattern kind `{kind}`")
    if kind == "composite" and not section_text(markdown, "## 组合依赖与归因"):
        errors.append(f"`{rel_path}` composite pattern missing `## 组合依赖与归因`")

    if status in {"draft_from_source", "human_reviewed"}:
        errors.append(
            f"`{path.relative_to(REPO_ROOT)}` has status `{status}`; "
            "draft/candidate knowledge must stay under <demo_root>/op_learning"
        )
        return errors

    if status not in KNOWN_STATUSES:
        errors.append(f"`{rel_path}` has unknown pattern status `{status}`")
        return errors

    evidence_ids = referenced_evidence_ids(markdown)
    if not evidence_ids:
        errors.append(f"`{rel_path}` has no portable evidence ID")
        return errors

    try:
        registry = load_evidence_registry()
    except ValidationError as exc:
        errors.append(str(exc))
        return errors

    evidence_items: list[tuple[str, dict[str, Any]]] = []
    for evidence_id in evidence_ids:
        item = registry.get(evidence_id)
        if not isinstance(item, dict):
            errors.append(f"`{rel_path}` references unknown evidence `{evidence_id}`")
            continue
        evidence_items.append((evidence_id, item))

    if status in FAILURE_STATUSES and "pitfalls" not in path.relative_to(PATTERN_ROOT).parts:
        errors.append(
            f"`{rel_path}` uses failure status outside learned-patterns/pitfalls/"
        )

    if kind == "pitfall" and "pitfalls" not in path.relative_to(PATTERN_ROOT).parts:
        errors.append(f"`{rel_path}` uses pitfall kind outside learned-patterns/pitfalls/")

    if status == "superseded" and "superseded_by:" not in markdown:
        errors.append(f"`{rel_path}` is superseded but has no `superseded_by:` target")

    if status in SUCCESS_STATUSES:
        require_performance = kind in {"optimization", "composite"}
        for evidence_id, item in evidence_items:
            errors.extend(
                validate_evidence_item(
                    evidence_id,
                    item,
                    require_performance=require_performance,
                )
            )
        if status == "promoted":
            contexts = {
                (item.get("backend"), item.get("target_op"), item.get("source_revision"))
                for _, item in evidence_items
            }
            if len(contexts) < 2:
                errors.append(f"`{rel_path}` promoted status requires two independent contexts")
        return errors

    if status in FAILURE_STATUSES:
        if kind != "pitfall":
            errors.append(f"`{rel_path}` failure status requires pitfall kind")
        if not any(evidence_is_failed_or_regressed(item) for _, item in evidence_items):
            errors.append(f"`{rel_path}` has no failed or regressed evidence")
    return errors


def iter_pattern_files(paths: list[Path]) -> list[Path]:
    if paths:
        result = []
        for path in paths:
            candidate = path if path.is_absolute() else REPO_ROOT / path
            if candidate.is_dir():
                result.extend(candidate.rglob("*.md"))
            else:
                result.append(candidate)
        return sorted(set(result))
    return sorted(path for path in PATTERN_ROOT.rglob("*.md") if path.name != "README.md")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()

    all_errors: list[str] = validate_evidence_registry()
    all_errors.extend(validate_domain_routes())
    for path in iter_pattern_files(args.paths):
        if path.name == "README.md":
            continue
        if not path.exists():
            all_errors.append(f"`{path}` does not exist")
            continue
        all_errors.extend(validate_pattern(path))

    if all_errors:
        print("learned-pattern validation failed:", file=sys.stderr)
        for error in all_errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("learned-pattern validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
