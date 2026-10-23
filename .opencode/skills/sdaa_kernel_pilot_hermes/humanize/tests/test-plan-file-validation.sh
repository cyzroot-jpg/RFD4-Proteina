#!/usr/bin/env bash
#
# setup-rlcr-loop.sh 中计划文件验证的测试
#
# 测试：
# - 绝对路径拒绝
# - 项目内的相对路径
# - 符号链接拒绝
# - 子模块拒绝
# - Git 仓库验证
# - 计划文件跟踪状态验证
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 取消设置 CLAUDE_PROJECT_DIR 以便 setup-rlcr-loop.sh 使用 pwd（临时测试仓库）
# 而不是此测试运行的实际仓库根目录
unset CLAUDE_PROJECT_DIR

# 测试辅助函数
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; echo "  Expected: $2"; echo "  Got: $3"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1 - $2"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); }

# 设置测试环境
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

setup_test_repo() {
    cd "$TEST_DIR"

    # 仅在尚未初始化时初始化 git
    if [[ ! -d ".git" ]]; then
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        echo "initial" > init.txt
        git add init.txt
        git -c commit.gpgsign=false commit -q -m "Initial commit"

        # 创建测试计划文件
        mkdir -p plans
        cat > plans/test-plan.md << 'EOF'
# Test Plan

## Goal
Test the RLCR loop functionality

## Requirements
- Requirement 1
- Requirement 2
- Requirement 3
EOF

        # 将 plans/ 添加到 gitignore（默认行为）
        echo "plans/" >> .gitignore
        git add .gitignore
        git -c commit.gpgsign=false commit -q -m "Add gitignore"
    fi
}

# 模拟 codex 命令 - 始终使用模拟以避免调用真实 codex（速度慢）
mock_codex() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/codex" << 'EOF'
#!/usr/bin/env bash
# test-plan-file-validation.sh 的模拟 codex
echo "mock codex"
EOF
    chmod +x "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

echo "=== Test: Plan File Path Validation ==="
echo ""

# 测试 1：绝对路径应该失败
setup_test_repo
mock_codex

echo "Test 1: Reject absolute path"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "/absolute/path/plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "relative path"; then
    pass "Absolute path rejected"
else
    fail "Absolute path rejection" "exit 1 with relative path error" "$RESULT"
fi

# 测试 2：不存在的文件应该失败
echo "Test 2: Reject non-existent file"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "nonexistent.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "not found"; then
    pass "Non-existent file rejected"
else
    fail "Non-existent file rejection" "exit 1 with not found error" "$RESULT"
fi

# 测试 2.5：不存在的目录应该以清晰错误失败
echo "Test 2.5: Reject non-existent parent directory"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "nonexistent-dir/plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "directory not found"; then
    pass "Non-existent parent directory rejected with clear error"
else
    fail "Non-existent parent directory rejection" "exit 1 with directory not found error" "$RESULT"
fi

# 测试 2.6：带空格的路径应该失败
echo "Test 2.6: Reject path with spaces"
mkdir -p "$TEST_DIR/path with spaces"
cat > "$TEST_DIR/path with spaces/plan.md" << 'EOF'
# Plan
## Goal
Test spaces
## Requirements
- Requirement 1
- Requirement 2
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "path with spaces/plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "cannot contain spaces"; then
    pass "Path with spaces rejected"
else
    fail "Path with spaces rejection" "exit 1 with spaces error" "$RESULT"
fi

# 测试 2.7：带空格的文件名应该失败
echo "Test 2.7: Reject filename with spaces"
cat > "$TEST_DIR/plan with spaces.md" << 'EOF'
# Plan
## Goal
Test spaces
## Requirements
- Requirement 1
- Requirement 2
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plan with spaces.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "cannot contain spaces"; then
    pass "Filename with spaces rejected"
else
    fail "Filename with spaces rejection" "exit 1 with spaces error" "$RESULT"
fi

