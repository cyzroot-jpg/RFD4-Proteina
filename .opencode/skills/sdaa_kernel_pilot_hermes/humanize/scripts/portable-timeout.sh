#!/usr/bin/env bash
#
# 用于 macOS/Linux 兼容性的可移植超时封装器
# 用法: source portable-timeout.sh; run_with_timeout <seconds> <command> [args...]
#
# 优先级: gtimeout (Homebrew) > timeout (GNU) > python3 > 无超时
#

# 检测可用的超时实现
detect_timeout_impl() {
    if command -v gtimeout &>/dev/null; then
        echo "gtimeout"
        return
    fi
    if command -v timeout &>/dev/null; then
        # 要求可识别的 GNU coreutils 输出以避免匹配垫片
        # （垫片通常对 --version 不输出任何内容，且输出中缺少 "timeout"）
        if timeout --version 2>&1 | grep -qiE 'GNU|coreutils|timeout [0-9]'; then
            echo "timeout"
            return
        fi
    fi
    if command -v python3 &>/dev/null; then
        echo "python3"
        return
    fi
    if command -v python &>/dev/null; then
        echo "python"
        return
    fi
    echo "none"
}

TIMEOUT_IMPL=$(detect_timeout_impl)

# 带超时运行命令
# 参数: timeout_seconds command [args...]
run_with_timeout() {
    local timeout_secs="$1"
    shift
    local cmd=("$@")

    case "$TIMEOUT_IMPL" in
        gtimeout)
            gtimeout "$timeout_secs" "${cmd[@]}"
            return $?
            ;;
        timeout)
            timeout "$timeout_secs" "${cmd[@]}"
            return $?
            ;;
        python3|python)
            # 使用 Python 的 subprocess 并设置超时
            "$TIMEOUT_IMPL" -c "
import subprocess
import sys

try:
    result = subprocess.run(sys.argv[1:], timeout=$timeout_secs)
    sys.exit(result.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)  # 匹配 GNU timeout 退出码
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" "${cmd[@]}"
            return $?
            ;;
        none)
            # 没有可用的超时 - 无超时运行
            echo "Warning: No timeout implementation available. Running without timeout." >&2
            "${cmd[@]}"
            return $?
            ;;
    esac
}

# 使 TIMEOUT_IMPL 对导入脚本可用
# 注意: export -f 是 bash 特有的，但不需要，因为该函数
# 直接在导入脚本中使用，而不是在子进程中使用
export TIMEOUT_IMPL
