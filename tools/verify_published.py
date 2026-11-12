"""Exercise the tagged Mooncakes package from consumers outside the checkout."""
import argparse
import base64
from pathlib import Path
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "Ridge-Lab/moonwavkit"
TEST = r'''
test "public stream API reads samples across chunk boundaries and rejects short data" {
  let decoder = @wav.WavStreamDecoder::new()
  let got = []
  let emit = fn(block : @wav.FloatBuffer) {
    for sample in block.samples { got.push(sample) }
  }
  let wav = b"RIFF\x28\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x40\x1f\x00\x00\x80\x3e\x00\x00\x02\x00\x10\x00data\x04\x00\x00\x00\x00\x80\x00\x40"
  for i in 0..<wav.length() {
    decoder.feed(wav[i:i+1].to_owned(), emit)
  }
  assert_eq(decoder.finish().sample_rate, 8000)
  assert_eq(got, [-1.0, 0.5])
  let cut = @wav.WavStreamDecoder::new()
  cut.feed(wav[:wav.length()-1].to_owned(), emit)
  try cut.finish() catch {
    @wav.InvalidStream(@wav.ErrorTruncatedData, _, _) => ()
    _ => fail("unexpected EOF error")
  } noraise { _ => fail("one byte missing from PCM16 accepted") }
}
'''


def manifest_value(directory, key):
    manifest = (directory / "moon.mod").read_text(encoding="utf-8")
    return re.search(rf'^{key}\s*=\s*"([^"]+)"', manifest, re.MULTILINE).group(1)


def installed(directory, version):
    package = directory / ".mooncakes" / PACKAGE
    if manifest_value(package, "name") != PACKAGE or manifest_value(package, "version") != version:
        raise RuntimeError(f"Unexpected resolved package at {package}")


def run(*args, directory):
    result = subprocess.run(["moon", *args], cwd=directory, capture_output=True, timeout=300)
    if result.returncode:
        sys.stderr.buffer.write(result.stderr)
        result.check_returncode()
    return result


def verify(directory, version, targets):
    consumer = directory / "reader"
    consumer.mkdir()
    (consumer / "moon.mod").write_text(
        f'name = "consumer/reader"\nversion = "0.0.0"\nimport {{ "{PACKAGE}@{version}" }}\n', encoding="utf-8")
    (consumer / "moon.pkg").write_text(f'import {{ "{PACKAGE}" @wav }} for "test"\n', encoding="utf-8")
    (consumer / "reader_test.mbt").write_text(TEST, encoding="utf-8")
    for target in targets:
        subprocess.run(["moon", "test", "--target", target, "--deny-warn"], cwd=consumer,
                       check=True, timeout=300)
    installed(consumer, version)

    # Copy only the integration sources. Its two direct dependencies must both
    # resolve from the registry, including any shared transitive WAV dependency.
    integration = directory / "fingerprint"
    integration.mkdir()
    for name in ("moon.mod", "moon.pkg", "main.mbt"):
        shutil.copyfile(ROOT / "integrations/moonecho" / name, integration / name)
    wav = directory / "noise.wav"
    rng = random.Random(42)
    with wave.open(str(wav), "wb") as file:
        file.setparams((1, 2, 16000, 0, "NONE", "not compressed"))
        for _ in range(6):
            file.writeframesraw(struct.pack("<16000h", *(rng.randint(-32768, 32767) for _ in range(16000))))
    outputs = []
    for mode in ("full", "stream"):
        result = run("run", "--release", "--target", "wasm", ".", "--", mode, str(wav), directory=integration)
        outputs.append([base64.b64decode(line, validate=True) for line in result.stdout.splitlines()])
    installed(integration, version)
    full, streamed = outputs
    if full != streamed or len(full) != 2 or any(not f.startswith(b"MOONFP01") or len(f) <= 64 for f in full):
        raise RuntimeError("MoonEcho fingerprints differ or are empty")
    print(f"Registry {PACKAGE}@{version} passed {targets} and both MoonEcho analysis windows")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--targets", nargs="+", choices=("wasm", "wasm-gc", "js", "native"),
                        default=["wasm", "wasm-gc", "js", "native"])
    args = parser.parse_args()
    version = manifest_value(ROOT, "version")
    if args.tag != "v" + version:
        parser.error("release tag does not match module version")
    location = args.work_dir.resolve()
    if any((p / "moon.work").exists() for p in (location, *location.parents)):
        parser.error("choose a directory outside MoonBit workspaces for the registry-only check")
    with tempfile.TemporaryDirectory(dir=location) as tmp:
        verify(Path(tmp), version, args.targets)
