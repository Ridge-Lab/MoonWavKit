# MoonWavKit

[![CI](https://github.com/Ridge-Lab/MoonWavKit/actions/workflows/ci.yml/badge.svg)](https://github.com/Ridge-Lab/MoonWavKit/actions/workflows/ci.yml)

MoonWavKit 是一个 MoonBit 原生 WAV 音频解析与 PCM 工具库，面向游戏资源检查、音频可视化、教学实验、WebAssembly 音频应用和自动化素材流水线。

它不是播放器，也不依赖外部音频库；v0.1.5 聚焦 RIFF/WAVE 结构解析、PCM/Float 解码、音频统计、波形摘要、区段分析、质量检查、内置 fixture 验收矩阵和可复现示例。

## 发布与质量

- 测试：77 个测试，覆盖解析、解码、统计、处理、校验、元数据、区段分析、质量检查和 fixture 矩阵。
- 示例：`cmd/main` 和 `examples/basic` 均可运行。
- CI：覆盖格式检查、全目标检查/构建/测试、覆盖率摘要、公开接口一致性和示例运行。
- 发布：Mooncakes 包 `Ridge-Lab/moonwavkit@0.1.5`。
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
- 区段分析：静音段、普通信号段、响亮段、削波段、覆盖率和文本/CSV 报告。
- 质量检查：削波、静音、过低音量、DC offset、crest factor、zero crossing。
- 可运行 fixture catalog，用于回归验证支持矩阵。

暂不支持：

- MP3、AAC、FLAC、OGG 等压缩格式解码。
- WAV 播放器、实时音频设备、复杂 DSP 合成引擎。
- WAVE_FORMAT_EXTENSIBLE 的完整 channel mask/subformat 解析。

解码始终生成归一化 `FloatBuffer`。`DecodeOptions.target_channels` 只接受 `0`（保留源声道）或与源文件相同的声道数；声道转换请显式调用 `downmix_to_mono` 等处理 API，不会被静默执行。

## 兼容性

- 2026-11-11 使用官方 stable 工具链验证了 0.1.4 和 0.1.5。`moon version --all` 显示 `moonc v0.10.20+65efd5b93 (2026-11-05)`、`moon 0.1.20261104 (940aa18 2026-11-04)` 和 `moonrun 0.1.20261104 (940aa18 2026-11-04)`，功能标记为 `rr_moon_mod,rr_moon_pkg`。更新方法见[官方安装页](https://www.moonbitlang.com/download/)。
- 0.1.4 使用当前编译器的 `#derive` 语法。使用 0.10.8 的现有工程可继续使用 0.1.3，升级到 0.1.4 及以上时请同步升级工具链。
- 默认目标：`wasm-gc`；CI 在 Ubuntu 上检查、构建、测试 `wasm`、`wasm-gc`、`js` 和 `native`。JS 示例需要 Node.js，native 构建需要系统 C 工具链。
- 不依赖浏览器音频 API、系统音频设备或第三方音频库。
- 输入由调用方以 `Array[Int]` 提供，库不负责文件系统读取或流式解码。

## 生态差异

[bw448/moon-wav 0.3.0](https://mooncakes.io/docs/bw448/moon-wav) 也能读写 WAV，并提供重采样、音效、峰值和 RMS 分析。需要在编辑器中载入带标记的素材时，MoonWavKit 还能把 `LIST/INFO` 标签和 `cue ` 采样位置交给调用方。游戏资源导入器可以保留片段名称与定位点，质量检查可以标出削波发生的具体区段。

可用 `fixture_with_info_and_cue()` 复核这一区别。我们用两个公开包解码同一份 PCM16 字节，并逐样本核对归一化结果。MoonWavKit 的 `info_tag_value(parsed.wav, "INAM")` 另外给出名称 `tone`，`cue_sample_offsets(parsed.wav)` 返回 `[2]`，在这个 8 kHz 文件中对应 0.25 ms。相关断言见[元数据测试](metadata_test.mbt)。

## 哪些项目在用

- MoonEcho 将 WAV 解码为 PCM，混成单声道并重采样，作为音频指纹检索的输入。它发布的 0.1.4 声明依赖 MoonWavKit 0.1.3。[音频预处理源码](https://github.com/lin2077-zeming/MoonEcho/blob/a279b61a1ddfe2ca38dbdd5c2ce30be1cbe0a113/src/audio/audio.mbt)
- BoxRIR 为房间声学仿真读取 WAV 声源。它用 `parse_wav` 检查格式，再以 `clamp=false` 解码，保留输入振幅。它发布的 0.3.0 声明依赖 MoonWavKit 0.1.3。[声源读取源码](https://github.com/zhangbowen2006/BoxRIR/blob/6949c70d6f83edbc9bc785630f5e3ec523bd8444/io/wav.mbt)

我们在两个项目的独立副本中把依赖升到 0.1.5，分别跑通了 MoonEcho 的 38 项和 BoxRIR 的 31 项 Wasm 测试。[复现步骤](docs/TESTING.md#下游兼容性)

## 安装

通过 Mooncakes 安装：

```bash
moon add Ridge-Lab/moonwavkit@0.1.5
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

从仓库根目录检查实际文件（Wasm 使用 moonrun，native 使用系统 C 编译器）：

```bash
moon run cmd/wavinfo --target wasm -- --json "assets/intro.wav"
moon run cmd/wavinfo --target native -- "assets/intro.wav"
```

`wavinfo` 接收一个不超过 16 MiB 的普通文件，一次读入并解码。成功时退出 0；JSON 报告包含帧数、位深、峰值和 RMS。文件无法读取、超过上限或验证失败时退出 1 并输出错误码。文件入口使用官方 core 的 async/fs，支持 Wasm 和 native；解析库仍支持四个后端。

运行内置 fixture，默认输出 text 报告：

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

内置 PCM16 单声道示例应输出 `sample_rate=8000`、`frames=4`、`peak=1` 和 `fixture_catalog_passed=true`。

## API 摘要

| 分类 | API |
| --- | --- |
| 解析 | `parse_wav(bytes)`, `validate_wav(bytes)`, `validate_wav_detailed(bytes)` |
| 解码 | `decode_pcm(bytes, wav)`, `parse_and_decode(bytes)` |
| 统计 | `analyze_audio(buffer)`, `summarize_waveform(buffer, buckets)`, `channel_stats(buffer)` |
| PCM 工具 | `apply_gain`, `normalize_peak`, `trim_silence`, `resample_linear`, `encode_float_to_pcm_bytes`, `build_wav_from_float` |
| 元数据 | `collect_info_catalog`, `collect_cue_timeline`, `describe_wav`, `chunk_table_to_text` |
| 区段分析 | `segment_audio`, `silence_regions`, `clipping_regions`, `audio_segmentation_to_text` |
| 质量 | `inspect_audio_quality`, `quality_profile_to_text`, `recommended_quality_action` |
| 验收 | `fixture_catalog`, `run_fixture_catalog`, `fixture_catalog_passed`, `support_matrix_to_text` |
| 报告 | `build_report`, `validation_report_to_text`, `quality_profile_to_text`, `region_summary_csv` |

完整接口说明见 [docs/API.md](docs/API.md)，架构与扩展约束见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 项目定位

MoonWavKit 的目标是补齐 MoonBit 生态中“原生音频文件解析与 PCM 基础处理”能力。它可以作为游戏资源检查器、可视化工具、教学 demo、WASM 音频应用和自动化测试 fixture 的底层库。

本项目为原创 MoonBit 开源库；自带 WAV fixture 均由代码生成，不包含第三方音频素材。

安全边界和漏洞报告方式见 [SECURITY.md](SECURITY.md)，参与开发规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。
