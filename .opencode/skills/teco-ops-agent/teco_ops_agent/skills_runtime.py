from __future__ import annotations

import json
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from teco_ops_agent.config import REPO_ROOT

OPS_ROOT = REPO_ROOT / "ops"
ENV_CHECK_SKILL = OPS_ROOT / "sdaa-env-check"


@dataclass
class SkillStep:
    name: str
    status: str
    detail: str = ""


@dataclass
class SkillContext:
    steps: list[SkillStep] = field(default_factory=list)
    env_check: dict[str, Any] | None = None
    device_info: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "steps": [step.__dict__ for step in self.steps],
            "env_check": self.env_check,
            "device_info": self.device_info,
        }


def collect_skill_context(
    *,
    run_env_check: bool = True,
    run_device_info: bool = True,
    verbose: bool = False,
) -> SkillContext:
    context = SkillContext()

    if run_env_check:
        context.env_check, step = _run_env_check()
        context.steps.append(step)
        if verbose:
            print(f"[skill] {step.name}: {step.status} — {step.detail}", flush=True)

    if run_device_info:
        context.device_info, step = _run_device_info()
        context.steps.append(step)
        if verbose:
            print(f"[skill] {step.name}: {step.status} — {step.detail}", flush=True)

    return context


def build_agent_system_prompt() -> str:
    return (
        "你是 TECO Ops Agent（SDAA 算子开发 demo）。\n"
        "你必须基于用户消息中附带的【技能执行结果】作答，"
        "禁止声称无法访问本机环境。\n"
        "若环境检查 JSON 显示某项失败，应明确指出失败项与修复建议。"
    )


def build_agent_user_prompt(user_query: str, context: SkillContext) -> str:
    sections = [f"## 用户问题\n\n{user_query.strip()}\n"]

    if context.env_check is not None:
        sections.append(
            "## sdaa-env-check 执行结果\n\n```json\n"
            + json.dumps(context.env_check, indent=2, ensure_ascii=False)
            + "\n```\n"
        )

    if context.device_info is not None:
        sections.append(
            "## device_info 执行结果\n\n```json\n"
            + json.dumps(context.device_info, indent=2, ensure_ascii=False)
            + "\n```\n"
        )

    return "\n".join(sections)


def _run_env_check() -> tuple[dict[str, Any] | None, SkillStep]:
    script = ENV_CHECK_SKILL / "scripts/check_env.sh"
    if not script.exists():
        return None, SkillStep("sdaa-env-check", "skipped", f"missing script: {script}")

    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        output_path = Path(tmp.name)

    try:
        proc = subprocess.run(
            ["bash", str(script), "--json", "-o", str(output_path)],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        if proc.returncode != 0 and not output_path.exists():
            detail = (proc.stderr or proc.stdout or "check_env.sh failed").strip()
            return None, SkillStep("sdaa-env-check", "failed", detail[:500])

        data = json.loads(output_path.read_text(encoding="utf-8"))
        status_value = data.get("status") or data.get("overall_status")
        status = "ok" if status_value == "pass" else "warn"
        return data, SkillStep("sdaa-env-check", status, f"status={status_value}")
    except (OSError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        return None, SkillStep("sdaa-env-check", "failed", str(exc))
    finally:
        output_path.unlink(missing_ok=True)


def _run_device_info() -> tuple[dict[str, Any] | None, SkillStep]:
    script = ENV_CHECK_SKILL / "scripts/device_info.py"
    if not script.exists():
        return None, SkillStep("device_info", "skipped", f"missing script: {script}")

    try:
        proc = subprocess.run(
            ["python3", str(script), "--json"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "device_info.py failed").strip()
            return None, SkillStep("device_info", "failed", detail[:500])
        data = json.loads(proc.stdout)
        device_count = data.get("device_count")
        if device_count is None and isinstance(data.get("devices"), list):
            device_count = len(data["devices"])
        return data, SkillStep("device_info", "ok", f"devices={device_count}")
    except (OSError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        return None, SkillStep("device_info", "failed", str(exc))
