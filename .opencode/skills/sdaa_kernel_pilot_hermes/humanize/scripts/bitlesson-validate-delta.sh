#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  scripts/bitlesson-validate-delta.sh \
      --summary-file <path> \
      --bitlesson-file <path> \
      --bitlesson-relpath <relpath> \
      --allow-empty-none <true|false> \
      --template-dir <path> \
      --current-round <int>
EOF
}

SUMMARY_FILE=""
BITLESSON_FILE=""
BITLESSON_FILE_REL=""
BITLESSON_ALLOW_EMPTY_NONE=""
TEMPLATE_DIR=""
CURRENT_ROUND=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary-file)
            SUMMARY_FILE="${2:-}"
            shift 2
            ;;
        --bitlesson-file)
            BITLESSON_FILE="${2:-}"
            shift 2
            ;;
        --bitlesson-relpath)
            BITLESSON_FILE_REL="${2:-}"
            shift 2
            ;;
        --allow-empty-none)
            BITLESSON_ALLOW_EMPTY_NONE="${2:-}"
            shift 2
            ;;
        --template-dir)
            TEMPLATE_DIR="${2:-}"
            shift 2
            ;;
        --current-round)
            CURRENT_ROUND="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$SUMMARY_FILE" ]] || [[ -z "$BITLESSON_FILE" ]] || [[ -z "$BITLESSON_FILE_REL" ]] || \
   [[ -z "$BITLESSON_ALLOW_EMPTY_NONE" ]] || [[ -z "$TEMPLATE_DIR" ]] || [[ -z "$CURRENT_ROUND" ]]; then
    echo "Error: Missing required argument(s)" >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$SUMMARY_FILE" ]]; then
    echo "Error: Summary file not found: $SUMMARY_FILE" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/hooks/lib/template-loader.sh"

block_exit() {
    local reason="$1"
    local msg="$2"
    jq -n \
        --arg reason "$reason" \
        --arg msg "$msg" \
        '{
            "decision": "block",
            "reason": $reason,
            "systemMessage": $msg
        }'
    exit 0
}

