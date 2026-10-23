"""Resolve the teco-ops-wiki root for bundled scripts."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _looks_like_wiki_root(path: Path) -> bool:
    return (path / "data" / "tags.yaml").is_file() and (path / "wiki").is_dir()


def _error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(2)


def resolve_wiki_root() -> Path:
    env = os.environ.get("TECO_OPS_WIKI_ROOT")
    if env:
        candidate = Path(env).expanduser().resolve()
        if _looks_like_wiki_root(candidate):
            return candidate
        _error(f"TECO_OPS_WIKI_ROOT={env!r} is not a valid teco-ops-wiki root")

    default_root = Path(__file__).resolve().parent.parent
    if _looks_like_wiki_root(default_root):
        return default_root

    for start in (Path(__file__).resolve().parent, Path.cwd().resolve()):
        for candidate in [start, *start.parents]:
            if _looks_like_wiki_root(candidate):
                return candidate

    _error("Could not locate teco-ops-wiki root; expected data/tags.yaml and wiki/")
    return Path()


WIKI_ROOT = resolve_wiki_root()
