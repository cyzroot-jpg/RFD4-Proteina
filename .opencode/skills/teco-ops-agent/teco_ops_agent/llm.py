from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from teco_ops_agent.config import REPO_ROOT, repo_path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:  # pragma: no cover
        tomllib = None  # type: ignore[assignment]

DEFAULT_LLM_SETTINGS_PATH = REPO_ROOT / "configs/llm_runtime.json"


@dataclass
class ProviderConfig:
    name: str
    base_url: str
    wire_api: str
    env_key: str | None = None


@dataclass
class LLMRuntimeConfig:
    provider: ProviderConfig
    model: str
    api_key: str
    profile_name: str


@dataclass
class LLMSettings:
    auth_path: Path
    config_path: Path
    default_profile_name: str | None
    default_model: str
    default_wire_api: str


def load_llm_settings(path: Path = DEFAULT_LLM_SETTINGS_PATH) -> LLMSettings:
    data = json.loads(path.read_text(encoding="utf-8"))
    auth_path_value = str(data["auth_path"]).strip()
    if not auth_path_value:
        raise ValueError(f"auth_path is empty in {path}")
    config_path_value = str(data["codex_config_path"]).strip()
    if not config_path_value:
        raise ValueError(f"codex_config_path is empty in {path}")
    default_model = str(data.get("default_model", "gpt-5.4")).strip()
    if not default_model:
        raise ValueError(f"default_model is empty in {path}")
    default_profile_name = str(data.get("default_profile_name", "")).strip() or None
    return LLMSettings(
        auth_path=repo_path(auth_path_value),
        config_path=repo_path(config_path_value),
        default_profile_name=default_profile_name,
        default_model=default_model,
        default_wire_api=str(data.get("default_wire_api", "responses")),
    )


def load_runtime_config(
    auth_path: Path | None = None,
    config_path: Path | None = None,
    profile_name: str | None = None,
    settings_path: Path = DEFAULT_LLM_SETTINGS_PATH,
) -> LLMRuntimeConfig:
    claude_settings = Path.home() / ".claude" / "settings.json"
    if claude_settings.exists():
        try:
            settings = json.loads(claude_settings.read_text(encoding="utf-8"))
            env_vars = settings.get("env", {})
            base_url = str(env_vars.get("ANTHROPIC_BASE_URL", "")).strip()
            auth_token = str(
                env_vars.get("ANTHROPIC_AUTH_TOKEN") or env_vars.get("ANTHROPIC_API_KEY", "")
            ).strip()
            model = str(
                env_vars.get("ANTHROPIC_MODEL", settings.get("model", "deepseek-v4-pro"))
            ).strip()
            if base_url and auth_token:
                provider = ProviderConfig(
                    name="ClaudeCode",
                    base_url=base_url,
                    wire_api="responses",
                    env_key=None,
                )
                return LLMRuntimeConfig(
                    provider=provider,
                    model=model,
                    api_key=auth_token,
                    profile_name="claude-code",
                )
        except (json.JSONDecodeError, OSError, KeyError):
            pass

    settings = load_llm_settings(settings_path)
    resolved_auth_path = auth_path or settings.auth_path
    resolved_config_path = config_path or settings.config_path
    auth_data = json.loads(resolved_auth_path.read_text(encoding="utf-8"))
    config_data = _load_toml(resolved_config_path)

    resolved_profile = profile_name or settings.default_profile_name or str(config_data.get("profile", "")).strip()
    profiles = config_data.get("profiles", {})
    if resolved_profile and isinstance(profiles, dict) and resolved_profile in profiles:
        profile = profiles[resolved_profile]
        provider_name = str(profile.get("model_provider", ""))
        model = str(profile.get("model", settings.default_model))
    else:
        provider_name = str(config_data.get("model_provider", ""))
        model = str(config_data.get("model", settings.default_model))

    providers = config_data.get("model_providers", {})
    provider_data = providers.get(provider_name, {}) if isinstance(providers, dict) else {}
    provider = ProviderConfig(
        name=provider_name or "codex",
        base_url=str(provider_data.get("base_url", "")),
        wire_api=str(provider_data.get("wire_api", settings.default_wire_api)),
        env_key=str(provider_data.get("env_key", "")) or None,
    )
    api_key = _resolve_api_key(auth_data, provider)
    return LLMRuntimeConfig(
        provider=provider,
        model=model,
        api_key=api_key,
        profile_name=resolved_profile or provider_name or "codex-default",
    )


