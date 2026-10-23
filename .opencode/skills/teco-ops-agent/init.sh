#!/usr/bin/env bash
set -euo pipefail

BRAND="teco-ops-agent"
VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$SCRIPT_DIR/ops"
INCLUDED_SKILLS="sdaa-env-check sdaa-docs-search sdaa-performance-best-practices sdaa-op-design sdaa-op-requirement sdaa-op-template sdaa-op-learning-validation kernel-bench record-repo-change"

show_help() {
  cat <<'EOF'
Usage: ./init.sh [global|project] [codex|cursor|claude]

Install TECO Ops Agent skills into Codex, Cursor, or Claude Code.

Examples:
  ./init.sh project codex     # .codex/skills + AGENTS.md
  ./init.sh project cursor    # .cursor/skills + AGENTS.md
  ./init.sh project claude    # .claude/skills + CLAUDE.md (from AGENTS.md)

  ./init.sh global claude     # ~/.claude/skills + ~/.claude/CLAUDE.md

Claude Code plugin (optional):
  /plugin marketplace add <repo-url>
  /plugin install teco-ops-agent-skills@teco-ops

EOF
}

LEVEL="project"
TOOL="codex"

for arg in "$@"; do
  case "$arg" in
    --help|-h) show_help; exit 0 ;;
    global|project) LEVEL="$arg" ;;
    codex|cursor|claude) TOOL="$arg" ;;
    *)
      echo "Unknown argument: $arg" >&2
      show_help
      exit 1
      ;;
  esac
done

if [ "$LEVEL" = "global" ]; then
  case "$TOOL" in
    cursor) CONFIG_ROOT="$HOME/.cursor" ;;
    claude) CONFIG_ROOT="$HOME/.claude" ;;
    *) CONFIG_ROOT="$HOME/.codex" ;;
  esac
  INSTALL_BASE="$CONFIG_ROOT"
else
  INSTALL_BASE="$PWD"
  case "$TOOL" in
    cursor) CONFIG_ROOT="$INSTALL_BASE/.cursor" ;;
    claude) CONFIG_ROOT="$INSTALL_BASE/.claude" ;;
    *) CONFIG_ROOT="$INSTALL_BASE/.codex" ;;
  esac
fi

echo "TECO Ops Agent installer"
echo "  tool:  $TOOL"
echo "  level: $LEVEL"
echo "  path:  $CONFIG_ROOT"
echo ""

mkdir -p "$CONFIG_ROOT/skills"

for name in $INCLUDED_SKILLS; do
  src="$SKILL_ROOT/$name"
  dst="$CONFIG_ROOT/skills/$name"
  if [ ! -d "$src" ]; then
    echo "Missing skill source: $src" >&2
    exit 1
  fi
  ln -sfn "$(realpath "$src")" "$dst"
  echo "  linked skill: $name"
done

AGENTS_SRC="$(realpath "$SCRIPT_DIR/AGENTS.md")"

if [ "$TOOL" = "claude" ]; then
  SETTINGS_EXAMPLE="$SCRIPT_DIR/configs/claude_settings.example.json"
  SETTINGS_DST="$CONFIG_ROOT/settings.json"
  if [ -f "$SETTINGS_EXAMPLE" ]; then
    python3 - "$SETTINGS_EXAMPLE" "$SETTINGS_DST" "$HOME/.codex/auth.json" <<'PY'
import json
import sys
from pathlib import Path

example = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
dst = Path(sys.argv[2])
codex_auth = Path(sys.argv[3])
current = json.loads(dst.read_text(encoding="utf-8")) if dst.is_file() else {}

def merge(dst_data: dict) -> dict:
    out = dst_data
    out["model"] = example["model"]
    env = out.setdefault("env", {})
    for key, value in example.get("env", {}).items():
        env[key] = value
    # Never keep placeholder keys in project settings.
    for key in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"):
        if env.get(key) in {"", "YOUR_API_KEY"}:
            env.pop(key, None)
    # Global install: pull API key from Codex auth if available.
    if codex_auth.is_file() and dst.parent == Path.home() / ".claude":
        try:
            token = str(json.loads(codex_auth.read_text(encoding="utf-8")).get("OPENAI_API_KEY", "")).strip()
        except (OSError, json.JSONDecodeError, TypeError):
            token = ""
        if token:
            env["ANTHROPIC_API_KEY"] = token
            env["ANTHROPIC_AUTH_TOKEN"] = token
    return out

merged = merge(current)
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"  wrote {dst} (model={example['model']})")
PY
  fi
  if [ "$LEVEL" = "project" ] && [ "$INSTALL_BASE" = "$SCRIPT_DIR" ]; then
    if [ ! -e "$INSTALL_BASE/CLAUDE.md" ]; then
      ln -sfn "AGENTS.md" "$INSTALL_BASE/CLAUDE.md"
      echo "  linked CLAUDE.md -> AGENTS.md (in repo)"
    else
      echo "  CLAUDE.md already present"
    fi
  else
    ln -sfn "$AGENTS_SRC" "$INSTALL_BASE/CLAUDE.md"
    echo "  linked CLAUDE.md -> $AGENTS_SRC"
  fi
else
  if [ "$LEVEL" = "project" ] && [ "$INSTALL_BASE" = "$SCRIPT_DIR" ]; then
    echo "  AGENTS.md already in repo root"
  elif [ "$LEVEL" = "project" ]; then
    ln -sfn "$AGENTS_SRC" "$INSTALL_BASE/AGENTS.md"
    echo "  linked AGENTS.md -> $AGENTS_SRC"
  else
    ln -sfn "$AGENTS_SRC" "$CONFIG_ROOT/AGENTS.md"
    echo "  linked AGENTS.md -> $CONFIG_ROOT/AGENTS.md"
  fi
fi

MANIFEST="$CONFIG_ROOT/teco-ops-agent-manifest.json"
python3 - <<PY
import json
from datetime import datetime, timezone
from pathlib import Path

manifest = {
    "brand": "$BRAND",
    "version": "$VERSION",
    "tool": "$TOOL",
    "level": "$LEVEL",
    "installed_skills": "$(echo $INCLUDED_SKILLS)".split(),
    "config_root": "$CONFIG_ROOT",
    "install_time": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
Path("$MANIFEST").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
PY

echo ""
echo "Done. Quick start:"
case "$TOOL" in
  codex)
    echo "  1. codex"
    echo "  2. python3 run_cli.py llm-plan"
    ;;
  claude)
    echo "  1. claude   (in: $INSTALL_BASE)"
    echo "  2. python3 run_cli.py agent-ask \"检查 SDAA 环境\" --verbose"
    echo ""
    echo "Plugin install (optional):"
    echo "  /plugin marketplace add <this-repo-url>"
    echo "  /plugin install teco-ops-agent-skills@teco-ops"
    echo "  ln -sf AGENTS.md CLAUDE.md   # if CLAUDE.md not created by plugin"
    ;;
  cursor)
    echo "  1. Open Cursor in this project"
    echo "  2. python3 run_cli.py llm-plan"
    ;;
esac
