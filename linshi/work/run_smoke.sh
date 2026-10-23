#!/usr/bin/env bash
set -e
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src
export HF_HUB_OFFLINE=1
exec python3 -u -m rfproteina.generate \
  inference_experiment=quickstart \
  inputs=data/benchmarks/monomer/monomer-short.cif.zst \
  num_replicates=1 \
  out_dir=./linshi/work/smoke10 \
  hf_ckpt_path=/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502 \
  verbose=true \
  generation.args.nsteps=20 'generation.n_recycle_schedule=[[20,0]]'