def build_llm_summary(config: LLMRuntimeConfig) -> dict[str, str]:
    return {
        "profile_name": config.profile_name,
        "model": config.model,
        "provider_name": config.provider.name,
        "base_url": config.provider.base_url,
        "wire_api": config.provider.wire_api,
    }


def complete_prompt(
    prompt: str,
    system: str | None = None,
    auth_path: Path | None = None,
    config_path: Path | None = None,
    profile_name: str | None = None,
    settings_path: Path = DEFAULT_LLM_SETTINGS_PATH,
    timeout_s: float = 120.0,
    reasoning_effort: str | None = None,
) -> dict[str, Any]:
    runtime = load_runtime_config(
        auth_path=auth_path,
        config_path=config_path,
        profile_name=profile_name,
        settings_path=settings_path,
    )

    if runtime.provider.name == "ClaudeCode":
        try:
            return _complete_anthropic(runtime, prompt, system, timeout_s)
        except RuntimeError:
            return _complete_chat_completions(runtime, prompt, system, timeout_s)

    if runtime.provider.wire_api == "responses":
        try:
            return _complete_responses(runtime, prompt, system, timeout_s, reasoning_effort)
        except RuntimeError as exc:
            msg = str(exc).lower()
            if (
                "404" in str(exc)
                or "not found" in msg
                or "unsupported model" in msg
                or ("400" in str(exc) and "bad request" in msg)
            ):
                return _complete_chat_completions(runtime, prompt, system, timeout_s)
            raise
    if runtime.provider.wire_api in {"chat", "chat_completions"}:
        return _complete_chat_completions(runtime, prompt, system, timeout_s)
    raise ValueError(f"unsupported wire_api: {runtime.provider.wire_api}")


def _complete_anthropic(
    runtime: LLMRuntimeConfig,
    prompt: str,
    system: str | None,
    timeout_s: float,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": runtime.model,
        "max_tokens": 16000,
        "messages": [{"role": "user", "content": prompt}],
    }
    if system:
        payload["system"] = system
    data = _post_json(
        runtime.provider.base_url.rstrip("/") + "/v1/messages",
        payload,
        headers={
            "x-api-key": runtime.api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        },
        timeout_s=timeout_s,
    )
    text = _extract_anthropic_text(data)
    return _result_dict(runtime, text, data)


def _complete_responses(
    runtime: LLMRuntimeConfig,
    prompt: str,
    system: str | None,
    timeout_s: float,
    reasoning_effort: str | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": runtime.model,
        "input": prompt,
    }
    if system:
        payload["instructions"] = system
    if reasoning_effort:
        payload["reasoning"] = {"effort": reasoning_effort}
    data = _post_json(
        runtime.provider.base_url.rstrip("/") + "/responses",
        payload,
        headers={
            "Authorization": f"Bearer {runtime.api_key}",
            "Content-Type": "application/json",
        },
        timeout_s=timeout_s,
    )
    text = extract_output_text(data)
    result = _result_dict(runtime, text, data)
    result["reasoning_text"] = extract_reasoning_text(data)
    return result


def _complete_chat_completions(
    runtime: LLMRuntimeConfig,
    prompt: str,
    system: str | None,
    timeout_s: float,
) -> dict[str, Any]:
    messages: list[dict[str, str]] = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    payload = {"model": runtime.model, "messages": messages}
    data = _post_json(
        runtime.provider.base_url.rstrip("/") + "/chat/completions",
        payload,
        headers={
            "Authorization": f"Bearer {runtime.api_key}",
            "Content-Type": "application/json",
        },
        timeout_s=timeout_s,
    )
    text = _extract_chat_completion_text(data)
    return _result_dict(runtime, text, data)


