#!/usr/bin/env bash
#
# 积分 (I) 组件的测试脚本：commit-history-section
#
# 验证：
# 1. 第 0 轮："(no commits yet)" 和 "(first round, no prior history)"
# 2. 第 2+ 轮：提交日志和轮次文件引用正确渲染
# 3. 损坏的 BASE_COMMIT：带注释的优雅回退
# 4. 模板缺失：回退渲染完整的部分，包括轮次文件
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$PROJECT_ROOT/hooks/lib/template-loader.sh"

TEMPLATE_DIR="$PROJECT_ROOT/prompt-template"

echo "========================================"
echo "Testing commit-history-section (I component)"
echo "========================================"
echo ""

# ========================================
# 设置：创建临时 git 仓库
# ========================================
setup_test_dir
init_test_git_repo "$TEST_DIR/repo"

# ========================================
# 测试 1：第 0 轮 - 基准后无提交，第一轮
# ========================================
echo "Test 1: Round 0 - no commits, first round"

CURRENT_ROUND=0
BASE_COMMIT=$(git -C "$TEST_DIR/repo" rev-parse HEAD)

# BASE_COMMIT..HEAD 之间无提交（同一提交）
COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse "$BASE_COMMIT"..HEAD 2>/dev/null | tail -80)
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

RECENT_ROUND_FILES=""
LOOP_TIMESTAMP="2026-01-01_00-00-00"
for (( r = CURRENT_ROUND - 1; r >= 0 && r >= CURRENT_ROUND - 3; r-- )); do
    RECENT_ROUND_FILES+="- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-summary.md
- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-review-result.md
"
done
[[ -z "$RECENT_ROUND_FILES" ]] && RECENT_ROUND_FILES="(first round, no prior history)"

RESULT=$(load_and_render_safe "$TEMPLATE_DIR" "codex/commit-history-section.md" "FALLBACK" \
    "COMMIT_HISTORY=$COMMIT_HISTORY" \
    "RECENT_ROUND_FILES=$RECENT_ROUND_FILES")

if echo "$RESULT" | grep -q "(no commits yet)" && echo "$RESULT" | grep -q "(first round, no prior history)"; then
    pass "Round 0 shows correct placeholders"
else
    fail "Round 0 placeholders" "(no commits yet) and (first round, no prior history)" "$RESULT"
fi

# ========================================
# 测试 2：第 3 轮 - 带有提交和轮次历史
# ========================================
echo ""
echo "Test 2: Round 3 - commits and round file references"

# 创建一些提交
cd "$TEST_DIR/repo"
echo "feat1" > feat1.txt && git add feat1.txt && git commit -q -m "feat: add feature 1"
echo "feat2" > feat2.txt && git add feat2.txt && git commit -q -m "feat: add feature 2"
echo "fix1" > fix1.txt && git add fix1.txt && git commit -q -m "fix: resolve bug in feature 1"
cd - > /dev/null

CURRENT_ROUND=3
COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse "$BASE_COMMIT"..HEAD 2>/dev/null | tail -80)
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

RECENT_ROUND_FILES=""
for (( r = CURRENT_ROUND - 1; r >= 0 && r >= CURRENT_ROUND - 3; r-- )); do
    RECENT_ROUND_FILES+="- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-summary.md
- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-review-result.md
"
done
[[ -z "$RECENT_ROUND_FILES" ]] && RECENT_ROUND_FILES="(first round, no prior history)"

RESULT=$(load_and_render_safe "$TEMPLATE_DIR" "codex/commit-history-section.md" "FALLBACK" \
    "COMMIT_HISTORY=$COMMIT_HISTORY" \
    "RECENT_ROUND_FILES=$RECENT_ROUND_FILES")

HAS_COMMITS=true
HAS_ROUNDS=true

echo "$RESULT" | grep -q "feat: add feature 1" || HAS_COMMITS=false
echo "$RESULT" | grep -q "feat: add feature 2" || HAS_COMMITS=false
echo "$RESULT" | grep -q "fix: resolve bug in feature 1" || HAS_COMMITS=false

