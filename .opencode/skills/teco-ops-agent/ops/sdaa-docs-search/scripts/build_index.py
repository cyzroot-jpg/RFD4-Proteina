#!/usr/bin/env python3
"""Build a local JSON index for sdaa-docs-search."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_INDEX = SKILL_DIR / ".index" / "docs_index.json"

TEXT_SUFFIXES = {".md", ".h", ".hpp", ".c", ".cpp", ".swcu"}

PATH_BLOCKLIST = {"xuan", "kai", "tecoal", "tecocustom", "tecolmk"}


def repo_roots(explicit: str | None) -> list[Path]:
    if explicit:
        return [Path(explicit).expanduser().resolve()]
    # teco-ops-agent/../../ = workspace root
    agent_root = SKILL_DIR.parents[1]
    return [agent_root.parent, agent_root]


def corpus_globs(root: Path) -> list[Path]:
    patterns = [
        root / "teco-ops-agent/ops",
        root / "teco-ops-agent/docs",
        root / "teco-ops/teco",
        root / "teco-ops/common",
        root / "teco-ops/thirdparty",
        root / "sdaa-kernel-poilot/knowledge",
        root / "optest-agent/docs",
    ]
    sdk = Path("/opt/tecoai/include")
    if sdk.is_dir():
        patterns.append(sdk)
    teco_home = os.environ.get("TECOAI_HOME")
    if teco_home:
        patterns.append(Path(teco_home) / "include")
    return patterns


def classify(path: Path) -> str:
    text = str(path)
    if "teco-ops-agent/ops" in text and "/references/" in text:
        return "skill-ref"
    if "teco-ops-agent/docs" in text:
        return "project-doc"
    if "knowledge" in text:
        return "knowledge"
    if text.endswith(".h") or text.endswith(".hpp"):
        return "header"
    if "teco-ops/teco" in text:
        return "teco-ops"
    if "optest-agent/docs" in text:
        return "optest-doc"
    return "other"


def is_blocklisted(path: Path) -> bool:
    lower = path.name.lower()
    return any(kw in lower for kw in PATH_BLOCKLIST)


def iter_files(target: Path) -> list[Path]:
    if not target.exists():
        return []
    if target.is_file():
        return [target] if target.suffix.lower() in TEXT_SUFFIXES and not is_blocklisted(target) else []
    files: list[Path] = []
    for path in target.rglob("*"):
        if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES and not is_blocklisted(path):
            files.append(path)
    return files


def build_index(roots: list[Path]) -> list[dict]:
    entries: list[dict] = []
    seen: set[Path] = set()
    for root in roots:
        for target in corpus_globs(root):
            target = target.resolve() if target.exists() else target
            for path in iter_files(target):
                if path in seen:
                    continue
                seen.add(path)
                try:
                    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
                except OSError:
                    continue
                source = classify(path)
                for lineno, line in enumerate(lines, start=1):
                    stripped = line.strip()
                    if not stripped or stripped.startswith("//") and source == "header":
                        continue
                    entries.append(
                        {
                            "path": str(path),
                            "line": lineno,
                            "text": line[:500],
                            "source": source,
                        }
                    )
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description="Build local docs index for sdaa-docs-search")
    parser.add_argument("--root", default=None, help="Workspace root override")
    parser.add_argument("-o", "--output", default=str(DEFAULT_INDEX), help="Index output path")
    args = parser.parse_args()

    roots = repo_roots(args.root)
    entries = build_index(roots)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "roots": [str(r) for r in roots],
        "entry_count": len(entries),
        "entries": entries,
    }
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(entries)} lines to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
