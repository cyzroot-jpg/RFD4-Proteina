#!/usr/bin/env bash
#
# 辅助脚本：设置监控器测试环境
# 此脚本创建必要的目录结构和状态文件，
# 用于测试 monitor 命令。
#
# 用法：./setup-monitor-test-env.sh <test_dir> <test_name>
#

set -euo pipefail

TEST_DIR="${1:-}"
TEST_NAME="${2:-default}"

if [[ -z "$TEST_DIR" ]]; then
    echo "Usage: $0 <test_dir> <test_name>" >&2
    exit 1
fi

case "$TEST_NAME" in
    *)
        echo "Unknown test name: $TEST_NAME" >&2
        echo "Available: (none currently)" >&2
        exit 1
        ;;
esac

echo "$TEST_DIR"
