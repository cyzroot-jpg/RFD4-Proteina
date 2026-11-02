# run_sdaa — full pipeline runner (SDAA / CUDA)

Runs the official pipeline end to end for five tasks, with provenance:

```text
generate (official inline metrics) -> offline rfd4-evaluate -> aggregate metrics -> summary
```

Tasks and inputs (all official benchmarks):

| task | input | replicates | metrics_tags |
| --- | --- | --- | --- |
| monomer-short | `data/benchmarks/monomer/monomer-short.cif.zst` | 8 | `[design,developability]` |
| monomer-medium | `data/benchmarks/monomer/monomer-medium.cif.zst` | 6 | `[design,developability]` |
| monomer-long | `data/benchmarks/monomer/monomer-long.cif.zst` | 4 | `[design,developability]` |
| motif-1BCF | `data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst` | 8 | `[design,developability,3d_coordinate_conditioning]` |
| ppi-pdl1 | `data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst` | 6 | `[design,developability,interchain_interactions]` |

Fixed settings: `inference_experiment=inference_on_user_inputs`, `compile_lengths=null`,
`seed=1234`, `batch_size=1`, `precision=bf16-mixed`, `job_id=0`,
`save_chain_of_interest=true`, `hf_ckpt_path=nvidia/RFD4-Proteina` (revision pinned in
`configs/inference.yaml`), `metrics/inline_metrics=all_inline_metrics_no_rosetta`.

## Run (detached, survives session close)

The same command works on SDAA and CUDA; the platform and device mapping are detected.

```bash
cd /path/to/RFD4-Proteina
source scripts/load_local_env.sh
export PYTHONPATH=src

( setsid nohup env OUT_ROOT="$PWD/run_sdaa/results" \
    bash run_sdaa/run_all.sh > run_sdaa/logs/run_all.log 2>&1 < /dev/null & )
```

- SDAA: `DEVICE` is a card slot; the stride (`logical devices / physical cards`) is detected
  automatically, so slots 0..4 land on physical cards 0..4.
- CUDA: `DEVICE` maps directly to `CUDA_VISIBLE_DEVICES` (stride 1); slots 0..4 are GPUs 0..4.
- Non-empty `<OUT_ROOT>/<platform>` is refused to protect old results; set `RESUME=1` to append.

## Outputs

```text
run_sdaa/results/<platform>/
├── run_env.txt          # platform, seed, ckpt revision + sha256, git commit, dirty src/configs
├── command.txt          # common overrides and task matrix
├── scripts.sha256       # hashes of the runner scripts
├── status.txt           # PASS/FAIL per task
├── summary.md           # metrics + performance + inventory (written at the end)
├── metrics.csv          # task x metric means
├── checksums.sha256     # sha256 of every output file
├── DONE / FAILED        # completion marker
└── <task>/
    ├── task_env.txt     # task-specific env (device, input, tags, start/end)
    ├── command.txt      # exact generate command
    ├── generate.log
    ├── evaluate.log
    ├── aggregate.log
    ├── inference_samples/...
    ├── inference_metrics/   # inline metrics (+ per_example_metrics.csv, aggregated_metrics.csv)
    └── evaluation/         # offline evaluate (+ aggregated metrics)
```

## Notes

- No AF3/OF3, PyRosetta or FoldSeek on this host: no scRMSD / pLDDT / ipTM / ipAE / pass rate,
  no `rosetta_developability.*`, no structural clustering. Refolding is a separate CUDA-side
  step on the generated CIFs.
- The PPI task uses the official `ppi_bb_only/pdl1.cif.zst` (target backbone `C_CRD`), not the
  old `linshi/work/binder.yaml` spec.
- `aggregate_metrics` takes `--input=<dir>` (Fire) and moves per-job CSVs into
  `individual_job_results/`, writing `per_example_metrics.csv` /
  `aggregated_metrics.csv` / `per_task_metrics.csv`.
- Offline evaluate stages symlinks to `*_generated.cif` only; otherwise
  `inference_samples/foldseek_input_chains/` would be scored as duplicate designs.