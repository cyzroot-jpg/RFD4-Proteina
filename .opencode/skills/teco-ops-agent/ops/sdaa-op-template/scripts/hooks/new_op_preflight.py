#!/usr/bin/env python3
"""Codex UserPromptSubmit hook for SDAA operator/kernel work preflight.

The hook is intentionally advisory: when a prompt appears to request a new
operator or kernel optimization, it points to the performance best-practices
entry, searches the local learned-patterns knowledge base, and summarizes the
project code style / SIMD references so the agent consumes them before
implementation.
"""

from __future__ import annotations

import json
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
LEARNED_PATTERNS = (
    REPO_ROOT / "ops" / "sdaa-op-learning-validation" / "references" / "learned-patterns"
)
DOMAIN_ROUTES = LEARNED_PATTERNS / "domain-routes.json"
PERF_BEST_PRACTICES = REPO_ROOT / "ops" / "sdaa-performance-best-practices" / "SKILL.md"
CODE_STYLE = REPO_ROOT / "docs" / "code-style.md"
SIMD_MANUAL = REPO_ROOT / "docs" / "共享知识库" / "SIMD使用手册-zh.md"
SIMD_DUAL_ISSUE = REPO_ROOT / "docs" / "共享知识库" / "simd-dual-issue-pattern.md"
OUTPUT_DIR_CANDIDATES = [
    REPO_ROOT / ".tmp" / "codex-hook-output",
    Path("/tmp") / "teco-ops-agent-hooks",
]
STATE_FILE_NAME = "latest-kernel-work-preflight-state.json"
BACKEND_CONFIG_CANDIDATES = [
    REPO_ROOT / "configs" / "backend_config.local.json",
    REPO_ROOT / "configs" / "backend_config.json",
]

TRIGGER_PATTERNS = [
    r"新算子",
    r"生成.*算子",
    r"写.*算子",
    r"开发.*算子",
    r"实现.*算子",
    r"new\s+op(?:erator)?",
    r"write\s+(?:a\s+)?(?:new\s+)?op(?:erator)?",
    r"implement\s+(?:a\s+)?(?:new\s+)?op(?:erator)?",
    r"scaffold.*op",
    r"优化.*算子",
    r"优化.*kernel",
    r"优化.*swcu",
    r"改.*kernel",
    r"改.*swcu",
    r"性能优化",
    r"向量化",
    r"串行",
    r"\bSIMD\b",
    r"\bsimd\b",
    r"\breduce\b",
    r"\bepilogue\b",
    r"\.swcu\b",
    r"\bSATE\b",
    r"\bsate\b",
]

DOMAIN_ACTION_PATTERNS = [
    r"优化",
    r"实现",
    r"开发",
    r"新增",
    r"修改",
    r"改造",
    r"\boptimi[sz](?:e|ing|ation)\b",
    r"\bimplement(?:ation|ing)?\b",
    r"\bdevelop(?:ment|ing)?\b",
    r"\bmodif(?:y|ying|ication)\b",
    r"\brefactor(?:ing)?\b",
]

STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "from",
    "this",
    "that",
    "operator",
    "new",
    "op",
    "算子",
    "生成",
    "开发",
    "实现",
    "优化",
    "性能",
    "kernel",
    "swcu",
    "sate",
    "test",
    "testing",
    "benchmark",
    "benchmarking",
    "optimize",
    "optimise",
    "optimization",
    "implementation",
    "implement",
    "develop",
    "development",
    "create",
    "write",
    "modify",
}

CJK_ACTION_STOPWORDS = {
    "算子",
    "内核",
    "继续",
    "优化",
    "实现",
    "开发",
    "新增",
    "生成",
    "编写",
    "写",
    "修改",
    "改造",
    "测试",
    "测一下",
    "压测",
    "性能",
}


def collect_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            result.extend(collect_strings(item))
        return result
    if isinstance(value, dict):
        result = []
        preferred_keys = [
            "prompt",
            "user_prompt",
            "message",
            "text",
            "input",
            "content",
            "cwd",
        ]
        for key in preferred_keys:
            if key in value:
                result.extend(collect_strings(value[key]))
        if not result:
            for item in value.values():
                result.extend(collect_strings(item))
        return result
    return []


