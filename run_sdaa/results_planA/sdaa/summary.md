# RFD4-Proteina full pipeline summary (sdaa)

## Run information

| item | value |
| --- | --- |
| platform | `sdaa` |
| seed | `1234` |
| ckpt | `nvidia/RFD4-Proteina` |
| hf_ckpt_revision | `a06e2509c7033b010fc43614e9fd840303588502` |
| ckpt_model_safetensors_sha256 | `5b549dd61adb2f6c6b5cb95bda13f40f5e31556b4e6c755edc0ca6f011c68fb0` |
| git_commit | `54ef019072c08e7ee118a7671a30efa181c03ae8` |
| git_dirty_src_configs | `0` |
| python | `3.12.13` |
| torch | `2.12.0` |
| torch_sdaa | `3.3.0` |
| foldseek | `absent` |
| apptainer | `absent` |
| out_root | `/data01/tuyilist/cyz/RFD4-Proteina/run_sdaa/results_planA/sdaa` |
| start | `2026-10-28T10:44:52+00:00` |
| end | `2026-10-28T13:56:59+00:00` |

## Metrics (official inline metrics)

| task | n | n_res | bad_bond max | clash max | helix | sheet | loop | n_SSE | GRAVY | instability | motif RMSD (Å) | hotspot | H-bond pairs | salt-bridge pairs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 100.0000 | 0.0000 | 0.0000 | 0.8262 | 0.0000 | 0.1738 | 11.5000 | -0.4070 | 71.8854 |  |  |  |  |
| monomer-medium | 6 | 150.0000 | 0.0000 | 0.0000 | 0.7111 | 0.0789 | 0.2100 | 16.8333 | -0.1442 | 73.1623 |  |  |  |  |
| monomer-long | 4 | 250.0000 | 0.0000 | 0.0000 | 0.6880 | 0.0950 | 0.2170 | 31.0000 | 0.0045 | 42.6609 |  |  |  |  |
| motif-1BCF | 8 | 124.5000 | 0.0000 | 0.0000 | 0.8678 | 0.0000 | 0.1322 | 9.0000 | -0.5654 | 61.7955 | 0.1589 |  |  |  |
| ppi-pdl1 | 6 | 199.1667 | 0.0000 | 0.0000 | 0.1552 | 0.3066 | 0.5382 | 24.0000 | -0.2274 | 33.6684 |  |  | 7.0000 | 3.6667 |

Ranges where meaningful:

| task | n_res | motif RMSD (Å) | hotspot |
| --- | --- | --- | --- |
| monomer-short | 100.00 (100.00-100.00) |  |  |
| monomer-medium | 150.00 (150.00-150.00) |  |  |
| monomer-long | 250.00 (250.00-250.00) |  |  |
| motif-1BCF | 124.50 (114.00-137.00) | 0.16 (0.15-0.17) |  |
| ppi-pdl1 | 199.17 (166.00-224.00) |  |  |

## Performance

| task | designs | wall (s) | cpu time (s) | cpu util (%) | peak device (GB) | peak RSS (GB) | designs/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 3820.1 | 3195.2 | 0.65 | 1.74 | 4.11 | 0.0021 |
| monomer-medium | 6 | 6100.3 | 2851.5 | 0.37 | 1.87 | 4.09 | 0.0010 |
| monomer-long | 4 | 10935.9 | 2843.8 | 0.20 | 2.28 | 4.11 | 0.0004 |
| motif-1BCF | 8 | 6755.1 | 3663.8 | 0.42 | 1.83 | 4.12 | 0.0012 |
| ppi-pdl1 | 6 | 11368.8 | 3651.7 | 0.25 | 2.15 | 4.11 | 0.0005 |

## Output inventory

- `monomer-short`: 8 generated CIF; inference_metrics=True; evaluation_metrics=True
- `monomer-medium`: 6 generated CIF; inference_metrics=True; evaluation_metrics=True
- `monomer-long`: 4 generated CIF; inference_metrics=True; evaluation_metrics=True
- `motif-1BCF`: 8 generated CIF; inference_metrics=True; evaluation_metrics=True
- `ppi-pdl1`: 6 generated CIF; inference_metrics=True; evaluation_metrics=True

## Gaps

- No AF3/OF3 on this host: no scRMSD / pLDDT / ipTM / ipAE / pass rate. Refolding is a CUDA-side step.
- No PyRosetta: `rosetta_developability.*` absent; `developability.pass` incomplete.
- No FoldSeek: no structural clustering / clustered pass rate.
- PPI uses the official input `data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst`.
