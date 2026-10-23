#!/usr/bin/env python3
"""Limit swdnn_test_ops CMake to compile a single op's .swcu (debug helper)."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT / "swdnn_test_ops"
BACKUP_SUFFIX = ".scope_cmake_backup"

GLOB_DEFAULT = (
    'file(GLOB_RECURSE ALL_SWCU_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" '
    '"${CMAKE_CURRENT_SOURCE_DIR}/src/*.swcu")'
)
MARKER_BEGIN = "# SCOPE_OP_BEGIN"
MARKER_END = "# SCOPE_OP_END"


def validate_op(op: str) -> None:
    if not re.match(r"^[a-z][a-z0-9_]*$", op):
        raise SystemExit(f"invalid --op '{op}'")


def scoped_glob(op: str) -> str:
    return (
        f'set(ALL_SWCU_FILES "src/{op}/{op}.swcu")'
    )


def patch_cmake(cmake: Path, op: str, *, ensure_baseline: bool) -> None:
    text = cmake.read_text(encoding="utf-8")
    backup = cmake.with_suffix(cmake.suffix + BACKUP_SUFFIX)
    if not backup.exists():
        backup.write_text(text, encoding="utf-8")

    if ensure_baseline:
        sys.path.insert(0, str(SCRIPT_DIR))
        from cmake_baseline import ensure_cmake_baseline  # noqa: WPS433

        changes = ensure_cmake_baseline(cmake)
        if changes:
            print("cmake baseline:", ", ".join(changes))

    block = f"{MARKER_BEGIN} {op}\n{scoped_glob(op)}\n{MARKER_END}\n"
    text = cmake.read_text(encoding="utf-8")
    pattern = re.compile(
        rf"{re.escape(MARKER_BEGIN)}.*?{re.escape(MARKER_END)}\n",
        re.DOTALL,
    )
    if pattern.search(text):
        text = pattern.sub(block, text)
    elif GLOB_DEFAULT in text:
        text = text.replace(GLOB_DEFAULT, block)
    else:
        raise SystemExit("cannot find ALL_SWCU_FILES glob in CMakeLists.txt")

    cmake.write_text(text, encoding="utf-8")
    print(f"scoped CMake to src/{op}/*.swcu (backup: {backup.name})")


def restore_cmake(cmake: Path) -> None:
    backup = cmake.with_suffix(cmake.suffix + BACKUP_SUFFIX)
    if not backup.is_file():
        raise SystemExit(f"no backup found: {backup}")
    cmake.write_text(backup.read_text(encoding="utf-8"), encoding="utf-8")
    backup.unlink()
    print(f"restored {cmake} from backup")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scope swdnn_test_ops CMake to one operator (workaround broken sibling .swcu)"
    )
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument("--op", help="Operator directory name under src/")
    parser.add_argument("--restore", action="store_true", help="Restore CMakeLists.txt from backup")
    parser.add_argument(
        "--no-cmake-baseline",
        action="store_true",
        help="Skip cmake 4.x / tecocc / LINK_FLAGS baseline patches",
    )
    args = parser.parse_args()

    demo_root = Path(args.demo_root).resolve()
    cmake = demo_root / "CMakeLists.txt"
    if not cmake.is_file():
        raise SystemExit(f"CMakeLists.txt not found: {cmake}")

    if args.restore:
        restore_cmake(cmake)
        return 0

    if not args.op:
        raise SystemExit("--op required unless --restore")
    validate_op(args.op)
    swcu = demo_root / "src" / args.op
    if not swcu.is_dir():
        raise SystemExit(f"src/{args.op}/ not found under {demo_root}")

    patch_cmake(cmake, args.op, ensure_baseline=not args.no_cmake_baseline)
    print(f"next: cd {demo_root} && rm -rf build && ./run.sh {args.op}")
    print(f"restore: python3 {SCRIPT_DIR / 'scope_cmake_op.py'} --restore --demo-root {demo_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
