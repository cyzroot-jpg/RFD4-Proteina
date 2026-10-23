#!/usr/bin/env bash
# TECO 设备信息查询（封装 device_info.py）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "TECO 设备信息查询"
echo "================================"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found" >&2
    exit 1
fi

if ! python3 "$SCRIPT_DIR/device_info.py" --json; then
    echo ""
    echo "查询失败。请确认："
    echo "  1. 已安装 TECO SDK 并 source /opt/tecoai/setvars.sh"
    echo "  2. teco-smi 在 PATH 中且驱动正常"
    exit 1
fi

echo ""
echo "空闲设备 index (gid:auto):"
python3 "$SCRIPT_DIR/device_info.py" --idle
