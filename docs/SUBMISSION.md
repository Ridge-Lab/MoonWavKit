# Project Submission Notes

## 项目类型

原创 MoonBit 开源库。

## 项目目标

为 MoonBit 生态提供可复用的 WAV 解析、PCM 解码、音频统计、质量检查和 fixture 验收基础能力。

## 验收对应关系

- MoonBit 为主要实现语言：核心解析、解码、统计、处理、校验均为 MoonBit。
- 公开仓库：`https://github.com/Ridge-Lab/MoonWavKit.git`。
- README：已包含项目目标、安装方式、使用方法、示例和验收命令。
- 示例：`cmd/main` 与 `examples/basic`。
- CI：`.github/workflows/ci.yml` 覆盖格式、全目标检查/构建/测试、覆盖率、接口一致性和示例运行。
- 测试：72 个测试覆盖核心路径、错误路径和输入边界。
- Mooncakes：已发布包 `Ridge-Lab/moonwavkit@0.1.3`。
- 许可证：MIT。

## 可复现验收

```bash
moon fmt --check
moon check --deny-warn
moon build
moon test --deny-warn
moon run cmd/main
moon run cmd/main -- --json
moon run examples/basic
```
