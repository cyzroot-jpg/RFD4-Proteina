from __future__ import annotations

import argparse
import json
import sys

from teco_ops_agent.llm import build_llm_summary, complete_prompt, load_runtime_config
from teco_ops_agent.skills_runtime import (
    build_agent_system_prompt,
    build_agent_user_prompt,
    collect_skill_context,
)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="TECO Ops Agent CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    llm_plan = subparsers.add_parser("llm-plan", help="Print resolved LLM runtime summary.")
    llm_plan.add_argument("--profile", default=None, help="Optional Codex profile override.")
    llm_plan.set_defaults(func=command_llm_plan)

    llm_chat = subparsers.add_parser(
        "llm-chat",
        help="Raw one-shot LLM call (does NOT run skills).",
    )
    llm_chat.add_argument("prompt", help="User prompt text.")
    llm_chat.add_argument("--system", default=None, help="Optional system instruction.")
    llm_chat.add_argument("--profile", default=None, help="Optional Codex profile override.")
    llm_chat.add_argument(
        "--reasoning",
        choices=["low", "medium", "high"],
        default=None,
        help="Request model reasoning (Responses API only).",
    )
    llm_chat.add_argument("--json", action="store_true", help="Print full JSON response.")
    llm_chat.set_defaults(func=command_llm_chat)

    agent_ask = subparsers.add_parser(
        "agent-ask",
        help="Run sdaa-env-check skill, then ask the LLM.",
    )
    agent_ask.add_argument("prompt", help="User question.")
    agent_ask.add_argument("--profile", default=None, help="Optional Codex profile override.")
    agent_ask.add_argument(
        "--reasoning",
        choices=["low", "medium", "high"],
        default=None,
        help="Request model reasoning (Responses API only).",
    )
    agent_ask.add_argument(
        "--no-env-check",
        action="store_true",
        help="Skip sdaa-env-check script execution.",
    )
    agent_ask.add_argument(
        "--verbose",
        action="store_true",
        help="Print skill execution steps to stderr.",
    )
    agent_ask.add_argument("--json", action="store_true", help="Print full JSON response.")
    agent_ask.set_defaults(func=command_agent_ask)

    return parser


def command_llm_plan(args: argparse.Namespace) -> int:
    runtime = load_runtime_config(profile_name=args.profile)
    print(json.dumps(build_llm_summary(runtime), indent=2, ensure_ascii=False))
    return 0


def command_llm_chat(args: argparse.Namespace) -> int:
    result = complete_prompt(
        prompt=args.prompt,
        system=args.system,
        profile_name=args.profile,
        reasoning_effort=args.reasoning,
    )
    _print_llm_result(result, as_json=args.json, show_reasoning=bool(args.reasoning))
    return 0 if result.get("output_text") else 1


def command_agent_ask(args: argparse.Namespace) -> int:
    if args.verbose:
        print("[agent] collecting skill context...", file=sys.stderr, flush=True)

    context = collect_skill_context(
        run_env_check=not args.no_env_check,
        run_device_info=not args.no_env_check,
        verbose=args.verbose,
    )

    system = build_agent_system_prompt()
    prompt = build_agent_user_prompt(args.prompt, context)

    if args.verbose:
        print("[agent] calling LLM...", file=sys.stderr, flush=True)

    result = complete_prompt(
        prompt=prompt,
        system=system,
        profile_name=args.profile,
        reasoning_effort=args.reasoning,
    )
    result["skill_context"] = context.to_dict()

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        reasoning = result.get("reasoning_text", "")
        if reasoning:
            print("=== Reasoning ===")
            print(reasoning)
            print()
        print(result.get("output_text", ""))
    return 0 if result.get("output_text") else 1


def _print_llm_result(result: dict, *, as_json: bool, show_reasoning: bool) -> None:
    if as_json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return
    reasoning = result.get("reasoning_text", "")
    if show_reasoning and reasoning:
        print("=== Reasoning ===")
        print(reasoning)
        print()
    print(result.get("output_text", ""))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
