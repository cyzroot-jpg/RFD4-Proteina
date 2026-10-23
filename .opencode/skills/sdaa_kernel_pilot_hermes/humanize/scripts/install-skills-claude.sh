#!/usr/bin/env bash
# Install KernelPilot Humanize for Claude Code and expose teco-ops-wiki as the
# exclusive external knowledge skill.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HUMANIZE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNELPILOT_ROOT="$(cd "$HUMANIZE_ROOT/.." && pwd)"
TECO_OPS_WIKI_ROOT="${TECO_OPS_WIKI_ROOT:-}"
CLAUDE_BIN="${CLAUDE_BIN:-}"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
INSTALL_PIP="true"
DISABLE_POLYARCH="true"
DRY_RUN="false"

usage() {
    cat <<'EOF'
Usage: humanize/scripts/install-skills-claude.sh [options]

Options:
  --kernelpilot-root PATH     KernelPilot checkout root.
  --teco-ops-wiki-root PATH   Exclusive wiki root (default: external/teco-ops-wiki).
  --claude-bin PATH           Claude Code binary.
  --claude-config-dir PATH    Claude config directory (default: ~/.claude).
  --skip-pip                  Skip wiki Python dependency installation.
  --keep-polyarch-enabled     Keep an existing humanize@PolyArch enabled.
  --dry-run                   Print operations without writing.
  -h, --help                  Show this help.
EOF
}

log() { printf '[install-claude-skills] %s\n' "$*"; }
die() { printf '[install-claude-skills] Error: %s\n' "$*" >&2; exit 1; }

sync_dir() {
    local src="$1" dst="$2"
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN sync $src -> $dst"
        return
    fi
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --exclude '.git' "$src/" "$dst/"
    else
        cp -a "$src/." "$dst/"
    fi
}

link_skill() {
    local name="$1" target="$2" link_path="$CLAUDE_CONFIG_DIR/skills/$1"
    [[ -f "$target/SKILL.md" ]] || die "$name skill not found: $target/SKILL.md"
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN link $link_path -> $target"
        return
    fi
    mkdir -p "$CLAUDE_CONFIG_DIR/skills"
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
    elif [[ -e "$link_path" ]]; then
        die "$link_path exists and is not a symlink"
    fi
    ln -s "$target" "$link_path"
}

remove_retired_links() {
    local name path
    for name in KernelWiki SDAAKernelWiki ncu-report-skill optest-skill gemm-performance-modeling kernel-bench tecoal-op-test tecolmk-op-test; do
        path="$CLAUDE_CONFIG_DIR/skills/$name"
        [[ -e "$path" || -L "$path" ]] || continue
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN remove retired installed skill: $path"
        elif [[ -L "$path" ]]; then
            rm "$path"
        else
            die "$path is a real directory; remove or archive it explicitly before migration"
        fi
    done
}

hydrate_plugin_cache() {
    local plugin_root="$1" path tmp
    [[ "$DRY_RUN" == "true" ]] && { log "DRY-RUN hydrate $plugin_root/skills"; return; }
    while IFS= read -r path; do
        tmp="$(mktemp)"
        _HUMANIZE_ROOT="$plugin_root" \
        _KERNELPILOT_ROOT="$KERNELPILOT_ROOT" \
        _TECO_OPS_WIKI_ROOT="$TECO_OPS_WIKI_ROOT" \
            awk '{
                gsub(/\{\{HUMANIZE_RUNTIME_ROOT\}\}/, ENVIRON["_HUMANIZE_ROOT"]);
                gsub(/\{\{KERNELPILOT_ROOT\}\}/, ENVIRON["_KERNELPILOT_ROOT"]);
                gsub(/\{\{TECO_OPS_WIKI_ROOT\}\}/, ENVIRON["_TECO_OPS_WIKI_ROOT"]);
                print
            }' "$path" > "$tmp"
        mv "$tmp" "$path"
    done < <(find "$plugin_root/skills" -name 'SKILL*.md' -type f)
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernelpilot-root) KERNELPILOT_ROOT="${2:?missing value}"; shift 2 ;;
        --teco-ops-wiki-root) TECO_OPS_WIKI_ROOT="${2:?missing value}"; shift 2 ;;
        --claude-bin) CLAUDE_BIN="${2:?missing value}"; shift 2 ;;
        --claude-config-dir) CLAUDE_CONFIG_DIR="${2:?missing value}"; shift 2 ;;
        --skip-pip) INSTALL_PIP="false"; shift ;;
        --keep-polyarch-enabled) DISABLE_POLYARCH="false"; shift ;;
        --dry-run) DRY_RUN="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

