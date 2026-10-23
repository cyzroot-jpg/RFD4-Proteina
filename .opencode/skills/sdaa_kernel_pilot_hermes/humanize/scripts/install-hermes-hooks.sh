#!/usr/bin/env bash
#
# Install KernelPilot Hermes shell hooks into ~/.hermes/config.yaml.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DEFAULT_RUNTIME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HERMES_CONFIG_DIR="${HERMES_HOME:-${HOME}/.hermes}"
RUNTIME_ROOT="$DEFAULT_RUNTIME_ROOT"
DRY_RUN="false"

usage() {
    cat <<'EOF'
Usage: install-hermes-hooks.sh [--hermes-config-dir PATH] [--runtime-root PATH] [--dry-run]

Installs the KernelPilot Hermes pre_verify shell hook. The hook itself is
short-running and only instructs Hermes to run the foreground RLCR stop gate.
EOF
}

log() {
    printf '[install-hermes-hooks] %s\n' "$*"
}

die() {
    printf '[install-hermes-hooks] Error: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hermes-config-dir)
            [[ -n "${2:-}" ]] || die "--hermes-config-dir requires a value"
            HERMES_CONFIG_DIR="$2"
            shift 2
            ;;
        --runtime-root)
            [[ -n "${2:-}" ]] || die "--runtime-root requires a value"
            RUNTIME_ROOT="$2"
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

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$RUNTIME_ROOT" != /* ]]; then
        RUNTIME_ROOT="$(pwd)/$RUNTIME_ROOT"
    fi
else
    RUNTIME_ROOT="$(cd "$RUNTIME_ROOT" 2>/dev/null && pwd || true)"
    [[ -n "$RUNTIME_ROOT" ]] || die "runtime root not found"
fi

HOOK_SCRIPT="$RUNTIME_ROOT/hooks/loop-hermes-pre-verify-hook.sh"
if [[ "$DRY_RUN" != "true" ]]; then
    [[ -f "$HOOK_SCRIPT" ]] || die "Hermes pre_verify hook script not found: $HOOK_SCRIPT"
fi

CONFIG_FILE="$HERMES_CONFIG_DIR/config.yaml"
ALLOWLIST_FILE="$HERMES_CONFIG_DIR/shell-hooks-allowlist.json"
HOOK_COMMAND="bash $(python3 - "$HOOK_SCRIPT" <<'PY'
import shlex
import sys
print(shlex.quote(sys.argv[1]))
PY
)"
HOOK_TIMEOUT=3600

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN install Hermes pre_verify hook"
    log "config: $CONFIG_FILE"
    log "allowlist: $ALLOWLIST_FILE"
    log "command: $HOOK_COMMAND"
    log "timeout: $HOOK_TIMEOUT"
    exit 0
fi

mkdir -p "$HERMES_CONFIG_DIR"

python3 - "$CONFIG_FILE" "$ALLOWLIST_FILE" "$HOOK_COMMAND" "$HOOK_SCRIPT" "$HOOK_TIMEOUT" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

try:
    import yaml
except ImportError:
    print("PyYAML is required to update Hermes config.yaml", file=sys.stderr)
    raise SystemExit(2)

config_file = pathlib.Path(sys.argv[1])
allowlist_file = pathlib.Path(sys.argv[2])
hook_command = sys.argv[3]
hook_script = pathlib.Path(sys.argv[4])
timeout = int(sys.argv[5])

if config_file.exists():
    raw = config_file.read_text(encoding="utf-8")
    data = yaml.safe_load(raw) if raw.strip() else {}
else:
    data = {}
if not isinstance(data, dict):
    data = {}

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = {}
data["hooks"] = hooks

pre_verify = hooks.get("pre_verify")
if not isinstance(pre_verify, list):
    pre_verify = []

managed_name = "loop-hermes-pre-verify-hook.sh"
pre_verify = [
    entry for entry in pre_verify
    if not (
        isinstance(entry, dict)
        and managed_name in str(entry.get("command", ""))
    )
]
pre_verify.append({"command": hook_command, "timeout": timeout})
hooks["pre_verify"] = pre_verify

config_file.write_text(
    yaml.safe_dump(data, sort_keys=False, allow_unicode=True),
    encoding="utf-8",
)

try:
    allowlist = json.loads(allowlist_file.read_text(encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError):
    allowlist = {"approvals": []}
if not isinstance(allowlist, dict):
    allowlist = {"approvals": []}
approvals = allowlist.get("approvals")
if not isinstance(approvals, list):
    approvals = []

approvals = [
    entry for entry in approvals
    if not (
        isinstance(entry, dict)
        and entry.get("event") == "pre_verify"
        and entry.get("command") == hook_command
    )
]
mtime = datetime.fromtimestamp(hook_script.stat().st_mtime, timezone.utc).isoformat().replace("+00:00", "Z")
approvals.append({
    "event": "pre_verify",
    "command": hook_command,
    "approved_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "script_mtime_at_approval": mtime,
})
allowlist["approvals"] = approvals
allowlist_file.write_text(json.dumps(allowlist, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

log "installed Hermes pre_verify hook into: $CONFIG_FILE"
log "approved Hermes shell hook in: $ALLOWLIST_FILE"
