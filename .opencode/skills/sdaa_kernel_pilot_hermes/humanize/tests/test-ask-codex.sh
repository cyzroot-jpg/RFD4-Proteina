#!/usr/bin/env bash
#
# ask-codex.sh 测试 - 使用模拟 Codex 的一次性咨询
#
# 所有测试使用模拟的 codex 二进制文件（不进行真实的 Codex 调用）。
# 模拟行为通过导出的环境变量控制：
#   MOCK_CODEX_EXIT_CODE - 模拟返回的退出码（默认：0）
#   MOCK_CODEX_STDOUT    - 模拟写入 stdout 的文本
#   MOCK_CODEX_STDERR    - 模拟写入 stderr 的文本
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

ASK_CODEX_SCRIPT="$SCRIPT_DIR/../scripts/ask-codex.sh"
ASK_CODEX_SKILL="$SCRIPT_DIR/../skills/ask-codex/SKILL.md"

echo "=========================================="
echo "Ask Codex Tests (mock)"
echo "=========================================="
echo ""

# ========================================
# 设置：模拟 codex 二进制文件和测试项目
# ========================================

setup_test_dir

# 创建一个模拟 git 仓库作为 PROJECT_ROOT
MOCK_PROJECT="$TEST_DIR/project"
init_test_git_repo "$MOCK_PROJECT"

# 创建模拟 codex 二进制文件目录
MOCK_BIN_DIR="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN_DIR"

cat > "$MOCK_BIN_DIR/codex" << 'MOCK_EOF'
#!/usr/bin/env bash
# 用于测试 ask-codex.sh 的模拟 codex 二进制文件
# 通过环境变量控制。
if [[ -n "${MOCK_CODEX_STDERR:-}" ]]; then
    echo "$MOCK_CODEX_STDERR" >&2
fi
if [[ -n "${MOCK_CODEX_STDOUT:-}" ]]; then
    echo "$MOCK_CODEX_STDOUT"
fi
# 消耗 stdin 以避免管道中断
cat > /dev/null
exit "${MOCK_CODEX_EXIT_CODE:-0}"
MOCK_EOF
chmod +x "$MOCK_BIN_DIR/codex"

# 导出模拟变量，使子进程（模拟 codex）可以看到它们
export MOCK_CODEX_EXIT_CODE=""
export MOCK_CODEX_STDOUT=""
export MOCK_CODEX_STDERR=""

# 在测试之间重置模拟状态；同时清除 skill 目录，使
# find...sort|tail -1 总是选取下一次调用的单个目录。
reset_mock() {
    export MOCK_CODEX_EXIT_CODE="0"
    export MOCK_CODEX_STDOUT=""
    export MOCK_CODEX_STDERR=""
    rm -rf "$MOCK_PROJECT/.humanize/skill" 2>/dev/null || true
}

# 覆盖 run_ask_codex_capturing_dir 的 XDG_CACHE_HOME；设置为不可写路径
# 以练习回退缓存分支（CACHE_DIR=$SKILL_DIR/cache）。
RUN_XDG_CACHE_HOME="$TEST_DIR/cache"

# 辅助函数：使用可控的 XDG_CACHE_HOME 运行 ask-codex，捕获 stderr，并
# 推导该调用的确切项目本地 skill 目录。
# 设置 RUN_EXIT_CODE（整数）和 RUN_SKILL_DIR（路径，解析失败时为空）。
#
# 主要："ask-codex: response saved to .../output.md"（成功时发出，始终
#   项目本地，无论使用了哪种缓存布局）。
# 回退 A："ask-codex: cache=.../skill-<id>"  -> 正常布局
# 回退 B："ask-codex: cache=.../.humanize/skill/<id>/cache" -> 回退布局
# 如果以上都不匹配，RUN_SKILL_DIR 被设置为 ""（显式失败）。
run_ask_codex_capturing_dir() {
    local run_stderr output_path cache_path skill_basename
    RUN_EXIT_CODE=0
    run_stderr=$(
        cd "$MOCK_PROJECT"
        export CLAUDE_PROJECT_DIR="$MOCK_PROJECT"
        export XDG_CACHE_HOME="$RUN_XDG_CACHE_HOME"
        PATH="$MOCK_BIN_DIR:$PATH" bash "$ASK_CODEX_SCRIPT" "$@" 2>&1 >/dev/null
    ) || RUN_EXIT_CODE=$?
    output_path=$(printf '%s\n' "$run_stderr" | grep "^ask-codex: response saved to " | sed 's/^ask-codex: response saved to //')
    if [[ -n "$output_path" ]]; then
        RUN_SKILL_DIR=$(dirname "$output_path")
        return
    fi
    cache_path=$(printf '%s\n' "$run_stderr" | grep "^ask-codex: cache=" | sed 's/^ask-codex: cache=//')
    skill_basename=$(basename "$cache_path")
    case "$skill_basename" in
        skill-*)
            RUN_SKILL_DIR="$MOCK_PROJECT/.humanize/skill/${skill_basename#skill-}"
            ;;
        cache)
            RUN_SKILL_DIR=$(dirname "$cache_path")
            ;;
        *)
            RUN_SKILL_DIR=""
            ;;
    esac
}

