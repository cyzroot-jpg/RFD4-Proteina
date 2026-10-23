#!/usr/bin/env python3
"""Codex Stop hook for learned-pattern and kernel-work guards."""

from __future__ import annotations

import json
import hashlib
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
PATTERN_PREFIX = "ops/sdaa-op-learning-validation/references/learned-patterns/"
EVIDENCE_REGISTRY = (
    "ops/sdaa-op-learning-validation/references/evidence/pattern-evidence.json"
)
VALIDATOR = REPO_ROOT / "ops" / "sdaa-op-learning-validation" / "scripts" / "validate_learned_patterns.py"
STATE_FILE_CANDIDATES = [
    REPO_ROOT / ".tmp" / "codex-hook-output" / "latest-kernel-work-preflight-state.json",
    Path("/tmp") / "teco-ops-agent-hooks" / "latest-kernel-work-preflight-state.json",
]
KERNEL_EXTENSIONS = {".swcu", ".h", ".hpp", ".cpp"}
STAGE_RESULT_RE = re.compile(r"^(?:[\w./-]+/)?op_learning/.+/stage_results/.+\.json$")
SIMD_TOKEN_RE = re.compile(r"\b(?:simd_|batch_|reduce_)\w*\b")
SCALAR_FLOAT_LOOP_RE = re.compile(
    r"\bfor\s*\([^)]*\)\s*\{(?:(?!\n\s*\}).){0,1200}\bfloat\s+[A-Za-z_]\w*\s*=",
    re.DOTALL,
)


def changed_knowledge_scope() -> list[str] | None:
    result = subprocess.run(
        ["git", "status", "--short", "--", PATTERN_PREFIX, EVIDENCE_REGISTRY],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return None

    paths: list[str] = []
    validate_all = False
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path == EVIDENCE_REGISTRY:
            validate_all = True
        elif path.endswith(".md") and path != PATTERN_PREFIX + "README.md":
            paths.append(path)
    if validate_all:
        return []
    return paths or None


def git_status(root: Path, prefix: str = "") -> dict[str, str]:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        return {}

    statuses: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if not line.strip() or len(line) < 4:
            continue
        status = line[:2]
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        full_path = root / path
        if full_path.is_file():
            digest = hashlib.sha256(full_path.read_bytes()).hexdigest()
            statuses[prefix + path] = f"{status}:{digest}"
        else:
            statuses[prefix + path] = f"{status}:missing"
    return statuses


def snapshot_status() -> dict[str, str]:
    statuses = git_status(REPO_ROOT)
    teco_ops = REPO_ROOT.parents[1] / "teco-ops"
    if teco_ops.is_dir():
        statuses.update(git_status(teco_ops, "teco-ops/"))
    return statuses


def read_preflight_state() -> dict | None:
    for path in STATE_FILE_CANDIDATES:
        if not path.is_file():
            continue
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None
    return None


def changed_since_preflight() -> list[str]:
    state = read_preflight_state()
    if not state:
        return []
    baseline = state.get("baseline_status")
    if not isinstance(baseline, dict):
        return []
    current = snapshot_status()
    changed = []
    for path, status in current.items():
        if baseline.get(path) != status:
            changed.append(path)
    for path in baseline:
        if path not in current:
            changed.append(path)
    return sorted(set(changed))


def is_kernel_file(path: str) -> bool:
    if Path(path).suffix not in KERNEL_EXTENSIONS:
        return False
    return path.startswith(
        (
            "teco-ops/teco/",
            "teco-ops/test/zoo/teco/",
            "ops/",
            "src/",
        )
    )


def repo_path(path: str) -> Path:
    return REPO_ROOT / path


def scalar_hotspot_warnings(kernel_paths: list[str]) -> list[str]:
    warnings: list[str] = []
    for path in kernel_paths:
        if not path.endswith(".swcu"):
            continue
        full_path = repo_path(path)
        if not full_path.is_file():
            continue
        text = full_path.read_text(encoding="utf-8", errors="ignore")
        if not SCALAR_FLOAT_LOOP_RE.search(text):
            continue
        if SIMD_TOKEN_RE.search(text):
            continue
        warnings.append(
            f"- `{path}` contains a float scalar loop but no SIMD/batch/reduce token. "
            "If this is a hot LDM loop, evaluate SIMD using `docs/共享知识库/SIMD使用手册-zh.md`; "
            "if it is only a tail/fallback, document that in the stage_result."
        )
    return warnings


def kernel_work_warnings() -> list[str]:
    changed = changed_since_preflight()
    if not changed:
        return []

    kernel_paths = [path for path in changed if is_kernel_file(path)]
    if not kernel_paths:
        return []

    stage_results = [path for path in changed if STAGE_RESULT_RE.match(path)]
    warnings = [
        "# Kernel Work Guard",
        "",
        "Kernel/source files changed after the latest operator/kernel preflight:",
        *[f"- `{path}`" for path in kernel_paths[:20]],
    ]
    if len(kernel_paths) > 20:
        warnings.append(f"- ... {len(kernel_paths) - 20} more")

    if not stage_results:
        warnings.extend([
            "",
            "No new or updated `<demo_root>/op_learning/**/stage_results/*.json` was detected since preflight.",
            "For optimization work, record allowed/forbidden scope plus correctness, delivery/pipeline, and benchmark evidence.",
        ])

    hotspot_warnings = scalar_hotspot_warnings(kernel_paths)
    if hotspot_warnings:
        warnings.extend([
            "",
            "Potential scalar hotspot checks:",
            *hotspot_warnings,
        ])

    warnings.extend([
        "",
        "SIMD guidance: do not default hot LDM elementwise/reduce loops to scalar code. "
        "Use SIMD/batch/reduce when appropriate, and choose unroll by P0/P1 dual issue, "
        "alignment, tail handling, vector-register pressure, and measurement.",
    ])
    return warnings


def read_stop_hook_input() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def build_stop_output(
    *,
    validation_error: str,
    kernel_warnings: list[str],
    stop_hook_active: bool,
) -> dict:
    warning_text = "\n".join(kernel_warnings).strip()
    if validation_error:
        message = "Learned-pattern validation failed:\n" + validation_error.strip()
        if warning_text:
            message += "\n\n" + warning_text
        if stop_hook_active:
            return {
                "continue": True,
                "systemMessage": (
                    message
                    + "\n\nThe Stop hook already requested one continuation, so it will not block again."
                ),
            }
        return {
            "decision": "block",
            "reason": message,
            "systemMessage": message,
        }
    if warning_text:
        return {"continue": True, "systemMessage": warning_text}
    return {}


def emit_hook_output(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def main() -> int:
    hook_input = read_stop_hook_input()
    paths = changed_knowledge_scope()
    kernel_warnings = kernel_work_warnings()
    validation_error = ""

    if paths is not None:
        cmd = ["python3", str(VALIDATOR), *paths]
        result = subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode != 0:
            validation_error = (result.stderr or result.stdout).strip()
            if not validation_error:
                validation_error = f"validator exited with code {result.returncode}"

    emit_hook_output(
        build_stop_output(
            validation_error=validation_error,
            kernel_warnings=kernel_warnings,
            stop_hook_active=bool(hook_input.get("stop_hook_active")),
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        emit_hook_output(
            {
                "decision": "block",
                "reason": f"Stop hook internal error: {exc}",
                "systemMessage": f"Stop hook internal error: {exc}",
            }
        )
        raise SystemExit(0) from exc
