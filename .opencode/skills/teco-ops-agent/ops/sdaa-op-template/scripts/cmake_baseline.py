#!/usr/bin/env python3
"""Idempotent CMake baseline fixes for swdnn_test_ops on CMake 4.x + tecocc."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

MIN_CMAKE_LINE = "cmake_minimum_required(VERSION 3.10)"
CMP0210_BLOCK = """if(POLICY CMP0210)
    cmake_policy(SET CMP0210 OLD)
endif()
"""
TECocc_BLOCK = """# set compiler to tecocc before project() so modern CMake detects the toolchain correctly.
set(CMAKE_CXX_COMPILER "tecocc" CACHE STRING "SDAA compiler" FORCE)
"""
LINK_FLAGS_BLOCK = """set_target_properties(${PROJECT_NAME} PROPERTIES
    LINK_FLAGS "${TEST_CXX_FLAGS} --sdaa-link -shared -fuse-ld=lld")"""


def ensure_cmake_baseline(cmake: Path, *, dry_run: bool = False) -> list[str]:
    if not cmake.is_file():
        raise FileNotFoundError(cmake)

    text = cmake.read_text(encoding="utf-8")
    original = text
    changes: list[str] = []

    version_match = re.search(
        r"cmake_minimum_required\s*\(\s*VERSION\s+([0-9]+)\.([0-9]+)", text
    )
    if version_match:
        major, minor = int(version_match.group(1)), int(version_match.group(2))
        if major < 3 or (major == 3 and minor < 10):
            text = re.sub(
                r"cmake_minimum_required\s*\(\s*VERSION\s+[0-9.]+\s*\)",
                MIN_CMAKE_LINE,
                text,
                count=1,
            )
            changes.append("bump cmake_minimum_required to 3.10")

    if "CMP0210" not in text and MIN_CMAKE_LINE in text:
        text = text.replace(MIN_CMAKE_LINE + "\n", MIN_CMAKE_LINE + "\n\n" + CMP0210_BLOCK, 1)
        changes.append("set CMP0210 OLD")
    elif "CMP0210" not in text:
        first_line = text.split("\n", 1)[0]
        if first_line.startswith("cmake_minimum_required"):
            text = text.replace(first_line + "\n", first_line + "\n\n" + CMP0210_BLOCK, 1)
            changes.append("set CMP0210 OLD")

    if 'CMAKE_CXX_COMPILER "tecocc"' not in text and "project (" in text:
        text = text.replace("project (swdnn_test)", TECocc_BLOCK + "project (swdnn_test)", 1)
        if TECocc_BLOCK not in text:
            text = text.replace("project(swdnn_test)", TECocc_BLOCK + "project(swdnn_test)", 1)
        changes.append("force CMAKE_CXX_COMPILER=tecocc before project()")

    if "LINK_FLAGS" not in text or "--sdaa-link" not in text:
        anchor = "set_target_properties(${PROJECT_NAME} PROPERTIES LINKER_LANGUAGE CXX)"
        if anchor in text and LINK_FLAGS_BLOCK not in text:
            text = text.replace(
                anchor,
                anchor + "\n" + LINK_FLAGS_BLOCK,
                1,
            )
            changes.append("add target LINK_FLAGS for .swcu link")

    if text != original and not dry_run:
        cmake.write_text(text, encoding="utf-8")

    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply idempotent swdnn_test_ops CMake baseline fixes")
    parser.add_argument("--demo-root", default=str(Path(__file__).resolve().parents[2] / "swdnn_test_ops"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).resolve()
    cmake = demo_root / "CMakeLists.txt"
    if not cmake.is_file():
        raise SystemExit(f"CMakeLists.txt not found: {cmake}")

    changes = ensure_cmake_baseline(cmake, dry_run=args.dry_run)
    payload = {"cmake": str(cmake), "changes": changes, "dry_run": args.dry_run}
    if args.json:
        print(json.dumps(payload, indent=2))
    elif changes:
        print("cmake baseline:", ", ".join(changes))
    else:
        print("cmake baseline: already OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
