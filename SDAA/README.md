# SDAA adaptation

- `SDAA_ADAPTATION.md`: full adaptation record (environment, analysis, changes,
  weights, test results, CUDA vs SDAA comparison, pitfalls).
- `patches/rfd4-proteina-sdaa.patch`: source/config/doc diff.

`patches/rfd4-proteina-sdaa.patch` contains the source/config/doc changes for
running RFD4-Proteina on Teco SDAA (LoongArch, Torch-SDAA 3.3.0). It is a plain
`git diff` against commit `6fc44c060ef96d4c759bafeaa1eae1a66a5be67c`.

Apply / revert from the repository root:

```bash
git apply SDAA/patches/rfd4-proteina-sdaa.patch
# revert
git apply -R SDAA/patches/rfd4-proteina-sdaa.patch
```

The patch adds a narrow runtime compatibility layer and keeps CUDA/CPU paths
unchanged. It includes:

- `src/rfproteina/utils/sdaa_compat.py`: SDAA detection, CUDA -> SDAA migration,
  and biotite/rdkit/pyarrow/torch layout bridges.
- `src/rfproteina/utils/resource_monitor.py`: inference/evaluation wall time,
  throughput, peak device memory, RSS and CPU usage.
- `src/rfproteina/generate.py`: configurable Lightning accelerator and the
  resource callback.
- `src/rfproteina/evaluate.py`: resource recorder around the official evaluator.
- `src/rfproteina/nn/modules/pair_bias_attn.py`: SDPA-with-einsum-fallback on
  SDAA for additive pair bias.
- `src/rfproteina/utils/align.py`: device-safe `torch.where` guard.
- `configs/metrics/inline_metrics/*_no_rosetta.yaml`: official developability
  subset for hosts without a PyRosetta container.
- `docs/how-to/sdaa-evaluation.md`: usage documentation.

Runtime-only prerequisites (not in the patch): `.env.local`, LoongArch wheels,
RDKit Boost symlinks, and the cached HF weights. See
`linshi/change_report/README.md` for the full record.