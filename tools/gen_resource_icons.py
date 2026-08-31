#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v25.1 资源图标重绘——去卡通化，对齐写实国漫厚涂风格。
设计目标：
  - 青黛冷调低饱和（整体降饱和 35~40%，向场景美术 home_bg_sect_a.png 对齐）
  - 径向渐变代替平涂（有体积感/光泽感，非扁平矢量）
  - 微噪点纹理（模拟油画笔触/厚涂质感）
  - 古铜描边代替亮金（更沉、不跳、融入暗色资源栏）
  - 形状保留辨识度但边缘略带手工感（非完美几何）
输出：art/ui/buttons/res_{lingshi,lingqi,lingzhi,shengwang,xianyu}.png (64×64 RGBA)
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "art", "ui", "buttons")

SS = 4            # 超采样倍数（4× 抗锯齿）
SIZE = 64         # 最终输出尺寸
CANV = SIZE * SS  # 256 画布
C = CANV // 2     # 128 中心
R = CANV // 2 - 28  # 100 半径（留描边空间）

# ── 配色板（青黛冷调 · 低饱和 · 对齐场景美术）──
# 原则：每个色相的 V(明度) 压到 45~65，S(饱和) 压到 35~55

# 灵石：冷灰蓝晶体（原高饱和蓝 → 压为钢青色）
C_LS = (82, 110, 148, 255)       # 主色：钢青
C_LS_L = (120, 148, 185, 255)    # 高光：浅钢青
C_LS_D = (52, 76, 108, 255)      # 暗面：深钢蓝
C_LS_C = (168, 195, 225, 255)    # 切面反光：冷白

# 灵气：暗紫烟霭（原亮紫 → 压为墨紫灰）
C_LQ = (108, 78, 132, 255)       # 主色：墨紫
C_LQ_L = (148, 118, 172, 255)    # 亮纹：淡紫
C_LQ_D = (68, 48, 92, 255)       # 暗部：深紫褐

# 灵植/草药：苍绿（原鲜绿 → 压为松烟绿）
C_LZ = (72, 128, 95, 255)        # 主色：松烟绿
C_LZ_L = (105, 162, 128, 255)    # 叶脉亮：豆绿
C_LZ_D = (42, 82, 60, 255)       # 暗脉：深墨绿

# 声望：古铜褐（原琥珀 → 压为沉铜色）
C_SW = (162, 125, 88, 255)        # 主色：古铜
C_SW_L = (198, 162, 125, 255)     # 亮部：浅铜
C_SW_D = (112, 80, 52, 255)       # 暗部：深铜褐

# 仙玉：青玉（原玉绿 → 压为墨玉青）
C_XY = (78, 145, 132, 255)        # 主色：墨玉
C_XY_L = (115, 178, 165, 255)     # 玉光：浅青玉
C_XY_D = (46, 98, 86, 255)        # 暗部：深青

# ── 描边：古铜（非亮金）──
BRONZE = (168, 140, 98, 220)      # α=220 微半透明，不抢
BRONZE_W = 5                       # 256 画布下 5px ≈ 64 下 1.25px


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (CANV, CANV), (0, 0, 0, 0))