echo "$RESULT" | grep -q "round-2-summary.md" || HAS_ROUNDS=false
echo "$RESULT" | grep -q "round-1-summary.md" || HAS_ROUNDS=false
echo "$RESULT" | grep -q "round-0-summary.md" || HAS_ROUNDS=false
echo "$RESULT" | grep -q "round-2-review-result.md" || HAS_ROUNDS=false

if [[ "$HAS_COMMITS" == "true" ]]; then
    pass "Round 3 shows all 3 commits"
else
    fail "Round 3 commits" "3 commit messages" "$RESULT"
fi

if [[ "$HAS_ROUNDS" == "true" ]]; then
    pass "Round 3 shows round 0-2 file references"
else
    fail "Round 3 round files" "round-0/1/2 summary and review files" "$RESULT"
fi

# ========================================
# 测试 3：损坏的 BASE_COMMIT - 不存在的对象
# ========================================
echo ""
echo "Test 3: Corrupted BASE_COMMIT graceful fallback"

BAD_COMMIT="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

# 模拟停止钩子中的确切逻辑（merge-base --is-ancestor）
if [[ -n "$BAD_COMMIT" ]] && git -C "$TEST_DIR/repo" merge-base --is-ancestor "$BAD_COMMIT" HEAD 2>/dev/null; then
    COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse "$BAD_COMMIT"..HEAD 2>/dev/null | tail -80)
