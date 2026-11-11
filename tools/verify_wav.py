"""Exercise the real file CLI with independent stdlib WAV writers and readers."""
import argparse
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave


def chunk(name, data):
    return name + struct.pack("<I", len(data)) + data + bytes(len(data) % 2)


def riff(body):
    return b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body


def check_audio(report, channels, rate, width, values, encoding):
    expected = dict(ok=True, encoding=encoding, channels=channels, sample_rate=rate,
                    bits_per_sample=width * 8, frames=len(values) // channels)
    for key, value in expected.items():
        assert report[key] == value, (key, value, report)
    peak = max(map(abs, values), default=0.0)
    rms = math.sqrt(math.fsum(v * v for v in values) / len(values)) if values else 0.0
    for key, value in (("peak", peak), ("rms", rms)):
        assert math.isclose(report[key], value, rel_tol=1e-10, abs_tol=1e-12), (key, value, report)


def run(target, project):
    def invoke(path, ok):
        result = subprocess.run(
            ["moon", "run", "cmd/wavinfo", "--target", target, "--", "--json", str(path)],
            cwd=project, capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == (0 if ok else 1), (path, result.returncode, result.stderr, result.stdout)
        return json.loads(result.stdout)

    tmp = project / "_build"
    tmp.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=tmp) as tmp_name:
        path = Path(tmp_name) / "real audio.wav"
        count = 0
        for channels in (1, 2):
            for width in (1, 2, 3, 4):
                scale = 1 << (8 * width - 1)
                centered = [-scale, scale // 3, scale - 1, -scale // 7, 0] * channels
                raw = b"".join((v + (128 if width == 1 else 0)).to_bytes(
                    width, "little", signed=width != 1) for v in centered)
                for payload in (b"", raw):
                    with wave.open(str(path), "wb") as wav:
                        wav.setparams((channels, width, 22050, 0, "NONE", "not compressed"))
                        wav.writeframes(payload)
                    with wave.open(str(path), "rb") as wav:
                        data = wav.readframes(wav.getnframes())
                        vals = [(int.from_bytes(data[i:i+width], "little", signed=width != 1)
                                 - (128 if width == 1 else 0)) / scale for i in range(0, len(data), width)]
                        check_audio(invoke(path, True), wav.getnchannels(), wav.getframerate(),
                                    wav.getsampwidth(), vals, "pcm")
                    count += 1

        fmt = chunk(b"fmt ", struct.pack("<HHIIHH", 3, 1, 48000, 192000, 4, 32))
        samples = struct.pack("<5f", -0.75, 0.125, 0.375, 0.5, 0.0)
        audio = chunk(b"data", samples)
        path.write_bytes(riff(fmt + chunk(b"JUNK", b"abc") + audio) + chunk(b"data", bytes(8)))
        check_audio(invoke(path, True), 1, 48000, 4, struct.unpack("<5f", samples), "ieee-float")

        invalid = [
            (riff(fmt + b"data" + struct.pack("<I", 0x7fff_ffff)), "chunk-out-of-bounds"),
            (riff(fmt + chunk(b"LIST", b"INFOINAM" + struct.pack("<I", 0xffff_fff8)) + audio),
             "chunk-out-of-bounds"),
            (riff(fmt + chunk(b"LIST", b"INFOINAM" + struct.pack("<I", 100)) + audio),
             "chunk-out-of-bounds"),
            (riff(fmt + chunk(b"data", b"abc")), "truncated-data"),
            (riff(fmt) + audio, "missing-data"),
            (riff(fmt + audio + b"X"), "chunk-out-of-bounds"),
        ]
        for data, code in invalid:
            path.write_bytes(data)
            assert invoke(path, False) == {"ok": False, "error": code}, code
        path.unlink()
        assert invoke(path, False) == {"ok": False, "error": "input-io"}
        with path.open("wb") as output:
            output.truncate(16 * 1024 * 1024 + 1)
        assert invoke(path, False) == {"ok": False, "error": "input-limit"}
        print(f"{target}: {count} wave PCM files, 1 struct float file, {len(invalid)+2} rejection cases passed")


if __name__ == "__main__":
    if not __debug__:
        raise RuntimeError("Verification requires assertions; run Python without -O")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("wasm", "native"), default="wasm")
    run(parser.parse_args().target, Path(__file__).resolve().parents[1])
