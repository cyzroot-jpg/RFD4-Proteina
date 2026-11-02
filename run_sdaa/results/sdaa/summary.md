# RFD4-Proteina full pipeline summary (SDAA)

## Run information

| item | value |
| --- | --- |
| platform | `sdaa` |
| seed | `1234` |
| ckpt | `nvidia/RFD4-Proteina` |
| hf_ckpt_revision | `a06e2509c7033b010fc43614e9fd840303588502` |
| ckpt_model_safetensors_sha256 | `5b549dd61adb2f6c6b5cb95bda13f40f5e31556b4e6c755edc0ca6f011c68fb0` |
| git_commit | `00b916c63abe910df3f2f8f0af7222ebb253fca8` |
| git_dirty_src_configs | `0` |
| python | `3.12.13` |
| torch | `2.12.0` |
| torch_sdaa | `3.3.0` |
| foldseek | `absent` |
| apptainer | `absent` |
| out_root | `/data01/tuyilist/cyz/RFD4-Proteina/run_sdaa/results/sdaa` |
| start | `2026-10-26T11:03:48+00:00` |
| end | `2026-10-27T01:39:56+00:00` |

## Metrics (official inline metrics)

| task | n | n_res | bad_bond max | clash max | helix | sheet | loop | n_SSE | GRAVY | instability | motif RMSD (Å) | hotspot | H-bond pairs | salt-bridge pairs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 100.0000 | 0.0000 | 0.0000 | 0.7712 | 0.0500 | 0.1788 | 11.2500 | -0.2919 | 47.8425 |  |  |  |  |
| monomer-medium | 6 | 150.0000 | 0.0000 | 0.0000 | 0.7933 | 0.0456 | 0.1611 | 13.6667 | -0.4858 | 54.5333 |  |  |  |  |
| monomer-long | 4 | 250.0000 | 0.0000 | 0.0000 | 0.8560 | 0.0130 | 0.1310 | 24.0000 | 0.3271 | 46.4995 |  |  |  |  |
| motif-1BCF | 8 | 124.5000 | 0.0000 | 0.0000 | 0.8711 | 0.0000 | 0.1289 | 9.0000 | -0.6063 | 66.3289 | 0.1601 |  |  |  |
| ppi-pdl1 | 6 | 199.1667 | 0.0000 | 0.0000 | 0.2318 | 0.2794 | 0.4887 | 23.0000 | -0.4529 | 56.3246 |  |  | 8.8333 | 3.1667 |

Ranges where meaningful:

| task | n_res | motif RMSD (Å) | hotspot |
| --- | --- | --- | --- |
| monomer-short | 100.00 (100.00-100.00) |  |  |
| monomer-medium | 150.00 (150.00-150.00) |  |  |
| monomer-long | 250.00 (250.00-250.00) |  |  |
| motif-1BCF | 124.50 (114.00-137.00) | 0.16 (0.15-0.16) |  |
| ppi-pdl1 | 199.17 (166.00-224.00) |  |  |

## Performance

| task | designs | wall (s) | cpu time (s) | cpu util (%) | peak device (GB) | peak RSS (GB) | designs/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 3645.9 | 3041.4 | 0.65 | 1.74 | 4.14 | 0.0022 |
| monomer-medium | 6 | 5993.9 | 2705.8 | 0.35 | 1.87 | 4.14 | 0.0010 |
| monomer-long | 4 | 10815.3 | 2705.3 | 0.20 | 2.28 | 4.11 | 0.0004 |
| motif-1BCF | 8 | 6633.5 | 3506.2 | 0.41 | 1.83 | 4.13 | 0.0012 |
| ppi-pdl1 | 6 | 11221.1 | 3465.5 | 0.24 | 2.15 | 4.12 | 0.0005 |

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
