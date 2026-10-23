#!/usr/bin/env bash
#
# 统一 codex_model/codex_effort 配置的测试
#
# 验证：
# - default_config.json 包含 codex_model/codex_effort（非 loop_reviewer_*）
# - 配置加载器通过 4 层合并层次结构公开 codex 键
# - loop-common.sh 加载配置支持的 DEFAULT_CODEX_MODEL/DEFAULT_CODEX_EFFORT
# - 停止钩子使用 STATE_CODEX_* -> DEFAULT_CODEX_* 回退链
# - 设置脚本不向 state.md 写入 loop_reviewer_* 字段
# - 配置/状态中的过期 loop_reviewer_* 键被静默忽略
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$PROJECT_ROOT/scripts/portable-timeout.sh"

# 辅助函数：assert_eq DESCRIPTION EXPECTED ACTUAL
# 基于字符串相等性调用 pass/fail
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc" "$expected" "$actual"
    fi
}

# 辅助函数：assert_grep DESCRIPTION PATTERN FILE
# 如果在 FILE 中找到 PATTERN 则通过
assert_grep() {
    local desc="$1" pattern="$2" file="$3"
    if grep -q "$pattern" "$file"; then pass "$desc"; else fail "$desc"; fi
}

# 辅助函数：assert_no_grep DESCRIPTION PATTERN FILE_OR_STRING
# 如果在 FILE_OR_STRING 中未找到 PATTERN 则通过
assert_no_grep() {
    local desc="$1" pattern="$2" file="$3"
    if grep -q "$pattern" "$file"; then fail "$desc"; else pass "$desc"; fi
}

# 辅助函数：assert_contains DESCRIPTION PATTERN STRING
# 如果在 STRING 中找到 PATTERN 则通过
assert_contains() {
    local desc="$1" pattern="$2" text="$3"
    if grep -q -- "$pattern" <<< "$text"; then pass "$desc"; else fail "$desc"; fi
}

echo "=========================================="
echo "Unified Codex Config Tests"
echo "=========================================="
echo ""

# ========================================
# default_config.json 包含 codex 键（非 reviewer 键）
# ========================================

echo "--- default_config.json keys ---"

DEFAULT_CONFIG="$PROJECT_ROOT/config/default_config.json"

if ! command -v jq >/dev/null 2>&1; then
    skip "default config tests require jq" "jq not found"
else
    assert_eq "default_config.json: codex_model is gpt-5.5" \
        "gpt-5.5" "$(jq -r '.codex_model' "$DEFAULT_CONFIG")"

    assert_eq "default_config.json: codex_effort is high" \
        "high" "$(jq -r '.codex_effort' "$DEFAULT_CONFIG")"

    # 验证 reviewer 键不存在
    assert_eq "default_config.json: loop_reviewer_model is absent" \
        "ABSENT" "$(jq -r '.loop_reviewer_model // "ABSENT"' "$DEFAULT_CONFIG")"

    assert_eq "default_config.json: loop_reviewer_effort is absent" \
        "ABSENT" "$(jq -r '.loop_reviewer_effort // "ABSENT"' "$DEFAULT_CONFIG")"
fi

echo ""

# ========================================
# 配置合并层次结构加载 codex 键
# ========================================

echo "--- Config merge hierarchy ---"

CONFIG_LOADER="$PROJECT_ROOT/scripts/lib/config-loader.sh"
if [[ ! -f "$CONFIG_LOADER" ]]; then
    skip "config merge tests require config-loader.sh" "file not found"
