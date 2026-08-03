# -*- coding: utf-8 -*-
import os, subprocess
from PIL import Image

ROOT = "E:/Xiuxian/taixuanzongmenlu"
OUT_DIR = os.path.join(ROOT, "art/backgrounds")
SRC_DIR = os.path.join(ROOT, "art/backgrounds/_gen/sect_bg_grand")
OVERLAY = (22, 34, 29)  # #16221D
ALPHA = 0.50

final_paths = []
for i in range(1, 11):
    path = os.path.join(OUT_DIR, f"sect_bg_grand_{i:02d}.png")
    img = Image.open(path).convert("RGB")
    # blend with overlay
    overlay = Image.new("RGB", img.size, OVERLAY)
    img = Image.blend(img, overlay, ALPHA)
    img.save(path, "PNG")
    final_paths.append(path)
    print(f"[OVERLAY] {path}")

# rebuild montage
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

# re-validate
validator = os.path.join(ROOT, "art/scene_pipeline/scene_validate.py")
subprocess.run([
    "C:/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe",
    validator, "--src", OUT_DIR, "--pattern", "sect_bg_grand_*.png"
], check=False)
