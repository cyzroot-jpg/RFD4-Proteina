#!/usr/bin/env bash
#
# Hermes RLCR foreground runner helper.
#
# This helper displays the current round prompt and records the explicit read
# acknowledgement required by hermes-stop-gate.sh before reviewing rounds > 0.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOKS_LIB_DIR="$(cd "$SCRIPT_DIR/../hooks/lib" && pwd)"
source "$HOOKS_LIB_DIR/project-root.sh"

usage() {
    cat <<'EOF'
Usage: hermes-rlcr-runner.sh [--project-root PATH]

Displays the current Hermes RLCR round prompt and marks it as read. Run this
before implementing a NEEDS_CHANGES round. The stop gate will reject the round
summary until this acknowledgement exists.
EOF
}

PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            [[ -n "${2:-}" ]] || { echo "Error: --project-root requires a value" >&2; exit 20; }
            PROJECT_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 20
            ;;
    esac
done

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

PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root 2>/dev/null || true)}"
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "No project root detected."
    exit 0
fi
PROJECT_ROOT="$(canonicalize_path "$PROJECT_ROOT")"

STATE_FILE="$(latest_state_file "$PROJECT_ROOT" || true)"
if [[ -z "$STATE_FILE" ]]; then
    echo "No active Hermes RLCR loop exists."
    exit 0
fi

LOOP_DIR="$(dirname "$STATE_FILE")"
CURRENT_ROUND="$(state_value "$STATE_FILE" current_round)"
CURRENT_ROUND="${CURRENT_ROUND:-0}"
if [[ ! "$CURRENT_ROUND" =~ ^[0-9]+$ ]]; then
    echo "Invalid current_round in $STATE_FILE." >&2
    exit 20
fi

PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-prompt.md"
if [[ "$CURRENT_ROUND" -eq 0 && ! -f "$PROMPT_FILE" ]]; then
    echo "Round 0 has no generated follow-up prompt to acknowledge."
    exit 0
fi

if [[ ! -s "$PROMPT_FILE" ]]; then
    echo "Missing current round prompt: $PROMPT_FILE" >&2
    exit 10
fi

echo "Hermes RLCR prompt: $PROMPT_FILE"
echo ""
sed -n '1,260p' "$PROMPT_FILE"
touch "${PROMPT_FILE}.read"
rm -f "${PROMPT_FILE}.pending"
echo ""
echo "Acknowledged prompt read: ${PROMPT_FILE}.read"
