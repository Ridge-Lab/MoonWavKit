# 长录音指纹对照

这个独立消费者使用 MoonWavKit 0.2.0 和 MoonEcho 0.1.4 的公开接口。两条路径对同一份 16 kHz 单声道 WAV 做相同的处理。每 64,000 个样本生成一条 MoonEcho 指纹，末尾的剩余样本也参与计算。全量路径一次解码整个文件，分块路径每次读 65,521 字节，PCM16 的一个样本可以跨越两次读取。两者都将每个窗口完整的指纹字节编码为一行 Base64 输出。

## 输入与复现

实测使用 LibriVox 的《爱丽丝漫游奇境记》第一章，由 Kristen McQuillin 朗读。Project Gutenberg 提供录音来源和公有领域声明。录音可在本地转换，仓库只包含消费者源码。[原始录音与使用说明](https://www.gutenberg.org/files/19573/19573-index.html)

在本目录中使用 MoonBit 0.10.20、Python 3 和 FFmpeg 运行以下命令。使用的 Ogg 原件 SHA-256 为 `0fa73553d78b40c979f5856dbe95c433a99b009e07ce18ca3cb49b43b4dc676d`。

```sh
curl -fL https://www.gutenberg.org/files/19573/ogg/19573-01.ogg -o chapter.ogg
ffmpeg -nostdin -i chapter.ogg -ac 1 -ar 16000 -c:a pcm_s16le -map_metadata -1 -bitexact chapter.wav
moon update
moon run --release --target wasm . -- full chapter.wav > full.txt
moon run --release --target wasm . -- stream chapter.wav > stream.txt
python -c "import base64,hashlib,pathlib; a,b=[pathlib.Path(p).read_bytes().splitlines() for p in ('full.txt','stream.txt')]; assert a==b and len(a)==161; print(len(a),hashlib.sha256(b''.join(map(base64.b64decode,a))).hexdigest())"
```

## 实测

Windows x64、moonc 0.10.20、Wasm release、FFmpeg 7.1。输入为 10,248,329 帧、640.52 秒。Python 标准库按 PCM16 原始样本计算的峰值为 0.629913330078125，RMS 为 0.07050401616046617，与 `wavinfo --stream` 一致。

两条路径的 161 条指纹逐字节相同。串联解码后的 18,697,608 字节，SHA-256 为 `46f7b3cc3a4780f6b8a93fc08f3e9128857124cf9e08c88222dc1ff68ce9c8f4`。音频转换工具版本不同可能改变输入 PCM，重跑时应先在同一输入上比较两条路径。

用同一份编译好的 Wasm 分别启动两个全新 `moonrun` 进程，将标准输出重定向至文件，每 20 ms 读取 Windows 的 `Process.PeakWorkingSet64`。这次全量路径的进程峰值工作集为 **237.4 MiB**，分块路径为 **26.8 MiB**。数值包括 MoonEcho 的频谱、指纹计算和 Wasm 运行时，仅描述此次录音、窗口和运行环境。
