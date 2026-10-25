#!/usr/bin/env python3
"""Converts a Hugging Face Whisper checkpoint to the openai-whisper format.

sherpa-onnx's export script loads models with openai-whisper, while
Quran-tuned models such as tarteel-ai/whisper-base-ar-quran are published in
the Hugging Face format. The two hold the same weights under different names.

    python hf_to_openai.py tarteel-ai/whisper-base-ar-quran quran-base.pt
"""

import re
import sys

import torch
from transformers import WhisperForConditionalGeneration

# Applied in order to every key, after the "model." prefix is dropped.
_RENAMES = [
    (r"^(encoder|decoder)\.layers\.", r"\1.blocks."),
    (r"\.self_attn_layer_norm\.", ".attn_ln."),
    (r"\.encoder_attn_layer_norm\.", ".cross_attn_ln."),
    (r"\.final_layer_norm\.", ".mlp_ln."),
    (r"\.self_attn\.", ".attn."),
    (r"\.encoder_attn\.", ".cross_attn."),
    (r"\.q_proj\.", ".query."),
    (r"\.k_proj\.", ".key."),
    (r"\.v_proj\.", ".value."),
    (r"\.out_proj\.", ".out."),
    (r"\.fc1\.", ".mlp.0."),
    (r"\.fc2\.", ".mlp.2."),
    (r"^encoder\.embed_positions\.weight$", "encoder.positional_embedding"),
    (r"^decoder\.embed_positions\.weight$", "decoder.positional_embedding"),
    (r"^decoder\.embed_tokens\.", "decoder.token_embedding."),
    (r"^encoder\.layer_norm\.", "encoder.ln_post."),
    (r"^decoder\.layer_norm\.", "decoder.ln."),
]


def convert(hf_name: str, out_path: str) -> None:
    model = WhisperForConditionalGeneration.from_pretrained(hf_name)
    cfg = model.config
    dims = {
        "n_mels": cfg.num_mel_bins,
        "n_vocab": cfg.vocab_size,
        "n_audio_ctx": cfg.max_source_positions,
        "n_audio_state": cfg.d_model,
        "n_audio_head": cfg.encoder_attention_heads,
        "n_audio_layer": cfg.encoder_layers,
        "n_text_ctx": cfg.max_target_positions,
        "n_text_state": cfg.d_model,
        "n_text_head": cfg.decoder_attention_heads,
        "n_text_layer": cfg.decoder_layers,
    }
    state = {}
    for key, value in model.state_dict().items():
        # The output projection is tied to the token embedding.
        if key == "proj_out.weight":
            continue
        key = key.removeprefix("model.")
        for pattern, repl in _RENAMES:
            key = re.sub(pattern, repl, key)
        state[key] = value.clone()
    torch.save({"dims": dims, "model_state_dict": state}, out_path)
    print(f"saved {out_path}: {dims}")


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
