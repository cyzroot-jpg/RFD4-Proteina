#!/usr/bin/env bash
#
# Hermes RLCR stop-gate entrypoint.
#
# This gate reviews the active RLCR round with Hermes and fails closed when
# review cannot run, the serialized round state is inconsistent, or Hermes
# does not return an accepted marker.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOKS_LIB_DIR="$(cd "$SCRIPT_DIR/../hooks/lib" && pwd)"
source "$HOOKS_LIB_DIR/project-root.sh"

usage() {
    cat <<'EOF'
Usage: hermes-stop-gate.sh [--project-root PATH] [--json]

Reviews the active RLCR round with Hermes. The gate allows COMPLETE verdicts
and blocks missing summaries, Hermes failures, NEEDS_CHANGES, and unknown
verdicts.
EOF
}

PROJECT_ROOT=""
PRINT_JSON="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            [[ -n "${2:-}" ]] || { echo "Error: --project-root requires a value" >&2; exit 20; }
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --json)
            PRINT_JSON="true"
            shift
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

emit_allow() {
    local reason="$1"
    if [[ "$PRINT_JSON" == "true" ]]; then
        printf '{"decision":"approve","reason":"%s"}\n' "$reason"
    else
        echo "ALLOW: $reason"
    fi
}

emit_block() {
    local title="$1"
    local reason="$2"
    if [[ "$PRINT_JSON" == "true" ]]; then
        printf '{"decision":"block","systemMessage":"%s","reason":"%s"}\n' "$title" "$reason"
    else
        echo "BLOCK: $title"
        echo "$reason"
    fi
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

set_state_current_round() {
    local state_file="$1"
    local round="$2"
    local tmp_file="${state_file}.tmp.$$"

    chmod u+w "$state_file" 2>/dev/null || true
    awk -v round="$round" '
        BEGIN { updated = 0 }
        /^current_round:[[:space:]]*/ {
            print "current_round: " round
            updated = 1
            next
        }
        { print }
        END {
            if (!updated) {
                print "current_round: " round
            }
        }
    ' "$state_file" > "$tmp_file" && mv "$tmp_file" "$state_file"
    chmod a-w "$state_file" 2>/dev/null || true
}

write_next_round_prompt() {
    local next_round="$1"
    local prompt_file="$LOOP_DIR/round-${next_round}-prompt.md"
    local next_summary="$LOOP_DIR/round-${next_round}-summary.md"

    cat > "$prompt_file" <<EOF_PROMPT
# Hermes RLCR Round $next_round

Continue the KernelPilot RLCR loop after Hermes review.

## Required Work

- Read the plan, previous round summary, and Hermes review findings.
- Implement only the next smallest verifiable change.
- Run focused correctness tests or benchmarks that prove the change.
- Update ledgers or profile artifacts when they explain the decision.
- Commit the work.
- Write the next round summary at:

\`\`\`text
$next_summary
\`\`\`

## Previous Round Summary

$(sed -n '1,240p' "$ROUND_SUMMARY")

## Hermes Review Findings

$(sed -n '1,240p' "$REVIEW_RESULT")
EOF_PROMPT
    : > "${prompt_file}.pending"
    rm -f "${prompt_file}.read"
}

acquire_review_lock() {
    REVIEW_LOCK_DIR="$LOOP_DIR/review.lock.d"
    if mkdir "$REVIEW_LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$REVIEW_LOCK_DIR/pid"
        printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$REVIEW_LOCK_DIR/started_at"
        trap 'rm -rf "$REVIEW_LOCK_DIR"' EXIT
        return 0
    fi

    emit_block "Hermes review already in progress" "A review lock exists at $REVIEW_LOCK_DIR. Wait for the foreground gate to finish before starting another round."
    exit 10
}

last_transition_to() {
    local transitions_file="$1"
    [[ -s "$transitions_file" ]] || return 1

    python3 - "$transitions_file" <<'PY'
import json
import sys

path = sys.argv[1]
last = None
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        last = json.loads(line)
if not isinstance(last, dict) or "to" not in last:
    raise SystemExit(2)
print(last["to"])
PY
}

validate_transition_ledger() {
    TRANSITIONS_FILE="$LOOP_DIR/transitions.jsonl"
    if [[ ! -s "$TRANSITIONS_FILE" ]]; then
        if [[ "$CURRENT_ROUND" -eq 0 ]]; then
            return 0
        fi
        emit_block "Hermes transition ledger mismatch" "current_round is $CURRENT_ROUND, but $TRANSITIONS_FILE does not exist. Restart or repair the loop instead of editing state.md by hand."
        exit 10
    fi

    local last_to
    set +e
    last_to="$(last_transition_to "$TRANSITIONS_FILE")"
    local ledger_exit=$?
    set -e
    if [[ $ledger_exit -ne 0 || ! "$last_to" =~ ^[0-9]+$ ]]; then
        emit_block "Hermes transition ledger mismatch" "Could not read the last transition target from $TRANSITIONS_FILE."
        exit 10
    fi
    if [[ "$last_to" -ne "$CURRENT_ROUND" ]]; then
        emit_block "Hermes transition ledger mismatch" "current_round is $CURRENT_ROUND, but the last recorded transition target is $last_to. Do not advance RLCR state manually."
        exit 10
    fi
}

require_prompt_acknowledgement() {
    if [[ "$CURRENT_ROUND" -eq 0 ]]; then
        return 0
    fi

    local prompt_file="$LOOP_DIR/round-${CURRENT_ROUND}-prompt.md"
    if [[ ! -f "${prompt_file}.read" ]]; then
        emit_block "Hermes prompt was not acknowledged" "Before reviewing round $CURRENT_ROUND, read $prompt_file and create ${prompt_file}.read through hermes-rlcr-runner.sh."
        exit 10
    fi
}

append_transition() {
    local from_round="$1"
    local to_round="$2"
    local verdict="$3"
    local commit_id
    local summary_sha

    commit_id="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
    summary_sha="$(shasum -a 256 "$ROUND_SUMMARY" 2>/dev/null | awk '{ print $1 }')"

    python3 - "$TRANSITIONS_FILE" "$from_round" "$to_round" "$verdict" "$commit_id" "$summary_sha" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, from_round, to_round, verdict, commit_id, summary_sha = sys.argv[1:]
row = {
    "timestamp": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "from": int(from_round),
    "to": int(to_round),
    "verdict": verdict,
    "commit": commit_id,
    "summary_sha256": summary_sha,
}
with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
PY
}

run_hermes_review() {
    local stdout_file
    local stderr_file
    local heartbeat_seconds
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    heartbeat_seconds="${HERMES_REVIEW_HEARTBEAT_SECONDS:-30}"
    if [[ ! "$heartbeat_seconds" =~ ^[0-9]+$ || "$heartbeat_seconds" -lt 1 ]]; then
        heartbeat_seconds=30
    fi

    (
        cd "$PROJECT_ROOT" &&
        export CLAUDE_PROJECT_DIR="$PROJECT_ROOT" &&
        "$SCRIPT_DIR/ask-hermes.sh" \
            --hermes-provider "$HERMES_PROVIDER" \
            --hermes-model "$HERMES_MODEL" \
            --hermes-timeout "$HERMES_TIMEOUT" \
            "$PROMPT_CONTENT"
    ) >"$stdout_file" 2>"$stderr_file" &
    local hermes_pid=$!
    local elapsed=0

    while kill -0 "$hermes_pid" 2>/dev/null; do
        sleep 1
        elapsed=$((elapsed + 1))
        if kill -0 "$hermes_pid" 2>/dev/null; then
            if [[ $((elapsed % heartbeat_seconds)) -eq 0 ]]; then
                echo "Hermes review still running after ${elapsed}s; keep this foreground gate open." >&2
            fi
        fi
    done

    set +e
    wait "$hermes_pid"
    HERMES_EXIT=$?
    set -e

    if [[ -s "$stderr_file" ]]; then
        sed -n '1,240p' "$stderr_file" >&2
    fi
    HERMES_OUTPUT="$(cat "$stdout_file")"
    rm -f "$stdout_file" "$stderr_file"
}

PROJECT_ROOT="${PROJECT_ROOT:-$(resolve_project_root 2>/dev/null || true)}"
if [[ -z "$PROJECT_ROOT" ]]; then
    emit_allow "No project root detected."
    exit 0
fi
PROJECT_ROOT="$(canonicalize_path "$PROJECT_ROOT")"

STATE_FILE="$(latest_state_file "$PROJECT_ROOT" || true)"
if [[ -z "$STATE_FILE" ]]; then
    emit_allow "No active Hermes RLCR loop exists."
    exit 0
fi

LOOP_DIR="$(dirname "$STATE_FILE")"
CURRENT_ROUND="$(state_value "$STATE_FILE" current_round)"
CURRENT_ROUND="${CURRENT_ROUND:-0}"
if [[ ! "$CURRENT_ROUND" =~ ^[0-9]+$ ]]; then
    emit_block "Invalid Hermes RLCR State" "current_round must be numeric in $STATE_FILE."
    exit 10
fi

validate_transition_ledger
require_prompt_acknowledgement

ROUND_SUMMARY="$LOOP_DIR/round-${CURRENT_ROUND}-summary.md"
if [[ ! -s "$ROUND_SUMMARY" ]]; then
    emit_block "Missing round summary" "Expected $ROUND_SUMMARY before Hermes review."
    exit 10
fi

acquire_review_lock

if ! command -v hermes >/dev/null 2>&1; then
    emit_block "Hermes unavailable" "The hermes CLI is not installed or not in PATH."
    exit 10
fi

HERMES_PROVIDER="$(state_value "$STATE_FILE" hermes_provider)"
HERMES_MODEL="$(state_value "$STATE_FILE" hermes_model)"
HERMES_TIMEOUT="$(state_value "$STATE_FILE" hermes_timeout)"
HERMES_PROVIDER="${HERMES_PROVIDER:-deepseek}"
HERMES_MODEL="${HERMES_MODEL:-deepseek-chat}"
HERMES_TIMEOUT="${HERMES_TIMEOUT:-3600}"
if [[ ! "$HERMES_TIMEOUT" =~ ^[0-9]+$ ]]; then
    emit_block "Invalid Hermes RLCR State" "hermes_timeout must be numeric in $STATE_FILE."
    exit 10
fi

PLAN_FILE="$(state_value "$STATE_FILE" plan_file)"
PLAN_PATH=""
if [[ -n "$PLAN_FILE" ]]; then
    if [[ "$PLAN_FILE" = /* ]]; then
        PLAN_PATH="$PLAN_FILE"
    else
        PLAN_PATH="$PROJECT_ROOT/$PLAN_FILE"
    fi
fi

REVIEW_PROMPT="$LOOP_DIR/round-${CURRENT_ROUND}-review-prompt.md"
REVIEW_RESULT="$LOOP_DIR/round-${CURRENT_ROUND}-review-result.md"
GIT_STATUS="$(git -C "$PROJECT_ROOT" status --short 2>/dev/null || true)"
GIT_DIFF="$(git -C "$PROJECT_ROOT" diff --stat 2>/dev/null || true)"

{
    echo "# Hermes RLCR Review Prompt"
    echo ""
    echo "Review the active KernelPilot RLCR round."
    echo ""
    echo "Reply with one marker line as the first non-empty line:"
    echo "- COMPLETE when the implementation satisfies the plan and no further loop work is needed."
    echo "- NEEDS_CHANGES when another RLCR round should run."
    echo "- UNAVAILABLE when review cannot be completed."
    echo ""
    echo "## Loop"
    echo ""
    echo "- Round: $CURRENT_ROUND"
    echo "- Project root: $PROJECT_ROOT"
    echo "- State file: $STATE_FILE"
    echo ""
    echo "## Plan"
    echo ""
    if [[ -n "$PLAN_PATH" && -f "$PLAN_PATH" ]]; then
        sed -n '1,240p' "$PLAN_PATH"
    else
        echo "No readable plan file was configured."
    fi
    echo ""
    echo "## Round Summary"
    echo ""
    sed -n '1,240p' "$ROUND_SUMMARY"
    echo ""
    echo "## Git Status"
    echo ""
    if [[ -n "$GIT_STATUS" ]]; then
        printf '%s\n' "$GIT_STATUS"
    else
        echo "Working tree has no uncommitted file status."
    fi
    echo ""
    echo "## Git Diff Stat"
    echo ""
    if [[ -n "$GIT_DIFF" ]]; then
        printf '%s\n' "$GIT_DIFF"
    else
        echo "No diff stat is available."
    fi
} > "$REVIEW_PROMPT"

PROMPT_CONTENT="$(cat "$REVIEW_PROMPT")"
run_hermes_review

if [[ $HERMES_EXIT -ne 0 ]]; then
    printf '%s\n' "$HERMES_OUTPUT" > "$REVIEW_RESULT"
    emit_block "Hermes review failed" "ask-hermes.sh exited with code $HERMES_EXIT. Review output was saved to $REVIEW_RESULT."
    exit 10
fi

printf '%s\n' "$HERMES_OUTPUT" > "$REVIEW_RESULT"

# Some providers (observed live with deepseek-chat) explain their reasoning
# before the verdict and wrap the marker in markdown emphasis, e.g. a final
# line reading "**NEEDS_CHANGES**" instead of a bare first-line marker. Parse
# defensively: prefer an exact marker match on any line (after stripping
# markdown emphasis characters), then a line that starts with a marker word,
# and only fall back to the legacy "first token of the first line" heuristic
# if neither is found.
VERDICT="$(python3 - "$HERMES_OUTPUT" <<'PY'
import re
import sys

MARKERS = ("COMPLETE", "NEEDS_CHANGES", "UNAVAILABLE")
lines = sys.argv[1].splitlines()


def strip_emphasis(line):
    return re.sub(r"^[\s*_`#>-]+|[\s*_`]+$", "", line)


for line in lines:
    if strip_emphasis(line) in MARKERS:
        print(strip_emphasis(line))
        raise SystemExit(0)

for line in lines:
    stripped = strip_emphasis(line)
    for marker in MARKERS:
        if re.match(r"^" + marker + r"\b", stripped):
            print(marker)
            raise SystemExit(0)

for line in lines:
    if line.strip():
        print(line.split()[0])
        raise SystemExit(0)

print("")
PY
)"

case "$VERDICT" in
    COMPLETE)
        append_transition "$CURRENT_ROUND" "$CURRENT_ROUND" "COMPLETE"
        chmod a-w "$STATE_FILE" 2>/dev/null || true
        emit_allow "Hermes returned COMPLETE for round $CURRENT_ROUND."
        exit 0
        ;;
    NEEDS_CHANGES)
        NEXT_ROUND=$((CURRENT_ROUND + 1))
        append_transition "$CURRENT_ROUND" "$NEXT_ROUND" "NEEDS_CHANGES"
        set_state_current_round "$STATE_FILE" "$NEXT_ROUND"
        write_next_round_prompt "$NEXT_ROUND"
        emit_block "Hermes requested another round" "Hermes returned NEEDS_CHANGES. Continue with $LOOP_DIR/round-${NEXT_ROUND}-prompt.md."
        exit 10
        ;;
    UNAVAILABLE)
        emit_block "Hermes review unavailable" "Hermes returned $VERDICT. Review output was saved to $REVIEW_RESULT."
        exit 10
        ;;
    *)
        emit_block "Hermes returned unknown verdict" "Expected COMPLETE, NEEDS_CHANGES, or UNAVAILABLE as the first non-empty line. Review output was saved to $REVIEW_RESULT."
        exit 10
        ;;
esac
