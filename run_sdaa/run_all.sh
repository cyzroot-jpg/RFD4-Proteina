#!/usr/bin/env bash
# Full SDAA/CUDA pipeline orchestrator, detached-friendly.
#
# For every task: generate -> offline evaluate -> aggregate. Then summarize.
# Survives session close when launched with:
#   ( setsid nohup bash run_sdaa/run_all.sh > run_sdaa/logs/run_all.log 2>&1 < /dev/null & )
#
# env: OUT_ROOT=<base> (default run_sdaa/results), PLATFORM=auto, SEED=1234,
#      CKPT=nvidia/RFD4-Proteina, EVAL=1, RESUME=1 (allow non-empty output root)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-0}"

ROOT_DIR="$REPO_ROOT/run_sdaa"
OUT_ROOT="${OUT_ROOT:-$ROOT_DIR/results}"
PLATFORM="${PLATFORM:-auto}"
SEED="${SEED:-1234}"
CKPT="${CKPT:-nvidia/RFD4-Proteina}"
EVAL="${EVAL:-1}"
DEVICE_OFFSET="${DEVICE_OFFSET:-0}"
PYTHON="${PYTHON:-python3}"
LOGS="$ROOT_DIR/logs"

detect_platform() {
  if [[ -n "${PLATFORM:-}" && "${PLATFORM}" != auto ]]; then
    printf '%s\n' "$PLATFORM"; return
  fi
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    printf 'cuda\n'; return
  fi
  if command -v teco-smi >/dev/null 2>&1; then
    printf 'sdaa\n'; return
  fi
  printf 'cpu\n'
}
if [[ "$PLATFORM" == auto ]]; then PLATFORM="$(detect_platform)"; fi

# Cross-platform comparison requires the SDAA random stream to match CUDA A100.
# `torch.sdaa.random_align_nv_device()` only *queries* this; the env var is what
# actually enables it. Default to a100 on SDAA so the pipeline is comparable
# with a CUDA run unless the caller explicitly set another value.
if [[ "$PLATFORM" == sdaa && -z "${TORCH_SDAA_ALIGN_NV_DEVICE:-}" ]]; then
  export TORCH_SDAA_ALIGN_NV_DEVICE=a100
  echo "[rng] TORCH_SDAA_ALIGN_NV_DEVICE unset; defaulting to a100 (CUDA A100 stream)"
fi

RUN_ROOT="$OUT_ROOT/$PLATFORM"
mkdir -p "$LOGS" "$OUT_ROOT"
if [[ -d "$RUN_ROOT" && -n "$(ls -A "$RUN_ROOT" 2>/dev/null)" && "${RESUME:-0}" != 1 ]]; then
  echo "$RUN_ROOT is not empty; choose a fresh OUT_ROOT or set RESUME=1." >&2
  exit 2
fi
mkdir -p "$RUN_ROOT"

HF_REVISION="$(grep -m1 '^hf_ckpt_revision:' configs/inference.yaml | awk '{print $2}')"
CKPT_PATH="$("$PYTHON" - <<'PY'
try:
    from huggingface_hub import snapshot_download
    print(snapshot_download("nvidia/RFD4-Proteina",
                            revision="a06e2509c7033b010fc43614e9fd840303588502",
                            local_files_only=True))
except Exception:
    pass
PY
)"
CKPT_SHA=""
if [[ -n "$CKPT_PATH" && -f "$CKPT_PATH/model.safetensors" ]]; then
  CKPT_SHA="$(sha256sum "$CKPT_PATH/model.safetensors" | cut -d' ' -f1)"
fi

{
  printf 'platform=%s\n' "$PLATFORM"
  printf 'seed=%s\n' "$SEED"
  printf 'ckpt=%s\n' "$CKPT"
  printf 'hf_ckpt_revision=%s\n' "$HF_REVISION"
  printf 'ckpt_snapshot=%s\n' "$CKPT_PATH"
  printf 'ckpt_model_safetensors_sha256=%s\n' "$CKPT_SHA"
  printf 'git_commit=%s\n' "$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  printf 'git_dirty_total=%s\n' "$(git status --porcelain | wc -l)"
  printf 'git_dirty_src_configs=%s\n' "$(git status --porcelain src configs | wc -l)"
  printf 'torch_sdaa_align_nv_device=%s\n' "${TORCH_SDAA_ALIGN_NV_DEVICE:-unset}"
  printf 'plan_a=%s\n' "${PLAN_A:-0}"
  printf 'ablate=%s\n' "${ABLATE:-none}"
  printf 'tasks=%s\n' "${TASKS[*]}"
  printf 'seeds=%s\n' "${SEEDS:-$SEED}"
  printf 'replicates=%s\n' "${REPLICATES:-default}"
  printf 'ppi_subset=%s\n' "${PPI_SUBSET:-none}"
  printf 'nsteps=%s\n' "${NSTEPS:-default}"
  printf 'device_offset=%s\n' "$DEVICE_OFFSET"
  printf 'eval=%s\n' "$EVAL"
  printf 'out_root=%s\n' "$RUN_ROOT"
  printf 'python=%s\n' "$("$PYTHON" -c 'import platform; print(platform.python_version())' 2>/dev/null)"
  printf 'torch=%s\n' "$("$PYTHON" -c 'import torch; print(torch.__version__)' 2>/dev/null | tail -1)"
  printf 'torch_sdaa=%s\n' "$("$PYTHON" -c 'import torch_sdaa; print(torch_sdaa.__version__)' 2>/dev/null | tail -1)"
  printf 'foldseek=%s\n' "$(command -v foldseek || echo absent)"
  printf 'apptainer=%s\n' "$(command -v apptainer || echo absent)"
  printf 'start=%s\n' "$(date -Is)"
} > "$RUN_ROOT/run_env.txt"

