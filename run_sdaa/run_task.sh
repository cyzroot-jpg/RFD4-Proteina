#!/usr/bin/env bash
# One task end-to-end: official generate -> official offline evaluate -> official aggregate.
#
# usage: bash run_sdaa/run_task.sh <task>
# env:   OUT_ROOT (required), PLATFORM=auto|sdaa|cuda|cpu, DEVICE=<slot>, SEED=1234,
#        CKPT=<repo id|snapshot>, EVAL=1, DEVICE_STRIDE=<override>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-0}"

TASK="${1:?usage: run_task.sh <monomer-short|monomer-medium|monomer-long|motif-1BCF|ppi-pdl1>}"
PLATFORM="${PLATFORM:-auto}"
DEVICE="${DEVICE:-0}"
DEVICE_STRIDE="${DEVICE_STRIDE:-}"
SEED="${SEED:-1234}"
CKPT="${CKPT:-nvidia/RFD4-Proteina}"
OUT_ROOT="${OUT_ROOT:?OUT_ROOT must be set}"
EVAL="${EVAL:-1}"
PYTHON="${PYTHON:-python3}"

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

# Match the CUDA A100 RNG stream so results are comparable across platforms.
if [[ "$PLATFORM" == sdaa && -z "${TORCH_SDAA_ALIGN_NV_DEVICE:-}" ]]; then
  export TORCH_SDAA_ALIGN_NV_DEVICE=a100
  echo "[rng] TORCH_SDAA_ALIGN_NV_DEVICE unset; defaulting to a100 (CUDA A100 stream)"
fi

case "$TASK" in
  monomer-short)  INPUT=data/benchmarks/monomer/monomer-short.cif.zst;                   REPS=8; TAGS='[design,developability]' ;;
  monomer-medium) INPUT=data/benchmarks/monomer/monomer-medium.cif.zst;                  REPS=6; TAGS='[design,developability]' ;;
  monomer-long)   INPUT=data/benchmarks/monomer/monomer-long.cif.zst;                    REPS=4; TAGS='[design,developability]' ;;
  motif-1BCF)     INPUT=data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst; REPS=8; TAGS='[design,developability,3d_coordinate_conditioning]' ;;
  ppi-pdl1)       INPUT=data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst;                    REPS=6; TAGS='[design,developability,interchain_interactions]' ;;
  *) echo "unknown task: $TASK" >&2; exit 2 ;;
esac

SEED_TAG="${SEED_TAG:-}"
PPI_SUBSET="${PPI_SUBSET:-}"
NSTEPS="${NSTEPS:-}"
INPUT="${INPUT_OVERRIDE:-$INPUT}"
if [[ -n "${REPLICATES:-}" ]]; then REPS="$REPLICATES"; fi
if [[ -n "$PPI_SUBSET" && "$TASK" != ppi-* ]]; then
  echo "PPI_SUBSET is only valid for a ppi-* task, got TASK=$TASK" >&2; exit 2
fi

# DEVICE is a slot: on SDAA a physical card exposes several logical devices.
PRECISION="bf16-mixed"
EXTRA_OVERRIDES=()
case "$PLATFORM" in
  sdaa)
    if [[ -z "$DEVICE_STRIDE" ]]; then
      logical="$(ls /dev/tcaicard* 2>/dev/null | wc -l)"
      physical="$(teco-smi -L 2>/dev/null | wc -l)"
      if [[ "$logical" -gt 0 && "$physical" -gt 0 && $((logical % physical)) -eq 0 ]]; then
        DEVICE_STRIDE=$((logical / physical))
      else
        DEVICE_STRIDE=1
      fi
    fi
    PLATFORM_DEVICE=$((DEVICE * DEVICE_STRIDE))
    DEVICE_VAR=SDAA_VISIBLE_DEVICES
    export SDAA_VISIBLE_DEVICES="$PLATFORM_DEVICE"
    ;;
  cuda)
    DEVICE_STRIDE="${DEVICE_STRIDE:-1}"
    PLATFORM_DEVICE=$((DEVICE * DEVICE_STRIDE))
    DEVICE_VAR=CUDA_VISIBLE_DEVICES
    export CUDA_VISIBLE_DEVICES="$PLATFORM_DEVICE"
    ;;
  cpu)
    DEVICE_STRIDE="${DEVICE_STRIDE:-1}"
    PLATFORM_DEVICE="$DEVICE"
    DEVICE_VAR=cpu
    PRECISION="32"
    EXTRA_OVERRIDES+=("hardware.accelerator=cpu")
    ;;
  *) echo "unknown PLATFORM: $PLATFORM" >&2; exit 2 ;;
