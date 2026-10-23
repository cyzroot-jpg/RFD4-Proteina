#!/usr/bin/env bash
#
# RLCR 循环钩子的模板加载函数
#
# 此库提供加载和渲染提示模板的函数。
#
# 模板变量语法
# ========================
# 模板使用 {{VARIABLE_NAME}} 语法作为占位符。
# - 变量名：仅大写字母、数字、下划线
# - 示例：{{PLAN_FILE}}、{{CURRENT_ROUND}}、{{GOAL_TRACKER_FILE}}
# - 单次替换：值中的 {{VAR}} 不会被展开
# - 缺失变量：占位符保持原样（例如 {{UNDEFINED}}）
#
# 可用函数：
# - get_template_dir：获取模板目录路径
# - load_template：按名称加载模板文件
# - render_template：用值替换 {{VAR}} 占位符
# - load_and_render：在一次调用中加载和渲染
# - load_and_render_safe：与上面相同，但对缺失模板有回退
# - validate_template_dir：检查模板目录是否有效
#

# 获取模板目录路径
# 这是相对于 hooks/lib 目录的（向上 2 级到插件根）
get_template_dir() {
    local script_dir="$1"
    local plugin_root
    plugin_root="$(cd "$script_dir/../.." && pwd)"
    echo "$plugin_root/prompt-template"
}

# 加载模板文件并输出其内容
# 用法：load_template "$TEMPLATE_DIR" "codex/full-alignment-review.md"
# 如果文件未找到则返回空字符串
load_template() {
    local template_dir="$1"
    local template_name="$2"
    local template_path="$template_dir/$template_name"

    if [[ -f "$template_path" ]]; then
        cat "$template_path"
    else
        echo "Warning: Template not found: $template_path" >&2
    fi
}

# 使用多次变量替换渲染模板（单次传递）
# 用法：render_template "$template_content" "VAR1=value1" "VAR2=value2" ...
# 变量应作为 VAR=value 对传递
#
# 重要：这使用单次传递方法来防止占位符注入。
# 如果变量值包含 {{OTHER_VAR}}，它不会被替换。
# 这防止像 REVIEW_CONTENT 这样的内容的 {{...}} 模式被意外替换，
# 这可能会损坏提示。
render_template() {
    local content="$1"
    shift

    # 为所有替换构建环境变量
    # 使用 TMPL_VAR_ 前缀以避免冲突
    local -a env_vars=()
    for var_assignment in "$@"; do
        local var_name="${var_assignment%%=*}"
        local var_value="${var_assignment#*=}"
        env_vars+=("TMPL_VAR_${var_name}=${var_value}")
    done

    # 使用 awk 的单次替换
    # 扫描 {{VAR}} 模式并用环境中的值替换它们
    # 替换的内容直接进入输出而不重新扫描
    local awk_exit=0
    content=$(env ${env_vars[@]+"${env_vars[@]}"} awk '
    BEGIN {
        # Build lookup table from environment variables with TMPL_VAR_ prefix
        for (name in ENVIRON) {
            if (substr(name, 1, 9) == "TMPL_VAR_") {
                var_name = substr(name, 10)  # Remove prefix
                vars[var_name] = ENVIRON[name]
            }
        }
    }
    {
        line = $0
        result = ""

        # Process line character by character, looking for {{ patterns
        while (length(line) > 0) {
            # Find next {{
            open_idx = index(line, "{{")
            if (open_idx == 0) {
                # No more placeholders, append rest of line
                result = result line
                break
            }

            # Append everything before {{
            result = result substr(line, 1, open_idx - 1)
            line = substr(line, open_idx)  # line now starts with {{

            # Find closing }}
            close_idx = index(substr(line, 3), "}}")
            if (close_idx == 0) {
                # No closing }}, treat {{ as literal
                result = result substr(line, 1, 2)
                line = substr(line, 3)
                continue
            }

            # Extract variable name (between {{ and }})
            var_name = substr(line, 3, close_idx - 1)
            placeholder = "{{" var_name "}}"

            # Look up in our variables table
            if (var_name in vars) {
                # Replace with value (value goes to output, not re-scanned)
                result = result vars[var_name]
            } else {
                # Keep original placeholder if not found
                result = result placeholder
            }

            # Move past the placeholder
            line = substr(line, length(placeholder) + 1)
        }

        print result
    }' <<< "$content") || awk_exit=$?

    if [[ $awk_exit -ne 0 ]]; then
        echo "Error: Template rendering failed (awk exit code: $awk_exit)" >&2
        return 1
    fi

    echo "$content"
}

# 在一步中加载和渲染模板
# 用法：load_and_render "$TEMPLATE_DIR" "block/git-not-clean.md" "GIT_ISSUES=uncommitted changes"
load_and_render() {
    local template_dir="$1"
    local template_name="$2"
    shift 2

    local content
    content=$(load_template "$template_dir" "$template_name")

    if [[ -n "$content" ]]; then
        render_template "$content" "$@"
    fi
}

# 从另一个模板文件追加内容
# 用法：append_template "$base_content" "$TEMPLATE_DIR" "claude/post-alignment.md"
# 仅在模板存在且非空时追加。
append_template() {
    local base_content="$1"
    local template_dir="$2"
    local template_name="$3"

    local additional_content
    additional_content=$(load_template "$template_dir" "$template_name" 2>/dev/null) || true

    echo "$base_content"
    if [[ -n "$additional_content" ]]; then
        echo "$additional_content"
    fi
}

# ========================================
# 带有回退消息的安全版本
# ========================================

# 发出回退消息，可选地渲染模板变量。
_emit_fallback() {
    local fallback_msg="$1"
    shift
    if [[ $# -gt 0 ]]; then
        render_template "$fallback_msg" "$@"
    else
        echo "$fallback_msg"
    fi
}

# 如果模板失败则加载和渲染带有回退消息
# 用法：load_and_render_safe "$TEMPLATE_DIR" "block/message.md" "fallback message" "VAR=value" ...
# 如果模板缺失或为空则返回回退消息
load_and_render_safe() {
    local template_dir="$1"
    local template_name="$2"
    local fallback_msg="$3"
    shift 3

    local content
    content=$(load_template "$template_dir" "$template_name" 2>/dev/null) || true

    if [[ -z "$content" ]]; then
        _emit_fallback "$fallback_msg" "$@"
        return
    fi

    local result
    result=$(render_template "$content" "$@") || true

    if [[ -z "$result" ]]; then
        _emit_fallback "$fallback_msg" "$@"
        return
    fi

    echo "$result"
}

# 验证 TEMPLATE_DIR 存在且包含模板
# 用法：validate_template_dir "$TEMPLATE_DIR"
# 如果有效则返回 0，否则返回 1
validate_template_dir() {
    local template_dir="$1"

    if [[ ! -d "$template_dir" ]]; then
        echo "ERROR: Template directory not found: $template_dir" >&2
        return 1
    fi

    local required_subdirs=("block" "codex" "claude" "plan")
    local missing=()
    local subdir
    for subdir in "${required_subdirs[@]}"; do
        if [[ ! -d "$template_dir/$subdir" ]]; then
            missing+=("$subdir")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Template directory missing subdirectories (${missing[*]}): $template_dir" >&2
        return 1
    fi

    return 0
}
