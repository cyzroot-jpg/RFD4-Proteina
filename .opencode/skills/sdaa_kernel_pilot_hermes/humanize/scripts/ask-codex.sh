#!/usr/bin/env bash
#
# Ask Codex - 与 Codex 的一次性咨询
#
# 向 codex exec 发送问题或任务并返回响应。
# 这是一个主动的一次性技能（不同于被动的 RLCR 循环）。
#
# 用法:
#   ask-codex.sh [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [question...]
#
# 输出:
#   stdout: Codex 的响应（供 Claude 读取）
#   stderr: 状态/调试信息（模型、努力级别、日志路径）
#
# 存储:
#   项目本地: .humanize/skill/<unique-id>/{input,output,metadata}.md
#   缓存: ~/.cache/humanize/<sanitized-path>/skill-<unique-id>/codex-run.{cmd,out,log}
#

set -euo pipefail

# ========================================
# 导入共享库
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 导入可移植的超时封装器
source "$SCRIPT_DIR/portable-timeout.sh"

# 导入共享循环库以获取 DEFAULT_CODEX_MODEL 和 DEFAULT_CODEX_EFFORT
HOOKS_LIB_DIR="$(cd "$SCRIPT_DIR/../hooks/lib" && pwd)"
source "$HOOKS_LIB_DIR/loop-common.sh"

# ========================================
# 默认配置
# ========================================

DEFAULT_ASK_CODEX_TIMEOUT=3600

CODEX_MODEL="$DEFAULT_CODEX_MODEL"
CODEX_EFFORT="$DEFAULT_CODEX_EFFORT"
CODEX_TIMEOUT="$DEFAULT_ASK_CODEX_TIMEOUT"

# ========================================
# 帮助信息
# ========================================

show_help() {
    cat << 'HELP_EOF'
ask-codex - One-shot consultation with Codex

USAGE:
  /humanize:ask-codex [OPTIONS] <question or task>

OPTIONS:
  --codex-model <MODEL:EFFORT>
                       Codex model and reasoning effort (default from config, fallback gpt-5.5:high)
  --codex-timeout <SECONDS>
                       Timeout for the Codex query in seconds (default: 3600)
  -h, --help           Show this help message

DESCRIPTION:
  Sends a one-shot question or task to Codex and returns the response.
  Unlike the RLCR loop, this is a single consultation without iteration.

  The response is saved to .humanize/skill/<unique-id>/output.md for reference.

EXAMPLES:
  /humanize:ask-codex How should I structure the authentication module?
  /humanize:ask-codex --codex-model gpt-5.5:high What are the performance bottlenecks?
  /humanize:ask-codex --codex-timeout 300 Review the error handling in src/api/

ENVIRONMENT:
  HUMANIZE_CODEX_BYPASS_SANDBOX
    Set to "true" or "1" to bypass Codex sandbox protections.
    WARNING: This is dangerous. See README for details.
HELP_EOF
    exit 0
}

# ========================================
# 解析参数
# ========================================

QUESTION_PARTS=()
OPTIONS_DONE=false

while [[ $# -gt 0 ]]; do
    if [[ "$OPTIONS_DONE" == "true" ]]; then
        # 在第一个位置参数或 -- 之后，所有剩余参数都是问题文本
        QUESTION_PARTS+=("$1")
        shift
        continue
    fi
    case $1 in
        -h|--help)
            show_help
            ;;
        --)
            # 显式的选项结束标记
            OPTIONS_DONE=true
            shift
            ;;
        --codex-model)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --codex-model requires a MODEL:EFFORT argument" >&2
                exit 1
            fi
            # 解析 MODEL:EFFORT 格式（与 setup-rlcr-loop.sh 相同的模式）
            if [[ "$2" == *:* ]]; then
                CODEX_MODEL="${2%%:*}"
                CODEX_EFFORT="${2#*:}"
            else
                CODEX_MODEL="$2"
                CODEX_EFFORT="$DEFAULT_CODEX_EFFORT"
            fi
            shift 2
            ;;
        --codex-timeout)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --codex-timeout requires a number argument (seconds)" >&2
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --codex-timeout must be a positive integer (seconds), got: $2" >&2
                exit 1
            fi
            CODEX_TIMEOUT="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            # 第一个位置参数：停止解析选项，其余为问题文本
            QUESTION_PARTS+=("$1")
            OPTIONS_DONE=true
            shift
            ;;
    esac
done

# 将问题部分合并为单个字符串（使用 ${arr[*]+...} 以避免 bash 3.2 下 set -u 崩溃）
QUESTION="${QUESTION_PARTS[*]+"${QUESTION_PARTS[*]}"}"

# ========================================
# 验证前置条件
# ========================================

# 检查 codex 是否可用
if ! command -v codex &>/dev/null; then
    echo "Error: 'codex' command is not installed or not in PATH" >&2
    echo "" >&2
    echo "Please install Codex CLI: https://github.com/openai/codex" >&2
    echo "Then retry: /humanize:ask-codex <your question>" >&2
    exit 1
