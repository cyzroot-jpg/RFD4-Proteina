# PROVENANCE

- Source repository: `https://gitee.com/tecorigin/teco-al`
- Branch: `develop`
- Commit: `17c5cd66f0ca86d74e5f9c37d507656febfb8897`
- Fetched: 2026-07-11
- License: BSD-3-Clause (see `LICENSE` in this directory; `NOTICE` for copyright)
- Content: complete verbatim working-tree snapshot at the above commit (`.git` history not included). This is the full repository — including `interface/`, `ual/`, `custom_ops/`, `test/` (tecotest framework + vendored `thirdparty/` protobuf and googletest source under `test/frame_work/tecotest/thirdparty/`), `samples/`, `SDAAC_examples/`, `thirdparty/` — not just the `doc/` + root `README.md` subset structured into `sources/docs/teco-al-docs*` elsewhere in this wiki.
- Relationship to `sources/docs/teco-al-docs*`: those pages are curated, schema-conformant, per-topic breakdowns of this repository's documentation only. This directory is the unabridged source, including the actual `interface`+`ual` implementation code referenced (but not reproduced) by the curated pages and by `wiki/kernels/teco-al-gemm.md`, `wiki/kernels/teco-al-conv-forward.md`, and `wiki/kernels/teco-al-add-tensor.md` — e.g. `ual/kernel/add_tensor/add_tensor_ft16.scpp`, `ual/kernel/gemm/`, `interface/include/tecoal.h`.
