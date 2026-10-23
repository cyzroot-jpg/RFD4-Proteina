from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

import record_change  # noqa: E402


class RecordChangeTests(unittest.TestCase):
    def test_render_is_concise(self) -> None:
        content = record_change.render_entry(
            record_id="CR-202607-001",
            record_date="2026-07-15",
            change_type="bugfix",
            title="Stop hook JSON 输出修复",
            problem="stdout 输出普通文本。",
            solution="统一输出 Codex hook JSON。",
            verification="hook stdout 可被 json.loads 解析。",
            files=[".codex/config.toml"],
        )
        self.assertLessEqual(len(content.splitlines()), 8)
        self.assertIn("核心问题", content)
        self.assertIn("核心方案", content)

    def test_relative_file_cannot_escape_repository(self) -> None:
        with self.assertRaises(ValueError):
            record_change.portable_file("../../outside.txt")

    def test_cli_creates_sequential_records(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            command = [
                sys.executable,
                str(SCRIPT_DIR / "record_change.py"),
                "--type",
                "feature",
                "--title",
                "轻量变更记录",
                "--problem",
                "仓库缺少简短的功能变更记录。",
                "--solution",
                "新增生成脚本。",
                "--verification",
                "单测通过。",
                "--date",
                "2026-07-15",
                "--record-root",
                root,
                "--json",
            ]
            first = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            second = subprocess.run(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            monthly_path = Path(root) / "2026-07.md"
            monthly_content = monthly_path.read_text(encoding="utf-8")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(json.loads(first.stdout)["record_id"], "CR-202607-001")
        self.assertEqual(json.loads(second.stdout)["record_id"], "CR-202607-002")
        self.assertEqual(monthly_content.count("# 2026-07 仓库问题与功能记录"), 1)
        self.assertIn("## CR-202607-001", monthly_content)
        self.assertIn("## CR-202607-002", monthly_content)

    def test_solution_doc_must_exist_under_core_solution_directory(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            record_root = Path(root)
            solution_root = record_root / "核心方案"
            solution_root.mkdir()
            solution_path = solution_root / "hook-json.md"
            solution_path.write_text("# Hook JSON\n", encoding="utf-8")

            relative_path = record_change.portable_solution_doc(
                str(solution_path), record_root
            )
            content = record_change.render_entry(
                record_id="CR-202607-001",
                record_date="2026-07-15",
                change_type="bugfix",
                title="Stop hook JSON 输出修复",
                problem="stdout 输出普通文本。",
                solution="统一输出 Codex hook JSON。",
                verification="JSON 解析通过。",
                files=[],
                solution_doc=relative_path,
            )

            self.assertEqual(relative_path, "核心方案/hook-json.md")
            self.assertIn("[详细方案](核心方案/hook-json.md)", content)
            with self.assertRaises(ValueError):
                record_change.portable_solution_doc(__file__, record_root)


if __name__ == "__main__":
    unittest.main()
