# -*- coding: utf-8 -*-
import os, numpy as np, cv2
from PIL import Image

HERE = "E:/Xiuxian/taixuanzongmenlu/art/backgrounds/_gen/ui_mockup_fusion_v2"
SRC = os.path.join(HERE, "mockup_v2.png")          # 原始未动过的图
DST = os.path.join(HERE, "mockup_v2_nowm.png")

img = cv2.imread(SRC)
h, w = img.shape[:2]
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# 只锁定四角最外缘小区域（AI平台水印常驻角落，底边中央Tab/顶部状态栏不在内）
R = 0.13
corners = [
    (0, 0, int(w*R), int(h*R)),               # 左上
    (int(w*(1-R)), 0, w, int(h*R)),           # 右上
    (0, int(h*(1-R)), int(w*R), h),           # 左下
    (int(w*(1-R)), int(h*(1-R)), w, h),       # 右下
]
mask = np.zeros((h, w), dtype=np.uint8)
for (x0, y0, x1, y1) in corners:
    band = np.zeros((h, w), dtype=np.uint8)
    band[y0:y1, x0:x1] = 1
    local_mean = cv2.blur(gray.astype(np.float32), (25, 25))
    diff = gray.astype(np.float32) - local_mean
    cand = (diff > 20) & (gray > 95) & (band > 0)
    mask |= cand.astype(np.uint8) * 255

mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=2)
cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
clean = np.zeros_like(mask)
kept = 0
for c in cnts:
    a = cv2.contourArea(c)
    if 20 < a < 8000:                 # 只修小亮块（水印logo/字），不碰大块UI
        cv2.drawContours(clean, [c], -1, 255, -1)
        kept += 1
        x, y, cw, ch = cv2.boundingRect(c)
        print(f"  region bbox=({x},{y},{cw},{ch}) area={int(a)}")
mask = clean

if mask.sum() > 0:
    out = cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)
    print(f"[WATERMARK] kept={kept}, masked_px={int(mask.sum()//255)}")
else:
    out = img
    print("[WATERMARK] none in corners")
cv2.imwrite(DST, out)
print(f"[SAVE] {DST}")
