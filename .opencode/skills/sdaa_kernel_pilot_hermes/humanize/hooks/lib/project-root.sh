#!/usr/bin/env bash
#
# 所有 humanize 钩子和脚本的确定性项目根解析器。
#
# 解析优先级：
#   1. 链接的 git worktree toplevel，当它与 CLAUDE_PROJECT_DIR 不同时
#   2. CLAUDE_PROJECT_DIR（Claude 会话根）
#   3. git rev-parse --show-toplevel（最近的包含仓库）
#   4. 非零返回。
#
# CLAUDE_PROJECT_DIR 通常是权威的会话根。钩子和辅助脚本通常从插件检出执行，
# 同时目标是不同的项目，因此盲目优先使用插件仓库的 git toplevel 会使
# 活跃循环状态和项目配置消失。
#
# 例外是链接的 git worktree：explore-idea workers 可以继承协调器的
# CLAUDE_PROJECT_DIR，同时在自己的 worktree 中运行。在这种情况下，
# 当前检出是更安全的根。
#
# 故意不使用 pwd 作为回退：它在会话期间随 `cd` 调用漂移，
# 并静默导致 .humanize/rlcr/ 下的 state.md 查找错过活跃循环目录。
#
# 解析的路径通过 realpath 传递，以便符号链接的前缀
# （例如 /Users/x vs /private/Users/x 在 macOS 上，或 /var vs /private/var）
# 在设置时和钩子时解析之间不会不同。
#
# 验证器中的路径比较站点必须通过规范化用户提供的侧来镜像这一点；
# 使用下面的 companion `canonicalize_path` 辅助函数。
#

if [[ -n "${_HUMANIZE_PROJECT_ROOT_SOURCED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_HUMANIZE_PROJECT_ROOT_SOURCED=1

# resolve_project_root
#
# 将解析的项目根打印到 stdout。成功时返回 0，
# 当 CLAUDE_PROJECT_DIR 和 git toplevel 都不可用时返回 1。
#
# 必须有项目根的调用者应处理失败：
#
#   PROJECT_ROOT="$(resolve_project_root)" || exit 0   # 钩子：允许自然停止
#   PROJECT_ROOT="$(resolve_project_root)" || {        # 设置：硬错误
#       echo "Error: cannot determine humanize project root" >&2
#       exit 1
#   }
#
resolve_project_root() {
    local env_root="${CLAUDE_PROJECT_DIR:-}"
    local git_root=""
    local root=""

    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$git_root" ]]; then
        git_root="$(canonicalize_path "$git_root")"
    fi
    if [[ -n "$env_root" ]]; then
        env_root="$(canonicalize_path "$env_root")"
    fi

    if [[ -n "$git_root" && -n "$env_root" && "$git_root" != "$env_root" && -f "$git_root/.git" ]]; then
        root="$git_root"
    elif [[ -n "$env_root" ]]; then
        root="$env_root"
    else
        root="$git_root"
    fi
    if [[ -z "$root" ]]; then
        return 1
    fi

    printf '%s\n' "$root"
}

# canonicalize_path_prefix
#
# 仅在父目录中解析符号链接并逐字重新附加原始 basename。
# 这是将用户提供的文件名与已知目录内的预期路径进行比较的正确辅助函数：
# /tmp/alias 指向 /real/loop/state.md 的符号链接不能规范化为
# /real/loop/state.md 进行比较，因为 `mv` 操作链接路径本身。
# 仅解析父目录仍然让符号链接的项目前缀（例如 /var vs /private/var 在 macOS 上）
# 匹配规范的预期路径。
#
# 如果父目录的 realpath 失败，则回退到返回输入路径不变
# （前缀无法规范化 -> 调用者的比较将正确失败于规范的预期路径）。
#
# 空输入不打印任何内容并返回 0。
#
canonicalize_path_prefix() {
    local path="$1"
    if [[ -z "$path" ]]; then
        return 0
    fi

    local parent base parent_real
    parent=$(dirname -- "$path")
    base=$(basename -- "$path")

    if parent_real=$(realpath "$parent" 2>/dev/null) && [[ -n "$parent_real" ]]; then
        printf '%s/%s\n' "${parent_real%/}" "$base"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        parent_real=$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$parent" 2>/dev/null || true)
        if [[ -n "$parent_real" ]]; then
            printf '%s/%s\n' "${parent_real%/}" "$base"
            return 0
        fi
    fi

    printf '%s\n' "$path"
}

# canonicalize_path
#
# 打印输入路径的 realpath。如果路径本身尚不存在
# （在文件创建之前的写入验证中很常见），则规范化父目录并重新附加 basename。
# 如果 realpath 不可用且 python3 缺失，则逐字打印输入路径。
#
# 安全说明：此辅助函数在叶子存在时取消引用叶子处的符号链接。
# 不要使用它来授权用户提供的路径与预期文件名 -- 改用
# canonicalize_path_prefix，它仅解析父目录。
#
# 空输入不打印任何内容并返回 0。
#
canonicalize_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        return 0
    fi

    local canonical=""

    if canonical=$(realpath "$path" 2>/dev/null) && [[ -n "$canonical" ]]; then
        printf '%s\n' "$canonical"
        return 0
    fi

    # 路径不存在：规范化父目录，重新附加 basename。
    local parent base
    parent=$(dirname -- "$path")
    base=$(basename -- "$path")
    if canonical=$(realpath "$parent" 2>/dev/null) && [[ -n "$canonical" ]]; then
        printf '%s/%s\n' "${canonical%/}" "$base"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        canonical=$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null || true)
        if [[ -n "$canonical" ]]; then
            printf '%s\n' "$canonical"
            return 0
        fi
    fi

    printf '%s\n' "$path"
}