esac

PLAN_A="${PLAN_A:-0}"
ABLATE="${ABLATE:-}"
if [[ "$PLAN_A" == 1 && -z "$ABLATE" ]]; then
  ABLATE=force_einsum
fi
GEN=("$PYTHON" -u -m rfproteina.generate)
if [[ -n "$ABLATE" ]]; then
  GEN=("$PYTHON" -u "$REPO_ROOT/run_sdaa/experiments/ablate.py")
  EXTRA_OVERRIDES+=("nn.tri_mult_backend=torch" "torch_deterministic=true")
fi

BASE_OVERRIDES=(
  inference_experiment=inference_on_user_inputs
  compile_lengths=null
  seed="$SEED"
  batch_size=1
  precision="$PRECISION"
  job_id=0
  save_chain_of_interest=true
  hf_ckpt_path="$CKPT"
  metrics/inline_metrics=all_inline_metrics_no_rosetta
  ${EXTRA_OVERRIDES[@]+"${EXTRA_OVERRIDES[@]}"}
)
if [[ -n "$NSTEPS" ]]; then
  BASE_OVERRIDES+=(
    "generation.n_recycle_schedule=[[${NSTEPS},2]]"
    "generation.args.nsteps=${NSTEPS}"
  )
fi

RUN_ROOT="$OUT_ROOT/$PLATFORM"
RUN_DIR="$RUN_ROOT/$TASK"
[[ -n "$SEED_TAG" ]] && RUN_DIR="$RUN_DIR/$SEED_TAG"
mkdir -p "$RUN_DIR"

# PPI subset mode: run the official val-set config (multiple targets) instead of
# a single input file, with num_replicates taken from REPLICATES.
GEN_ARGS=()
if [[ -n "$PPI_SUBSET" ]]; then
  GEN_ARGS=(
    inference_experiment=inference_on_val_set
    "+datasets/val@generation=ppi/ppi_bb_only_subset_${PPI_SUBSET}"
    "run_name_=${TASK}_subset${PPI_SUBSET}_seed${SEED}"
    compile_lengths=null
    seed="$SEED"
    batch_size=1
    precision="$PRECISION"
    job_id=0
    save_chain_of_interest=true
    hf_ckpt_path="$CKPT"
    metrics/inline_metrics=all_inline_metrics_no_rosetta
    "generation.dataset.num_replicates=$REPS"
    "generation.dataset.transform.metrics_tags=[design,developability,3d_coordinate_conditioning,hotspot_conditioning,interchain_interactions]"
    ${EXTRA_OVERRIDES[@]+"${EXTRA_OVERRIDES[@]}"}
  )
  if [[ -n "$NSTEPS" ]]; then
    GEN_ARGS+=(
      "generation.n_recycle_schedule=[[${NSTEPS},2]]"
      "generation.args.nsteps=${NSTEPS}"
    )
  fi
else
  GEN_ARGS=(
    "${BASE_OVERRIDES[@]}"
    inputs="$INPUT"
    num_replicates="$REPS"
    "metrics_tags=$TAGS"
  )
fi

