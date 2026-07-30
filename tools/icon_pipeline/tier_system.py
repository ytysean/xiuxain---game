# -*- coding: utf-8 -*-
"""
太玄宗门录 · 等阶视觉系统 (tier_system.py)  v2
==============================================
3 套等阶大模板(凡阶/灵阶/玄阶) + 7 色阶点 + 玉扣阶点，代码绘制，零积分、零漂移。

设计决策 v2(结合老大评审反馈):
【P0 梯度强拉开】
- 中心物占比大幅拉开: 凡 35% / 灵 45% / 玄 60% (原 38/48/56, 太平缓)
- 边框结构分层:
    凡 = 单圈哑光暗铜窄边(做旧金属, 无玉质), 与灵的亮面金边直接拉开材质差
    灵 = 双圈亮面金边 + 内侧淡玉环(结构差)
    玄 = 三圈暗金宽边(宽度≈灵 1.5x) + 浮雕雷纹/云纹 + 内圈暗金, 结构直接碾压中低档
- 底纹换赛道(材质级差异, 非细节差):
    凡 = 粗粝麻石底(深色哑光, 颗粒感, 无光), 中灰暗调
    灵 = 细腻暖白玉底(温润柔光, 亮调)
    玄 = 深灵玉底 + 暗裂纹(深色, 与亮中心物强对比)

【P1 质感升级】
- 玄阶光效: 中心强聚光 + 边缘细碎星点溢出, 光只集中在宝物主体, 边框只被中心光照亮内侧,
  不做整体泛光(消除"灯泡感")。
- 玄阶中心物材质由生成端重绘(厚重金属 + 蕴光灵玉, 非琉璃玻璃感)。
- 统一顶光: 全图标叠加柔和顶光, 消除中心物与边框的拼接感。

【P2 细节】
- 阶点放大 1.5x, 改玉扣样式(凡灰玉 / 灵青玉 / 玄红玉), 贴合修仙题材 + 醒目。
- 玄阶极淡金色外光晕, 强化顶级氛围(不过浓)。

用法:
  python tier_system.py --templates   生成 3 张空白等阶模板
  python tier_system.py --compose     读取中心物 -> 合成 9 张验证样
"""

import os
import json
import math
import random
import argparse
from PIL import Image, ImageDraw, ImageChops

SIZE = 1024
CX = CY = SIZE // 2
MED_R = 448          # 品阶底板(材质圆盘)半径
FRAME_OUT = 500      # 外框外缘半径
FRAME_IN = MED_R     # 外框内缘(=底板边缘)
OBJ_REF = SIZE       # 中心物占比参考(全画布)

# ---- 配置加载: 优先读 tier_config.json, 缺失则回退内置默认值 ----
_CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tier_config.json")

