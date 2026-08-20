# -*- coding: utf-8 -*-
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "submission" / "MoonWavKit_项目申报书.pdf"
FONT_DIR = Path(r"C:\Windows\Fonts")

TEAM = "没巭起名"
CONTACT = "17692756613"
GITHUB_URL = "https://github.com/Ridge-Lab/MoonWavKit.git"
SUBMIT_DATE = "2026年8月20日"


def register_fonts():
    candidates = [
        ("CN", "Deng.ttf"),
        ("CNBold", "Dengb.ttf"),
    ]
    for name, filename in candidates:
        path = FONT_DIR / filename
        if path.exists():
            pdfmetrics.registerFont(TTFont(name, str(path)))
        else:
            fallback = FONT_DIR / "msyh.ttc"
            pdfmetrics.registerFont(TTFont(name, str(fallback)))


def wrap_text(text, font, size, max_width):
    lines = []
    for paragraph in text.split("\n"):
        current = ""
        for char in paragraph:
            candidate = current + char
            if pdfmetrics.stringWidth(candidate, font, size) <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = char
        if current:
            lines.append(current)
    return lines


def draw_wrapped(c, text, x, y, width, font="CN", size=7.6, leading=10.0, color="#111827"):
    c.setFillColor(colors.HexColor(color))
    c.setFont(font, size)
    for line in wrap_text(text, font, size, width):
        c.drawString(x, y, line)
        y -= leading
    return y


def title(c, x, y, width):
    c.setFillColor(colors.HexColor("#111827"))
    c.setFont("CNBold", 18)
    c.drawCentredString(x + width / 2, y, "MoonWavKit 项目申报书")
    c.setStrokeColor(colors.HexColor("#2563EB"))
    c.setLineWidth(1.1)
    c.line(x, y - 13, x + width, y - 13)


def section(c, name, x, y, width):
    c.setFillColor(colors.HexColor("#2563EB"))
    c.rect(x, y - 3, 4, 12, fill=1, stroke=0)
    c.setFillColor(colors.HexColor("#111827"))
    c.setFont("CNBold", 9.6)
    c.drawString(x + 8, y, name)
    c.setStrokeColor(colors.HexColor("#CBD5E1"))
    c.setLineWidth(0.5)
    c.line(x, y - 7, x + width, y - 7)
    return y - 17


def info_table(c, x, y, width):
    rows = [
        ("项目名称", "MoonWavKit：MoonBit 原生 WAV 音频解析与 PCM 工具库"),
        ("参赛团队/申报人", TEAM),
        ("联系方式", CONTACT),
        ("GitHub 仓库", GITHUB_URL),
        ("项目方向", "MoonBit 原创开源基础库 / 音频文件解析与素材质量检查"),
        ("项目性质", "原创项目；自制测试 WAV fixture；MIT 许可证"),
    ]
    label_w = 86
    row_h = 20
    c.setFont("CNBold", 9.4)
    c.setFillColor(colors.HexColor("#111827"))
    c.drawString(x, y, "基本信息")
    y -= 7
    for label, value in rows:
        c.setStrokeColor(colors.HexColor("#94A3B8"))
        c.setLineWidth(0.55)
        c.setFillColor(colors.HexColor("#F1F5F9"))
        c.rect(x, y - row_h, label_w, row_h, fill=1, stroke=1)
        c.setFillColor(colors.white)
        c.rect(x + label_w, y - row_h, width - label_w, row_h, fill=1, stroke=1)
        c.setFillColor(colors.HexColor("#111827"))
        c.setFont("CNBold", 7.8)
        c.drawString(x + 6, y - 13, label)
        draw_wrapped(c, value, x + label_w + 7, y - 13, width - label_w - 14, size=7.55, leading=8.6)
        y -= row_h
    return y - 10


def bullets(c, items, x, y, width):
    for item in items:
        c.setFillColor(colors.HexColor("#2563EB"))
        c.circle(x + 2, y + 3, 1.3, fill=1, stroke=0)
        y = draw_wrapped(c, item, x + 8, y, width - 8, size=7.35, leading=9.25)
        y -= 1.2
    return y


