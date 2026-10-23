# PROVENANCE

- Source repository: `https://github.com/Tecorigin/PICT_smoke`
- Branch: `main`
- Commit: `9a928d46fe7370d12e7ad76ad9e6134ff949d2e5`
- Fetched: 2026-07-11
- License: none declared in the repository (confirmed via GitHub Licenses API, 404). `readme_en.md` is substantially the original upstream academic project's README (Wang, Tang, Chu; SIGGRAPH 2024); copyright of the original authors, not Tecorigin. See `NOTICE.md` at the wiki root for details.
- Content: complete verbatim working-tree snapshot at the above commit. This is the full repository — including `raymarching/src/` (original CUDA implementation), `raymarching/src_sdaa/` (the SDAA port, a real file-for-file CUDA→SDAA migration pair), `src/` (model implementation), `configs/`, `train.py`, `test.py`, `env_test.py` — not just the two root README files structured into `sources/docs/pict-smoke-docs*` elsewhere in this wiki.
- Relationship to `sources/docs/pict-smoke-docs*` and `wiki/techniques/pict-smoke-cuda-sdaa-model-migration.md`: those pages describe the migration pattern (`TORCH_SDAA_AUTOLOAD`, `USE_SDAA`) at a high level. This directory has the actual migration diff: compare `raymarching/src/raymarching.cu` against `raymarching/src_sdaa/raymarching.scpp`.
