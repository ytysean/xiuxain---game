# -*- coding: utf-8 -*-
"""
太玄宗门录 · 路线A 弟子性格原型套组 生成器
================================================
按「灵根(5) × 性格(6)」确定性产出矢量原型资产(SVG)：
  - avatars/   disciple_{element}_{personality}.svg   头像图标(120×120 圆形)
  - portraits/ disciple_{element}_{personality}_portrait.svg  立绘(240×320 半身)

设计约束（与项目 UI 配色 / v2.0 同源）：
  - 锁定色：青黛#6E8F88 宣纸米白#F4EFE3 墨青#1E2B28 暗金#C8A86A 朱砂红#B3423D 玉石绿#8FBF9F
  - 发色/描边统一墨青；肤色统一暖玉白#E8D8BE(中性，不占五行)；袍服=灵根主+次色
  - 性格决定脸(眉眼嘴型/发型/微配饰/姿态气质)，灵根决定袍服与灵气色
  - 本批为纯代码UI阶段的矢量占位皮；v2.0 写实最终立绘后续走 AI 出图替换

游戏接入：生成弟子时 roll 灵根(0..4)×性格(0..5)，prototype_id = 灵根序*6+性格序(0..29)
  命名与文件名一致；Godot TextureRect 按 id 加载：头像进名册/弟子卡，立绘进详情弹窗。
"""
import os

OUT = os.path.dirname(os.path.abspath(__file__))
AVATAR_DIR = os.path.join(OUT, "avatars")
PORTRAIT_DIR = os.path.join(OUT, "portraits")
os.makedirs(AVATAR_DIR, exist_ok=True)
os.makedirs(PORTRAIT_DIR, exist_ok=True)

# ---- 锁定色板 ----
SKIN = "#E8D8BE"          # 暖玉白(中性肤色)
INK  = "#1E2B28"          # 墨青(发色/描边)
GOLD = "#C8A86A"          # 暗金
RICE = "#F4EFE3"          # 宣纸米白
WOOD = "#6E5A45"          # 木簪棕

# 灵根：主色 / 次色(高光或深衬)
EL = {
    "jin":  ("金", "#C8A86A", "#F4EFE3"),
    "mu":   ("木", "#8FBF9F", "#5E8F76"),
    "shui": ("水", "#6E8F88", "#4A6B66"),
    "huo":  ("火", "#B3423D", "#D98C88"),
    "tu":   ("土", "#4A3B2A", "#6E5A45"),
}
EL_ORDER = ["jin", "mu", "shui", "huo", "tu"]

# 性格：名 / 序号 / 发型简述
PER = {
    "p_chen": ("沉稳", 0),
    "p_huo":  ("活泼", 1),
    "p_gu":   ("孤傲", 2),
    "p_bao":  ("暴躁", 3),
    "p_wen":  ("温润", 4),
    "p_jiao": ("狡黠", 5),
}
PER_ORDER = ["p_chen", "p_huo", "p_gu", "p_bao", "p_wen", "p_jiao"]


# ---------------- SVG 基础原语 ----------------
def _ellipse(cx, cy, rx, ry, fill, extra=""):
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" {extra}/>'

def _circle(cx, cy, r, fill, extra=""):
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}" {extra}/>'

def _line(x1, y1, x2, y2, stroke, sw, extra=""):
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{stroke}" stroke-width="{sw:.1f}" stroke-linecap="round" {extra}/>'

def _path(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}" {extra}/>'

def _path_s(d, stroke, sw, extra=""):
    return f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{sw:.1f}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'

def _rect(x, y, w, h, fill, extra=""):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" {extra}/>'


# ---------------- 头部静态部分(头/耳/颈) ----------------
def _head_static(cx, cy, s):
    rx, ry = 24 * s, 28 * s
    p = []
    p.append(_ellipse(cx, cy, rx, ry, SKIN))                          # 脸
    p.append(_ellipse(cx - rx + 2 * s, cy + 1 * s, 4 * s, 6 * s, SKIN))  # 左耳
    p.append(_ellipse(cx + rx - 2 * s, cy + 1 * s, 4 * s, 6 * s, SKIN))  # 右耳
    # 颈
    p.append(_rect(cx - 7 * s, cy + ry - 4 * s, 14 * s, 12 * s, SKIN))
    return "".join(p)


