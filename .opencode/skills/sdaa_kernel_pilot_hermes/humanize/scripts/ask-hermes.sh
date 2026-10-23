#!/usr/bin/env bash
#
# Ask Hermes - one-shot consultation with NousResearch Hermes Agent.
#
# This wrapper is intentionally Hermes-only. It never falls back to Codex or
# Claude, because the Hermes KernelPilot runtime must fail closed when Hermes is
# unavailable or unconfigured.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/portable-timeout.sh"

HOOKS_LIB_DIR="$(cd "$SCRIPT_DIR/../hooks/lib" && pwd)"
source "$HOOKS_LIB_DIR/loop-common.sh"

DEFAULT_ASK_HERMES_TIMEOUT=3600
HERMES_MODEL="${HERMES_MODEL:-}"
HERMES_PROVIDER="${HERMES_PROVIDER:-}"
HERMES_TIMEOUT="$DEFAULT_ASK_HERMES_TIMEOUT"
DRY_RUN="false"

show_help() {
    cat <<'HELP_EOF'
ask-hermes - One-shot consultation with Hermes Agent

USAGE:
  ask-hermes.sh [OPTIONS] <question or task>

OPTIONS:
  --hermes-model <MODEL>     Hermes model name (default: config.yaml model)
  --hermes-provider <NAME>   Hermes provider name (default: config.yaml provider)
  --hermes-timeout <SECONDS> Timeout for the Hermes query in seconds (default: 3600)
  --dry-run                  Write input/metadata without invoking Hermes
  -h, --help                 Show this help message

DESCRIPTION:
  Sends a one-shot question or task to Hermes and returns the response. The
  response and metadata are saved under .humanize/skill/<unique-id>/.

  Live calls require the `hermes` CLI and a configured Hermes provider. Dry runs
  are used by tests and installer validation and do not require provider auth.
HELP_EOF
    exit 0
}

QUESTION_PARTS=()
OPTIONS_DONE=false

