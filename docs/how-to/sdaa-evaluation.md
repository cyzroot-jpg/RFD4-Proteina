# Running and evaluating on Teco SDAA

This page documents the LoongArch / Teco SDAA port used for the adaptation report.
The model code, weights and metric definitions are unchanged; SDAA support is a
narrow runtime compatibility layer (`rfproteina.utils.sdaa_compat`). On CUDA and
CPU hosts that layer is a no-op.

## Platform detection

```bash
teco-smi | head -20          # SDAA
nvidia-smi -L                # CUDA
python -c "import torch; print(torch.cuda.is_available())"
```

`import rfproteina` automatically enables the CUDA -> SDAA migration when a real
CUDA device is absent and `torch_sdaa` is installed. Set
`RFPROTEINA_DISABLE_SDAA=1` to force CPU on an SDAA host.

## Environment

```bash
cd RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src
```

`.env.local` should provide `DATA_PATH`, `HF_HOME`, and (for an offline cache)
`HF_HUB_OFFLINE=1`.

The LoongArch environment used for this port needs:

- `numpy==1.26.4` and `scipy==1.15.3` (the LoongArch RDKit wheel targets the
  NumPy 1.x C API).
- `rdkit==2026.9.1`, `openbabel`, `biotraj` from the provided LoongArch wheels.
- `wandb==0.17.9` (a newer wandb needs Go to build on LoongArch).
- `pyarrow==23.0.1` installed from the downloaded wheel (`pip install --no-deps`)
  because the index hash is stale; Parquet I/O is stubbed at runtime.
- Symlinks for the RDKit Boost runtime:
  `/usr/local/lib/libboost_numpy312.so.1.81.0 -> /usr/lib64/libboost_numpy311.so.1.81.0`
  and the matching `libboost_python312` link.

See `linshi/change_report/README.md` for the full dependency and pitfall log.

## Weights

The released bundle is `nvidia/RFD4-Proteina` at revision
`a06e2509c7033b010fc43614e9fd840303588502` (`config.json` + `model.safetensors`,
about 1.74 GB, FP32, includes the autoencoder). Point `hf_ckpt_path` at a local
snapshot to avoid network access:

```bash
CKPT=/path/to/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
```

## Generate

```bash
PYTHONPATH=src python3 -m rfproteina.generate \
  inference_experiment=quickstart \
  inputs=data/benchmarks/monomer/monomer-short.cif.zst \
  num_replicates=1 \
  out_dir=./runs/monomer-short \
  hf_ckpt_path=$CKPT

# Select a device when several are available:
SDAA_VISIBLE_DEVICES=0 <the command above>
```

`quickstart` disables the `torch.compile` warm-up (SDAA runs eagerly) and leaves
the official sampling defaults intact (`thinking_medium`: 60 steps, 180 trunk
passes). For metrics that need the input structure (motif RMSD, hotspot
obedience, interchain interactions), compose the official metric group and pass
the official tags:

```bash
PYTHONPATH=src python3 -m rfproteina.generate \
  inference_experiment=inference_on_user_inputs \
  compile_lengths=null \
  inputs=data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst \
  num_replicates=2 out_dir=./runs/motif \
  hf_ckpt_path=$CKPT \
  metrics_tags='[design,3d_coordinate_conditioning]'
```

## Evaluate

The evaluation entry point is the official `rfd4-evaluate`
(`src/rfproteina/evaluate.py`); metrics come from
`configs/metrics/all_metrics.yaml` and are selected with `metrics_tags`.

```bash
PYTHONPATH=src python3 -m rfproteina.evaluate \
  inputs=./runs/monomer-short/inference_samples \
  metrics_tags='[design,developability]' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta \
  out_dir=./eval/monomer-short
```

Results land in `evaluation_metrics/per_example_metrics.csv`. When
`rosetta_developability` is available (`$PYROSETTA_CONTAINER`), omit the
`metrics/inline_metrics=...` override to use the full official developability
group.

### Datasets and tags used in the report

| Task | Dataset | Tags |
| --- | --- | --- |
| Unconditional monomer | `data/benchmarks/monomer/monomer-{short,medium,long}.cif.zst` | `[design, developability]` |
| Indexed motif scaffolding | `data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst` | `[design, 3d_coordinate_conditioning]` |
| Protein binder (PD-L1) | `docs/examples/inputs/5o45_cropped.cif.zst` + binder spec | `[design, hotspot_conditioning, interchain_interactions]` |

### Metrics reported

- `bond_length_metrics.bond_length.frac_unreasonable`
- `clash_metrics.frac_atoms_clashing_1p5A`
- `sse_distribution.helix_fraction` / `sheet_fraction` / `loop_fraction` /
  `num_ss_elements`
- `amino_acid_composition.n_standard_residues` / `ala_fraction` etc.
- `sequence_developability.gravy` / `instability_index`
- `design_motif_allatom_rmsd.rmsd`
- `hotspot_obedience.hotspot_obedience`
- `interchain_interactions.*_count_coi` and `*_conditioning_adherence`

Refolding metrics (`refolded_backbone_rmsd`, pLDDT, ipTM/ipAE) and pass criteria
(`*.pass`) require an AF3 / OpenFold3 runtime and are not computed when the
oracle is unavailable. Rosetta developability requires a PyRosetta apptainer.
Do not replace these with ad-hoc metrics; report the gap.

## Resource instrumentation

Both generation and evaluation write:

- `inference_metrics/resource_usage.json` (generation)
- `evaluation_metrics/resource_usage.json` (evaluation)

with wall time, CPU time, process CPU utilization, peak RSS, and device peak
memory. Generation also writes per-batch rows in `resource_usage_batches.csv`.
This instrumentation does not change model or metric behaviour.