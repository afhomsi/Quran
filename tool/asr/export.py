#!/usr/bin/env python3
"""Exports a converted Quran Whisper checkpoint to sherpa-onnx's format.

Runs sherpa-onnx's scripts/whisper/export-onnx.py (downloaded next to this
file as export_onnx.py) with its model loading pointed at our checkpoint.

    python export.py quran-base

reads ./quran-base.pt and writes quran-base-encoder.int8.onnx,
quran-base-decoder.int8.onnx and quran-base-tokens.txt.

It also writes quran-base-decoder.small.onnx, which quantizes the token
embedding too. Most of the int8 decoder is that embedding left in float32,
so this makes the download much smaller.
"""

import argparse
import sys
from pathlib import Path

import whisper

sys.path.insert(0, str(Path(__file__).parent))
import export_onnx  # noqa: E402


def main() -> None:
    name = sys.argv[1]
    export_onnx.get_args = lambda: argparse.Namespace(model=name)
    export_onnx.load_model = lambda n: whisper.load_model(f"./{n}.pt")

    from whisper.model import disable_sdpa

    import torch

    torch.set_num_threads(1)
    torch.set_num_interop_threads(1)
    with disable_sdpa():
        export_onnx.main()

    from onnxruntime.quantization import QuantType, quantize_dynamic

    quantize_dynamic(
        model_input=f"{name}-decoder.onnx",
        model_output=f"{name}-decoder.small.onnx",
        op_types_to_quantize=["MatMul", "Gather"],
        weight_type=QuantType.QInt8,
    )


if __name__ == "__main__":
    main()