KERNELPILOT_ROOT="$(cd "$KERNELPILOT_ROOT" 2>/dev/null && pwd || true)"
[[ -f "$KERNELPILOT_ROOT/.claude-plugin/marketplace.json" ]] || die "invalid KernelPilot root"

if [[ -z "$TECO_OPS_WIKI_ROOT" ]]; then
    TECO_OPS_WIKI_ROOT="$KERNELPILOT_ROOT/external/teco-ops-wiki"
fi
TECO_OPS_WIKI_ROOT="$(cd "$TECO_OPS_WIKI_ROOT" 2>/dev/null && pwd || true)"
[[ -f "$TECO_OPS_WIKI_ROOT/SKILL.md" ]] || die "teco-ops-wiki skill is missing"
[[ -f "$TECO_OPS_WIKI_ROOT/scripts/query.py" ]] || die "teco-ops-wiki query tool is missing"
[[ -f "$TECO_OPS_WIKI_ROOT/scripts/get_page.py" ]] || die "teco-ops-wiki page tool is missing"
[[ -d "$TECO_OPS_WIKI_ROOT/wiki" ]] || die "teco-ops-wiki pages are missing"


if [[ -z "$CLAUDE_BIN" ]]; then
    CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
fi
[[ "$DRY_RUN" == "true" || -x "$CLAUDE_BIN" ]] || die "Claude Code CLI not found"

VERSION="$(python3 - "$HUMANIZE_ROOT/.claude-plugin/plugin.json" <<'PY'
import json, pathlib, sys
print(json.loads(pathlib.Path(sys.argv[1]).read_text())["version"])
PY
)"
PLUGIN_ROOT="$CLAUDE_CONFIG_DIR/plugins/cache/KernelPilot/humanize/$VERSION"

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN install humanize@KernelPilot"
else
    (cd "$KERNELPILOT_ROOT" && "$CLAUDE_BIN" plugin marketplace add ./ >/dev/null 2>&1 || "$CLAUDE_BIN" plugin marketplace update KernelPilot)
    "$CLAUDE_BIN" plugin install humanize@KernelPilot >/dev/null 2>&1 || "$CLAUDE_BIN" plugin update humanize@KernelPilot
    [[ "$DISABLE_POLYARCH" == "false" ]] || "$CLAUDE_BIN" plugin disable humanize@PolyArch >/dev/null 2>&1 || true
fi

sync_dir "$HUMANIZE_ROOT" "$PLUGIN_ROOT"
remove_retired_links
link_skill "teco-ops-wiki" "$TECO_OPS_WIKI_ROOT"
hydrate_plugin_cache "$PLUGIN_ROOT"

if [[ "$INSTALL_PIP" == "true" && -f "$TECO_OPS_WIKI_ROOT/requirements.txt" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY-RUN python3 -m pip install -r $TECO_OPS_WIKI_ROOT/requirements.txt"
    else
        python3 -m pip install -r "$TECO_OPS_WIKI_ROOT/requirements.txt"
    fi
fi

if [[ "$DRY_RUN" != "true" ]] && grep -R '{{TECO_OPS_WIKI_ROOT}}' "$PLUGIN_ROOT/skills" >/dev/null 2>&1; then
    die "unhydrated teco-ops-wiki placeholder remains"
fi

log "installed humanize@KernelPilot $VERSION"
log "exclusive wiki: $CLAUDE_CONFIG_DIR/skills/teco-ops-wiki -> $TECO_OPS_WIKI_ROOT"