def read_hook_input() -> str:
    raw = sys.stdin.read()
    if not raw.strip():
        return ""
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    strings = collect_strings(payload)
    return "\n".join(strings) if strings else raw


def looks_like_kernel_work(prompt: str) -> bool:
    if any(re.search(pattern, prompt, re.IGNORECASE | re.DOTALL) for pattern in TRIGGER_PATTERNS):
        return True
    has_domain_action = any(
        re.search(pattern, prompt, re.IGNORECASE | re.DOTALL)
        for pattern in DOMAIN_ACTION_PATTERNS
    )
    return has_domain_action and bool(matched_domain_names(prompt))


def extract_terms(prompt: str) -> set[str]:
    ascii_terms = re.findall(r"[A-Za-z_][A-Za-z0-9_]{2,}", prompt.lower())
    cjk_terms = re.findall(r"[\u4e00-\u9fff]{2,}", prompt)
    terms = {term for term in ascii_terms if term not in STOPWORDS}
    for term in cjk_terms:
        normalized = term
        for action in CJK_ACTION_STOPWORDS:
            normalized = normalized.replace(action, "")
        if len(normalized) >= 2 and normalized not in STOPWORDS:
            terms.add(normalized)
    return terms


def load_domain_routes() -> dict[str, dict[str, object]]:
    if not DOMAIN_ROUTES.is_file():
        return {}
    payload = json.loads(DOMAIN_ROUTES.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise ValueError("learned-pattern domain-routes.json schema_version must be 1")
    routes = payload.get("routes")
    if not isinstance(routes, dict):
        raise ValueError("learned-pattern domain-routes.json must contain a routes object")
    for name, route in routes.items():
        if not isinstance(name, str) or not isinstance(route, dict):
            raise ValueError("learned-pattern domain route entries must be objects")
        for field in ("triggers", "patterns"):
            value = route.get(field, [])
            if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
                raise ValueError(f"domain route {name}.{field} must be a string list")
        inherits = route.get("inherits", [])
        if not isinstance(inherits, list) or any(not isinstance(item, str) for item in inherits):
            raise ValueError(f"domain route {name}.inherits must be a string list")
        if not isinstance(route.get("index", ""), str):
            raise ValueError(f"domain route {name}.index must be a string")
    for name, route in routes.items():
        for parent in route.get("inherits", []):
            if parent not in routes:
                raise ValueError(f"domain route {name} inherits unknown route {parent}")
        index = str(route.get("index", ""))
        if index and not (LEARNED_PATTERNS / index).is_file():
            raise ValueError(f"domain route {name} index does not exist: {index}")
        for relative in route.get("patterns", []):
            if not (LEARNED_PATTERNS / relative).is_file():
                raise ValueError(f"domain route {name} pattern does not exist: {relative}")
    return routes


def matched_domain_names(prompt: str) -> list[str]:
    routes = load_domain_routes()
    direct_matches = []
    for name, route in routes.items():
        triggers = route.get("triggers", [])
        if any(re.search(pattern, prompt, re.IGNORECASE | re.DOTALL) for pattern in triggers):
            direct_matches.append(name)

    resolved: list[str] = []
    visiting: set[str] = set()

    def add_route(name: str) -> None:
        if name in resolved:
            return
        if name in visiting:
            raise ValueError(f"cyclic learned-pattern domain route inheritance at {name}")
        route = routes.get(name)
        if route is None:
            raise ValueError(f"unknown inherited learned-pattern domain route: {name}")
        visiting.add(name)
        for parent in route.get("inherits", []):
            add_route(parent)
        visiting.remove(name)
        resolved.append(name)

    for name in direct_matches:
        add_route(name)
    return resolved


def domain_index_summaries(prompt: str) -> list[str]:
    routes = load_domain_routes()
    summaries = []
    for name in matched_domain_names(prompt):
        route = routes[name]
        index = str(route.get("index", ""))
        if not index:
            continue
        path = LEARNED_PATTERNS / index
        label = str(route.get("label", name))
        if path.is_file():
            summaries.append(f"- `{rel_path(path)}`: {label} 算子族路由索引。")
        else:
            summaries.append(f"- Missing `{rel_path(path)}`: {label} 算子族路由索引。")
    return summaries


def routed_pattern_paths(prompt: str) -> list[Path]:
    routes = load_domain_routes()
    paths = []
    seen = set()
    for name in matched_domain_names(prompt):
        for relative in routes[name].get("patterns", []):
            path = LEARNED_PATTERNS / relative
            if path not in seen:
                paths.append(path)
                seen.add(path)
    return paths


def first_section(markdown: str, heading: str, max_lines: int = 8) -> list[str]:
    lines = markdown.splitlines()
    start = None
    for idx, line in enumerate(lines):
        if line.strip().lower() == heading.lower():
            start = idx + 1
            break
    if start is None:
        return []
    out = []
    for line in lines[start:]:
        if line.startswith("## ") and out:
            break
        if line.strip():
            out.append(line.strip())
        if len(out) >= max_lines:
            break
    return out


def summarize_pattern(path: Path, terms: set[str]) -> tuple[int, str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    lowered = text.lower()
    score = sum(1 for term in terms if term.lower() in lowered)
    if path.suffix == ".md":
        score += 1

    title = next((line.strip("# ").strip() for line in text.splitlines() if line.startswith("# ")), path.name)
    status_lines = first_section(text, "## 状态", 1) or first_section(text, "## Status", 1)
    status = status_lines[0] if status_lines else ""
    if status in {"verified_by_stage", "promoted"}:
        score += 2
    elif status in {"needs_revalidation", "superseded", "deprecated"}:
        score -= 1
    core = first_section(text, "## 核心思路", 2) or first_section(text, "## Core Idea", 2)
    problem = first_section(text, "## 问题", 2) or first_section(text, "## Problem", 2)
    summary_parts = []
    if status:
        summary_parts.append(f"status={status}")
    if core:
        summary_parts.append("core=" + " ".join(core))
    elif problem:
        summary_parts.append("problem=" + " ".join(problem))
    rel = path.relative_to(REPO_ROOT)
    summary = f"- `{rel}`: {title}"
    if summary_parts:
        summary += " | " + " | ".join(summary_parts)
    return score, summary


def pattern_matches_terms(path: Path, terms: set[str]) -> bool:
    if not terms:
        return False
    text = path.read_text(encoding="utf-8", errors="ignore").lower()
    return any(term.lower() in text for term in terms)


def search_patterns(prompt: str) -> list[str]:
    terms = extract_terms(prompt)
    selected = []
    selected_paths = set()
    for path in routed_pattern_paths(prompt):
        if not path.is_file():
            continue
        _, summary = summarize_pattern(path, terms)
        selected.append(summary)
        selected_paths.add(path)

    candidates = []
    for path in LEARNED_PATTERNS.rglob("*.md"):
        if path.name == "README.md":
            continue
        if path in selected_paths:
            continue
        if not pattern_matches_terms(path, terms):
            continue
        score, summary = summarize_pattern(path, terms)
        if score > 1:
            candidates.append((score, summary))
    candidates.sort(key=lambda item: item[0], reverse=True)
    remaining = max(0, 12 - len(selected))
    selected.extend(summary for _, summary in candidates[:remaining])
    return selected


def rel_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def code_style_summary() -> list[str]:
    if not CODE_STYLE.exists():
        return [f"- Missing `{rel_path(CODE_STYLE)}`"]
    text = CODE_STYLE.read_text(encoding="utf-8", errors="ignore")
    important = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and any(
            key in stripped
            for key in [
                "一行只写",
                "snake_case",
                "UPPER_SNAKE_CASE",
                "M2",
                "Device Kernel",
                "rt_ace_writeback",
                "性能优化",
                "修改 tile",
            ]
        ):
            important.append(stripped)
        if len(important) >= 10:
            break
    return [f"- `{rel_path(CODE_STYLE)}`"] + important


def simd_reference_summary(prompt: str) -> list[str]:
    terms = extract_terms(prompt)
    simd_relevant = bool(
        {"simd", "reduce", "epilogue"} & terms
        or re.search(r"向量化|串行|规约|逐元素|后处理|性能优化", prompt, re.IGNORECASE)
    )
    if not simd_relevant:
        return []
    refs = []
    for path, note in [
        (SIMD_MANUAL, "P0/P1 双发射、向量寄存器、load/store/add 拍数"),
        (SIMD_DUAL_ISSUE, "软件流水模板；使用前仍需结合实测和寄存器压力"),
    ]:
        if path.exists():
            refs.append(f"- `{rel_path(path)}`: {note}")
        else:
            refs.append(f"- Missing `{rel_path(path)}`: {note}")
    return refs


def performance_best_practices_summary() -> list[str]:
    if PERF_BEST_PRACTICES.exists():
        return [
            f"- `{rel_path(PERF_BEST_PRACTICES)}`: 先用该入口完成机制层、算子族、API 和验证流程路由。"
        ]
    return [f"- Missing `{rel_path(PERF_BEST_PRACTICES)}`"]


def git_status(root: Path, prefix: str = "") -> dict[str, str]:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
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


def write_state(prompt: str, output_dir: Path) -> None:
    state = {
        "prompt_terms": sorted(extract_terms(prompt)),
        "matched_domain_routes": matched_domain_names(prompt),
        "baseline_status": snapshot_status(),
    }
    (output_dir / STATE_FILE_NAME).write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def build_user_prompt_output(report: str) -> dict:
    if not report:
        return {}
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": report,
        }
    }


