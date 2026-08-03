#!/usr/bin/env python3
# 用正确的选中底板(nav_dz_selected) 复刻 nav_jy_selected：
# 1) 取 nav_dz_selected 的底板（圆角深底+金边），把其中弟子图案区域用不透明底板色填掉
# 2) 把 nav_jy_normal（宗门殿阁）居中贴上去
from PIL import Image

SEL = "art/ui/buttons/nav_dz_selected.png"
NORM = "art/ui/buttons/nav_jy_normal.png"
OUT = "art/ui/buttons/nav_jy_selected.png"

sel = Image.open(SEL).convert("RGBA")
norm = Image.open(NORM).convert("RGBA")
W, H = sel.size
sel_px = sel.load()
norm_px = norm.load()

# 1) 估算不透明底板色：sel 中 alpha>200、暗色、且非金边(金边 r,g 高 b 低) 的中间值
cands = []
for y in range(0, H, 2):
    for x in range(0, W, 2):
        r, g, b, a = sel_px[x, y]
        if a > 200 and (r + g + b) < 200 and not (r > 120 and b < 90):
            cands.append((r, g, b, a))
cands.sort()
panel_color = cands[len(cands) // 2] if cands else (44, 61, 67, 255)
print("panel_color", panel_color, "n_cands", len(cands))

# 2) 构造纯底板：copy sel，把图案区(=norm 不透明区)填成不透明底板色
new = sel.copy()
np_ = new.load()
for y in range(H):
    for x in range(W):
        if norm_px[x, y][3] > 30:
            np_[x, y] = panel_color

# 3) 居中贴 norm（opaque）
nw, nh = norm.size
new.alpha_composite(norm, ((W - nw) // 2, (H - nh) // 2))
new.save(OUT)

# 自检
px = new.load()
# 边角(应透明)
print("corner_alpha", px[3, 3][3])
# 金边区(顶部内侧约 y=18,x=128 应金)
print("border_sample", px[128, 18][:3], "alpha", px[128, 18][3])
# 内部底板(约 x=40,y=128 应暗)
print("interior_sample", px[40, 128][:3], "alpha", px[40, 128][3])
# 中心殿阁(应非暗底)
print("center_sample", px[128, 150][:3], "alpha", px[128, 150][3])
print("saved", OUT)
