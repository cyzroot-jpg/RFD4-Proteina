# PPI A-class metric attribution (complete experiment)

All metrics are recomputed on one host with one code path; inputs are the two
design sets (SDAA aligned vs CUDA). No oracle is used.

## H0 metric cross-check

- GRAVY (sequence-derived vs official): max abs diff SDAA 4.11e-05, CUDA 4.50e-05
- instability: max abs diff SDAA 4.07e-05, CUDA 4.31e-05

## H1/H2 per-design

| rep | len S/C | identity | design RMSD (Å) | deg S/C | ΔGRAVY | Δinstability | ΔH-bond | Δsalt |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| rep0 | 51/51 | 0.576 | 6.79 | N/N | -0.394 | -17.6 | -3 | +4 |
| rep1 | 79/79 | 0.519 | 11.53 | N/N | +0.237 | -32.2 | -3 | +3 |
| rep2 | 85/85 | 0.540 | 7.57 | N/N | +0.380 | -4.6 | -3 | -3 |
| rep3 | 108/108 | 0.781 | 2.03 | Y/N | +0.019 | +3.8 | +11 | -5 |
| rep4 | 73/73 | 0.615 | 10.58 | N/N | +1.171 | -63.4 | +7 | -1 |
| rep5 | 109/109 | 1.000 | 0.12 | Y/Y | -0.026 | +0.0 | +15 | +6 |

## H3/H4 genuine-only statistics

| metric | mean all | degenerate contribution | mean genuine | direction | sign-flip p | Wilcoxon p | MW p | bootstrap 95% CI | jackknife range |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | --- |
| gravy | +0.231 | -0.001 | +0.348 | +3/-1 | 0.500 | 0.625 | 0.200 | [-0.201, +0.938] | [+0.074, +0.596] |
| instability | -18.982 | +0.640 | -29.433 | +0/-4 | 0.125 | 0.125 | 0.057 | [-51.924, -11.074] | [-37.725, -18.122] |
| hbond | +4.000 | +4.333 | -0.500 | +1/-3 | 1.000 | 1.000 | 0.663 | [-3.000, +4.500] | [-3.000, +0.333] |
| salt | +0.667 | +0.167 | +0.750 | +2/-2 | 0.875 | 0.750 | 0.557 | [-2.000, +3.500] | [-0.333, +2.000] |
| hydrophobic | +0.333 | +1.167 | -1.250 | +1/-3 | 0.500 | 0.625 | 0.557 | [-3.500, +1.750] | [-2.667, -0.333] |

## H5 composition shift (genuine designs, SDAA − CUDA)

| residue | Δ frequency | KD contribution to ΔGRAVY |
| --- | ---: | ---: |
| E | -0.0612 | +0.2142 |
| V | +0.0410 | +0.1723 |
| I | -0.0381 | -0.1714 |
| D | +0.0401 | -0.1403 |
| R | -0.0210 | +0.0945 |
| K | -0.0216 | +0.0841 |
| L | -0.0153 | -0.0583 |
| A | +0.0312 | +0.0562 |

## Verdict

- **H-bond**: all-design mean Δ +4.00, of which the degenerate pairs contribute +4.33; genuine mean Δ -0.50 (sign-flip p=1.00). → the headline H-bond gap is a degenerate-design artifact.
- **GRAVY**: genuine mean Δ +0.348 (direction +3/-1, sign-flip p=0.50); SDAA is slightly more hydrophobic, but not significant at this n.
- **instability**: genuine mean Δ -29.4 (direction +0/-4, sign-flip p=0.12); SDAA is more stable in all four genuine pairs, but the minimum achievable p at n=4 is 0.125.

**Conclusion**: with metrics, conditioning and degeneracy all controlled, the A-class
differences reduce to different binder sequences. The large H-bond gap is caused by
degenerate target-copy designs, not by the platform; the residual GRAVY/instability
difference is a sampling trend that cannot be distinguished from noise at n=4.