{
  echo "# Pipeline: generate (official inline metrics) -> offline evaluate -> aggregate"
  echo "# Tasks: monomer-{short,medium,long}, motif-1BCF, ppi-pdl1 (official ppi_bb_only/pdl1.cif.zst)"
  echo "# Per-task commands are stored in <task>/command.txt"
  echo "# common overrides:"
  echo "#   inference_experiment=inference_on_user_inputs compile_lengths=null seed=$SEED batch_size=1"
  echo "#   precision=bf16-mixed job_id=0 save_chain_of_interest=true hf_ckpt_path=$CKPT"
  echo "#   metrics/inline_metrics=all_inline_metrics_no_rosetta"
} > "$RUN_ROOT/command.txt"

sha256sum "$ROOT_DIR"/*.sh "$ROOT_DIR"/*.py > "$RUN_ROOT/scripts.sha256" 2>/dev/null || true

# RNG probe: lets the two platforms compare their random streams directly.
case "$PLATFORM" in
  sdaa)
    "$PYTHON" - 2>/dev/null <<'RNGEOF' | grep -E '^(aligned|randn5):' > "$RUN_ROOT/rng_probe.txt" || true
import torch, torch_sdaa
print("aligned:", torch.sdaa.random_align_nv_device())
torch.sdaa.manual_seed(1234)
print("randn5:", torch.randn(5, device="sdaa").tolist())
RNGEOF
    ;;
  cuda)
    "$PYTHON" - 2>/dev/null <<'RNGEOF' | grep -E '^(randn5):' > "$RUN_ROOT/rng_probe.txt" || true
import torch
torch.manual_seed(1234)
torch.cuda.manual_seed_all(1234)
print("randn5:", torch.randn(5, device="cuda").tolist())
RNGEOF
    ;;
esac

# Fail fast: an unaligned stream makes every cross-platform comparison invalid.
if [[ "$PLATFORM" == sdaa ]] && ! grep -qx 'aligned: True' "$RUN_ROOT/rng_probe.txt" 2>/dev/null; then
  if [[ "${ALLOW_UNALIGNED_RNG:-0}" == 1 ]]; then
    echo "WARNING: SDAA RNG is not aligned to CUDA; continuing (ALLOW_UNALIGNED_RNG=1)" >&2
  else
    echo "ERROR: SDAA RNG is not aligned to CUDA ($RUN_ROOT/rng_probe.txt)." >&2
    echo "       Set TORCH_SDAA_ALIGN_NV_DEVICE=a100 (or ALLOW_UNALIGNED_RNG=1 to override)." >&2
    exit 3
  fi
fi

case "$PLATFORM" in
  sdaa) NSLOTS="$(teco-smi -L 2>/dev/null | wc -l)" ;;
  cuda) NSLOTS="$(nvidia-smi -L 2>/dev/null | wc -l)" ;;
  *)    NSLOTS=1 ;;
esac
[[ "$NSLOTS" -ge 1 ]] || NSLOTS=1

read -r -a TASKS <<< "${TASKS:-monomer-short monomer-medium monomer-long motif-1BCF ppi-pdl1}"
read -r -a SEEDS_ARR <<< "${SEEDS:-$SEED}"

echo "== pipeline start $(date -Is) platform=$PLATFORM slots=$NSLOTS out=$RUN_ROOT"
echo "   tasks=${TASKS[*]} seeds=${SEEDS_ARR[*]} replicates=${REPLICATES:-default} ppi_subset=${PPI_SUBSET:-none}"
pids=()
labels=()
idx=0
for task in "${TASKS[@]}"; do
  for s in "${SEEDS_ARR[@]}"; do
    if [[ ${#SEEDS_ARR[@]} -gt 1 ]]; then
      label="$task.seed$s"; seed_tag="seed$s"
    else
      label="$task"; seed_tag=""
    fi
    OUT_ROOT="$OUT_ROOT" PLATFORM="$PLATFORM" DEVICE="$(((idx + DEVICE_OFFSET) % NSLOTS))" SEED="$s" CKPT="$CKPT" EVAL="$EVAL" \
    SEED_TAG="$seed_tag" REPLICATES="${REPLICATES:-}" PPI_SUBSET="${PPI_SUBSET:-}" NSTEPS="${NSTEPS:-}" \
    PLAN_A="${PLAN_A:-0}" ABLATE="${ABLATE:-}" \
      bash "$ROOT_DIR/run_task.sh" "$task" > "$LOGS/$label.log" 2>&1 &
    pids+=("$!")
    labels+=("$label")
    idx=$((idx + 1))
  done
done

status_file="$RUN_ROOT/status.txt"
: > "$status_file"
failed=0
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    echo "PASS ${labels[$i]}" | tee -a "$status_file"
  else
    echo "FAIL ${labels[$i]}" | tee -a "$status_file"
    failed=1
  fi
done

printf 'end=%s\n' "$(date -Is)" >> "$RUN_ROOT/run_env.txt"

if [[ "$failed" == 0 ]]; then
  if [[ ${#SEEDS_ARR[@]} -eq 1 ]]; then
    "$PYTHON" "$ROOT_DIR/summarize.py" "$RUN_ROOT" 2>&1 | tee "$RUN_ROOT/summarize.log"
  else
    echo "multi-seed run: skipping summarize.py (per-seed dirs); see $RUN_ROOT/<task>/seed*/" | tee "$RUN_ROOT/summarize.log"
  fi
  echo "DONE $(date -Is)" > "$RUN_ROOT/DONE"
else
  echo "FAILED $(date -Is)" > "$RUN_ROOT/FAILED"
fi
echo "== pipeline end $(date -Is)"