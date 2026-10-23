#!/usr/bin/env python3
"""Validate that an iteration has a real evidence-based plan.

This is a guardrail for teco-kernel-optimizer. It cannot prove that the model
actually understood the evidence, but it blocks the common failure mode where an
automation script writes shallow, repeated analysis and immediately benchmarks
template branches.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path


REQUIRED_ANALYSIS_SECTIONS = [
    "Required Evidence",
    "Previous Evidence",
    "Diagnosis",
    "Chosen methods",
    "Hardware",
    "Excluded candidates",
    "Branch variants",
]

REQUIRED_METHOD_FIELDS = [
    "id",
    "name",
    "axis",
    "priority",
    "description",
    "trigger_evidence",
    "expected_bench_shift",
]


def _read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _file_sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def _branch_hashes(iter_dir: Path, branches: int) -> list[str]:
    hashes: list[str] = []
    for i in range(1, branches + 1):
        p = iter_dir / "branches" / f"b{i}" / "kernel.scpp"
        if p.is_file():
            hashes.append(_file_sha(p))
    return hashes


def _method_ids(methods_payload: dict) -> list[str]:
    return [str(m.get("id", "")).strip() for m in methods_payload.get("methods", [])]


def validate(state_path: Path, iteration: int) -> list[str]:
    errors: list[str] = []
    state = _read_json(state_path)
    run_dir = Path(state["run_dir"])
    iter_dir = run_dir / f"iterv{iteration}"
    analysis_path = iter_dir / "analysis.md"
    methods_path = iter_dir / "methods.json"
    wiki_path = iter_dir / "wiki_queries.json"
    branches = int(state.get("branches", 4))

    if not wiki_path.is_file():
        errors.append(f"missing wiki query evidence: {wiki_path}")
    if not analysis_path.is_file():
        errors.append(f"missing analysis plan: {analysis_path}")
    if not methods_path.is_file():
        errors.append(f"missing methods json: {methods_path}")
    if errors:
        return errors

    analysis = analysis_path.read_text(encoding="utf-8", errors="ignore")
    methods_payload = _read_json(methods_path)

    if len(analysis.strip()) < 1800:
        errors.append("analysis.md is too short for an evidence-based iteration plan (<1800 chars)")

    for section in REQUIRED_ANALYSIS_SECTIONS:
        if section not in analysis:
            errors.append(f"analysis.md missing required section marker: {section}")

    forbidden_placeholders = [
        "{{",
        "TODO",
        "_Fill this section",
        "_Summarize what",
        "_Describe the K",
        "same as previous",
        "static candidate family",
    ]
    for marker in forbidden_placeholders:
        if marker in analysis:
            errors.append(f"analysis.md contains placeholder or banned boilerplate: {marker}")

    if str(wiki_path) not in analysis and "wiki_queries.json" not in analysis:
        errors.append("analysis.md does not explicitly cite wiki_queries.json")
    if "state.json" not in analysis:
        errors.append("analysis.md does not explicitly cite state.json")

    if iteration > 1:
        prev_dir = run_dir / f"iterv{iteration - 1}"
        for name in ("analysis.md", "branch_results.json", "bench.json"):
            if not (prev_dir / name).is_file():
                errors.append(f"previous evidence missing: {prev_dir / name}")
            elif name not in analysis:
                errors.append(f"analysis.md does not explicitly cite previous {name}")

        prev_methods_path = prev_dir / "methods.json"
        if prev_methods_path.is_file():
            prev_ids = _method_ids(_read_json(prev_methods_path))
            cur_ids = _method_ids(methods_payload)
            if cur_ids == prev_ids:
                allowed = re.search(
                    r"\b(extend|extension|repair|ablation|follow-up|narrow|因|由于|延续|修复|消融|收窄)\b",
                    analysis,
                    re.IGNORECASE,
                )
                if not allowed:
                    errors.append(
                        "methods.json repeats the previous method set without an explicit extension/repair rationale"
                    )

        prev_hashes = set(_branch_hashes(prev_dir, branches))
        cur_hashes = _branch_hashes(iter_dir, branches)
        repeated = sum(1 for h in cur_hashes if h in prev_hashes)
        if repeated >= max(2, branches // 2):
            errors.append(
                f"{repeated}/{branches} branch kernels are byte-identical to the previous iteration"
            )

    if not isinstance(methods_payload, dict) or "methods" not in methods_payload:
        errors.append("methods.json must contain a top-level methods list")
    else:
        if methods_payload.get("iter") != iteration:
            errors.append(f"methods.json must contain iter={iteration}")
        methods = methods_payload.get("methods")
        if not isinstance(methods, list) or not methods:
            errors.append("methods.json methods must be a non-empty list")
        else:
            for idx, method in enumerate(methods, 1):
                for field in REQUIRED_METHOD_FIELDS:
                    if field not in method or method[field] in ("", None, []):
                        errors.append(f"methods[{idx}] missing required field: {field}")
                if method.get("axis") not in ("compute", "memory", "latency"):
                    errors.append(f"methods[{idx}] has invalid axis: {method.get('axis')}")
                if not isinstance(method.get("priority"), int):
                    errors.append(f"methods[{idx}] priority must be an integer P-level")
                if "skipped_higher" not in method:
                    errors.append(f"methods[{idx}] missing skipped_higher priority-scan evidence")

    branch_lines = re.findall(r"\bb[1-9][0-9]?\b", analysis)
    if len(set(branch_lines)) < branches:
        errors.append(f"analysis.md must describe all {branches} branch variants")

    for i in range(1, branches + 1):
        branch_kernel = iter_dir / "branches" / f"b{i}" / "kernel.scpp"
        if not branch_kernel.is_file():
            errors.append(f"missing branch kernel: {branch_kernel}")

    if analysis_path.stat().st_mtime > 0:
        for i in range(1, branches + 1):
            branch_kernel = iter_dir / "branches" / f"b{i}" / "kernel.scpp"
            if branch_kernel.is_file() and branch_kernel.stat().st_mtime < analysis_path.stat().st_mtime:
                errors.append(
                    f"{branch_kernel} is older than analysis.md; write plan before generating branches"
                )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a teco-kernel-optimizer iteration plan")
    parser.add_argument("--state", required=True)
    parser.add_argument("--iter", type=int, required=True)
    args = parser.parse_args()

    errors = validate(Path(args.state), args.iter)
    if errors:
        print("iteration plan validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(json.dumps({"iter": args.iter, "plan_validation": "passed"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
