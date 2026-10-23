#!/usr/bin/env python3
"""Legacy entry point for promoting verified stage facts into op design files.

The stage result is intentionally structured. Failed stages, TODOs, and facts
without evidence are rejected before touching design.json/design.md.
"""
from __future__ import annotations

import argparse
import json
import re
from copy import deepcopy
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

import backend_profiles
import validate_stage_result as stage_contract

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parents[1]

PASS_STATUSES = {"pass", "passed", "ok", "success", "succeeded"}
PATH_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$")
FORBIDDEN_ROOTS = {"schema_version", "op", "created_at"}
MACHINE_PATH_RE = re.compile(r"(?<![A-Za-z0-9_])/(?:data|home|Users)/")
TODO_RE = re.compile(r"\bTODO\b", re.IGNORECASE)

AUTO_START = "<!-- AUTO-PROMOTED-STAGE-RESULTS:START -->"
AUTO_END = "<!-- AUTO-PROMOTED-STAGE-RESULTS:END -->"


@dataclass(frozen=True)
class Paths:
    demo_root: Path
    op: str
    topic: str

    @property
    def design_dir(self) -> Path:
        return self.demo_root / "op_design" / self.op

    @property
    def design_json(self) -> Path:
        return self.design_dir / "design.json"

    @property
    def design_md(self) -> Path:
        return self.design_dir / "design.md"

    @property
    def learned_patterns(self) -> Path:
        return self.demo_root / "op_learning" / self.topic / "learned_patterns.md"


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"missing file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {path}: {exc}")
    if not isinstance(payload, dict):
        raise SystemExit(f"expected object JSON in {path}")
    return payload


def validate_topic(topic: str) -> str:
    clean = topic.strip().strip("/")
    if not clean or ".." in clean.split("/"):
        raise SystemExit(f"invalid topic: {topic}")
    return clean


def validate_promotable_stage_result(
    result: dict[str, Any],
    *,
    op: str,
    topic: str,
    stage: str | None,
    backend: str,
) -> None:
    contract_errors = stage_contract.validate(result)
    if contract_errors:
        raise SystemExit("invalid normalized stage result: " + "; ".join(contract_errors))

    result_op = result.get("target_op") or result.get("op")
    if result_op and result_op != op:
        raise SystemExit(f"stage_result op mismatch: expected {op}, got {result_op}")

    result_backend = result.get("backend")
    if result_backend != backend:
        raise SystemExit(
            f"stage_result backend mismatch: expected {backend}, got {result_backend}"
        )

    result_topic = result.get("topic")
    if result_topic and result_topic.strip().strip("/") != topic:
        raise SystemExit(f"stage_result topic mismatch: expected {topic}, got {result_topic}")

    result_stage = str(result.get("stage", "")).strip()
    if not result_stage:
        raise SystemExit("stage_result.stage is required")
    if stage and result_stage != stage:
        raise SystemExit(f"stage_result stage mismatch: expected {stage}, got {result_stage}")

    status = str(result.get("status", "")).strip().lower()
    if status not in PASS_STATUSES:
        raise SystemExit(f"refusing to promote non-passing stage status: {result.get('status')!r}")

    evidence = result.get("evidence", [])
    if not evidence:
        raise SystemExit("stage_result.evidence is required")
    portable_payload = {
        "summary": result.get("summary", ""),
        "evidence": evidence,
        "verified_facts": result.get("verified_facts", []),
        "design_updates": result.get("design_updates", {}),
    }
    portable_blob = json.dumps(portable_payload, ensure_ascii=False)
    if MACHINE_PATH_RE.search(portable_blob):
        raise SystemExit("promoted design facts must not contain machine absolute paths")
    if TODO_RE.search(json.dumps(
        {
            "verified_facts": result.get("verified_facts", []),
            "design_updates": result.get("design_updates", {}),
        },
        ensure_ascii=False,
    )):
        raise SystemExit("refusing to promote TODO design facts")

    verified_facts = result.get("verified_facts", [])
    design_updates = result.get("design_updates", {})
    if verified_facts is None:
        verified_facts = []
    if design_updates is None:
        design_updates = {}
    if not isinstance(verified_facts, list):
        raise SystemExit("stage_result.verified_facts must be a list")
    if not isinstance(design_updates, dict):
        raise SystemExit("stage_result.design_updates must be an object")
    if not verified_facts and not design_updates:
        raise SystemExit("nothing to promote: provide verified_facts or design_updates")

    for idx, fact in enumerate(verified_facts):
        if not isinstance(fact, dict):
            raise SystemExit(f"verified_facts[{idx}] must be an object")
        fact_path = fact.get("path")
        if not isinstance(fact_path, str) or not PATH_RE.match(fact_path):
            raise SystemExit(f"verified_facts[{idx}].path is invalid: {fact_path!r}")
        root = fact_path.split(".", 1)[0]
        if root in FORBIDDEN_ROOTS:
            raise SystemExit(f"verified_facts[{idx}].path cannot update {root}")
        operations = [key for key in ("value", "append", "extend", "merge") if key in fact]
        if len(operations) != 1:
            raise SystemExit(
                f"verified_facts[{idx}] must contain exactly one of value/append/extend/merge"
            )
        if "evidence" not in fact or not fact["evidence"]:
            raise SystemExit(f"verified_facts[{idx}].evidence is required")