# 测试 2.8：带 shell 元字符的路径应该失败
echo "Test 2.8: Reject path with shell metacharacters"
cat > "$TEST_DIR/plans/test-plan.md" << 'EOF'
# Plan
## Goal
Test metacharacters
## Requirements
- Requirement 1
- Requirement 2
EOF
# 测试各种 shell 元字符
for meta_char in ';' '&' '|' '$' '`' '<' '>' '(' ')' '{' '}' '[' ']' '!' '#' '~' '*' '?'; do
    RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/test${meta_char}plan.md" 2>&1) || true
    if ! echo "$RESULT" | grep -q "shell metacharacters"; then
        fail "Shell metacharacter rejection ($meta_char)" "error mentioning metacharacters" "$RESULT"
        break
    fi
done
pass "Path with shell metacharacters rejected"

# 测试 3：符号链接应该失败
echo "Test 3: Reject symbolic link"
ln -sf plans/test-plan.md "$TEST_DIR/link-plan.md"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "link-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "symbolic link"; then
    pass "Symlink rejected"
else
    fail "Symlink rejection" "exit 1 with symbolic link error" "$RESULT"
fi

# Test 3.5: Path resolution error handling (Fix #4)
echo "Test 3.5: Handle path resolution errors gracefully"
# 创建一个 cd 可能失败的目录结构
mkdir -p "$TEST_DIR/permission-test"
cd "$TEST_DIR/permission-test"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
# 创建一个我们将使其不可访问的计划目录
mkdir -p plans
cat > plans/plan.md << 'EOF'
# Plan
## Goal
Test path resolution
## Requirements
- Requirement 1
- Requirement 2
EOF
echo "plans/" >> .gitignore
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Gitignore"
# 使 plans 目录不可读（如果我们有权限这样做）
if chmod 000 plans 2>/dev/null; then
    set +e
    RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/plan.md" 2>&1)
    EXIT_CODE=$?
    set -e
    # 恢复权限以便清理
    chmod 755 plans
    # 应该因目录访问的清晰错误而失败
    if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -qE "resolve|not found|directory"; then
        pass "Path resolution error handled gracefully"
    else
        fail "Path resolution error" "clear error message" "exit $EXIT_CODE, output: $RESULT"
    fi
else
    skip "Path resolution error" "cannot change permissions in test environment"
fi
cd "$TEST_DIR"

# 测试 4：项目外的计划（../ 逃逸）应该失败
echo "Test 4: Reject path escaping project directory"
mkdir -p "$TEST_DIR/outside"
cat > "$TEST_DIR/outside/escape-plan.md" << 'EOF'
# Escape Plan
## Goal
Test escape
## Requirements
- Requirement 1
- Requirement 2
EOF
mkdir -p "$TEST_DIR/project"
cd "$TEST_DIR/project"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "../outside/escape-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -qE "(within project|not found)"; then
    pass "Path escape rejected"
else
    fail "Path escape rejection" "exit 1 with project directory error" "$RESULT"
fi

# 测试 5：非 git 仓库应该失败
echo "Test 5: Reject non-git repository"
# 创建一个完全不在任何 git 仓库内的独立目录
NOGIT_DIR=$(mktemp -d)
cd "$NOGIT_DIR"
cat > plan.md << 'EOF'
# Plan
## Goal
Test non-git
## Requirements
- Requirement 1
- Requirement 2
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plan.md" 2>&1)
EXIT_CODE=$?
set -e
rm -rf "$NOGIT_DIR"
cd "$TEST_DIR"
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "git repository"; then
    pass "Non-git repo rejected"
else
    fail "Non-git repo rejection" "exit 1 with git repository error" "$RESULT"
fi

# 测试 6：没有提交的 git 仓库应该失败
echo "Test 6: Reject git repo without commits"
# 创建一个完全不在任何 git 仓库内的独立目录
NOCOMMIT_DIR=$(mktemp -d)
cd "$NOCOMMIT_DIR"
git init -q
cat > plan.md << 'EOF'
# Plan
## Goal
Test no commits
## Requirements
- Requirement 1
- Requirement 2
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plan.md" 2>&1)
EXIT_CODE=$?
set -e
rm -rf "$NOCOMMIT_DIR"
cd "$TEST_DIR"
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "at least one commit"; then
    pass "Git repo without commits rejected"
else
    fail "Git repo without commits rejection" "exit 1 with commit error" "$RESULT"
fi

echo ""
echo "=== Test: Plan File Tracking Validation ==="
echo ""

