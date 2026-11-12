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

## 分块解码

`WavStreamDecoder::new(clamp=true)` 接收顺序到达的 RIFF/WAVE 字节。调用方可以直接把文件读出的各块交给解码器。

```moonbit
fn count_frames(chunks : Array[Bytes]) -> Int64 raise @moonwavkit.WavStreamError {
  let decoder = @moonwavkit.WavStreamDecoder::new()
  let mut frames = 0L
  for chunk in chunks {
    decoder.feed(chunk, block => frames += block.frame_count().to_int64())
  }
  ignore(decoder.finish())
  frames
}
```

回调收到的 `FloatBuffer` 拥有自己的交错声道样本，每批最多 2,048 帧且对应最多 64 KiB 的源 PCM。消费完即释放即可按固定空间处理长文件。若调用方保存所有块，调用方的内存仍按时长增长。整数归一化和 Float32 的有限值、NaN、无穷值处理与 `decode_pcm` 一致，`clamp=false` 保留超单位范围的有限浮点数。

`feed` 可以接收空块。它跨输入块拼合头部和数据，跳过带填充的附加块。`finish` 核实容器完整性并返回格式，包括零帧文件。错误携带 `WavErrorKind`、64 位字节位置和原因，解码器会保留首次流格式错误。EOF 或尾部块可能在若干音频块已经交付后才触发错误，需要原子交付的调用方应在 `finish` 成功后提交结果。

支持一个 `fmt ` 后跟一个 `data` 的小端 RIFF/WAVE，遵守 32 位 RIFF 长度并兼容末尾奇数字节 `data` 省略填充。只处理第一个 RIFF 容器，超出容器的尾随字节不参与解码。附加块只校验顶层长度，不提取或解析 INFO、cue 等内部元数据。RF64、多段 wavl、压缩音频和 extensible 格式超出当前支持范围。

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

支持 PCM 8/16/24/32-bit 和 IEEE Float32 的 RIFF/WAVE 文件。整文件解析器识别 `fmt `、`data`、`fact`、`LIST/INFO` 与 `cue `，并保留未知 chunk 的标识和边界。`cmd/wavinfo` 负责文件访问。