# ---------------- 发型(墨青) ----------------
def _hair(pkey, cx, cy, s):
    rx, ry = 24 * s, 28 * s
    top = cy - ry
    p = []
    if pkey == "p_chen":   # 整齐束发 + 暗金玉冠
        p.append(_circle(cx, top - 2 * s, 7 * s, INK))               # 发髻
        p.append(_rect(cx - 9 * s, top - 5 * s, 18 * s, 5 * s, GOLD, 'rx="2"'))  # 玉冠
        p.append(_path(f"M{cx-rx},{cy-6*s} Q{cx},{top-6*s} {cx+rx},{cy-6*s} L{cx+rx},{cy-2*s} Q{cx},{top+2*s} {cx-rx},{cy-2*s} Z", INK))  # 额发
    elif pkey == "p_huo":  # 双髻 + 翘发
        p.append(_circle(cx - 14 * s, top + 2 * s, 7 * s, INK))
        p.append(_circle(cx + 14 * s, top + 2 * s, 7 * s, INK))
        p.append(_path(f"M{cx-rx},{cy-4*s} Q{cx-10*s},{top-8*s} {cx},{top+2*s} Q{cx+10*s},{top-8*s} {cx+rx},{cy-4*s} L{cx+rx},{cy} Q{cx},{top+8*s} {cx-rx},{cy} Z", INK))
    elif pkey == "p_gu":   # 高束长发披一肩
        p.append(_circle(cx, top - 4 * s, 6 * s, INK))
        p.append(_path(f"M{cx-rx-2*s},{cy} Q{cx-2*s},{top-10*s} {cx+2*s},{top-2*s} Q{cx+rx+8*s},{cy+20*s} {cx+rx+10*s},{cy+46*s} L{cx+rx-6*s},{cy+46*s} Q{cx+rx-2*s},{cy+18*s} {cx+rx},{cy} Z", INK))  # 垂肩长发
        p.append(_path(f"M{cx-rx},{cy-4*s} Q{cx},{top-4*s} {cx+rx-4*s},{cy-6*s} L{cx+rx-4*s},{cy-2*s} Q{cx},{top} {cx-rx},{cy} Z", INK))
    elif pkey == "p_bao":  # 乱短发(尖刺)
        pts = f"M{cx-rx},{cy-2*s} "
        for i in range(-3, 4):
            x = cx + i * 8 * s
            y = top - 2 * s if i % 2 == 0 else top - 12 * s
            pts += f"L{x:.1f},{y:.1f} "
        pts += f"L{cx+rx},{cy-2*s} L{cx+rx},{cy+2*s} L{cx-rx},{cy+2*s} Z"
        p.append(_path(pts, INK))
    elif pkey == "p_wen":  # 柔顺披发 + 木簪
        p.append(_path(f"M{cx-rx-3*s},{cy+34*s} Q{cx-rx-4*s},{top} {cx},{top-4*s} Q{cx+rx+4*s},{top} {cx+rx+3*s},{cy+34*s} L{cx+rx-2*s},{cy+34*s} Q{cx+rx-2*s},{cy} {cx+rx-6*s},{cy-4*s} Q{cx},{top+2*s} {cx-rx+6*s},{cy-4*s} Q{cx-rx+2*s},{cy} {cx-rx+2*s},{cy+34*s} Z", INK))
        p.append(_line(cx + 6 * s, top - 6 * s, cx + 20 * s, top + 6 * s, WOOD, 2.4 * s))  # 木簪
    elif pkey == "p_jiao": # 偏分短束 + 耳坠
        p.append(_path(f"M{cx-rx},{cy-2*s} Q{cx-4*s},{top-10*s} {cx+10*s},{top-6*s} Q{cx+rx+2*s},{top} {cx+rx},{cy-2*s} L{cx+rx},{cy+2*s} Q{cx+6*s},{top+4*s} {cx-rx},{cy+2*s} Z", INK))
        p.append(_circle(cx + rx - 1 * s, cy + 14 * s, 2.4 * s, GOLD))                    # 耳坠
        p.append(_line(cx + rx - 1 * s, cy + 8 * s, cx + rx - 1 * s, cy + 12 * s, GOLD, 1.2 * s))
    return "".join(p)


