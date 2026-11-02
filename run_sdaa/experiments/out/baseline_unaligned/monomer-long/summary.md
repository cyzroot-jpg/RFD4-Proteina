# Design comparison: results_aligned vs results

- A: `run_sdaa/results_aligned/sdaa/monomer-long/inference_samples`
- B: `run_sdaa/results/sdaa/monomer-long/inference_samples`
- pairs: 4
- identity (aligned columns): median 0.2702, min 0.2378, ≥0.95: 0.0%, ≥0.99: 0.0%
- design backbone RMSD (Å): median 24.432, max 29.483

| key | len A | len B | identity | identity/min | backbone RMSD (Å) | CA RMSD (Å) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| monomer-long_rep0_job0 | 250 | 250 | 0.2597 | 0.3480 | 20.297 | 20.353 |
| monomer-long_rep1_job0 | 250 | 250 | 0.2806 | 0.3480 | 28.568 | 28.613 |
| monomer-long_rep2_job0 | 250 | 250 | 0.3833 | 0.4600 | 29.483 | 29.494 |
| monomer-long_rep3_job0 | 250 | 250 | 0.2378 | 0.2920 | 20.180 | 20.226 |
