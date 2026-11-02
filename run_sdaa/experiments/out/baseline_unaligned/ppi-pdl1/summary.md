# Design comparison: aligned vs unaligned

- A: `run_sdaa/results_aligned/sdaa/ppi-pdl1/inference_samples`
- B: `run_sdaa/results/sdaa/ppi-pdl1/inference_samples`
- pairs: 6
- identity (aligned columns): median 0.3099, min 0.2121, ≥0.95: 0.0%, ≥0.99: 0.0%
- design backbone RMSD (Å): median 9.695, max 15.062

| key | len A | len B | identity | identity/min | backbone RMSD (Å) | CA RMSD (Å) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| pdl1_rep0_job0 | 51 | 51 | 0.3281 | 0.4118 | 5.141 | 5.234 |
| pdl1_rep1_job0 | 79 | 79 | 0.2917 | 0.3544 | 13.580 | 13.711 |
| pdl1_rep2_job0 | 85 | 85 | 0.3585 | 0.4471 | 7.583 | 7.613 |
| pdl1_rep3_job0 | 108 | 108 | 0.8120 | 0.8796 | 1.009 | 0.933 |
| pdl1_rep4_job0 | 73 | 73 | 0.2121 | 0.2877 | 11.806 | 11.897 |
| pdl1_rep5_job0 | 109 | 109 | 0.2868 | 0.3394 | 15.062 | 15.148 |
