# Project Submission Notes

## 项目类型

原创 MoonBit 开源库。

## 项目目标

为 MoonBit 生态提供可复用的 WAV 解析、PCM 解码、音频统计、质量检查和 fixture 验收基础能力。

## 验收对应关系

- MoonBit 为主要实现语言：核心解析、解码、统计、处理、校验均为 MoonBit。
- 公开仓库：计划使用 `https://github.com/Ridge-Lab/MoonWavKit.git`。
- README：已包含项目目标、安装方式、使用方法、示例和验收命令。
- 示例：`cmd/main` 与 `examples/basic`。
- CI：`.github/workflows/ci.yml` 覆盖检查、测试和示例运行。
- 测试：66 个测试覆盖核心路径和错误路径。
- Mooncakes：仓库创建并登录 Mooncakes 后执行 `moon publish --dry-run` 与 `moon publish`。
- 许可证：MIT。

## 发布前检查

```bash
moon fmt
moon check
moon build
moon test
moon run cmd/main
moon run examples/basic
moon publish --dry-run
```
