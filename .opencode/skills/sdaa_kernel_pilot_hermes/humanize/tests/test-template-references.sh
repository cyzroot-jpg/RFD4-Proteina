#!/usr/bin/env bash
#
# 模板引用验证
#
# 此脚本扫描所有使用模板加载函数的 shell 脚本，
# 并验证所有引用的模板文件确实存在。
#
# 这防止了当验证器阻止操作时，缺失的模板文件导致
# Claude 收到空错误消息的关键问题。
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/prompt-template"

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

pass() {
    echo -e "  ${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn() {
    echo -e "  ${YELLOW}WARN${NC}: $1"
    WARNINGS=$((WARNINGS + 1))
}

section() {
    echo ""
    echo -e "${BLUE}========================================"
    echo "$1"
    echo -e "========================================${NC}"
}

# ========================================
# 第 1 部分：查找所有模板引用
# ========================================
section "Section 1: Scanning Shell Scripts for Template References"

# 查找所有可能使用模板的 shell 脚本
SCRIPTS_TO_CHECK=(
    "$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh"
    "$PROJECT_ROOT/hooks/loop-read-validator.sh"
    "$PROJECT_ROOT/hooks/loop-write-validator.sh"
    "$PROJECT_ROOT/hooks/loop-edit-validator.sh"
    "$PROJECT_ROOT/hooks/loop-bash-validator.sh"
    "$PROJECT_ROOT/hooks/lib/loop-common.sh"
)

# 引用模板的模式
# - load_template "$TEMPLATE_DIR" "path/to/template.md"
# - load_and_render "$TEMPLATE_DIR" "path/to/template.md"
# - load_and_render_safe "$TEMPLATE_DIR" "path/to/template.md"

MISSING_TEMPLATES=()
FOUND_REFERENCES=0

for script in "${SCRIPTS_TO_CHECK[@]}"; do
    if [[ ! -f "$script" ]]; then
        warn "Script not found: $script"
        continue
    fi

    script_name=$(basename "$script")
    echo "Checking: $script_name"

    # 从 load_template、load_and_render、load_and_render_safe 调用中提取模板路径
    # 模式：function_name "$TEMPLATE_DIR" "template/path.md"
    # 我们查找 $TEMPLATE_DIR 后的带引号字符串

    while IFS= read -r line; do
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Match load_template, load_and_render, or load_and_render_safe
        if echo "$line" | grep -qE '(load_template|load_and_render|load_and_render_safe)[[:space:]]+"\$TEMPLATE_DIR"'; then
            # Extract the template path (second quoted argument)
            template_path=$(echo "$line" | sed -n 's/.*"\$TEMPLATE_DIR"[[:space:]]*"\([^"]*\)".*/\1/p')

            if [[ -n "$template_path" ]]; then
                FOUND_REFERENCES=$((FOUND_REFERENCES + 1))
                full_path="$TEMPLATE_DIR/$template_path"

                if [[ -f "$full_path" ]]; then
                    pass "Template exists: $template_path"
                else
                    fail "Template MISSING: $template_path (referenced in $script_name)"
                    MISSING_TEMPLATES+=("$template_path")
                fi
            fi
        fi
    done < "$script"
done

echo ""
echo "Total template references found: $FOUND_REFERENCES"

# ========================================
# 第 2 部分：检查模板目录完整性
# ========================================
section "Section 2: Verify All Templates Are Referenced"

# 获取所有模板文件列表
TEMPLATE_FILES=()
while IFS= read -r -d '' file; do
    relative_path="${file#$TEMPLATE_DIR/}"
    TEMPLATE_FILES+=("$relative_path")
done < <(find "$TEMPLATE_DIR" -name "*.md" -type f -print0)

echo "Total template files: ${#TEMPLATE_FILES[@]}"

# 对于每个模板，检查它是否在某处被引用
# （这是信息性的 - 并非所有模板都需要被引用）
UNREFERENCED=()

for template in "${TEMPLATE_FILES[@]}"; do
    # 在任何 shell 脚本中搜索此模板路径
    if grep -rq "\"$template\"" "$PROJECT_ROOT/hooks/" 2>/dev/null; then
        pass "Template referenced: $template"
    else
        warn "Template not directly referenced: $template (may be OK if used dynamically)"
        UNREFERENCED+=("$template")
    fi
done

# ========================================
# 第 3 部分：交叉引用验证
# ========================================
section "Section 3: Cross-Reference Validation"

# 检查 loop-common.sh 中的消息函数是否引用有效模板
echo "Checking loop-common.sh message functions..."

COMMON_TEMPLATES=(
    "block/todos-file-access.md"
    "block/prompt-file-write.md"
    "block/state-file-modification.md"
    "block/summary-bash-write.md"
    "block/goal-tracker-bash-write.md"
    "block/goal-tracker-modification.md"
)

for template in "${COMMON_TEMPLATES[@]}"; do
    if [[ -f "$TEMPLATE_DIR/$template" ]]; then
        pass "Common template exists: $template"
    else
        fail "Common template MISSING: $template"
    fi
done

# ========================================
# 第 4 部分：验证回退消息存在
# ========================================
section "Section 4: Verify load_and_render_safe Usage"

echo "Checking that critical validators use load_and_render_safe..."

CRITICAL_SCRIPTS=(
    "$PROJECT_ROOT/hooks/loop-read-validator.sh"
    "$PROJECT_ROOT/hooks/loop-write-validator.sh"
    "$PROJECT_ROOT/hooks/loop-edit-validator.sh"
)

for script in "${CRITICAL_SCRIPTS[@]}"; do
    script_name=$(basename "$script")

    # Count lines with load_and_render that are NOT load_and_render_safe
    # First get all load_and_render lines, then exclude _safe ones
    unsafe_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q 'load_and_render[[:space:]]*"\$TEMPLATE_DIR"'; then
            if ! echo "$line" | grep -q 'load_and_render_safe'; then
                unsafe_count=$((unsafe_count + 1))
            fi
        fi
    done < "$script"

    if [[ "$unsafe_count" -gt 0 ]]; then
        fail "$script_name has $unsafe_count unsafe load_and_render calls (should use load_and_render_safe)"
    else
        pass "$script_name uses load_and_render_safe for all template rendering"
    fi
done

# ========================================
# 总结
# ========================================
section "Test Summary"

echo ""
echo -e "Passed:   ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:   ${RED}$TESTS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [[ ${#MISSING_TEMPLATES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}CRITICAL: Missing template files:${NC}"
    for t in "${MISSING_TEMPLATES[@]}"; do
        echo "  - $t"
    done
fi

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}All template reference checks passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Template reference validation failed!${NC}"
    echo "Fix the missing templates before committing."
    exit 1
fi
