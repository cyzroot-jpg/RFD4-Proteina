#!/usr/bin/env bash
# SDAA 环境检查脚本
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0
WARNINGS=0
JSON_MODE=false
JSON_OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        -o) JSON_OUTPUT="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

declare -a CHECK_ROWS=()

_add_check() {
    local name="$1"
    local result="$2"
    local detail="$3"
    CHECK_ROWS+=("{\"name\":\"$name\",\"result\":\"$result\",\"detail\":\"$(echo "$detail" | sed 's/"/\\"/g')\"}")
    case "$result" in
        fail) ERRORS=$((ERRORS + 1)) ;;
        warn) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

_find_setvars() {
    local candidates=(
        "${TECOAI_SETVARS:-}"
        "/opt/tecoai/setvars.sh"
        "${TECOAI_ROOT:-}/setvars.sh"
        "${SDAA_HOME:-}/setvars.sh"
    )
    for p in "${candidates[@]}"; do
        if [[ -n "$p" && -f "$p" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

_find_sdaa_runtime_header() {
    local candidates=(
        "/opt/tecoai/include/sdaa_runtime.h"
        "${TECOAI_ROOT:-}/include/sdaa_runtime.h"
        "${SDAA_HOME:-}/include/sdaa_runtime.h"
    )
    for p in "${candidates[@]}"; do
        if [[ -f "$p" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

echo "================================"
echo "SDAA 环境检查"
echo "================================"
echo ""

# [1/6] setvars.sh
echo -e "${YELLOW}[1/6] 检查 TECO SDK (setvars.sh)...${NC}"
SETVARS_PATH=""
if SETVARS_PATH="$(_find_setvars)"; then
    echo -e "${GREEN}✓ setvars.sh = $SETVARS_PATH${NC}"
    _add_check "setvars" "pass" "$SETVARS_PATH"
else
    echo -e "${RED}✗ 未找到 setvars.sh${NC}"
    echo "  建议: source /opt/tecoai/setvars.sh"
    _add_check "setvars" "fail" "setvars.sh not found"
fi
echo ""

# [2/6] tecocc
echo -e "${YELLOW}[2/6] 检查 tecocc 编译器...${NC}"
if [[ -n "$SETVARS_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$SETVARS_PATH" >/dev/null 2>&1 || true
fi
if command -v tecocc >/dev/null 2>&1; then
    TECOCC_VER="$(tecocc --version 2>/dev/null | head -1 || echo 'unknown')"
    echo -e "${GREEN}✓ tecocc 可用: $TECOCC_VER${NC}"
    _add_check "tecocc" "pass" "$TECOCC_VER"
else
    echo -e "${RED}✗ tecocc 不可用${NC}"
    _add_check "tecocc" "fail" "tecocc not in PATH"
fi
echo ""

# [3/6] cmake
echo -e "${YELLOW}[3/6] 检查 cmake...${NC}"
if command -v cmake >/dev/null 2>&1; then
    CMAKE_VER="$(cmake --version | head -1)"
    echo -e "${GREEN}✓ $CMAKE_VER${NC}"
    _add_check "cmake" "pass" "$CMAKE_VER"
else
    echo -e "${RED}✗ cmake 不可用${NC}"
    _add_check "cmake" "fail" "cmake not in PATH"
fi
echo ""

# [4/6] SDAA runtime header
echo -e "${YELLOW}[4/6] 检查 SDAA Runtime 头文件...${NC}"
if RUNTIME_HDR="$(_find_sdaa_runtime_header)"; then
    echo -e "${GREEN}✓ sdaa_runtime.h = $RUNTIME_HDR${NC}"
    _add_check "sdaa_runtime" "pass" "$RUNTIME_HDR"
else
    echo -e "${RED}✗ 未找到 sdaa_runtime.h${NC}"
    _add_check "sdaa_runtime" "fail" "sdaa_runtime.h not found"
fi
echo ""

# [5/6] teco-smi
echo -e "${YELLOW}[5/6] 检查 teco-smi / 设备...${NC}"
DEVICE_JSON="null"
if command -v teco-smi >/dev/null 2>&1; then
    echo -e "${GREEN}✓ teco-smi 可用${NC}"
    _add_check "teco-smi" "pass" "teco-smi in PATH"
    if python3 "$SCRIPT_DIR/device_info.py" --json >/tmp/sdaa_device_info.json 2>/dev/null; then
        DEVICE_JSON="$(cat /tmp/sdaa_device_info.json)"
        python3 - "$DEVICE_JSON" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
print(f"  设备: {data.get('device_name', 'unknown')}, count={data.get('device_count', 0)}")
print(f"  SPE 时钟: {data.get('spe_clock_mhz', 'n/a')} MHz (max {data.get('spe_clock_max_mhz', 'n/a')} MHz)")
print(f"  显存: {data.get('memory_total_mb', 'n/a')} MB, 驱动: {data.get('driver_version', 'n/a')}")
PY
        _add_check "device_query" "pass" "teco-smi query ok"
    else
        echo -e "${YELLOW}⚠ teco-smi 存在但查询失败${NC}"
        _add_check "device_query" "warn" "teco-smi query failed"
    fi
else
    echo -e "${YELLOW}⚠ teco-smi 不可用（无硬件或驱动未加载）${NC}"
    _add_check "teco-smi" "warn" "teco-smi not in PATH"
fi
echo ""

# [6/6] optional SDPTI + python
echo -e "${YELLOW}[6/6] 检查可选依赖 (SDPTI / python3)...${NC}"
SDPTI_ROOT="${SDPTI_SDK_ROOT:-}"
if [[ -z "$SDPTI_ROOT" ]]; then
    for p in "${TECOAI_ROOT:-}/sdpti" "/opt/tecoai/sdpti"; do
        if [[ -d "$p/include" && -d "$p/lib64" ]]; then
            SDPTI_ROOT="$p"
            break
        fi
    done
fi
if [[ -n "$SDPTI_ROOT" && -f "$SDPTI_ROOT/include/sdpti.h" ]]; then
    echo -e "${GREEN}✓ SDPTI SDK = $SDPTI_ROOT${NC}"
    _add_check "sdpti" "pass" "$SDPTI_ROOT"
else
    echo -e "${YELLOW}⚠ SDPTI SDK 未配置（仅性能采集需要）${NC}"
    _add_check "sdpti" "warn" "SDPTI SDK not found"
fi

if command -v python3 >/dev/null 2>&1; then
    PY_VER="$(python3 --version 2>&1)"
    echo -e "${GREEN}✓ $PY_VER${NC}"
    _add_check "python3" "pass" "$PY_VER"
else
    echo -e "${YELLOW}⚠ python3 不可用${NC}"
    _add_check "python3" "warn" "python3 not in PATH"
fi
echo ""

# Summary
echo "================================"
echo "检查结果"
echo "================================"
if [[ $ERRORS -gt 0 ]]; then
    STATUS="fail"
    echo -e "${RED}✗ 发现 $ERRORS 个错误, $WARNINGS 个警告${NC}"
    EXIT_CODE=1
elif [[ $WARNINGS -gt 0 ]]; then
    STATUS="warn"
    echo -e "${YELLOW}⚠ 发现 $WARNINGS 个警告${NC}"
    EXIT_CODE=0
else
    STATUS="pass"
    echo -e "${GREEN}✓ 环境检查通过${NC}"
    EXIT_CODE=0
fi

if [[ "$JSON_MODE" == true ]]; then
    CHECKS_JSON="$(printf '%s\n' "${CHECK_ROWS[@]}" | paste -sd, -)"
    JSON_DOC="{\"status\":\"$STATUS\",\"errors\":$ERRORS,\"warnings\":$WARNINGS,\"checks\":[$CHECKS_JSON],\"device\":$DEVICE_JSON}"
    if [[ -n "$JSON_OUTPUT" ]]; then
        echo "$JSON_DOC" > "$JSON_OUTPUT"
        echo "Wrote $JSON_OUTPUT"
    else
        echo "$JSON_DOC"
    fi
fi

exit "$EXIT_CODE"
