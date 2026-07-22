# MoonWavKit API

## Core Types

- `ByteReader`：安全读取小端字节、FourCC、PCM 整数。
- `RiffHeader` / `WaveChunk` / `WaveFormat` / `ParsedWav`：WAV 结构模型。
- `PcmBuffer` / `FloatBuffer`：整数 PCM 与归一化浮点采样。
- `AudioStats` / `WaveformSummary` / `QualityProfile`：分析结果模型。
- `ValidationReport`：结构校验与兼容性报告。

## Parse

`parse_wav(bytes)` 返回 `WavParseResult`，成功时包含 header、format、chunks、INFO tags、cue points、data offset/size。

`validate_wav(bytes)` 返回单个 `WavError`，适合快速失败判断。

`validate_wav_detailed(bytes)` 返回 `ValidationReport`，适合 CLI、CI 或素材流水线展示。

## Decode

`decode_pcm(bytes, wav)` 将 `ParsedWav` 的 data chunk 解码为：

- `PcmBuffer`：保留整数采样。
- `FloatBuffer`：统一归一化为 `[-1.0, 1.0]` 区间。

`parse_and_decode(bytes)` 是解析加解码的一步入口。

## Analyze

`analyze_audio(buffer)` 计算 duration、frame count、sample count、peak、RMS、静音样本、削波样本和 DC offset。

`summarize_waveform(buffer, buckets)` 生成 min/max/average_abs 波形摘要。

`channel_stats(buffer)` 按通道计算 peak、RMS、均值、静音和削波计数。

## PCM Tools

- `apply_gain(buffer, gain)`
- `normalize_peak(buffer, target_peak=0.95)`
- `trim_silence(buffer, threshold=0.0001, keep_frames=0)`
- `reverse_audio(buffer)`
- `resample_linear(buffer, target_sample_rate)`
- `mix_buffers(a, b, gain_a=1.0, gain_b=1.0)`
- `append_buffers(a, b)`
- `pad_buffer(buffer, left_frames=0, right_frames=0)`

## Metadata

- `collect_info_catalog(wav)`
- `info_tag_value(wav, key)`
- `collect_cue_timeline(wav)`
- `cue_times_seconds(wav)`
- `describe_wav(wav)`

## Conformance

`fixture_catalog_passed()` 运行内置 fixture catalog，可作为 smoke test。

`support_matrix_to_text()` 输出 v1 支持矩阵，便于 README、CLI 和验收材料复用。
