#!/usr/bin/env python3
"""Unified query tool for teco-ops-wiki."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _wiki_root import WIKI_ROOT  # noqa: E402


_ALIASES = None


def load_aliases() -> dict[str, str]:
    global _ALIASES
    if _ALIASES is not None:
        return _ALIASES
    out: dict[str, str] = {}
    path = WIKI_ROOT / "data" / "aliases.yaml"
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        raw = {}
    for canonical, variants in raw.items():
        if not isinstance(canonical, str):
            continue
        out[canonical.lower()] = canonical
        for variant in variants or []:
            if isinstance(variant, str):
                out[variant.lower()] = canonical
    _ALIASES = out
    return out


def expand_keyword(word: str) -> list[str]:
    canonical = load_aliases().get(word.lower())
    if canonical and canonical.lower() != word.lower():
        return [word, canonical]
    return [word]


def load_frontmatter(path: Path):
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return None, None
    match = re.match(r"^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)", text, re.DOTALL)
    if not match:
        return None, None
    try:
        fm = yaml.safe_load(match.group(1))
    except yaml.YAMLError:
        return None, None
    if not isinstance(fm, dict):
        return None, None
    return fm, match.group(2)


def detect_page_type(fm: dict, path: str) -> str:
    if "type" in fm:
        return f"wiki-{fm['type']}"
    if path.startswith("sources/local/"):
        return "source-local"
    if path.startswith("docs/"):
        return "doc"
    return "unknown"


def load_pages() -> list[dict]:
    pages = []
    for subdir in ("sources", "wiki", "docs"):
        base = WIKI_ROOT / subdir
        if not base.exists():
            continue
        for md in base.rglob("*.md"):
            fm, body = load_frontmatter(md)
            if fm is None:
                continue
            rel = str(md.relative_to(WIKI_ROOT))
            pages.append({"path": rel, "fm": fm, "body": body or "", "_ptype": detect_page_type(fm, rel)})
    return pages


def field_values(fm: dict) -> set[str]:
    values: set[str] = set()
    for key in ("tags", "techniques", "hardware_features", "kernel_types", "languages", "symptoms", "architectures"):
        values.update(str(v) for v in (fm.get(key) or []))
    return values


def filter_pages(pages: list[dict], args) -> list[dict]:
    out = []
    for page in pages:
        fm = page["fm"]
        values = field_values(fm)
        if args.type and not page["_ptype"].endswith(args.type) and page["_ptype"] != args.type:
            continue
        if args.tag:
            variants = {v.lower() for v in expand_keyword(args.tag)}
            if not any(v.lower() in variants for v in values):
                continue
        if args.architecture:
            variants = {v.lower() for v in expand_keyword(args.architecture)}
            archs = {str(v).lower() for v in (fm.get("architectures") or [])}
            if not archs & variants:
                continue
        if args.symptom:
            variants = {v.lower() for v in expand_keyword(args.symptom)}
            symptoms = {str(v).lower() for v in (fm.get("symptoms") or [])}
            if not symptoms & variants:
                continue
        if args.confidence and str(fm.get("confidence", "")) != args.confidence:
            continue
        out.append(page)
    return out


def type_rank(ptype: str) -> int:
    # Curated wiki content ranks above raw source material so faceted queries
    # surface guidance before reference dumps. Doc parts are still returned.
    if ptype.startswith("wiki-source-doc-part"):
        return 4
    if ptype.startswith("wiki-source-doc") or ptype == "doc":
        return 3
    if ptype.startswith("wiki-source"):  # source-repo / source-op
        return 2
    if ptype == "source-local":
        return 2
    if ptype.startswith("wiki-"):        # hardware/technique/kernel/pattern/...
        return 0
    return 5


def score(page: dict, keywords: list[str]) -> int:
    fm = page["fm"]
    title = str(fm.get("title", "")).lower()
    values = " ".join(field_values(fm)).lower()
    body = page["body"].lower()
    total = 0
    for keyword in keywords:
        best = 0
        for variant in expand_keyword(keyword):
            v = variant.lower()
            s = 0
            if v in title:
                s += 10
            if v in values:
                s += 5
            s += min(body.count(v), 3)
            best = max(best, s)
        total += best
    return total


def format_page(page: dict, compact: bool) -> str:
    fm = page["fm"]
    pid = fm.get("id", "")
    title = fm.get("title", "Untitled")
    if compact:
        return f"  [{page['_ptype']}] {pid}: {title}  ({page['path']})"
    lines = [
        f"## {title}",
        f"- **id**: `{pid}`",
        f"- **type**: `{page['_ptype']}`",
        f"- **path**: `{page['path']}`",
    ]
    for key in ("architectures", "confidence", "reproducibility", "tags", "symptoms", "candidate_techniques", "sources"):
        if fm.get(key):
            lines.append(f"- **{key}**: {fm[key]}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Query teco-ops-wiki")
    parser.add_argument("query", nargs="*", help="Free-text keywords")
    parser.add_argument("--type", help="Page type: hardware, technique, pattern, kernel, local, doc")
    parser.add_argument("--tag", help="Tag or alias")
    parser.add_argument("--architecture", help="Architecture such as teco-t1")
    parser.add_argument("--symptom", help="Pattern symptom")
    parser.add_argument("--confidence", help="Confidence filter")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--compact", action="store_true")
    parser.add_argument("--paths-only", action="store_true")
    args = parser.parse_args()

    pages = filter_pages(load_pages(), args)
    keywords = [tok for q in args.query for tok in re.split(r"\s+", q.strip()) if tok]
    if keywords:
        for page in pages:
            page["_score"] = score(page, keywords)
        pages = [p for p in pages if p["_score"] > 0]
        pages.sort(key=lambda p: (-p["_score"], type_rank(p["_ptype"]), p["path"]))
    else:
        pages.sort(key=lambda p: (type_rank(p["_ptype"]), p["path"]))
    pages = pages[: args.limit]

    if args.paths_only:
        for page in pages:
            print(page["path"])
        return
    if not pages:
        print("No matching pages.")
        return
    print(f"# {len(pages)} result(s)\n")
    for page in pages:
        print(format_page(page, args.compact))
        if not args.compact:
            print()


if __name__ == "__main__":
    main()
