#!/usr/bin/env bash
#
# explore-idea worker 结果契约的测试。
#
# 验证 worker 提示模板的结构契约：
#   - 模板文件存在
#   - 包含结果哨兵标记
#   - 包含必需的占位符变量
#   - 包含必需的结果 JSON 字段
#   - 硬约束存在
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

WORKER_PROMPT="$PROJECT_ROOT/prompt-template/explore/worker-prompt.md"

echo "=========================================="
echo "Worker Result Contract Tests"
echo "=========================================="
echo ""

echo "--- 模板存在性 ---"
echo ""

# 模板文件存在
if [[ -f "$WORKER_PROMPT" ]]; then
    pass "worker-prompt.md template exists"
else
    fail "worker-prompt.md template exists" "file found" "not found"
fi

echo ""
echo "--- 哨兵标记 ---"
echo ""

# 结果哨兵开始标记
if grep -q "=== EXPLORE_RESULT_JSON_BEGIN ===" "$WORKER_PROMPT"; then
    pass "template contains EXPLORE_RESULT_JSON_BEGIN sentinel"
else
    fail "template contains EXPLORE_RESULT_JSON_BEGIN sentinel"
fi

# 结果哨兵结束标记
if grep -q "=== EXPLORE_RESULT_JSON_END ===" "$WORKER_PROMPT"; then
    pass "template contains EXPLORE_RESULT_JSON_END sentinel"
else
    fail "template contains EXPLORE_RESULT_JSON_END sentinel"
fi

# 哨兵按正确顺序出现（BEGIN 在 END 之前）
BEGIN_LINE=$(grep -n "=== EXPLORE_RESULT_JSON_BEGIN ===" "$WORKER_PROMPT" | head -1 | cut -d: -f1)
END_LINE=$(grep -n "=== EXPLORE_RESULT_JSON_END ===" "$WORKER_PROMPT" | head -1 | cut -d: -f1)
if [[ -n "$BEGIN_LINE" && -n "$END_LINE" && "$BEGIN_LINE" -lt "$END_LINE" ]]; then
    pass "EXPLORE_RESULT_JSON_BEGIN appears before EXPLORE_RESULT_JSON_END"
else
    fail "EXPLORE_RESULT_JSON_BEGIN before END" "begin < end" "begin=$BEGIN_LINE end=$END_LINE"
fi

echo ""
echo "--- 占位符变量 ---"
echo ""

REQUIRED_PLACEHOLDERS=(
    "<RUN_ID>"
    "<DIRECTION_ID>"
    "<DIR_SLUG>"
    "<DIRECTION_NAME>"
    "<DIRECTION_RATIONALE>"
    "<APPROACH_SUMMARY>"
    "<OBJECTIVE_EVIDENCE>"
    "<KNOWN_RISKS>"
    "<CONFIDENCE>"
    "<MAX_WORKER_ITERATIONS>"
    "<CODEX_TIMEOUT_MIN>"
    "<CODEX_REVIEW_MODEL_SPEC>"
    "<BASE_BRANCH>"
    "<BASE_COMMIT>"
    "<ORIGINAL_IDEA>"
)

for placeholder in "${REQUIRED_PLACEHOLDERS[@]}"; do
    if grep -q "$placeholder" "$WORKER_PROMPT"; then
        pass "template contains placeholder $placeholder"
    else
        fail "template contains placeholder $placeholder" "$placeholder in template" "not found"
    fi
done

echo ""
echo "--- 结果 JSON 字段 ---"
echo ""

# 必需的结果 JSON 字段
REQUIRED_FIELDS=(
    "schema_version"
    "run_id"
    "direction_id"
    "dir_slug"
    "task_status"
    "codex_review_model"
    "codex_review_effort"
    "codex_review_metadata_path"
    "codex_final_verdict"
    "rounds_used"
    "tests_passed"
    "tests_failed"
    "worktree_path"
    "branch_name"
    "commit_sha"
    "commit_count"
    "dirty_state"
    "commit_status"
    "summary_markdown"
    "what_worked"
    "what_didnt"
    "bitlesson_action"
    "error"
)

for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "\"$field\"" "$WORKER_PROMPT"; then
        pass "result JSON contains field: $field"
    else
        fail "result JSON contains field: $field" "\"$field\" in template" "not found"
    fi
done

echo ""
echo "--- 硬约束 ---"
echo ""

# 硬约束部分
if grep -q "Hard Constraints" "$WORKER_PROMPT"; then
    pass "template has Hard Constraints section"
else
    fail "template has Hard Constraints section"
fi

CONSTRAINTS_LINE=$(grep -n "^## Hard Constraints" "$WORKER_PROMPT" | head -1 | cut -d: -f1)
DIRECTION_DATA_LINE=$(grep -n "^## Direction Data" "$WORKER_PROMPT" | head -1 | cut -d: -f1)
if [[ -n "$CONSTRAINTS_LINE" && -n "$DIRECTION_DATA_LINE" && "$CONSTRAINTS_LINE" -lt "$DIRECTION_DATA_LINE" ]] \
        && grep -qi "untrusted" "$WORKER_PROMPT"; then
    pass "hard constraints appear before untrusted direction data"
else
    fail "hard constraints appear before untrusted direction data" \
        "Hard Constraints before Direction Data with untrusted-data warning" \
        "constraints_line=$CONSTRAINTS_LINE direction_data_line=$DIRECTION_DATA_LINE"
fi

if ! sed -n '/```bash/,/```/p' "$WORKER_PROMPT" | grep -q "<DIRECTION_NAME>"; then
    pass "bash snippets avoid untrusted DIRECTION_NAME interpolation"
else
    fail "bash snippets avoid untrusted DIRECTION_NAME interpolation" \
        "no <DIRECTION_NAME> inside bash code fences" \
        "found"
fi

# 无嵌套技能约束
if grep -q "nested Skills" "$WORKER_PROMPT" || grep -q "No nested" "$WORKER_PROMPT"; then
    pass "template forbids nested skills/slash commands"
else
    fail "template forbids nested skills/slash commands"
fi

# 无 git push 约束：要求明确禁止的措辞，而非附带提及命令。
if grep -q "No git push" "$WORKER_PROMPT" && grep -qi "Do not push .*remote" "$WORKER_PROMPT"; then
    pass "template forbids git push"
else
    fail "template forbids git push" "explicit no-push phrasing" "missing"
fi

# ask-codex.sh 范围约束
if grep -q "CLAUDE_PROJECT_DIR" "$WORKER_PROMPT"; then
    pass "template requires CLAUDE_PROJECT_DIR scoping for Codex calls"
else
    fail "template requires CLAUDE_PROJECT_DIR scoping"
fi

# 显式审查模型占位符，不在测试中固定确切模型。
if grep -q -- '--codex-model "<CODEX_REVIEW_MODEL_SPEC>"' "$WORKER_PROMPT"; then
    pass "template uses explicit CODEX_REVIEW_MODEL_SPEC placeholder for Codex review"
else
    fail "template uses explicit CODEX_REVIEW_MODEL_SPEC placeholder" \
        '--codex-model "<CODEX_REVIEW_MODEL_SPEC>"' \
        "missing"
fi

# 分支命名格式
if grep -q "explore/<RUN_ID>/<DIR_SLUG>" "$WORKER_PROMPT"; then
    pass "template enforces branch naming format explore/<RUN_ID>/<DIR_SLUG>"
else
    fail "template enforces branch naming format" "explore/<RUN_ID>/<DIR_SLUG>" "not found"
fi

echo ""
print_test_summary "Worker Result Contract Test Summary"
