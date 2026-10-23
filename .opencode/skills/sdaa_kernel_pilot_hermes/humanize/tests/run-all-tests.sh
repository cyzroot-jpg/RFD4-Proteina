#!/usr/bin/env bash
#
# 运行 Humanize 插件的所有测试套件（并行执行）
#
# 用法：./tests/run-all-tests.sh
#
# 每个测试套件在各自隔离的临时目录中运行，因此并行执行是安全的，
# 不存在共享状态或资源竞争问题。
#
# 退出码：
#   0 - 所有测试通过
#   1 - 一个或多个测试失败
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 最大并行测试任务数（限制以避免在小型 CI 运行器上资源耗尽）。
# 可通过 HUMANIZE_TEST_JOBS=<N> 覆盖。
default_jobs() {
    local n=4
    if command -v getconf >/dev/null 2>&1; then
        n=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
    fi
    [[ "$n" =~ ^[0-9]+$ ]] || n=4
    # 默认上限以控制内存/进程使用量。
    [[ "$n" -gt 8 ]] && n=8
    [[ "$n" -lt 1 ]] && n=1
    echo "$n"
}

MAX_JOBS="${HUMANIZE_TEST_JOBS:-$(default_jobs)}"
if ! [[ "$MAX_JOBS" =~ ^[0-9]+$ ]] || [[ "$MAX_JOBS" -lt 1 ]]; then
    echo "Error: HUMANIZE_TEST_JOBS must be an integer >= 1, got: ${HUMANIZE_TEST_JOBS:-}" >&2
    exit 1
fi

# wait -n 从 bash 4.3 开始可用
supports_wait_n() {
    local major="${BASH_VERSINFO[0]:-0}"
    local minor="${BASH_VERSINFO[1]:-0}"
    [[ "$major" -gt 4 ]] || ( [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]] )
}

# 输出颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo "========================================"
echo "Running All Humanize Plugin Tests"
echo "========================================"
echo "Parallel jobs: $MAX_JOBS"
echo ""

# 要运行的测试套件
TEST_SUITES=(
    "test-template-loader.sh"
    "test-bash-validator-patterns.sh"
    "test-todo-checker.sh"
    "test-plan-file-validation.sh"
    "test-template-references.sh"
    "test-state-exit-naming.sh"
    "test-stop-gate.sh"
    "test-strict-success.sh"
    "test-kernel-agent-loop-skill.sh"
    "test-teco-performance-wiki.sh"
    "test-templates-comprehensive.sh"
    "test-plan-file-hooks.sh"
    "test-stop-hook-legacy-compat.sh"
    "test-stop-hook-bg-allow.sh"
    "test-error-scenarios.sh"
    "test-ansi-parsing.sh"
    "test-allowlist-validators.sh"
    "test-finalize-phase.sh"
    "test-codex-review-merge.sh"
    "test-cancel-signal-file.sh"
    "test-humanize-escape.sh"
    "test-zsh-monitor-safety.sh"
    "test-monitor-runtime.sh"
    "test-monitor-e2e-deletion.sh"
    "test-monitor-e2e-sigint.sh"
    "test-gen-plan.sh"
    "test-refine-plan.sh"
    "test-task-tag-routing.sh"
    "test-config-merge.sh"
    "test-config-error-handling.sh"
    "test-codex-hook-install.sh"
    "test-unified-codex-config.sh"
    "test-disable-nested-codex-hooks.sh"
    # 会话 ID 和 Agent Teams 测试
    "test-session-id.sh"
    "test-agent-teams.sh"
    # gen-idea 伴随 JSON 测试 (PR-A)
    "test-validate-gen-idea-io.sh"
    "test-directions-json-schema.sh"
    "test-gen-idea-dual-write.sh"
    # explore-idea 测试 (PR-B)
    "test-validate-explore-idea-io.sh"
    "test-worker-result-contract.sh"
    "test-explore-manifest.sh"
    "test-explore-command-structure.sh"
    # Ask Codex 测试
    "test-ask-codex.sh"
    # Hermes 目标测试
    "test-hermes-wrapper.sh"
    "test-hermes-install.sh"
    "test-hermes-stop-gate.sh"
    "test-hermes-health-check.sh"
    # Bitlesson 路由测试
    "test-bitlesson-select-routing.sh"
    # 提供者路由测试
    "test-model-router.sh"
    # Skill 监控测试
    "test-skill-monitor.sh"
    # 可视化仪表盘测试
    "test-viz.sh"
    "test-viz-isolation.sh"
    "test-streaming.sh"
    "test-app-auth.sh"
    "test-app-routes-live.sh"
    "test-cancel-session.sh"
    "test-frontend-migration.sh"
    "test-rlcr-sources.sh"
    "test-style-compliance.sh"
    # 健壮性测试
    "robustness/test-state-file-robustness.sh"
    "robustness/test-session-robustness.sh"
    "robustness/test-goal-tracker-robustness.sh"
    "robustness/test-path-validation-robustness.sh"
    "robustness/test-git-operations-robustness.sh"
    "robustness/test-hook-input-robustness.sh"
    "robustness/test-template-stress-robustness.sh"
    "robustness/test-plan-file-robustness.sh"
    "robustness/test-cancel-security-robustness.sh"
    "robustness/test-timeout-robustness.sh"
    "robustness/test-base-branch-detection.sh"
    "robustness/test-setup-scripts-robustness.sh"
    "robustness/test-concurrent-state-robustness.sh"
    "robustness/test-hook-system-robustness.sh"
    "robustness/test-template-error-robustness.sh"
    "robustness/test-state-transition-robustness.sh"
)

