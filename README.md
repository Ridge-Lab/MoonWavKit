# MoonWavKit

MoonWavKit 是一个 MoonBit 原生 WAV 音频解析与 PCM 工具库，面向游戏资源检查、音频可视化、教学实验、WebAssembly 音频应用和自动化素材流水线。

它不是播放器，也不依赖外部音频库；v0.1.1 聚焦 RIFF/WAVE 结构解析、PCM/Float 解码、音频统计、波形摘要、质量检查、内置 fixture 验收矩阵和可复现示例。

## 项目状态

- MoonBit 有效源码规模：约 4800 行，核心实现和测试均为 MoonBit。
- 测试：66 个测试，覆盖解析、解码、统计、处理、校验、元数据、质量检查和 fixture 矩阵。
- 示例：`cmd/main` 和 `examples/basic` 均可运行。
- 发布：已发布到 Mooncakes，包名 `Ridge-Lab/moonwavkit`，当前版本 `0.1.1`。
- 许可证：MIT，属于 OSI 认可开源许可证。

## 支持范围

已支持：

- RIFF/WAVE header 与 chunk 遍历。
- `fmt `、`data`、`fact`、`LIST/INFO`、`cue `，未知 chunk 会跳过并保留元数据。
- PCM 8-bit unsigned、16/24/32-bit signed 解码。
- IEEE Float 32-bit 解码。
- 音频统计：时长、帧数、peak、RMS、静音样本、削波样本、DC offset。
- PCM 工具：增益、归一化、静音裁剪、反转、线性重采样、混音、拼接、padding、PCM 编码、从 FloatBuffer 构造 WAV。
- 波形工具：bucket 摘要、直方图、文本波形、通道拆分、downmix。
- 质量检查：削波、静音、过低音量、DC offset、crest factor、zero crossing。
- 可运行 fixture catalog，用于回归验证支持矩阵。

暂不支持：

- MP3、AAC、FLAC、OGG 等压缩格式解码。
- WAV 播放器、实时音频设备、复杂 DSP 合成引擎。
- WAVE_FORMAT_EXTENSIBLE 的完整 channel mask/subformat 解析。

## 安装

通过 Mooncakes 安装：

```bash
moon add Ridge-Lab/moonwavkit@0.1.1
```

本地开发：

```bash
moon check
moon test
moon run cmd/main
moon run examples/basic
```

## 最小示例

```moonbit
test "parse decode analyze wav" {
  let bytes = @moonwavkit.fixture_pcm16_mono()
  let parsed = @moonwavkit.parse_wav(bytes)
  assert_true(parsed.ok)
  let decoded = @moonwavkit.decode_pcm(bytes, parsed.wav)
  assert_true(decoded.ok)
  let stats = @moonwavkit.analyze_audio(decoded.float_buffer)
  assert_true(stats.peak >= 0.999)
}
```

## CLI 示例

默认输出 text 报告：

```bash
moon run cmd/main
```

输出 JSON smoke report：

```bash
moon run cmd/main -- --json
```

最小示例：

```bash
moon run examples/basic
```

## API 摘要

| 分类 | API |
| --- | --- |
| 解析 | `parse_wav(bytes)`, `validate_wav(bytes)`, `validate_wav_detailed(bytes)` |
| 解码 | `decode_pcm(bytes, wav)`, `parse_and_decode(bytes)` |
| 统计 | `analyze_audio(buffer)`, `summarize_waveform(buffer, buckets)`, `channel_stats(buffer)` |
| PCM 工具 | `apply_gain`, `normalize_peak`, `trim_silence`, `resample_linear`, `encode_float_to_pcm_bytes`, `build_wav_from_float` |
| 元数据 | `collect_info_catalog`, `collect_cue_timeline`, `describe_wav`, `chunk_table_to_text` |
| 质量 | `inspect_audio_quality`, `quality_profile_to_text`, `recommended_quality_action` |
| 验收 | `fixture_catalog`, `run_fixture_catalog`, `fixture_catalog_passed`, `support_matrix_to_text` |

完整说明见 [docs/API.md](docs/API.md)。

## 项目定位

MoonWavKit 的目标是补齐 MoonBit 生态中“原生音频文件解析与 PCM 基础处理”能力。它可以作为游戏资源检查器、可视化工具、教学 demo、WASM 音频应用和自动化测试 fixture 的底层库。

本项目为原创 MoonBit 开源库；自带 WAV fixture 均由代码生成，不包含第三方音频素材。
