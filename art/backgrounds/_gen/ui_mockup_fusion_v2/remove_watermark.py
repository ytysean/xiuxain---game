# -*- coding: utf-8 -*-
import os, numpy as np, cv2
from PIL import Image

HERE = "E:/Xiuxian/taixuanzongmenlu/art/backgrounds/_gen/ui_mockup_fusion_v2"
SRC = os.path.join(HERE, "mockup_v2.png")
DST = os.path.join(HERE, "mockup_v2_nowm.png")

img = cv2.imread(SRC)
if img is None:
    raise SystemExit("cannot read " + SRC)
h, w = img.shape[:2]
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# 1) 只在图片外围边缘带（四边各 16%）内搜索水印，避免误伤中心 UI
edge = int(round(min(h, w) * 0.16))
band = np.zeros((h, w), dtype=np.uint8)
band[0:edge, :] = 1          # top
band[h-edge:h, :] = 1        # bottom
band[:, 0:edge] = 1          # left
band[:, w-edge:w] = 1        # right

# 2) 局部亮度异常检测：水印=半透明浅块，比局部均值明显亮
kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31))
local_mean = cv2.blur(gray.astype(np.float32), (31, 31))
diff = gray.astype(np.float32) - local_mean
# 只在边缘带内取亮异常（>22 且本身不算最暗区域）
candidate = (diff > 22) & (gray > 90) & (band > 0)
mask = candidate.astype(np.uint8) * 255

# 3) 膨胀让边缘平滑，再清理小噪点
mask = cv2.dilate(mask, np.ones((4, 4), np.uint8), iterations=2)
mask = cv2.erode(mask, np.ones((3, 3), np.uint8), iterations=1)
cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
clean = np.zeros_like(mask)
kept = 0
for c in cnts:
    a = cv2.contourArea(c)
    if 30 < a < 60000:
        cv2.drawContours(clean, [c], -1, 255, -1)
        kept += 1
mask = clean

# 4) inpaint（只修补被 mask 标记区域）
if mask.sum() > 0:
    res = cv2.inpaint(img, mask, 4, cv2.INPAINT_TELEA)
    out = res
    print(f"[WATERMARK] regions kept={kept}, masked_px={int(mask.sum()//255)}")
else:
    out = img
    print("[WATERMARK] none detected in edge band")

cv2.imwrite(DST, out)
print(f"[SAVE] {DST} size={(w,h)}")
