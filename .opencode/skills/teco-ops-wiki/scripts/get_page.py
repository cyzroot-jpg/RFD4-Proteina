#!/usr/bin/env python3
"""Fetch a teco-ops-wiki page by id or path."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _wiki_root import WIKI_ROOT  # noqa: E402


def load_frontmatter(path: Path):
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)", text, re.DOTALL)
    if not match:
        return {}, text
    return yaml.safe_load(match.group(1)) or {}, match.group(2)


def all_markdown_pages():
    for subdir in ("sources", "wiki", "docs", "references", "queries"):
        base = WIKI_ROOT / subdir
        if base.exists():
            yield from base.rglob("*.md")


def resolve_page(selector: str) -> Path | None:
    candidate = WIKI_ROOT / selector
    if candidate.is_file():
        return candidate
    if not selector.endswith(".md"):
        candidate = WIKI_ROOT / f"{selector}.md"
        if candidate.is_file():
            return candidate
    for page in all_markdown_pages():
        try:
            fm, _ = load_frontmatter(page)
        except Exception:
            continue
        if fm.get("id") == selector:
            return page
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch a teco-ops-wiki page")
    parser.add_argument("selector", help="Page id or relative path")
    parser.add_argument("--body-only", action="store_true")
    parser.add_argument("--frontmatter-only", action="store_true")
    parser.add_argument("--follow-sources", action="store_true")
    args = parser.parse_args()

    page = resolve_page(args.selector)
    if page is None:
        print(f"No page found for {args.selector!r}", file=sys.stderr)
        sys.exit(1)
    text = page.read_text(encoding="utf-8")
    fm, body = load_frontmatter(page)
    if args.frontmatter_only:
        print(yaml.safe_dump(fm, allow_unicode=True, sort_keys=False).strip())
        return
    if args.body_only:
        print(body)
        return
    print(text)

    if args.follow_sources:
        sources = fm.get("sources") or []
        if sources:
            print("\n---\n# Followed Sources\n")
        for source_id in sources:
            source_page = resolve_page(str(source_id))
            if source_page is None:
                print(f"## {source_id}\n\nMissing source page.\n")
                continue
            sfm, sbody = load_frontmatter(source_page)
            print(f"## {source_id} ({source_page.relative_to(WIKI_ROOT)})\n")
            print(sbody[:3000].rstrip())
            print()


if __name__ == "__main__":
    main()
