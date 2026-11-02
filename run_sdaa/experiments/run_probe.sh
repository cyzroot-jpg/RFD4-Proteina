#!/usr/bin/env bash
# One-shot probe bundle for root-cause analysis. Run the SAME command on SDAA and
# CUDA, then compare the two output dirs on one host.
#
# Produces:
#   <OUT>/fidelity/        first N trunk calls (inputs + outputs)
#   <OUT>/layers/          per-module output statistics for the first trunk call
#   <OUT>/ops_<platform>.json   per-op micro-benchmarks with a float64 CPU reference
#
# usage:
#   OUT=<dir> bash run_sdaa/experiments/run_probe.sh
# env:
#   OUT (required), TASK (default monomer-short), DEVICE (default 0),
#   NSTEPS (default 20; must be >= 20), FIDELITY_CALLS (default NSTEPS),
#   CKPT, PLATFORM=auto|sdaa|cuda
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$HERE"
while [[ "$REPO_ROOT" != "/" && ! -f "$REPO_ROOT/pyproject.toml" ]]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

OUT="${OUT:?OUT must be set}"
TASK="${TASK:-monomer-short}"
DEVICE="${DEVICE:-0}"
NSTEPS="${NSTEPS:-20}"
FIDELITY_CALLS="${FIDELITY_CALLS:-$NSTEPS}"
CKPT="${CKPT:-nvidia/RFD4-Proteina}"
PYTHON="${PYTHON:-python3}"
PLATFORM="${PLATFORM:-auto}"

case "$TASK" in
  monomer-short)  INPUT=data/benchmarks/monomer/monomer-short.cif.zst ;;
  monomer-medium) INPUT=data/benchmarks/monomer/monomer-medium.cif.zst ;;
  monomer-long)   INPUT=data/benchmarks/monomer/monomer-long.cif.zst ;;
  motif-1BCF)     INPUT=data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst ;;
  ppi-pdl1)       INPUT=data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst ;;
  *) echo "unknown TASK: $TASK" >&2; exit 2 ;;
esac

if [[ "$NSTEPS" -lt 20 ]]; then
  echo "NSTEPS must be >= 20 (tail_steps * tail_step_multiplier)" >&2
  exit 2
fi

if [[ "$PLATFORM" == auto ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then PLATFORM=cuda; else PLATFORM=sdaa; fi
fi
case "$PLATFORM" in
  sdaa)
    export SDAA_VISIBLE_DEVICES="$DEVICE"
    if [[ -z "${TORCH_SDAA_ALIGN_NV_DEVICE:-}" ]]; then
      echo "WARNING: TORCH_SDAA_ALIGN_NV_DEVICE is not set; this SDAA probe will NOT be" >&2
      echo "         comparable to CUDA (different noise stream). Set it to a100." >&2
    fi
    ;;
  cuda) export CUDA_VISIBLE_DEVICES="$DEVICE" ;;
esac

mkdir -p "$OUT"
{
  echo "platform=$PLATFORM"; echo "task=$TASK"; echo "nsteps=$NSTEPS"
  echo "fidelity_calls=$FIDELITY_CALLS"; echo "device=$DEVICE"
  echo "torch_sdaa_align_nv_device=${TORCH_SDAA_ALIGN_NV_DEVICE:-unset}"
  echo "git_commit=$(git rev-parse HEAD)"
  echo "start=$(date -Is)"
} > "$OUT/run_info.txt"

COMMON=(
  inference_experiment=quickstart
  compile_lengths=null
  seed=1234
  batch_size=1
  job_id=0
  hf_ckpt_path="$CKPT"
  inputs="$INPUT"
  num_replicates=1
  "generation.n_recycle_schedule=[[${NSTEPS},2]]"
  "generation.args.nsteps=${NSTEPS}"
)

echo "== fidelity probe ($FIDELITY_CALLS calls)"
FIDELITY_OUT="$OUT/fidelity" FIDELITY_CALLS="$FIDELITY_CALLS" \
  "$PYTHON" -u "$HERE/fidelity_probe.py" "${COMMON[@]}" \
  out_dir="$OUT/run_fidelity" > "$OUT/logs_fidelity.log" 2>&1

echo "== layer probe"
LAYER_PROBE_OUT="$OUT/layers" \
  "$PYTHON" -u "$HERE/layer_probe.py" "${COMMON[@]}" \
  out_dir="$OUT/run_layers" > "$OUT/logs_layers.log" 2>&1

echo "== op bench"
"$PYTHON" "$HERE/op_bench.py" --out "$OUT/ops_${PLATFORM}.json" \
  > "$OUT/logs_ops.log" 2>&1

printf 'end=%s\n' "$(date -Is)" >> "$OUT/run_info.txt"
echo "done: $OUT"