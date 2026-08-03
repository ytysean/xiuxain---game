# -*- coding: utf-8 -*-
"""合成 路线A 系统总览板 SVG：灵根(列) × 性格(行) 网格 + 标签。"""
import os, re
import generate_prototypes as G

OUT = os.path.dirname(os.path.abspath(__file__))
LABEL_COL = 70
HEADER = 56
CELL = 116
THUMB = 96
PAD = 24

EL_ORDER = G.EL_ORDER
PER_ORDER = G.PER_ORDER

def strip_outer(svg_str):
    m = re.search(r"<svg[^>]*>(.*)</svg>\s*$", svg_str, re.S)
    return m.group(1) if m else svg_str

board_w = PAD + LABEL_COL + len(EL_ORDER) * CELL + PAD
board_h = PAD + HEADER + len(PER_ORDER) * CELL + PAD

parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{board_w}" height="{board_h}" '
         f'viewBox="0 0 {board_w} {board_h}" font-family="sans-serif">']
# 背景
parts.append(f'<rect x="0" y="0" width="{board_w}" height="{board_h}" fill="#F4EFE3"/>')
parts.append(f'<rect x="{PAD-8}" y="{PAD-8}" width="{board_w-2*(PAD-8)}" height="{board_h-2*(PAD-8)}" '
             f'fill="none" stroke="#1E2B28" stroke-width="2" rx="8"/>')
# 标题
parts.append(f'<text x="{PAD}" y="34" font-size="20" font-weight="bold" fill="#1E2B28">'
             f'太玄宗门录 · 弟子性格原型套组（路线A）</text>')
parts.append(f'<text x="{PAD}" y="50" font-size="11" fill="#6E8F88">'
             f'灵根(列) × 性格(行) · 矢量占位皮 · prototype_id = 灵根序×6 + 性格序 (0–29)</text>')

# 列头(灵根)
for ci, ek in enumerate(EL_ORDER):
    x = PAD + LABEL_COL + ci * CELL + CELL / 2
    nm = G.EL[ek][0]
    parts.append(f'<text x="{x:.0f}" y="{PAD+HEADER-14}" font-size="15" font-weight="bold" '
                 f'fill="{G.EL[ek][1]}" text-anchor="middle">{nm}</text>')

# 行(性格) + 单元
for ri, pk in enumerate(PER_ORDER):
    y0 = PAD + HEADER + ri * CELL
    # 行标
    parts.append(f'<text x="{PAD+LABEL_COL/2:.0f}" y="{y0+CELL/2+5:.0f}" font-size="15" '
                 f'font-weight="bold" fill="#1E2B28" text-anchor="middle">{G.PER[pk][0]}</text>')
    parts.append(f'<line x1="{PAD}" y1="{y0:.0f}" x2="{board_w-PAD:.0f}" y2="{y0:.0f}" '
                 f'stroke="#C8A86A" stroke-width="0.6" opacity="0.5"/>')
    for ci, ek in enumerate(EL_ORDER):
        cx0 = PAD + LABEL_COL + ci * CELL
        cy0 = y0
        inner = strip_outer(G.build_avatar(pk, ek))
        # 去重 ID（嵌套 svg 共享文档，避免 url(#) 串到首个定义）
        inner = re.sub(r'id="([^"]+)"', lambda m: f'id="{m.group(1)}_{ri}{ci}"', inner)
        inner = re.sub(r'url\(#([^)]+)\)', lambda m: f'url(#{m.group(1)}_{ri}{ci})', inner)
        x = cx0 + (CELL - THUMB) / 2
        y = cy0 + (CELL - THUMB) / 2
        parts.append(f'<svg x="{x:.0f}" y="{y:.0f}" width="{THUMB}" height="{THUMB}" '
                     f'viewBox="0 0 120 120">{inner}</svg>')

parts.append('</svg>')
out = os.path.join(OUT, "style_board.svg")
with open(out, "w", encoding="utf-8", newline="") as f:
    f.write("".join(parts))
print("wrote", out, f"({board_w}x{board_h})")
