# Contributing

MoonWavKit 当前优先保持 v1 边界清晰：WAV/PCM 基础能力优先，压缩音频和播放器能力暂不进入核心包。

提交缺陷报告时，请提供最小可复现字节序列、MoonBit 工具链版本、实际错误码和期望行为。不要在公开 Issue 中上传私有、受版权保护或包含敏感信息的音频文件。较大的 API 或格式支持变更应先通过 Issue 说明使用场景和兼容性影响。

提交前请运行：

```bash
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon info
moon run examples/basic
```

新增 fixture 必须由代码生成或来自许可清晰的公开素材，并在文档中说明来源。

公共 API 变更必须同步 `pkg.generated.mbti`、`docs/API.md`、测试和 `CHANGELOG.md`。解析器、解码器与编码器的修改应同时覆盖成功路径、边界输入和错误码。

## Release Checklist

1. 更新 `moon.mod` 版本，并同步 README 和 CHANGELOG 中的版本号。
2. 运行格式检查、全目标检查、测试、覆盖率、公开接口检查和示例。
3. 使用 `moon package --list` 确认发布包不包含申报材料、个人信息或本地工具。
4. 运行 `moon publish --dry-run`，确认打包后的模块仍能通过 `moon check`。
5. 执行 `moon publish`，并确认 Mooncakes 的版本和构建状态。
6. 推送对应提交，等待 GitHub Actions 成功；需要发布说明时再创建与版本一致的 GitHub Release。