# 必须使用 zsh（而非 bash）运行的测试
ZSH_TESTS=(
    "test-zsh-monitor-safety.sh"
)

# 信号密集的运行时测试在并行批次完成后运行更稳定。
SERIAL_TESTS=(
    "test-monitor-runtime.sh"
)

# 每个套件输出文件的临时目录
OUTPUT_DIR=$(mktemp -d)
trap "rm -rf $OUTPUT_DIR" EXIT

# 当真实 codex 未安装时提供模拟 codex 二进制文件。
# 测试仅需要 codex 来通过设置脚本中的 `command -v codex` 检查；
# 需要特定 codex 行为的测试已自行创建模拟对象。
if ! command -v codex &>/dev/null; then
    mkdir -p "$OUTPUT_DIR/mock-bin"
    cat > "$OUTPUT_DIR/mock-bin/codex" << 'MOCK_CODEX'
#!/usr/bin/env bash
exit 0
MOCK_CODEX
    chmod +x "$OUTPUT_DIR/mock-bin/codex"
    export PATH="$OUTPUT_DIR/mock-bin:$PATH"
fi

# 在缺少 `timeout` 的平台上提供可移植的 shim（例如 macOS 基础安装）。
# 使用 python3 子进程，保留 stdin 并在超时时返回退出码 124。
if ! command -v timeout &>/dev/null; then
    mkdir -p "$OUTPUT_DIR/mock-bin"
    cat > "$OUTPUT_DIR/mock-bin/timeout" << 'TIMEOUT_SHIM'
