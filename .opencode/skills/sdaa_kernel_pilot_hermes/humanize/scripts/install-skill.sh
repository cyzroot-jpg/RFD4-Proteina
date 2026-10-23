#!/usr/bin/env bash
#
# 为 Kimi、Codex 和/或 Hermes 安装/升级 KernelPilot Humanize 技能。
#
# 此脚本的功能：
# 1) 将 skills/{humanize,humanize-gen-plan,humanize-rlcr,...} 同步到目标技能目录
# 2) 将运行时依赖复制到 <skills-dir>/humanize/{scripts,hooks,prompt-template}
# 3) Sync teco-ops-wiki as the exclusive external knowledge skill
# 4) 用具体的运行时根路径填充 SKILL.md 命令路径
#
# 用法:
#   ./scripts/install-skill.sh [options]
#
# 选项:
#   --repo-root PATH        Humanize 仓库根目录（默认: 自动检测）
#   --target MODE           kimi|codex|hermes|both（默认: kimi）
#   --skills-dir PATH       目标技能目录的旧版别名（为兼容性保留）
#   --kimi-skills-dir PATH  Kimi 技能目录（默认: ~/.config/agents/skills）
#   --codex-skills-dir PATH Codex 技能目录（默认: ${CODEX_HOME:-~/.codex}/skills）
#   --codex-config-dir PATH Codex 配置目录用于 hooks/config.toml（默认: ${CODEX_HOME:-~/.codex})
#   --hermes-skills-dir PATH Hermes 技能目录（默认: ${HERMES_HOME:-~/.hermes}/skills）
#   --hermes-config-dir PATH Hermes 配置目录（默认: ${HERMES_HOME:-~/.hermes})
#   --kernelpilot-root PATH KernelPilot 检出根目录（默认: 自动检测）
#   --teco-ops-wiki-root PATH
#                            teco-ops-wiki checkout (default: external/teco-ops-wiki)
#   --dry-run               打印操作但不写入
#   -h, --help              显示帮助
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SOURCE_ROOT=""
RUNTIME_SOURCE_ROOT=""
TARGET="kimi"
KIMI_SKILLS_DIR="${HOME}/.config/agents/skills"
CODEX_SKILLS_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
CODEX_CONFIG_DIR="${CODEX_HOME:-${HOME}/.codex}"
HERMES_SKILLS_DIR="${HERMES_HOME:-${HOME}/.hermes}/skills"
HERMES_CONFIG_DIR="${HERMES_HOME:-${HOME}/.hermes}"
HUMANIZE_USER_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/humanize"
COMMAND_BIN_DIR="${HUMANIZE_COMMAND_BIN_DIR:-${HOME}/.local/bin}"
LEGACY_SKILLS_DIR=""
DRY_RUN="false"
KERNELPILOT_ROOT="${KERNELPILOT_ROOT:-}"
TECO_OPS_WIKI_ROOT="${TECO_OPS_WIKI_ROOT:-}"

SKILL_NAMES=(
    "humanize"
    "humanize-gen-plan"
    "humanize-refine-plan"
    "humanize-rlcr"
    "humanize-kernel-agent-loop"
    "teco-ops-op-test"
)
TECO_OPS_WIKI_SKILL_NAME="teco-ops-wiki"

usage() {
    cat <<'EOF'
Install KernelPilot Humanize skills for Kimi, Codex, and/or Hermes.

Usage:
  scripts/install-skill.sh [options]

Options:
  --target MODE           kimi|codex|hermes|both (default: kimi)
  --repo-root PATH        Humanize repo root (default: auto-detect)
  --skills-dir PATH       Legacy alias for target skills dir (compat)
  --kimi-skills-dir PATH  Kimi skills dir (default: ~/.config/agents/skills)
  --codex-skills-dir PATH Codex skills dir (default: ${CODEX_HOME:-~/.codex}/skills)
  --codex-config-dir PATH Codex config dir for hooks/config.toml (default: ${CODEX_HOME:-~/.codex})
  --hermes-skills-dir PATH Hermes skills dir (default: ${HERMES_HOME:-~/.hermes}/skills)
  --hermes-config-dir PATH Hermes config dir (default: ${HERMES_HOME:-~/.hermes})
  --command-bin-dir PATH  Install helper command shims here (default: ~/.local/bin)
  --kernelpilot-root PATH KernelPilot checkout root (default: auto-detect)
  --teco-ops-wiki-root PATH
                           Exclusive wiki checkout (default: external/teco-ops-wiki)
  --dry-run               Print actions without writing
  -h, --help              Show help
EOF
}