def emit_hook_output(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def main() -> int:
    prompt = read_hook_input()
    if not looks_like_kernel_work(prompt):
        emit_hook_output({})
        return 0

    pattern_summaries = search_patterns(prompt)
    if not pattern_summaries:
        pattern_summaries = ["- No matching learned patterns found; still read the learned-patterns README before implementing."]
    simd_refs = simd_reference_summary(prompt)
    domain_indexes = domain_index_summaries(prompt)

    report_lines = [
        "# Operator / Kernel Work Preflight",
        "",
        "Triggered by a prompt that appears to request SDAA operator development or kernel optimization.",
        "",
        "## Performance Best-Practices Entry To Read",
        *performance_best_practices_summary(),
        "",
    ]
    if domain_indexes:
        report_lines.extend([
            "## Operator-Family Routing Indexes To Read",
            *domain_indexes,
            "",
        ])
    report_lines.extend([
        "## Learned Patterns To Read",
        *pattern_summaries,
        "",
    ])
    if simd_refs:
        report_lines.extend([
            "## SIMD References To Read",
            *simd_refs,
            "",
        ])
    report_lines.extend([
        "## Code Style To Read",
        *code_style_summary(),
        "",
        "## Required Agent Action",
        "- Before choosing a design or optimization attempt, read the performance best-practices entry and follow its routing.",
        "- When operator-family routing indexes are listed, read them in inherited order before the mechanism patterns.",
        "- Before generating or editing operator code, read the listed learned patterns and `docs/code-style.md`.",
        "- For LDM elementwise/reduce/epilogue hot loops, evaluate SIMD or batch/reduce APIs before writing scalar loops.",
        "- SIMD choices must consider P0/P1 dual issue, 64B alignment, tail handling, vector-register pressure, and benchmark evidence; do not blindly force 8x unroll.",
        "- For new operators, still follow requirement -> design -> scaffold -> implement -> L3 -> delivery.",
        "- For optimization attempts, record the single-point scope, L3/delivery/benchmark evidence, and stage_result.",
    ])
    report = "\n".join(report_lines) + "\n"
    for output_dir in OUTPUT_DIR_CANDIDATES:
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
            (output_dir / "latest-new-op-preflight.md").write_text(report, encoding="utf-8")
            (output_dir / "latest-kernel-work-preflight.md").write_text(report, encoding="utf-8")
            write_state(prompt, output_dir)
            break
        except OSError:
            continue
    emit_hook_output(build_user_prompt_output(report))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        emit_hook_output(
            {
                "continue": True,
                "systemMessage": f"UserPromptSubmit hook internal error: {exc}",
            }
        )
        raise SystemExit(0) from exc
