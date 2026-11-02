#!/usr/bin/env python3
"""Run generation with a numerical ablation selected by RFPROTEINA_ABLATE.

Values (combine with ','):
  force_einsum  replace F.scaled_dot_product_attention with explicit einsum attention
  no_cuet       disable the cuequivariance fused pair-bias attention

Other ablations are plain Hydra overrides in run_ablation.sh:
  precision=32            (bf16 vs fp32)
  torch_deterministic=true
  nn.tri_mult_backend=torch   (disable cuequivariance triangle multiplication)

usage:
  RFPROTEINA_ABLATE=force_einsum python run_sdaa/experiments/ablate.py <generate overrides...>
"""

from __future__ import annotations

import os
import sys

import torch


def main(argv: list[str]) -> int:
    mode = os.environ.get("RFPROTEINA_ABLATE", "")

    import rfproteina  # noqa: F401  (activates the SDAA compat shim when needed)

    if "force_einsum" in mode:
        import torch.nn.functional as F

        def sdpa_einsum(query, key, value, attn_mask=None, dropout_p=0.0,
                        is_causal=False, scale=None, enable_gqa=False):
            scale = scale if scale is not None else query.shape[-1] ** -0.5
            sim = torch.einsum("bhid,bhjd->bhij", query, key) * scale
            if attn_mask is not None:
                sim = sim + attn_mask
            attn = torch.softmax(sim, dim=-1)
            return torch.einsum("bhij,bhjd->bhid", attn, value)

        F.scaled_dot_product_attention = sdpa_einsum
        print("[ablate] forced explicit einsum attention", file=sys.stderr)

    if "manual_ln" in mode:
        import torch.nn.functional as F

        def rms_norm(x, normalized_shape, weight=None, eps=None):
            eps = eps if eps is not None else torch.finfo(x.dtype).eps
            out = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + eps)
            return out * weight if weight is not None else out

        def layer_norm(x, normalized_shape, weight=None, bias=None, eps=1e-5):
            mean = x.mean(-1, keepdim=True)
            var = x.var(-1, unbiased=False, keepdim=True)
            out = (x - mean) * torch.rsqrt(var + eps)
            if weight is not None:
                out = out * weight
            if bias is not None:
                out = out + bias
            return out

        F.rms_norm = rms_norm
        F.layer_norm = layer_norm
        print("[ablate] using manual (non-fused) LayerNorm/RMSNorm", file=sys.stderr)

    if "no_cuet" in mode:
        import rfproteina.nn.modules.pair_bias_attn as pba

        pba.CUET_AVAILABLE = False
        pba.cuet_attention_pair_bias = None
        print("[ablate] disabled cuequivariance pair-bias attention", file=sys.stderr)

    from rfproteina.generate import main_hydra

    sys.argv[0] = "rfproteina.generate"
    main_hydra()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))