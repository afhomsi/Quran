#!/usr/bin/env python3
"""Transcribes recitation clips with an exported model, as a smoke test.

    python check.py quran-base decoder.onnx clip1.wav clip2.wav ...

Each clip must be 16 kHz mono 16-bit WAV.
"""

import sys
import time
import wave

import numpy as np
import sherpa_onnx


def read_wav(path: str) -> np.ndarray:
    with wave.open(path) as f:
        assert f.getframerate() == 16000 and f.getnchannels() == 1
        data = f.readframes(f.getnframes())
    return np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768


def main() -> None:
    name, decoder, clips = sys.argv[1], sys.argv[2], sys.argv[3:]
    recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
        encoder=f"{name}-encoder.int8.onnx",
        decoder=decoder,
        tokens=f"{name}-tokens.txt",
        language="ar",
        task="transcribe",
        num_threads=2,
    )
    print(f"== {decoder}")
    for clip in clips:
        samples = read_wav(clip)
        start = time.time()
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, samples)
        recognizer.decode_stream(stream)
        took = time.time() - start
        print(f"{clip} ({len(samples) / 16000:.1f}s audio, {took:.1f}s): "
              f"{stream.result.text}")


if __name__ == "__main__":
    main()
