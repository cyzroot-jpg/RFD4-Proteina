# BSD 3- Clause License Copyright (c) 2023, Tecorigin Co., Ltd. All rights
# reserved.
# 说明：本文件是"模型适配组网骨架"，供参考；实际请按目标模型改写。
# Adapted to tecorigin hardware
"""Generic model-networking skeleton for TecovLLM / SDAA.

把任意目标模型适配到 TecovLLM 的通用骨架。替换 TODO 部分即可。
关键点：
  * 线性层用 vLLM 的 TP 版（QKV/Row/MergedColumn），Attention 用自定义 backend；
  * Norm/RoPE 一律用 tecovllm_models.layers（内部接 tecoops）；
  * load_weights 处理 packed / 前缀 / k_eq_v / 多模态跳过；
  * 注册 arch 名必须与 config.architectures[0] 一致。
"""

from collections.abc import Iterable
from itertools import islice

import torch
from torch import nn

from vllm.config import VllmConfig, CacheConfig
from vllm.distributed import get_tensor_model_parallel_world_size
from vllm.sequence import IntermediateTensors
from vllm.model_executor.layers.attention import Attention
from vllm.model_executor.layers.linear import (
    QKVParallelLinear,
    RowParallelLinear,
    MergedColumnParallelLinear,
)
from vllm.model_executor.layers.logits_processor import LogitsProcessor
from vllm.model_executor.layers.vocab_parallel_embedding import (
    VocabParallelEmbedding,
    ParallelLMHead,
)
from vllm.model_executor.models.utils import (
    AutoWeightsLoader,
    maybe_prefix,
    make_layers,
    make_empty_intermediate_tensors_factory,
    is_pp_missing_parameter,
    extract_layer_index,
)
from vllm.model_executor.model_loader.weight_utils import default_weight_loader
from vllm.v1.attention.backend import AttentionType

from tecovllm_models.layers.rms_norm import RMSNorm
from tecovllm_models.layers.rotary_embedding import build_rotary_embedding
from tecovllm_models.layers.flash_attn import FlashAttentionBackend


def _get_text_config(config):
    """多模态 checkpoint 取嵌套 text_config；纯文本直接返回。"""
    return getattr(config, "text_config", config)


def _act_and_mul(x: torch.Tensor, act: str = "silu") -> torch.Tensor:
    d = x.shape[-1] // 2
    if act == "silu":
        return torch.nn.functional.silu(x[..., :d]) * x[..., d:]
    if act == "gelu_pytorch_tanh":
        return torch.nn.functional.gelu(x[..., :d], approximate="tanh") * x[..., d:]
    raise ValueError(act)


class ModelMLP(nn.Module):
    def __init__(self, hidden, inter, act, quant_config=None, prefix=""):
        super().__init__()
        self.gate_up_proj = MergedColumnParallelLinear(
            hidden, [inter] * 2, bias=False, quant_config=quant_config,
            prefix=f"{prefix}.gate_up_proj")
        self.down_proj = RowParallelLinear(
            inter, hidden, bias=False, quant_config=quant_config,
            prefix=f"{prefix}.down_proj")
        self.act = act

    def forward(self, x):
        gate_up, _ = self.gate_up_proj(x)
        x = _act_and_mul(gate_up, self.act)
        x, _ = self.down_proj(x)
        return x


