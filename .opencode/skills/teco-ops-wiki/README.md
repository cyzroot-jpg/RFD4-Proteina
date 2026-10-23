# teco-ops-wiki

This is KernelPilot's exclusive knowledge base for public Tecorigin operator
development and SDAA optimization. It combines searchable source/document pages,
curated techniques, official manuals, and complete repository snapshots.

The teco-ops snapshot under `artifacts/repos/teco-ops/` tracks upstream `main`
commit `ac7eb023faa0c84bdd8d9959561a59d44105da6e` and includes all eight current
operators:

- causal_conv1d
- flash_attention
- flatten_rays
- memset
- morton3D_invert
- reduce_variance
- reshape_and_cache
- rms_norm

Use `sources/ops/teco-ops-*.md` to locate each operator's implementation,
design document, native oracle, and prototxt cases. Use
`technique-teco-ops-native-testing` for the required correctness and
SDPTI-backed benchmark policy.

```bash
python3 scripts/query.py "rms norm DMA double buffering" --compact
python3 scripts/query.py "Average Hardware Time" --compact
python3 scripts/get_page.py source-teco-ops-rms-norm
python3 scripts/get_page.py technique-teco-ops-native-testing --follow-sources
python3 scripts/validate.py
```

For exact behavior, inspect the source snapshot directly:

```bash
git grep -n "warm_repeat" -- artifacts/repos/teco-ops/README.md \
  artifacts/repos/teco-ops/doc/README_OP.md
sed -n '210,285p' artifacts/repos/teco-ops/test/src/suite/executor.cpp
```

If the wiki does not cover a question, record the gap and inspect upstream
teco-ops. Do not substitute another local wiki.
