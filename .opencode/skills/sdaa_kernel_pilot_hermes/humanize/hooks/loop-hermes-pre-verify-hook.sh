#!/usr/bin/env bash
#
# Hermes pre_verify hook for KernelPilot RLCR.
#
# Hermes shell hooks have a short timeout ceiling, so this hook never runs the
# LLM review itself. It only checks RLCR state and tells Hermes to continue with
# the foreground gate command when review is still required.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
RUNTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_LIB_DIR="$RUNTIME_ROOT/hooks/lib"
source "$HOOKS_LIB_DIR/project-root.sh"

HOOK_INPUT="$(cat)"

json_value() {
    local key="$1"
    python3 - "$key" "$HOOK_INPUT" <<'PY'
import json
import sys

key = sys.argv[1]
payload = json.loads(sys.argv[2] or "{}")
value = payload.get(key, "")
print(value if isinstance(value, str) else "")
PY
}

emit_continue() {
    local message="$1"
    python3 - "$message" <<'PY'
import json
import sys

print(json.dumps({"action": "continue", "message": sys.argv[1]}, separators=(",", ":")))
PY
}

state_value() {
    local state_file="$1"
    local key="$2"
    awk -v key="$key" '
        /^---[[:space:]]*$/ {
            if (!frontmatter) {
                frontmatter = 1
                next
            }
            exit
        }
        frontmatter && $0 ~ "^[[:space:]]*" key "[[:space:]]*:" {
            sub("^[^:]*:[[:space:]]*", "")
            gsub(/^["'\'']|["'\'']$/, "")
            print
            exit
        }
    ' "$state_file"
}

latest_state_file() {
    local project_root="$1"
    local rlcr_dir="$project_root/.humanize/rlcr"
    [[ -d "$rlcr_dir" ]] || return 1
    find "$rlcr_dir" -mindepth 2 -maxdepth 2 -name state.md -print 2>/dev/null | sort | tail -1
}

last_transition_field() {
    local transitions_file="$1"
    local field="$2"
    [[ -s "$transitions_file" ]] || return 1
    python3 - "$transitions_file" "$field" <<'PY'
import json
import sys

path, field = sys.argv[1:]
last = None
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            last = json.loads(line)
if not isinstance(last, dict) or field not in last:
    raise SystemExit(1)
print(last[field])
PY
}

first_marker() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    awk 'NF { print $1; exit }' "$file"
}

PROJECT_ROOT="$(json_value cwd || true)"
if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(resolve_project_root 2>/dev/null || true)"
fi
if [[ -z "$PROJECT_ROOT" ]]; then
    exit 0
fi
PROJECT_ROOT="$(canonicalize_path "$PROJECT_ROOT")"

STATE_FILE="$(latest_state_file "$PROJECT_ROOT" || true)"
if [[ -z "$STATE_FILE" ]]; then
    exit 0
fi

LOOP_DIR="$(dirname "$STATE_FILE")"
CURRENT_ROUND="$(state_value "$STATE_FILE" current_round)"
CURRENT_ROUND="${CURRENT_ROUND:-0}"
if [[ ! "$CURRENT_ROUND" =~ ^[0-9]+$ ]]; then
    emit_continue "KernelPilot Hermes RLCR state is invalid: current_round is not numeric in $STATE_FILE. Stop and repair the loop state before continuing."
    exit 0
fi

if [[ -d "$LOOP_DIR/review.lock.d" ]]; then
    emit_continue "KernelPilot Hermes RLCR review is already running. Keep the foreground gate open and wait for it to finish before ending the turn."
    exit 0
fi

TRANSITIONS_FILE="$LOOP_DIR/transitions.jsonl"
LAST_TO=""
LAST_VERDICT=""
if [[ -s "$TRANSITIONS_FILE" ]]; then
    LAST_TO="$(last_transition_field "$TRANSITIONS_FILE" to 2>/dev/null || true)"
    LAST_VERDICT="$(last_transition_field "$TRANSITIONS_FILE" verdict 2>/dev/null || true)"
    if [[ ! "$LAST_TO" =~ ^[0-9]+$ || "$LAST_TO" -ne "$CURRENT_ROUND" ]]; then
        emit_continue "KernelPilot Hermes RLCR transition ledger does not match current_round. Do not edit state.md by hand; repair $TRANSITIONS_FILE and $STATE_FILE before continuing."
        exit 0
    fi
elif [[ "$CURRENT_ROUND" -ne 0 ]]; then
    emit_continue "KernelPilot Hermes RLCR is at round $CURRENT_ROUND but has no transition ledger. Do not edit state.md by hand; repair the loop before continuing."
    exit 0
fi

PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-prompt.md"
if [[ "$CURRENT_ROUND" -gt 0 && ! -f "${PROMPT_FILE}.read" ]]; then
    emit_continue "Read and acknowledge the current Hermes RLCR prompt before implementing or ending this round: run '$RUNTIME_ROOT/scripts/hermes-rlcr-runner.sh --project-root \"$PROJECT_ROOT\"', then continue the round."
    exit 0
fi

ROUND_SUMMARY="$LOOP_DIR/round-${CURRENT_ROUND}-summary.md"
if [[ ! -s "$ROUND_SUMMARY" ]]; then
    emit_continue "Write the required Hermes RLCR round summary before review: $ROUND_SUMMARY. Then run '$RUNTIME_ROOT/scripts/hermes-stop-gate.sh --project-root \"$PROJECT_ROOT\"' in the foreground."
    exit 0
fi

REVIEW_RESULT="$LOOP_DIR/round-${CURRENT_ROUND}-review-result.md"
REVIEW_MARKER="$(first_marker "$REVIEW_RESULT" 2>/dev/null || true)"
if [[ "$LAST_VERDICT" == "COMPLETE" && "$REVIEW_MARKER" == "COMPLETE" ]]; then
    exit 0
fi

emit_continue "Run the Hermes RLCR review gate in the foreground and wait for the verdict: '$RUNTIME_ROOT/scripts/hermes-stop-gate.sh --project-root \"$PROJECT_ROOT\"'. The gate uses the round hermes_timeout value, so long reviews should not run inside this pre_verify hook."