def get_parent(doc: dict[str, Any], path: str) -> tuple[dict[str, Any], str]:
    parts = path.split(".")
    cur: Any = doc
    for part in parts[:-1]:
        if not isinstance(cur, dict):
            raise SystemExit(f"cannot descend through non-object path: {path}")
        nxt = cur.setdefault(part, {})
        if not isinstance(nxt, dict):
            raise SystemExit(f"cannot merge path through non-object field: {part} in {path}")
        cur = nxt
    if not isinstance(cur, dict):
        raise SystemExit(f"parent is not an object for path: {path}")
    return cur, parts[-1]


def deep_merge(
    dst: dict[str, Any],
    src: dict[str, Any],
    *,
    root: bool = True,
) -> dict[str, Any]:
    for key, value in src.items():
        if root and key in FORBIDDEN_ROOTS:
            raise SystemExit(f"design_updates cannot update {key}")
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            deep_merge(dst[key], value, root=False)
        else:
            dst[key] = deepcopy(value)
    return dst


def apply_fact(doc: dict[str, Any], fact: dict[str, Any]) -> str:
    parent, leaf = get_parent(doc, fact["path"])
    if "value" in fact:
        parent[leaf] = deepcopy(fact["value"])
        return f"set {fact['path']}"
    if "merge" in fact:
        value = fact["merge"]
        if not isinstance(value, dict):
            raise SystemExit(f"merge value must be object for {fact['path']}")
        current = parent.setdefault(leaf, {})
        if not isinstance(current, dict):
            raise SystemExit(f"cannot merge into non-object field: {fact['path']}")
        deep_merge(current, value, root=False)
        return f"merge {fact['path']}"
    if "append" in fact:
        current = parent.setdefault(leaf, [])
        if not isinstance(current, list):
            raise SystemExit(f"cannot append into non-list field: {fact['path']}")
        current.append(deepcopy(fact["append"]))
        return f"append {fact['path']}"
    if "extend" in fact:
        value = fact["extend"]
        if not isinstance(value, list):
            raise SystemExit(f"extend value must be list for {fact['path']}")
        current = parent.setdefault(leaf, [])
        if not isinstance(current, list):
            raise SystemExit(f"cannot extend non-list field: {fact['path']}")
        current.extend(deepcopy(value))
        return f"extend {fact['path']}"
    raise SystemExit(f"unreachable fact operation for {fact['path']}")


def compact_json(value: Any) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def evidence_summary(evidence: Any) -> str:
    if isinstance(evidence, str):
        return evidence
    if isinstance(evidence, dict):
        return compact_json(evidence)
    if isinstance(evidence, list):
        return "; ".join(evidence_summary(item) for item in evidence[:4])
    return compact_json(evidence)


def promoted_entry(result: dict[str, Any], applied: list[str]) -> dict[str, Any]:
    return {
        "date": date.today().isoformat(),
        "topic": result.get("topic", ""),
        "stage": result.get("stage", ""),
        "status": result.get("status", ""),
        "summary": result.get("summary", ""),
        "evidence": result.get("evidence", []),
        "applied_updates": applied,
    }


