# tools/make_resource_icons.py
# 生成顶部资源栏 4 个小图标（统一暗金/白底模版的 PNG）。
# 图标为 20x20，在 game 中会被 UITheme.COLOR_TEXT_BODY_GOLD 着色，因此本底用白色。
from PIL import Image, ImageDraw

OUT_DIR = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
SIZE = 80          # 高清绘制后降采样
FINAL = 20
WHITE = (255, 255, 255, 255)


def new() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def down(im: Image.Image, name: str) -> None:
    im.resize((FINAL, FINAL), Image.Resampling.LANCZOS).save(f"{OUT_DIR}/{name}.png")


def lingshi() -> Image.Image:
    im = new(); d = ImageDraw.Draw(im)
    cx, cy = SIZE // 2, SIZE // 2
    # 菱形宝石
    d.polygon([(cx, 8), (SIZE - 8, cy), (cx, SIZE - 8), (8, cy)], fill=WHITE)
    # 内部高光切面
    d.polygon([(cx, 14), (SIZE - 18, cy), (cx, cy - 2)], fill=(220, 220, 220, 255))
    return im


def lingqi() -> Image.Image:
    im = new(); d = ImageDraw.Draw(im)
    cx, cy = SIZE // 2, SIZE // 2
    # 螺旋/灵气用三层弧线
    for r, sw in [(34, 8), (24, 6), (14, 4)]:
        d.arc([cx - r, cy - r, cx + r, cy + r], start=60, end=300, fill=WHITE, width=sw)
    return im


def lingzhi() -> Image.Image:
    im = new(); d = ImageDraw.Draw(im)
    cx, cy = SIZE // 2, SIZE // 2
    # 叶片
    d.ellipse([cx - 6, 8, cx + 6, 28], fill=WHITE)
    d.ellipse([cx - 18, 18, cx + 2, 38], fill=WHITE)
    d.ellipse([cx - 2, 18, cx + 18, 38], fill=WHITE)
    # 茎
    d.line([(cx, 28), (cx, SIZE - 8)], fill=WHITE, width=5)
    return im


def shengwang() -> Image.Image:
    im = new(); d = ImageDraw.Draw(im)
    cx, cy = SIZE // 2, SIZE // 2
    # 卷轴/旌旗：立柱 + 飘带
    d.rectangle([cx - 22, 10, cx - 16, SIZE - 10], fill=WHITE)
    d.polygon([(cx - 16, 10), (cx + 20, 18), (cx + 20, 32), (cx - 16, 40)], fill=WHITE)
    # 纹章圆
    d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(200, 200, 200, 255))
    return im


if __name__ == "__main__":
    down(lingshi(), "res_lingshi")
    down(lingqi(), "res_lingqi")
    down(lingzhi(), "res_lingzhi")
    down(shengwang(), "res_shengwang")
    print("resource icons generated")
