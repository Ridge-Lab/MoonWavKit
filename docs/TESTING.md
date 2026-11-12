# Testing

推荐验收命令：

```bash
moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all --deny-warn
moon test --enable-coverage
moon coverage report -f summary
moon info --target all
moon run cmd/main
moon run cmd/main -- --json
moon run examples/basic
```

`native` 目标需要系统 C 编译器；GitHub Actions 的 Ubuntu 环境已覆盖该目标。本地没有 C 编译器时，仍可分别验证 `wasm`、`wasm-gc` 和 `js` 目标。

覆盖范围：

- RIFF/WAVE header 与 chunk bounds。
- `fmt `、`data`、`fact`、`LIST/INFO`、`cue `。
- PCM 8/16/24/32-bit 与 IEEE Float32。
- 非 RIFF、非 WAVE、缺少 data、unsupported A-law、partial frame、字节边界不匹配和不支持的解码选项。
- 统计、通道拆分、downmix、波形摘要、直方图。
- PCM 工具：gain、normalize、trim、reverse、resample、mix、encode、WAV round trip。
- 区段分析：静音段、普通信号段、响亮段、削波段、覆盖率和文本/CSV 报告。
- 质量检查与 conformance fixture catalog。

测试规模：77 个 MoonBit 测试。CI 对 Wasm 和 native 另执行 `python tools/verify_wav.py --target wasm` 或 `--target native`。它用 Python 标准库 wave 写入并回读 16 份不同位深、声道数和帧数的 PCM 文件，用 struct 构造 Float32 文件，再将文件参数传入实际 CLI 比对帧数、峰值和 RMS。8 个反例检查截断帧、顶层和嵌套块大小、RIFF 容器外的 data、文件读取和上限错误。

## 下游兼容性

在临时目录分别检出 [BoxRIR 的固定提交](https://github.com/zhangbowen2006/BoxRIR/tree/6949c70d6f83edbc9bc785630f5e3ec523bd8444)和 [MoonEcho 的固定提交](https://github.com/lin2077-zeming/MoonEcho/tree/a279b61a1ddfe2ca38dbdd5c2ce30be1cbe0a113)。两者的 `moon.mod` 均声明使用 MoonWavKit 0.1.3。要复核升级兼容性，只将清单中的 `Ridge-Lab/moonwavkit@0.1.3` 改为 `Ridge-Lab/moonwavkit@0.1.5`，保留其余依赖、源码和测试，然后在各项目根目录执行：

```sh
moon version --all
moon test --target wasm
```

2026-11-12 用 moonc `0.10.20+65efd5b93` 和发布包 0.1.5 复跑，BoxRIR 的 31 项测试全部通过。其中一项用 Float32 WAV 往返写读 `[0.0, 2.5, -3.0, 0.125]`。房间声学计算需要保留这个动态范围，按单位振幅截断将导致该断言失败。[下游原始断言](https://github.com/zhangbowen2006/BoxRIR/blob/6949c70d6f83edbc9bc785630f5e3ec523bd8444/io/wav_wbtest.mbt#L1-L10)

同一环境中，MoonEcho 的 38 项测试全部通过。另在 MoonEcho 根目录运行 `moon run examples/wav-adapter --target wasm`，其 WAV 输入经过解码、混音与重采样后输出单声道、16 kHz、6 帧。[音频输入测试](https://github.com/lin2077-zeming/MoonEcho/blob/a279b61a1ddfe2ca38dbdd5c2ce30be1cbe0a113/src/audio/audio_test.mbt)

## Float32 解码基准

`moon bench --target js -p Ridge-Lab/moonwavkit -f decoder_bench_wbtest.mbt` 解码一秒、48 kHz 的单声道 Float32 音频，同时生成整数和浮点两个缓冲区。构造样本和解析 RIFF 在计时前完成。CI 运行同一基准并校验输出，耗时只供比较。

Windows x64、i7-12700H、Node 24.14.1、moonc 0.10.20 上，使用相同基准连续独立运行三次，每次由 `moon bench` 统计 10 组。使用提交 `4c573ca` 的解码器时，三次均值为 2.28、2.16、2.21 ms。改为每个样本读取一次，并直接转换 IEEE 位模式后，均值为 0.848、0.827、0.853 ms。这些时间只覆盖上述内存输入和 JS 后端。