fi

# 检查问题是否为空
if [[ -z "$QUESTION" ]]; then
    echo "Error: No question or task provided" >&2
    echo "" >&2
    echo "Usage: /humanize:ask-codex [OPTIONS] <question or task>" >&2
    echo "" >&2
    echo "For help: /humanize:ask-codex --help" >&2
    exit 1
fi

# 验证 codex 模型的安全性（仅允许字母数字、连字符、下划线、点号）
if [[ ! "$CODEX_MODEL" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: Codex model contains invalid characters" >&2
    echo "  Model: $CODEX_MODEL" >&2
    echo "  Only alphanumeric, hyphen, underscore, dot allowed" >&2
    exit 1
fi

# 验证 codex 努力级别的安全性（仅允许字母数字、连字符、下划线）
if [[ ! "$CODEX_EFFORT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Codex effort contains invalid characters" >&2
    echo "  Effort: $CODEX_EFFORT" >&2
    echo "  Only alphanumeric, hyphen, underscore allowed" >&2
    exit 1
fi

# ========================================
# 检测项目根目录
# ========================================

PROJECT_ROOT="$(resolve_project_root)" || {
    echo "Error: Cannot determine project root." >&2
    echo "  Set CLAUDE_PROJECT_DIR or run inside a git repository." >&2
    exit 1
}

# ========================================
# 创建存储目录
# ========================================

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
UNIQUE_ID="${TIMESTAMP}-$$-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

# 项目本地存储: .humanize/skill/<unique-id>/
SKILL_DIR="$PROJECT_ROOT/.humanize/skill/$UNIQUE_ID"
mkdir -p "$SKILL_DIR"

# 缓存存储: ~/.cache/humanize/<sanitized-path>/skill-<unique-id>/
# 如果主目录缓存不可写，则回退到项目本地 .humanize/cache/
SANITIZED_PROJECT_PATH=$(echo "$PROJECT_ROOT" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$CACHE_BASE/humanize/$SANITIZED_PROJECT_PATH/skill-$UNIQUE_ID"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    CACHE_DIR="$SKILL_DIR/cache"
    mkdir -p "$CACHE_DIR"
    echo "ask-codex: warning: home cache not writable, using $CACHE_DIR" >&2
fi

# ========================================
# 保存输入
# ========================================

cat > "$SKILL_DIR/input.md" << EOF
# Ask Codex Input

## Question

$QUESTION

## Configuration

- Model: $CODEX_MODEL
- Effort: $CODEX_EFFORT
- Timeout: ${CODEX_TIMEOUT}s
- Timestamp: $TIMESTAMP
- Tool: codex
EOF

# ========================================
# 构建 Codex 命令
# ========================================

# 探测已安装的 Codex CLI 是否支持 --disable hooks，以防止
# 当 ask-codex.sh 在运行中的循环内被调用时出现嵌套钩子递归。
# 将探测结果缓存在技能目录中以避免重复探测。
CODEX_DISABLE_HOOKS_ARGS=()
_CODEX_DISABLE_HOOKS_CACHE="$SKILL_DIR/.codex-disable-hooks-supported"
if [[ -f "$_CODEX_DISABLE_HOOKS_CACHE" ]]; then
    [[ "$(cat "$_CODEX_DISABLE_HOOKS_CACHE")" == "yes" ]] && CODEX_DISABLE_HOOKS_ARGS=(--disable hooks)
else
    CODEX_HELP_OUTPUT="$(codex --help </dev/null 2>&1 || true)"
    if grep -q -- '--disable' <<< "$CODEX_HELP_OUTPUT"; then
        CODEX_DISABLE_HOOKS_ARGS=(--disable hooks)
        echo "yes" > "$_CODEX_DISABLE_HOOKS_CACHE" 2>/dev/null || true
    else
        echo "no" > "$_CODEX_DISABLE_HOOKS_CACHE" 2>/dev/null || true
    fi
fi

# 构建 codex exec 参数（与 loop-codex-stop-hook.sh 相同的模式）
# 使用 ${arr[@]+"${arr[@]}"} 在 set -u 下安全展开可能为空的数组（bash 3.2 兼容）
CODEX_EXEC_ARGS=(${CODEX_DISABLE_HOOKS_ARGS[@]+"${CODEX_DISABLE_HOOKS_ARGS[@]}"} "-m" "$CODEX_MODEL")
if [[ -n "$CODEX_EFFORT" ]]; then
    CODEX_EXEC_ARGS+=("-c" "model_reasoning_effort=${CODEX_EFFORT}")
fi

# 根据环境变量确定自动化标志
CODEX_AUTO_FLAG="--full-auto"
if [[ "${HUMANIZE_CODEX_BYPASS_SANDBOX:-}" == "true" ]] || [[ "${HUMANIZE_CODEX_BYPASS_SANDBOX:-}" == "1" ]]; then
    CODEX_AUTO_FLAG="--dangerously-bypass-approvals-and-sandbox"
fi

CODEX_EXEC_ARGS+=("$CODEX_AUTO_FLAG" "-C" "$PROJECT_ROOT")

# ========================================
# 保存调试命令
# ========================================

CODEX_CMD_FILE="$CACHE_DIR/codex-run.cmd"
CODEX_STDOUT_FILE="$CACHE_DIR/codex-run.out"
CODEX_STDERR_FILE="$CACHE_DIR/codex-run.log"

{
    echo "# Codex ask-codex 调用调试信息"
    echo "# 时间戳: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# 工作目录: $PROJECT_ROOT"
    echo "# 超时时间: $CODEX_TIMEOUT 秒"
    echo ""
    echo "codex exec ${CODEX_EXEC_ARGS[*]} \"<prompt>\""
    echo ""
    echo "# 提示内容:"
    echo "$QUESTION"
} > "$CODEX_CMD_FILE"

# ========================================
# 运行 Codex
# ========================================

echo "ask-codex: model=$CODEX_MODEL effort=$CODEX_EFFORT timeout=${CODEX_TIMEOUT}s" >&2
echo "ask-codex: cache=$CACHE_DIR" >&2
echo "ask-codex: running codex exec..." >&2

# 可移植的 epoch 到 ISO8601 格式化器（GNU date -d 与 BSD date -r）
epoch_to_iso() {
    local epoch="$1"
    date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    echo "unknown"
}

START_TIME=$(date +%s)

CODEX_EXIT_CODE=0
printf '%s' "$QUESTION" | run_with_timeout "$CODEX_TIMEOUT" codex exec "${CODEX_EXEC_ARGS[@]}" - \
    > "$CODEX_STDOUT_FILE" 2> "$CODEX_STDERR_FILE" || CODEX_EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "ask-codex: exit_code=$CODEX_EXIT_CODE duration=${DURATION}s" >&2

# ========================================
# 处理结果
# ========================================

# 检查超时
if [[ $CODEX_EXIT_CODE -eq 124 ]]; then
    echo "Error: Codex timed out after ${CODEX_TIMEOUT} seconds" >&2
    echo "" >&2
    echo "Try increasing the timeout:" >&2
    echo "  /humanize:ask-codex --codex-timeout $((CODEX_TIMEOUT * 2)) <your question>" >&2
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    # 即使超时也保存元数据
    cat > "$SKILL_DIR/metadata.md" << EOF
---
tool: codex
model: $CODEX_MODEL
effort: $CODEX_EFFORT
timeout: $CODEX_TIMEOUT
exit_code: 124
duration: ${DURATION}s
status: timeout
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 124
fi

# 检查非零退出码
if [[ $CODEX_EXIT_CODE -ne 0 ]]; then
    echo "Error: Codex exited with code $CODEX_EXIT_CODE" >&2
    if [[ -s "$CODEX_STDERR_FILE" ]]; then
        echo "" >&2
        echo "Codex stderr (last 20 lines):" >&2
        tail -20 "$CODEX_STDERR_FILE" >&2
    fi
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    # 保存元数据
    cat > "$SKILL_DIR/metadata.md" << EOF
---
tool: codex
model: $CODEX_MODEL
effort: $CODEX_EFFORT
timeout: $CODEX_TIMEOUT
exit_code: $CODEX_EXIT_CODE
duration: ${DURATION}s
status: error
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit "$CODEX_EXIT_CODE"
fi

# 检查标准输出是否为空
if [[ ! -s "$CODEX_STDOUT_FILE" ]]; then
    echo "Error: Codex returned empty response" >&2
    if [[ -s "$CODEX_STDERR_FILE" ]]; then
        echo "" >&2
        echo "Codex stderr (last 20 lines):" >&2
        tail -20 "$CODEX_STDERR_FILE" >&2
    fi
    echo "" >&2
    echo "Debug logs: $CACHE_DIR" >&2

    cat > "$SKILL_DIR/metadata.md" << EOF
---
tool: codex
model: $CODEX_MODEL
effort: $CODEX_EFFORT
timeout: $CODEX_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: empty_response
started_at: $(epoch_to_iso "$START_TIME")
---
EOF
    exit 1
fi

# ========================================
# 保存输出和元数据
# ========================================

# 将 Codex 响应保存到项目本地存储
cp "$CODEX_STDOUT_FILE" "$SKILL_DIR/output.md"

# 保存元数据
cat > "$SKILL_DIR/metadata.md" << EOF
---
tool: codex
model: $CODEX_MODEL
effort: $CODEX_EFFORT
timeout: $CODEX_TIMEOUT
exit_code: 0
duration: ${DURATION}s
status: success
started_at: $(epoch_to_iso "$START_TIME")
---
EOF

echo "ask-codex: response saved to $SKILL_DIR/output.md" >&2

# ========================================
# 输出响应
# ========================================

# 将 Codex 的响应输出到标准输出（供 Claude 读取的干净输出）
cat "$CODEX_STDOUT_FILE"
