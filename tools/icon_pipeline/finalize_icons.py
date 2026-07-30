# -*- coding: utf-8 -*-
"""
图标交付最终化脚本 (finalize_icons.py)
=====================================
在最终批量 + 凝合之后运行:
  1) 全量验收: 落盘存在 / 正方形画布 / 四角透明 / 中心有内容
  2) 重写 icon_manifest.csv (354 行 + 落盘校验)
  3) 生成预览拼图: 等阶梯度表 / 法宝全览 / 凝合前后对照
用法:
  python tools/icon_pipeline/finalize_icons.py
"""
import os, csv, sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = "icon"
CSV = "tools/icon_pipeline/asset_batch_template.csv"
OUT_CSV = "icon_manifest.csv"
VALDIR = "icon/_validation"
BACKUP = os.path.join(VALDIR, "cohesion_backup")
os.makedirs(VALDIR, exist_ok=True)

def font(sz=18):
    try: return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", sz)
    except: return ImageFont.load_default()

def load(p):
    return np.array(Image.open(p).convert("RGBA"))

# ---------------- 1) 验收 ----------------
rows = list(csv.DictReader(open(CSV, encoding="utf-8-sig")))
missing, sz_bad, corner_bad, content_bad = [], [], [], []
for d in rows:
    p = d["icon_path"].replace("res://", "").replace("/", "\\")
    if not os.path.isfile(p):
        missing.append(p); continue
    a = load(p); h, w, _ = a.shape
    if w != h:
        sz_bad.append((d["item_id"], (w, h))); continue
    al = a[:, :, 3]
    c = [al[0,0], al[w-1,0], al[0,h-1], al[w-1,h-1]]
    if not all(v == 0 for v in c):
        corner_bad.append((d["item_id"], [int(v) for v in c]))
    cy, cx = h//2, w//2
    r = al[cy-30:cy+30, cx-30:cx+30]
    if int((r > 10).sum()) < 50:
        content_bad.append(d["item_id"])

total = len(rows)
print("=== 验收 ===")
print(f"  总行数: {total} | 缺失: {len(missing)}")
print(f"  非正方形: {len(sz_bad)} {sz_bad[:5]}")
print(f"  四角不透明: {len(corner_bad)} {corner_bad[:5]}")
print(f"  中心无内容: {len(content_bad)} {content_bad[:5]}")
print(f"  PASS: {total-len(missing)-len(sz_bad)-len(corner_bad)-len(content_bad)}/{total}")

# ---------------- 2) 清单 ----------------
with open(OUT_CSV, "w", encoding="utf-8-sig", newline="") as f:
    cols = ["item_id","item_name","category","folder","grade","tier","badge_grade","archetype","icon_path","file_exists"]
    w = csv.DictWriter(f, fieldnames=cols); w.writeheader()
    for d in rows:
        p = d["icon_path"].replace("res://", "").replace("/", "\\")
        w.writerow({"item_id":d["item_id"],"item_name":d["item_name"],"category":d["category"],
                    "folder":d["folder"],"grade":d["grade"],"tier":d["tier"],"badge_grade":d["badge_grade"],
                    "archetype":d["archetype"],"icon_path":d["icon_path"],
                    "file_exists":("Y" if os.path.isfile(p) else "N")})
print(f"清单已写: {OUT_CSV}")

# ---------------- 3) 等阶梯度表 ----------------
order, label = [], {}
for d in rows:
    if d["folder"] not in label:
        order.append(d["folder"]); label[d["folder"]] = d["category"]
pick = {}
for d in rows:
    k = (d["folder"], d["tier"])
    if k not in pick:
        pick[k] = d["icon_path"].replace("res://", "").replace("/", "\\")
