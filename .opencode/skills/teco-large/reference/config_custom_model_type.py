# BSD 3- Clause License Copyright (c) 2023, Tecorigin Co., Ltd. All rights
# reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)  ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.

"""Config classes for the Gemma4 "unified" checkpoints.

The provided ``google/gemma-4-12B-it`` checkpoint uses the model types
``gemma4_unified`` / ``gemma4_unified_text`` (see ``config.json``), which are
not known to the installed ``transformers`` release.  These lightweight
``PretrainedConfig`` subclasses make the checkpoint loadable by vLLM while
exposing the nested ``text_config`` that vLLM expects for multimodal
checkpoints.

Only the text stack is modelled here; the vision/audio sub-configs are kept
as plain configs so the checkpoint metadata round-trips, but the corresponding
weights are not instantiated (text-only inference).
"""

from transformers import AutoConfig, PretrainedConfig


class Gemma4UnifiedTextConfig(PretrainedConfig):
    model_type = "gemma4_unified_text"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


class Gemma4UnifiedVisionConfig(PretrainedConfig):
    model_type = "gemma4_unified_vision"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


class Gemma4UnifiedAudioConfig(PretrainedConfig):
    model_type = "gemma4_unified_audio"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


class Gemma4UnifiedConfig(PretrainedConfig):
    model_type = "gemma4_unified"

    def __init__(
        self,
        text_config=None,
        vision_config=None,
        audio_config=None,
        **kwargs,
    ):
        if isinstance(text_config, dict):
            text_config = Gemma4UnifiedTextConfig(**text_config)
        elif text_config is None:
            text_config = Gemma4UnifiedTextConfig()
        self.text_config = text_config

        if isinstance(vision_config, dict):
            vision_config = Gemma4UnifiedVisionConfig(**vision_config)
        self.vision_config = vision_config

        if isinstance(audio_config, dict):
            audio_config = Gemma4UnifiedAudioConfig(**audio_config)
        self.audio_config = audio_config

        super().__init__(**kwargs)


def register_configs():
    """Register the Gemma4-unified config classes with ``AutoConfig``."""
    AutoConfig.register(
        "gemma4_unified", Gemma4UnifiedConfig, exist_ok=True
    )
    AutoConfig.register(
        "gemma4_unified_text", Gemma4UnifiedTextConfig, exist_ok=True
    )
    AutoConfig.register(
        "gemma4_unified_vision", Gemma4UnifiedVisionConfig, exist_ok=True
    )
    AutoConfig.register(
        "gemma4_unified_audio", Gemma4UnifiedAudioConfig, exist_ok=True
    )


__all__ = [
    "Gemma4UnifiedConfig",
    "Gemma4UnifiedTextConfig",
    "Gemma4UnifiedVisionConfig",
    "Gemma4UnifiedAudioConfig",
    "register_configs",
]