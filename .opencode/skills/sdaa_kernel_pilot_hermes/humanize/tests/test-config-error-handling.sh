#!/usr/bin/env bash
#
# scripts/lib/config-loader.sh 中错误处理的测试
#
# 验证：
# - 缺失 default_config.json 导致致命（非零）退出
# - 项目配置中的格式错误 JSON 发出警告并回退到默认值
# - 用户配置中的格式错误 JSON 发出警告并回退到默认值
# - 空的 ({}) 项目配置有效，使用所有默认值
# - 缺失项目配置文件不致命；使用默认值
# - 缺失可选用户配置文件不致命；使用默认值
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

CONFIG_LOADER="$PROJECT_ROOT/scripts/lib/config-loader.sh"

echo "=========================================="
echo "Config Error Handling Tests"
echo "=========================================="
echo ""

if [[ ! -f "$CONFIG_LOADER" ]]; then
    echo "FATAL: config-loader.sh not found at $CONFIG_LOADER" >&2
    exit 1
fi

# shellcheck source=../scripts/lib/config-loader.sh
source "$CONFIG_LOADER"


# ========================================
# 测试 1：缺失 default_config.json 是致命的
# ========================================

setup_test_dir
FAKE_PLUGIN_ROOT="$TEST_DIR/fake-plugin"
mkdir -p "$FAKE_PLUGIN_ROOT/config"
# 故意不创建 default_config.json

PROJECT_DIR="$TEST_DIR/project-fatal"
mkdir -p "$PROJECT_DIR"

if ! load_merged_config "$FAKE_PLUGIN_ROOT" "$PROJECT_DIR" >/dev/null 2>&1; then
    pass "missing default_config.json: load_merged_config exits with non-zero status"
else
    fail "missing default_config.json: load_merged_config exits with non-zero status" \
        "non-zero exit" "zero exit (no error)"
fi

# ========================================
# 测试 2：项目配置中的格式错误 JSON → 警告 + 回退到默认值
# ========================================

setup_test_dir
PROJECT_DIR="$TEST_DIR/malformed-project"
mkdir -p "$PROJECT_DIR/.humanize"
printf 'not valid json at all' > "$PROJECT_DIR/.humanize/config.json"

stderr_out=$(XDG_CONFIG_HOME="$TEST_DIR/no-user" \
    load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>&1 >/dev/null || true)

if echo "$stderr_out" | grep -qi "malformed\|ignoring\|warning"; then
    pass "malformed project config: warning emitted to stderr"
else
    fail "malformed project config: warning emitted to stderr" \
        "warning/ignoring message on stderr" "no warning output"
fi

merged=$(XDG_CONFIG_HOME="$TEST_DIR/no-user" \
    load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null)
val=$(get_config_value "$merged" "bitlesson_model")
if [[ "$val" == "haiku" ]]; then
    pass "malformed project config: falls back to defaults"
else
    fail "malformed project config: falls back to defaults" "haiku" "$val"
fi

# ========================================
# 测试 3：用户配置中的格式错误 JSON → 警告 + 回退到默认值
# ========================================

setup_test_dir
PROJECT_DIR="$TEST_DIR/malformed-user"
mkdir -p "$PROJECT_DIR"
mkdir -p "$TEST_DIR/bad-user-cfg/humanize"
printf '{bad json here}' > "$TEST_DIR/bad-user-cfg/humanize/config.json"

stderr_out=$(XDG_CONFIG_HOME="$TEST_DIR/bad-user-cfg" \
    load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>&1 >/dev/null || true)

if echo "$stderr_out" | grep -qi "malformed\|ignoring\|warning"; then
    pass "malformed user config: warning emitted to stderr"
else
    fail "malformed user config: warning emitted to stderr" \
        "warning/ignoring message on stderr" "no warning output"
fi

merged=$(XDG_CONFIG_HOME="$TEST_DIR/bad-user-cfg" \
    load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null)
val=$(get_config_value "$merged" "bitlesson_model")
if [[ "$val" == "haiku" ]]; then
    pass "malformed user config: falls back to defaults"
else
    fail "malformed user config: falls back to defaults" "haiku" "$val"
fi

# ========================================
# 测试 4：空的项目配置 ({}) 有效 → 使用所有默认值
# ========================================

setup_test_dir
PROJECT_DIR="$TEST_DIR/empty-proj-cfg"
mkdir -p "$PROJECT_DIR/.humanize"
printf '{}' > "$PROJECT_DIR/.humanize/config.json"

merged=$(XDG_CONFIG_HOME="$TEST_DIR/no-user2" \
    load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null)
val=$(get_config_value "$merged" "bitlesson_model")
if [[ "$val" == "haiku" ]]; then
    pass "empty project config: uses all defaults"
else
    fail "empty project config: uses all defaults" "haiku" "$val"
fi

# ========================================
# 测试 5：缺失项目配置文件不致命
# ========================================

setup_test_dir
PROJECT_DIR="$TEST_DIR/no-proj-cfg"
mkdir -p "$PROJECT_DIR"
# 完全没有 .humanize/ 目录

if merged=$(XDG_CONFIG_HOME="$TEST_DIR/no-user3" \
        load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null); then
    val=$(get_config_value "$merged" "bitlesson_model")
    if [[ "$val" == "haiku" ]]; then
        pass "missing project config file: not fatal, uses defaults"
    else
        fail "missing project config file: not fatal, uses defaults" "haiku" "$val"
    fi
else
    fail "missing project config file: not fatal, uses defaults" \
        "success with defaults" "fatal error"
fi

# ========================================
# 测试 6：缺失用户配置目录不致命
# ========================================

setup_test_dir
PROJECT_DIR="$TEST_DIR/no-user-dir-project"
mkdir -p "$PROJECT_DIR"
# 将 XDG_CONFIG_HOME 指向不存在的目录

if merged=$(XDG_CONFIG_HOME="$TEST_DIR/does-not-exist" \
        load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null); then
    val=$(get_config_value "$merged" "bitlesson_model")
    if [[ "$val" == "haiku" ]]; then
        pass "missing user config directory: not fatal, uses defaults"
    else
        fail "missing user config directory: not fatal, uses defaults" "haiku" "$val"
    fi
else
    fail "missing user config directory: not fatal, uses defaults" \
        "success with defaults" "fatal error"
fi

print_test_summary "Config Error Handling Tests"