def _result_dict(runtime: LLMRuntimeConfig, text: str, raw: dict[str, Any]) -> dict[str, Any]:
    return {
        "profile_name": runtime.profile_name,
        "model": runtime.model,
        "provider": runtime.provider.name,
        "output_text": text,
        "raw_response": raw,
    }


def _post_json(url: str, payload: dict[str, Any], headers: dict[str, str], timeout_s: float) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_s) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:  # pragma: no cover
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"llm request failed: {exc.code} {body}") from exc
    return json.loads(body)


def _extract_anthropic_text(data: dict[str, Any]) -> str:
    content = data.get("content", [])
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(str(block.get("text", "")))
        return "\n".join(parts)
    return ""


def extract_reasoning_text(data: dict[str, Any]) -> str:
    chunks: list[str] = []
    for item in data.get("output", []):
        if not isinstance(item, dict) or item.get("type") != "reasoning":
            continue
        summary = item.get("summary")
        if isinstance(summary, list):
            for block in summary:
                if isinstance(block, dict) and isinstance(block.get("text"), str):
                    chunks.append(block["text"])
        for content in item.get("content", []):
            if not isinstance(content, dict):
                continue
            text = content.get("text")
            if isinstance(text, str) and text:
                chunks.append(text)
    reasoning = data.get("reasoning")
    if isinstance(reasoning, dict):
        summary = reasoning.get("summary")
        if isinstance(summary, str) and summary:
            chunks.append(summary)
        elif isinstance(summary, list):
            for block in summary:
                if isinstance(block, dict) and isinstance(block.get("text"), str):
                    chunks.append(block["text"])
    return "\n".join(chunk for chunk in chunks if chunk)


def extract_output_text(data: dict[str, Any]) -> str:
    output_text = data.get("output_text")
    if isinstance(output_text, str) and output_text:
        return output_text
    chunks: list[str] = []
    for item in data.get("output", []):
        if not isinstance(item, dict):
            continue
        for content in item.get("content", []):
            if not isinstance(content, dict):
                continue
            if content.get("type") == "output_text" and isinstance(content.get("text"), str):
                chunks.append(content["text"])
    return "\n".join(chunk for chunk in chunks if chunk)


def _extract_chat_completion_text(data: dict[str, Any]) -> str:
    choices = data.get("choices", [])
    if not isinstance(choices, list) or not choices:
        return ""
    message = choices[0].get("message", {}) if isinstance(choices[0], dict) else {}
    return str(message.get("content", ""))


def _resolve_api_key(auth_data: dict[str, Any], provider: ProviderConfig) -> str:
    if provider.env_key:
        value = os.environ.get(provider.env_key)
        if value:
            return value
    mapped = auth_data.get("OPENAI_API_KEYS", {})
    if isinstance(mapped, dict):
        value = mapped.get(provider.name)
        if isinstance(value, str) and value:
            return value
    fallback = auth_data.get("OPENAI_API_KEY")
    if isinstance(fallback, str) and fallback:
        return fallback
    raise KeyError(f"missing API key for provider {provider.name}")


def _load_toml(path: Path) -> dict[str, Any]:
    if tomllib is not None:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    return _load_simple_toml(path.read_text(encoding="utf-8"))


def _load_simple_toml(text: str) -> dict[str, Any]:
    root: dict[str, Any] = {}
    current = root
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            current = root
            for part in section.split("."):
                current = current.setdefault(part, {})
            continue
        if "=" not in line:
            continue
        key, value = [item.strip() for item in line.split("=", 1)]
        current[key] = _parse_simple_toml_value(value)
    return root


def _parse_simple_toml_value(value: str) -> Any:
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1]
    if value.lower() in {"true", "false"}:
        return value.lower() == "true"
    try:
        return int(value)
    except ValueError:
        return value
