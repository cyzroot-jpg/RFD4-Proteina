#!/usr/bin/env bash
# Numerical ablation matrix: run generation with one numerical path changed, then
# compare the resulting designs to a reference set (compare_designs.py).
#
# Intended for the CUDA host: 8 designs take about a minute per variant.
# To run it on SDAA, set PLATFORM=sdaa (slower; consider REPS=2).
#
# usage:
#   TASK=monomer-short REF=<reference inference_samples> OUT=<dir> \
#     bash run_sdaa/experiments/run_ablation.sh
#
# env:
#   TASK       monomer-short | monomer-medium | monomer-long | motif-1BCF | ppi-pdl1
#   REF        reference inference_samples dir (e.g. the SDAA aligned designs)
#   OUT        output root (must be fresh unless RESUME=1)
#   VARIANTS   default "base einsum no_cuet einsum_no_cuet fp32 det"
#   REPS       default 8
#   NSTEPS     default 60 (if != 60 a matching recycle schedule is set; REF must match)
#   DEVICE     device slot (default 0)
#   CKPT       default nvidia/RFD4-Proteina
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

TASK="${TASK:-monomer-short}"
REF="${REF:?REF must point at the reference inference_samples dir}"
OUT="${OUT:?OUT must be set}"
VARIANTS="${VARIANTS:-base einsum no_cuet einsum_no_cuet manual_ln manual_ln_einsum tri_torch all_manual all_manual_fp32 fp32 det}"
REPS="${REPS:-8}"
NSTEPS="${NSTEPS:-60}"
DEVICE="${DEVICE:-0}"
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

if [[ -d "$OUT" && -n "$(ls -A "$OUT" 2>/dev/null)" && "${RESUME:-0}" != 1 ]]; then
  echo "$OUT is not empty; choose a fresh OUT or set RESUME=1." >&2
  exit 2
fi
mkdir -p "$OUT/logs" "$OUT/compare"

SCHEDULE=()
if [[ "$NSTEPS" != 60 ]]; then
  SCHEDULE=("generation.n_recycle_schedule=[[${NSTEPS},2]]")
fi

case "$PLATFORM" in
  sdaa) export SDAA_VISIBLE_DEVICES="$DEVICE" ;;
  cuda) export CUDA_VISIBLE_DEVICES="$DEVICE" ;;
  auto)
    if command -v nvidia-smi >/dev/null 2>&1; then export CUDA_VISIBLE_DEVICES="$DEVICE"
    else export SDAA_VISIBLE_DEVICES="$DEVICE"; fi
    ;;
esac

{
  echo "task=$TASK"; echo "input=$INPUT"; echo "ref=$REF"
  echo "variants=$VARIANTS"; echo "reps=$REPS"; echo "nsteps=$NSTEPS"
  echo "git_commit=$(git rev-parse HEAD)"
  echo "precision_default=bf16-mixed"; echo "start=$(date -Is)"
} > "$OUT/run_info.txt"

for variant in $VARIANTS; do
  ablate=""
  extra=()
  case "$variant" in
    base) ;;
    einsum) ablate="force_einsum" ;;
    no_cuet) ablate="no_cuet"; extra+=("nn.tri_mult_backend=torch") ;;
    einsum_no_cuet) ablate="force_einsum,no_cuet"; extra+=("nn.tri_mult_backend=torch") ;;
    fp32) extra+=("precision=32") ;;
    manual_ln) ablate="manual_ln" ;;
    manual_ln_einsum) ablate="manual_ln,force_einsum"; extra+=("nn.tri_mult_backend=torch") ;;
    tri_torch) extra+=("nn.tri_mult_backend=torch") ;;
    all_manual) ablate="force_einsum,manual_ln,no_cuet"; extra+=("nn.tri_mult_backend=torch") ;;
    all_manual_fp32) ablate="force_einsum,manual_ln,no_cuet"; extra+=("nn.tri_mult_backend=torch" "precision=32") ;;
    det) extra+=("torch_deterministic=true") ;;
    *) echo "unknown variant: $variant" >&2; exit 2 ;;
  esac

  echo "== $variant (RFPROTEINA_ABLATE=$ablate ${extra[*]:-})"
  if ! RFPROTEINA_ABLATE="$ablate" "$PYTHON" -u "$HERE/ablate.py" \
      inference_experiment=quickstart \
      compile_lengths=null \
      seed=1234 \
      batch_size=1 \
      job_id=0 \
      hf_ckpt_path="$CKPT" \
      inputs="$INPUT" \
      num_replicates="$REPS" \
      "${SCHEDULE[@]}" \
      "${extra[@]}" \
      out_dir="$OUT/$variant" \
      > "$OUT/logs/$variant.log" 2>&1; then
    echo "FAIL $variant" | tee -a "$OUT/status.txt"
    continue
  fi
  "$PYTHON" "$HERE/compare_designs.py" \
    --a "$REF" --b "$OUT/$variant/inference_samples" \
    --out "$OUT/compare/$variant" --a-name ref --b-name "$variant" \
    > "$OUT/logs/compare_$variant.log" 2>&1 || { echo "FAIL compare $variant" | tee -a "$OUT/status.txt"; continue; }
  echo "PASS $variant" | tee -a "$OUT/status.txt"
done

"$PYTHON" - "$OUT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
lines = ["# Numerical ablation", "",
         "| variant | pairs | median identity | ≥0.95 | median design RMSD (Å) |",
         "| --- | ---: | ---: | ---: | ---: |"]
for summary in sorted(root.glob("compare/*/summary.json")):
    d = json.loads(summary.read_text())
    lines.append(f"| {summary.parent.name} | {d['n_pairs']} | {d['median_identity']:.4f} | "
                 f"{d['frac_identity_ge_0.95']:.1%} | {d['median_backbone_rmsd']:.3f} |")
(root / "summary.md").write_text("\n".join(lines) + "\n")
print(f"wrote {root}/summary.md")
PY
printf 'end=%s\n' "$(date -Is)" >> "$OUT/run_info.txt"