# MoonWavKit 项目申报书

## 基本信息
- 项目名称：MoonWavKit：MoonBit 原生 WAV 音频解析与 PCM 工具库
- 参赛者：没巭起名（GitHub 账号：Ridge-Lab）
- 联系方式：17692756613
- GitHub 仓库链接：https://github.com/Ridge-Lab/MoonWavKit
- Mooncakes 包：Ridge-Lab/moonwavkit@0.1.3
- 项目方向：MoonBit 音频文件解析基础库 / 素材质量检查工具
- 是否为移植项目：否，原创项目

## 项目简介

MoonWavKit 是一个用 MoonBit 实现的 WAV 音频文件解析与 PCM 处理基础库，解决 MoonBit 应用读取 WAV 结构、解码采样数据、分析波形和自动检查素材质量的问题。项目核心实现约 4260 行 MoonBit 代码，不依赖外部音频库，适用于游戏资源检查、音频可视化、教学实验、WebAssembly 音频工具和自动化素材流水线。

项目边界为 RIFF/WAVE 文件结构和 PCM 数据处理，不包含播放器、实时音频设备接入、流式解码，也不解码 MP3、AAC、FLAC、OGG 等压缩格式。

## 项目方向与适用场景

项目属于 MoonBit 原生音频基础设施，可作为游戏和 Web 素材导入工具、资源 CI 检查器、波形预览程序、教学示例及其他 MoonBit/Wasm 音频应用的底层库。与现有编码器、播放器、音频设备绑定和音乐中间表示包不同，本项目专注 RIFF/WAVE 输入、PCM 解码和素材质量分析。

## 已完成核心功能
- 解析 RIFF/WAVE 文件头，检查文件类型、大小字段和 WAVE 标识；
- 遍历 WAV chunk，支持识别 `fmt `、`data`、`fact`、`LIST/INFO`、`cue ` 等常见 chunk；
- 对未知 chunk 做跳过和记录，避免因为扩展字段导致整个文件无法解析；
- 支持 PCM 8-bit unsigned、16-bit signed、24-bit signed、32-bit signed 的基础解码；
- 支持 IEEE Float32 WAV 的基础解码；
- 提供 `PcmBuffer` 和 `FloatBuffer` 数据结构，用于统计、转换和处理；
- 提供音频信息统计，包括采样率、声道数、bit depth、帧数、时长、peak、RMS、静音样本和削波样本；
- 提供波形摘要能力，可按 bucket 生成波形概览，便于前端显示或命令行报告；
- 提供音频区段分析能力，识别静音段、普通信号段、响亮段和削波段，便于定位素材裁剪与过载问题；
- 提供基础 PCM 处理工具，包括通道拆分、downmix、归一化、静音裁剪、线性重采样、混音、PCM 编码和从 FloatBuffer 构造 WAV；
- 提供 CLI 和示例程序，可以对内置自制 WAV fixture 输出解析报告和质量摘要；
- 提供 72 个 MoonBit 测试，覆盖正常解析、错误输入、不支持格式、截断数据、输入边界、元数据解析和核心处理流程；
- 配置 GitHub Actions，覆盖格式检查、全目标检查/构建/测试、覆盖率、公开接口一致性和示例运行；
- 提供 `cmd/main` 与 `examples/basic` 两个可运行入口，并发布 Mooncakes 包 `Ridge-Lab/moonwavkit@0.1.3`。

## 原创、移植或参考说明
- 本项目为原创 MoonBit 开源项目，不是移植项目；
- 项目没有复制其他语言生态中现有 WAV 库的源码；
- WAV 文件解析依据公开的 RIFF/WAVE 文件格式约定实现；
- 测试用 WAV fixture 由项目代码自行构造，不包含第三方音频素材；
- 本项目许可证：MIT。
