#!/usr/bin/env bash
#
# Run the Hermes KernelPilot operational test set.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS=(
    "test-hermes-wrapper.sh"
    "test-hermes-install.sh"
    "test-hermes-hook-install.sh"
    "test-hermes-stop-gate.sh"
    "test-hermes-pre-verify-hook.sh"
    "test-hermes-rlcr-runner.sh"
    "test-hermes-health-check.sh"
    "test-model-router.sh"
    "test-strict-success.sh"
    "test-kernel-agent-loop-skill.sh"
)

bash -n \
    "$PROJECT_ROOT/scripts/ask-hermes.sh" \
    "$PROJECT_ROOT/scripts/hermes-stop-gate.sh" \
    "$PROJECT_ROOT/scripts/install-hermes-hooks.sh" \
    "$PROJECT_ROOT/scripts/hermes-rlcr-runner.sh" \
    "$PROJECT_ROOT/scripts/hermes-health-check.sh" \
    "$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" \
    "$PROJECT_ROOT/hooks/loop-hermes-pre-verify-hook.sh" \
    "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh"

for test_name in "${TESTS[@]}"; do
    echo "==> $test_name"
    bash "$SCRIPT_DIR/$test_name"
done

echo "Hermes operational tests passed."
