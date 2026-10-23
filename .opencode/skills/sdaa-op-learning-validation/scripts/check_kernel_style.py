#!/usr/bin/env python3
"""Lightweight kernel style checks not covered by cpplint/clang-format."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


KERNEL_EXTENSIONS = {".swcu", ".h", ".hpp", ".cpp"}
MULTI_SIMD_RE = re.compile(r"\bSIMD_(?:LOAD|STORE)\s*\([^;]+;\s*SIMD_(?:LOAD|STORE)\s*\(")
SINGLE_LINE_IF_RE = re.compile(r"^\s*if\s*\([^)]*\)\s+[^/{;][^;]*;\s*(?://.*)?$")


def git_changed_files(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git status failed")

    files: list[Path] = []
    for line in result.stdout.splitlines():
        if not line.strip() or len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        full_path = root / path
        if full_path.suffix in KERNEL_EXTENSIONS and full_path.is_file():
            files.append(full_path)
    return sorted(set(files))


def strip_line_comment(line: str) -> str:
    in_string = False
    escaped = False
    for i in range(len(line) - 1):
        ch = line[i]
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if not in_string and line[i : i + 2] == "//":
            return line[:i]
    return line


def statement_semicolon_count(code: str) -> int:
    count = 0
    depth = 0
    in_string = False
    escaped = False
    for ch in code:
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch == "(":
            depth += 1
        elif ch == ")" and depth > 0:
            depth -= 1
        elif ch == ";" and depth == 0:
            count += 1
    return count


def should_skip_line(code: str) -> bool:
    stripped = code.strip()
    if not stripped:
        return True
    if stripped.startswith(("//", "*", "/*")):
        return True
    if stripped.startswith("#"):
        return True
    if stripped.startswith("do ") or stripped == "do":
        return True
    return False


def check_file(path: Path) -> list[str]:
    warnings: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError as exc:
        return [f"{path}: failed to read: {exc}"]

    for lineno, line in enumerate(lines, start=1):
        code = strip_line_comment(line)
        if should_skip_line(code):
            continue
        if MULTI_SIMD_RE.search(code):
            warnings.append(
                f"{path}:{lineno}: multiple SIMD_LOAD/STORE calls on one line"
            )
            continue
        if statement_semicolon_count(code) > 1:
            warnings.append(
                f"{path}:{lineno}: multiple statements on one line"
            )
            continue
        if SINGLE_LINE_IF_RE.match(line):
            warnings.append(
                f"{path}:{lineno}: single-line if body; use braces and a separate line"
            )
    return warnings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help="Files or directories to check. Defaults to changed/untracked files in --repo.",
    )
    parser.add_argument(
        "--repo",
        default=".",
        help="Git repository root used when no paths are passed.",
    )
    return parser.parse_args()


def collect_paths(args: argparse.Namespace) -> list[Path]:
    if not args.paths:
        return git_changed_files(Path(args.repo).resolve())

    paths: list[Path] = []
    for raw_path in args.paths:
        path = Path(raw_path).resolve()
        if path.is_dir():
            paths.extend(
                item for item in path.rglob("*")
                if item.suffix in KERNEL_EXTENSIONS and item.is_file()
            )
        elif path.suffix in KERNEL_EXTENSIONS and path.is_file():
            paths.append(path)
    return sorted(set(paths))


def main() -> int:
    args = parse_args()
    try:
        paths = collect_paths(args)
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        return 2

    warnings: list[str] = []
    for path in paths:
        warnings.extend(check_file(path))

    if warnings:
        print("Kernel style check failed:")
        for warning in warnings:
            print(f"- {warning}")
        return 1

    print(f"Kernel style check passed ({len(paths)} files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