# 测试 7：没有 --track-plan-file 的跟踪文件应该失败
echo "Test 7: Reject tracked file without --track-plan-file"
cd "$TEST_DIR"
rm -rf tracked-test 2>/dev/null || true
mkdir -p tracked-test
cd tracked-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
cat > tracked-plan.md << 'EOF'
# Tracked Plan
## Goal
Test tracking
## Requirements
- Requirement 1
- Requirement 2
EOF
git add tracked-plan.md
git -c commit.gpgsign=false commit -q -m "Add plan"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "tracked-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "gitignored"; then
    pass "Tracked file without --track-plan-file rejected"
else
    fail "Tracked file rejection" "exit 1 with gitignored error" "$RESULT"
fi

# 测试 8：带 --track-plan-file 的未跟踪文件应该失败
echo "Test 8: Reject untracked file with --track-plan-file"
cd "$TEST_DIR"
rm -rf untracked-test 2>/dev/null || true
mkdir -p untracked-test
cd untracked-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
mkdir -p plans
cat > plans/untracked-plan.md << 'EOF'
# Untracked Plan
## Goal
Test untracked
## Requirements
- Requirement 1
- Requirement 2
EOF
echo "plans/" >> .gitignore
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Gitignore"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --track-plan-file "plans/untracked-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "tracked in git"; then
    pass "Untracked file with --track-plan-file rejected"
else
    fail "Untracked file with --track-plan-file rejection" "exit 1 with tracked error" "$RESULT"
fi

# 测试 9：带 --track-plan-file 的已修改跟踪文件应该失败
echo "Test 9: Reject modified tracked file with --track-plan-file"
cd "$TEST_DIR"
rm -rf modified-test 2>/dev/null || true
mkdir -p modified-test
cd modified-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
cat > modified-plan.md << 'EOF'
# Modified Plan
## Goal
Test modified
## Requirements
- Requirement 1
- Requirement 2
EOF
git add modified-plan.md
git -c commit.gpgsign=false commit -q -m "Add plan"
echo "# Extra line" >> modified-plan.md
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --track-plan-file "modified-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "clean"; then
    pass "Modified tracked file with --track-plan-file rejected"
else
    fail "Modified tracked file rejection" "exit 1 with clean error" "$RESULT"
fi

echo ""
echo "=== Test: Branch Name Validation ==="
echo ""

# 测试 9.5：拒绝带 YAML 不安全字符的分支名称（修复 #2）
# 注意：Git 本身可能会拒绝其中一些字符，这没问题
# 我们测试 git 拒绝它或我们的脚本拒绝它
echo "Test 9.5: Reject branch with colon (YAML-unsafe)"
cd "$TEST_DIR"
rm -rf branch-test 2>/dev/null || true
mkdir -p branch-test
cd branch-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
# 获取此仓库的默认分支名称（main 或 master）
BRANCH_TEST_DEFAULT=$(git rev-parse --abbrev-ref HEAD)
mkdir -p plans
cat > plans/plan.md << 'EOF'
# Plan
## Goal
Test branch validation
## Requirements
- Requirement 1
- Requirement 2
EOF
echo "plans/" >> .gitignore
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Gitignore"
# 尝试创建带冒号的分支（YAML 不安全）- git 可能会拒绝
if git checkout -q -b "feature:test" 2>/dev/null; then
    set +e
    RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/plan.md" 2>&1)
    EXIT_CODE=$?
    set -e
    if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "YAML-unsafe"; then
        pass "Branch with colon rejected"
    else
        fail "Branch with colon rejection" "exit 1 with YAML-unsafe error" "$RESULT"
    fi
    git checkout -q "$BRANCH_TEST_DEFAULT" 2>/dev/null || true
else
    # Git 本身拒绝了分支名称，这也没问题
    pass "Branch with colon rejected (by git)"
fi

