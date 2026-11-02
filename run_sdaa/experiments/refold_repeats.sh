#!/usr/bin/env bash
# Refold the same CIFs several times with different AF3/OF3 diffusion seeds.
#
# Run this on the CUDA host (needs apptainer + AF3_IMAGE / AF3_MODEL_DIR /
# AF3_JAX_CACHE_DIR). The oracle samples its own diffusion noise when `seed` is
# None (the production default), so repeating a fold measures the oracle's own
# variance -- the missing control for the SDAA vs CUDA B-class comparison.
#
# usage:
#   INPUTS=<dir with *_generated.cif> TAGS='[design,developability,unconditional_refolding]' \
#   OUT=<dir> bash run_sdaa/experiments/refold_repeats.sh
#
# env:
#   SEEDS="0 1 2"     diffusion seeds (also written to run_info.txt)
#   ORACLE=of3        oracle group: of3 | af3 | af2
#   LIMIT=0           >0: only the first N sorted CIFs (cost control)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

INPUTS="${INPUTS:?INPUTS must point at a directory with *_generated.cif}"
TAGS="${TAGS:?TAGS must be set (task-specific metrics_tags)}"
OUT="${OUT:?OUT must be set}"
SEEDS="${SEEDS:-0 1 2}"
ORACLE="${ORACLE:-of3}"
LIMIT="${LIMIT:-0}"
PYTHON="${PYTHON:-python3}"

[[ -d "$INPUTS" ]] || { echo "INPUTS not a directory: $INPUTS" >&2; exit 2; }
if [[ -d "$OUT" && -n "$(ls -A "$OUT" 2>/dev/null)" && "${RESUME:-0}" != 1 ]]; then
  echo "$OUT is not empty; choose a fresh OUT or set RESUME=1." >&2
  exit 2
fi
mkdir -p "$OUT/logs" "$OUT/inputs"

mapfile -t FILES < <(find "$INPUTS" -type f -name "*_generated.cif" | sort)
if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "no *_generated.cif under $INPUTS" >&2
  exit 2
fi
if [[ "$LIMIT" -gt 0 && "${#FILES[@]}" -gt "$LIMIT" ]]; then
  FILES=("${FILES[@]:0:$LIMIT}")
fi
for f in "${FILES[@]}"; do
  ln -sf "$(realpath "$f")" "$OUT/inputs/$(basename "$f")"
done

{
  echo "inputs=$INPUTS"
  echo "tags=$TAGS"
  echo "seeds=$SEEDS"
  echo "oracle=$ORACLE"
  echo "designs=${#FILES[@]}"
  echo "start=$(date -Is)"
} > "$OUT/run_info.txt"

for seed in $SEEDS; do
  echo "== seed $seed"
  "$PYTHON" -u -m rfproteina.evaluate \
    inputs="$OUT/inputs" \
    "metrics_tags=$TAGS" \
    metrics/inline_metrics=all_inline_metrics_no_rosetta \
    "metrics/refolding_oracles=$ORACLE" \
    "++metrics.refolding_oracles.oracle.seed=$seed" \
    "++metrics.refolding_oracles.oracle_ppi.seed=$seed" \
    job_id=0 \
    "out_dir=$OUT/seed$seed" \
    > "$OUT/logs/seed$seed.log" 2>&1
  echo "seed $seed done"
done

"$PYTHON" "$HERE/aggregate_repeats.py" "$OUT" | tee "$OUT/aggregate.log"
echo "end=$(date -Is)" >> "$OUT/run_info.txt"
