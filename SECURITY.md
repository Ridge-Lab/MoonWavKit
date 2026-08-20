# Security Policy

MoonWavKit parses untrusted RIFF/WAVE byte arrays without file-system or network access. All chunk reads are bounds-checked, unknown chunks are skipped, and malformed or unsupported input is reported through stable error values.

## Supported Versions

Security and correctness fixes are applied to the latest published `0.1.x` release.

## Reporting

Report a suspected vulnerability through the repository's GitHub security advisory channel. Do not attach private, copyrighted, or sensitive audio files to a public issue; use the smallest synthetic byte sequence that reproduces the problem.

## Scope

Resource limits for file acquisition, upload size, concurrency, and storage remain the responsibility of the host application. MoonWavKit does not open paths, access audio devices, stream data, or execute embedded metadata.