def _load_config():
    default = {
        "tiers": {
            "low":  {"label": "凡阶", "badge_grade": "凡", "obj_ratio": 0.35, "glow": [150, 170, 160], "glow_alpha": 0.0,  "jade": [178, 176, 168, 255]},
            "mid":  {"label": "灵阶", "badge_grade": "宝", "obj_ratio": 0.45, "glow": [190, 210, 200], "glow_alpha": 0.42, "jade": [108, 172, 142, 255]},
            "high": {"label": "玄阶", "badge_grade": "道", "obj_ratio": 0.60, "glow": [185, 235, 220], "glow_alpha": 0.55, "jade": [198, 86, 76, 255]},
        },
        "grade_colors": {
            "凡": [183, 178, 168, 255], "灵": [127, 191, 160, 255], "宝": [111, 163, 199, 255],
            "王": [168, 143, 208, 255], "圣": [214, 154, 92, 255], "仙": [226, 197, 102, 255], "道": [194, 80, 74, 255],
        },
        "grade_to_tier": {
            "凡品": "low", "灵品": "low", "宝品": "mid", "王品": "mid", "圣品": "mid", "仙品": "high", "道品": "high",
        },
    }
    if os.path.exists(_CONFIG_PATH):
        try:
            with open(_CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg = json.load(f)
            # 合并兜底, 防止 json 缺字段
            for k in ("tiers", "grade_colors", "grade_to_tier"):
                if k not in cfg:
                    cfg[k] = default[k]
            return cfg
        except Exception as e:
            print(f"[warn] 读取 {_CONFIG_PATH} 失败, 回退内置默认: {e}")
    return default

_CFG = _load_config()

# 7 品阶色(数据层)
GRADE_COLORS = {g: tuple(c) for g, c in _CFG["grade_colors"].items()}

# 等阶定义(由 json 归一化, 兼容旧字段名 grade/obj_ratio/glow/jade)
TIERS = {}
for _t, _d in _CFG["tiers"].items():
    TIERS[_t] = {
        "grade": _d.get("badge_grade", "凡"),
        "label": _d.get("label", _t),
        "obj_ratio": _d.get("obj_ratio", 0.45),
        "glow": tuple(_d.get("glow", [190, 210, 200])),
        "glow_alpha": _d.get("glow_alpha", 0.42),
        "jade": tuple(_d.get("jade", [150, 170, 150, 255])),
    }

# 7 档 -> 3 等阶映射(批量生产用)
GRADE_TO_TIER = _CFG["grade_to_tier"]

BRONZE = (108, 95, 70, 255)      # 哑光暗铜(凡)
GOLD = (205, 172, 110, 255)      # 亮面金(灵/玄外圈)
DARK_GOLD = (150, 120, 70, 255)  # 暗金(玄)
INK = (28, 40, 36, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def radial_disc(radius, inner, outer):
    """径向渐变圆盘(inner=中心色, outer=边缘色), 透明背景。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    steps = 72
    for i in range(steps, 0, -1):
        r = radius * i / steps
        t = 1.0 - i / steps
        col = lerp(outer, inner, t)
        d.ellipse([CX - r, CY - r, CX + r, CY + r], fill=col)
    return img


def ring(r_out, r_in, color, width=None):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if width is not None:
        d.ellipse([CX - r_out, CY - r_out, CX + r_out, CY + r_out],
                  outline=color, width=width)
    else:
        d.ellipse([CX - r_out, CY - r_out, CX + r_out, CY + r_out], fill=color)
        d.ellipse([CX - r_in, CY - r_in, CX + r_in, CY + r_in], fill=(0, 0, 0, 0))
    return img


def speckle(r_max, count, col_a, col_b, alpha, seed=1):
    """在半径 r_max 内散布 count 个细小颗粒(麻石/磨损质感)。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    ca = min(col_a, (255, 255, 255))
    cb = min(col_b, (255, 255, 255))
    for _ in range(count):
        ang = rnd.uniform(0, 2 * math.pi)
        rad = r_max * math.sqrt(rnd.uniform(0, 1))
        x = CX + rad * math.cos(ang)
        y = CY + rad * math.sin(ang)
        s = rnd.choice([1, 1, 2, 2, 3])
        col = ca if rnd.random() < 0.5 else cb
        d.ellipse([x - s, y - s, x + s, y + s], fill=(col[0], col[1], col[2], alpha))
    return img


def draw_cracks(r_max, n, color, alpha, seed=7):
    """暗裂纹(玄阶底纹), 自中心向外的不规则折线。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(n):
        ang = rnd.uniform(0, 2 * math.pi)
        pts = []
        rad = r_max * rnd.uniform(0.25, 0.95)
        x = CX + rad * math.cos(ang)
        y = CY + rad * math.sin(ang)
        segs = rnd.randint(2, 4)
        for _ in range(segs):
            x += rnd.uniform(-40, 40)
            y += rnd.uniform(-40, 40)
            if (x - CX) ** 2 + (y - CY) ** 2 < (r_max + 20) ** 2:
                pts.append((x, y))
        if len(pts) >= 2:
            d.line(pts, fill=color, width=2)
    return img


def draw_cloud_marks(r_center, count, color, size=26):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(count):
        ang = 2 * math.pi * k / count - math.pi / 2
        x = CX + r_center * math.cos(ang)
        y = CY + r_center * math.sin(ang)
        d.arc([x - size, y - size, x + size, y + size],
              start=200, end=340, fill=color, width=4)
    return img


def draw_rune_marks(r_center, count, color, length=22, width=3):
    """雷纹/符文(径向短刻线 + 小折线), 玄阶浮雕感。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(count):
        ang = 2 * math.pi * k / count - math.pi / 2
        x0 = CX + (r_center - length) * math.cos(ang)
        y0 = CY + (r_center - length) * math.sin(ang)
        x1 = CX + (r_center + length) * math.cos(ang)
        y1 = CY + (r_center + length) * math.sin(ang)
        d.line([(x0, y0), (x1, y1)], fill=color, width=width)
        px = CX + r_center * math.cos(ang)
        py = CY + r_center * math.sin(ang)
        tx = px + 12 * math.cos(ang + 1.2)
        ty = py + 12 * math.sin(ang + 1.2)
        bx = px + 12 * math.cos(ang - 1.2)
        by = py + 12 * math.sin(ang - 1.2)
        d.line([(tx, ty), (px, py), (bx, by)], fill=color, width=max(1, width - 1))
    return img


def glow_disc(radius, color, strength=0.55):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    steps = 60
    for i in range(steps, 0, -1):
        r = radius * i / steps
        t = 1.0 - i / steps
        a = int(255 * strength * (t ** 1.6))
        col = (color[0], color[1], color[2], a)
        d.ellipse([CX - r, CY - r, CX + r, CY + r], fill=col)
    return img


def top_light(intensity=0.10):
    """柔和顶光(自顶部照下), 统一光影方向, 消除拼接感。限制在底板圆内, 不污染透明区。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    steps = 50
    for i in range(steps, 0, -1):
        r = 540 * i / steps
        t = i / steps
        a = int(255 * intensity * (t ** 2))
        cx2, cy2 = CX, CY - 280
        d.ellipse([cx2 - r, cy2 - r, cx2 + r, cy2 + r], fill=(255, 252, 240, a))
    # 裁剪到材质圆盘内
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse([CX - MED_R, CY - MED_R, CX + MED_R, CY + MED_R], fill=255)
    img.putalpha(ImageChops.multiply(img.split()[3], mask))
    return img


def make_base(tier):
    """品阶底板 + 外框(透明外圈)。"""
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # 1) 材质圆盘(底纹) —— 三档换赛道
    if tier == "low":
        # 粗粝麻石底(深色哑光, 中灰暗调), 颗粒感, 无光
        mat = radial_disc(MED_R, (96, 92, 84, 255), (60, 56, 50, 255))
        base = Image.alpha_composite(base, mat)
        base = Image.alpha_composite(base, speckle(MED_R - 6, 2200, (70, 66, 58), (120, 114, 102), 70, seed=11))
    elif tier == "mid":
        # 细腻暖白玉底(亮调, 温润柔光)
        mat = radial_disc(MED_R, (120, 122, 108, 255), (82, 86, 74, 255))
        base = Image.alpha_composite(base, mat)
        base = Image.alpha_composite(base, glow_disc(MED_R * 0.92, (230, 228, 210), 0.18))
    else:
        # 深灵玉底 + 暗裂纹(深色, 与亮中心物强对比)
        mat = radial_disc(MED_R, (44, 58, 46, 255), (22, 30, 24, 255))
        base = Image.alpha_composite(base, mat)
        base = Image.alpha_composite(base, draw_cracks(MED_R - 10, 9, (14, 20, 16, 180), 150, seed=7))

    # 2) 外框 —— 结构分层
    if tier == "low":
        # 单圈哑光暗铜窄边(做旧金属), 加一道更细内线, 无玉质 —— P1 拉大三档间距: 外边收窄至 9
        base = Image.alpha_composite(base, ring(FRAME_OUT, FRAME_IN - 9, BRONZE, width=9))
        base = Image.alpha_composite(base, speckle(FRAME_OUT, 600, (80, 70, 50), (130, 115, 85), 90, seed=21))
        base = Image.alpha_composite(base, ring(FRAME_IN - 30, FRAME_IN - 33, (70, 60, 42, 160), width=3))
    elif tier == "mid":
        # 双圈亮面金边 + 内侧淡玉环(结构差) —— P1 拉大三档间距: 外边加宽至 20, 内边 14
        base = Image.alpha_composite(base, ring(FRAME_OUT, FRAME_OUT - 20, GOLD, width=20))
        base = Image.alpha_composite(base, ring(FRAME_IN + 14, FRAME_IN + 2, GOLD, width=14))
        base = Image.alpha_composite(base, ring(FRAME_IN - 26, FRAME_IN - 34, (150, 170, 150, 150), width=6))  # 淡玉环
        base = Image.alpha_composite(base, draw_cloud_marks((FRAME_IN + FRAME_OUT) // 2, 18, (225, 195, 135, 200)))
    else:
        # 三圈暗金宽边(宽度≈灵 1.5x) + 浮雕雷纹 + 内圈暗金 —— P1 拉大三档间距: 外边加宽至 30, 中/内各 +2
        base = Image.alpha_composite(base, ring(FRAME_OUT, FRAME_OUT - 30, DARK_GOLD, width=30))
        base = Image.alpha_composite(base, ring(FRAME_OUT - 32, FRAME_OUT - 44, GOLD, width=12))
        base = Image.alpha_composite(base, ring(FRAME_IN + 14, FRAME_IN + 2, DARK_GOLD, width=14))
        base = Image.alpha_composite(base, draw_rune_marks((FRAME_IN + FRAME_OUT) // 2 + 4, 28, (215, 185, 125, 230), length=24, width=4))
        base = Image.alpha_composite(base, draw_rune_marks(FRAME_IN - 60, 16, (120, 95, 55, 150), length=28, width=3))
    return base


def make_badge(grade, tier):
    """右上角玉扣阶点(放大 1.5x): 徽章体用 7 档精细色(凡灰/灵绿/宝蓝/王紫/圣橙/仙金/道红),
    样式(环/外发光)按 3 等阶分层 —— 实现「3 等阶边框 + 7 色阶点」。"""
    g = grade.rstrip("品") if grade and grade.endswith("品") else grade
    color = GRADE_COLORS.get(g, GRADE_COLORS.get(grade, (200, 200, 200, 255)))
    jade = TIERS[tier]["jade"]
    r = 70                         # 原 46 -> 放大
    bx = CX + 0.70 * MED_R
    by = CY - 0.70 * MED_R
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if tier == "low":
        # 暗玉边, 无外发光
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=color)
        d.ellipse([bx - r, by - r, bx + r, by + r], outline=(110, 108, 100, 255), width=5)
        d.arc([bx - r + 8, by - r + 8, bx + r - 8, by + r - 8],
              start=200, end=320, fill=(235, 233, 226, 150), width=6)
    elif tier == "mid":
        # 柔和外发光, 金边
        gd = ImageDraw.Draw(img)
        for i in range(12, 0, -3):
            gd.ellipse([bx - r - i, by - r - i, bx + r + i, by + r + i],
                       outline=(jade[0], jade[1], jade[2], 18), width=2)
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=color)
        d.ellipse([bx - r, by - r, bx + r, by + r], outline=GOLD, width=6)
        d.arc([bx - r + 8, by - r + 8, bx + r - 8, by + r - 8],
              start=200, end=320, fill=(240, 245, 235, 180), width=7)
    else:
        # 强外发光(金+红), 暗金双描边
        gd = ImageDraw.Draw(img)
        for i in range(20, 0, -3):
            gd.ellipse([bx - r - i, by - r - i, bx + r + i, by + r + i],
                       outline=(235, 150, 120, 22), width=2)
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=color)
        d.ellipse([bx - r, by - r, bx + r, by + r], outline=DARK_GOLD, width=9)
        d.ellipse([bx - r + 5, by - r + 5, bx + r - 5, by + r - 5], outline=GOLD, width=3)
        d.arc([bx - r + 8, by - r + 8, bx + r - 8, by + r - 8],
              start=200, end=320, fill=(255, 245, 240, 220), width=8)
    return img


def clean_center(img):
    """强制透明化：flood-fill 抠背景 + 内容圆盘外环强制清透明。"""
    img = img.convert("RGBA")
    W, H = img.size
    px = img.load()
    corners = [px[8, 8], px[W - 8, 8], px[8, H - 8], px[W - 8, H - 8]]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    TOL = 80
    TOL2 = TOL * TOL
    CORE = int(min(W, H) * 0.30)
    cx0, cy0 = W // 2, H // 2

    def in_core(x, y):
        return abs(x - cx0) < CORE and abs(y - cy0) < CORE

    stack = [(8, 8), (W - 8, 8), (8, H - 8), (W - 8, H - 8),
             (W // 2, 8), (W // 2, H - 8), (8, H // 2), (W - 8, H // 2)]
    visited = set()
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= W or y >= H or (x, y) in visited:
            continue
        visited.add((x, y))
        r, g, b, a = px[x, y]
        if a > 0:
            d = (r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2
            if d <= TOL2:
                px[x, y] = (r, g, b, 0)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in visited and not in_core(nx, ny):
                        stack.append((nx, ny))
    R_LIMIT2 = (0.46 * min(W, H)) ** 2   # 玄阶 60% -> 半径~307, 留足余量
    for y in range(H):
        for x in range(W):
            if (x - cx0) ** 2 + (y - cy0) ** 2 > R_LIMIT2:
                r, g, b, a = px[x, y]
                if a > 0:
                    d = (r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2
                    if d <= TOL2 * 2:
                        px[x, y] = (r, g, b, 0)
    return img


def star_particles(color, count, seed=5):
    """玄阶边缘细碎星点溢出(集中在中心物外侧)。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(count):
        ang = rnd.uniform(0, 2 * math.pi)
        rad = rnd.uniform(180, 360)
        x = CX + rad * math.cos(ang)
        y = CY + rad * math.sin(ang)
        s = rnd.choice([1, 1, 2])
        a = rnd.randint(90, 200)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(color[0], color[1], color[2], a))
    return img


def compose(center_path, tier, grade, out_path):
    base = make_base(tier)
    spec = TIERS[tier]

    obj_raw = Image.open(center_path).convert("RGBA")
    obj_raw = clean_center(obj_raw)

    # 2) 光效(中心物背后) —— glow_alpha 由 tier_config.json 控制(玄阶上限 0.55, 预留 UI 滤镜空间)
    ga = spec.get("glow_alpha", 0.42)
    if tier == "mid":
        base = Image.alpha_composite(base, glow_disc(int(MED_R * 0.55), spec["glow"], ga))
    elif tier == "high":
        # 中心强聚光(只覆盖宝物主体) + 边缘星点溢出
        base = Image.alpha_composite(base, glow_disc(int(MED_R * 0.50), spec["glow"], ga))
        base = Image.alpha_composite(base, star_particles(spec["glow"], 90, seed=5))
        # 边框内侧被中心光照亮(极淡内光环)
        base = Image.alpha_composite(base, ring(FRAME_IN, FRAME_IN - 26, (120, 180, 165, 60), width=14))

    # 3) 中心物缩放
    obj = obj_raw
    max_d = int(OBJ_REF * spec["obj_ratio"])
    bbox = obj.getbbox()
    if bbox:
        bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
        obj_crop = obj.crop(bbox)
        scale = max_d / max(bw, bh)
        nw, nh = max(1, int(obj_crop.width * scale)), max(1, int(obj_crop.height * scale))
        obj_crop = obj_crop.resize((nw, nh), Image.LANCZOS)
        paste = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        paste.paste(obj_crop, (CX - nw // 2, CY - nh // 2), obj_crop)
        base = Image.alpha_composite(base, paste)
    else:
        obj = obj.resize((max_d, max_d), Image.LANCZOS)
        base.paste(obj, (CX - max_d // 2, CY - max_d // 2), obj)

    # 4) 统一顶光(消除拼接感)
    base = Image.alpha_composite(base, top_light(0.10))

    # 5) 阶点(玉扣)
    base = Image.alpha_composite(base, make_badge(grade, tier))

    # 6) 玄阶极淡金色外光晕(边框外缘向外渐隐, 不染底板内部)
    if tier == "high":
        hb = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hb)
        for i in range(64, 0, -4):
            r = FRAME_OUT + i
            a = int(30 * (i / 64))
            hd.ellipse([CX - r, CY - r, CX + r, CY + r], outline=(222, 192, 132, a), width=4)
        base = Image.alpha_composite(base, hb)

    base.save(out_path)
    return out_path


def gen_templates(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for tier in ["low", "mid", "high"]:
        grade = TIERS[tier]["grade"]
        img = make_base(tier)
        img = Image.alpha_composite(img, make_badge(grade, tier))
        p = os.path.join(out_dir, f"template_{tier}.png")
        img.save(p)
        paths.append(p)
    return paths


def gen_samples(src_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    mapping = [
        ("orb_common.png",   "low",  "凡"),
        ("orb_elite.png",    "mid",  "宝"),
        ("orb_top.png",      "high", "道"),
        ("gourd_common.png", "low",  "凡"),
        ("gourd_elite.png",  "mid",  "宝"),
        ("gourd_top.png",    "high", "道"),
        ("mirror_common.png","low",  "凡"),
        ("mirror_elite.png", "mid",  "宝"),
        ("mirror_top.png",   "high", "道"),
    ]
    done = []
    for fname, tier, grade in mapping:
        src = os.path.join(src_dir, fname)
        if not os.path.exists(src):
            print(f"[skip] 中心物缺失: {src}")
            continue
        out = os.path.join(out_dir, fname.replace(".png", f"_sample.png"))
        compose(src, tier, grade, out)
        done.append(out)
    return done


def gen_batch(csv_path, center_root, out_root=".", missing="skip"):
    """批量合成: 读资产 CSV + 中心物目录 -> 全量成品。
    CSV 须含列: item_id, grade, archetype, icon_path, [center_normal], [center_top]
    grade(7档)->tier(3等阶); tier=high 用 center_top, 其余用 center_normal。
    """
    import csv
    rows = []
    with open(csv_path, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            rows.append(row)
    done = skip = 0
    for row in rows:
        grade = (row.get("grade") or "").strip()
        tier = GRADE_TO_TIER.get(grade, "low")
        arche = (row.get("archetype") or "").strip()
        item_id = row.get("item_id") or "?"
        if not arche:
            skip += 1
            if missing != "skip":
                print(f"[skip] 无 archetype: {item_id}")
            continue
        center = (row.get("center_top") or "").strip() if tier == "high" \
            else (row.get("center_normal") or "").strip()
        if not center:
            center = f"{arche}_top.png" if tier == "high" else f"{arche}_normal.png"
        center_path = os.path.join(center_root, center)
        if not os.path.exists(center_path):
            skip += 1
            if missing != "skip":
                print(f"[skip] 中心物缺失: {center_path}")
            continue
        icon_path = (row.get("icon_path") or "").strip()
        if not icon_path:
            skip += 1
            continue
        local = icon_path.replace("res://", "").lstrip("/")
        out_path = os.path.join(out_root, local)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        compose(center_path, tier, grade, out_path)
        done += 1
    print(f"批量合成完成: done={done} skip={skip} (总 {len(rows)} 行)")
    return done, skip


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--templates", action="store_true")
    ap.add_argument("--compose", action="store_true")
    ap.add_argument("--batch", action="store_true", help="读 CSV 批量合成全量")
    ap.add_argument("--src", default="icon/_validation/treasure_tier_9")
    ap.add_argument("--out", default="icon/_validation/treasure_tier_9")
    ap.add_argument("--csv", default="icon_manifest.csv")
    ap.add_argument("--center-root", default="icon/_centers")
    args = ap.parse_args()

    if args.templates:
        ps = gen_templates(args.out)
        print("模板已生成:")
        for p in ps:
            print("  ", p)
    if args.compose:
        ds = gen_samples(args.src, args.out)
        print(f"验证样已合成 {len(ds)}/9:")
        for p in ds:
            print("  ", p)
    if args.batch:
        gen_batch(args.csv, args.center_root, args.out)
    if not (args.templates or args.compose or args.batch):
        print("用法: --templates | --compose | --batch [--csv X --center-root Y --out Z]")


if __name__ == "__main__":
    main()
