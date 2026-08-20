# Contributing

MoonWavKit 当前优先保持 v1 边界清晰：WAV/PCM 基础能力优先，压缩音频和播放器能力暂不进入核心包。

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
