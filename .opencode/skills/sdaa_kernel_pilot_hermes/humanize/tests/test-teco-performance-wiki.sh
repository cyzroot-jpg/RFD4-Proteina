#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=========================================="
echo "TECO Performance and Wiki Tests"
echo "=========================================="

WIKI_ROOT="$PROJECT_ROOT/external/teco-ops-wiki"
LOOP_SKILL="$PROJECT_ROOT/humanize/skills/humanize-kernel-agent-loop/SKILL.md"
OP_TEST_SKILL="$PROJECT_ROOT/humanize/skills/teco-ops-op-test/SKILL.md"
INSTALL_SCRIPT="$PROJECT_ROOT/humanize/scripts/install-skill.sh"
TECO_SNAPSHOT="$WIKI_ROOT/artifacts/repos/teco-ops"

for path in \
    "$WIKI_ROOT/SKILL.md" \
    "$WIKI_ROOT/scripts/query.py" \
    "$WIKI_ROOT/scripts/get_page.py" \
    "$WIKI_ROOT/data/tags.yaml" \
    "$LOOP_SKILL" \
    "$OP_TEST_SKILL"; do
    [[ -e "$path" ]] || fail "missing migrated component: $path"
done

grep -q '{{TECO_OPS_WIKI_ROOT}}' "$LOOP_SKILL" \
    || fail "kernel loop does not expose the exclusive wiki root"
grep -q -- '--warm_repeat=3 --perf_repeat=50' "$LOOP_SKILL" \
    || fail "kernel loop does not preserve the teco-ops README repeat policy"
grep -q -- '--warm_repeat=0 --perf_repeat=0' "$LOOP_SKILL" \
    || fail "kernel loop does not require a standalone correctness gate"
grep -q -- 'bash build.sh --arch teco -f "$OP"' "$LOOP_SKILL" \
    || fail "kernel loop does not filter the test build to the selected operator"
grep -q 'Average Hardware Time' "$LOOP_SKILL" \
    || fail "kernel loop does not use the native hardware-time metric"
grep -q 'SDPTI' "$OP_TEST_SKILL" \
    || fail "teco-ops test skill does not identify the native device profiler"
grep -q 'discards the highest and lowest five samples' "$OP_TEST_SKILL" \
    || fail "teco-ops test skill does not document the trimmed mean"
grep -q 'TECO_OPS_WIKI_ROOT' "$INSTALL_SCRIPT" \
    || fail "installer does not hydrate teco-ops-wiki"
grep -q 'ac7eb023faa0c84bdd8d9959561a59d44105da6e' "$TECO_SNAPSHOT/PROVENANCE.md" \
    || fail "teco-ops snapshot provenance is not pinned to the requested latest commit"
for op in causal_conv1d flash_attention flatten_rays memset morton3D_invert reduce_variance reshape_and_cache rms_norm; do
    [[ -d "$TECO_SNAPSHOT/teco/ual/kernel/$op" ]] \
        || fail "latest teco-ops snapshot is missing operator: $op"
done

if grep -R -n -E 'SDAAKernelWiki|KernelWiki|ncu-report-skill|optest-skill|optest-agent|performance-map|kernel-bench|tecoal-op-test|tecolmk-op-test' \
    "$PROJECT_ROOT/README.md" \
    "$PROJECT_ROOT/AGENTS.md" \
    "$PROJECT_ROOT/CLAUDE.md" \
    "$PROJECT_ROOT/docs/sdaa-hermes-runbook.md" \
    "$PROJECT_ROOT/prompts" \
    "$PROJECT_ROOT/humanize/skills" \
    "$PROJECT_ROOT/humanize/docs"; then
    fail "an active path still references a retired wiki or performance method"
fi
if grep -E 'KERNELWIKI_ROOT|SDAA_KERNELWIKI_ROOT|NCU_REPORT_SKILL_ROOT|OPTEST_AGENT_ROOT' \
    "$PROJECT_ROOT/humanize/scripts/install-skill.sh" \
    "$PROJECT_ROOT/humanize/scripts/install-skills-claude.sh"; then
    fail "an installer still resolves a retired dependency"
fi

python3 "$WIKI_ROOT/scripts/query.py" "DMA" --limit 1 --compact >/dev/null
python3 "$WIKI_ROOT/scripts/query.py" "Average Hardware Time" --limit 1 --compact >/dev/null
pass "teco-ops native correctness/performance flow and exclusive wiki are wired"
print_test_summary "TECO Performance and Wiki Test Summary"