class ModelAttention(nn.Module):
    def __init__(self, config, hidden_size, head_dim, max_position,
                 cache_config=None, quant_config=None, prefix="", sliding_window=None):
        super().__init__()
        tp = get_tensor_model_parallel_world_size()
        n_heads = config.num_attention_heads
        n_kv = getattr(config, "num_key_value_heads", n_heads)
        assert n_heads % tp == 0
        self.num_heads = n_heads // tp
        self.num_kv_heads = max(1, n_kv // tp)
        self.head_dim = head_dim
        self.q_size = self.num_heads * head_dim
        self.kv_size = self.num_kv_heads * head_dim
        self.scaling = getattr(config, "attention_scale", head_dim ** -0.5)  # TODO 按模型

        self.qkv_proj = QKVParallelLinear(
            hidden_size, head_dim, n_heads, n_kv, bias=False,
            quant_config=quant_config, prefix=f"{prefix}.qkv_proj")
        self.o_proj = RowParallelLinear(
            n_heads * head_dim, hidden_size, bias=False,
            quant_config=quant_config, prefix=f"{prefix}.o_proj")

        # TODO: 是否 Q/K/V norm（Gemma 系列有）
        self.q_norm = RMSNorm(head_dim, eps=config.rms_norm_eps)
        self.k_norm = RMSNorm(head_dim, eps=config.rms_norm_eps)

        rope = getattr(config, "rope_parameters", None) or {}
        rope = rope.get("full_attention", rope) if isinstance(rope, dict) else {}
        self.rotary_emb = build_rotary_embedding(
            head_dim, max_position,
            rope.get("rope_theta", 10000.0), is_neox_style=True,
            dtype=torch.get_default_dtype(),
            rope_type=rope.get("rope_type", "default"),
            partial_rotary_factor=rope.get("partial_rotary_factor", 1.0))

        self.attn = Attention(
            self.num_heads, head_dim, self.scaling, num_kv_heads=self.num_kv_heads,
            cache_config=cache_config, quant_config=quant_config,
            per_layer_sliding_window=sliding_window,
            prefix=f"{prefix}.attn", attn_type=AttentionType.DECODER,
            attn_backend=FlashAttentionBackend)

    def forward(self, positions, hidden_states):
        qkv, _ = self.qkv_proj(hidden_states)
        q, k, v = qkv.split([self.q_size, self.kv_size, self.kv_size], dim=-1)
        q = self.q_norm(q.unflatten(-1, (self.num_heads, self.head_dim))).flatten(-2, -1)
        k = self.k_norm(k.unflatten(-1, (self.num_kv_heads, self.head_dim))).flatten(-2, -1)
        q, k = self.rotary_emb(positions, q, k)
        out = self.attn(q, k, v)
        out, _ = self.o_proj(out)
        return out


class ModelDecoderLayer(nn.Module):
    def __init__(self, config, cache_config=None, quant_config=None, prefix=""):
        super().__init__()
        layer_type = getattr(config, "layer_types", None)
        idx = extract_layer_index(prefix)
        sliding = config.sliding_window if layer_type and layer_type[idx] == "sliding_attention" else None
        # TODO: 按模型决定 head_dim（可能 dual head_dim）
        head_dim = getattr(config, "head_dim", config.hidden_size // config.num_attention_heads)
        self.self_attn = ModelAttention(
            config, config.hidden_size, head_dim, config.max_position_embeddings,
            cache_config=cache_config, quant_config=quant_config,
            prefix=f"{prefix}.self_attn", sliding_window=sliding)
        self.mlp = ModelMLP(
            config.hidden_size, config.intermediate_size,
            getattr(config, "hidden_activation", "silu"),
            quant_config=quant_config, prefix=f"{prefix}.mlp")
        self.input_layernorm = RMSNorm(config.hidden_size, eps=config.rms_norm_eps)
        self.post_attention_layernorm = RMSNorm(config.hidden_size, eps=config.rms_norm_eps)

    def forward(self, positions, hidden_states, residual):
        if residual is None:
            residual = hidden_states
            hidden_states = self.input_layernorm(hidden_states)
        else:
            hidden_states, residual = self.input_layernorm(hidden_states, residual)
        hidden_states = self.self_attn(positions, hidden_states)
        hidden_states, residual = self.post_attention_layernorm(hidden_states, residual)
        hidden_states = self.mlp(hidden_states)
        return hidden_states, residual


class ModelModel(nn.Module):
    def __init__(self, *, vllm_config: VllmConfig, prefix: str = ""):
        super().__init__()
        config = _get_text_config(vllm_config.model_config.hf_config)
        self.config = config
        cache_config = vllm_config.cache_config
        quant_config = vllm_config.quant_config
        self.embed_tokens = VocabParallelEmbedding(
            config.vocab_size, config.hidden_size, quant_config=quant_config,
            prefix=f"{prefix}.embed_tokens")
        self.start_layer, self.end_layer, self.layers = make_layers(
            config.num_hidden_layers,
            lambda p: ModelDecoderLayer(config, cache_config, quant_config, p),
            prefix=f"{prefix}.layers")
        self.norm = RMSNorm(config.hidden_size, eps=config.rms_norm_eps)
        self.make_empty_intermediate_tensors = make_empty_intermediate_tensors_factory(
            ["hidden_states", "residual"], config.hidden_size)

    def embed_input_ids(self, input_ids):
        return self.embed_tokens(input_ids)

    def forward(self, input_ids, positions, intermediate_tensors=None, inputs_embeds=None):
        hidden_states = inputs_embeds if inputs_embeds is not None else self.embed_input_ids(input_ids)
        residual = None
        for layer in islice(self.layers, self.start_layer, self.end_layer):
            hidden_states, residual = layer(positions, hidden_states, residual)
        if residual is None:
            hidden_states = self.norm(hidden_states)
        else:
            hidden_states, _ = self.norm(hidden_states, residual)
        return hidden_states

    def load_weights(self, weights: Iterable[tuple[str, torch.Tensor]]) -> set[str]:
        stacked = [
            ("qkv_proj", "q_proj", "q"), ("qkv_proj", "k_proj", "k"),
            ("qkv_proj", "v_proj", "v"),
            ("gate_up_proj", "gate_proj", 0), ("gate_up_proj", "up_proj", 1),
        ]
        params = dict(self.named_parameters())
        params.update(dict(self.named_buffers()))
        loaded = set()
        for name, w in weights:
            if "rotary_emb.inv_freq" in name:
                continue
            for pname, sname, sid in stacked:
                if sname not in name:
                    continue
                n = name.replace(sname, pname)
                if n.endswith(".bias") and n not in params:
                    continue
                if is_pp_missing_parameter(n, self) or n not in params:
                    continue
                p = params[n]
                wl = getattr(p, "weight_loader", default_weight_loader)
                if wl == default_weight_loader:
                    wl(p, w)
                else:
                    wl(p, w, sid)
                break
            else:
                if name.endswith(".bias") and name not in params:
                    continue
                if is_pp_missing_parameter(name, self) or name not in params:
                    continue  # 跳过 vision/audio 等无关权重
                p = params[name]
                getattr(p, "weight_loader", default_weight_loader)(p, w)
            loaded.add(name)
        return loaded


class ModelForCausalLM(nn.Module):
    packed_modules_mapping = {
        "qkv_proj": ["q_proj", "k_proj", "v_proj"],
        "gate_up_proj": ["gate_proj", "up_proj"],
    }

    def __init__(self, *, vllm_config: VllmConfig, prefix: str = ""):
        super().__init__()
        config = _get_text_config(vllm_config.model_config.hf_config)
        quant_config = vllm_config.quant_config
        self.config = config
        self.model = ModelModel(vllm_config=vllm_config, prefix=maybe_prefix(prefix, "model"))
        self.lm_head = ParallelLMHead(config.vocab_size, config.hidden_size,
                                      quant_config=quant_config, prefix=maybe_prefix(prefix, "lm_head"))
        if config.tie_word_embeddings:
            self.lm_head = self.lm_head.tie_weights(self.model.embed_tokens)
        self.logits_processor = LogitsProcessor(
            config.vocab_size, soft_cap=getattr(config, "final_logit_softcapping", None))
        self.make_empty_intermediate_tensors = self.model.make_empty_intermediate_tensors

    def embed_input_ids(self, input_ids):
        return self.model.embed_input_ids(input_ids)

    def forward(self, input_ids, positions, intermediate_tensors=None, inputs_embeds=None):
        return self.model(input_ids, positions, intermediate_tensors, inputs_embeds)

    def compute_logits(self, hidden_states):
        return self.logits_processor(self.lm_head, hidden_states)

    def load_weights(self, weights: Iterable[tuple[str, torch.Tensor]]) -> set[str]:
        def it():
            for name, w in weights:
                name = name.replace("language_model.", "")  # TODO 按 checkpoint 前缀调整
                # k_eq_v：full 层只有 k_proj，复制成 v_proj
                if getattr(self.config, "attention_k_eq_v", False) and "self_attn.k_proj" in name:
                    yield name, w
                    yield name.replace("k_proj", "v_proj"), w.clone()
                    continue
                yield name, w

        skip = ["embed_audio.", "embed_vision.", "vision_embedder.",
                "audio_tower.", "vision_tower."]
        if self.config.tie_word_embeddings:
            skip.append("lm_head.")
        return AutoWeightsLoader(self, skip_substrs=skip).load_weights(it())


# --- 注册（放到 tecovllm_models/__init__.py 的 init() 里） ---
# from vllm import ModelRegistry
# ModelRegistry.register_model(
#     model_arch="<config.architectures[0]>",
#     model_cls="tecovllm_models.models.<file>:ModelForCausalLM")