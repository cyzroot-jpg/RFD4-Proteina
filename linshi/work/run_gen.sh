#!/usr/bin/env bash
# Launch one generation job.
# usage: run_gen.sh <out_dir> <input> [extra hydra overrides...]
set -e
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src
export HF_HUB_OFFLINE=1
out_dir="$1"; shift
input="$1"; shift
exec python3 -u -m rfproteina.generate \
  inference_experiment=quickstart \
  inputs="$input" \
  out_dir="$out_dir" \
  hf_ckpt_path=/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502 \
  verbose=false \
  "$@"