def update_design_json(design: dict[str, Any], result: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    out = deepcopy(design)
    applied: list[str] = []
    design_updates = result.get("design_updates") or {}
    if design_updates:
        deep_merge(out, deepcopy(design_updates))
        applied.append("merge design_updates")

    for fact in result.get("verified_facts") or []:
        applied.append(apply_fact(out, fact))

    out["updated_at"] = date.today().isoformat()
    workflow = out.setdefault("workflow", {})
    history = workflow.setdefault("history", [])
    if isinstance(history, list):
        stage = result.get("stage", "")
        summary = result.get("summary", "")
        history_line = f"promoted {stage} stage result"
        if summary:
            history_line += f": {summary}"
        if history_line not in history:
            history.append(history_line)

    learning = out.setdefault("learning_validation", {})
    promoted = learning.setdefault("promoted_stage_results", [])
    if not isinstance(promoted, list):
        raise SystemExit("design.learning_validation.promoted_stage_results must be a list")
    entry = promoted_entry(result, applied)
    promoted[:] = [
        old
        for old in promoted
        if not (old.get("topic") == entry["topic"] and old.get("stage") == entry["stage"])
    ]
    promoted.append(entry)
    return out, applied


def render_auto_block(design: dict[str, Any]) -> str:
    entries = (
        design.get("learning_validation", {})
        .get("promoted_stage_results", [])
    )
    lines = [
        AUTO_START,
        "## 自动提升的学习阶段结果",
        "",
        "> 本节由 `promote_design_facts.py` 维护。只记录已通过阶段验证并带证据的事实摘要。",
        "",
    ]
    if not entries:
        lines.append("暂无。")
    else:
        lines.extend(["| 日期 | Topic | Stage | 摘要 | 证据 |", "|------|-------|-------|------|------|"])
        for entry in entries:
            lines.append(
                "| {date} | `{topic}` | `{stage}` | {summary} | {evidence} |".format(
                    date=entry.get("date", ""),
                    topic=entry.get("topic", ""),
                    stage=entry.get("stage", ""),
                    summary=str(entry.get("summary", "")).replace("|", "\\|"),
                    evidence=evidence_summary(entry.get("evidence", "")).replace("|", "\\|"),
                )
            )
    lines.append(AUTO_END)
    return "\n".join(lines) + "\n"


def replace_auto_block(text: str, block: str) -> str:
    start = text.find(AUTO_START)
    end = text.find(AUTO_END)
    if start != -1 and end != -1 and end > start:
        end += len(AUTO_END)
        return text[:start].rstrip() + "\n\n" + block + text[end:].lstrip()
    return text.rstrip() + "\n\n---\n\n" + block


def update_markdown(path: Path, design: dict[str, Any]) -> None:
    if path.exists():
        text = path.read_text(encoding="utf-8")
    else:
        text = f"# 算子设计：{design.get('title', design.get('op', 'unknown'))}\n"
    path.write_text(replace_auto_block(text, render_auto_block(design)), encoding="utf-8")


def append_learned_patterns(path: Path, result: dict[str, Any], applied: list[str]) -> None:
    if not path.exists():
        return
    stage = re.escape(str(result.get("stage", "")))
    marker_re = re.compile(
        rf"<!-- promoted-stage:{stage}(?::\d{{4}}-\d{{2}}-\d{{2}})? -->"
    )
    marker = f"<!-- promoted-stage:{result.get('stage')} -->"
    existing = path.read_text(encoding="utf-8")
    if marker_re.search(existing):
        return
    lines = [
        "",
        marker,
        f"## 已提升的设计事实：{result.get('stage')}",
        "",
        f"- date: `{date.today().isoformat()}`",
        f"- status: `{result.get('status')}`",
        f"- summary: {result.get('summary', '')}",
        f"- evidence: {evidence_summary(result.get('evidence', []))}",
        f"- applied updates: {', '.join(applied)}",
        "",
    ]
    with path.open("a", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Promote passing stage facts into design.json/design.md"
    )
    parser.add_argument("--op", required=True)
    parser.add_argument("--topic", required=True, help="op_learning topic, e.g. gemm/pvc-smallk-fp16-fp32")
    parser.add_argument("--stage-result", required=True)
    parser.add_argument("--stage", default="", help="Optional expected stage name")
    parser.add_argument(
        "--backend",
        default=backend_profiles.DEFAULT_BACKEND,
        choices=sorted(backend_profiles.BACKENDS),
        help="Backend profile (controls default demo-root)",
    )
    parser.add_argument(
        "--demo-root",
        default="",
        help="Demo root directory (defaults to backend profile's default_demo_root)",
    )
    parser.add_argument("--design", default="", help="Override design.json path")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-md", action="store_true", help="Do not update design.md auto block")
    parser.add_argument("--no-learned", action="store_true", help="Do not append learned_patterns.md")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    topic = validate_topic(args.topic)
    backend_profile = backend_profiles.get_backend(args.backend, demo_root_override=args.demo_root)
    demo_root_str = backend_profile["default_demo_root"]
    demo_root = Path(demo_root_str).expanduser().resolve()
    paths = Paths(demo_root=demo_root, op=args.op, topic=topic)
    design_path = Path(args.design).expanduser().resolve() if args.design else paths.design_json
    result_path = Path(args.stage_result).expanduser().resolve()

    result = load_json(result_path)
    validate_promotable_stage_result(
        result,
        op=args.op,
        topic=topic,
        stage=args.stage or None,
        backend=args.backend,
    )
    result.setdefault("op", args.op)
    result.setdefault("target_op", args.op)
    result.setdefault("topic", topic)

    design = load_json(design_path)
    if design.get("op") and design["op"] != args.op:
        raise SystemExit(
            f"design op mismatch: expected {args.op}, got {design.get('op')}"
        )
    updated, applied = update_design_json(design, result)

    payload = {
        "op": args.op,
        "topic": topic,
        "stage": result.get("stage"),
        "dry_run": args.dry_run,
        "design_json": str(design_path),
        "design_md": str(paths.design_md),
        "learned_patterns": str(paths.learned_patterns),
        "applied_updates": applied,
    }

    if not args.dry_run:
        design_path.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if not args.no_md:
            update_markdown(paths.design_md, updated)
        if not args.no_learned:
            append_learned_patterns(paths.learned_patterns, result, applied)

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        action = "would promote" if args.dry_run else "promoted"
        print(f"{action} {result.get('stage')} -> {design_path}")
        for item in applied:
            print(f"  - {item}")
        if not args.no_md:
            print(f"updated design.md auto block: {paths.design_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