else
    COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse -30 2>/dev/null)
    [[ -n "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(base commit unavailable, showing recent branch commits)
${COMMIT_HISTORY}"
fi
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

if echo "$COMMIT_HISTORY" | grep -q "base commit unavailable"; then
    pass "Corrupted BASE_COMMIT triggers annotation"
else
    fail "Corrupted BASE_COMMIT annotation" "base commit unavailable" "$COMMIT_HISTORY"
fi

if echo "$COMMIT_HISTORY" | grep -q "feat: add feature"; then
    pass "Corrupted BASE_COMMIT still shows recent commits"
else
    fail "Corrupted BASE_COMMIT recent commits" "recent branch commits" "$COMMIT_HISTORY"
fi

# 验证没有崩溃（我们到达这里 = 没有 set -e 崩溃）
pass "Corrupted BASE_COMMIT did not crash (set -e safe)"

# ========================================
# 测试 3b：有效但无关的提交（不是 HEAD 的祖先）
# ========================================
echo ""
echo "Test 3b: Valid but unrelated BASE_COMMIT (orphan branch)"

# 创建一个带有自己提交的孤儿分支，然后切换回来
cd "$TEST_DIR/repo"
ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git checkout -q --orphan orphan-test
echo "orphan" > orphan.txt && git add orphan.txt && git commit -q -m "orphan commit"
ORPHAN_COMMIT=$(git rev-parse HEAD)
git checkout -q "$ORIG_BRANCH"
cd - > /dev/null

# ORPHAN_COMMIT 存在但不是 HEAD 的祖先
if [[ -n "$ORPHAN_COMMIT" ]] && git -C "$TEST_DIR/repo" merge-base --is-ancestor "$ORPHAN_COMMIT" HEAD 2>/dev/null; then
    COMMIT_HISTORY="should not reach here"
else
    COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse -30 2>/dev/null)
    [[ -n "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(base commit unavailable, showing recent branch commits)
${COMMIT_HISTORY}"
fi
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

if echo "$COMMIT_HISTORY" | grep -q "base commit unavailable"; then
    pass "Unrelated valid commit triggers annotation"
else
    fail "Unrelated valid commit annotation" "base commit unavailable" "$COMMIT_HISTORY"
fi

# ========================================
# 测试 4：模板缺失 - 回退渲染完整部分
# ========================================
echo ""
echo "Test 4: Missing template fallback renders full section"

CURRENT_ROUND=2
COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse "$BASE_COMMIT"..HEAD 2>/dev/null | tail -80)

RECENT_ROUND_FILES=""
for (( r = CURRENT_ROUND - 1; r >= 0 && r >= CURRENT_ROUND - 3; r-- )); do
    RECENT_ROUND_FILES+="- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-summary.md
- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-review-result.md
"
done

# 使用停止钩子中的确切回退格式
COMMIT_HISTORY_SECTION_FALLBACK="## Development History (Integral Context)
\`\`\`
${COMMIT_HISTORY}
\`\`\`
### Recent Round Files
Read these files before conducting your review to understand the trajectory of work:
${RECENT_ROUND_FILES}"

# 指向不存在的模板以强制回退
RESULT=$(load_and_render_safe "$TEMPLATE_DIR" "codex/non-existent-template.md" "$COMMIT_HISTORY_SECTION_FALLBACK" \
    "COMMIT_HISTORY=$COMMIT_HISTORY" \
    "RECENT_ROUND_FILES=$RECENT_ROUND_FILES")

FALLBACK_OK=true
echo "$RESULT" | grep -q "Development History" || FALLBACK_OK=false
echo "$RESULT" | grep -q "feat: add feature 1" || FALLBACK_OK=false
echo "$RESULT" | grep -q "Recent Round Files" || FALLBACK_OK=false
echo "$RESULT" | grep -q "round-1-summary.md" || FALLBACK_OK=false
echo "$RESULT" | grep -q "round-0-review-result.md" || FALLBACK_OK=false
echo "$RESULT" | grep -q "Read these files" || FALLBACK_OK=false

if [[ "$FALLBACK_OK" == "true" ]]; then
    pass "Fallback renders full section with commits, round files, and directive"
else
    fail "Fallback full section" "commits + round files + directive" "$RESULT"
fi

# ========================================
# 测试 5：第 1 轮 - 仅 1 个先前轮次（边界）
# ========================================
echo ""
echo "Test 5: Round 1 - only 1 prior round"

CURRENT_ROUND=1
RECENT_ROUND_FILES=""
for (( r = CURRENT_ROUND - 1; r >= 0 && r >= CURRENT_ROUND - 3; r-- )); do
    RECENT_ROUND_FILES+="- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-summary.md
- @.humanize/rlcr/${LOOP_TIMESTAMP}/round-${r}-review-result.md
"
done
[[ -z "$RECENT_ROUND_FILES" ]] && RECENT_ROUND_FILES="(first round, no prior history)"

if echo "$RECENT_ROUND_FILES" | grep -q "round-0-summary.md" && \
   ! echo "$RECENT_ROUND_FILES" | grep -q "round-1-"; then
    pass "Round 1 references only round 0"
else
    fail "Round 1 boundary" "only round-0 references" "$RECENT_ROUND_FILES"
fi

# ========================================
# 测试 6：空的 BASE_COMMIT（旧版循环）
# ========================================
echo ""
echo "Test 6: Empty BASE_COMMIT fallback"

EMPTY_BASE=""
if [[ -n "$EMPTY_BASE" ]] && git -C "$TEST_DIR/repo" merge-base --is-ancestor "$EMPTY_BASE" HEAD 2>/dev/null; then
    COMMIT_HISTORY="should not reach here"
else
    COMMIT_HISTORY=$(git -C "$TEST_DIR/repo" log --oneline --no-decorate --reverse -30 2>/dev/null)
    [[ -n "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(base commit unavailable, showing recent branch commits)
${COMMIT_HISTORY}"
fi
[[ -z "$COMMIT_HISTORY" ]] && COMMIT_HISTORY="(no commits yet)"

if echo "$COMMIT_HISTORY" | grep -q "base commit unavailable"; then
    pass "Empty BASE_COMMIT triggers annotation"
else
    fail "Empty BASE_COMMIT annotation" "base commit unavailable" "$COMMIT_HISTORY"
fi

# ========================================
# 摘要
# ========================================
print_test_summary "Commit History Section (I Component) Tests"