#!/usr/bin/env python3
import subprocess, sys
timeout_secs = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    result = subprocess.run(cmd, timeout=timeout_secs)
    sys.exit(result.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except Exception as e:
    print(f"timeout shim error: {e}", file=sys.stderr)
    sys.exit(1)
TIMEOUT_SHIM
    chmod +x "$OUTPUT_DIR/mock-bin/timeout"
    export PATH="$OUTPUT_DIR/mock-bin:$PATH"
fi

# 检查套件是否需要 zsh
needs_zsh() {
    local suite="$1"
    for zsh_test in "${ZSH_TESTS[@]}"; do
        if [[ "$suite" == "$zsh_test" ]]; then
            return 0
        fi
    done
    return 1
}

needs_serial() {
    local suite="$1"
    for serial_test in "${SERIAL_TESTS[@]}"; do
        if [[ "$suite" == "$serial_test" ]]; then
            return 0
        fi
    done
    return 1
}

# 将毫秒格式化为人类可读的持续时间
format_ms() {
    local ms="$1"
    local s=$((ms / 1000))
    local frac=$(( (ms % 1000) / 100 ))  # 十分之一秒
    echo "${s}.${frac}s"
}

# 可移植的毫秒级时间戳（date +%s%3N 仅限 GNU，macOS bash 3.2 不支持）
ms_now() {
    python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null \
        || echo "$(date +%s)000"
}

run_suite_capture() {
    local suite="$1"
    local out_file="$2"
    local exit_file="$3"
    local time_file="$4"
    local suite_path="$SCRIPT_DIR/$suite"
    local t_start

    t_start=$(ms_now)
    if needs_zsh "$suite"; then
        zsh "$suite_path" >"$out_file" 2>&1
    else
        "$suite_path" >"$out_file" 2>&1
    fi
    echo $? >"$exit_file"
    echo $(( $(ms_now) - t_start )) >"$time_file"
}

collect_suite_result() {
    local suite="$1"
    local safe_name="$2"
    local out_file="$3"
    local exit_file="$4"
    local time_file="$5"
    local exit_code
    local output
    local elapsed_ms
    local elapsed_display
    local output_stripped
    local passed
    local failed
    local line
    local zsh_label

    exit_code=$(cat "$exit_file" 2>/dev/null || echo "1")
    output=$(cat "$out_file" 2>/dev/null || echo "")
    elapsed_ms=$(cat "$time_file" 2>/dev/null || echo "0")
    elapsed_display=$(format_ms "$elapsed_ms")

    # 去除 ANSI 转义码并提取通过/失败计数
    output_stripped=$(echo "$output" | sed "s/${esc}\\[[0-9;]*m//g")
    passed=$(echo "$output_stripped" | grep -oE 'Passed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | tail -1 || echo "0")
    failed=$(echo "$output_stripped" | grep -oE 'Failed:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | tail -1 || echo "0")

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))

    if [[ $exit_code -ne 0 ]] || [[ "$failed" -gt 0 ]]; then
        FAILED_SUITES+=("$suite")
        line=$(echo -e "${RED}FAILED${NC}: $suite (exit code: $exit_code, failed: $failed, ${elapsed_display})")
        printf '%d\t%s\n' "$elapsed_ms" "$line" >> "$SORT_FILE"
        # 保留完整的套件日志，以便 CI 显示确切的失败断言。
        printf '%s\n' "$output" > "$OUTPUT_DIR/${safe_name}.detail"
    else
        zsh_label=""
        needs_zsh "$suite" && zsh_label=" (zsh)"
        line=$(echo -e "${GREEN}PASSED${NC}: $suite${zsh_label} ($passed tests, ${elapsed_display})")
        printf '%d\t%s\n' "$elapsed_ms" "$line" >> "$SORT_FILE"
    fi
}

# 并行启动所有测试套件，但信号密集的运行时测试除外，
# 它们在并行批次完成后串行运行。PID 和跳过原因存储在 OUTPUT_DIR 中，
# 而非关联数组，以兼容 bash 3.2。
ACTIVE_PIDS=()
SERIAL_SUITES=()

for suite in "${TEST_SUITES[@]}"; do
    suite_path="$SCRIPT_DIR/$suite"
    safe_name="$(echo "$suite" | tr '/' '_')"
    out_file="$OUTPUT_DIR/${safe_name}.out"
    exit_file="$OUTPUT_DIR/${safe_name}.exit"
    time_file="$OUTPUT_DIR/${safe_name}.time"

    if [[ ! -f "$suite_path" ]]; then
        echo "not found" > "$OUTPUT_DIR/${safe_name}.skip"
        continue
    fi

    if needs_serial "$suite"; then
        SERIAL_SUITES+=("$suite")
        echo "serial" > "$OUTPUT_DIR/${safe_name}.serial"
        continue
    fi

    if needs_zsh "$suite"; then
        if ! command -v zsh &>/dev/null; then
            echo "zsh not available" > "$OUTPUT_DIR/${safe_name}.skip"
            continue
        fi
    fi

    (
        run_suite_capture "$suite" "$out_file" "$exit_file" "$time_file"
    ) &
    echo $! > "$OUTPUT_DIR/${safe_name}.pid"
    ACTIVE_PIDS+=($!)

    # 限制后台任务数
    while [[ "${#ACTIVE_PIDS[@]}" -ge "$MAX_JOBS" ]]; do
        if supports_wait_n; then
            wait -n 2>/dev/null || true
            # 从 ACTIVE_PIDS 中清除已完成的 PID
            still_running=()
            for pid in "${ACTIVE_PIDS[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    still_running+=("$pid")
                fi
            done
            ACTIVE_PIDS=(${still_running[@]+"${still_running[@]}"})
        else
            # 回退：等待最旧的 PID（效率较低但兼容旧版 bash）
            wait "${ACTIVE_PIDS[0]}" 2>/dev/null || true
            ACTIVE_PIDS=("${ACTIVE_PIDS[@]:1}")
        fi
    done
done

# 等待并行套件并收集结果。
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_SUITES=()
# 可排序文件：elapsed_ms<TAB>display_line
SORT_FILE="$OUTPUT_DIR/sortable.txt"
: > "$SORT_FILE"

esc=$'\033'
for suite in "${TEST_SUITES[@]}"; do
    safe_name="$(echo "$suite" | tr '/' '_')"
    [[ -f "$OUTPUT_DIR/${safe_name}.skip" ]] && continue
    [[ -f "$OUTPUT_DIR/${safe_name}.serial" ]] && continue

    pid=$(cat "$OUTPUT_DIR/${safe_name}.pid" 2>/dev/null || echo "")
    [[ -n "$pid" ]] && wait "$pid" 2>/dev/null

    out_file="$OUTPUT_DIR/${safe_name}.out"
    exit_file="$OUTPUT_DIR/${safe_name}.exit"
    time_file="$OUTPUT_DIR/${safe_name}.time"
    collect_suite_result "$suite" "$safe_name" "$out_file" "$exit_file" "$time_file"
done

# 在并行批次完成后运行串行套件。
for suite in "${SERIAL_SUITES[@]}"; do
    safe_name="$(echo "$suite" | tr '/' '_')"
    out_file="$OUTPUT_DIR/${safe_name}.out"
    exit_file="$OUTPUT_DIR/${safe_name}.exit"
    time_file="$OUTPUT_DIR/${safe_name}.time"

    run_suite_capture "$suite" "$out_file" "$exit_file" "$time_file"
    collect_suite_result "$suite" "$safe_name" "$out_file" "$exit_file" "$time_file"
done

# 先打印被跳过的套件
for suite in "${TEST_SUITES[@]}"; do
    safe_name="$(echo "$suite" | tr '/' '_')"
    skip_file="$OUTPUT_DIR/${safe_name}.skip"
    if [[ -f "$skip_file" ]]; then
        skip_reason=$(cat "$skip_file" 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}SKIP${NC}: $suite ($skip_reason)"
    fi
done

# 按耗时排序打印结果（最快的在前）
sort -t$'\t' -k1,1n "$SORT_FILE" | cut -f2-

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Total Failed: ${RED}$TOTAL_FAILED${NC}"
echo ""

if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo -e "${RED}Failed Test Suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo "  - $suite"
        safe_name="$(echo "$suite" | tr '/' '_')"
        detail_file="$OUTPUT_DIR/${safe_name}.detail"
        if [[ -f "$detail_file" ]]; then
            echo "    ----------------------------------------"
            sed 's/^/    /' "$detail_file"
            echo ""
        fi
    done
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