# 辅助函数：在模拟项目内使用 PATH 中的模拟 codex 运行 ask-codex
run_ask_codex() {
    (
        cd "$MOCK_PROJECT"
        export CLAUDE_PROJECT_DIR="$MOCK_PROJECT"
        export XDG_CACHE_HOME="$TEST_DIR/cache"
        PATH="$MOCK_BIN_DIR:$PATH" bash "$ASK_CODEX_SCRIPT" "$@"
    )
}

# ========================================
# 验证测试
# ========================================

echo "--- Validation Tests ---"
echo ""

# 测试：空问题
EXIT_CODE=0
OUTPUT=$(run_ask_codex 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "No question or task provided"; then
    pass "empty question exits 1 with error message"
else
    fail "empty question exits 1 with error message" "exit 1 + error" "exit=$EXIT_CODE"
fi

# 测试：--help 以 0 退出
EXIT_CODE=0
OUTPUT=$(run_ask_codex --help 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q "USAGE"; then
    pass "--help exits 0 with usage info"
else
    fail "--help exits 0 with usage info" "exit 0 + USAGE" "exit=$EXIT_CODE"
fi

# 测试：未知选项以 1 退出
EXIT_CODE=0
OUTPUT=$(run_ask_codex --bad-flag test 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "Unknown option"; then
    pass "unknown option exits 1"
else
    fail "unknown option exits 1" "exit 1 + Unknown option" "exit=$EXIT_CODE"
fi

# 测试：--codex-model 无参数
EXIT_CODE=0
OUTPUT=$(run_ask_codex --codex-model 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "requires a MODEL:EFFORT"; then
    pass "--codex-model without argument exits 1"
else
    fail "--codex-model without argument exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# 测试：--codex-timeout 无参数
EXIT_CODE=0
OUTPUT=$(run_ask_codex --codex-timeout 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "requires a number"; then
    pass "--codex-timeout without argument exits 1"
else
    fail "--codex-timeout without argument exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# 测试：--codex-timeout 非数字
EXIT_CODE=0
OUTPUT=$(run_ask_codex --codex-timeout abc test 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "must be a positive integer"; then
    pass "--codex-timeout non-numeric exits 1"
else
    fail "--codex-timeout non-numeric exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# 测试：无效的模型字符
EXIT_CODE=0
OUTPUT=$(run_ask_codex --codex-model 'bad;model' test 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "invalid characters"; then
    pass "invalid model characters exits 1"
else
    fail "invalid model characters exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# 测试：无效的 effort 字符
EXIT_CODE=0
OUTPUT=$(run_ask_codex --codex-model 'model:bad;effort' test 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]] && echo "$OUTPUT" | grep -q "invalid characters"; then
    pass "invalid effort characters exits 1"
else
    fail "invalid effort characters exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# ========================================
# 成功运行测试
# ========================================

echo ""
echo "--- Successful Run Tests ---"
echo ""

# 测试：成功的 codex 响应出现在 stdout
reset_mock
export MOCK_CODEX_STDOUT="This is the answer"
STDOUT=$(run_ask_codex "What is 1+1?" 2>/dev/null)
if echo "$STDOUT" | grep -q "This is the answer"; then
    pass "successful run outputs codex response to stdout"
else
    fail "successful run outputs codex response to stdout" "This is the answer" "$STDOUT"
fi

# 测试：成功运行在 skill 目录中创建 output.md
SKILL_DIRS_BEFORE=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
reset_mock
export MOCK_CODEX_STDOUT="Test output for file"
run_ask_codex "file test" > /dev/null 2>&1
SKILL_DIRS_AFTER=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
NEW_DIR=$(comm -13 <(echo "$SKILL_DIRS_BEFORE") <(echo "$SKILL_DIRS_AFTER") | head -1)
if [[ -n "$NEW_DIR" ]] && [[ -f "$NEW_DIR/output.md" ]] && grep -q "Test output for file" "$NEW_DIR/output.md"; then
    pass "successful run creates output.md with codex response"
else
    fail "successful run creates output.md with codex response" "output.md with content" "dir=$NEW_DIR"
fi

# 测试：成功运行创建 status: success 的 metadata.md
if [[ -n "$NEW_DIR" ]] && [[ -f "$NEW_DIR/metadata.md" ]] && grep -q "status: success" "$NEW_DIR/metadata.md"; then
    pass "successful run creates metadata.md with status: success"
else
    fail "successful run creates metadata.md with status: success"
fi

# 测试：成功运行创建包含问题的 input.md
if [[ -n "$NEW_DIR" ]] && [[ -f "$NEW_DIR/input.md" ]] && grep -q "file test" "$NEW_DIR/input.md"; then
    pass "successful run saves question to input.md"
else
    fail "successful run saves question to input.md"
fi

# 测试：成功运行以 0 退出
reset_mock
export MOCK_CODEX_STDOUT="ok"
EXIT_CODE=0
run_ask_codex "exit code test" > /dev/null 2>&1 || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "successful run exits 0"
else
    fail "successful run exits 0" "exit 0" "exit=$EXIT_CODE"
fi

# ========================================
# 错误处理测试
# ========================================

echo ""
echo "--- Error Handling Tests ---"
echo ""

# 测试：codex 非零退出传播
reset_mock
export MOCK_CODEX_EXIT_CODE="42"
export MOCK_CODEX_STDERR="something broke"
EXIT_CODE=0
run_ask_codex "error test" > /dev/null 2>&1 || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 42 ]]; then
    pass "codex non-zero exit code propagates"
else
    fail "codex non-zero exit code propagates" "exit 42" "exit=$EXIT_CODE"
fi

# 测试：codex 错误创建 status: error 的 metadata
LATEST_DIR=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
if [[ -n "$LATEST_DIR" ]] && [[ -f "$LATEST_DIR/metadata.md" ]] && grep -q "status: error" "$LATEST_DIR/metadata.md"; then
    pass "codex error creates metadata with status: error"
else
    fail "codex error creates metadata with status: error"
fi

# 测试：codex 空响应以 1 退出
reset_mock
export MOCK_CODEX_STDOUT=""
EXIT_CODE=0
run_ask_codex "empty test" > /dev/null 2>&1 || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]]; then
    pass "empty codex response exits 1"
else
    fail "empty codex response exits 1" "exit 1" "exit=$EXIT_CODE"
fi

# 测试：空响应创建 status: empty_response 的 metadata
LATEST_DIR=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
if [[ -n "$LATEST_DIR" ]] && [[ -f "$LATEST_DIR/metadata.md" ]] && grep -q "status: empty_response" "$LATEST_DIR/metadata.md"; then
    pass "empty response creates metadata with status: empty_response"
else
    fail "empty response creates metadata with status: empty_response"
fi

# 测试：codex 超时（退出码 124）被处理
reset_mock
export MOCK_CODEX_EXIT_CODE="124"
EXIT_CODE=0
STDERR=$(run_ask_codex --codex-timeout 999 "timeout test" 2>&1 >/dev/null) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 124 ]] && echo "$STDERR" | grep -q "timed out"; then
    pass "timeout exit 124 is handled with error message"