def main():
    register_fonts()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUT), pagesize=A4)
    page_w, page_h = A4
    margin = 36
    width = page_w - margin * 2

    c.setFillColor(colors.white)
    c.rect(0, 0, page_w, page_h, fill=1, stroke=0)
    title(c, margin, page_h - 34, width)
    y = info_table(c, margin, page_h - 68, width)

    y = section(c, "项目简介", margin, y, width)
    y = draw_wrapped(
        c,
        "MoonWavKit 面向 MoonBit 生态补齐 WAV 音频文件处理基础能力，提供 RIFF/WAVE 结构解析、PCM/IEEE Float 解码、音频统计、波形与区段分析、质量检查、元数据读取和自制 fixture 验收矩阵。项目服务于游戏素材检查、音频可视化、教学实验、WebAssembly 音频工具和自动化资源流水线，区别于编码器、播放器和设备绑定。",
        margin,
        y,
        width,
        size=7.55,
        leading=9.4,
    )
    y -= 6

    left_x = margin
    right_x = margin + width / 2 + 11
    col_w = width / 2 - 11
    left_y = section(c, "核心功能", left_x, y, col_w)
    left_y = bullets(
        c,
        [
            "解析 RIFF/WAVE、fmt、data、fact、LIST/INFO、cue，并保留未知 chunk 边界。",
            "解码 PCM 8/16/24/32-bit 与 IEEE Float32，输出整数 PCM 与统一 FloatBuffer。",
            "提供 peak、RMS、静音、削波、DC offset、波形 bucket、直方图、通道统计。",
            "提供区段识别、增益、归一化、静音裁剪、反转、重采样、混音、PCM 编码和 WAV 构造工具。",
        ],
        left_x,
        left_y,
        col_w,
    )
    right_y = section(c, "工程完成情况", right_x, y, col_w)
    right_y = bullets(
        c,
        [
            "核心库约 4260 行 MoonBit 代码，核心实现不依赖外部音频库。",
            "72 个测试覆盖解析、解码、错误路径、输入边界、处理工具和 fixture catalog。",
            "提供 cmd/main 与 examples/basic 两个可运行入口，CI 覆盖全目标构建、测试和示例运行。",
            "README、API、测试说明、MIT LICENSE、更新日志和安全策略完整。",
        ],
        right_x,
        right_y,
        col_w,
    )

    y = min(left_y, right_y) - 6
    left_y = section(c, "技术路线", left_x, y, col_w)
    left_y = bullets(
        c,
        [
            "以 Array[Int] 表示字节输入，ByteReader 统一处理小端读取、FourCC 与边界检查。",
            "解析层只处理结构和元数据，解码层负责采样格式，分析层和工具层复用 FloatBuffer。",
            "通过内置原创 WAV fixture 覆盖常见格式与异常路径，避免第三方素材版权风险。",
        ],
        left_x,
        left_y,
        col_w,
    )
    right_y = section(c, "工程交付", right_x, y, col_w)
    right_y = bullets(
        c,
        [
            "GitHub 仓库公开可访问，默认分支包含完整源码和连续有效提交记录。",
            "Mooncakes 包 Ridge-Lab/moonwavkit@0.1.3 可安装，构建状态正常。",
            "API 文档、支持边界、测试记录、更新日志和重要技术说明均已纳入仓库。",
        ],
        right_x,
        right_y,
        col_w,
    )

    y = min(left_y, right_y) - 6
    y = section(c, "开源合规与确认", margin, y, width)
    y = draw_wrapped(
        c,
        "本项目为原创 MoonBit 开源库，许可证为 MIT；测试 WAV fixture 均由项目代码构造，不包含来源不明的音频素材或第三方私有代码。项目材料、公开仓库和发布包使用一致的功能范围与版本信息。",
        margin,
        y,
        width,
        size=7.45,
        leading=9.2,
    )
    y -= 4
    c.setStrokeColor(colors.HexColor("#CBD5E1"))
    c.line(margin, y, margin + width, y)
    y -= 15
    c.setFont("CN", 8.2)
    c.setFillColor(colors.HexColor("#111827"))
    c.drawString(margin, y, f"申报团队/申报人：{TEAM}")
    c.drawString(margin + 190, y, f"联系方式：{CONTACT}")
    c.drawString(margin + 360, y, f"日期：{SUBMIT_DATE}")
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
