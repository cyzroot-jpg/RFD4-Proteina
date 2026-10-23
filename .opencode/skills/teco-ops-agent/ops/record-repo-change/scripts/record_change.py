#!/usr/bin/env python3
"""Create a concise repository bug-fix or feature-support record."""

from __future__ import annotations

import argparse
import json
import re
from datetime import date as date_type
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_RECORD_ROOT = REPO_ROOT / "docs" / "问题记录"
MAX_TEXT_LENGTH = 300


def compact(value: str, *, field: str, max_length: int = MAX_TEXT_LENGTH) -> str:
    text = " ".join(value.split())
    if not text:
        raise ValueError(f"{field} must not be empty")
    if len(text) > max_length:
        raise ValueError(f"{field} must not exceed {max_length} characters")
    return text


def normalize_date(value: str) -> str:
    try:
        return date_type.fromisoformat(value).isoformat()
    except ValueError as exc:
        raise ValueError("date must use YYYY-MM-DD") from exc


def monthly_record_path(record_root: Path, record_date: str) -> Path:
    return record_root / f"{record_date[:7]}.md"


def next_record_id(record_path: Path, record_date: str) -> str:
    month = record_date[:7].replace("-", "")
    pattern = re.compile(rf"^## CR-{month}-(\d{{3}})\b", re.MULTILINE)
    numbers = []
    if record_path.is_file():
        numbers = [
            int(match.group(1))
            for match in pattern.finditer(record_path.read_text(encoding="utf-8"))
        ]
    return f"CR-{month}-{max(numbers, default=0) + 1:03d}"


def portable_file(value: str) -> str:
    text = compact(value, field="file", max_length=240)
    path = Path(text).expanduser()
    candidate = path if path.is_absolute() else REPO_ROOT / path
    try:
        return str(candidate.resolve().relative_to(REPO_ROOT))
    except ValueError as exc:
        raise ValueError(f"file must be inside repository: {value}") from exc


def portable_solution_doc(value: str, record_root: Path) -> str:
    text = compact(value, field="solution_doc", max_length=240)
    path = Path(text).expanduser()
    if path.is_absolute():
        candidate = path.resolve()
    else:
        repo_candidate = (REPO_ROOT / path).resolve()
        record_candidate = (record_root / path).resolve()
        candidate = repo_candidate if repo_candidate.is_file() else record_candidate

    solution_root = (record_root / "核心方案").resolve()
    try:
        relative_path = candidate.relative_to(solution_root)
    except ValueError as exc:
        raise ValueError("solution_doc must be inside record-root/核心方案") from exc
    if candidate.suffix.lower() != ".md":
        raise ValueError("solution_doc must be a Markdown file")
    if not candidate.is_file():
        raise ValueError(f"solution_doc does not exist: {value}")
    return (Path("核心方案") / relative_path).as_posix()


def render_entry(
    *,
    record_id: str,
    record_date: str,
    change_type: str,
    title: str,
    problem: str,
    solution: str,
    verification: str,
    files: list[str],
    solution_doc: str | None = None,
) -> str:
    type_label = "问题修复" if change_type == "bugfix" else "功能支持"
    problem_label = "核心问题" if change_type == "bugfix" else "核心需求"
    lines = [
        f"## {record_id} {record_date} {title}",
        "",
        f"- 类型：{type_label}",
        f"- {problem_label}：{problem}",
        (
            f"- 核心方案：{solution}；详见 [详细方案]({solution_doc})"
            if solution_doc
            else f"- 核心方案：{solution}"
        ),
        f"- 验证：{verification}",
    ]
    if files:
        lines.append("- 关联文件：" + "、".join(f"`{path}`" for path in files))
    return "\n".join(lines) + "\n"


def monthly_header(record_date: str) -> str:
    return f"# {record_date[:7]} 仓库问题与功能记录\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--type", required=True, choices=["bugfix", "feature"])
    parser.add_argument("--title", required=True)
    parser.add_argument("--problem", required=True, help="Core problem or feature need")
    parser.add_argument("--solution", required=True)
    parser.add_argument("--verification", required=True)
    parser.add_argument("--file", action="append", default=[])
    parser.add_argument(
        "--solution-doc",
        help="Existing Markdown detail under record-root/核心方案",
    )
    parser.add_argument("--date", default=date_type.today().isoformat())
    parser.add_argument("--record-root", type=Path, default=DEFAULT_RECORD_ROOT)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        record_date = normalize_date(args.date)
        title = compact(args.title, field="title", max_length=80)
        problem = compact(args.problem, field="problem")
        solution = compact(args.solution, field="solution")
        verification = compact(args.verification, field="verification")
        if len(args.file) > 8:
            raise ValueError("at most 8 related files are allowed")
        files = list(dict.fromkeys(portable_file(value) for value in args.file))
    except ValueError as exc:
        parser.error(str(exc))

    record_root = args.record_root.expanduser().resolve()
    try:
        solution_doc = (
            portable_solution_doc(args.solution_doc, record_root)
            if args.solution_doc
            else None
        )
    except ValueError as exc:
        parser.error(str(exc))

    record_path = monthly_record_path(record_root, record_date)
    record_id = next_record_id(record_path, record_date)
    content = render_entry(
        record_id=record_id,
        record_date=record_date,
        change_type=args.type,
        title=title,
        problem=problem,
        solution=solution,
        verification=verification,
        files=files,
        solution_doc=solution_doc,
    )

    if not args.dry_run:
        record_root.mkdir(parents=True, exist_ok=True)
        if record_path.is_file():
            existing = record_path.read_text(encoding="utf-8").rstrip()
            monthly_content = f"{existing}\n\n{content}"
        else:
            monthly_content = f"{monthly_header(record_date)}\n{content}"
        record_path.write_text(monthly_content, encoding="utf-8")

    payload = {
        "record_id": record_id,
        "record_path": str(record_path),
        "dry_run": args.dry_run,
    }
    if args.json:
        if args.dry_run:
            payload["content"] = content
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    elif args.dry_run:
        print(content, end="")
    else:
        print(f"wrote {record_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