log() {
    printf '[install-skills] %s\n' "$*"
}

die() {
    printf '[install-skills] Error: %s\n' "$*" >&2
    exit 1
}

validate_repo() {
    [[ -n "$SKILLS_SOURCE_ROOT" ]] || die "internal error: SKILLS_SOURCE_ROOT not set"
    [[ -n "$RUNTIME_SOURCE_ROOT" ]] || die "internal error: RUNTIME_SOURCE_ROOT not set"
    [[ -d "$SKILLS_SOURCE_ROOT" ]] || die "skills source directory not found: $SKILLS_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/scripts" ]] || die "scripts directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/hooks" ]] || die "hooks directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/prompt-template" ]] || die "prompt-template directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/templates" ]] || die "templates directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/config" ]] || die "config directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    [[ -d "$RUNTIME_SOURCE_ROOT/agents" ]] || die "agents directory not found under runtime source root: $RUNTIME_SOURCE_ROOT"
    for skill in "${SKILL_NAMES[@]}"; do
        [[ -f "$SKILLS_SOURCE_ROOT/$skill/SKILL.md" ]] || die "missing $SKILLS_SOURCE_ROOT/$skill/SKILL.md"
    done
}

resolve_source_layout() {
    local candidate_root="$1"
    local runtime_root="$candidate_root"
    local skills_root

    # Source checkout layout:
    #   <repo>/skills/<skill>/SKILL.md
    #   <repo>/scripts
    if [[ -d "$candidate_root/skills" ]] && [[ -d "$candidate_root/scripts" ]]; then
        SKILLS_SOURCE_ROOT="$candidate_root/skills"
        RUNTIME_SOURCE_ROOT="$candidate_root"
        return 0
    fi

    # Installed runtime layout:
    #   <skills-dir>/humanize/scripts/install-skill.sh
    #   <skills-dir>/humanize-gen-plan/SKILL.md
    #   <skills-dir>/humanize-rlcr/SKILL.md
    if [[ -d "$runtime_root/scripts" ]] && [[ -d "$runtime_root/hooks" ]] && [[ -d "$runtime_root/prompt-template" ]]; then
        skills_root="$(cd "$runtime_root/.." && pwd)"
        if [[ -f "$skills_root/humanize/SKILL.md" ]] && [[ -f "$skills_root/humanize-gen-plan/SKILL.md" ]] && [[ -f "$skills_root/humanize-refine-plan/SKILL.md" ]] && [[ -f "$skills_root/humanize-rlcr/SKILL.md" ]]; then
            SKILLS_SOURCE_ROOT="$skills_root"
            RUNTIME_SOURCE_ROOT="$runtime_root"
            return 0
        fi
    fi

    die "could not resolve Humanize source layout from: $candidate_root"
}

resolve_kernelpilot_root() {
    if [[ -n "$KERNELPILOT_ROOT" ]]; then
        KERNELPILOT_ROOT="$(cd "$KERNELPILOT_ROOT" 2>/dev/null && pwd || true)"
        return 0
    fi

    local candidate
    candidate="$(cd "$REPO_ROOT/.." 2>/dev/null && pwd || true)"
    if [[ -n "$candidate" && -f "$candidate/.claude-plugin/marketplace.json" ]]; then
        KERNELPILOT_ROOT="$candidate"
    fi
}

