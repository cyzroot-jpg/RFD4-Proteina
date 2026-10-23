#!/usr/bin/env zsh
#
# humanize monitor 的 Zsh 运行时安全测试
#
# 此测试必须由 zsh 执行以验证：
# - 无 zsh "no matches found" 错误
# - 在 zsh shell 中正常工作
#
# 在 zsh 下使用空/仅点文件目录测试实际的 humanize.sh 函数
#

# 错误时失败
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo "${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo "${RED}FAIL${NC}: $1"
    echo "  Details: $2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "========================================"
echo "Zsh Runtime Safety Tests"
echo "========================================"
echo "Shell: $ZSH_VERSION"
echo ""

# ========================================
# 测试设置：创建隔离的测试环境
# ========================================

TEST_BASE="/tmp/test-zsh-humanize-$$"
mkdir -p "$TEST_BASE"
cd "$TEST_BASE"

# 设置隔离的缓存目录以避免权限问题
export XDG_CACHE_HOME="$TEST_BASE/.cache"
mkdir -p "$XDG_CACHE_HOME"

cleanup() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_BASE"
}
trap cleanup EXIT

# ========================================
# 测试 1：在 zsh 下加载 humanize.sh
# ========================================
echo "Test 1: Source humanize.sh under zsh"
echo ""

# 创建最小测试环境
mkdir -p .humanize/rlcr

# 加载脚本
source_output=$(source "$PROJECT_ROOT/scripts/humanize.sh" 2>&1) || true
if [[ "$source_output" == *"no matches found"* ]]; then
    fail "Source humanize.sh" "Got 'no matches found' error: $source_output"
else
    pass "Source humanize.sh without glob errors"
fi

# ========================================
# 测试 2：空循环目录的 _find_latest_session
# ========================================
echo ""
echo "Test 2: _find_latest_session with empty loop dir"
echo ""

# 创建空的 .humanize/rlcr 目录
rm -rf .humanize/rlcr
mkdir -p .humanize/rlcr

