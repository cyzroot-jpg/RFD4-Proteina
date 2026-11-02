#!/usr/bin/env bash
# Plan A: force the SAME numerical path on SDAA and CUDA.
#   - explicit einsum attention        (RFPROTEINA_ABLATE=force_einsum)
#   - torch triangle multiplication    (nn.tri_mult_backend=torch)
#   - deterministic kernels            (torch_deterministic=true)
#
# Run the SAME command on the CUDA host into a fresh OUT_ROOT, then compare with
# the SDAA aligned results using run_e1.sh / compare_designs.py.
#
# usage:
#   OUT_ROOT=<dir> bash run_sdaa/experiments/run_plan_a.sh            # all 5 tasks
#   OUT_ROOT=<dir> bash run_sdaa/experiments/run_plan_a.sh ppi-pdl1  # one task
# env:
#   OUT_ROOT (required), DEVICE (default 0), SEED (default 1234),
#   CKPT, PYTHON, NSTEPS (default 60, for smoke tests)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$HERE"
while [[ "$REPO_ROOT" != "/" && ! -f "$REPO_ROOT/pyproject.toml" ]]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

OUT_ROOT="${OUT_ROOT:?OUT_ROOT must be set}"
DEVICE="${DEVICE:-0}"
SEED="${SEED:-1234}"
CKPT="${CKPT:-nvidia/RFD4-Proteina}"
PYTHON="${PYTHON:-python3}"
NSTEPS="${NSTEPS:-60}"

DEVICE_STRIDE="${DEVICE_STRIDE:-}"
if command -v nvidia-smi >/dev/null 2>&1; then
  PLATFORM=cuda
  DEVICE_STRIDE="${DEVICE_STRIDE:-1}"
  export CUDA_VISIBLE_DEVICES="$((DEVICE * DEVICE_STRIDE))"
else
  PLATFORM=sdaa
  if [[ -z "$DEVICE_STRIDE" ]]; then
    logical="$(ls /dev/tcaicard* 2>/dev/null | wc -l)"
    physical="$(teco-smi -L 2>/dev/null | wc -l)"
    if [[ "$logical" -gt 0 && "$physical" -gt 0 && $((logical % physical)) -eq 0 ]]; then
      DEVICE_STRIDE=$((logical / physical))
    else
      DEVICE_STRIDE=1
    fi
  fi
  export SDAA_VISIBLE_DEVICES="$((DEVICE * DEVICE_STRIDE))"
fi

case "$NSTEPS" in
  60) SCHEDULE=() ;;
  *)  SCHEDULE=("generation.n_recycle_schedule=[[${NSTEPS},2]]") ;;
esac

TASKS=("$@")
if [[ ${#TASKS[@]} -eq 0 ]]; then
  TASKS=(monomer-short monomer-medium monomer-long motif-1BCF ppi-pdl1)
fi

mkdir -p "$OUT_ROOT"

for task in "${TASKS[@]}"; do
  case "$task" in
    monomer-short)  INPUT=data/benchmarks/monomer/monomer-short.cif.zst;                   REPS=8; TAGS='[design,developability]' ;;
    monomer-medium) INPUT=data/benchmarks/monomer/monomer-medium.cif.zst;                  REPS=6; TAGS='[design,developability]' ;;
    monomer-long)   INPUT=data/benchmarks/monomer/monomer-long.cif.zst;                    REPS=4; TAGS='[design,developability]' ;;
    motif-1BCF)     INPUT=data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst; REPS=8; TAGS='[design,developability,3d_coordinate_conditioning]' ;;
    ppi-pdl1)       INPUT=data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst;                    REPS=6; TAGS='[design,developability,interchain_interactions]' ;;
    *) echo "unknown task: $task" >&2; exit 2 ;;
  esac
  run_dir="$OUT_ROOT/$task"
  mkdir -p "$run_dir"
  START="$(date -Is)"
  echo "== $task ($PLATFORM, device $DEVICE, Plan A)"
  RFPROTEINA_ABLATE=force_einsum "$PYTHON" -u "$HERE/ablate.py" \
    inference_experiment=inference_on_user_inputs \
    compile_lengths=null \
    seed="$SEED" \
    batch_size=1 \
    precision=bf16-mixed \
    job_id=0 \
    hf_ckpt_path="$CKPT" \
    metrics/inline_metrics=all_inline_metrics_no_rosetta \
    inputs="$INPUT" \
    num_replicates="$REPS" \
    "metrics_tags=$TAGS" \
    nn.tri_mult_backend=torch \
    torch_deterministic=true \
    ${SCHEDULE[@]+"${SCHEDULE[@]}"} \
    out_dir="$run_dir" \
    2>&1 | tee "$run_dir/generate.log"
  {
    echo "platform=$PLATFORM"; echo "plan=A (force_einsum + tri_mult=torch + deterministic)"
    echo "task=$task"; echo "seed=$SEED"; echo "nsteps=$NSTEPS"; echo "device=$DEVICE"
    echo "input=$INPUT"; echo "num_replicates=$REPS"; echo "metrics_tags=$TAGS"
    echo "git_commit=$(git rev-parse HEAD)"
    echo "start=$START"; echo "end=$(date -Is)"
  } > "$run_dir/run_info.txt"
done
echo "done: $OUT_ROOT"