resolve_teco_ops_wiki_root() {
    if [[ -n "$TECO_OPS_WIKI_ROOT" ]]; then
        TECO_OPS_WIKI_ROOT="$(cd "$TECO_OPS_WIKI_ROOT" 2>/dev/null && pwd || true)"
        return 0
    fi

    local candidate
    for candidate in \
        "$KERNELPILOT_ROOT/external/teco-ops-wiki" \
        "$REPO_ROOT/../external/teco-ops-wiki"; do
        if [[ -n "$candidate" && -f "$candidate/SKILL.md" && -f "$candidate/scripts/query.py" ]]; then
            TECO_OPS_WIKI_ROOT="$(cd "$candidate" && pwd)"
            return 0
        fi
    done
}

validate_external_skill_roots() {
    [[ -n "$KERNELPILOT_ROOT" ]] || die "KernelPilot root not found; run from the kernel-pilot/humanize checkout or pass --kernelpilot-root PATH"
    [[ -d "$KERNELPILOT_ROOT" ]] || die "KernelPilot root is not a directory: $KERNELPILOT_ROOT"
    [[ -n "$TECO_OPS_WIKI_ROOT" ]] || die "teco-ops-wiki not found; pass --teco-ops-wiki-root PATH"
    [[ -f "$TECO_OPS_WIKI_ROOT/SKILL.md" ]] || die "teco-ops-wiki skill not found: $TECO_OPS_WIKI_ROOT/SKILL.md"
    [[ -f "$TECO_OPS_WIKI_ROOT/scripts/query.py" ]] || die "teco-ops-wiki query script not found"
    [[ -f "$TECO_OPS_WIKI_ROOT/scripts/get_page.py" ]] || die "teco-ops-wiki page script not found"
    [[ -f "$TECO_OPS_WIKI_ROOT/data/tags.yaml" ]] || die "teco-ops-wiki tags not found"
    [[ -d "$TECO_OPS_WIKI_ROOT/wiki" ]] || die "teco-ops-wiki pages not found"
}

sync_dir() {
    local src="$1"
    local dst="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN sync $src -> $dst"
        return
    fi

    if [[ -L "$dst" ]]; then
        rm "$dst"
    fi
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --exclude '.git' "$src/" "$dst/"
    else
        # Copy to a temp sibling first so the destination is not destroyed
        # if cp fails partway through (disk full, permission error, etc.).
        local tmp_dst
        tmp_dst="$(mktemp -d "$(dirname "$dst")/.sync_tmp.XXXXXX")"
        if cp -a "$src/." "$tmp_dst/"; then
            rm -rf "$tmp_dst/.git"
            rm -rf "$dst"
            mv "$tmp_dst" "$dst"
        else
            rm -rf "$tmp_dst"
            die "failed to copy $src to $dst"
        fi
    fi
}

remove_retired_installed_skills() {
    local target_dir="$1"
    local retired path
    for retired in KernelWiki SDAAKernelWiki ncu-report-skill optest-skill gemm-performance-modeling kernel-bench tecoal-op-test tecolmk-op-test; do
        path="$target_dir/$retired"
        [[ -e "$path" || -L "$path" ]] || continue
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN remove retired installed skill: $path"
        else
            rm -rf -- "$path"
            log "removed retired installed skill: $path"
        fi
    done
}

canonical_path_for_compare() {
    local path="$1"
    local dir base

    if [[ -e "$path" ]]; then
        realpath "$path" 2>/dev/null && return
    fi

    dir="$(dirname "$path")"
    base="$(basename "$path")"
    if [[ -d "$dir" ]]; then
        printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$path" <<'PY'
import os
import sys

print(os.path.realpath(os.path.abspath(sys.argv[1])))
PY
        return
    fi

    printf '%s\n' "$path"
}

sync_one_skill() {
    local skill="$1"
    local target_dir="$2"
    local src="$SKILLS_SOURCE_ROOT/$skill"
    local dst="$target_dir/$skill"
    sync_dir "$src" "$dst"
}

sync_teco_ops_wiki_skill() {
    local target_dir="$1"
    local dst="$target_dir/$TECO_OPS_WIKI_SKILL_NAME"
    sync_dir "$TECO_OPS_WIKI_ROOT" "$dst"
}

