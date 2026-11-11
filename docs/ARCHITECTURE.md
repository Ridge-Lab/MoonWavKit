# MoonWavKit Architecture

## Design Goals

MoonWavKit 将 WAV 文件处理拆分为结构解析、采样解码、信号分析和结果呈现四层。核心包只接收内存中的 `Array[Int]`，不访问文件系统、网络或音频设备，因此可以在 Wasm、WasmGC、JavaScript 和 Native 后端复用。

主要设计目标：

- 对不可信字节输入执行显式边界检查；
- 使用稳定结果类型返回可预期的格式错误；
- 保留 RIFF chunk 信息，避免未知扩展导致整体解析失败；
- 将不同位深统一为可分析的 `FloatBuffer`；
- 让处理、质量检查和报告模块共享同一数据模型；
- 使用代码生成 fixture 保持测试可复现和许可证清晰。

## Data Flow

```text
Array[Int]
   |
   v
ByteReader -> parse_wav -> ParsedWav -> validate_wav_detailed
                              |
                              v
                         decode_pcm
                         /        \
                    PcmBuffer   FloatBuffer
                                    |
              +---------------------+---------------------+
              |                     |                     |
        audio statistics      PCM processing       segmentation
              |                     |                     |
              +---------------------+---------------------+
                                    |
                         text / JSON / CSV reports
```

## Layer Responsibilities

### Byte and RIFF Layer

`ByteReader` 负责小端整数、FourCC 和有符号 PCM 值读取。所有公开解析入口先检查字节范围；越界读取不会成为正常控制流。

`parse_wav` 遍历 RIFF chunk，解析 `fmt `、`data`、`fact`、`LIST/INFO` 和 `cue `。未知 chunk 保留标识、偏移和长度，供验证和诊断使用。

### Decode Layer

`decode_pcm` 校验 `ParsedWav` 与原始字节数组的一致性，再解码 PCM 8/16/24/32-bit 或 IEEE Float32。整数采样保存在 `PcmBuffer`，归一化采样保存在 `FloatBuffer`。

解码层不隐式执行声道转换。调用者需要显式使用 `downmix_to_mono` 等 API，使数据变换在代码和测试中可见。

### Analysis and Processing Layer

统计、波形摘要、直方图、质量检查和区段分析只依赖 `FloatBuffer`。增益、归一化、裁剪、重采样、混音和 WAV 构造同样复用该类型，避免每个功能重复理解文件格式。

### Reporting and Conformance Layer

报告模块提供 text、JSON 和 CSV 形式的稳定输出。conformance fixture catalog 将支持矩阵转化为可执行验收用例，内置示例和 CI 使用同一组 fixture 验证行为。磁盘入口 cmd/wavinfo 将文件内容交给同一个 build_report，跨实现检查从 Python wave 独立生成 PCM 文件。

## Core Invariants

- `FloatBuffer.samples.length()` 必须能被声道数整除；
- `WaveFormat.block_align` 必须等于声道数乘以每采样字节数；
- `WaveFormat.byte_rate` 必须等于采样率乘以 block align；
- data chunk 必须落在输入字节数组范围内并包含完整帧；
- 公共解析和解码错误通过 `WavError` 返回，不依赖异常文本；
- 未支持的格式返回明确错误，不使用近似解码或静默降级。

## Complexity

- RIFF 解析：时间复杂度与 chunk 数及元数据长度线性相关；
- PCM 解码：时间和内存复杂度均与采样数线性相关；
- 统计、波形和区段分析：单次扫描或有限次线性扫描；
- 线性重采样和混音：与输出帧数线性相关。

MoonWavKit 面向已经完整载入内存的素材文件。上传大小、并发、存储和流式读取的资源限制由宿主应用负责。

## Extension Rules

新增编码格式时，应先扩展 `WaveEncoding` 与结构验证，再实现解码和 fixture；不得只添加枚举入口。新增公开 API 必须同步接口文件、API 文档、成功路径测试、错误路径测试和 CHANGELOG。

压缩格式、实时设备和播放器不进入核心包。完整 WAVE_FORMAT_EXTENSIBLE 或 RF64 支持需要单独设计大文件尺寸、channel mask 和 subformat 行为，不能作为现有 PCM 分支的无说明特例。
