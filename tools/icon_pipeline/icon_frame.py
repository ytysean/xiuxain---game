"""
《太玄宗门录》图标品阶边框 + 合成管线
- 7 张品阶边框（代码绘制，零积分）：凡灰/灵绿/宝蓝/王紫/圣橙/仙金/道红
- 合成：原型底图(中性) + 品阶边框(叠层) -> 最终图标
风格锚定：AI美术生产规范 §四·A 品阶色卡 + UI 硬性约束色板，低饱和、古风。
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
GOLD = (200, 168, 106, 255)      # 暗金 #C8A86A
GOLD_SOFT = (200, 168, 106, 160)

# 七品阶色（低饱和，贴合整体色板）
GRADE_COLORS = {
    "凡品": (183, 178, 168, 255),  # 灰
    "灵品": (127, 191, 160, 255),  # 玉绿
    "宝品": (111, 163, 199, 255),  # 蓝
    "王品": (168, 143, 208, 255),  # 紫
    "圣品": (214, 154, 92, 255),   # 橙
    "仙品": (226, 197, 102, 255),  # 金
    "道品": (194, 80, 74, 255),    # 朱红
}

def _radial_halo(size, max_alpha, inner_frac=0.55):
    """生成边缘强、中心弱的径向 alpha 蒙版（做品阶光晕）。"""
    cx = cy = size // 2
    max_r = size / 2.0
    inner_r = max_r * inner_frac
    mask = Image.new("L", (size, size), 0)
    px = mask.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d <= inner_r:
                a = 0
            else:
                t = min(1.0, (d - inner_r) / (max_r - inner_r))
                a = int(max_alpha * (t * t))  # 平滑提升
            px[x, y] = a
    return mask

def make_frame(grade_name, size=SIZE):
    color = GRADE_COLORS[grade_name]
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # 1) 光晕（品阶色，边缘强），置于底层
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    halo_color = Image.new("RGBA", (size, size), color)
    mask = _radial_halo(size, max_alpha=70)
    halo.paste(halo_color, (0, 0), mask)
    halo = halo.filter(ImageFilter.GaussianBlur(45))
    base = Image.alpha_composite(base, halo)
    # 2) 主描边（品阶色，圆角矩形）
    d = ImageDraw.Draw(base)
    m = 60
    d.rounded_rectangle([m, m, size - m, size - m], radius=90,
                        outline=color, width=34)
    # 3) 内圈暗金细线
    mi = m + 30
    d.rounded_rectangle([mi, mi, size - mi, size - mi], radius=70,
                        outline=GOLD_SOFT, width=8)
    # 4) 四角暗金回纹角饰（L 形括号，略外探）
    corner = 150
    o = m - 14
    lw = 12
    for (x0, y0, sx, sy) in [
        (o, o, 1, 1), (size - o, o, -1, 1),
        (o, size - o, 1, -1), (size - o, size - o, -1, -1)
    ]:
        ax, ay = x0, y0
        bx, by = x0 + sx * corner, y0
        cx2, cy2 = x0, y0 + sy * corner
        d.line([(ax, ay), (bx, by)], fill=GOLD, width=lw)
        d.line([(ax, ay), (cx2, cy2)], fill=GOLD, width=lw)
    return base

def compose(base_path, grade_name, out_path, size=SIZE):
    base = Image.open(base_path).convert("RGBA")
    if base.size != (size, size):
        base = base.resize((size, size), Image.LANCZOS)
    frame = make_frame(grade_name, size)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas = Image.alpha_composite(canvas, frame)   # 光晕在底
    canvas = Image.alpha_composite(canvas, base)     # 底图在中
    # 边框描边再压一层（让边框盖在物体边缘之上）
    border_only = make_frame(grade_name, size)
    # border_only 含光晕，需仅取描边部分：重画纯描边层
    border_only = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border_only)
    m = 60
    bd.rounded_rectangle([m, m, size - m, size - m], radius=90, outline=GRADE_COLORS[grade_name], width=34)
    mi = m + 30
    bd.rounded_rectangle([mi, mi, size - mi, size - mi], radius=70, outline=GOLD_SOFT, width=8)
    corner = 150; o = m - 14; lw = 12
    for (x0, y0, sx, sy) in [(o,o,1,1),(size-o,o,-1,1),(o,size-o,1,-1),(size-o,size-o,-1,-1)]:
        bd.line([(x0,y0),(x0+sx*corner,y0)], fill=GOLD, width=lw)
        bd.line([(x0,y0),(x0,y0+sy*corner)], fill=GOLD, width=lw)
    canvas = Image.alpha_composite(canvas, border_only)
    canvas.save(out_path)
    return out_path

if __name__ == "__main__":
    import os
    out_dir = os.path.join(os.path.dirname(__file__), "preview_frames")
    os.makedirs(out_dir, exist_ok=True)
    for g in GRADE_COLORS:
        f = make_frame(g)
        # 放深墨底上便于预览边框形态
        bg = Image.new("RGBA", (SIZE, SIZE), (30, 43, 40, 255))
        preview = Image.alpha_composite(bg, f)
        preview.save(os.path.join(out_dir, "frame_%s.png" % g))
        print("frame saved:", g)