else
    fail "timeout exit 124 is handled with error message" "exit 124 + timed out" "exit=$EXIT_CODE"
fi

# 测试：超时创建 status: timeout 的 metadata
LATEST_DIR=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
if [[ -n "$LATEST_DIR" ]] && [[ -f "$LATEST_DIR/metadata.md" ]] && grep -q "status: timeout" "$LATEST_DIR/metadata.md"; then
    pass "timeout creates metadata with status: timeout"
else
    fail "timeout creates metadata with status: timeout"
fi

# ========================================
# 目录唯一性测试
# ========================================

echo ""
echo "--- Directory Uniqueness Tests ---"
echo ""

# 测试：两次快速调用产生不同的 skill 目录
DIRS_BEFORE=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

reset_mock
export MOCK_CODEX_STDOUT="call-concurrent"
run_ask_codex "uniqueness test 1" > /dev/null 2>&1 &
PID1=$!
run_ask_codex "uniqueness test 2" > /dev/null 2>&1 &
PID2=$!
wait "$PID1" 2>/dev/null || true
wait "$PID2" 2>/dev/null || true

DIRS_AFTER=$(find "$MOCK_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
NEW_DIRS=$(comm -13 <(echo "$DIRS_BEFORE") <(echo "$DIRS_AFTER"))
NEW_DIR_COUNT=$(echo "$NEW_DIRS" | grep -c . || true)

if [[ "$NEW_DIR_COUNT" -ge 2 ]]; then
    pass "two concurrent calls create distinct skill directories"
else
    fail "two concurrent calls create distinct skill directories" ">=2 new dirs" "$NEW_DIR_COUNT new dirs"
fi

# 测试：缓存目录也是唯一的
CACHE_BASE="$TEST_DIR/cache/humanize"
if [[ -d "$CACHE_BASE" ]]; then
    CACHE_DIRS=$(find "$CACHE_BASE" -maxdepth 2 -mindepth 2 -type d -name "skill-*" 2>/dev/null | sort)
    CACHE_DIR_COUNT=$(echo "$CACHE_DIRS" | grep -c . || true)
    if [[ "$CACHE_DIR_COUNT" -ge 2 ]]; then
        pass "concurrent calls create distinct cache directories"
    else
        fail "concurrent calls create distinct cache directories" ">=2 cache dirs" "$CACHE_DIR_COUNT"
    fi
else
    fail "concurrent calls create distinct cache directories" "cache dir exists" "not found"
fi

# ========================================
# 参数解析测试
# ========================================

echo ""
echo "--- Argument Parsing Tests ---"
echo ""

# 测试：--codex-model MODEL:EFFORT 设置模型和 effort
reset_mock
export MOCK_CODEX_STDOUT="model-test"
run_ask_codex_capturing_dir --codex-model "custom-model:high" "model test"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -d "$RUN_SKILL_DIR" ]] \
        && grep -q "Model: custom-model" "$RUN_SKILL_DIR/input.md" \
        && grep -q "Effort: high" "$RUN_SKILL_DIR/input.md"; then
    pass "--codex-model MODEL:EFFORT parses model and effort"