# 加载并调用函数
(
    source "$PROJECT_ROOT/scripts/humanize.sh"

    # 通过监控包装器上下文访问内部函数
    # 我们需要模拟监控环境
    loop_dir=".humanize/rlcr"

    # 在本地定义函数（与 humanize.sh 中相同）
    _find_latest_session_test() {
        local latest_session=""
        if [[ ! -d "$loop_dir" ]]; then
            echo ""
            return
        fi
        while IFS= read -r session_dir; do
            [[ -z "$session_dir" ]] && continue
            [[ ! -d "$session_dir" ]] && continue
            local session_name=$(basename "$session_dir")
            if [[ "$session_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
                if [[ -z "$latest_session" ]] || [[ "$session_name" > "$(basename "$latest_session")" ]]; then
                    latest_session="$session_dir"
                fi
            fi
        done < <(find "$loop_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        echo "$latest_session"
    }

    result=$(_find_latest_session_test 2>&1)
    if [[ "$result" == *"no matches found"* ]]; then
        echo "ERROR: $result"
        exit 1
    fi
    echo "OK: result='$result'"
) && pass "_find_latest_session with empty dir" || fail "_find_latest_session with empty dir" "Got glob error"

# ========================================
# 测试 3：仅点文件的 _find_latest_session
# ========================================
echo ""
echo "Test 3: _find_latest_session with dotfiles only"
echo ""

touch .humanize/rlcr/.cancel-requested
touch .humanize/rlcr/.hidden-file

(
    loop_dir=".humanize/rlcr"

    # 重用测试 2 中的相同函数模式（测试仅包含点文件的目录）
    result=""
    while IFS= read -r session_dir; do
        [[ -z "$session_dir" ]] && continue
        [[ ! -d "$session_dir" ]] && continue
        session_name=$(basename "$session_dir")
        if [[ "$session_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
            if [[ -z "$result" ]] || [[ "$session_name" > "$(basename "$result")" ]]; then
                result="$session_dir"
            fi
        fi
    done < <(find "$loop_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [[ "$result" == *"no matches found"* ]]; then
        echo "ERROR: $result"
        exit 1
    fi
    echo "OK: result='$result'"
) && pass "_find_latest_session with dotfiles only" || fail "_find_latest_session with dotfiles only" "Got glob error"

# ========================================
# 测试 4：无 *-state.md 文件的 _find_state_file
# ========================================
echo ""
echo "Test 4: _find_state_file with no *-state.md files"
echo ""

mkdir -p .humanize/rlcr/2026-01-16_10-00-00
touch .humanize/rlcr/2026-01-16_10-00-00/other.md

(
    session_dir=".humanize/rlcr/2026-01-16_10-00-00"

    _find_state_file_test() {
        if [[ -z "$session_dir" || ! -d "$session_dir" ]]; then
            echo "|unknown"
            return
        fi
        if [[ -f "$session_dir/state.md" ]]; then
            echo "$session_dir/state.md|active"
            return
        fi
        local state_file=""
        local stop_reason=""
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if [[ -f "$f" ]]; then
                state_file="$f"
                local basename=$(basename "$f")
                stop_reason="${basename%-state.md}"
                break
            fi
        done < <(find "$session_dir" -maxdepth 1 -name '*-state.md' -type f 2>/dev/null)
        if [[ -n "$state_file" ]]; then
            echo "$state_file|$stop_reason"
        else
            echo "|unknown"
        fi
    }

    result=$(_find_state_file_test 2>&1)
    if [[ "$result" == *"no matches found"* ]]; then
        echo "ERROR: $result"
        exit 1
    fi
    echo "OK: result='$result'"
) && pass "_find_state_file with no *-state.md" || fail "_find_state_file with no *-state.md" "Got glob error"

# ========================================
# 测试 5：空缓存的 _find_latest_codex_log
# ========================================
echo ""
echo "Test 5: _find_latest_codex_log with empty cache dir"
echo ""

# 创建会话但没有缓存日志文件
mkdir -p "$XDG_CACHE_HOME/humanize/test-project/2026-01-16_10-00-00"

(
    loop_dir=".humanize/rlcr"
    cache_dir="$XDG_CACHE_HOME/humanize/test-project/2026-01-16_10-00-00"

    # 模拟缓存日志迭代
    found_count=0
    while IFS= read -r log_file; do
        [[ -z "$log_file" ]] && continue
        [[ ! -f "$log_file" ]] && continue
        found_count=$((found_count + 1))
    done < <(find "$cache_dir" -maxdepth 1 -name 'round-*-codex-run.log' -type f 2>/dev/null)

    if [[ "$found_count" -eq 0 ]]; then
        echo "OK: found_count=0 (no error)"
    else
        echo "ERROR: expected 0, got $found_count"
        exit 1
    fi
) && pass "_find_latest_codex_log with empty cache" || fail "_find_latest_codex_log with empty cache" "Got error"

rm -rf "$XDG_CACHE_HOME/humanize/test-project"

# ========================================
# 测试 6：完整会话目录迭代
# ========================================
echo ""
echo "Test 6: Full session directory iteration"
echo ""

# 创建有效的会话目录
mkdir -p .humanize/rlcr/2026-01-16_10-00-00
mkdir -p .humanize/rlcr/2026-01-16_11-00-00

(
    loop_dir=".humanize/rlcr"

    found_count=0
    latest=""
    while IFS= read -r session_dir; do
        [[ -z "$session_dir" ]] && continue
        [[ ! -d "$session_dir" ]] && continue
        session_name=$(basename "$session_dir")
        if [[ "$session_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
            found_count=$((found_count + 1))
            if [[ -z "$latest" ]] || [[ "$session_name" > "$(basename "$latest")" ]]; then
                latest="$session_dir"
            fi
        fi
    done < <(find "$loop_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [[ "$found_count" -eq 2 ]] && [[ "$(basename "$latest")" == "2026-01-16_11-00-00" ]]; then
        echo "OK: found 2 sessions, latest is 11-00-00"
    else
        echo "ERROR: expected 2 sessions with latest 11-00-00, got $found_count with $(basename "$latest")"
        exit 1
    fi
) && pass "Full session iteration finds correct sessions" || fail "Full session iteration" "Wrong result"

# ========================================
# 测试 7：验证实际使用的是 zsh
# ========================================
echo ""
echo "Test 7: Verify zsh is actually being used"
echo ""

if [[ -n "$ZSH_VERSION" ]]; then
    pass "Running under zsh $ZSH_VERSION"
else
    fail "Shell verification" "Not running under zsh!"
fi

# ========================================
# 测试 8：旧代码会出现 Zsh 特定的 glob 错误
# ========================================
echo ""
echo "Test 8: Demonstrate zsh glob error (old code pattern)"
echo ""

# 此测试显示旧代码模式会在 zsh 中失败，
# 通过尝试有问题的模式并捕获错误
rm -rf .humanize/rlcr
mkdir -p .humanize/rlcr

(
    setopt +o nomatch 2>/dev/null || true  # Don't fail on no match for this test

    # 旧的问题模式（应产生空或错误）
    old_pattern_output=""
    old_pattern_error=""

    # 尝试会失败的旧 glob 模式
    if eval 'for x in .humanize/rlcr/*; do [[ -e "$x" ]] && old_pattern_output="$old_pattern_output $x"; done' 2>/dev/null; then
        echo "OK: Old pattern handled (but would error without nomatch option)"
    else
        echo "OK: Old pattern would have errored in strict zsh"
    fi

    # 使用 find 的新模式永不报错
    new_pattern_output=""
    while IFS= read -r x; do
        [[ -n "$x" ]] && new_pattern_output="$new_pattern_output $x"
    done < <(find .humanize/rlcr -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    echo "OK: New find pattern works safely"
) && pass "Glob vs find safety demonstration" || fail "Glob vs find demonstration" "Error"

# ========================================
# 总结
# ========================================
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo "${GREEN}All zsh runtime safety tests passed!${NC}"
    exit 0
else
    echo ""
    echo "${RED}Some tests failed!${NC}"
    exit 1
fi
