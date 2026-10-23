#!/usr/bin/env bash
#
# Convenience wrapper: install Humanize skills for the Hermes target.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
bash "$SCRIPT_DIR/install-skill.sh" --target hermes "$@"
