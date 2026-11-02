#!/usr/bin/env python3
"""Report which attention implementation actually runs (SDPA vs explicit einsum).

Patching both entry points and running one short generation reveals the real path
on this backend, resolving the "does SDAA use einsum or SDPA math" question.
"""

from __future__ import annotations

import sys

import torch
import torch.nn.functional as F


def main(argv: list[str]) -> int:
    import rfproteina  # noqa: F401
    import rfproteina.nn.modules.pair_bias_attn as pba

    counts = {"sdpa": 0, "einsum": 0}
    orig_sdpa = F.scaled_dot_product_attention
    orig_einsum = pba._einsum_attention

    def sdpa(*args, **kwargs):
        counts["sdpa"] += 1
        return orig_sdpa(*args, **kwargs)

    def einsum(*args, **kwargs):
        counts["einsum"] += 1
        return orig_einsum(*args, **kwargs)

    F.scaled_dot_product_attention = sdpa
    pba._einsum_attention = einsum

    from rfproteina.generate import main_hydra

    sys.argv[0] = "rfproteina.generate"
    try:
        main_hydra()
    finally:
        print(f"ATTENTION_PATH counts={counts} _SDAA_SDPA_UNAVAILABLE={pba._SDAA_SDPA_UNAVAILABLE}",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))