else
    fail "--codex-model MODEL:EFFORT parses model and effort"
fi

# 测试：--codex-model MODEL（无 effort）使用默认 effort
reset_mock
export MOCK_CODEX_STDOUT="effort-default-test"
run_ask_codex_capturing_dir --codex-model "solo-model" "effort default test"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -d "$RUN_SKILL_DIR" ]] \
        && grep -q "Model: solo-model" "$RUN_SKILL_DIR/input.md" \
        && grep -q "Effort: high" "$RUN_SKILL_DIR/input.md"; then
    pass "--codex-model MODEL without effort uses default high"
else
    fail "--codex-model MODEL without effort uses default high"
fi

# 测试：-- 分隔符将剩余参数视为问题
reset_mock
export MOCK_CODEX_STDOUT="separator-test"
run_ask_codex_capturing_dir -- --not-a-flag "is question"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -d "$RUN_SKILL_DIR" ]] \
        && grep -qF -- "--not-a-flag" "$RUN_SKILL_DIR/input.md"; then
    pass "-- separator passes remaining args as question text"
else
    fail "-- separator passes remaining args as question text"
fi

# 测试：--codex-timeout 被记录到 input.md
reset_mock
export MOCK_CODEX_STDOUT="timeout-val"
run_ask_codex_capturing_dir --codex-timeout 123 "timeout value test"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -d "$RUN_SKILL_DIR" ]] \
        && grep -q "Timeout: 123s" "$RUN_SKILL_DIR/input.md"; then
    pass "--codex-timeout value is recorded in input.md"
else
    fail "--codex-timeout value is recorded in input.md"
fi

# 测试：当 home 缓存不可写时 run_ask_codex_capturing_dir 解析正确的 skill 目录
# （练习 ask-codex.sh 的回退分支：CACHE_DIR=$SKILL_DIR/cache）
READONLY_CACHE="$TEST_DIR/readonly-cache"
mkdir -p "$READONLY_CACHE"
chmod 444 "$READONLY_CACHE"
reset_mock
export MOCK_CODEX_STDOUT="fallback-cache-test"
RUN_XDG_CACHE_HOME="$READONLY_CACHE"
run_ask_codex_capturing_dir "fallback cache skill dir test"
RUN_XDG_CACHE_HOME="$TEST_DIR/cache"
chmod 755 "$READONLY_CACHE"
if [[ "$RUN_EXIT_CODE" -eq 0 ]] && [[ -d "$RUN_SKILL_DIR" ]] \
        && grep -q "fallback cache skill dir test" "$RUN_SKILL_DIR/input.md"; then
    pass "run_ask_codex_capturing_dir resolves skill dir when home cache is not writable"
