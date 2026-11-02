# Design comparison: aligned vs unaligned

- A: `run_sdaa/results_aligned/sdaa/motif-1BCF/inference_samples`
- B: `run_sdaa/results/sdaa/motif-1BCF/inference_samples`
- pairs: 8
- identity (aligned columns): median 0.8020, min 0.6992, ≥0.95: 0.0%, ≥0.99: 0.0%
- design backbone RMSD (Å): median 0.226, max 1.189

| key | len A | len B | identity | identity/min | backbone RMSD (Å) | CA RMSD (Å) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1BCF_AA_rep0_job0 | 114 | 114 | 0.7478 | 0.7544 | 0.756 | 0.787 |
| 1BCF_AA_rep1_job0 | 123 | 123 | 0.8780 | 0.8780 | 0.282 | 0.285 |
| 1BCF_AA_rep2_job0 | 133 | 133 | 0.7970 | 0.7970 | 0.159 | 0.149 |
| 1BCF_AA_rep3_job0 | 128 | 128 | 0.8359 | 0.8359 | 0.152 | 0.159 |
| 1BCF_AA_rep4_job0 | 114 | 114 | 0.8070 | 0.8070 | 0.219 | 0.192 |
| 1BCF_AA_rep5_job0 | 127 | 127 | 0.7874 | 0.7874 | 0.232 | 0.227 |
| 1BCF_AA_rep6_job0 | 120 | 120 | 0.6992 | 0.7167 | 1.189 | 1.203 |
| 1BCF_AA_rep7_job0 | 137 | 137 | 0.8321 | 0.8321 | 0.156 | 0.164 |