install_runtime_bundle() {
    local target_dir="$1"
    local runtime_root="$target_dir/humanize"
    local component

    log "syncing runtime bundle into: $runtime_root"

    for component in scripts hooks prompt-template templates config agents; do
        sync_dir "$RUNTIME_SOURCE_ROOT/$component" "$runtime_root/$component"
    done
}

hydrate_skill_runtime_root() {
    local target_dir="$1"
    local runtime_root="$target_dir/humanize"
    local skill
    local skill_file
    local tmp

    for skill in "${SKILL_NAMES[@]}"; do
        for skill_file in "$target_dir/$skill"/SKILL*.md; do
            [[ -f "$skill_file" ]] || continue

            if [[ "$DRY_RUN" == "true" ]]; then
                log "DRY-RUN hydrate runtime root in $skill_file"
                continue
            fi

            tmp="$(mktemp)"
            # Use ENVIRON to pass the runtime root to awk instead of -v, which
            # interprets backslash escape sequences (e.g. \n -> newline).
            # ENVIRON passes the value verbatim.
            _HYDRATE_RUNTIME_ROOT="$runtime_root" \
            _HYDRATE_KERNELPILOT_ROOT="$KERNELPILOT_ROOT" \
            _HYDRATE_TECO_OPS_WIKI_ROOT="$TECO_OPS_WIKI_ROOT" \
                awk '{
                    gsub(/\{\{HUMANIZE_RUNTIME_ROOT\}\}/, ENVIRON["_HYDRATE_RUNTIME_ROOT"]);
                    gsub(/\{\{KERNELPILOT_ROOT\}\}/, ENVIRON["_HYDRATE_KERNELPILOT_ROOT"]);
                    gsub(/\{\{TECO_OPS_WIKI_ROOT\}\}/, ENVIRON["_HYDRATE_TECO_OPS_WIKI_ROOT"]);
                    print
                }' "$skill_file" > "$tmp" \
                || { rm -f "$tmp"; die "failed to hydrate $skill_file"; }
            mv "$tmp" "$skill_file"
        done
    done
}

strip_claude_specific_frontmatter() {
    local target_dir="$1"
    local skill
    local skill_file
    local tmp

    for skill in "${SKILL_NAMES[@]}"; do
        skill_file="$target_dir/$skill/SKILL.md"
        [[ -f "$skill_file" ]] || continue

        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN strip Claude-specific frontmatter in $skill_file"
            continue
        fi

        tmp="$(mktemp)"
        awk '
            BEGIN { in_fm = 0; fm_done = 0 }
            /^---[[:space:]]*$/ {
                if (fm_done == 0) {
                    in_fm = !in_fm
                    if (in_fm == 0) {
                        fm_done = 1
                    }
                }
                print
                next
            }
            in_fm && $0 ~ /^user-invocable:[[:space:]]*/ { next }
            in_fm && $0 ~ /^disable-model-invocation:[[:space:]]*/ { next }
            in_fm && $0 ~ /^hide-from-slash-command-tool:[[:space:]]*/ { next }
            { print }
        ' "$skill_file" > "$tmp" \
            || { rm -f "$tmp"; die "failed to update $skill_file"; }
        mv "$tmp" "$skill_file"
    done
}

sync_target() {
    local label="$1"
    local target_dir="$2"
    local selected_skills=("${SKILL_NAMES[@]}")

    log "target: $label"
    log "skills dir: $target_dir"

    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$target_dir"
    fi

    remove_retired_installed_skills "$target_dir"

    for skill in "${selected_skills[@]}"; do
        log "syncing [$label] skill: $skill"
        sync_one_skill "$skill" "$target_dir"
    done
    log "syncing [$label] skill: $TECO_OPS_WIKI_SKILL_NAME"
    sync_teco_ops_wiki_skill "$target_dir"
    install_runtime_bundle "$target_dir"
    hydrate_skill_runtime_root "$target_dir"
    strip_claude_specific_frontmatter "$target_dir"
}