else
    source "$CONFIG_LOADER"

    # 测试仅默认值（无项目覆盖）
    setup_test_dir
    PROJECT_DIR="$TEST_DIR/empty-project"
    mkdir -p "$PROJECT_DIR"

    merged=$(XDG_CONFIG_HOME="$TEST_DIR/no-user-config" load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null)

    assert_eq "default-only: codex_model defaults to gpt-5.5" \
        "gpt-5.5" "$(get_config_value "$merged" "codex_model")"

    assert_eq "default-only: codex_effort defaults to high" \
        "high" "$(get_config_value "$merged" "codex_effort")"

    # 测试项目配置覆盖
    setup_test_dir
    PROJECT_DIR="$TEST_DIR/project-override"
    mkdir -p "$PROJECT_DIR/.humanize"
    printf '{"codex_model": "gpt-5.2", "codex_effort": "xhigh"}' > "$PROJECT_DIR/.humanize/config.json"

    merged=$(XDG_CONFIG_HOME="$TEST_DIR/no-user-config2" load_merged_config "$PROJECT_ROOT" "$PROJECT_DIR" 2>/dev/null)

    assert_eq "project override: codex_model overrides default" \
        "gpt-5.2" "$(get_config_value "$merged" "codex_model")"

    assert_eq "project override: codex_effort overrides default" \
        "xhigh" "$(get_config_value "$merged" "codex_effort")"
fi

echo ""

# ========================================
# loop-common.sh 加载配置支持的默认值
# ========================================

echo "--- loop-common.sh config-backed defaults ---"

LOOP_COMMON="$PROJECT_ROOT/hooks/lib/loop-common.sh"

if [[ ! -f "$LOOP_COMMON" ]]; then
    skip "loop-common.sh tests require loop-common.sh" "file not found"