# ---------------- 眉眼嘴(性格表情) ----------------
def _face(pkey, cx, cy, s):
    brow_y = cy - 10 * s
    eye_y = cy - 1 * s
    mouth_y = cy + 13 * s
    sw = 1.8 * s
    p = []
    if pkey == "p_chen":   # 平眉、眼微垂、抿嘴直线
        p.append(_line(cx - 14 * s, brow_y, cx - 4 * s, brow_y + 1 * s, INK, sw))
        p.append(_line(cx + 4 * s, brow_y + 1 * s, cx + 14 * s, brow_y, INK, sw))
        p.append(_line(cx - 13 * s, eye_y, cx - 3 * s, eye_y + 1 * s, INK, sw))
        p.append(_line(cx + 3 * s, eye_y + 1 * s, cx + 13 * s, eye_y, INK, sw))
        p.append(_line(cx - 8 * s, mouth_y, cx + 8 * s, mouth_y, INK, sw))
    elif pkey == "p_huo":  # 圆眼、眉上扬、笑弧
        p.append(_path_s(f"M{cx-15*s},{brow_y+2*s} Q{cx-9*s},{brow_y-3*s} {cx-3*s},{brow_y+1*s}", INK, sw))
        p.append(_path_s(f"M{cx+3*s},{brow_y+1*s} Q{cx+9*s},{brow_y-3*s} {cx+15*s},{brow_y+2*s}", INK, sw))
        p.append(_circle(cx - 9 * s, eye_y, 3.2 * s, INK))
        p.append(_circle(cx + 9 * s, eye_y, 3.2 * s, INK))
        p.append(_path_s(f"M{cx-9*s},{mouth_y} Q{cx},{mouth_y+6*s} {cx+9*s},{mouth_y}", INK, sw))
    elif pkey == "p_gu":   # 细挑眉、半阖眼、紧抿
        p.append(_path_s(f"M{cx-14*s},{brow_y-1*s} Q{cx-9*s},{brow_y-5*s} {cx-3*s},{brow_y-1*s}", INK, sw))
        p.append(_path_s(f"M{cx+3*s},{brow_y-1*s} Q{cx+9*s},{brow_y-5*s} {cx+14*s},{brow_y-1*s}", INK, sw))
        p.append(_line(cx - 13 * s, eye_y, cx - 3 * s, eye_y, INK, 1.4 * s))
        p.append(_line(cx + 3 * s, eye_y, cx + 13 * s, eye_y, INK, 1.4 * s))
        p.append(_line(cx - 7 * s, mouth_y + 1 * s, cx + 7 * s, mouth_y + 1 * s, INK, sw))
    elif pkey == "p_bao":  # 倒八字浓眉、瞪眼、咧齿
        p.append(_line(cx - 14 * s, brow_y - 3 * s, cx - 4 * s, brow_y + 3 * s, INK, sw + 0.6 * s))
        p.append(_line(cx + 4 * s, brow_y + 3 * s, cx + 14 * s, brow_y - 3 * s, INK, sw + 0.6 * s))
        p.append(_circle(cx - 9 * s, eye_y + 1 * s, 3.6 * s, INK))
        p.append(_circle(cx + 9 * s, eye_y + 1 * s, 3.6 * s, INK))
        p.append(_path(f"M{cx-9*s},{mouth_y-2*s} Q{cx},{mouth_y+7*s} {cx+9*s},{mouth_y-2*s} Z", INK))  # 张口
        p.append(_rect(cx - 6 * s, mouth_y - 1 * s, 12 * s, 3 * s, RICE))                              # 牙
    elif pkey == "p_wen":  # 弯眉笑眼、浅笑
        p.append(_path_s(f"M{cx-14*s},{brow_y+1*s} Q{cx-9*s},{brow_y-4*s} {cx-3*s},{brow_y}", INK, sw))
        p.append(_path_s(f"M{cx+3*s},{brow_y} Q{cx+9*s},{brow_y-4*s} {cx+14*s},{brow_y+1*s}", INK, sw))
        p.append(_path_s(f"M{cx-13*s},{eye_y+2*s} Q{cx-9*s},{eye_y-4*s} {cx-5*s},{eye_y+2*s}", INK, sw))  # 笑眼
        p.append(_path_s(f"M{cx+5*s},{eye_y+2*s} Q{cx+9*s},{eye_y-4*s} {cx+13*s},{eye_y+2*s}", INK, sw))
        p.append(_path_s(f"M{cx-7*s},{mouth_y} Q{cx},{mouth_y+4*s} {cx+7*s},{mouth_y}", INK, sw))
    elif pkey == "p_jiao": # 单边挑眉、眯眼、斜笑
        p.append(_line(cx - 14 * s, brow_y, cx - 4 * s, brow_y - 2 * s, INK, sw))
        p.append(_path_s(f"M{cx+3*s},{brow_y-2*s} Q{cx+9*s},{brow_y-5*s} {cx+14*s},{brow_y-1*s}", INK, sw))
        p.append(_line(cx - 13 * s, eye_y, cx - 3 * s, eye_y, INK, 1.4 * s))   # 眯眼
        p.append(_circle(cx + 9 * s, eye_y, 2.6 * s, INK))
        p.append(_path_s(f"M{cx-8*s},{mouth_y+2*s} Q{cx+2*s},{mouth_y-3*s} {cx+10*s},{mouth_y+3*s}", INK, sw))  # 斜笑
    return "".join(p)