install_codex_native_hooks() {
    local target_dir="$1"
    local runtime_root="$target_dir/humanize"
    local hooks_installer="$REPO_ROOT/scripts/install-codex-hooks.sh"
    local args=(
        --codex-config-dir "$CODEX_CONFIG_DIR"
        --runtime-root "$runtime_root"
    )

    [[ -x "$hooks_installer" ]] || die "missing Codex hooks installer: $hooks_installer"
    [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)

    log "installing native Codex hooks into: $CODEX_CONFIG_DIR"
    "$hooks_installer" "${args[@]}"
}

install_codex_user_config() {
    local runtime_root="$1"
    local install_target="$2"
    local user_config_dir="${HUMANIZE_USER_CONFIG_DIR}"
    local user_config_file="$user_config_dir/config.json"
    local default_config_file="$runtime_root/config/default_config.json"

    if ! command -v python3 >/dev/null 2>&1; then
        die "python3 is required to update Humanize user config for Codex installs"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN seed Codex-friendly BitLesson config in $user_config_file"
        return
    fi

    [[ -f "$default_config_file" ]] || die "missing default config: $default_config_file"

    mkdir -p "$user_config_dir"

    python3 - "$default_config_file" "$user_config_file" "$install_target" <<'PY'
import json
import pathlib
import sys

default_config = pathlib.Path(sys.argv[1])
user_config = pathlib.Path(sys.argv[2])
install_target = sys.argv[3]

defaults = json.loads(default_config.read_text(encoding="utf-8"))
default_codex_model = defaults.get("codex_model") or "gpt-5.5"

if user_config.exists():
    try:
        data = json.loads(user_config.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"malformed existing user config: {user_config}: {exc}", file=sys.stderr)
        sys.exit(2)
    if not isinstance(data, dict):
        print(f"existing user config is not a JSON object: {user_config}", file=sys.stderr)
        sys.exit(2)
else:
    data = {}

if not data.get("bitlesson_model"):
    data["bitlesson_model"] = data.get("codex_model") or default_codex_model

if install_target == "codex" and not data.get("provider_mode"):
    data["provider_mode"] = "codex-only"

user_config.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
    case "$?" in
        0)
            log "ensured BitLesson uses a Codex/OpenAI model in $user_config_file"
            ;;
        2)
            die "failed to update $user_config_file because it is malformed; fix it manually and rerun install"
            ;;
        *)
            die "failed to update Humanize user config at $user_config_file"
            ;;
    esac
}

install_bitlesson_selector_shim() {
    local primary_runtime_root="$1"
    local secondary_runtime_root="${2:-}"
    local shim_path="$COMMAND_BIN_DIR/bitlesson-selector"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN install bitlesson-selector shim into $shim_path"
        return
    fi

    mkdir -p "$COMMAND_BIN_DIR"

    # Escape paths for safe embedding in the generated script.
    # Use single-quoted strings so shell metacharacters in paths are inert.
    _escaped_primary=$(printf '%s' "$primary_runtime_root" | sed "s/'/'\\\\''/g")

    cat > "$shim_path" <<SHIM_EOF
#!/usr/bin/env bash
set -euo pipefail

candidate_paths=(
  '${_escaped_primary}/scripts/bitlesson-select.sh'
SHIM_EOF

    if [[ -n "$secondary_runtime_root" ]]; then
        _escaped_secondary=$(printf '%s' "$secondary_runtime_root" | sed "s/'/'\\\\''/g")
        cat >> "$shim_path" <<SHIM_EOF
  '${_escaped_secondary}/scripts/bitlesson-select.sh'
SHIM_EOF
    fi

    cat >> "$shim_path" <<'EOF'
)

for candidate in "${candidate_paths[@]}"; do
    if [[ -x "$candidate" ]]; then
        exec "$candidate" "$@"
    fi
done

echo "Error: Humanize bitlesson selector runtime not found. Re-run install-skill.sh." >&2
exit 1
EOF

    chmod +x "$shim_path"
    log "installed bitlesson-selector shim into: $shim_path"
}