extract_bitlesson_delta_block() {
    local mode="$1"

    awk -v mode="$mode" '
        BEGIN {
            in_delta = 0
            found_delta = 0
            in_fence = 0
            fence_delim = ""
            in_html_comment = 0
        }

        function update_fence_state(line) {
            if (in_html_comment) {
                return
            }

            if (!in_fence && line ~ /^```/) {
                in_fence = 1
                fence_delim = "```"
                return
            }

            if (!in_fence && line ~ /^~~~/) {
                in_fence = 1
                fence_delim = "~~~"
                return
            }

            if (in_fence && fence_delim == "```" && line ~ /^```/) {
                in_fence = 0
                fence_delim = ""
                return
            }

            if (in_fence && fence_delim == "~~~" && line ~ /^~~~/) {
                in_fence = 0
                fence_delim = ""
            }
        }

        function update_html_comment_state(line,    start_idx, end_idx) {
            if (in_fence) {
                return
            }

            start_idx = index(line, "<!--")
            end_idx = index(line, "-->")

            if (in_html_comment) {
                if (end_idx > 0) {
                    in_html_comment = 0
                }
                return
            }

            if (start_idx > 0 && (end_idx == 0 || end_idx < start_idx)) {
                in_html_comment = 1
            }
        }

        {
            if (!in_fence && !in_html_comment &&
                tolower($0) ~ /^##[[:space:]]*bitlesson delta[[:space:]]*$/) {
                found_delta = 1
                in_delta = 1
                next
            }

            if (in_delta && !in_fence && !in_html_comment && /^##[[:space:]]+/) {
                in_delta = 0
            }

            if (mode == "extract" && in_delta) {
                print
            }

            update_fence_state($0)
            update_html_comment_state($0)
        }

        END {
            if (mode == "detect" && !found_delta) {
                exit 1
            }
        }
    ' "$SUMMARY_FILE"
}

if ! extract_bitlesson_delta_block detect >/dev/null; then
    FALLBACK=$(cat <<'EOF'
# 缺少 BitLesson Delta

你的摘要中缺少必需的 `## BitLesson Delta` 部分。

必需的最小格式：
```markdown
## BitLesson Delta
- Action: none|add|update
- Lesson ID(s): <IDs or NONE>
- Notes: <what changed and why>
```
EOF
)
    REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-missing.md" "$FALLBACK")
    block_exit "$REASON" "Loop: Summary missing BitLesson Delta section (round $CURRENT_ROUND)"
fi

BITLESSON_DELTA_BLOCK=$(extract_bitlesson_delta_block extract)

BITLESSON_ACTION_CANDIDATES=$(echo "$BITLESSON_DELTA_BLOCK" | sed -nE 's/^[[:space:]-]*Action:[[:space:]]*([A-Za-z]+)[[:space:]]*$/\1/p' | tr '[:upper:]' '[:lower:]')
BITLESSON_ACTION_COUNT=$(echo "$BITLESSON_ACTION_CANDIDATES" | awk 'NF{c++} END{print c+0}')
BITLESSON_ACTION=$(echo "$BITLESSON_ACTION_CANDIDATES" | awk 'NF{print; exit}')

if [[ "$BITLESSON_ACTION_COUNT" -ne 1 ]] || [[ "$BITLESSON_ACTION" != "none" && "$BITLESSON_ACTION" != "add" && "$BITLESSON_ACTION" != "update" ]]; then
    FALLBACK=$(cat <<'EOF'
# 无效的 BitLesson Delta Action

你的 `## BitLesson Delta` 部分存在，但必须包含一个 action：
- `none`
- `add`
- `update`
EOF
)
    REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-invalid.md" "$FALLBACK")
    block_exit "$REASON" "Loop: BitLesson Delta must include action none/add/update (round $CURRENT_ROUND)"
fi

BITLESSON_IDS_RAW=$(echo "$BITLESSON_DELTA_BLOCK" | sed -nE 's/^[[:space:]-]*Lesson ID\(s\):[[:space:]]*(.*)$/\1/p' | head -n1)
if [[ -z "$BITLESSON_IDS_RAW" ]]; then
    BITLESSON_IDS_RAW=$(echo "$BITLESSON_DELTA_BLOCK" | sed -nE 's/^[[:space:]-]*Lesson IDs:[[:space:]]*(.*)$/\1/p' | head -n1)
fi
BITLESSON_IDS_RAW=$(echo "$BITLESSON_IDS_RAW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
BITLESSON_IDS_UPPER=$(echo "$BITLESSON_IDS_RAW" | tr '[:lower:]' '[:upper:]')

CONCRETE_BITLESSON_COUNT=0
if [[ -f "$BITLESSON_FILE" ]]; then
    CONCRETE_BITLESSON_COUNT=$(awk '
        /^Lesson ID:[[:space:]]*/ {
            id=$0
            sub(/^Lesson ID:[[:space:]]*/, "", id)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
            if (id != "" && id != "<BL-YYYYMMDD-short-name>" && id != "BL-YYYYMMDD-short-name" && id !~ /^<.*>$/) {
                count++
            }
        }
        END { print count+0 }
    ' "$BITLESSON_FILE" 2>/dev/null)
fi

if [[ "$BITLESSON_ACTION" == "none" ]]; then
    if [[ -n "$BITLESSON_IDS_RAW" ]] && [[ "$BITLESSON_IDS_UPPER" != "NONE" ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson Delta 不一致

`Action: none` 要求 `Lesson ID(s): NONE`（或留空 Lesson ID(s)）。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK")
        block_exit "$REASON" "Loop: BitLesson Delta inconsistent for action none (round $CURRENT_ROUND)"
    fi

    if [[ "$CONCRETE_BITLESSON_COUNT" -eq 0 ]] && [[ "$BITLESSON_ALLOW_EMPTY_NONE" != "true" ]]; then
        FALLBACK=$(cat <<'EOF'
# 需要记录 BitLesson

当 {{BITLESSON_FILE}} 仍然没有具体的课程条目时，第 {{CURRENT_ROUND}} 轮不允许使用 `Action: none`。

如果本轮解决了前几轮发现的问题，请添加或更新至少一个可复用的课程，并报告 `Action: add` 或 `Action: update`。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-empty-kb.md" "$FALLBACK" \
            "CURRENT_ROUND=$CURRENT_ROUND" \
            "BITLESSON_FILE=$BITLESSON_FILE_REL")
        block_exit "$REASON" "Loop: BitLesson entry required for non-zero round (round $CURRENT_ROUND)"
    fi
else
    if [[ -z "$BITLESSON_IDS_RAW" ]] || [[ "$BITLESSON_IDS_UPPER" == "NONE" ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson Delta 不一致

`Action: {{ACTION}}` 要求具体的 `Lesson ID(s)`（不是 `NONE`）。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK" \
            "ACTION=$BITLESSON_ACTION")
        block_exit "$REASON" "Loop: BitLesson Delta missing lesson IDs for action $BITLESSON_ACTION (round $CURRENT_ROUND)"
    fi

    BITLESSON_NOTES=$(echo "$BITLESSON_DELTA_BLOCK" | sed -nE 's/^[[:space:]-]*Notes:[[:space:]]*(.*)$/\1/p' | head -n1)
    BITLESSON_NOTES=$(echo "$BITLESSON_NOTES" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    NOTES_PLACEHOLDER_REGEX='^(\[.*\]|<.*>)$'

    if [[ -z "$BITLESSON_NOTES" ]] || [[ "$BITLESSON_NOTES" =~ $NOTES_PLACEHOLDER_REGEX ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson Delta 缺少 Notes

`Action: {{ACTION}}` 要求一个 `Notes:` 字段来解释更改了什么以及原因。

Notes 字段不得为空或包含占位符文本如 `[what changed and why]`。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-missing-notes.md" "$FALLBACK" \
            "ACTION=$BITLESSON_ACTION")
        block_exit "$REASON" "Loop: BitLesson Delta missing Notes for action $BITLESSON_ACTION (round $CURRENT_ROUND)"
    fi

    if [[ ! -f "$BITLESSON_FILE" ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson 文件缺失

摘要声明了 `Action: {{ACTION}}`，但 {{BITLESSON_FILE}} 不存在。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK" \
            "ACTION=$BITLESSON_ACTION" \
            "BITLESSON_FILE=$BITLESSON_FILE_REL")
        block_exit "$REASON" "Loop: BitLesson file missing for action $BITLESSON_ACTION (round $CURRENT_ROUND)"
    fi

    INVALID_IDS=""
    MISSING_IDS=""
    HAS_ANY_ID=false
    IFS=',' read -r -a LESSON_ID_ARRAY <<< "$BITLESSON_IDS_RAW"

    for RAW_ID in "${LESSON_ID_ARRAY[@]}"; do
        LESSON_ID=$(echo "$RAW_ID" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -n "$LESSON_ID" ]] || continue
        HAS_ANY_ID=true

        if [[ ! "$LESSON_ID" =~ ^BL-[0-9]{8}-[A-Za-z0-9._-]+$ ]]; then
            INVALID_IDS="${INVALID_IDS}
- $LESSON_ID"
            continue
        fi

        if ! awk -v target="$LESSON_ID" '
            /^Lesson ID:[[:space:]]*/ {
                id=$0
                sub(/^Lesson ID:[[:space:]]*/, "", id)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
                if (id == target) found=1
            }
            END { exit(found ? 0 : 1) }
        ' "$BITLESSON_FILE" >/dev/null 2>&1; then
            MISSING_IDS="${MISSING_IDS}
- $LESSON_ID"
        fi
    done

    if [[ "$HAS_ANY_ID" != "true" ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson Delta 不一致

`Action: {{ACTION}}` 要求至少一个具体的 Lesson ID。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK" \
            "ACTION=$BITLESSON_ACTION")
        block_exit "$REASON" "Loop: BitLesson Delta has no concrete lesson IDs (round $CURRENT_ROUND)"
    fi

    if [[ -n "$INVALID_IDS" ]]; then
        FALLBACK=$(cat <<'EOF'
# 无效的 BitLesson Lesson ID(s)

`## BitLesson Delta` 中的以下 ID 无效：
{{INVALID_IDS}}

期望格式：`BL-YYYYMMDD-short-name`。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK" \
            "INVALID_IDS=$INVALID_IDS")
        block_exit "$REASON" "Loop: Invalid Lesson ID format in BitLesson Delta (round $CURRENT_ROUND)"
    fi

    if [[ -n "$MISSING_IDS" ]]; then
        FALLBACK=$(cat <<'EOF'
# BitLesson 条目缺失

摘要声明了 `Action: {{ACTION}}`，但这些 Lesson ID(s) 在 {{BITLESSON_FILE}} 中未找到：
{{MISSING_IDS}}

请在退出前在 {{BITLESSON_FILE}} 中添加/更新这些条目。
EOF
)
        REASON=$(load_and_render_safe "$TEMPLATE_DIR" "block/bitlesson-delta-inconsistent.md" "$FALLBACK" \
            "ACTION=$BITLESSON_ACTION" \
            "BITLESSON_FILE=$BITLESSON_FILE_REL" \
            "MISSING_IDS=$MISSING_IDS")
        block_exit "$REASON" "Loop: BitLesson IDs missing in knowledge base (round $CURRENT_ROUND)"
    fi
fi

exit 0
