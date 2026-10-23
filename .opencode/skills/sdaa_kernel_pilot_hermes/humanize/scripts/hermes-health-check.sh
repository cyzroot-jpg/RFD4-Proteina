#!/usr/bin/env bash
#
# Hermes KernelPilot health check.
#
# This script validates the pieces required to run the Hermes-backed SDAA
# KernelPilot workflow on a target machine.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_LIVE="false"
RUN_WIKI_QUERY="true"
HERMES_TIMEOUT=120

usage() {
    cat <<'EOF'
Usage: hermes-health-check.sh [OPTIONS]

Options:
  --project-root PATH   KernelPilot Hermes checkout root.
  --live                Run a real Hermes/DeepSeek request through ask-hermes.sh.
  --skip-live           Do not run a live Hermes request (default).
  --skip-wiki-query     Only check teco-ops-wiki files; do not run query.py.
  --hermes-timeout N    Timeout for live Hermes request (default: 120).
  -h, --help            Show help.
EOF
}

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

need_file() {
    local path="$1"
    local label="$2"
    if [[ -f "$path" ]]; then
        pass "$label"
    else
        fail "$label missing: $path"
    fi
}

need_executable_or_file() {
    local path="$1"
    local label="$2"
    if [[ -f "$path" ]]; then
        pass "$label"
    else
        fail "$label missing: $path"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            [[ -n "${2:-}" ]] || { echo "Error: --project-root requires a value" >&2; exit 2; }
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --live)
            RUN_LIVE="true"
            shift
            ;;
        --skip-live)
            RUN_LIVE="false"
            shift
            ;;
        --skip-wiki-query)
            RUN_WIKI_QUERY="false"
            shift
            ;;
        --hermes-timeout)
            [[ -n "${2:-}" ]] || { echo "Error: --hermes-timeout requires a value" >&2; exit 2; }
            [[ "$2" =~ ^[0-9]+$ ]] || { echo "Error: --hermes-timeout must be numeric" >&2; exit 2; }
            HERMES_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: project root is not a directory: $PROJECT_ROOT" >&2
    exit 2
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "Hermes KernelPilot health check"
echo "Project root: $PROJECT_ROOT"
echo ""

for cmd in bash git python3 jq; do
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "command available: $cmd"
    else
        fail "command missing: $cmd"
    fi
done

if command -v hermes >/dev/null 2>&1; then
    HERMES_VERSION="$(hermes --version 2>/dev/null | head -1 || true)"
    pass "Hermes CLI available${HERMES_VERSION:+: $HERMES_VERSION}"
else
    fail "Hermes CLI missing"
fi

need_file "$PROJECT_ROOT/humanize/scripts/ask-hermes.sh" "ask-hermes wrapper"
need_file "$PROJECT_ROOT/humanize/scripts/setup-rlcr-loop.sh" "RLCR setup script"
need_file "$PROJECT_ROOT/humanize/scripts/hermes-stop-gate.sh" "Hermes stop gate"
need_file "$PROJECT_ROOT/humanize/scripts/hermes-rlcr-runner.sh" "Hermes RLCR runner"
need_file "$PROJECT_ROOT/humanize/scripts/install-hermes-hooks.sh" "Hermes hook installer"
need_file "$PROJECT_ROOT/humanize/hooks/loop-hermes-pre-verify-hook.sh" "Hermes pre_verify hook"
need_file "$PROJECT_ROOT/humanize/skills/humanize-kernel-agent-loop/SKILL.md" "kernel-agent-loop skill"
need_file "$PROJECT_ROOT/humanize/skills/teco-ops-op-test/SKILL.md" "teco-ops native test skill"

need_file "$PROJECT_ROOT/external/teco-ops-wiki/SKILL.md" "teco-ops-wiki skill"
need_file "$PROJECT_ROOT/external/teco-ops-wiki/scripts/query.py" "teco-ops-wiki query script"
need_file "$PROJECT_ROOT/external/teco-ops-wiki/scripts/get_page.py" "teco-ops-wiki page script"
need_file "$PROJECT_ROOT/external/teco-ops-wiki/data/tags.yaml" "teco-ops-wiki tags"

if [[ "$RUN_WIKI_QUERY" == "true" && -f "$PROJECT_ROOT/external/teco-ops-wiki/scripts/query.py" ]]; then
    if (cd "$PROJECT_ROOT/external/teco-ops-wiki" && python3 scripts/query.py "DMA" --limit 1 --compact >/tmp/hermes-health-teco-query.out 2>/tmp/hermes-health-teco-query.err); then
        pass "teco-ops-wiki query smoke test"
    else
        fail "teco-ops-wiki query smoke test failed; see /tmp/hermes-health-teco-query.err"
    fi
fi

if [[ "$RUN_LIVE" == "true" ]]; then
    if "$PROJECT_ROOT/humanize/scripts/ask-hermes.sh" --hermes-timeout "$HERMES_TIMEOUT" "Reply exactly: OK" >/tmp/hermes-health-live.out 2>/tmp/hermes-health-live.err; then
        if grep -q '^OK$' /tmp/hermes-health-live.out; then
            pass "live Hermes request"
        else
            fail "live Hermes request returned unexpected output; see /tmp/hermes-health-live.out"
        fi
    else
        fail "live Hermes request failed; see /tmp/hermes-health-live.err"
    fi
else
    pass "live Hermes request skipped"
fi

echo ""
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo "Hermes KernelPilot health check passed"
    exit 0
fi

echo "Hermes KernelPilot health check failed" >&2
exit 1
