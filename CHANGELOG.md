# Changelog

## 0.1.5

- Added the Wasm/native wavinfo file command with text/JSON output, failure exits and a 16 MiB file limit.
- Handle empty PCM and an unpadded odd final data chunk. Confine chunks to their RIFF/LIST extents and reject integer overflow before advancing.
- Verify real PCM and Float32 files against Python's wave and struct in CI, including malformed length and truncation cases.

## 0.1.4

- Updated trait derivations for moonc 0.10.20 and preserved public method calls for equality and debug representation.
- Moved package exclusions to `.moonignore`. The library still has no external runtime dependencies.
- Check the public PCM example and the JSON report on each supported backend with the stable SDK.

## 0.1.3

- Clarified runtime dependency and compatibility boundaries in the README.
- Added architecture, invariants, complexity, and extension guidance.
- Added issue and pull request templates for maintainable project collaboration.
- Documented the reproducible release checklist and synchronized submission materials.

## 0.1.2

- Added audio segmentation analysis for silence, quiet signal, loud signal, and clipping regions.
- Added segmentation reports, tests, and documentation.
- Hardened decode option validation and byte-array bounds checks.
- Expanded strict multi-target CI, coverage reporting, public interface checks, and final acceptance documentation.

## 0.1.1

- Synchronized README and submission notes with the published Mooncakes package status.

## 0.1.0

- Initial MoonWavKit hackathon version.
- Added RIFF/WAVE parser, chunk traversal, format model, INFO and cue parsing.
- Added PCM 8/16/24/32-bit and IEEE Float32 decode.
- Added audio stats, waveform summary, PCM processing, quality checks, metadata helpers, conformance fixtures, CLI and basic example.
- Published Mooncakes package `Ridge-Lab/moonwavkit@0.1.0`.
