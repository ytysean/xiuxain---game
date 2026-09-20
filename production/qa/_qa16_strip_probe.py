# -*- coding: utf-8 -*-
"""PH7-QA-16 探针：定位「微量变化页」的改动位置（条带/行分布）+ 与 art md5 口径对账。只读。"""
import os, io, hashlib
import numpy as np
from PIL import Image

VIS = r"E:\Xiuxian\taixuanzongmenlu\.workbuddy\_ph7visual"
B = os.path.join(VIS, "baseline_before")
A = os.path.join(VIS, "after")
OUT = r"E:\Xiuxian\taixuanzongmenlu\production\qa\_qa16_strip_probe.txt"

PAGES = ["S01_丹方", "S38_科技", "S20_宗门舆图", "X04_宗主详情", "X05_玩家交易", "X06_离线管理", "S11_坊市"]


def md5f(p):
    with open(p, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


L = ["== 微量变化页定位探针 =="]
for pg in PAGES:
    pb = os.path.join(B, pg + ".png")
    pa = os.path.join(A, pg + ".png")
    if not (os.path.isfile(pb) and os.path.isfile(pa)):
        L.append("%s: MISSING" % pg)
        continue
    ib = np.asarray(Image.open(pb).convert("RGB"), dtype=np.int16)
    ia = np.asarray(Image.open(pa).convert("RGB"), dtype=np.int16)
    same_md5 = (md5f(pb) == md5f(pa))
    if ib.shape != ia.shape:
        L.append("%s: SIZE %s vs %s" % (pg, ib.shape, ia.shape))
        continue
    d = np.abs(ib - ia).max(axis=2)
    h, w = d.shape
    nz = int((d > 0).sum())
    n8 = int((d > 8).sum())
    rows_changed = np.where((d > 0).any(axis=1))[0]
    rows8 = np.where((d > 8).any(axis=1))[0]
    L.append("")
    L.append("[%s] 尺寸 %dx%d  md5同=%s" % (pg, w, h, same_md5))
    L.append("  像素: 非零=%d   >8=%d   max=%d" % (nz, n8, int(d.max())))
    if len(rows_changed):
        L.append("  非零行范围: y=%d..%d  (共%d行)" % (rows_changed.min(), rows_changed.max(), len(rows_changed)))
    if len(rows8):
        L.append("  >8  行范围: y=%d..%d  (共%d行)" % (rows8.min(), rows8.max(), len(rows8)))
    # 行直方（每 8 段）
    seg = max(1, h // 8)
    hh = []
    for i in range(8):
        y0, y1 = i * seg, min(h, (i + 1) * seg)
        hh.append(int((d[y0:y1] > 8).sum()))
    L.append("  行8段 >8 像素: %s" % hh)
    # 若顶部有变化，取首个 >8 行的列范围与颜色
    if len(rows8):
        y = int(rows8.min())
        cols = np.where(d[y] > 8)[0]
        L.append("  首>8行 y=%d 列=%d..%d  该行 before=%s after=%s" % (
            y, int(cols.min()), int(cols.max()),
            list(ib[y, cols[0]]), list(ia[y, cols[0]])))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")
print("WROTE", OUT)
