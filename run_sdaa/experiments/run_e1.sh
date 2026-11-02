#!/usr/bin/env bash
# E1 driver: per-design comparison of two generated CIF sets, one task at a time.
#
# usage:
#   B_ROOT=/path/to/cuda/run_sdaa/results/cuda bash run_sdaa/experiments/run_e1.sh
# env:
#   A_ROOT (default run_sdaa/results_aligned/sdaa)
#   B_ROOT (required)          another results root with <task>/inference_samples
#   OUT    (default run_sdaa/experiments/out/E1)
#   TASKS  (default: all five)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$REPO_ROOT"
source scripts/load_local_env.sh
export PYTHONPATH=src

A_ROOT="${A_ROOT:-run_sdaa/results_aligned/sdaa}"
B_ROOT="${B_ROOT:?B_ROOT must point at the other platform results root}"
OUT="${OUT:-run_sdaa/experiments/out/E1}"
TASKS="${TASKS:-monomer-short monomer-medium monomer-long motif-1BCF ppi-pdl1}"
PYTHON="${PYTHON:-python3}"

mkdir -p "$OUT"
for task in $TASKS; do
  echo "== $task"
  "$PYTHON" "$HERE/compare_designs.py" \
    --a "$A_ROOT/$task/inference_samples" \
    --b "$B_ROOT/$task/inference_samples" \
    --out "$OUT/$task" \
    --a-name "$(basename "$(dirname "$A_ROOT")")" \
    --b-name "$(basename "$(dirname "$B_ROOT")")"
done

"$PYTHON" - "$OUT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
rows = []
for summary in sorted(root.glob("*/summary.json")):
    d = json.loads(summary.read_text())
    rows.append((summary.parent.name, d["n_pairs"], d["median_identity"],
                 d["frac_identity_ge_0.95"], d["median_backbone_rmsd"], d["max_backbone_rmsd"]))
lines = ["| task | pairs | median identity | ≥0.95 | median design RMSD (Å) | max (Å) |",
         "| --- | ---: | ---: | ---: | ---: | ---: |"]
for task, n, ident, frac, med, mx in rows:
    lines.append(f"| {task} | {n} | {ident:.4f} | {frac:.1%} | {med:.3f} | {mx:.3f} |")
(root / "summary.md").write_text("# E1 design comparison\n\n" + "\n".join(lines) + "\n")
print(f"wrote {root / 'summary.md'}")
PY
