#!/usr/bin/env bash
#
# 便捷包装器：为 Kimi 目标安装 Humanize 技能。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
bash "$SCRIPT_DIR/install-skill.sh" --target kimi "$@"