else
    # 测试默认值正确加载
    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        echo \"\$DEFAULT_CODEX_MODEL|\$DEFAULT_CODEX_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "loop-common.sh: DEFAULT_CODEX_MODEL is set" \
        "gpt-5.5" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "loop-common.sh: DEFAULT_CODEX_EFFORT is set" \
        "high" "$(echo "$result" | cut -d'|' -f2)"

    # 验证不存在 reviewer 常量或默认值
    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        echo \"\${FIELD_LOOP_REVIEWER_MODEL:-ABSENT}|\${DEFAULT_LOOP_REVIEWER_MODEL:-ABSENT}\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "loop-common.sh: FIELD_LOOP_REVIEWER_MODEL absent" \
        "ABSENT" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "loop-common.sh: DEFAULT_LOOP_REVIEWER_MODEL absent" \
        "ABSENT" "$(echo "$result" | cut -d'|' -f2)"

    # 测试配置覆盖输入到 DEFAULT_CODEX_MODEL
    setup_test_dir
    OVERRIDE_PROJECT="$TEST_DIR/override-project"
    mkdir -p "$OVERRIDE_PROJECT/.humanize"
    printf '{"codex_model": "o3-mini", "codex_effort": "low"}' > "$OVERRIDE_PROJECT/.humanize/config.json"

    result=$(bash -c "
        export CLAUDE_PROJECT_DIR='$OVERRIDE_PROJECT'
        export XDG_CONFIG_HOME='$TEST_DIR/no-user-config'
        source '$LOOP_COMMON' 2>/dev/null
        echo \"\$DEFAULT_CODEX_MODEL|\$DEFAULT_CODEX_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "config merge: project override feeds into DEFAULT_CODEX_MODEL" \
        "o3-mini" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "config merge: project override feeds into DEFAULT_CODEX_EFFORT" \
        "low" "$(echo "$result" | cut -d'|' -f2)"

    # 调用者提供的默认值必须继续覆盖配置值
    result=$(bash -c "
        export DEFAULT_CODEX_MODEL='preset-model'
        export DEFAULT_CODEX_EFFORT='medium'
        export CLAUDE_PROJECT_DIR='$OVERRIDE_PROJECT'
        export XDG_CONFIG_HOME='$TEST_DIR/no-user-config'
        source '$LOOP_COMMON' 2>/dev/null
        echo \"\$DEFAULT_CODEX_MODEL|\$DEFAULT_CODEX_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "caller preset: DEFAULT_CODEX_MODEL wins over config" \
        "preset-model" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "caller preset: DEFAULT_CODEX_EFFORT wins over config" \
        "medium" "$(echo "$result" | cut -d'|' -f2)"

    # 无效配置值应警告并回退到硬编码默认值
    setup_test_dir
    INVALID_PROJECT="$TEST_DIR/invalid-project"
    mkdir -p "$INVALID_PROJECT/.humanize"
    printf '{"codex_model": "haiku!", "codex_effort": "superhigh"}' > "$INVALID_PROJECT/.humanize/config.json"

    result=$(bash -c "
        export CLAUDE_PROJECT_DIR='$INVALID_PROJECT'
        export XDG_CONFIG_HOME='$TEST_DIR/no-user-config-invalid'
        source '$LOOP_COMMON'
        printf 'RESULT:%s|%s\n' \"\$DEFAULT_CODEX_MODEL\" \"\$DEFAULT_CODEX_EFFORT\"
    " 2>&1 || echo "ERROR")

    result_line="$(printf '%s\n' "$result" | grep '^RESULT:' | tail -n 1)"

    assert_eq "invalid config: codex_model falls back to gpt-5.5" \
        "gpt-5.5" "$(echo "$result_line" | cut -d':' -f2 | cut -d'|' -f1)"

    assert_eq "invalid config: codex_effort falls back to high" \
        "high" "$(echo "$result_line" | cut -d'|' -f2)"

    assert_contains "invalid config: warns on invalid codex_model" \
        "Warning: Invalid codex_model in merged config: haiku!" "$result"

    assert_contains "invalid config: warns on invalid codex_effort" \
        "Warning: Invalid codex_effort in merged config: superhigh" "$result"

    # Shell 安全但非 Codex 模型也应警告并回退
    for invalid_model in haiku false claude-3; do
        setup_test_dir
        INVALID_PROJECT="$TEST_DIR/invalid-model-project"
        mkdir -p "$INVALID_PROJECT/.humanize"
        printf '{"codex_model": "%s"}' "$invalid_model" > "$INVALID_PROJECT/.humanize/config.json"

        result=$(bash -c "
            export CLAUDE_PROJECT_DIR='$INVALID_PROJECT'
            export XDG_CONFIG_HOME='$TEST_DIR/no-user-config-invalid-model'
            source '$LOOP_COMMON'
            printf 'RESULT:%s|%s\n' \"\$DEFAULT_CODEX_MODEL\" \"\$DEFAULT_CODEX_EFFORT\"
        " 2>&1 || echo "ERROR")

        result_line="$(printf '%s\n' "$result" | grep '^RESULT:' | tail -n 1)"

        assert_eq "non-Codex config ($invalid_model): codex_model falls back to gpt-5.5" \
            "gpt-5.5" "$(echo "$result_line" | cut -d':' -f2 | cut -d'|' -f1)"

        assert_eq "non-Codex config ($invalid_model): codex_effort stays at high fallback" \
            "high" "$(echo "$result_line" | cut -d'|' -f2)"

        assert_contains "non-Codex config ($invalid_model): warns on unsupported codex_model" \
            "Warning: Unsupported codex_model in merged config: $invalid_model" "$result"
    done
fi

echo ""

# ========================================
# 停止钩子回退链：STATE_CODEX_* -> DEFAULT_CODEX_*
# ========================================

echo "--- Stop hook fallback chain ---"

if [[ ! -f "$LOOP_COMMON" ]]; then
    skip "stop hook fallback tests require loop-common.sh" "file not found"
else
    # 包含 codex 字段的状态 - 应直接使用它们
    setup_test_dir
    cat > "$TEST_DIR/codex-state.md" << 'STATE_EOF'
---
current_round: 1
max_iterations: 42
codex_model: gpt-5.2
codex_effort: xhigh
codex_timeout: 5400
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: feature
base_branch: main
base_commit: abc123
review_started: false
ask_codex_question: true
session_id: test
agent_teams: false
---
STATE_EOF

    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        parse_state_file '$TEST_DIR/codex-state.md'
        EXEC_MODEL=\"\${STATE_CODEX_MODEL:-\$DEFAULT_CODEX_MODEL}\"
        EXEC_EFFORT=\"\${STATE_CODEX_EFFORT:-\$DEFAULT_CODEX_EFFORT}\"
        echo \"\$EXEC_MODEL|\$EXEC_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "stop hook: codex model from state (gpt-5.2)" \
        "gpt-5.2" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "stop hook: codex effort from state (xhigh)" \
        "xhigh" "$(echo "$result" | cut -d'|' -f2)"

    # 裸状态（无 codex 字段）- 应回退到默认值
    setup_test_dir
    cat > "$TEST_DIR/bare-state.md" << 'BARE_EOF'
---
current_round: 0
max_iterations: 10
codex_timeout: 3600
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: feature
base_branch: main
base_commit: abc123
review_started: false
ask_codex_question: true
session_id: bare-session
agent_teams: false
---
BARE_EOF

    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        parse_state_file '$TEST_DIR/bare-state.md'
        EXEC_MODEL=\"\${STATE_CODEX_MODEL:-\$DEFAULT_CODEX_MODEL}\"
        EXEC_EFFORT=\"\${STATE_CODEX_EFFORT:-\$DEFAULT_CODEX_EFFORT}\"
        echo \"\$EXEC_MODEL|\$EXEC_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "bare state: falls back to DEFAULT_CODEX_MODEL (gpt-5.5)" \
        "gpt-5.5" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "bare state: falls back to DEFAULT_CODEX_EFFORT (high)" \
        "high" "$(echo "$result" | cut -d'|' -f2)"

    # 配置覆盖 + 裸状态：使用配置支持的默认值
    setup_test_dir
    OVERRIDE_PROJECT="$TEST_DIR/codex-override"
    mkdir -p "$OVERRIDE_PROJECT/.humanize"
    printf '{"codex_model": "o1-preview", "codex_effort": "medium"}' > "$OVERRIDE_PROJECT/.humanize/config.json"

    cat > "$TEST_DIR/cfg-bare-state.md" << 'CFG_BARE_EOF'
---
current_round: 0
max_iterations: 10
codex_timeout: 3600
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: feature
base_branch: main
base_commit: abc123
review_started: false
ask_codex_question: true
session_id: cfg-bare
agent_teams: false
---
CFG_BARE_EOF

    result=$(bash -c "
        export CLAUDE_PROJECT_DIR='$OVERRIDE_PROJECT'
        export XDG_CONFIG_HOME='$TEST_DIR/no-user-config'
        source '$LOOP_COMMON' 2>/dev/null
        parse_state_file '$TEST_DIR/cfg-bare-state.md'
        EXEC_MODEL=\"\${STATE_CODEX_MODEL:-\$DEFAULT_CODEX_MODEL}\"
        EXEC_EFFORT=\"\${STATE_CODEX_EFFORT:-\$DEFAULT_CODEX_EFFORT}\"
        echo \"\$EXEC_MODEL|\$EXEC_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "config override + bare state: codex model from config (o1-preview)" \
        "o1-preview" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "config override + bare state: codex effort from config (medium)" \
        "medium" "$(echo "$result" | cut -d'|' -f2)"
fi

echo ""

# ========================================
# 设置脚本不写入 reviewer 字段
# ========================================

echo "--- Setup script state.md template ---"

SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup-rlcr-loop.sh"

assert_no_grep "setup script: no loop_reviewer references" 'loop_reviewer' "$SETUP_SCRIPT"
assert_grep "setup script: state.md template includes codex_model" 'codex_model:' "$SETUP_SCRIPT"
assert_grep "setup script: state.md template includes codex_effort" 'codex_effort:' "$SETUP_SCRIPT"

echo ""

# ========================================
# 配置中的过期 loop_reviewer_* 键被静默忽略
# ========================================

echo "--- Stale config key handling ---"

if [[ ! -f "$LOOP_COMMON" ]]; then
    skip "stale key tests require loop-common.sh" "file not found"
else
    # 包含过期 reviewer 键的项目配置不应影响默认值
    setup_test_dir
    STALE_PROJECT="$TEST_DIR/stale-project"
    mkdir -p "$STALE_PROJECT/.humanize"
    printf '{"loop_reviewer_model": "o3-mini", "loop_reviewer_effort": "low", "codex_model": "gpt-5.3"}' > "$STALE_PROJECT/.humanize/config.json"

    result=$(bash -c "
        export CLAUDE_PROJECT_DIR='$STALE_PROJECT'
        export XDG_CONFIG_HOME='$TEST_DIR/no-user-config'
        source '$LOOP_COMMON' 2>/dev/null
        echo \"\$DEFAULT_CODEX_MODEL|\$DEFAULT_CODEX_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "stale config: codex_model from config (gpt-5.3), reviewer keys ignored" \
        "gpt-5.3" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "stale config: codex_effort from hardcoded fallback (high), reviewer keys ignored" \
        "high" "$(echo "$result" | cut -d'|' -f2)"

    # 包含过期 reviewer 字段的状态文件 - 解析器不应设置 STATE_LOOP_REVIEWER_*
    setup_test_dir
    cat > "$TEST_DIR/stale-state.md" << 'STALE_EOF'
---
current_round: 1
max_iterations: 42
codex_model: gpt-5.5
codex_effort: high
codex_timeout: 5400
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: feature
base_branch: main
base_commit: abc123
review_started: false
ask_codex_question: true
session_id: stale-test
agent_teams: false
loop_reviewer_model: gpt-5.2
loop_reviewer_effort: xhigh
---
STALE_EOF

    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        parse_state_file '$TEST_DIR/stale-state.md'
        echo \"\${STATE_LOOP_REVIEWER_MODEL:-ABSENT}|\${STATE_LOOP_REVIEWER_EFFORT:-ABSENT}\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "stale state: STATE_LOOP_REVIEWER_MODEL not parsed (ABSENT)" \
        "ABSENT" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "stale state: STATE_LOOP_REVIEWER_EFFORT not parsed (ABSENT)" \
        "ABSENT" "$(echo "$result" | cut -d'|' -f2)"

    # 验证 codex 字段仍从过期状态正确解析
    result=$(bash -c "
        source '$LOOP_COMMON' 2>/dev/null
        parse_state_file '$TEST_DIR/stale-state.md'
        echo \"\$STATE_CODEX_MODEL|\$STATE_CODEX_EFFORT\"
    " 2>/dev/null || echo "ERROR")

    assert_eq "stale state: STATE_CODEX_MODEL still parsed (gpt-5.5)" \
        "gpt-5.5" "$(echo "$result" | cut -d'|' -f1)"

    assert_eq "stale state: STATE_CODEX_EFFORT still parsed (high)" \
        "high" "$(echo "$result" | cut -d'|' -f2)"
fi

echo ""

# ========================================
# 停止钩子 effort 验证
# ========================================

echo "--- Stop-hook effort validation ---"

STOP_HOOK="$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh"

if [[ ! -f "$STOP_HOOK" ]]; then
    skip "stop-hook effort test requires stop hook" "file not found"
elif ! command -v jq >/dev/null 2>&1; then
    skip "stop-hook effort test requires jq" "jq not found"
else
    setup_test_dir
    HOOK_PROJECT="$TEST_DIR/hook-project"
    mkdir -p "$HOOK_PROJECT/.humanize/rlcr/2099-01-01_00-00-00"

    # 创建包含无效 codex effort 的 state.md
    cat > "$HOOK_PROJECT/.humanize/rlcr/2099-01-01_00-00-00/state.md" << 'HOOK_STATE_EOF'
---
current_round: 1
max_iterations: 10
codex_model: gpt-5.5
codex_effort: superhigh
codex_timeout: 3600
push_every_round: false
full_review_round: 5
plan_file: plan.md
plan_tracked: false
start_branch: main
base_branch: main
base_commit: abc123
review_started: false
ask_codex_question: false
session_id: hook-test
agent_teams: false
---
HOOK_STATE_EOF

    # 创建记录调用的存根 codex（应永远不会被调用）
    STUB_BIN="$TEST_DIR/stub-bin"
    mkdir -p "$STUB_BIN"
    cat > "$STUB_BIN/codex" << 'STUB_EOF'
#!/usr/bin/env bash
echo "CODEX_INVOKED" >> "$CODEX_INVOCATION_LOG"
exit 0
STUB_EOF
    chmod +x "$STUB_BIN/codex"

    CODEX_LOG="$TEST_DIR/codex-invocations.log"

    # 使用无效状态运行停止钩子
    hook_stderr=$(echo '{"session_id":"hook-test"}' | \
        CLAUDE_PROJECT_DIR="$HOOK_PROJECT" \
        CODEX_INVOCATION_LOG="$CODEX_LOG" \
        PATH="$STUB_BIN:$PATH" \
        bash "$STOP_HOOK" 2>&1 >/dev/null) || true

    # 断言：钩子报告了无效 effort 错误（现在是 "codex effort" 而非 "reviewer effort"）
    if echo "$hook_stderr" | grep -q "Invalid codex effort"; then
        pass "stop-hook behavioral: rejects 'superhigh' effort with error message"
    else
        fail "stop-hook behavioral: rejects 'superhigh' effort with error message" "contains 'Invalid codex effort'" "$hook_stderr"
    fi

    # 断言：codex 存根从未被调用
    if [[ ! -f "$CODEX_LOG" ]]; then
        pass "stop-hook behavioral: codex was not invoked for invalid effort"
    else
        fail "stop-hook behavioral: codex was not invoked for invalid effort" "no invocation log" "codex was called"
    fi
fi

echo ""

# ========================================
# 设置脚本执行测试
# ========================================

echo "--- Setup script execution test ---"

if ! command -v jq >/dev/null 2>&1; then
    skip "setup execution test requires jq" "jq not found"
elif ! command -v codex >/dev/null 2>&1; then
    skip "setup execution test requires codex" "codex not found"
else
    setup_test_dir
    EXEC_PROJECT="$TEST_DIR/exec-project"
    init_test_git_repo "$EXEC_PROJECT"
    # 确保存在 'master' 分支，使 --base-branch master 有效
    # （init_test_git_repo 可能根据 git 配置创建 'main'）
    (cd "$EXEC_PROJECT" && git branch master 2>/dev/null || true)

    # 创建包含 codex 覆盖的项目配置
    mkdir -p "$EXEC_PROJECT/.humanize"
    printf '{"codex_model": "gpt-5.2", "codex_effort": "low"}' > "$EXEC_PROJECT/.humanize/config.json"

    # 创建包含足够行数（最少 5 行）的计划文件并提交
    cat > "$EXEC_PROJECT/plan.md" << 'PLAN_EOF'
# Test Plan
## Goal
Test unified codex config
## Tasks
- Task 1: Add config keys
- Task 2: Wire through pipeline
PLAN_EOF
    (cd "$EXEC_PROJECT" && git add plan.md && git commit -q -m "Add plan")

    # 创建本地裸远程以防止网络调用
    BARE_REMOTE="$TEST_DIR/remote.git"
    git clone --bare "$EXEC_PROJECT" "$BARE_REMOTE" -q 2>/dev/null
    (cd "$EXEC_PROJECT" && git remote remove origin 2>/dev/null; git remote add origin "$BARE_REMOTE") 2>/dev/null || true

    # 使用 --codex-model 覆盖运行 setup-rlcr-loop.sh
    setup_exit=0
    output=$(cd "$EXEC_PROJECT" && CLAUDE_PROJECT_DIR="$EXEC_PROJECT" run_with_timeout 30 bash "$SETUP_SCRIPT" --codex-model gpt-5.3:xhigh --base-branch master --track-plan-file plan.md 2>&1) || setup_exit=$?

    assert_eq "setup execution: setup-rlcr-loop.sh exited successfully" \
        "0" "$setup_exit"

    # 查找生成的 state.md
    STATE_FILE=$(find "$EXEC_PROJECT/.humanize/rlcr" -name "state.md" 2>/dev/null | head -1 || true)
    if [[ -z "$STATE_FILE" ]]; then
        fail "setup execution: state.md was created" "non-empty path" "empty"
    else
        pass "setup execution: state.md was created"

        SUMMARY_FILE="$(dirname "$STATE_FILE")/round-0-summary.md"
        if [[ -f "$SUMMARY_FILE" ]]; then
            if grep -q '^## BitLesson Delta$' "$SUMMARY_FILE" && \
               grep -q '^Action: none$' "$SUMMARY_FILE"; then
                pass "setup execution: round-0 summary scaffold includes BitLesson Delta defaults"
            else
                fail "setup execution: round-0 summary scaffold includes BitLesson Delta defaults" \
                    "BitLesson Delta scaffold" \
                    "$(cat "$SUMMARY_FILE")"
            fi
        else
            fail "setup execution: round-0 summary scaffold was created" \
                "round-0-summary.md exists" \
                "not found"
        fi

        # 验证来自 --codex-model 标志的 codex_model
        assert_eq "setup execution: --codex-model set codex_model (gpt-5.3)" \
            "gpt-5.3" "$(grep '^codex_model:' "$STATE_FILE" | sed 's/codex_model: *//')"

        assert_eq "setup execution: --codex-model set codex_effort (xhigh)" \
            "xhigh" "$(grep '^codex_effort:' "$STATE_FILE" | sed 's/codex_effort: *//')"

        assert_no_grep "setup execution: state.md does not contain loop_reviewer fields" \
            'loop_reviewer' "$STATE_FILE"
    fi

    # 验证输出不提及 "Reviewer Model" 或 "Reviewer Effort"
    if echo "$output" | grep -q 'Reviewer Model\|Reviewer Effort'; then
        fail "setup execution: output does not mention Reviewer Model/Effort"
    else
        pass "setup execution: output does not mention Reviewer Model/Effort"
    fi
fi

echo ""

# ========================================
# 输入验证仍然有效
# ========================================

echo "--- Input validation ---"

# 测试无效模型名（包含空格）- 直接测试验证正则表达式
model_with_spaces="gpt 5.5 bad"
if [[ ! "$model_with_spaces" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    pass "validation: model with spaces is rejected by regex"
else
    fail "validation: model with spaces is rejected by regex"
fi

model_with_shell="gpt-5.5;rm-rf"
if [[ ! "$model_with_shell" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    pass "validation: model with shell metacharacters is rejected"
else
    fail "validation: model with shell metacharacters is rejected"
fi

# 测试无效 effort 值
invalid_effort="superhigh"
if [[ ! "$invalid_effort" =~ ^(xhigh|high|medium|low)$ ]]; then
    pass "validation: invalid effort value is rejected by regex"
else
    fail "validation: invalid effort value is rejected by regex"
fi

# 测试有效 effort 值
for effort in xhigh high medium low; do
    if [[ "$effort" =~ ^(xhigh|high|medium|low)$ ]]; then
        pass "validation: effort '$effort' is accepted"
    else
        fail "validation: effort '$effort' is accepted"
    fi
done

echo ""

# ========================================
# ask-codex 遵循配置支持的默认值（AC-5）
# ========================================

echo "--- ask-codex config-backed defaults ---"

ASK_CODEX="$PROJECT_ROOT/scripts/ask-codex.sh"

if [[ ! -f "$ASK_CODEX" ]]; then
    skip "ask-codex config tests require ask-codex.sh" "file not found"
else
    # ask-codex 不预设 DEFAULT_CODEX_MODEL 或 DEFAULT_CODEX_EFFORT
    assert_no_grep "ask-codex.sh: does not pre-set DEFAULT_CODEX_MODEL" \
        'DEFAULT_CODEX_MODEL=' "$ASK_CODEX"

    assert_no_grep "ask-codex.sh: does not pre-set DEFAULT_CODEX_EFFORT" \
        'DEFAULT_CODEX_EFFORT=' "$ASK_CODEX"

    # ask-codex 使用来自 loop-common.sh 的 DEFAULT_CODEX_MODEL（配置支持）
    assert_grep "ask-codex.sh: assigns CODEX_MODEL from DEFAULT_CODEX_MODEL" \
        'CODEX_MODEL="\$DEFAULT_CODEX_MODEL"' "$ASK_CODEX"

    assert_grep "ask-codex.sh: assigns CODEX_EFFORT from DEFAULT_CODEX_EFFORT" \
        'CODEX_EFFORT="\$DEFAULT_CODEX_EFFORT"' "$ASK_CODEX"

    # 帮助文本提及配置支持的默认值
    assert_grep "ask-codex.sh: help text mentions config-backed default" \
        'default from config' "$ASK_CODEX"
fi

echo ""

# ========================================
# ask-codex 运行时行为测试
# ========================================

echo "--- ask-codex runtime behavioral ---"

if [[ ! -f "$ASK_CODEX" ]]; then
    skip "ask-codex runtime test requires ask-codex.sh" "file not found"
else
    setup_test_dir
    ASK_CFG_PROJECT="$TEST_DIR/ask-cfg-project"
    init_test_git_repo "$ASK_CFG_PROJECT"
    mkdir -p "$ASK_CFG_PROJECT/.humanize"
    printf '{"codex_model": "o3-mini", "codex_effort": "low"}' > "$ASK_CFG_PROJECT/.humanize/config.json"

    # 创建输出固定响应的模拟 codex
    MOCK_BIN="$TEST_DIR/mock-bin"
    mkdir -p "$MOCK_BIN"
    cat > "$MOCK_BIN/codex" << 'MOCK_EOF'
#!/usr/bin/env bash
echo "mock codex response"
exit 0
MOCK_EOF
    chmod +x "$MOCK_BIN/codex"

    # 使用配置支持的默认值（无 --codex-model 标志）运行 ask-codex
    ask_stderr=$(cd "$ASK_CFG_PROJECT" && \
        CLAUDE_PROJECT_DIR="$ASK_CFG_PROJECT" \
        XDG_CONFIG_HOME="$TEST_DIR/no-user-config" \
        PATH="$MOCK_BIN:$PATH" \
        run_with_timeout 30 bash "$ASK_CODEX" "test question" 2>&1 >/dev/null) || true

    # Stderr 应报告配置支持的模型和 effort
    if echo "$ask_stderr" | grep -q 'model=o3-mini'; then
        pass "ask-codex runtime: config-backed model reported in stderr (o3-mini)"
    else
        fail "ask-codex runtime: config-backed model reported in stderr (o3-mini)" "contains 'model=o3-mini'" "$ask_stderr"
    fi

    if echo "$ask_stderr" | grep -q 'effort=low'; then
        pass "ask-codex runtime: config-backed effort reported in stderr (low)"
    else
        fail "ask-codex runtime: config-backed effort reported in stderr (low)" "contains 'effort=low'" "$ask_stderr"
    fi

    # 使用 --codex-model 覆盖运行 ask-codex
    override_stderr=$(cd "$ASK_CFG_PROJECT" && \
        CLAUDE_PROJECT_DIR="$ASK_CFG_PROJECT" \
        XDG_CONFIG_HOME="$TEST_DIR/no-user-config" \
        PATH="$MOCK_BIN:$PATH" \
        run_with_timeout 30 bash "$ASK_CODEX" --codex-model override-model:xhigh "test question" 2>&1 >/dev/null) || true

    if echo "$override_stderr" | grep -q 'model=override-model'; then
        pass "ask-codex runtime: --codex-model override reported in stderr (override-model)"
    else
        fail "ask-codex runtime: --codex-model override reported in stderr (override-model)" "contains 'model=override-model'" "$override_stderr"
    fi

    if echo "$override_stderr" | grep -q 'effort=xhigh'; then
        pass "ask-codex runtime: --codex-model override effort in stderr (xhigh)"
    else
        fail "ask-codex runtime: --codex-model override effort in stderr (xhigh)" "contains 'effort=xhigh'" "$override_stderr"
    fi
fi

echo ""

# ========================================
# 总结
# ========================================

print_test_summary "Unified Codex Config Test Summary"
