#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.0.0"]
# ///
"""
Local procedural UI button generator for 《太玄宗门录》.
No cloud API. Draws base plates (states) + line-art icons with Pillow.
Palette locked to project spec: 墨青#1E2B28 / 主绿#2C5F52 / 暗金#C8A86A / 负向#2A2A2A.
Outputs transparent PNGs to ./png/
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "png")
os.makedirs(OUT, exist_ok=True)

# ---- palette (RGB) ----
# 修真世界观调色盘：清冷玄妙、暗金墨线、灵气微光
GOLD       = (165, 138, 88)    # 暗金墨线（古朴，降亮度）
GOLD_HI    = (215, 188, 130)   # 选中高亮
MOQING     = (30, 43, 40)      # 墨青（底板）
BASE_TOP   = (44, 95, 82)      # 主绿
BASE_BOT   = (35, 48, 41)
NEG_TOP    = (54, 54, 54)
NEG_BOT    = (40, 40, 40)
DARK       = (0, 0, 0)
# 修真图标专用色
XUAN_QING  = (28, 52, 55)      # 玄青（冷、沉）
QING_DAI   = (70, 105, 105)    # 青黛
LING_QI    = (125, 185, 175)   # 灵气青（微光）
ZHUSH      = (145, 58, 52)     # 朱砂（丹火/ritual，降饱和）
JADE       = (95, 145, 115)    # 玉石绿（ muted ）
PARCHMENT  = (175, 165, 140)   # 古卷/玉简
INK        = (24, 36, 36)      # 浓墨
# 参考图风格：深青灰哑光 + 暗金描边
CLOUD_CENTER = (44, 95, 90)    # 底板中心，偏青绿
CLOUD_EDGE   = (24, 45, 48)    # 底板边缘，偏玄青

# ---------------------------------------------------------------- helpers
def rr_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0]-1, size[1]-1], radius=r, fill=255)
    return m

def vgradient(size, top, bot):
    w, h = size
    img = Image.new("RGBA", size)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        img.paste((c[0], c[1], c[2], 255), (0, y, w, 1))
    return img

def radial_vignette(size, center_light, edge_dark, power=2.2):
    """edge-darkened radial gradient to mimic reference plate lighting"""
    w, h = size
    cx, cy = w / 2, h / 2
    maxd = math.hypot(w, h) / 2
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy) / maxd
            t = min(1.0, d ** power)
            c = tuple(int(center_light[i] + (edge_dark[i] - center_light[i]) * t) for i in range(3))
            px[x, y] = (c[0], c[1], c[2], 255)
    return img

def add_aura(img, color, strength=0.38):
    """ subtle 灵气 glow behind icon """
    W, H = img.size
    aura = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(aura)
    r = min(W, H) * 0.44
    cx, cy = W // 2, H // 2
    for i in range(int(r), 0, -3):
        a = int(55 * strength * (i / r))
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(color[0], color[1], color[2], a))
    aura = aura.filter(ImageFilter.GaussianBlur(r * 0.30))
    return Image.alpha_composite(aura, img)

def plate(size, r, top, bot, stroke, sw=3, selected=False, center_only=False):
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    grad = vgradient(size, top, bot)
    mask = rr_mask(size, r)
    base.paste(grad, (0, 0), mask)
    w, h = size
    d = ImageDraw.Draw(base)
    # faint cloud arcs (skipped in 9-slice stretch zone when center_only)
    for i in range(3):
        a = 14 + i*22
        if center_only:
            x0, x1 = int(w*0.2) + a, int(w*0.8) - a
        else:
            x0, x1 = a, w - a
        y0, y1 = a, h - a
        if x1 > x0 and y1 > y0:
            d.arc([x0, y0, x1, y1], start=200, end=340, fill=(200,168,106,16))
    # inner shadow (dark inset strokes)
    for i in range(1, 4):
        d.rounded_rectangle([i, i, w-1-i, h-1-i], radius=max(1, r-i),
                            outline=(0, 0, 0, 38 - i*9))
    # main stroke
    d.rounded_rectangle([sw//2, sw//2, w-1-sw//2, h-1-sw//2], radius=r,
                        outline=stroke, width=sw)
    if selected:
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle([0, 0, w-1, h-1], radius=r,
                                                outline=GOLD_HI, width=7)
        glow = glow.filter(ImageFilter.GaussianBlur(7))
        base = Image.alpha_composite(glow, base)
        ImageDraw.Draw(base).rounded_rectangle([sw//2, sw//2, w-1-sw//2, h-1-sw//2],
                                                radius=r, outline=GOLD_HI, width=sw)
    return base

def cloud_corner_mask(size, r, cusp):
    """Rounded rect with concave scallops at 4 corners (placeholder for 如意云头)."""
    w, h = size
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    # main rounded rect
    d.rounded_rectangle([0, 0, w-1, h-1], radius=r, fill=255)
    # cut darker scallop shapes visually in draw step, not mask
    return m

def cloud_plate(size, r, cusp, top, bot, stroke, sw=3, selected=False,
                inner_panel=None, center_only=False):
    """
    Placeholder plate simulating 如意云头 scalloped corners + radial lighting.
    inner_panel: (y0_frac, y1_frac, inset) to draw a recessed bottom panel.
    """
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    # radial edge-darkened fill
    fill = radial_vignette(size, center_light=top, edge_dark=bot, power=2.2)
    mask = cloud_corner_mask(size, r, cusp)
    base.paste(fill, (0, 0), mask)
    w, h = size
    d = ImageDraw.Draw(base)

    # simulated scalloped corners: draw small dark concave quarter-circles at corners
    cc = (0, 0, 0, 55)
    corner_r = cusp
    for cx, cy in [(corner_r, corner_r), (w-1-corner_r, corner_r),
                   (w-1-corner_r, h-1-corner_r), (corner_r, h-1-corner_r)]:
        d.pieslice([cx-corner_r, cy-corner_r, cx+corner_r, cy+corner_r],
                   start=0, end=360, fill=cc)
    # brighten the remaining border to suggest metal rim
    rim = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle([sw//2, sw//2, w-1-sw//2, h-1-sw//2], radius=r,
                         outline=stroke, width=sw)
    rim = rim.filter(ImageFilter.GaussianBlur(0.6))
    base = Image.alpha_composite(base, rim)

    # corner cloud scrolls (concentrated in four corners)
    for i in range(2):
        a = 10 + i*14
        d.arc([a, a, w-a, h-a], start=200, end=340, fill=(200,168,106,12))

    # inner recessed panel (for nav tab bottom label area)
    if inner_panel:
        y0f, y1f, inset = inner_panel
        y0, y1 = int(h*y0f), int(h*y1f)
        pr = max(4, r//2)
        # dark inset shadow
        d.rounded_rectangle([inset+2, y0+2, w-inset-2, y1-2], radius=pr,
                            outline=(0,0,0,60))
        d.rounded_rectangle([inset, y0, w-inset, y1], radius=pr,
                            outline=stroke, width=max(1, sw-1))

    if selected:
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle([0, 0, w-1, h-1], radius=r,
                                                outline=GOLD_HI, width=7)
        glow = glow.filter(ImageFilter.GaussianBlur(7))
        base = Image.alpha_composite(glow, base)
        ImageDraw.Draw(base).rounded_rectangle([sw//2, sw//2, w-1-sw//2, h-1-sw//2],
                                                radius=r, outline=GOLD_HI, width=sw)
    return base

def supersample(draw_fn, size, ss=4, brush=False, brush_kw=None, aura_color=None, aura_strength=0.38):
    W, H = size
    big = Image.new("RGBA", (W*ss, H*ss), (0, 0, 0, 0))
    if brush:
        draw_fn(Brush(big, **(brush_kw or {})), W*ss, H*ss)
    else:
        draw_fn(ImageDraw.Draw(big), W*ss, H*ss)
    img = big.resize((W, H), Image.LANCZOS)
    if aura_color:
        img = add_aura(img, aura_color, aura_strength)
    return img

# ---------------------------------------------------------------- hand-drawn ink brush
# Wraps PIL ImageDraw: every stroke is re-rendered as a wobbly ink brush mark
# (pressure variation + perpendicular jitter + ink bleed + occasional fly-bai).
# Base plates stay crisp (drawn directly) to keep 9-slice seams clean.
HANDDRAWN  = True      # 主开关：True=手绘毛笔风 / False=原几何线稿
INK_JITTER = 0.14      # 笔锋抖动幅度（线宽占比）
INK_BLEED  = 0.06      # 水墨晕染模糊（线宽占比）
INK_ALPHA  = 205       # 墨色不透明度

def _to_rgba(c, a=INK_ALPHA):
    if c is None:
        return None
    if len(c) == 4:
        return c
    return (c[0], c[1], c[2], a)

class Brush:
    def __init__(self, img, jitter=INK_JITTER, bleed=INK_BLEED,
                 auto_fill=False, fill_color=(200, 168, 106)):
        self.img = img
        self.real = ImageDraw.Draw(img)   # fallback for solid fills
        self.jitter = jitter
        self.bleed = bleed
        self.auto_fill = auto_fill
        self.fill_color = fill_color

    def _stroke(self, pts, color, base_w):
        if len(pts) < 2:
            return
        rgba = _to_rgba(color)
        if rgba is None:
            rgba = (GOLD[0], GOLD[1], GOLD[2], INK_ALPHA)
        W, H = self.img.size
        # densify path with perpendicular jitter + brush pressure
        dense = []
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]; x1, y1 = pts[i+1]
            seg = math.hypot(x1 - x0, y1 - y0)
            steps = max(1, int(seg / (base_w * 0.35)))
            nx, ny = (0, 0)
            if seg > 0:
                nx, ny = -(y1 - y0) / seg, (x1 - x0) / seg
            for j in range(steps + 1):
                t = j / steps
                x = x0 + (x1 - x0) * t
                y = y0 + (y1 - y0) * t
                press = 0.80 + 0.20 * math.sin(t * math.pi)   # ends heavier
                jt = random.uniform(-1, 1) * self.jitter * base_w * (0.6 + 0.4 * math.sin(t * math.pi))
                dense.append((x + nx * jt, y + ny * jt, press))
        if not dense:
            return
        # watery halo (ink bleed)
        hlay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); hld = ImageDraw.Draw(hlay)
        hr = max(1.0, base_w * 0.6)
        for (x, y, _) in dense:
            if random.random() < 0.10:
                continue
            hld.ellipse([x - hr, y - hr, x + hr, y + hr], fill=(rgba[0], rgba[1], rgba[2], 55))
        hlay = hlay.filter(ImageFilter.GaussianBlur(base_w * self.bleed * 2.2 + 0.7))
        # solid core
        clay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); cld = ImageDraw.Draw(clay)
        for (x, y, pr) in dense:
            if random.random() < 0.05:        # fly-bai (dry brush gaps)
                continue
            r = max(0.5, base_w * 0.5 * pr)
            cld.ellipse([x - r, y - r, x + r, y + r], fill=rgba)
        clay = clay.filter(ImageFilter.GaussianBlur(max(0.3, base_w * self.bleed)))
        self.img.alpha_composite(hlay)
        self.img.alpha_composite(clay)

    # ---- volumetric color fill (top-lit, bottom-shadowed gradient) ----
    @staticmethod
    def _mix(c, target, t):
        return tuple(int(c[i] + (target[i] - c[i]) * t) for i in range(3))

    def _grad_fill(self, mask_fn, color, bbox):
        x0, y0, x1, y1 = [int(v) for v in bbox]
        W, H = self.img.size
        mask = Image.new("L", (W, H), 0)
        mask_fn(mask)
        grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = grad.load()
        span = max(1, y1 - y0)
        x0c, x1c = max(0, x0), min(W, x1 + 1)
        y0c, y1c = max(0, y0), min(H, y1 + 1)
        for y in range(y0c, y1c):
            t = max(0.0, min(1.0, (y - y0) / span))
            if t < 0.5:
                c = self._mix(color, (255, 255, 255), (0.5 - t) * 0.5)   # toward white at top
            else:
                c = self._mix(color, (0, 0, 0), (t - 0.5) * 0.5)         # toward black at bottom
            for x in range(x0c, x1c):
                gd[x, y] = (c[0], c[1], c[2], 235)
        comp = grad.copy()
        comp.putalpha(mask)
        self.img.alpha_composite(comp)

    def _norm(self, xy):
        xy = list(xy)
        if xy and not isinstance(xy[0], (tuple, list)):
            return [(xy[i], xy[i+1]) for i in range(0, len(xy) - 1, 2)]
        return xy

    def line(self, xy, fill=None, width=1, **kw):
        self._stroke(self._norm(xy), fill, width)

    def polygon(self, xy, outline=None, fill=None, width=1, **kw):
        pts = self._norm(xy)
        if fill is None and self.auto_fill:
            fill = self.fill_color
        if fill is not None:
            xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
            bbox = (min(xs), min(ys), max(xs), max(ys))
            self._grad_fill(lambda m: ImageDraw.Draw(m).polygon(xy, fill=255), fill, bbox)
        if outline is not None and len(pts) > 2:
            self._stroke(pts + [pts[0]], outline, width)

    def rectangle(self, xy, outline=None, fill=None, width=1, **kw):
        if fill is None and self.auto_fill:
            fill = self.fill_color
        if fill is not None:
            self._grad_fill(lambda m: ImageDraw.Draw(m).rectangle(xy, fill=255), fill, xy)
        if outline is not None:
            x0, y0, x1, y1 = xy
            self._stroke([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], outline, width)

    def ellipse(self, xy, outline=None, fill=None, width=1, **kw):
        if fill is None and self.auto_fill:
            fill = self.fill_color
        if fill is not None:
            self._grad_fill(lambda m: ImageDraw.Draw(m).ellipse(xy, fill=255), fill, xy)
        if outline is not None:
            x0, y0, x1, y1 = xy
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
            N = max(18, int(2 * math.pi * max(rx, ry) / (width * 0.45)))
            pts = [(cx + rx * math.cos(2*math.pi*k/N), cy + ry * math.sin(2*math.pi*k/N)) for k in range(N)]
            self._stroke(pts, outline, width)

    def arc(self, xy, start, end, fill=None, width=1, **kw):
        x0, y0, x1, y1 = xy
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
        a0, a1 = math.radians(start), math.radians(end)
        N = max(12, int(abs(end - start) / 4))
        pts = [(cx + rx * math.cos(a0 + (a1 - a0)*k/N), cy + ry * math.sin(a0 + (a1 - a0)*k/N)) for k in range(N + 1)]
        self._stroke(pts, fill, width)

    def rounded_rectangle(self, xy, **kw):
        self.real.rounded_rectangle(xy, **kw)

# ---------------------------------------------------------------- icons
def _frame(W, H, frac=0.72):
    s = min(W, H) * frac
    cx, cy = W/2, H/2
    lw = max(2, int(s * 0.045))
    return s, cx, cy, lw

def _cloud(d, cx, cy, w, h, lw):
    """single 祥云 arc"""
    d.arc([cx - w, cy - h, cx + w, cy + h], start=0, end=180, fill=GOLD, width=max(1, lw - 1))

# --- nav icons ---
def nav_jy(d, W, H):            # 经营 - 宗门太极徽
    s, cx, cy, lw = _frame(W, H, 0.64)
    for dx in (-s*0.28, 0.0, s*0.28):
        _cloud(d, cx+dx, cy + s*0.34, s*0.24, s*0.10, lw)
    r = s*0.26
    yc = cy - s*0.02
    d.ellipse([cx-r, yc-r, cx+r, yc+r], outline=GOLD, width=lw)
    d.arc([cx-r, yc-r, cx, yc+r], start=270, end=90, fill=GOLD, width=max(1,lw-1))
    d.arc([cx, yc-r, cx+r, yc+r], start=90, end=270, fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-s*0.08, yc-s*0.10, cx+s*0.02, yc], outline=GOLD, width=max(1,lw-1))
    d.ellipse([cx-s*0.02, yc, cx+s*0.08, yc+s*0.10], outline=GOLD, width=max(1,lw-1))

def nav_dz(d, W, H):            # 弟子 - 道袍修士剪影
    s, cx, cy, lw = _frame(W, H, 0.66)
    r = s*0.13
    d.polygon([(cx, cy-s*0.50), (cx-s*0.14, cy-s*0.32), (cx+s*0.14, cy-s*0.32)], outline=GOLD, width=lw)
    d.ellipse([cx-r, cy-s*0.34, cx+r, cy-s*0.08], outline=GOLD, width=lw)
    d.polygon([(cx-s*0.28, cy+s*0.42), (cx-s*0.14, cy-s*0.02),
               (cx+s*0.14, cy-s*0.02), (cx+s*0.28, cy+s*0.42)], outline=GOLD, width=lw)
    d.line([cx-s*0.28, cy+s*0.42, cx+s*0.28, cy+s*0.42], fill=GOLD, width=lw)

def nav_ll(d, W, H):            # 历练 - 飞剑御空+灵气尾迹
    s, cx, cy, lw = _frame(W, H, 0.66)
    d.arc([cx-s*0.45, cy-s*0.28, cx+s*0.25, cy+s*0.32], start=210, end=330, fill=LING_QI, width=max(1,lw-1))
    d.line([cx-s*0.32, cy+s*0.30, cx+s*0.34, cy-s*0.34], fill=GOLD, width=lw)
    d.line([cx+s*0.18, cy-s*0.34, cx+s*0.34, cy-s*0.34], fill=GOLD, width=lw)
    d.line([cx+s*0.34, cy-s*0.34, cx+s*0.34, cy-s*0.18], fill=GOLD, width=lw)

def nav_js(d, W, H):            # 纪事 - 玉简仙卷
    s, cx, cy, lw = _frame(W, H, 0.66)
    y1, y2 = cy - s*0.32, cy + s*0.32
    d.line([cx-s*0.38, y1, cx+s*0.38, y1], fill=GOLD, width=lw)
    d.line([cx-s*0.38, y2, cx+s*0.38, y2], fill=GOLD, width=lw)
    d.line([cx-s*0.38, y1, cx-s*0.38, y2], fill=GOLD, width=lw)
    d.line([cx+s*0.38, y1, cx+s*0.38, y2], fill=GOLD, width=lw)
    d.ellipse([cx-s*0.06, cy-s*0.08, cx+s*0.06, cy+s*0.08], outline=GOLD, width=max(1,lw-1))
    d.line([cx, cy-s*0.32, cx, cy-s*0.42], fill=GOLD, width=max(1,lw-1))
    for dy in (-s*0.12, 0, s*0.12):
        d.line([cx-s*0.22, cy+dy, cx+s*0.22, cy+dy], fill=GOLD, width=max(1,lw-2))

def nav_gd(d, W, H):            # 更多 - 三点阵+祥云
    s, cx, cy, lw = _frame(W, H, 0.60)
    _cloud(d, cx, cy + s*0.34, s*0.32, s*0.12, lw)
    r = s*0.09
    for dx in (-s*0.26, 0, s*0.26):
        d.ellipse([cx+dx-r, cy-s*0.04-r, cx+dx+r, cy-s*0.04+r], outline=GOLD, width=lw)

# --- square icons (17) ---
def sq_grid(d, W, H):           # 殿阁总览 - 宗门殿阁群缩影
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.18, cy+s*0.06), (cx, cy-s*0.18), (cx+s*0.18, cy+s*0.06)], outline=GOLD, width=lw)
    d.line([cx-s*0.12, cy+s*0.06, cx-s*0.12, cy+s*0.24], fill=GOLD, width=max(1,lw-1))
    d.line([cx+s*0.12, cy+s*0.06, cx+s*0.12, cy+s*0.24], fill=GOLD, width=max(1,lw-1))
    d.polygon([(cx-s*0.42, cy+s*0.18), (cx-s*0.30, cy+s*0.02), (cx-s*0.18, cy+s*0.18)], outline=GOLD, width=max(1,lw-1))
    d.polygon([(cx+s*0.18, cy+s*0.18), (cx+s*0.30, cy+s*0.02), (cx+s*0.42, cy+s*0.18)], outline=GOLD, width=max(1,lw-1))
    _cloud(d, cx, cy + s*0.34, s*0.38, s*0.14, lw)

def sq_scroll(d, W, H):         # 弟子录 - 玉简名册
    s, cx, cy, lw = _frame(W, H, 0.70)
    d.line([cx-s*0.28, cy-s*0.34, cx+s*0.28, cy-s*0.34], fill=GOLD, width=lw)
    d.line([cx-s*0.28, cy+s*0.34, cx+s*0.28, cy+s*0.34], fill=GOLD, width=lw)
    d.line([cx-s*0.28, cy-s*0.34, cx-s*0.28, cy+s*0.34], fill=GOLD, width=lw)
    d.line([cx+s*0.28, cy-s*0.34, cx+s*0.28, cy+s*0.34], fill=GOLD, width=lw)
    for dy in (-s*0.14, 0, s*0.14):
        d.line([cx-s*0.16, cy+dy, cx+s*0.16, cy+dy], fill=GOLD, width=max(1,lw-1))
    d.line([cx, cy-s*0.34, cx, cy-s*0.46], fill=GOLD, width=max(1,lw-1))

def sq_furnace_sword(d, W, H):  # 丹器炼制 - 丹炉+飞剑
    s, cx, cy, lw = _frame(W, H, 0.70)
    d.polygon([(cx-s*0.16, cy+s*0.08), (cx+s*0.16, cy+s*0.08),
               (cx+s*0.12, cy+s*0.34), (cx-s*0.12, cy+s*0.34)], outline=GOLD, width=lw)
    d.polygon([(cx-s*0.10, cy+s*0.08), (cx+s*0.10, cy+s*0.08), (cx, cy-s*0.14)], outline=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.10, cy+s*0.34, cx-s*0.14, cy+s*0.44], fill=GOLD, width=max(1,lw-1))
    d.line([cx+s*0.10, cy+s*0.34, cx+s*0.14, cy+s*0.44], fill=GOLD, width=max(1,lw-1))
    d.line([cx+s*0.06, cy-s*0.40, cx+s*0.34, cy-s*0.12], fill=GOLD, width=max(1,lw-1))

def sq_cave(d, W, H):           # 宗门洞府 - 洞府入口+禁制光幕
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.50, cy+s*0.42), (cx-s*0.22, cy-s*0.26),
               (cx+s*0.22, cy-s*0.26), (cx+s*0.50, cy+s*0.42)], outline=GOLD, width=lw)
    d.arc([cx-s*0.20, cy-s*0.06, cx+s*0.20, cy+s*0.42], start=180, end=360, fill=GOLD, width=lw)
    d.line([cx-s*0.12, cy+s*0.02, cx+s*0.12, cy+s*0.02], fill=LING_QI, width=max(1,lw-1))

def sq_target(d, W, H):         # 差事目标 - 天心镜/罗盘
    s, cx, cy, lw = _frame(W, H, 0.70)
    r = s*0.34
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=GOLD, width=lw)
    d.ellipse([cx-r*0.6, cy-r*0.6, cx+r*0.6, cy+r*0.6], outline=GOLD, width=max(1,lw-1))
    d.line([cx, cy-s*0.26, cx, cy+s*0.26], fill=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.26, cy, cx+s*0.26, cy], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=GOLD)

def sq_book_coin(d, W, H):      # 宗门库藏 - 玉牌+灵石
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.18, cy-s*0.34), (cx+s*0.18, cy-s*0.34),
               (cx+s*0.12, cy+s*0.12), (cx, cy+s*0.28), (cx-s*0.12, cy+s*0.12)], outline=GOLD, width=lw)
    d.line([cx, cy-s*0.28, cx, cy-s*0.06], fill=GOLD, width=max(1,lw-1))
    d.polygon([(cx+s*0.16, cy-s*0.06), (cx+s*0.32, cy+s*0.02),
               (cx+s*0.24, cy+s*0.22), (cx+s*0.08, cy+s*0.14)], outline=GOLD, width=max(1,lw-1))

def sq_bigroof(d, W, H):        # 宗门正殿 - 重檐仙殿
    s, cx, cy, lw = _frame(W, H, 0.74)
    y0 = cy - s*0.36
    d.polygon([(cx-s*0.50, y0+s*0.16), (cx, y0-s*0.14), (cx+s*0.50, y0+s*0.16),
               (cx+s*0.40, y0+s*0.26), (cx-s*0.40, y0+s*0.26)], outline=GOLD, width=lw)
    d.polygon([(cx-s*0.62, y0+s*0.32), (cx-s*0.10, y0+s*0.18), (cx+s*0.10, y0+s*0.18),
               (cx+s*0.62, y0+s*0.32), (cx+s*0.52, y0+s*0.42), (cx-s*0.52, y0+s*0.42)], outline=GOLD, width=lw)
    d.line([cx-s*0.32, y0+s*0.42, cx-s*0.32, y0+s*0.68], fill=GOLD, width=lw)
    d.line([cx+s*0.32, y0+s*0.42, cx+s*0.32, y0+s*0.68], fill=GOLD, width=lw)
    d.line([cx-s*0.46, y0+s*0.68, cx+s*0.46, y0+s*0.68], fill=GOLD, width=lw)
    d.line([cx, y0-s*0.14, cx, y0-s*0.24], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-3, y0-s*0.28, cx+3, y0-s*0.20], fill=GOLD)

def sq_paifang(d, W, H):        # 执事殿 - 山门云阶
    s, cx, cy, lw = _frame(W, H, 0.74)
    d.line([cx-s*0.42, cy-s*0.40, cx-s*0.42, cy+s*0.42], fill=GOLD, width=lw)
    d.line([cx+s*0.42, cy-s*0.40, cx+s*0.42, cy+s*0.42], fill=GOLD, width=lw)
    d.line([cx-s*0.52, cy-s*0.40, cx+s*0.52, cy-s*0.40], fill=GOLD, width=lw)
    d.polygon([(cx-s*0.52, cy-s*0.40), (cx, cy-s*0.62), (cx+s*0.52, cy-s*0.40)], outline=GOLD, width=lw)
    for i, dy in enumerate((s*0.12, s*0.24, s*0.36)):
        w = s*(0.50 - i*0.08)
        d.line([cx-w, cy+dy, cx+w, cy+dy], fill=GOLD, width=max(1,lw-1))

def sq_leaf(d, W, H):           # 灵田 - 灵草+地脉灵气
    s, cx, cy, lw = _frame(W, H, 0.70)
    for dx in (-s*0.22, 0, s*0.22):
        x = cx + dx
        d.line([x, cy+s*0.34, x, cy-s*0.06], fill=GOLD, width=max(1,lw-1))
        d.polygon([(x, cy-s*0.26), (x+s*0.12, cy-s*0.04), (x-s*0.12, cy-s*0.04)], outline=GOLD, width=max(1,lw-1))
        d.line([x, cy-s*0.14, x+s*0.14, cy-s*0.22], fill=GOLD, width=max(1,lw-2))
        d.line([x, cy-s*0.14, x-s*0.14, cy-s*0.22], fill=GOLD, width=max(1,lw-2))
    d.line([cx-s*0.30, cy+s*0.34, cx+s*0.30, cy+s*0.34], fill=LING_QI, width=max(1,lw-1))
    d.line([cx, cy+s*0.34, cx, cy+s*0.18], fill=LING_QI, width=max(1,lw-1))

def sq_ore(d, W, H):            # 矿脉 - 灵矿晶簇
    s, cx, cy, lw = _frame(W, H, 0.72)
    pts = [(cx-s*0.06, cy+s*0.36), (cx-s*0.26, cy+s*0.06), (cx-s*0.10, cy-s*0.16),
           (cx+s*0.10, cy-s*0.20), (cx+s*0.28, cy+s*0.08), (cx+s*0.08, cy+s*0.36)]
    d.polygon(pts, outline=GOLD, width=lw)
    d.line([cx-s*0.10, cy-s*0.16, cx+s*0.10, cy+s*0.36], fill=GOLD, width=max(1,lw-1))
    d.line([cx+s*0.10, cy-s*0.20, cx-s*0.06, cy+s*0.36], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-2, cy-s*0.04, cx+2, cy+s*0.04], fill=LING_QI)

def sq_scroll_eye(d, W, H):     # 探微阁 - 推演星盘/天眼
    s, cx, cy, lw = _frame(W, H, 0.72)
    r = s*0.34
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=GOLD, width=lw)
    for rr in (r*0.65, r*0.35):
        d.ellipse([cx-rr, cy-rr, cx+rr, cy+rr], outline=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.24, cy-s*0.24, cx+s*0.24, cy+s*0.24], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=GOLD)

def sq_furnace(d, W, H):        # 丹殿 - 三足炼丹炉+丹烟
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.24, cy-s*0.04), (cx+s*0.24, cy-s*0.04),
               (cx+s*0.18, cy+s*0.36), (cx-s*0.18, cy+s*0.36)], outline=GOLD, width=lw)
    d.polygon([(cx-s*0.18, cy-s*0.04), (cx+s*0.18, cy-s*0.04), (cx, cy-s*0.24)], outline=GOLD, width=lw)
    for dx in (-s*0.12, 0, s*0.12):
        d.line([cx+dx, cy+s*0.36, cx+dx, cy+s*0.48], fill=GOLD, width=max(1,lw-1))
    d.arc([cx-s*0.14, cy-s*0.52, cx+s*0.02, cy-s*0.24], start=0, end=180, fill=LING_QI, width=max(1,lw-1))
    d.arc([cx, cy-s*0.58, cx+s*0.16, cy-s*0.30], start=0, end=180, fill=LING_QI, width=max(1,lw-1))

def sq_hammer_sword(d, W, H):   # 器殿 - 飞剑+铸锤+符文
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.line([cx-s*0.10, cy-s*0.34, cx+s*0.30, cy+s*0.10], fill=GOLD, width=lw)
    d.line([cx+s*0.20, cy-s*0.24, cx+s*0.34, cy-s*0.10], fill=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.34, cy+s*0.06, cx-s*0.10, cy+s*0.30], fill=GOLD, width=lw)
    d.line([cx-s*0.42, cy+s*0.06, cx-s*0.22, cy+s*0.06], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-s*0.08, cy-s*0.08, cx+s*0.08, cy+s*0.08], outline=LING_QI, width=max(1,lw-1))

def sq_token(d, W, H):          # 功勋阁 - 功德金令
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.22, cy-s*0.38), (cx+s*0.22, cy-s*0.38), (cx+s*0.16, cy+s*0.08),
               (cx, cy+s*0.34), (cx-s*0.16, cy+s*0.08)], outline=GOLD, width=lw)
    d.ellipse([cx-4, cy-s*0.32, cx+4, cy-s*0.20], outline=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.08, cy-s*0.08, cx+s*0.08, cy-s*0.08], fill=GOLD, width=max(1,lw-1))
    d.line([cx, cy-s*0.16, cx, cy+s*0.08], fill=GOLD, width=max(1,lw-1))

def sq_bagua(d, W, H):          # 阵殿 - 八卦阴阳+阵纹
    s, cx, cy, lw = _frame(W, H, 0.74)
    r = s*0.38
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=GOLD, width=lw)
    d.arc([cx-r, cy-r, cx, cy+r], start=270, end=90, fill=GOLD, width=max(1,lw-1))
    d.arc([cx, cy-r, cx+r, cy+r], start=90, end=270, fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-s*0.10, cy-s*0.14, cx+s*0.02, cy-s*0.02], outline=GOLD, width=max(1,lw-1))
    d.ellipse([cx-s*0.02, cy+s*0.02, cx+s*0.10, cy+s*0.14], outline=GOLD, width=max(1,lw-1))
    for a in range(0, 360, 45):
        rad = math.radians(a)
        x1 = cx + math.cos(rad)*(r*0.72); y1 = cy + math.sin(rad)*(r*0.72)
        x2 = cx + math.cos(rad)*(r*0.92); y2 = cy + math.sin(rad)*(r*0.92)
        d.line([x1, y1, x2, y2], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-r*1.14, cy-r*1.14, cx+r*1.14, cy+r*1.14], outline=LING_QI, width=max(1,lw-1))

def sq_books(d, W, H):          # 藏书阁 - 玉简卷轴
    s, cx, cy, lw = _frame(W, H, 0.72)
    for i, dx in enumerate((-s*0.18, 0, s*0.18)):
        x = cx + dx
        d.rectangle([x-s*0.10, cy-s*0.28, x+s*0.10, cy+s*0.28], outline=GOLD, width=max(1,lw-1))
        d.line([x-s*0.10, cy-s*0.28, x+s*0.10, cy+s*0.28], fill=GOLD, width=max(1,lw-2))
        d.line([x, cy-s*0.34, x, cy-s*0.42], fill=GOLD, width=max(1,lw-1))

def sq_cart(d, W, H):           # 商驿 - 聚宝袋
    s, cx, cy, lw = _frame(W, H, 0.72)
    d.polygon([(cx-s*0.28, cy-s*0.12), (cx+s*0.28, cy-s*0.12),
               (cx+s*0.18, cy+s*0.34), (cx-s*0.18, cy+s*0.34)], outline=GOLD, width=lw)
    d.line([cx-s*0.10, cy-s*0.22, cx+s*0.10, cy-s*0.22], fill=GOLD, width=max(1,lw-1))
    d.line([cx-s*0.10, cy-s*0.22, cx-s*0.14, cy-s*0.12], fill=GOLD, width=max(1,lw-1))
    d.line([cx+s*0.10, cy-s*0.22, cx+s*0.14, cy-s*0.12], fill=GOLD, width=max(1,lw-1))
    d.ellipse([cx-3, cy+s*0.08, cx+3, cy+s*0.16], fill=LING_QI)

# --- micro icons (10) ---
def m_check(d, W, H):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    d.line([cx-s*0.22, cy, cx-s*0.04, cy+s*0.20], fill=GOLD, width=lw)
    d.line([cx-s*0.04, cy+s*0.20, cx+s*0.26, cy-s*0.22], fill=GOLD, width=lw)

def m_x(d, W, H):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    d.line([cx-s*0.2, cy-s*0.2, cx+s*0.2, cy+s*0.2], fill=GOLD, width=lw)
    d.line([cx+s*0.2, cy-s*0.2, cx-s*0.2, cy+s*0.2], fill=GOLD, width=lw)

def m_arrow(d, W, H, dx, dy):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    d.line([cx-dx*s*0.22, cy-dy*s*0.22, cx+dx*s*0.22, cy+dy*s*0.22], fill=GOLD, width=lw)
    if dx and dy == 0:
        d.line([cx+dx*s*0.22, cy+dy*s*0.22, cx+dx*s*0.22-dx*s*0.18, cy+dy*s*0.22-s*0.16], fill=GOLD, width=lw)
        d.line([cx+dx*s*0.22, cy+dy*s*0.22, cx+dx*s*0.22-dx*s*0.18, cy+dy*s*0.22+s*0.16], fill=GOLD, width=lw)
    else:
        d.line([cx+dx*s*0.22, cy+dy*s*0.22, cx+dx*s*0.22-dx*s*0.16, cy+dy*s*0.22-dy*s*0.18], fill=GOLD, width=lw)
        d.line([cx+dx*s*0.22, cy+dy*s*0.22, cx+dx*s*0.22+dx*s*0.16, cy+dy*s*0.22-dy*s*0.18], fill=GOLD, width=lw)

def m_chev(d, W, H, down):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    dy = 1 if down else -1
    d.line([cx-s*0.22, cy-dy*s*0.12, cx, cy+dy*s*0.14], fill=GOLD, width=lw)
    d.line([cx, cy+dy*s*0.14, cx+s*0.22, cy-dy*s*0.12], fill=GOLD, width=lw)

def m_flag(d, W, H):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    d.line([cx-s*0.2, cy-s*0.3, cx-s*0.2, cy+s*0.32], fill=GOLD, width=lw)
    d.polygon([(cx-s*0.2, cy-s*0.3), (cx+s*0.26, cy-s*0.18), (cx-s*0.2, cy-s*0.04)],
              outline=GOLD, width=lw)

def m_info(d, W, H):
    s, cx, cy, lw = _frame(W, H, 0.6); lw = max(2, lw)
    d.ellipse([cx-s*0.3, cy-s*0.3, cx+s*0.3, cy+s*0.3], outline=GOLD, width=lw)
    d.line([cx, cy-s*0.1, cx, cy+s*0.18], fill=GOLD, width=lw)
    d.ellipse([cx-2, cy-s*0.22, cx+2, cy-s*0.18], fill=GOLD)

def m_dots(d, W, H):
    s, cx, cy, lw = _frame(W, H, 0.55)
    r = s*0.09
    for dx in (-s*0.26, 0, s*0.26):
        d.ellipse([cx+dx-r, cy-r, cx+dx+r, cy+r], outline=GOLD, width=max(2, lw-1))

# ---------------------------------------------------------------- registry
NAV = {"jy": nav_jy, "dz": nav_dz, "ll": nav_ll, "js": nav_js, "gd": nav_gd}
SQ = {"jz_zl": sq_grid, "dz_lu": sq_scroll, "dq_lz": sq_furnace_sword, "zm_df": sq_cave,
      "rw_mb": sq_target, "zm_zc": sq_book_coin, "zd_zd": sq_bigroof, "jy_t": sq_paifang,
      "lt": sq_leaf, "km": sq_ore, "tw_g": sq_scroll_eye, "dt": sq_furnace,
      "qt": sq_hammer_sword, "gx_g": sq_token, "zt": sq_bagua, "cs_g": sq_books, "sy": sq_cart}
MIC = {"check": m_check, "x": m_x, "L": lambda d,W,H: m_arrow(d,W,H,-1,0),
       "R": lambda d,W,H: m_arrow(d,W,H,1,0), "U": lambda d,W,H: m_arrow(d,W,H,0,-1),
       "D": lambda d,W,H: m_arrow(d,W,H,0,1), "exp": lambda d,W,H: m_chev(d,W,H,True),
       "col": lambda d,W,H: m_chev(d,W,H,False), "go": m_flag, "info": m_info, "dots": m_dots}

# per-icon base colors (修真世界观 palette): 玄青/青黛/灵气青/朱砂/玉石绿/墨青/古卷
ICON_COLORS = {
    # nav
    "jy": XUAN_QING, "dz": QING_DAI, "ll": LING_QI, "js": PARCHMENT, "gd": XUAN_QING,
    # square
    "jz_zl": XUAN_QING, "dz_lu": PARCHMENT, "dq_lz": ZHUSH, "zm_df": INK,
    "rw_mb": GOLD, "zm_zc": GOLD, "zd_zd": XUAN_QING, "jy_t": QING_DAI,
    "lt": JADE, "km": LING_QI, "tw_g": QING_DAI, "dt": ZHUSH, "qt": QING_DAI,
    "gx_g": GOLD, "zt": XUAN_QING, "cs_g": PARCHMENT, "sy": JADE,
}
DEFAULT_ICON_COLOR = GOLD

# ---------------------------------------------------------------- generate
def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name)

def main():
    random.seed(7)   # stable hand-drawn look across runs
    # base plates
    # 1) nav tab: scalloped vertical with inner bottom panel
    save(cloud_plate((128,160), 12, 10, CLOUD_CENTER, CLOUD_EDGE, GOLD, 3, False,
                     inner_panel=(0.72, 0.92, 14), center_only=True), "nav_base_N.png")
    save(cloud_plate((128,160), 12, 10, CLOUD_CENTER, CLOUD_EDGE, GOLD_HI, 3, True,
                     inner_panel=(0.72, 0.92, 14), center_only=True), "nav_base_S.png")
    # 2) square entry: rounded, clean (matches reference image 1)
    save(plate((256,256), 16, CLOUD_CENTER, CLOUD_EDGE, GOLD, 4, False), "sq_base_N.png")
    save(plate((256,256), 16, CLOUD_CENTER, CLOUD_EDGE, GOLD_HI, 4, True), "sq_base_S.png")
    # 3) horizontal main button: scalloped long plate (reference image 2)
    for st, sw, sel in (("N",3,False),("H",3,False),("P",3,False)):
        save(cloud_plate((512,128), 10, 14, CLOUD_CENTER, CLOUD_EDGE, GOLD, sw, sel, center_only=True), f"rect_pos_{st}.png")
    for st in ("N","H","P"):
        save(cloud_plate((512,128), 10, 14, NEG_TOP, NEG_BOT, (120, 120, 120), 2, False, center_only=True), f"rect_neg_{st}.png")
    # toggle (switch embedded on left)
    def toggle(on):
        base = plate((512,128), 10, BASE_TOP, BASE_BOT, GOLD, 3, False, center_only=True)
        d = ImageDraw.Draw(base)
        sx, sy, sr = 70, 64, 26
        d.ellipse([sx-sr, sy-sr, sx+sr, sy+sr], outline=GOLD, width=3)
        knob = sx - sr*0.5 if not on else sx + sr*0.5
        d.ellipse([knob-12, sy-12, knob+12, sy+12], fill=(GOLD_HI if on else GOLD))
        return base
    save(toggle(False), "toggle_off.png")
    save(toggle(True), "toggle_on.png")
    save(plate((64,64), 10, MOQING, MOQING, GOLD, 2), "micro_base.png")

    # icons (transparent) with 灵气 aura
    for k, fn in NAV.items():
        color = ICON_COLORS.get(k, DEFAULT_ICON_COLOR)
        kw = {"auto_fill": True, "fill_color": color}
        save(supersample(fn, (96, 96), brush=HANDDRAWN, brush_kw=kw,
                         aura_color=color, aura_strength=0.30), f"icon_nav_{k}.png")
    for k, fn in SQ.items():
        color = ICON_COLORS.get(k, DEFAULT_ICON_COLOR)
        kw = {"auto_fill": True, "fill_color": color}
        save(supersample(fn, (180, 180), brush=HANDDRAWN, brush_kw=kw,
                         aura_color=color, aura_strength=0.42), f"icon_sq_{k}.png")
    for k, fn in MIC.items():
        save(supersample(fn, (48, 48), brush=HANDDRAWN), f"icon_micro_{k}.png")

    # contact sheet
    build_contact()

def build_contact():
    cell = 120; pad = 10; cols = 8
    base_names = ["nav_base_N.png", "nav_base_S.png", "sq_base_N.png", "sq_base_S.png",
                  "rect_pos_N.png", "rect_pos_H.png", "rect_pos_P.png",
                  "rect_neg_N.png", "rect_neg_H.png", "rect_neg_P.png",
                  "toggle_off.png", "toggle_on.png", "micro_base.png"]
    icon_names = [f"icon_nav_{k}.png" for k in NAV] + \
                 [f"icon_sq_{k}.png" for k in SQ] + \
                 [f"icon_micro_{k}.png" for k in MIC]
    names = base_names + icon_names
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGBA", (cols*(cell+pad)+pad, rows*(cell+pad)+pad), (20,28,25,255))
    d = ImageDraw.Draw(sheet)
    def place(name, r, c):
        img = Image.open(os.path.join(OUT, name)).convert("RGBA")
        img.thumbnail((cell, cell))
        x = pad + c*(cell+pad); y = pad + r*(cell+pad)
        sheet.alpha_composite(img, (x + (cell-img.width)//2, y + (cell-img.height)//2))
        d.text((x, y+cell-14), name.replace(".png",""), fill=(150,150,150,255))
    for i, n in enumerate(names):
        place(n, i // cols, i % cols)
    sheet.convert("RGB").save(os.path.join(OUT, "contact_sheet.png"), "PNG")
    print("wrote contact_sheet.png")

if __name__ == "__main__":
    main()