overwrite_kimi_rlcr_skill() {
    local target_dir="$1"
    local kimi_src="$SKILLS_SOURCE_ROOT/humanize-rlcr/SKILL-kimi.md"
    local skill_file="$target_dir/humanize-rlcr/SKILL.md"
    local runtime_root="$target_dir/humanize"

    [[ -f "$kimi_src" ]] || die "missing Kimi RLCR skill source: $kimi_src"
    [[ "$DRY_RUN" == "true" ]] && { log "DRY-RUN overwrite Kimi RLCR skill"; return; }

    local tmp
    tmp="$(mktemp)"
    _HYDRATE_RUNTIME_ROOT="$runtime_root" \
        awk '{gsub(/\{\{HUMANIZE_RUNTIME_ROOT\}\}/, ENVIRON["_HYDRATE_RUNTIME_ROOT"]); print}' \
        "$kimi_src" > "$tmp" \
        || { rm -f "$tmp"; die "failed to hydrate Kimi RLCR skill"; }
    mv "$tmp" "$skill_file"
    log "installed Kimi-specific humanize-rlcr SKILL.md (gate-based)"
}

install_kimi_target() {
    sync_target "kimi" "$KIMI_SKILLS_DIR"
    overwrite_kimi_rlcr_skill "$KIMI_SKILLS_DIR"
}

install_codex_target() {
    sync_target "codex" "$CODEX_SKILLS_DIR"
    install_codex_user_config "$CODEX_SKILLS_DIR/humanize" "codex"
    install_codex_native_hooks "$CODEX_SKILLS_DIR"
}

install_hermes_target() {
    sync_target "hermes" "$HERMES_SKILLS_DIR"
    local runtime_root="$HERMES_SKILLS_DIR/humanize"
    local hooks_installer="$runtime_root/scripts/install-hermes-hooks.sh"
    local args=(
        --hermes-config-dir "$HERMES_CONFIG_DIR"
        --runtime-root "$runtime_root"
    )

    if [[ "$DRY_RUN" == "true" ]]; then
        hooks_installer="$REPO_ROOT/scripts/install-hermes-hooks.sh"
        args+=(--dry-run)
    fi
    [[ -x "$hooks_installer" ]] || die "missing Hermes hooks installer: $hooks_installer"

    log "installing native Hermes pre_verify hook into: $HERMES_CONFIG_DIR"
    "$hooks_installer" "${args[@]}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            [[ -n "${2:-}" ]] || die "--target requires a value"
            case "$2" in
                kimi|codex|hermes|both) TARGET="$2" ;;
                *) die "--target must be one of: kimi, codex, hermes, both" ;;
            esac
            shift 2
            ;;
        --repo-root)
            [[ -n "${2:-}" ]] || die "--repo-root requires a value"
            REPO_ROOT="$2"
            shift 2
            ;;
        --skills-dir)
            [[ -n "${2:-}" ]] || die "--skills-dir requires a value"
            LEGACY_SKILLS_DIR="$2"
            shift 2
            ;;
        --kimi-skills-dir)
            [[ -n "${2:-}" ]] || die "--kimi-skills-dir requires a value"
            KIMI_SKILLS_DIR="$2"
            shift 2
            ;;
        --codex-skills-dir)
            [[ -n "${2:-}" ]] || die "--codex-skills-dir requires a value"
            CODEX_SKILLS_DIR="$2"
            shift 2
            ;;
        --codex-config-dir)
            [[ -n "${2:-}" ]] || die "--codex-config-dir requires a value"
            CODEX_CONFIG_DIR="$2"
            shift 2
            ;;
        --hermes-skills-dir)
            [[ -n "${2:-}" ]] || die "--hermes-skills-dir requires a value"
            HERMES_SKILLS_DIR="$2"
            shift 2
            ;;
        --hermes-config-dir)
            [[ -n "${2:-}" ]] || die "--hermes-config-dir requires a value"
            HERMES_CONFIG_DIR="$2"
            shift 2
            ;;
        --command-bin-dir)
            [[ -n "${2:-}" ]] || die "--command-bin-dir requires a value"
            COMMAND_BIN_DIR="$2"
            shift 2
            ;;
        --kernelpilot-root)
            [[ -n "${2:-}" ]] || die "--kernelpilot-root requires a value"
            KERNELPILOT_ROOT="$2"
            shift 2
            ;;
        --teco-ops-wiki-root)
            [[ -n "${2:-}" ]] || die "--teco-ops-wiki-root requires a value"
            TECO_OPS_WIKI_ROOT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