# 测试 9.6：拒绝带井号的分支名称（YAML 注释）
echo "Test 9.6: Reject branch with hash (YAML comment)"
git checkout -q "$BRANCH_TEST_DEFAULT" 2>/dev/null || true
# 尝试创建带井号的分支 - 某些 git 版本可能不允许
if git checkout -q -b "test#comment" 2>/dev/null; then
    set +e
    RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/plan.md" 2>&1)
    EXIT_CODE=$?
    set -e
    if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "YAML-unsafe"; then
        pass "Branch with hash rejected"
    else
        fail "Branch with hash rejection" "exit 1 with YAML-unsafe error" "$RESULT"
    fi
    git checkout -q "$BRANCH_TEST_DEFAULT" 2>/dev/null || true
else
    pass "Branch with hash rejected (by git)"
fi

# 测试 9.7：拒绝带引号的分支名称
echo "Test 9.7: Reject branch with quotes (YAML-unsafe)"
git checkout -q "$BRANCH_TEST_DEFAULT" 2>/dev/null || true
if git checkout -q -b 'test"quote' 2>/dev/null; then
    set +e
    RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/plan.md" 2>&1)
    EXIT_CODE=$?
    set -e
    if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "YAML-unsafe"; then
        pass "Branch with quotes rejected"
    else
        fail "Branch with quotes rejection" "exit 1 with YAML-unsafe error" "$RESULT"
    fi
    git checkout -q "$BRANCH_TEST_DEFAULT" 2>/dev/null || true
else
    pass "Branch with quotes rejected (by git)"
fi

echo ""
echo "=== Test: Plan File Content Validation ==="
echo ""

# 测试 9.8：拒绝只有空行的计划文件
echo "Test 9.8: Reject plan with only blank lines"
cd "$TEST_DIR"
rm -rf content-test 2>/dev/null || true
mkdir -p content-test
cd content-test
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > init.txt
git add init.txt
git -c commit.gpgsign=false commit -q -m "Initial"
mkdir -p plans
# 创建只有空行的计划（总共 6 行以通过 5 行最小值）
printf '\n\n\n\n\n\n' > plans/blank-plan.md
echo "plans/" >> .gitignore
git add .gitignore
git -c commit.gpgsign=false commit -q -m "Gitignore"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/blank-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "insufficient content"; then
    pass "Plan with only blank lines rejected"
else
    fail "Blank plan rejection" "exit 1 with insufficient content error" "$RESULT"
fi

# 测试 9.9：拒绝只有很少非空行的计划文件
echo "Test 9.9: Reject plan with too few non-blank lines"
# 创建大部分为空行且只有 2 个非空行的计划
cat > plans/sparse-plan.md << 'EOF'
# Title


Only one more line


EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/sparse-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "insufficient content"; then
    pass "Plan with too few non-blank lines rejected"
else
    fail "Sparse plan rejection" "exit 1 with insufficient content error" "$RESULT"
fi

# 测试 9.9.1：拒绝只有 HTML 注释的计划文件
echo "Test 9.9.1: Reject plan with only HTML comments"
cat > plans/comment-plan.md << 'EOF'
<!-- HTML comment line 1 -->
<!-- HTML comment line 2 -->


<!-- HTML comment line 3 -->
<!--
Multi-line HTML comment
that spans multiple lines
-->
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/comment-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "insufficient content"; then
    pass "Plan with only HTML comments rejected"
else
    fail "HTML-comment-only plan rejection" "exit 1 with insufficient content error" "$RESULT"
fi

# 测试 9.9.2：拒绝只有 shell/markdown 注释（# 行）的计划文件
echo "Test 9.9.2: Reject plan with only # comments"
cat > plans/hash-comment-plan.md << 'EOF'
# This is a comment line 1
# This is a comment line 2
# This is a comment line 3
# This is a comment line 4
# This is a comment line 5
# This is a comment line 6
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/hash-comment-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "insufficient content"; then
    pass "Plan with only # comments rejected"
else
    fail "#-comment-only plan rejection" "exit 1 with insufficient content error" "$RESULT"
fi

# 测试 9.10：接受有足够非空内容的计划
# 注意：以 # 开头的行被视为注释，所以我们使用纯文本
echo "Test 9.10: Accept plan with sufficient non-blank content"
cat > plans/good-plan.md << 'EOF'
Good Plan

Goal
This is a valid plan file with enough content.

Requirements
- Requirement 1
- Requirement 2