def add_noise(img: Image.Image, amount: int = 8) -> Image.Image:
    """添加微噪点模拟厚涂笔触纹理。"""
    import numpy as np
    arr = np.array(img, dtype=np.uint16)
    noise = np.random.randint(-amount, amount + 1, arr.shape[:2], dtype=np.int16)
    # 只对 RGB 通道加噪，保留 alpha
    for ch in range(3):
        arr[:, :, ch] = np.clip(arr[:, :, ch].astype(np.int16) + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def radial_gradient_fill(draw: ImageDraw.ImageDraw, cx, cy, r,
                          inner_color, outer_color) -> None:
    """用径向渐变填充圆形区域（从中心向外）。"""
    for dr in range(r, 0, -3):
        ratio = dr / r
        r_val = tuple(
            int(inner_color[i] + (outer_color[i] - inner_color[i]) * (1 - ratio))
            for i in range(3)
        ) + (255,)
        draw.ellipse([cx - dr, cy - dr, cx + dr, cy + dr], fill=r_val)


def stroke_shape(draw: ImageDraw.ImageDraw, pts, color=BRONZE, width=BRONZE_W) -> None:
    """给多边形加描边。"""
    n = len(pts)
    for i in range(n):
        a = pts[i]
        b = pts[(i + 1) % n]
        draw.line([a, b], fill=color, width=width, joint="curve")


def poly_gradient(draw: ImageDraw.ImageDraw, pts, inner_color, outer_color,
                  cx=C, cy=C) -> None:
    """多边形填充 + 渐变模拟（用同心缩放多边形近似）。"""
    draw.polygon(pts, fill=outer_color)
    # 内层亮色（缩小版多边形）
    inner_pts = [(cx + (px - cx) * 0.55, cy + (py - cy) * 0.55) for px, py in pts]
    draw.polygon(inner_pts, fill=inner_color)
    # 更内层高光点
    hot_pts = [(cx + (px - cx) * 0.25, cy + (py - cy) * 0.25) for px, py in pts]
    draw.polygon(hot_pts, fill=tuple(min(255, c + 50) for c in inner_color[:3]) + (255,))


# ═══════════════ 5 个图标绘制函数 ═══════════════

def icon_lingshi() -> Image.Image:
    """灵石：钢青六角双锥晶体——切面体+冷光折射。"""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # 上锥
    top_pts = [(C, 24), (C + 70, 100), (C, C + 8), (C - 70, 100)]
    poly_gradient(d, top_pts, C_LS_L, C_LS)
    # 下锥（稍大，透视感）
    bot_pts = [(C, C + 8), (C + 74, 108), (C, CANV - 24), (C - 74, 108)]
    poly_gradient(d, bot_pts, C_LS, C_LS_D)
    # 中间分界线（切面亮线）
    d.line([(C - 60, 102), (C + 60, 102)], fill=C_LS_C, width=3)
    d.line([(C - 30, 62), (C + 30, 62)], fill=C_LS_C, width=2)
    # 小高光点
    d.ellipse([C - 8, 56, C + 8, 72], fill=C_LS_C)
    stroke_shape(d, top_pts)
    stroke_shape(d, bot_pts)
    return img


def icon_lingqi() -> Image.Image:
    """灵气：墨紫烟霭球——内部漩涡+外柔光晕。"""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # 外层光晕（最淡，径向渐变）
    radial_gradient_fill(d, C, C, R + 12, (68, 48, 92, 40), (0, 0, 0, 0))
    # 主体球（径向渐变）
    radial_gradient_fill(d, C, C, R, C_LQ_L, C_LQ)
    # 漩涡纹路（粗→细 螺旋）
    spiral = []
    for i in range(0, 100):
        t = i * 0.16
        r = 14 + 13 * t
        if r > R - 10:
            break
        spiral.append((C + r * math.cos(t * 1.8 + 0.5), C + r * math.sin(t * 1.8 + 0.5)))
    if len(spiral) > 2:
        d.line(spiral, fill=C_LQ_L, width=10, joint="curve")
    # 第二条反向细螺旋
    spiral2 = []
    for i in range(0, 70):
        t = i * 0.20
        r = 8 + 10 * t
        if r > R - 18:
            break
        spiral2.append((C + r * math.cos(-t * 2.2 + 1.0), C + r * math.sin(-t * 2.2 + 1.0)))
    if len(spiral2) > 2:
        d.line(spiral2, fill=(C_LQ_L[0], C_LQ_L[1], C_LQ_L[2], 160), width=5, joint="curve")
    # 外环描边
    d.ellipse([C - R, C - R, C + R, C + R], outline=BRONZE, width=BRONZE_W)
    return img


def icon_lingzhi() -> Image.Image:
    """灵植/草药：松烟绿叶——带叶脉+不规则边缘。"""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # 叶形（略不对称，自然感）
    pts = [
        (C, 22),          # 叶尖
        (C + 52, 78),     # 右上
        (C + 42, 175),    # 右中
        (C + 18, CANV - 22),  # 右底圆
        (C - 18, CANV - 22),  # 左底圆
        (C - 42, 175),    # 左中
        (C - 52, 78),     # 左上
    ]
    poly_gradient(d, pts, C_LZ_L, C_LZ)
    # 主脉（偏左一点，自然弯曲）
    d.line([(C - 4, 28), (C - 6, CANV - 26)], fill=C_LZ_D, width=5)
    # 侧脉（左右交错）
    for yy, dx_r, dx_l in [(75, 28, 22), (120, 32, 26), (165, 24, 18)]:
        d.line([(C - 4, yy), (C - 4 + dx_r, yy + 28)], fill=C_LZ_D, width=3)
        d.line([(C - 6, yy), (C - 6 - dx_l, yy + 26)], fill=C_LZ_D, width=3)
    # 叶尖高光小点
    d.ellipse([C - 5, 26, C + 5, 38], fill=C_LZ_L)
    stroke_shape(d, pts)
    return img


def icon_shengwang() -> Image.Image:
    """声望：古铜令牌——六边形+内嵌徽记+磨损边缘感。"""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # 外六边形（略扁，厚重感）
    outer = [
        (C, 30),
        (C + 72, 78),
        (C + 68, 170),
        (C, 218),
        (C - 68, 170),
        (C - 72, 78),
    ]
    poly_gradient(d, outer, C_SW_L, C_SW)
    # 内嵌菱形徽记（古风纹样）
    inner = [
        (C, 82),
        (C + 32, C - 8),   # C-8 = 120
        (C, C + 44),
        (C - 32, C - 8),
    ]
    poly_gradient(d, inner, C_SW_D, (C_SW_D[0] + 30, C_SW_D[1] + 30, C_SW_D[2] + 30, 255))
    # 内部横线装饰（令牌纹）
    d.line([(C - 20, C), (C + 20, C)], fill=C_SW_L, width=3)
    d.line([(C - 12, C + 16), (C + 12, C + 16)], fill=C_SW_L, width=2)
    stroke_shape(d, outer)
    return img


def icon_xianyu() -> Image.Image:
    """仙玉：墨玉青钱——外圆内方+玉质光泽。"""
    img = new_canvas()
    d = ImageDraw.Draw(img)
    # 外圆（径向渐变模拟玉质光泽）
    radial_gradient_fill(d, C, C, R, C_XY_L, C_XY)
    # 方孔（挖透——深色模拟穿孔）
    hole_size = 42
    hole = [C - hole_size, C - hole_size, C + hole_size, C + hole_size]
    d.rectangle(hole, fill=(28, 58, 52, 200))  # 半透明深色（非全透，有厚度感）
    # 方孔内阴影（左侧+下侧暗线）
    d.line([(C - hole_size, C - hole_size), (C + hole_size, C - hole_size)],
           fill=C_XY_D, width=3)
    d.line([(C - hole_size, C - hole_size), (C - hole_size, C + hole_size)],
           fill=C_XY_D, width=3)
    # 外环描边
    d.ellipse([C - R, C - R, C + R, C + R], outline=BRONZE, width=BRONZE_W)
    # 方孔描边
    d.rectangle([C - hole_size, C - hole_size, C + hole_size, C + hole_size],
                outline=BRONZE, width=BRONZE_W)
    # 玉石高光弧（右上角反光）
    d.arc([C - R + 10, C - R + 10, C + R - 20, C + R - 20],
           start=250, end=320, fill=(200, 230, 220, 140), width=4)
    return img


# ═══════════════ 构建主流程 ═══════════════

BUILDERS = {
    "lingshi": icon_lingshi,
    "lingqi": icon_lingqi,
    "lingzhi": icon_lingzhi,
    "shengwang": icon_shengwang,
    "xianyu": icon_xianyu,
}


def main() -> None:
    random.seed(42)  # 固定种子保证可复现
    os.makedirs(OUT_DIR, exist_ok=True)
    thumbs = []
    for key, fn in BUILDERS.items():
        big = fn()
        # 加噪点（厚涂笔触感）
        big = add_noise(big, amount=6)
        # 下采样
        out = big.resize((SIZE, SIZE), Image.LANCZOS)
        path = os.path.join(OUT_DIR, "res_%s.png" % key)
        out.save(path)
        print("written:", os.path.normpath(path))
        thumbs.append(out)

    # 接触检验图（深青底，横排 5 个）
    sheet = Image.new("RGBA", (SIZE * 5 + 16, SIZE + 16), (22, 32, 42, 255))
    for i, t in enumerate(thumbs):
        sheet.alpha_composite(t, (8 + i * SIZE, 8))
    # 接触检验图属于开发 QA 产物，不进美术资产目录（会触发资产命名校验），
    # 重定向到 tools/_qa/ 下。
    qa_dir = os.path.join(os.path.dirname(__file__), "_qa")
    os.makedirs(qa_dir, exist_ok=True)
    sheet_path = os.path.join(qa_dir, "_icon_contact_sheet.png")
    sheet.convert("RGB").save(sheet_path)
    print("contact sheet:", os.path.normpath(sheet_path))


if __name__ == "__main__":
    main()
