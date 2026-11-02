#!/usr/bin/env bash
# Plan A on CUDA: generate CUDA Plan A designs, refold BOTH design sets with the
# same oracle, and compare them (E1 + A/B class metrics).
#
# Prerequisites on the CUDA host:
#   - repo at the same commit, venv activated, AF3/OF3 runtime configured
#   - run_sdaa/experiments/ synced (rsync, exclude out/)
#   - the SDAA Plan A designs synced to SDAA_ROOT (see PLAN_A.md)
#
# usage:
#   SDAA_ROOT=/path/to/results_planA/sdaa \
#   OUT_ROOT=$PWD/run_sdaa/results_planA/cuda \
#     bash run_sdaa/experiments/run_plan_a_cuda.sh
#
# env:
#   SDAA_ROOT   root with <task>/inference_samples (SDAA Plan A)
#   OUT_ROOT    CUDA Plan A output root (generated here)
#   ORACLE      of3 (default) | af3 | af2
#   TASKS       default: all five
#   DEVICE      GPU index (default 0)
#   EVAL_SDAA   where to refold the SDAA designs (default: ../sdaa_eval)
#   COMPARE     comparison output dir (default: ../compare)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$HERE"
while [[ "$REPO_ROOT" != "/" && ! -f "$REPO_ROOT/pyproject.toml" ]]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

SDAA_ROOT="${SDAA_ROOT:?SDAA_ROOT must point at the SDAA Plan A results root}"
OUT_ROOT="${OUT_ROOT:?OUT_ROOT must be set}"
ORACLE="${ORACLE:-of3}"
TASKS="${TASKS:-monomer-short monomer-medium monomer-long motif-1BCF ppi-pdl1}"
DEVICE="${DEVICE:-0}"
PYTHON="${PYTHON:-python3}"
PARENT="$(dirname "$OUT_ROOT")"
EVAL_SDAA="${EVAL_SDAA:-$PARENT/sdaa_eval}"
COMPARE="${COMPARE:-$PARENT/compare}"
LOG_DIR="$PARENT/logs"

mkdir -p "$OUT_ROOT" "$EVAL_SDAA" "$COMPARE" "$LOG_DIR"
export CUDA_VISIBLE_DEVICES="$DEVICE"

tags_for() {
  case "$1" in
    monomer-short|monomer-medium|monomer-long) printf '%s' '[design,developability,unconditional_refolding]' ;;
    motif-1BCF) printf '%s' '[design,developability,3d_coordinate_conditioning,motif_scaffold_refolding]' ;;
    ppi-pdl1)   printf '%s' '[design,developability,interchain_interactions,ppi_refolding]' ;;
  esac
}

refold() {
  local task="$1" designs="$2" eval_root="$3"
  "$PYTHON" -u -m rfproteina.evaluate \
    inputs="$designs/$task/inference_samples" \
    "metrics_tags=$(tags_for "$task")" \
    metrics/inline_metrics=all_inline_metrics_no_rosetta \
    "metrics/refolding_oracles=$ORACLE" \
    job_id=0 \
    out_dir="$eval_root/$task/evaluation" \
    > "$LOG_DIR/refold_$(basename "$eval_root")_$task.log" 2>&1
}

{
  echo "plan=A"; echo "oracle=$ORACLE"; echo "device=$DEVICE"
  echo "sdaa_root=$SDAA_ROOT"; echo "out_root=$OUT_ROOT"
  echo "eval_sdaa=$EVAL_SDAA"; echo "compare=$COMPARE"
  echo "git_commit=$(git rev-parse HEAD)"; echo "start=$(date -Is)"
} > "$PARENT/run_info.txt"

# 1) generate CUDA Plan A designs (skip tasks already present)
for task in $TASKS; do
  if [[ ! -d "$OUT_ROOT/$task/inference_samples" ]]; then
    echo "== generate $task"
    OUT_ROOT="$OUT_ROOT" DEVICE="$DEVICE" bash "$HERE/run_plan_a.sh" "$task"
  fi
done

# 2) refold both design sets with the same oracle
for task in $TASKS; do
  echo "== refold CUDA $task"
  refold "$task" "$OUT_ROOT" "$OUT_ROOT"
  if [[ -d "$SDAA_ROOT/$task/inference_samples" ]]; then
    echo "== refold SDAA $task"
    refold "$task" "$SDAA_ROOT" "$EVAL_SDAA"
  fi
done

# 3) design-level comparison (SDAA Plan A vs CUDA Plan A)
A_ROOT="$SDAA_ROOT" B_ROOT="$OUT_ROOT" OUT="$COMPARE/E1" TASKS="$TASKS" \
  bash "$HERE/run_e1.sh" | tee "$LOG_DIR/e1.log"

# 4) A/B class metric comparison
"$PYTHON" "$HERE/compare_metrics.py" \
  --a-root "$SDAA_ROOT" --b-root "$OUT_ROOT" \
  --a-eval-root "$EVAL_SDAA" --b-eval-root "$OUT_ROOT" \
  --out "$COMPARE/metrics" | tee "$LOG_DIR/metrics.log"

# 5) optional: compare CUDA Plan A against the default SDAA run
DEFAULT_SDAA="${DEFAULT_SDAA:-$REPO_ROOT/run_sdaa/results_aligned/sdaa}"
if [[ -d "$DEFAULT_SDAA" ]]; then
  "$PYTHON" "$HERE/compare_metrics.py" \
    --a-root "$DEFAULT_SDAA" --b-root "$OUT_ROOT" \
    --out "$COMPARE/vs_default_sdaa" | tee "$LOG_DIR/metrics_vs_default.log"
fi

echo "end=$(date -Is)" >> "$PARENT/run_info.txt"
echo "done: $COMPARE"