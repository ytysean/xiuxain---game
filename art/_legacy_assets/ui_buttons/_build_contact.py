import os, glob, math
from PIL import Image, ImageDraw, ImageFont

root = r"E:\Xiuxian\taixuanzongmenlu\美术资源\ui_buttons\png"
out = os.path.join(root, "contact_sheet_ai.png")

categories = [
    ("Base Plates", ["sq_base_N.png","sq_base_S.png","rect_pos_N.png","rect_pos_H.png","rect_pos_P.png",
                     "rect_neg_N.png","rect_neg_H.png","rect_neg_P.png","nav_base_N.png","nav_base_S.png",
                     "toggle_off.png","toggle_on.png"]),
    ("Nav Icons", ["icon_nav_jy.png","icon_nav_dz.png","icon_nav_ll.png","icon_nav_js.png","icon_nav_gd.png"]),
    ("Square Icons 1", ["icon_sq_jz_zl.png","icon_sq_dz_lu.png","icon_sq_dq_lz.png","icon_sq_zm_df.png",
                        "icon_sq_rw_mb.png","icon_sq_zm_zc.png","icon_sq_zd_zd.png","icon_sq_jy_t.png",
                        "icon_sq_lt.png","icon_sq_km.png"]),
    ("Square Icons 2", ["icon_sq_tw_g.png","icon_sq_dt.png","icon_sq_qt.png","icon_sq_gx_g.png",
                        "icon_sq_zt.png","icon_sq_cs_g.png","icon_sq_sy.png"]),
    ("Micro Icons", ["icon_micro_check.png","icon_micro_x.png","icon_micro_L.png","icon_micro_R.png",
                     "icon_micro_U.png","icon_micro_D.png","icon_micro_exp.png","icon_micro_col.png",
                     "icon_micro_go.png","icon_micro_info.png","icon_micro_dots.png"]),
]

cell = 140
pad = 10
label_h = 18
cols = 12
rows = sum(math.ceil(len(items)/cols) for _, items in categories) + len(categories)
sheet = Image.new("RGBA", (cols*(cell+pad)+pad, rows*(cell+pad+label_h)+pad), (28, 40, 38, 255))
d = ImageDraw.Draw(sheet)

try:
    font = ImageFont.truetype("msyh.ttc", 14)
except:
    font = ImageFont.load_default()

y = pad
for title, items in categories:
    d.text((pad, y), title, fill=(200, 168, 106, 255), font=font)
    y += label_h + pad
    for i, name in enumerate(items):
        c = i % cols
        r = i // cols
        x = pad + c*(cell+pad)
        yy = y + r*(cell+pad)
        path = os.path.join(root, name)
        if not os.path.exists(path):
            d.rectangle([x, yy, x+cell, yy+cell], outline=(100,100,100,255))
            d.text((x+4, yy+4), "MISS\n"+name, fill=(255,100,100,255), font=font)
            continue
        img = Image.open(path).convert("RGBA")
        # fit in cell preserving aspect
        img.thumbnail((cell-20, cell-20))
        ix = x + (cell - img.width)//2
        iy = yy + (cell - img.height)//2
        sheet.alpha_composite(img, (ix, iy))
        # label
        d.text((x, yy+cell-16), name[:18], fill=(200,200,200,255), font=font)
    y += math.ceil(len(items)/cols)*(cell+pad) + pad

sheet.save(out, "PNG")
print("wrote", out)
