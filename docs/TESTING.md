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

## Float32 解码基准

`moon bench --target js -p Ridge-Lab/moonwavkit -f decoder_bench_wbtest.mbt` 解码一秒、48 kHz 的单声道 Float32 音频，同时生成整数和浮点两个缓冲区。构造样本和解析 RIFF 在计时前完成。CI 运行同一基准并校验输出，耗时只供比较。

Windows x64、i7-12700H、Node 24.14.1、moonc 0.10.20 上，使用相同基准连续独立运行三次，每次由 `moon bench` 统计 10 组。使用提交 `4c573ca` 的解码器时，三次均值为 2.28、2.16、2.21 ms。改为每个样本读取一次，并直接转换 IEEE 位模式后，均值为 0.848、0.827、0.853 ms。这些时间只覆盖上述内存输入和 JS 后端。