while [[ $# -gt 0 ]]; do
    if [[ "$OPTIONS_DONE" == "true" ]]; then
        QUESTION_PARTS+=("$1")
        shift
        continue
    fi

    case "$1" in
        -h|--help)
            show_help
            ;;
        --)
            OPTIONS_DONE=true
            shift
            ;;
        --hermes-model)
            [[ -n "${2:-}" ]] || { echo "Error: --hermes-model requires a value" >&2; exit 1; }
            HERMES_MODEL="$2"
            shift 2
            ;;
        --hermes-provider)
            [[ -n "${2:-}" ]] || { echo "Error: --hermes-provider requires a value" >&2; exit 1; }
            HERMES_PROVIDER="$2"
            shift 2
            ;;
        --hermes-timeout)
            [[ -n "${2:-}" ]] || { echo "Error: --hermes-timeout requires a number argument" >&2; exit 1; }
            [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: --hermes-timeout must be a positive integer, got: $2" >&2; exit 1; }
            HERMES_TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            QUESTION_PARTS+=("$1")
            OPTIONS_DONE=true
            shift
            ;;
    esac
done

QUESTION="${QUESTION_PARTS[*]+"${QUESTION_PARTS[*]}"}"

if [[ -z "$QUESTION" ]]; then
    echo "Error: No question or task provided" >&2
    echo "Usage: ask-hermes.sh [OPTIONS] <question or task>" >&2
    exit 1
fi

if [[ -n "$HERMES_MODEL" && ! "$HERMES_MODEL" =~ ^[a-zA-Z0-9._:/@+-]+$ ]]; then
    echo "Error: Hermes model contains invalid characters" >&2
    echo "  Model: $HERMES_MODEL" >&2
    exit 1
fi

if [[ -n "$HERMES_PROVIDER" && ! "$HERMES_PROVIDER" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
    echo "Error: Hermes provider contains invalid characters" >&2
    echo "  Provider: $HERMES_PROVIDER" >&2
    exit 1
fi

PROJECT_ROOT="$(resolve_project_root)" || {
    echo "Error: Cannot determine project root." >&2
    echo "  Set CLAUDE_PROJECT_DIR or run inside a git repository." >&2
    exit 1
}

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
UNIQUE_ID="${TIMESTAMP}-$$-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
SKILL_DIR="$PROJECT_ROOT/.humanize/skill/$UNIQUE_ID"
mkdir -p "$SKILL_DIR"

SANITIZED_PROJECT_PATH=$(echo "$PROJECT_ROOT" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$CACHE_BASE/humanize/$SANITIZED_PROJECT_PATH/skill-$UNIQUE_ID"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="$SKILL_DIR/cache"
    mkdir -p "$CACHE_DIR"
    echo "ask-hermes: warning: home cache not writable, using $CACHE_DIR" >&2
fi

cat > "$SKILL_DIR/input.md" <<EOF
# Ask Hermes Input

## Question

$QUESTION

## Configuration

- Model: ${HERMES_MODEL:-config-default}
- Provider: ${HERMES_PROVIDER:-config-default}
- Timeout: ${HERMES_TIMEOUT}s
- Timestamp: $TIMESTAMP
- Tool: hermes
- Dry run: $DRY_RUN
EOF

epoch_to_iso() {
    local epoch="$1"
    date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    echo "unknown"
}

HERMES_CMD_FILE="$CACHE_DIR/hermes-run.cmd"
HERMES_STDOUT_FILE="$CACHE_DIR/hermes-run.out"
HERMES_STDERR_FILE="$CACHE_DIR/hermes-run.log"

{
    echo "# Hermes ask-hermes invocation"
    echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Working directory: $PROJECT_ROOT"
    echo "# Timeout: $HERMES_TIMEOUT seconds"
    echo ""
    echo "hermes chat -Q ${HERMES_PROVIDER:+--provider $HERMES_PROVIDER} ${HERMES_MODEL:+-m $HERMES_MODEL} -q \"<prompt>\""
    echo ""
    echo "# Prompt:"
    echo "$QUESTION"
} > "$HERMES_CMD_FILE"

if [[ "$DRY_RUN" == "true" ]]; then
    cat > "$SKILL_DIR/output.md" <<EOF
DRY_RUN: Hermes was not invoked.
EOF
    cat > "$SKILL_DIR/metadata.md" <<EOF
---
tool: hermes
model: $HERMES_MODEL
provider: $HERMES_PROVIDER
timeout: $HERMES_TIMEOUT
exit_code: 0
duration: 0s
status: dry_run
started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
output_path: $SKILL_DIR/output.md
---
EOF
    echo "ask-hermes: dry_run=true metadata=$SKILL_DIR/metadata.md" >&2
    cat "$SKILL_DIR/output.md"
    exit 0
fi

if ! command -v hermes >/dev/null 2>&1; then
    echo "Error: 'hermes' command is not installed or not in PATH" >&2
    echo "Install: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash" >&2
    exit 1
fi

echo "ask-hermes: model=${HERMES_MODEL:-config-default} timeout=${HERMES_TIMEOUT}s" >&2
echo "ask-hermes: provider=${HERMES_PROVIDER:-config-default}" >&2
echo "ask-hermes: cache=$CACHE_DIR" >&2
echo "ask-hermes: running hermes chat..." >&2

START_TIME=$(date +%s)
HERMES_EXIT_CODE=0
HERMES_ARGS=(chat -Q)
[[ -n "$HERMES_PROVIDER" ]] && HERMES_ARGS+=(--provider "$HERMES_PROVIDER")
[[ -n "$HERMES_MODEL" ]] && HERMES_ARGS+=(-m "$HERMES_MODEL")
HERMES_ARGS+=(-q "$QUESTION")
run_with_timeout "$HERMES_TIMEOUT" hermes "${HERMES_ARGS[@]}" \
    > "$HERMES_STDOUT_FILE" 2> "$HERMES_STDERR_FILE" || HERMES_EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ $HERMES_EXIT_CODE -eq 124 ]]; then
    echo "Error: Hermes timed out after ${HERMES_TIMEOUT} seconds" >&2
    cat > "$SKILL_DIR/metadata.md" <<EOF
---
tool: hermes
model: $HERMES_MODEL
provider: $HERMES_PROVIDER
timeout: $HERMES_TIMEOUT
exit_code: 124
duration: ${DURATION}s
status: timeout
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 124
fi

if [[ $HERMES_EXIT_CODE -ne 0 ]]; then
    echo "Error: Hermes exited with code $HERMES_EXIT_CODE" >&2
    [[ -s "$HERMES_STDERR_FILE" ]] && tail -20 "$HERMES_STDERR_FILE" >&2
    cat > "$SKILL_DIR/metadata.md" <<EOF
---
tool: hermes
model: $HERMES_MODEL
provider: $HERMES_PROVIDER
timeout: $HERMES_TIMEOUT
exit_code: $HERMES_EXIT_CODE
duration: ${DURATION}s
status: error
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit "$HERMES_EXIT_CODE"
fi

if [[ ! -s "$HERMES_STDOUT_FILE" ]]; then
    echo "Error: Hermes returned empty response" >&2
    cat > "$SKILL_DIR/metadata.md" <<EOF
---
tool: hermes
model: $HERMES_MODEL
provider: $HERMES_PROVIDER
timeout: $HERMES_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: empty_response
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 1
fi

cp "$HERMES_STDOUT_FILE" "$SKILL_DIR/output.md"
cat > "$SKILL_DIR/metadata.md" <<EOF
---
tool: hermes
model: $HERMES_MODEL
provider: $HERMES_PROVIDER
timeout: $HERMES_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: success
started_at: $(epoch_to_iso "$START_TIME")
output_path: $SKILL_DIR/output.md
---
EOF

echo "ask-hermes: response saved to $SKILL_DIR/output.md" >&2
cat "$HERMES_STDOUT_FILE"
