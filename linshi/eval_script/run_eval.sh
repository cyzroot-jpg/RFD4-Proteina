#!/usr/bin/env bash
set -e
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src
export HF_HUB_OFFLINE=1
out_dir="$1"; shift
inputs="$1"; shift
exec python3 -u -m rfproteina.evaluate inputs="$inputs" out_dir="$out_dir" verbose=true "$@"
