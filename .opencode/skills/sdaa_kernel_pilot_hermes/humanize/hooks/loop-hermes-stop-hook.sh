#!/usr/bin/env bash
#
# Native Stop hook adapter for Hermes installs.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
RUNTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_ROOT=""
if command -v jq >/dev/null 2>&1; then
    HOOK_INPUT="$(cat)"
    PROJECT_ROOT="$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi

args=()
[[ -n "$PROJECT_ROOT" ]] && args+=(--project-root "$PROJECT_ROOT")

"$RUNTIME_ROOT/scripts/hermes-stop-gate.sh" "${args[@]}" --json