# ---------------- 微配饰(肩部/身侧) ----------------
def _accessory(pkey, cx, cy, s, bottom_y):
    p = []
    if pkey == "p_chen":   # 卷轴(身侧)
        p.append(_rect(cx - 30 * s, bottom_y - 18 * s, 8 * s, 22 * s, RICE, 'rx="2"'))
        p.append(_rect(cx - 31 * s, bottom_y - 20 * s, 10 * s, 3 * s, GOLD))
        p.append(_rect(cx - 31 * s, bottom_y + 1 * s, 10 * s, 3 * s, GOLD))
    elif pkey == "p_huo":  # 小铃铛
        p.append(_circle(cx + 28 * s, bottom_y - 12 * s, 4 * s, GOLD))
        p.append(_rect(cx + 27 * s, bottom_y - 16 * s, 2 * s, 3 * s, GOLD))
    elif pkey == "p_gu":   # 背剑(剑柄露肩)
        p.append(_line(cx + 26 * s, bottom_y - 26 * s, cx + 34 * s, bottom_y + 6 * s, INK, 3 * s))
        p.append(_rect(cx + 23 * s, bottom_y - 30 * s, 12 * s, 4 * s, GOLD, 'rx="1"'))
        p.append(_rect(cx + 27 * s, bottom_y - 34 * s, 4 * s, 5 * s, GOLD))
    elif pkey == "p_bao":  # 小斧
        p.append(_line(cx - 30 * s, bottom_y - 20 * s, cx - 30 * s, bottom_y + 6 * s, WOOD, 3 * s))
        p.append(_path(f"M{cx-38*s},{bottom_y-22*s} Q{cx-30*s},{bottom_y-28*s} {cx-22*s},{bottom_y-22*s} L{cx-22*s},{bottom_y-14*s} Q{cx-30*s},{bottom_y-10*s} {cx-38*s},{bottom_y-14*s} Z", INK))
    elif pkey == "p_wen":  # 药葫芦
        p.append(_circle(cx + 28 * s, bottom_y - 14 * s, 5 * s, "#9CB98A"))
        p.append(_circle(cx + 28 * s, bottom_y - 22 * s, 3 * s, "#9CB98A"))
        p.append(_rect(cx + 26 * s, bottom_y - 26 * s, 4 * s, 3 * s, WOOD))
    elif pkey == "p_jiao": # 折扇
        p.append(_path(f"M{cx-30*s},{bottom_y-18*s} L{cx-18*s},{bottom_y-30*s} L{cx-14*s},{bottom_y-22*s} L{cx-26*s},{bottom_y-10*s} Z", GOLD))
        p.append(_line(cx - 30 * s, bottom_y - 18 * s, cx - 14 * s, bottom_y - 22 * s, INK, 1 * s))
    return "".join(p)


