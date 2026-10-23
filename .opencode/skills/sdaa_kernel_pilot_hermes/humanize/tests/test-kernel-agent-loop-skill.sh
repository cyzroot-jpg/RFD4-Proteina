#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$PROJECT_ROOT/skills/humanize-kernel-agent-loop/SKILL.md"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -f "$SKILL_FILE" ]] || fail "missing kernel-agent-loop skill"

grep -q '## Bootstrap gate' "$SKILL_FILE" \
    || fail "skill does not define a pre-RLCR bootstrap gate"
grep -q 'Do not implement or benchmark a candidate before RLCR is' "$SKILL_FILE" \
    || fail "skill does not forbid candidate work before RLCR"
grep -q 'teco-ops checkout itself' "$SKILL_FILE" \
    || fail "skill does not use the target checkout as the workspace"
grep -q 'find .humanize/rlcr -maxdepth 2 -name state.md -print' "$SKILL_FILE" \
    || fail "skill does not verify active RLCR state"
grep -q 'Stop if no state file exists' "$SKILL_FILE" \
    || fail "skill does not fail closed when RLCR setup does not create state"
grep -q -- '--strict-success' "$SKILL_FILE" \
    || fail "skill does not start RLCR in strict-success mode"
grep -q -- '--warm_repeat=3 --perf_repeat=50' "$SKILL_FILE" \
    || fail "skill does not preserve the native teco-ops repeat policy"
grep -q -- '--warm_repeat=0 --perf_repeat=0' "$SKILL_FILE" \
    || fail "skill does not require a standalone correctness gate"
grep -q -- 'bash build.sh --arch teco -f "$OP"' "$SKILL_FILE" \
    || fail "skill does not filter the test build to the selected operator"
grep -q 'Average Hardware Time' "$SKILL_FILE" \
    || fail "skill does not use native teco-ops hardware time"
grep -q '{{TECO_OPS_WIKI_ROOT}}' "$SKILL_FILE" \
    || fail "skill does not hydrate the exclusive wiki root"

python3 - "$SKILL_FILE" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
bootstrap = text.index("## Bootstrap gate")
iteration = text.index("## Iteration")
if bootstrap > iteration:
    print("FAIL: bootstrap gate appears after candidate iteration", file=sys.stderr)
    sys.exit(1)
PY

echo "PASS: teco-ops kernel-agent loop gates work on active RLCR"
