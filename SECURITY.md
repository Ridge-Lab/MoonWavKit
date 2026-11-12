# Security Policy

MoonWavKit accepts RIFF/WAVE byte arrays and sequential byte blocks. It checks chunk extents and frame alignment. The streaming decoder uses 64-bit offsets for unsigned RIFF lengths and writes complete PCM frames to the caller's callback.

## Supported Versions

Security and correctness fixes are applied to the latest published release.

## Reporting

Report a suspected vulnerability through the repository's GitHub security advisory channel. Do not attach private, copyrighted, or sensitive audio files to a public issue; use the smallest synthetic byte sequence that reproduces the problem.

## Scope

The core library receives its bytes from the caller. The optional `wavinfo` CLI opens a local regular file. The host application controls input size, concurrency, and the lifetime of output blocks. Use `finish` to detect truncated input even when earlier blocks have been delivered.
