#!/usr/bin/env bash
#
# 从非钩子环境（例如技能工作流）运行 RLCR stop-hook 逻辑。
#
# 此脚本包装了 hooks/loop-codex-stop-hook.sh，以便技能可以复用
# 钩子使用的相同强制执行逻辑和阶段转换。
#
# 退出码:
#   0   - 门控允许（无活跃循环阻塞）
#   10  - 门控阻塞（遵循返回的原因/说明并继续循环）
#   20  - 包装器/运行时错误
#
# 用法:
#   scripts/rlcr-stop-gate.sh [--session-id ID] [--transcript-path PATH] [--project-root PATH] [--json]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HUMANIZE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 确定性的项目根目录解析器（CLAUDE_PROJECT_DIR -> git 顶层目录，无 pwd 回退）。
# 非钩子调用者可通过 --project-root 覆盖；下方的标志处理器
# 始终优先，因为它在此默认赋值之后运行。
source "$HUMANIZE_ROOT/hooks/lib/project-root.sh"
PROJECT_ROOT="$(resolve_project_root 2>/dev/null || true)"
HOOK_SCRIPT="$HUMANIZE_ROOT/hooks/loop-codex-stop-hook.sh"

SESSION_ID="${CLAUDE_SESSION_ID:-}"
TRANSCRIPT_PATH="${CLAUDE_TRANSCRIPT_PATH:-}"
PRINT_JSON="false"
HOOK_MODEL="${CODEX_MODEL:-humanize-skill-gate}"
HOOK_PERMISSION_MODE="${CODEX_PERMISSION_MODE:-default}"

usage() {
    cat <<'EOF'
Usage: rlcr-stop-gate.sh [options]

Options:
  --session-id ID         Session ID forwarded to hook input
  --transcript-path PATH  Transcript path forwarded to hook input
  --project-root PATH     Project root (default: repo root)
  --json                  Print raw hook JSON on block
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-id)
            [[ -n "${2:-}" ]] || { echo "Error: --session-id requires a value" >&2; exit 20; }
            SESSION_ID="$2"
            shift 2
            ;;
        --transcript-path)
            [[ -n "${2:-}" ]] || { echo "Error: --transcript-path requires a value" >&2; exit 20; }
            TRANSCRIPT_PATH="$2"
            shift 2
            ;;
        --project-root)
            [[ -n "${2:-}" ]] || { echo "Error: --project-root requires a value" >&2; exit 20; }
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --json)
            PRINT_JSON="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 20
            ;;
    esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
    # 从此处无法访问 humanize 项目上下文 -- 无需强制执行。
    # 允许停止继续进行，而不是返回包装器错误，以便
    # 在任何项目（或任何 git 仓库）之外调用门控是无害的。
    echo "ALLOW: no humanize project root resolved."
    exit 0
fi

if [[ ! -x "$HOOK_SCRIPT" ]]; then
    echo "Error: Hook script not found or not executable: $HOOK_SCRIPT" >&2
    exit 20
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required by rlcr-stop-gate.sh" >&2
    exit 20
fi

# 构建钩子输入 JSON。包含标准 Stop 钩子字段，以便底层
# 钩子看到与真实 Claude Code Stop 事件相同的架构
# （hook_event_name、stop_hook_active、cwd）。
#
# 空的 session_id / transcript_path 变为显式 null 而不是被过滤掉；
# 用作普通对象值的 `select(length > 0)` 在任何选定字段为空时
# 会将整个封闭对象折叠为空，这会在仅 session_id 缺失时
# 隐藏转发的字段如 transcript_path。
HOOK_INPUT=$(jq -n \
    --arg session_id "$SESSION_ID" \
    --arg transcript_path "$TRANSCRIPT_PATH" \
    --arg cwd "$PROJECT_ROOT" \
    --arg model "$HOOK_MODEL" \
    --arg permission_mode "$HOOK_PERMISSION_MODE" \
    '{
        hook_event_name: "Stop",
        stop_hook_active: false,
        cwd: $cwd,
        model: $model,
        permission_mode: $permission_mode,
        last_assistant_message: null,
        session_id: (if ($session_id | length) > 0 then $session_id else null end),
        transcript_path: (if ($transcript_path | length) > 0 then $transcript_path else null end)
    }')

# 显式捕获钩子退出码，将非零映射到退出 20（包装器错误），
# 而不是让 set -e 传播原始钩子退出码。
HOOK_EXIT=0
HOOK_OUTPUT="$(printf '%s' "$HOOK_INPUT" | CLAUDE_PROJECT_DIR="$PROJECT_ROOT" "$HOOK_SCRIPT")" || HOOK_EXIT=$?

if [[ $HOOK_EXIT -ne 0 ]]; then
    echo "Error: Hook script exited with code $HOOK_EXIT" >&2
    [[ -n "$HOOK_OUTPUT" ]] && printf '%s\n' "$HOOK_OUTPUT" >&2
    exit 20
fi

# 没有 JSON 响应意味着钩子允许退出。
if [[ -z "$HOOK_OUTPUT" ]]; then
    echo "ALLOW: stop gate passed."
    exit 0
fi

if ! printf '%s' "$HOOK_OUTPUT" | jq -e '.' >/dev/null 2>&1; then
    echo "Error: Hook returned non-JSON output" >&2
    printf '%s\n' "$HOOK_OUTPUT" >&2
    exit 20
fi

DECISION="$(printf '%s' "$HOOK_OUTPUT" | jq -r '.decision // empty')"
SYSTEM_MESSAGE="$(printf '%s' "$HOOK_OUTPUT" | jq -r '.systemMessage // empty')"
REASON="$(printf '%s' "$HOOK_OUTPUT" | jq -r '.reason // empty')"

if [[ "$DECISION" == "block" ]]; then
    if [[ "$PRINT_JSON" == "true" ]]; then
        printf '%s\n' "$HOOK_OUTPUT"
    else
        [[ -n "$SYSTEM_MESSAGE" ]] && printf 'BLOCK: %s\n' "$SYSTEM_MESSAGE"
        [[ -n "$REASON" ]] && printf '%s\n' "$REASON"
    fi
    exit 10
fi

# JSON 中没有 decision 字段：根据 Claude Code Stop-hook 规范，这意味着
# 允许停止。显示任何 systemMessage 以便调用者看到原因
# （例如 "background task(s) still running"），然后退出 0。
if [[ -z "$DECISION" ]]; then
    if [[ "$PRINT_JSON" == "true" ]]; then
        printf '%s\n' "$HOOK_OUTPUT"
    elif [[ -n "$SYSTEM_MESSAGE" ]]; then
        printf 'ALLOW: %s\n' "$SYSTEM_MESSAGE"
    else
        echo "ALLOW: stop gate passed."
    fi
    exit 0
fi

echo "Error: Unexpected hook decision: ${DECISION:-<empty>}" >&2
printf '%s\n' "$HOOK_OUTPUT" >&2
exit 20
