#!/usr/bin/env bash
#
# 测试手动测试脚本
#
# 此脚本用于验证以下内容：
# - 删除 .humanize/ 目录后能正常退出并显示友好的用户消息
# - 优雅停止后终端状态能正确恢复
#
# 使用方法：
# 1. 在终端 1 中：cd 到项目根目录，运行 ./tests/manual-monitor-test.sh setup
# 2. 在终端 2 中：cd 到项目根目录，运行：source scripts/humanize.sh && humanize monitor rlcr
# 3. 在终端 1 中：运行 ./tests/manual-monitor-test.sh delete
# 4. 观察终端 2：应看到正常的退出消息，终端应已恢复
# 5. 清理：运行 ./tests/manual-monitor-test.sh cleanup
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

case "${1:-}" in
    setup)
        echo "Setting up test directories..."
        mkdir -p .humanize/rlcr/2026-01-16_99-99-99
        echo "current_round: 1
max_iterations: 5
codex_model: test
codex_effort: high
started_at: 2026-01-16T00:00:00Z
plan_file: test-plan.md" > .humanize/rlcr/2026-01-16_99-99-99/state.md
        echo "# Goal Tracker
## IMMUTABLE SECTION
### Ultimate Goal
Test
### Acceptance Criteria
- AC-1: Test" > .humanize/rlcr/2026-01-16_99-99-99/goal-tracker.md
        echo ""
        echo "Setup complete. Test directories created:"
        echo "  .humanize/rlcr/2026-01-16_99-99-99/"
        echo ""
        echo "Next steps:"
        echo "1. In another terminal, run: source scripts/humanize.sh && humanize monitor rlcr"
        echo "2. Then come back here and run: ./tests/manual-monitor-test.sh delete"
        ;;
    delete)
        echo "Deleting .humanize directory..."
        rm -rf .humanize
        echo ""
        echo "Done. Check the monitor terminal for:"
        echo "  - Clean exit message: 'Monitoring stopped: .humanize/rlcr directory no longer exists'"
        echo "  - Terminal should be restored (scroll region reset, cursor at bottom)"
        echo "  - No zsh/bash 'no matches found' errors"
        echo ""
        echo "If everything looks good, the tests are verified!"
        ;;
    cleanup)
        echo "Cleaning up..."
        rm -rf .humanize
        echo "Done."
        ;;
    *)
        echo "Usage: $0 {setup|delete|cleanup}"
        echo ""
        echo "Commands:"
        echo "  setup   - Create test .humanize directory with session"
        echo "  delete  - Delete .humanize directory (triggers graceful stop)"
        echo "  cleanup - Remove any leftover test directories"
        exit 1
        ;;
esac