Implementation
Details here.
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/good-plan.md" 2>&1)
EXIT_CODE=$?
set -e
# 不应该因内容验证而失败（可能因其他原因如 codex 而失败）
if ! echo "$RESULT" | grep -q "insufficient content"; then
    pass "Valid plan with sufficient content accepted"
else
    fail "Valid plan acceptance" "no insufficient content error" "$RESULT"
fi

# 测试 9.10.1：接受带单行 HTML 注释和有效内容的计划
# 回归测试：单行 HTML 注释不应触发多行注释模式
echo "Test 9.10.1: Accept plan with single-line HTML comments + valid content"
cat > plans/single-line-html-comment-plan.md << 'EOF'
<!-- This is a single-line HTML comment -->
This plan has real content

Goal
The goal is to test single-line comment handling.

Requirements
- Requirement 1
- Requirement 2
- Requirement 3
EOF
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" "plans/single-line-html-comment-plan.md" 2>&1)
EXIT_CODE=$?
set -e
# 不应该因内容验证而失败 - 单行注释应该被正确跳过
if ! echo "$RESULT" | grep -q "insufficient content"; then
    pass "Plan with single-line HTML comments + valid content accepted"
else
    fail "Single-line HTML comment handling" "no insufficient content error" "$RESULT"
fi

echo ""
echo "=== Test: CLI Options ==="
echo ""

# Test 10: --plan-file option works
echo "Test 10: --plan-file option"
cd "$TEST_DIR"
setup_test_repo
mock_codex
set +e
# 这应该失败验证（不实际运行），但通过 CLI 解析
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --plan-file "plans/test-plan.md" 2>&1)
EXIT_CODE=$?
set -e
# 应该通过 CLI 解析 - 要么运行要么在某些验证上失败
if ! echo "$RESULT" | grep -q "requires a file path"; then
    pass "--plan-file option accepted"
else
    fail "--plan-file option" "option accepted" "$RESULT"
fi

# 测试 11：同时使用 --plan-file 和位置参数应该失败
echo "Test 11: Reject both --plan-file and positional"
rm -rf "$TEST_DIR/.humanize/rlcr" 2>/dev/null || true
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --plan-file "plans/a.md" "plans/b.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "Cannot specify both"; then
    pass "Both --plan-file and positional rejected"
else
    fail "Both options rejection" "exit 1 with both error" "$RESULT"
fi

echo ""
echo "=== Test: Codex Parameter Validation ==="
echo ""

# 测试 12：拒绝带 YAML 不安全字符的 codex 模型
# 注意：冒号用作分隔符（model:effort），所以用 $ 测试，它会留在 model 部分
echo "测试 12：拒绝带 YAML 不安全字符的 codex 模型"
setup_test_repo
mock_codex
rm -rf "$TEST_DIR/.humanize/rlcr" 2>/dev/null || true
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --codex-model 'model$inject:high' "plans/test-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "invalid characters"; then
    pass "Codex model with $ rejected"
else
    fail "Codex model validation" "exit 1 with invalid characters error" "$RESULT"
fi

# 测试 13：拒绝带 YAML 不安全字符的 codex effort
echo "测试 13：拒绝带 YAML 不安全字符的 codex effort"
rm -rf "$TEST_DIR/.humanize/rlcr" 2>/dev/null || true
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --codex-model "gpt-5.5:high#comment" "plans/test-plan.md" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$RESULT" | grep -q "Invalid codex effort"; then
    pass "Codex effort with hash rejected"
else
    fail "Codex effort validation" "exit 1 with invalid codex effort error" "$RESULT"
fi

# 测试 14：接受带点和连字符的有效 codex 模型
echo "Test 14: Accept valid codex model (alphanumeric, dots, hyphens)"
set +e
RESULT=$("$PROJECT_ROOT/scripts/setup-rlcr-loop.sh" --codex-model "gpt-5.5:medium" "plans/test-plan.md" 2>&1)
EXIT_CODE=$?
set -e
# 不应该因 model/effort 验证而失败（可能因其他原因而失败）
if ! echo "$RESULT" | grep -q "invalid characters"; then
    pass "Valid codex model accepted"
else
    fail "Valid codex model" "no invalid characters error" "$RESULT"
fi

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

exit $TESTS_FAILED
