#!/usr/bin/env bash
#
# explore-idea 清单和运行状态结构的测试。
#
# 验证 commands/explore-idea.md 中描述的 manifest.json 模式
# 和运行目录结构，以及 worker-results.jsonl 契约。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

EXPLORE_CMD="$PROJECT_ROOT/commands/explore-idea.md"
WORKER_PROMPT="$PROJECT_ROOT/prompt-template/explore/worker-prompt.md"
REPORT_TEMPLATE="$PROJECT_ROOT/prompt-template/explore/report-template.md"
VALIDATE_IO_SCRIPT="$PROJECT_ROOT/scripts/validate-explore-idea-io.sh"

echo "=========================================="
echo "explore-idea Manifest and Run State Tests"
echo "=========================================="
echo ""

echo "--- File Existence ---"
echo ""

# 所有必需文件存在
for f in "$EXPLORE_CMD" "$WORKER_PROMPT" "$REPORT_TEMPLATE"; do
    if [[ -f "$f" ]]; then
        pass "file exists: $(basename "$f")"
    else
        fail "file exists: $(basename "$f")" "file found" "not found"
    fi
done

FINAL_IDEA_TEMPLATE="$PROJECT_ROOT/prompt-template/explore/final-idea-template.md"
if [[ -f "$FINAL_IDEA_TEMPLATE" ]]; then
    pass "file exists: final-idea-template.md"
else
    fail "file exists: final-idea-template.md" "file found" "not found"
fi

echo ""
echo "--- Manifest JSON Schema (from explore-idea.md) ---"
echo ""

# 命令中提到的 manifest.json 字段
MANIFEST_FIELDS=(
    "run_id"
    "created_at"
    "directions_json_file"
    "draft_path"
    "selected_direction_ids"
    "base_branch"
    "base_commit"
    "concurrency"
    "max_worker_iterations"
    "worker_timeout_min"
    "codex_timeout_min"
    "codex_review_model"
    "codex_review_effort"
    "report_path"
    "final_idea_path"
    "expected_worker_count"
    "runtime_spike_status"
    "workers"
)

for field in "${MANIFEST_FIELDS[@]}"; do
    if grep -q "\"$field\"" "$EXPLORE_CMD"; then
        pass "manifest.json field documented: $field"
    else
        fail "manifest.json field documented: $field" "\"$field\" in explore-idea.md" "not found"
    fi
done

echo ""
echo "--- Per-Worker Manifest Entry ---"
echo ""

WORKER_FIELDS=(
    "direction_id"
    "dir_slug"
    "prompt_path"
    "prompt_hash"
    "branch_name"
    "status"
)

for field in "${WORKER_FIELDS[@]}"; do
    if grep -q "\"$field\"" "$EXPLORE_CMD"; then
        pass "per-worker manifest entry documents: $field"
    else
        fail "per-worker manifest entry documents: $field" "\"$field\"" "not found"
    fi
done

echo ""
echo "--- Run Directory Structure ---"
echo ""

# 运行目录路径模式（在验证脚本中定义，在命令中引用为 <RUN_DIR>）
if grep -q "\.humanize/explore/" "$VALIDATE_IO_SCRIPT"; then
    pass "run directory is under .humanize/explore/ (validate-explore-idea-io.sh)"
else
    fail "run directory under .humanize/explore/" ".humanize/explore/" "not found"
fi

# dispatch-prompts 子目录
if grep -q "dispatch-prompts" "$EXPLORE_CMD"; then
    pass "dispatch-prompts/ subdirectory documented"
else
    fail "dispatch-prompts/ subdirectory documented"
fi

# worker-results.jsonl 文件
if grep -q "worker-results.jsonl" "$EXPLORE_CMD"; then
    pass "worker-results.jsonl 文件已记录"
else
    fail "worker-results.jsonl file documented"
fi

# explore-report.md 文件
if grep -q "explore-report.md" "$EXPLORE_CMD"; then
    pass "explore-report.md file documented"
else
    fail "explore-report.md file documented"
fi

# final-idea.md 文件
if grep -q "final-idea.md" "$EXPLORE_CMD"; then
    pass "final-idea.md file documented"
else
    fail "final-idea.md file documented"
fi

# .failed 哨兵文件
if grep -q "\.failed" "$EXPLORE_CMD"; then
    pass ".failed sentinel file documented for error recovery"
else
    fail ".failed sentinel file documented"
fi

echo ""
echo "--- worker-results.jsonl Schema ---"
echo ""

# worker-results.jsonl 字段
JSONL_FIELDS=(
    "schema_version"
    "run_id"
    "direction_id"
    "task_status"
    "codex_final_verdict"
    "tests_passed"
    "tests_failed"
    "branch_name"
    "commit_sha"
    "commit_status"
    "summary_markdown"
)

for field in "${JSONL_FIELDS[@]}"; do
    if grep -q "\"$field\"" "$EXPLORE_CMD"; then
        pass "worker-results.jsonl schema documents: $field"
    else
        fail "worker-results.jsonl schema documents: $field" "\"$field\"" "not found"
    fi
done

echo ""
echo "--- manifest.json Write Order ---"
echo ""

# manifest.json 必须在调度前写入
if grep -q "BEFORE" "$EXPLORE_CMD" && grep -q "manifest" "$EXPLORE_CMD"; then
    pass "command requires manifest.json written BEFORE dispatch"
else
    fail "command requires manifest.json written BEFORE dispatch"
fi

# 报告模板包含必需的部分
if grep -q "Tier 1" "$REPORT_TEMPLATE" && grep -q "Tier 2" "$REPORT_TEMPLATE"; then
    pass "report template contains two-tier ranking sections"
else
    fail "report template contains Tier 1 and Tier 2 sections"
fi

FINAL_IDEA_SECTIONS=(
    "Final Recommendation"
    "Rationale"
    "Approach Summary"
    "Objective Evidence"
    "Explore Outcomes"
    "Constraints"
    "Known Risks"
    "Cross-Direction Learnings"
)

if [[ -f "$FINAL_IDEA_TEMPLATE" ]]; then
    ALL_FINAL_SECTIONS_PRESENT=true
    for section in "${FINAL_IDEA_SECTIONS[@]}"; do
        if ! grep -q "$section" "$FINAL_IDEA_TEMPLATE"; then
            ALL_FINAL_SECTIONS_PRESENT=false
            fail "final-idea template contains section: $section"
            break
        fi
    done
    if [[ "$ALL_FINAL_SECTIONS_PRESENT" == "true" ]]; then
        pass "final-idea template contains plan-ready synthesis sections"
    fi
fi

echo ""
print_test_summary "explore-idea Manifest and Run State Test Summary"