{
  printf 'task=%s\n' "$TASK"
  printf 'platform=%s\n' "$PLATFORM"
  printf 'device_slot=%s\n' "$DEVICE"
  printf '%s=%s\n' "$DEVICE_VAR" "$PLATFORM_DEVICE"
  if [[ -n "$PPI_SUBSET" ]]; then
    printf 'input=ppi/ppi_bb_only_subset_%s\n' "$PPI_SUBSET"
  else
    printf 'input=%s\n' "$INPUT"
  fi
  printf 'num_replicates=%s\n' "$REPS"
  printf 'metrics_tags=%s\n' "$TAGS"
  printf 'seed=%s\n' "$SEED"
  printf 'seed_tag=%s\n' "${SEED_TAG:-none}"
  printf 'nsteps=%s\n' "${NSTEPS:-default}"
  printf 'ckpt=%s\n' "$CKPT"
  printf 'torch_sdaa_align_nv_device=%s\n' "${TORCH_SDAA_ALIGN_NV_DEVICE:-unset}"
  printf 'plan_a=%s\n' "$PLAN_A"
  printf 'ablate=%s\n' "${ABLATE:-none}"
  printf 'start=%s\n' "$(date -Is)"
} > "$RUN_DIR/task_env.txt"

{
  printf '%q ' "${GEN[@]}"
  printf '%q ' "${GEN_ARGS[@]}"
  printf ' out_dir=%q\n' "$RUN_DIR"
} > "$RUN_DIR/command.txt"

echo "[$TASK] generate on $DEVICE_VAR=$PLATFORM_DEVICE (plan_a=$PLAN_A ablate=${ABLATE:-none} subset=${PPI_SUBSET:-none} reps=$REPS seed=$SEED)"
"${GEN[@]}" \
  "${GEN_ARGS[@]}" \
  out_dir="$RUN_DIR" \
  2>&1 | tee "$RUN_DIR/generate.log"

if [[ "$EVAL" == 1 ]]; then
  # evaluate.py scans inputs recursively; inference_samples also holds
  # foldseek_input_chains/, which would be scored as duplicate designs. Stage
  # symlinks to the generated CIFs only.
  if ! find "$RUN_DIR/inference_samples" -type f -name "*_generated.cif" -print -quit 2>/dev/null | grep -q .; then
    echo "[$TASK] no generated CIF; skipping offline evaluate"
  else
  echo "[$TASK] offline evaluate"
  EVAL_INPUTS="$RUN_DIR/eval_inputs"
  rm -rf "$EVAL_INPUTS"
  mkdir -p "$EVAL_INPUTS"
  ( cd "$RUN_DIR/inference_samples" && find . -type f -name "*_generated.cif" -print0 |
      while IFS= read -r -d "" f; do
        mkdir -p "$EVAL_INPUTS/$(dirname "$f")"
        ln -s "$(realpath "$f")" "$EVAL_INPUTS/$f"
      done )
  "$PYTHON" -u -m rfproteina.evaluate \
    inputs="$EVAL_INPUTS" \
    "metrics_tags=${EVAL_TAGS:-$TAGS}" \
    metrics/inline_metrics=all_inline_metrics_no_rosetta \
    job_id=0 \
    out_dir="$RUN_DIR/evaluation" \
    2>&1 | tee "$RUN_DIR/evaluate.log"
  rm -rf "$EVAL_INPUTS"
  fi
fi

echo "[$TASK] aggregate metrics"
for metrics_dir in "$RUN_DIR/inference_metrics" "$RUN_DIR/evaluation/evaluation_metrics"; do
  [[ -d "$metrics_dir" ]] || continue
  "$PYTHON" -m rfproteina.inference_utils.aggregate_metrics --input="$metrics_dir" \
    >> "$RUN_DIR/aggregate.log" 2>&1 || echo "[$TASK] aggregate failed for $metrics_dir" | tee -a "$RUN_DIR/aggregate.log"
done

printf 'end=%s\n' "$(date -Is)" >> "$RUN_DIR/task_env.txt"
echo "[$TASK] done"