#!/usr/bin/env bash
#
# 方法论分析阶段库
#
# 为在 RLCR 循环真正退出之前运行的方法论改进分析阶段提供函数。
# 一个独立的 Opus 代理从纯方法论角度分析开发记录，
# 并可选地帮助用户提交带有改进建议的 GitHub issue。
#
# 此库由 loop-codex-stop-hook.sh 源码引入。
#

# 源码守卫：防止重复源码引入
[[ -n "${_METHODOLOGY_ANALYSIS_LOADED:-}" ]] && return 0 2>/dev/null || true
_METHODOLOGY_ANALYSIS_LOADED=1

# 进入方法论分析阶段
#
# 将当前状态文件重命名为 methodology-analysis-state.md，记录退出原因，
# 渲染分析提示，并输出阻止 JSON 响应。
#
# 参数：
#   $1 - exit_reason："complete"、"stop" 或 "maxiter"
#   $2 - exit_reason_description：循环退出原因的人类可读解释
#
# 读取的全局变量：
#   PRIVACY_MODE - "true" 跳过分析，"false" 继续
#   STATE_FILE   - 当前活跃状态文件的路径
#   LOOP_DIR     - 循环目录的路径
#   CURRENT_ROUND - 当前轮次编号
#   MAX_ITERATIONS - 最大迭代次数设置
#   TEMPLATE_DIR - 提示渲染的模板目录
#
# 返回：
#   0 - 已进入分析阶段，阻止 JSON 已输出，调用者应退出 0
#   1 - 应跳过分析（隐私开启、已完成或重新进入）
#
enter_methodology_analysis_phase() {
    local exit_reason="$1"
    local exit_reason_description="$2"

    # 如果隐私模式开启则跳过
    if [[ "$PRIVACY_MODE" == "true" ]]; then
        echo "Methodology analysis skipped (privacy mode enabled)" >&2
        return 1
    fi

    # 防止重新进入：如果 methodology-analysis-state.md 已存在则跳过
    if [[ -f "$LOOP_DIR/methodology-analysis-state.md" ]]; then
        echo "Methodology analysis phase already active, skipping re-entry" >&2
        return 1
    fi

    # 如果在先前的尝试中已完成则跳过
    if [[ -f "$LOOP_DIR/methodology-analysis-done.md" ]]; then
        local done_content
        done_content=$(cat "$LOOP_DIR/methodology-analysis-done.md" 2>/dev/null || echo "")
        if [[ -n "$done_content" ]]; then
            echo "Methodology analysis already completed, skipping" >&2
            return 1
        fi
    fi

    # 将当前状态文件重命名为 methodology-analysis-state.md
    mv "$STATE_FILE" "$LOOP_DIR/methodology-analysis-state.md"
    echo "State file renamed to: $LOOP_DIR/methodology-analysis-state.md" >&2

    # 记录原始退出原因，以便完成处理器可以最终确定
    echo "$exit_reason" > "$LOOP_DIR/.methodology-exit-reason"

    # 为完成产物创建空占位符
    touch "$LOOP_DIR/methodology-analysis-done.md"

    # 渲染提示模板
    local fallback="# Methodology Analysis Phase

Please analyze the development records in $LOOP_DIR and provide methodology improvement suggestions.
Write your analysis to $LOOP_DIR/methodology-analysis-report.md.
When done, write a completion note to $LOOP_DIR/methodology-analysis-done.md."

    local analysis_prompt
    analysis_prompt=$(load_and_render_safe "$TEMPLATE_DIR" "claude/methodology-analysis-prompt.md" "$fallback" \
        "LOOP_DIR=$LOOP_DIR" \
        "EXIT_REASON=$exit_reason" \
        "EXIT_REASON_DESCRIPTION=$exit_reason_description" \
        "CURRENT_ROUND=$CURRENT_ROUND" \
        "MAX_ITERATIONS=$MAX_ITERATIONS")

    # 输出带有渲染提示的阻止 JSON
    jq -n \
        --arg reason "$analysis_prompt" \
        --arg msg "Loop: Methodology Analysis Phase - analyzing development methodology" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'

    return 0
}

# 完成方法论分析阶段
#
# 检查完成产物，读取原始退出原因，将状态文件重命名为适当的终端状态，
# 并清理标记文件。
#
# 读取的全局变量：
#   LOOP_DIR - 循环目录的路径
#
# 返回：
#   0 - 完成成功，调用者应退出 0（允许退出）
#   1 - 未完成（done 标记缺失/为空、报告缺失或退出原因无效）
#
complete_methodology_analysis() {
    local done_file="$LOOP_DIR/methodology-analysis-done.md"
    local report_file="$LOOP_DIR/methodology-analysis-report.md"

    # 检查完成产物是否有实际内容（不仅仅是空占位符）
    if [[ ! -f "$done_file" ]]; then
        return 1
    fi

    local done_content
    done_content=$(cat "$done_file" 2>/dev/null || echo "")
    # 修剪空白以拒绝仅空白的标记
    done_content="${done_content#"${done_content%%[![:space:]]*}"}"
    if [[ -z "$done_content" ]]; then
        return 1
    fi

    # 要求分析报告存在且有内容（确保 Opus 代理实际产生了分析，
    # 而不是空的/截断的文件）
    if [[ ! -f "$report_file" ]]; then
        echo "Warning: methodology-analysis-report.md missing, blocking completion" >&2
        return 1
    fi
    local report_content
    report_content=$(cat "$report_file" 2>/dev/null || echo "")
    report_content="${report_content#"${report_content%%[![:space:]]*}"}"
    if [[ -z "$report_content" ]]; then
        echo "Warning: methodology-analysis-report.md is empty, blocking completion" >&2
        return 1
    fi

    # 读取退出原因（关闭失败：缺失标记阻止完成）
    if [[ ! -f "$LOOP_DIR/.methodology-exit-reason" ]]; then
        echo "Error: .methodology-exit-reason marker missing, cannot determine terminal state" >&2
        return 1
    fi

    local exit_reason
    exit_reason=$(cat "$LOOP_DIR/.methodology-exit-reason" 2>/dev/null || echo "")
    exit_reason=$(echo "$exit_reason" | tr -d '[:space:]')

    # 验证退出原因（对无效值关闭失败）
    case "$exit_reason" in
        complete|stop|maxiter)
            ;;
        *)
            echo "Error: Invalid methodology exit reason '$exit_reason', blocking completion" >&2
            return 1
            ;;
    esac

    # 验证完成。调用者（stop hook）负责在 git 清洁门控通过后
    # 将 methodology-analysis-state.md 重命名为终端状态并清理
    # .methodology-exit-reason，以便活跃状态文件在确认清洁之前保持原位。
    return 0
}

# 因方法论分析未完成而阻止退出
#
# 输出阻止 JSON 指示 Claude 在退出前完成分析。
#
# 读取的全局变量：
#   LOOP_DIR - 循环目录的路径
#
block_methodology_analysis_incomplete() {
    local done_file="$LOOP_DIR/methodology-analysis-done.md"

    local reason="# Methodology Analysis Incomplete

Please complete the methodology analysis before exiting.

You need to:
1. Spawn an Opus agent to analyze the development records
2. Review the analysis report
3. Optionally help the user file a GitHub issue
4. Write a completion note to: $done_file

The completion marker file must contain actual content (not be empty) to signal that the analysis is done."

    jq -n \
        --arg reason "$reason" \
        --arg msg "Loop: Methodology Analysis Phase - please complete the analysis" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
}