else
    fail "run_ask_codex_capturing_dir resolves skill dir when home cache is not writable" \
        "exit 0 + valid skill dir with input.md" \
        "exit=$RUN_EXIT_CODE skill_dir=$RUN_SKILL_DIR"
fi

# ========================================
# 缓存目录测试
# ========================================

echo ""
echo "--- Cache Directory Tests ---"
echo ""

# 测试：缓存目录包含预期的文件
reset_mock
export MOCK_CODEX_STDOUT="cache-file-test"
EXIT_CODE=0
STDERR=$(run_ask_codex "cache test" 2>&1 >/dev/null) || EXIT_CODE=$?
# 从 stderr 提取缓存路径
CACHE_PATH=$(echo "$STDERR" | grep "ask-codex: cache=" | sed 's/ask-codex: cache=//')
if [[ -n "$CACHE_PATH" ]] && [[ -f "$CACHE_PATH/codex-run.cmd" ]]; then
    pass "cache directory contains codex-run.cmd"
else
    fail "cache directory contains codex-run.cmd" "codex-run.cmd exists" "cache=$CACHE_PATH"
fi

if [[ -n "$CACHE_PATH" ]] && [[ -f "$CACHE_PATH/codex-run.out" ]]; then
    pass "cache directory contains codex-run.out"
else
    fail "cache directory contains codex-run.out"
fi

if [[ -n "$CACHE_PATH" ]] && grep -q "cache test" "$CACHE_PATH/codex-run.cmd"; then
    pass "codex-run.cmd records the question"
else
    fail "codex-run.cmd records the question"
fi

# ========================================
# Skill 指南测试
# ========================================

echo ""
echo "--- Skill Guidance Tests ---"
echo ""

# 测试：skill 显式警告不安全的裸 $ARGUMENTS shell 展开
if grep -Fq 'Never run this unsafe form' "$ASK_CODEX_SKILL" && grep -Fq '"${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" $ARGUMENTS' "$ASK_CODEX_SKILL"; then
    pass "skill warns against bare \$ARGUMENTS shell expansion"
else
    fail "skill warns against bare \$ARGUMENTS shell expansion" "explicit unsafe-form warning" "missing"
fi

# 测试：skill 记录了安全的引用简单调用
if grep -Fq '"${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh" "$ARGUMENTS"' "$ASK_CODEX_SKILL"; then
    pass "skill quotes the question when no flags are present"
else
    fail "skill quotes the question when no flags are present" "quoted simple invocation" "missing"
fi

# 测试：skill 说明自由文本必须是引用的最终参数
if grep -Fq 'one quoted final argument' "$ASK_CODEX_SKILL"; then
    pass "skill requires one quoted final argument for free-form text"
else
    fail "skill requires one quoted final argument for free-form text" "quoted final argument guidance" "missing"
fi

# ========================================
# 自动探针：嵌套钩子禁用测试
# ========================================

echo ""
echo "--- Auto-Probe: Nested Hook Disable Tests ---"
echo ""

# 设置：为探针测试创建辅助模拟 codex 二进制目录，
# 使探针结果不会从早期测试中缓存。
PROBE_BIN_DIR="$TEST_DIR/probe-bin"
PROBE_PROJECT="$TEST_DIR/probe-project"
init_test_git_repo "$PROBE_PROJECT"
mkdir -p "$PROBE_BIN_DIR"

run_ask_codex_probe() {
    (
        cd "$PROBE_PROJECT"
        export CLAUDE_PROJECT_DIR="$PROBE_PROJECT"
        export XDG_CACHE_HOME="$TEST_DIR/cache-probe"
        PATH="$PROBE_BIN_DIR:$PATH" bash "$ASK_CODEX_SCRIPT" "$@"
    )
}

# 测试 A：当 codex 支持 --disable 时，ask-codex.sh 注入 --disable hooks
# 创建一个在 --help 输出中回显 "--disable" 的模拟 codex
cat > "$PROBE_BIN_DIR/codex" << 'PROBE_MOCK_SUPPORTS'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]] || echo "$*" | grep -q -- '--help'; then
    echo "--disable <feature>   Disable a named feature"
    for i in $(seq 1 5000); do
        printf -- "--noise-%s\n" "$i"
    done
    exit 0