resolve_source_layout "$REPO_ROOT"
resolve_kernelpilot_root
resolve_teco_ops_wiki_root
validate_external_skill_roots
validate_repo

if [[ -n "$LEGACY_SKILLS_DIR" ]]; then
    case "$TARGET" in
        kimi) KIMI_SKILLS_DIR="$LEGACY_SKILLS_DIR" ;;
        codex) CODEX_SKILLS_DIR="$LEGACY_SKILLS_DIR" ;;
        hermes) HERMES_SKILLS_DIR="$LEGACY_SKILLS_DIR" ;;
        both)
            KIMI_SKILLS_DIR="$LEGACY_SKILLS_DIR"
            CODEX_SKILLS_DIR="$LEGACY_SKILLS_DIR"
            ;;
    esac
fi

if [[ "$TARGET" == "both" ]]; then
    _kimi_real="$(canonical_path_for_compare "$KIMI_SKILLS_DIR")"
    _codex_real="$(canonical_path_for_compare "$CODEX_SKILLS_DIR")"
    if [[ "$_kimi_real" == "$_codex_real" ]]; then
        die "--target both requires distinct kimi and codex skills dirs; both resolved to: $_kimi_real (use --kimi-skills-dir and --codex-skills-dir to set separate paths)"
    fi
fi

log "repo root: $REPO_ROOT"
log "target: $TARGET"
log "kernelpilot root: $KERNELPILOT_ROOT"
log "teco-ops-wiki root: $TECO_OPS_WIKI_ROOT"
if [[ "$TARGET" == "kimi" || "$TARGET" == "both" ]]; then
    log "kimi skills dir: $KIMI_SKILLS_DIR"
fi
if [[ "$TARGET" == "codex" || "$TARGET" == "both" ]]; then
    log "codex skills dir: $CODEX_SKILLS_DIR"
    log "codex config dir: $CODEX_CONFIG_DIR"
fi
if [[ "$TARGET" == "hermes" ]]; then
    log "hermes skills dir: $HERMES_SKILLS_DIR"
    log "hermes config dir: $HERMES_CONFIG_DIR"
fi
log "command bin dir: $COMMAND_BIN_DIR"

case "$TARGET" in
    kimi)
        install_kimi_target
        install_bitlesson_selector_shim "$KIMI_SKILLS_DIR/humanize"
        ;;
    codex)
        install_codex_target
        install_bitlesson_selector_shim "$CODEX_SKILLS_DIR/humanize" "$KIMI_SKILLS_DIR/humanize"
        ;;
    hermes)
        install_hermes_target
        install_bitlesson_selector_shim "$HERMES_SKILLS_DIR/humanize"
        ;;
    both)
        install_kimi_target
        install_codex_target
        install_bitlesson_selector_shim "$CODEX_SKILLS_DIR/humanize" "$KIMI_SKILLS_DIR/humanize"
        ;;
esac

cat <<EOF

Done.

Skills synced:
EOF

if [[ "$TARGET" == "kimi" || "$TARGET" == "both" ]]; then
    cat <<EOF
  - kimi:  $KIMI_SKILLS_DIR
EOF
fi

if [[ "$TARGET" == "codex" || "$TARGET" == "both" ]]; then
    cat <<EOF
  - codex: $CODEX_SKILLS_DIR
  - codex hooks: $CODEX_CONFIG_DIR/hooks.json
EOF
fi

if [[ "$TARGET" == "hermes" ]]; then
    cat <<EOF
  - hermes: $HERMES_SKILLS_DIR
  - hermes hooks: $HERMES_CONFIG_DIR/config.yaml
EOF
fi

cat <<EOF

Runtime root per target:
  <skills-dir>/humanize

Codex installs also update native hook/config state in:
  $CODEX_CONFIG_DIR

Hermes installs update native pre_verify hook/config state in:
  $HERMES_CONFIG_DIR

No shell profile changes were made.
If $COMMAND_BIN_DIR is on PATH, the bitlesson-selector shim is now available there.
EOF
