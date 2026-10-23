#!/usr/bin/env bash
#
# cancel-rlcr-loop 的取消脚本
#
# 通过创建取消信号文件并将状态文件重命名为 cancel-state.md
# 来取消活跃的 RLCR 循环。
#
# 用法:
#   cancel-rlcr-loop.sh [--force]
#
# 退出码:
#   0 - 成功取消
#   1 - 未找到活跃循环
#   2 - 检测到终结阶段，需要确认（使用 --force 覆盖）
#   3 - 其他错误
#

set -euo pipefail

# ========================================
# 解析参数
# ========================================

FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            cat << 'HELP_EOF'
cancel-rlcr-loop - Cancel active RLCR loop

USAGE:
  cancel-rlcr-loop.sh [OPTIONS]

OPTIONS:
  --force        Force cancel even during Finalize Phase
  -h, --help     Show this help message

EXIT CODES:
  0 - Successfully cancelled
  1 - No active loop found
  2 - Finalize phase detected, confirmation required
  3 - Other error

DESCRIPTION:
  Cancels the active RLCR loop by:
  1. Finding the most recent loop directory
  2. Creating a .cancel-requested signal file
  3. Renaming state.md, methodology-analysis-state.md, or finalize-state.md to cancel-state.md
HELP_EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 3
            ;;
    esac
done

# ========================================
# 查找循环目录
# ========================================

# 导入共享循环库以获取 find_active_loop 和 resolve_project_root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/../hooks/lib/loop-common.sh"

PROJECT_ROOT="$(resolve_project_root)" || {
    echo "Error: Cannot determine humanize project root." >&2
    echo "  Set CLAUDE_PROJECT_DIR or run inside a git repository." >&2
    exit 3
}
LOOP_BASE_DIR="$PROJECT_ROOT/.humanize/rlcr"

# 产品决策：取消操作全局执行（不按 session_id 过滤）。
#
# 取消通过 /cancel-rlcr-loop 斜杠命令作为独立的 Bash 命令调用。
# 与接收包含 session_id 的 JSON 的钩子（PreToolUse、PostToolUse、Stop）不同，
# 此脚本无法访问调用会话的 session_id。
#
# 这是根据 AC-6 的有意设计：取消是一个显式的用户操作，无论哪个会话调用它
# 都应该始终成功。如果用户输入 /cancel-rlcr-loop，他们想要取消当前项目
# 目录中正在运行的任何循环。
#
# 使用与钩子相同的查找方式查找最新的活跃循环目录（任意会话）
LOOP_DIR=$(find_active_loop "$LOOP_BASE_DIR")

if [[ -z "$LOOP_DIR" ]]; then
    echo "NO_LOOP"
    echo "No active RLCR loop found."
    exit 1
fi

# ========================================
# 检查循环状态
# ========================================

STATE_FILE="$LOOP_DIR/state.md"
FINALIZE_STATE_FILE="$LOOP_DIR/finalize-state.md"
METHODOLOGY_ANALYSIS_STATE_FILE="$LOOP_DIR/methodology-analysis-state.md"
CANCEL_SIGNAL="$LOOP_DIR/.cancel-requested"

if [[ -f "$STATE_FILE" ]]; then
    LOOP_STATE="NORMAL_LOOP"
    ACTIVE_STATE_FILE="$STATE_FILE"
elif [[ -f "$METHODOLOGY_ANALYSIS_STATE_FILE" ]]; then
    LOOP_STATE="METHODOLOGY_ANALYSIS_PHASE"
    ACTIVE_STATE_FILE="$METHODOLOGY_ANALYSIS_STATE_FILE"
elif [[ -f "$FINALIZE_STATE_FILE" ]]; then
    LOOP_STATE="FINALIZE_PHASE"
    ACTIVE_STATE_FILE="$FINALIZE_STATE_FILE"
else
    echo "NO_ACTIVE_LOOP"
    echo "No active RLCR loop found. The loop directory exists but no active state file is present."
    exit 1
fi

# ========================================
# 提取轮次信息
# ========================================

# 从状态文件中提取 current_round 和 max_iterations
CURRENT_ROUND=$(grep -E '^current_round:' "$ACTIVE_STATE_FILE" | sed 's/^current_round:[[:space:]]*//' | tr -d ' ')
MAX_ITERATIONS=$(grep -E '^max_iterations:' "$ACTIVE_STATE_FILE" | sed 's/^max_iterations:[[:space:]]*//' | tr -d ' ')

# 如果未找到则使用默认值
CURRENT_ROUND=${CURRENT_ROUND:-"?"}
MAX_ITERATIONS=${MAX_ITERATIONS:-"?"}

# ========================================
# 处理终结阶段
# ========================================

if [[ "$LOOP_STATE" == "FINALIZE_PHASE" && "$FORCE" != "true" ]]; then
    echo "FINALIZE_NEEDS_CONFIRM"
    echo "loop_dir: $LOOP_DIR"
    echo "current_round: $CURRENT_ROUND"
    echo "max_iterations: $MAX_ITERATIONS"
    echo ""
    echo "The loop is currently in Finalize Phase."
    echo "After this phase completes, the loop will end without returning to Codex review."
    echo ""
    echo "Use --force to cancel anyway."
    exit 2
fi

# ========================================
# 执行取消操作
# ========================================

# 创建取消信号文件
touch "$CANCEL_SIGNAL"

# 清理任何待处理的 session_id 信号文件（设置可能尚未完成）
rm -f "$PROJECT_ROOT/.humanize/.pending-session-id"

# 清理方法论分析标记文件（如果存在）
rm -f "$LOOP_DIR/.methodology-exit-reason"

# 将状态文件重命名为 cancel-state.md
mv "$ACTIVE_STATE_FILE" "$LOOP_DIR/cancel-state.md"

# ========================================
# 输出结果
# ========================================

if [[ "$LOOP_STATE" == "NORMAL_LOOP" ]]; then
    echo "CANCELLED"
    echo "Cancelled RLCR loop (was at round $CURRENT_ROUND of $MAX_ITERATIONS)."
    echo "State preserved as cancel-state.md"
elif [[ "$LOOP_STATE" == "METHODOLOGY_ANALYSIS_PHASE" ]]; then
    echo "CANCELLED_METHODOLOGY_ANALYSIS"
    echo "Cancelled RLCR loop during Methodology Analysis Phase (was at round $CURRENT_ROUND of $MAX_ITERATIONS)."
    echo "State preserved as cancel-state.md"
else
    echo "CANCELLED_FINALIZE"
    echo "Cancelled RLCR loop during Finalize Phase (was at round $CURRENT_ROUND of $MAX_ITERATIONS)."
    echo "State preserved as cancel-state.md"
fi

exit 0
