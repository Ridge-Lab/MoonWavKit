# Testing

推荐验收命令：

```bash
moon check
moon build
moon test
moon run cmd/main
moon run cmd/main -- --json
moon run examples/basic
```

覆盖范围：

- RIFF/WAVE header 与 chunk bounds。
- `fmt `、`data`、`fact`、`LIST/INFO`、`cue `。
- PCM 8/16/24/32-bit 与 IEEE Float32。
- 非 RIFF、非 WAVE、缺少 data、unsupported A-law、partial frame。
- 统计、通道拆分、downmix、波形摘要、直方图。
- PCM 工具：gain、normalize、trim、reverse、resample、mix、encode、WAV round trip。
- 质量检查与 conformance fixture catalog。

当前测试规模：66 个 MoonBit 测试。
