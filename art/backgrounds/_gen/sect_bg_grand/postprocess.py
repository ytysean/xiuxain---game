# -*- coding: utf-8 -*-
import os, sys, glob, subprocess
from PIL import Image

ROOT = "E:/Xiuxian/taixuanzongmenlu"
SRC_DIR = os.path.join(ROOT, "art/backgrounds/_gen/sect_bg_grand")
OUT_DIR = os.path.join(ROOT, "art/backgrounds")
CANVAS = (960, 1708)

def coversize(img):
    rgb = img.convert("RGB")
    sw, sh = rgb.size
    rs, rt = sw / sh, CANVAS[0] / CANVAS[1]
    if rs > rt:
        nw, nh = int(round(CANVAS[1] * rs)), CANVAS[1]
        left = (nw - CANVAS[0]) // 2
        return rgb.resize((nw, nh), Image.Resampling.LANCZOS).crop((left, 0, left + CANVAS[0], CANVAS[1]))
    nw, nh = CANVAS[0], int(round(CANVAS[0] / rs))
    top = (nh - CANVAS[1]) // 2
    return rgb.resize((nw, nh), Image.Resampling.LANCZOS).crop((0, top, CANVAS[0], top + CANVAS[1]))

# 1) resize + save finals
final_paths = []
for i in range(1, 11):
    src = os.path.join(SRC_DIR, f"style{i:02d}", "bg.png")
    dst = os.path.join(OUT_DIR, f"sect_bg_grand_{i:02d}.png")
    if not os.path.exists(src):
        print(f"[SKIP] missing {src}")
        continue
    img = Image.open(src)
    out = coversize(img)
    out.save(dst, "PNG")
    final_paths.append(dst)
    print(f"[SAVE] {dst} ({out.size})")

# 2) build 2x5 overview montage
n = len(final_paths)
if n:
    thumb_w, thumb_h = 240, 426
    montage = Image.new("RGB", (thumb_w * 5, thumb_h * 2), (20, 25, 23))
    for idx, path in enumerate(final_paths):
        img = Image.open(path).resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        x = (idx % 5) * thumb_w
        y = (idx // 5) * thumb_h
        montage.paste(img, (x, y))
    montage_path = os.path.join(SRC_DIR, "overview_2x5.png")
    montage.save(montage_path, "PNG")
    print(f"[MONTAGE] {montage_path}")

# 3) run scene_validate
validator = os.path.join(ROOT, "art/scene_pipeline/scene_validate.py")
if os.path.exists(validator):
    cmd = [
        sys.executable, validator,
        "--src", OUT_DIR,
        "--pattern", "sect_bg_grand_*.png",
    ]
    print("[VALIDATE]", " ".join(cmd))
    subprocess.run(cmd, check=False)
else:
    print("[WARN] scene_validate.py not found")