fi
if [[ -n "${MOCK_CODEX_STDERR:-}" ]]; then echo "$MOCK_CODEX_STDERR" >&2; fi
if [[ -n "${MOCK_CODEX_STDOUT:-}" ]]; then echo "$MOCK_CODEX_STDOUT"; fi
cat > /dev/null
exit "${MOCK_CODEX_EXIT_CODE:-0}"
PROBE_MOCK_SUPPORTS
chmod +x "$PROBE_BIN_DIR/codex"

reset_mock
export MOCK_CODEX_STDOUT="probe-test-supports"
run_ask_codex_probe "probe disable test" > /dev/null 2>&1 || true

# 检查 skill 目录中缓存的探针结果是否为 "yes"
PROBE_SKILL_DIR=$(find "$PROBE_PROJECT/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
if [[ -n "$PROBE_SKILL_DIR" ]] && [[ -f "$PROBE_SKILL_DIR/.codex-disable-hooks-supported" ]]; then
    PROBE_RESULT=$(cat "$PROBE_SKILL_DIR/.codex-disable-hooks-supported")
    if [[ "$PROBE_RESULT" == "yes" ]]; then
        pass "auto-probe: cached 'yes' when codex supports --disable"
    else
        fail "auto-probe: cached 'yes' when codex supports --disable" "yes" "$PROBE_RESULT"
    fi
else
    fail "auto-probe: probe cache file created" "cache file exists" "not found"
fi

# 测试 B：当 codex 不支持 --disable 时，探针结果为 "no"
PROBE_BIN_NO_DIR="$TEST_DIR/probe-bin-no"
PROBE_PROJECT_NO="$TEST_DIR/probe-project-no"
init_test_git_repo "$PROBE_PROJECT_NO"
mkdir -p "$PROBE_BIN_NO_DIR"

cat > "$PROBE_BIN_NO_DIR/codex" << 'PROBE_MOCK_NO_SUPPORT'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]] || echo "$*" | grep -q -- '--help'; then
    echo "Usage: codex exec [options]"
    echo "  --full-auto   Run without prompts"
    exit 0
fi
if [[ -n "${MOCK_CODEX_STDERR:-}" ]]; then echo "$MOCK_CODEX_STDERR" >&2; fi
if [[ -n "${MOCK_CODEX_STDOUT:-}" ]]; then echo "$MOCK_CODEX_STDOUT"; fi
cat > /dev/null
exit "${MOCK_CODEX_EXIT_CODE:-0}"
PROBE_MOCK_NO_SUPPORT
chmod +x "$PROBE_BIN_NO_DIR/codex"

run_ask_codex_probe_no() {
    (
        cd "$PROBE_PROJECT_NO"
        export CLAUDE_PROJECT_DIR="$PROBE_PROJECT_NO"
        export XDG_CACHE_HOME="$TEST_DIR/cache-probe-no"
        PATH="$PROBE_BIN_NO_DIR:$PATH" bash "$ASK_CODEX_SCRIPT" "$@"
    )
}

reset_mock
export MOCK_CODEX_STDOUT="probe-test-no-support"
run_ask_codex_probe_no "probe no-support test" > /dev/null 2>&1 || true

PROBE_NO_SKILL_DIR=$(find "$PROBE_PROJECT_NO/.humanize/skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
if [[ -n "$PROBE_NO_SKILL_DIR" ]] && [[ -f "$PROBE_NO_SKILL_DIR/.codex-disable-hooks-supported" ]]; then
    PROBE_NO_RESULT=$(cat "$PROBE_NO_SKILL_DIR/.codex-disable-hooks-supported")
    if [[ "$PROBE_NO_RESULT" == "no" ]]; then
        pass "auto-probe: cached 'no' when codex does not support --disable"
    else
        fail "auto-probe: cached 'no' when codex does not support --disable" "no" "$PROBE_NO_RESULT"
    fi
else
    fail "auto-probe: probe cache file created for no-support case" "cache file exists" "not found"
fi

# 测试 C：ask-codex.sh 脚本包含探针实现
if grep -q "CODEX_DISABLE_HOOKS_ARGS=(--disable hooks)" "$ASK_CODEX_SCRIPT" \
    && grep -q "codex-disable-hooks-supported" "$ASK_CODEX_SCRIPT"; then
    pass "ask-codex.sh contains nested hook disable auto-probe implementation"
else
    fail "ask-codex.sh contains nested hook disable auto-probe implementation" "hooks disable args + probe cache" "not found"
fi

# ========================================
# 摘要
# ========================================

print_test_summary "Ask Codex Test Summary"
