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

测试规模：72 个 MoonBit 测试。最近一次本地覆盖率摘要为 1412/1752 个可执行行（80.6%）；CLI 与示例另由 smoke step 直接运行。
