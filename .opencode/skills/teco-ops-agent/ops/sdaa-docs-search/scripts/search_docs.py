#!/usr/bin/env python3
"""Search local docs index for sdaa-docs-search."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_INDEX = SKILL_DIR / ".index" / "docs_index.json"


def load_index(path: Path) -> list[dict]:
    if not path.exists():
        raise FileNotFoundError(
            f"Index not found: {path}\nRun: python3 {SCRIPT_DIR / 'build_index.py'}"
        )
    data = json.loads(path.read_text(encoding="utf-8"))
    return data.get("entries", [])


def search(entries: list[dict], query: str, top: int) -> list[dict]:
    q = query.lower()
    hits = [e for e in entries if q in e.get("text", "").lower() or q in e.get("path", "").lower()]
    return hits[:top]


def main() -> int:
    parser = argparse.ArgumentParser(description="Search local SDAA docs index")
    parser.add_argument("--query", "-q", required=True, help="Search keyword")
    parser.add_argument("--top", type=int, default=10, help="Max results")
    parser.add_argument("--index", default=str(DEFAULT_INDEX), help="Index JSON path")
    parser.add_argument("--json", action="store_true", help="Print JSON output")
    args = parser.parse_args()

    try:
        entries = load_index(Path(args.index))
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1

    hits = search(entries, args.query, args.top)
    result = {"query": args.query, "count": len(hits), "hits": hits}

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        if not hits:
            print(f"No hits for: {args.query}")
            return 1
        for hit in hits:
            print(f"{hit['path']}:{hit['line']}: {hit['text'].strip()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