tiers = ["low","mid","high"]; tlabels = ["低阶 low","中阶 mid","高阶 high"]
cell = 220; lcol = 170; top = 70
W = lcol + len(tiers)*cell; H = top + len(order)*cell
sheet = Image.new("RGBA",(W,H),(235,238,236,255)); dr = ImageDraw.Draw(sheet); fnt = font(20); fnts = font(15)
dr.text((W//2, 18), "等阶梯度总表 (12 类 × 3 阶, 边框=tier/色点=7档品阶)", fill=(20,30,26,255), font=fnts, anchor="mm")
for j,t in enumerate(tiers):
    dr.text((lcol+j*cell+cell//2, top//2-6), tlabels[j], fill=(30,40,36,255), font=fnts, anchor="mm")
for i,fol in enumerate(order):
    y = top+i*cell
    dr.text((lcol//2, y+cell//2), f"{label[fol]}\n({fol})", fill=(20,30,26,255), font=fnt, anchor="mm")
    for j,t in enumerate(tiers):
        x = lcol+j*cell; p = pick.get((fol,t))
        if p and os.path.isfile(p):
            sheet.alpha_composite(Image.open(p).convert("RGBA").resize((cell,cell)),(x,y))
        else:
            dr.rectangle([x+4,y+4,x+cell-4,y+cell-4], outline=(180,180,180,255))
sheet.convert("RGB").save(os.path.join(VALDIR,"tier_gradient_sheet.png"))
print("梯度表已写:", os.path.join(VALDIR,"tier_gradient_sheet.png"), sheet.size)

# ---------------- 4) 法宝全览 ----------------
tr = [d for d in rows if d["folder"]=="treasure"]
cell = 190; pad = 8; cols_n = 6; rows_n = (len(tr)+cols_n-1)//cols_n; top = 40
W = cols_n*cell; H = top+rows_n*cell
sheet = Image.new("RGBA",(W,H),(235,238,236,255)); dr = ImageDraw.Draw(sheet); fnts = font(15)
dr.text((W//2,14), f"法宝 treasure 全 {len(tr)} 张 (低/中/高阶按 id 排)", fill=(20,30,26,255), font=fnts, anchor="mm")
for i,d in enumerate(tr):
    c = i%cols_n; rr = i//cols_n; x = c*cell; y = top+rr*cell
    p = d["icon_path"].replace("res://", "").replace("/", "\\")
    if os.path.isfile(p):
        sheet.alpha_composite(Image.open(p).convert("RGBA").resize((cell-pad*2,cell-pad*2)),(x+pad,y+pad))
    dr.rectangle([x+2,y+2,x+cell-2,y+cell-2], outline=(200,200,200,255))
    dr.text((x+6,y+cell-18), f"{d['item_id']} {d['tier'][0].upper()}", fill=(40,50,46,255), font=fnts)
sheet.convert("RGB").save(os.path.join(VALDIR,"treasure_sheet.png"))
print("法宝表已写:", os.path.join(VALDIR,"treasure_sheet.png"), sheet.size)

# ---------------- 5) 凝合前后对照 ----------------
samples = []
seen = set()
for d in rows:
    k = (d["folder"], d["tier"])
    if k in seen: continue
    seen.add(k)
    samples.append(d)
    if len(samples) >= 8: break
cell = 300; pad = 10; W = cell*2+pad*3; H = cell*len(samples)+pad*(len(samples)+1)
sheet = Image.new("RGBA",(W,H),(240,242,240,255)); dr = ImageDraw.Draw(sheet); fnts = font(15)
dr.text((W//2, 14), "整包光影凝合: 左=原图(备份) 右=凝合后", fill=(20,30,26,255), font=fnts, anchor="mm")
for i,d in enumerate(samples):
    rel = d["icon_path"].replace("res://","").lstrip("/").replace("/","\\")
    bp = os.path.join(BACKUP, rel); cp = os.path.join(ROOT, rel)
    y = pad+i*(cell+pad)
    if os.path.isfile(bp):
        sheet.alpha_composite(Image.open(bp).convert("RGBA").resize((cell,cell)),(pad,y))
    if os.path.isfile(cp):
        sheet.alpha_composite(Image.open(cp).convert("RGBA").resize((cell,cell)),(pad*2+cell,y))
    dr.text((pad, y-2), f"{d['item_id']} {d['folder']}/{d['tier']}", fill=(20,30,26,255), font=fnts)
sheet.convert("RGB").save(os.path.join(VALDIR,"cohesion_compare.png"))
print("凝合对照已写:", os.path.join(VALDIR,"cohesion_compare.png"), sheet.size)
print("DONE")
