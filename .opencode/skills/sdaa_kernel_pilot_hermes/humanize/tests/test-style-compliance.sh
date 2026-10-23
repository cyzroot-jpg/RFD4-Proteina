#!/usr/bin/env bash
#
# AC-10 风格合规测试（在第 5 轮作为任务 T15 添加；
# 在第 6 和 7 轮扩展以覆盖计划要求的完整范围）。
#
# AC-10 禁止字面量子串 "AC-"、"Milestone"、"Step "、"Phase "
# 出现在实现代码或注释中。这些标记保留给计划文档；在代码中
# 使用它们会使代码库携带在运行时没有领域含义的工作流标记。
#
# 范围（rebase 到 upstream/dev 后）：
#   - viz/ 下的所有 .sh 和 .py 文件（计划编写的代码）。
#   - scripts/cancel-rlcr-session.sh（此计划添加的新文件）。
#
# 更广泛的 scripts/ 目录由上游拥有。其文件合法地在正则表达式
# 模式、模板内容和面向用户的字符串中引用工作流术语如 "AC-1"、
# "Phase"、"Review Phase" —— 这些早于此计划且在 AC-10 的
# 职权范围之外。commands/ 和 hooks/ 同理。
#
# 排除：
#   - tests/ 本身（夹具合法地包含禁止的字面量作为预期输入）。
#   - scripts/* 除了计划编写的 cancel-rlcr-session.sh。
#   - commands/ 和 hooks/（上游拥有的工作流）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "AC-10 style compliance (T15 full scope)"
echo "========================================"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { printf '\033[0;32mPASS\033[0m: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { printf '\033[0;31mFAIL\033[0m: %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# 步骤 1：viz/ 下的每个 .sh 和 .py。
CORE_FILES=()
while IFS= read -r f; do
    CORE_FILES+=("$f")
done < <(
    find "$PLUGIN_ROOT/viz" \
        -type f \( -name '*.sh' -o -name '*.py' \) \
        -not -path "*/__pycache__/*" \
        2>/dev/null | sort
)

# 步骤 2：scripts/ 下计划编写的文件。
PLAN_AUTHORED_SCRIPTS=(
    "$PLUGIN_ROOT/scripts/cancel-rlcr-session.sh"
)
EXTRA_FILES=()
for f in "${PLAN_AUTHORED_SCRIPTS[@]}"; do
    [[ -f "$f" ]] && EXTRA_FILES+=("$f")
done

FILES=("${CORE_FILES[@]}" "${EXTRA_FILES[@]}")

if [[ ${#FILES[@]} -eq 0 ]]; then
    _fail "no plan-scope files found to scan"
    exit 1
fi

n_core=${#CORE_FILES[@]}
n_extra=${#EXTRA_FILES[@]}
echo "Scanning ${#FILES[@]} files (${n_core} under viz/, ${n_extra} plan-authored under scripts/)."

# 按模式键控的每文件发现，因此我们为每个模式报告单个 PASS 或
# FAIL 行，附带违规文件列表。
for pattern in 'AC-' 'Milestone' 'Step ' 'Phase '; do
    label="$pattern"
    found_files=()
    for f in "${FILES[@]}"; do
        if grep -nF "$pattern" "$f" >/dev/null 2>&1; then
            found_files+=("${f#$PLUGIN_ROOT/}")
        fi
    done
    if [[ ${#found_files[@]} -eq 0 ]]; then
        _pass "no '$label' literal across the plan's full AC-10 scope"
    else
        _fail "literal '$label' appears in: ${found_files[*]}"
        for f in "${found_files[@]}"; do
            echo "    --- matches in $f ---"
            grep -nF "$pattern" "$PLUGIN_ROOT/$f" | sed 's/^/      /'
        done
    fi
done

echo
echo "========================================"
printf 'Passed: \033[0;32m%d\033[0m\n' "$PASS_COUNT"
printf 'Failed: \033[0;31m%d\033[0m\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi

printf '\033[0;32mAC-10 compliance check passed!\033[0m\n'
