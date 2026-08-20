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

`DecodeOptions` 的 v0.1 行为：

- `normalize=true` 是固定支持模式，确保 `FloatBuffer` 使用归一化采样；`false` 会返回 `invalid-argument`。
- `clamp=true` 将 Float32 异常幅值限制到 `[-1.0, 1.0]`，设为 `false` 时保留文件中的浮点幅值。
- `target_channels=0` 保留源声道；也可以显式填写源声道数。其他值会返回 `invalid-argument`，声道转换不会被静默执行。
- `decode_pcm` 会重新校验 `ParsedWav` 的 data 边界，传入不匹配或截断的字节数组会返回 `truncated-data`。

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

## Segmentation

`segment_audio(buffer, options?)` 按帧识别 silence、quiet、signal、loud 和 clipping 区段，返回每段的起止帧、峰值和 RMS。

`silence_regions(buffer, min_region_frames?, threshold?)` 提取连续静音区段，适合素材自动裁剪前的检查。

`clipping_regions(buffer, min_region_frames?, threshold?)` 提取连续削波区段，适合 CI 中定位音频素材过载问题。

`audio_segmentation_to_text(report)` 和 `region_summary_csv(report)` 输出可读报告，便于 CLI、日志和资源流水线使用。

`min_region_frames` 用于过滤短于阈值的瞬态区段，因此各类型 coverage 之和可能小于 1。

## Errors

公共解析与解码入口不通过异常表示可预期的格式错误，而是返回 `WavError` 或带 `ok` 字段的结果类型。稳定错误码包括 `too-short`、`not-riff`、`not-wave`、`chunk-out-of-bounds`、`missing-fmt`、`missing-data`、`unsupported-format`、`invalid-format`、`truncated-data` 和 `invalid-argument`。

## Format Boundary

支持 PCM 8/16/24/32-bit 和 IEEE Float32 的 RIFF/WAVE 文件。解析器识别 `fmt `、`data`、`fact`、`LIST/INFO` 与 `cue `，并保留未知 chunk 的标识和边界。压缩编码、RF64、完整 WAVE_FORMAT_EXTENSIBLE、文件系统读取、流式解码和播放不属于 v0.1 API。