# ---------------- 头像(120×120 圆形) ----------------
def build_avatar(pkey, ekey):
    name_e, c_main, c_sub = EL[ekey]
    name_p = PER[pkey][0]
    gid = f"g_{ekey}"
    cx, cy = 60.0, 58.0
    s = 1.0
    rx, ry = 24 * s, 28 * s
    body = []
    body.append(f'<defs><radialGradient id="{gid}" cx="50%" cy="42%" r="62%">'
                f'<stop offset="0%" stop-color="{c_sub}" stop-opacity="0.55"/>'
                f'<stop offset="100%" stop-color="{c_main}" stop-opacity="0.18"/></radialGradient>'
                f'<clipPath id="clip_{ekey}"><circle cx="60" cy="60" r="56"/></clipPath></defs>')
    body.append(f'<circle cx="60" cy="60" r="56" fill="url(#{gid})"/>')
    # 袍服肩
    body.append(_path(f"M14,{120} Q14,86 {cx-26},{82} Q{cx},{74} {cx+26},{82} Q106,86 106,120 Z", c_main))
    body.append(_path(f"M{cx-12},{80} L{cx},{98} L{cx+12},{80} L{cx+6},{74} L{cx-6},{74} Z", c_sub))  # 交领
    body.append(_head_static(cx, cy, s))
    body.append(_hair(pkey, cx, cy, s))
    body.append(_face(pkey, cx, cy, s))
    body.append(_accessory(pkey, cx, cy, s, 120))
    inner = "".join(body)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">'
           f'<g clip-path="url(#clip_{ekey})">{inner}</g>'
           f'<circle cx="60" cy="60" r="56" fill="none" stroke="{INK}" stroke-width="2.5"/>'
           f'</svg>')
    return svg


# ---------------- 立绘(240×320 半身) ----------------
def build_portrait(pkey, ekey):
    name_e, c_main, c_sub = EL[ekey]
    gid = f"pg_{ekey}"
    cx, cy = 120.0, 116.0
    s = 2.0
    rx, ry = 24 * s, 28 * s
    parts = []
    parts.append(f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                 f'<stop offset="0%" stop-color="{c_main}" stop-opacity="0.30"/>'
                 f'<stop offset="100%" stop-color="{c_sub}" stop-opacity="0.06"/></linearGradient>'
                 f'<radialGradient id="aura_{ekey}" cx="50%" cy="38%" r="55%">'
                 f'<stop offset="0%" stop-color="{c_main}" stop-opacity="0.45"/>'
                 f'<stop offset="100%" stop-color="{c_main}" stop-opacity="0"/></radialGradient></defs>')
    parts.append(f'<rect x="0" y="0" width="240" height="320" fill="url(#{gid})"/>')
    parts.append(f'<ellipse cx="120" cy="130" rx="110" ry="150" fill="url(#aura_{ekey})"/>')
    # 袍服躯干
    parts.append(_path(f"M40,{320} Q36,210 {cx-46},{196} Q{cx},{176} {cx+46},{196} Q204,210 200,{320} Z", c_main))
    parts.append(_path(f"M{cx-24},{188} L{cx},{236} L{cx+24},{188} L{cx+12},{180} L{cx-12},{180} Z", c_sub))  # 交领
    parts.append(_line(cx, 196, cx, 300, GOLD, 4))   # 暗金腰带中线
    parts.append(_rect(cx - 40, 250, 80, 12, GOLD, 'rx="3" opacity="0.85"'))  # 腰带
    # 手(拢袖/持物)
    parts.append(_ellipse(cx - 18, 268, 14 * s * 0.5, 10 * s * 0.5, SKIN))
    parts.append(_ellipse(cx + 18, 268, 14 * s * 0.5, 10 * s * 0.5, SKIN))
    # 头
    parts.append(_head_static(cx, cy, s))
    parts.append(_hair(pkey, cx, cy, s))
    parts.append(_face(pkey, cx, cy, s))
    parts.append(_accessory(pkey, cx, cy, s, 300))
    # 地面投影
    parts.append(f'<ellipse cx="120" cy="312" rx="86" ry="10" fill="{INK}" opacity="0.18"/>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="240" height="320" viewBox="0 0 240 320">'
           + "".join(parts) + '</svg>')
    return svg


def main():
    count = 0
    for ekey in EL_ORDER:
        for pkey in PER_ORDER:
            a = build_avatar(pkey, ekey)
            p = build_portrait(pkey, ekey)
            with open(os.path.join(AVATAR_DIR, f"disciple_{ekey}_{pkey}.svg"), "w", encoding="utf-8", newline="") as f:
                f.write(a)
            with open(os.path.join(PORTRAIT_DIR, f"disciple_{ekey}_{pkey}_portrait.svg"), "w", encoding="utf-8", newline="") as f:
                f.write(p)
            count += 1
    print(f"OK generated {count*2} files (avatars:{count} portraits:{count})")
    print(f"avatars -> {AVATAR_DIR}")
    print(f"portraits-> {PORTRAIT_DIR}")


if __name__ == "__main__":
    main()
