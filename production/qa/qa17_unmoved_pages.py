# -*- coding: utf-8 -*-
"""PH7-QA-17 · 生成《P0-A 21 页未变清单》
读 QA 差分 TSV 的 IDENTICAL 行 → 逐页定位 >8 像素分布 → 分档/归因 → 出 Markdown。
只读 PNG（不启 Godot）。输出 production/qa/PH7-P0A-21页未变清单.md
"""
import os, io, re, sys
import numpy as np
from PIL import Image

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
B = os.path.join(ROOT, ".workbuddy", "_ph7visual", "baseline_before")
A = os.path.join(ROOT, ".workbuddy", "_ph7visual", "after")
TSV = os.path.join(ROOT, "production", "qa", "_qa16_out", "qa16_逐页差分.tsv")
OUT = os.path.join(ROOT, "production", "qa", "PH7-P0A-21页未变清单.md")

PIX = 8
TOP_BAR_Y = 150      # 顶栏/安全区
BOTTOM_TAB_Y = 1200  # 底部 Tab


def classify(y0, y1, x0, x1, n8, mx):
    if n8 == 0:
        return "量化噪声", "-", "否", "纯 PNG 量化噪声（max=%d ≤ 8，视觉无变化）；主背景**未接**本批 26 行 token" % mx
    # 区域描述
    if y1 < TOP_BAR_Y and x0 >= 640:
        region = "顶右条 y%d-%d x%d-%d" % (y0, y1, x0, x1)
        inmain = "否"
    elif y1 < TOP_BAR_Y:
        region = "顶栏区 y%d-%d x%d-%d" % (y0, y1, x0, x1)
        inmain = "否"
    elif y0 >= BOTTOM_TAB_Y:
        region = "底部Tab区 y%d-%d x%d-%d" % (y0, y1, x0, x1)
        inmain = "否"
    else:
        region = "主视区 y%d-%d x%d-%d" % (y0, y1, x0, x1)
        inmain = "**是**"
    if inmain == "否":
        cause = "仅**顶栏/安全区**小元素接了改后 token（%d px）；**主背景未变** → 候选 **硬编码 Color** 或**本批 26 行外 token**" % n8
    else:
        cause = "主视区**微量**元素接了改后 token（%d px，<0.05%%）；逐页精修时复核该元素" % n8
    return "亚阈值", region, inmain, cause


def main():
    rows = []
    with io.open(TSV, encoding="utf-8") as f:
        hdr = f.readline().rstrip("\n").split("\t")
        for ln in f:
            c = ln.rstrip("\n").split("\t")
            if len(c) < len(hdr):
                continue
            d = dict(zip(hdr, c))
            if d["判定"] == "IDENTICAL":
                rows.append(d)

    L = []
    L.append("# PH7 · P0-A 底色漂移批 —— 21 页「未变」清单（亚阈值/量化噪声归因）")
    L.append("")
    L.append("- **产出**：quality-lead-2 ｜ 依据 `qa16_逐页差分.tsv`（引擎判 IDENTICAL 的 21 页）＋ 逐像素定位")
    L.append("- **口径**：可见变化 = 改动像素占比 ≥ 0.05%（PIX_TOL=8）；下表 21 页**均低于该阈**（引擎判 IDENTICAL）")
    L.append("- **用途**：老大页序「首页→弟子→殿阁→坊市→灵钓→灵兽→**其他**」的**「其他」轮次派单依据**")
    L.append("- 主视觉窗定义：主视区 y∈[%d,%d)；顶栏/安全区 y<%d；底部 Tab y≥%d" % (
        TOP_BAR_Y, BOTTOM_TAB_Y, TOP_BAR_Y, BOTTOM_TAB_Y))
    L.append("")

    recs = []
    for d in rows:
        pg = d["页id"]
        pb = os.path.join(B, pg + ".png")
        pa = os.path.join(A, pg + ".png")
        if not (os.path.isfile(pb) and os.path.isfile(pa)):
            continue
        ib = np.asarray(Image.open(pb).convert("RGB"), dtype=np.int16)
        ia = np.asarray(Image.open(pa).convert("RGB"), dtype=np.int16)
        if ib.shape != ia.shape:
            recs.append((pg, "SIZE", 0, "-", "-", "尺寸不符"))
            continue
        dd = np.abs(ib - ia).max(axis=2)
        mx = int(dd.max())
        mask = dd > PIX
        n8 = int(mask.sum())
        if n8:
            ys, xs = np.where(mask)
            y0, y1, x0, x1 = int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())
        else:
            y0 = y1 = x0 = x1 = 0
        tier, region, inmain, cause = classify(y0, y1, x0, x1, n8, mx)
        recs.append((pg, tier, n8, region, inmain, cause, mx, float(d["改动占比"])))

    # 按档位排序：亚阈值在前
    recs.sort(key=lambda r: (r[1] == "量化噪声", -(r[2] if isinstance(r[2], int) else 0)))

    L.append("## 总表（%d 页）" % len(recs))
    L.append("")
    L.append("| 页 id | 档位 | >8 像素数 | 分布区域 | 落在主视觉窗 | 疑似原因 |")
    L.append("|---|---|---:|---|:--:|---|")
    for r in recs:
        pg, tier, n8, region, inmain, cause = r[0], r[1], r[2], r[3], r[4], r[5]
        L.append("| `%s` | %s | %s | %s | %s | %s |" % (
            pg, ("**亚阈值**" if tier == "亚阈值" else "量化噪声"), n8, region, inmain, cause))
    L.append("")

    n_sub = sum(1 for r in recs if r[1] == "亚阈值")
    n_noise = sum(1 for r in recs if r[1] == "量化噪声")
    L.append("**汇总**：亚阈值（>8 但 <0.05%%）**%d 页** ｜ 量化噪声（>8=0，max≤8）**%d 页**" % (n_sub, n_noise))
    L.append("")
    L.append("## 关键结论")
    L.append("")
    L.append("1. **21 页主背景均未被本批 26 行 token 触及**：")
    L.append("   - **%d 页（亚阈值）**：均为**顶栏条 `y24-80 x410-703`**（≈244 px）一处小元素接了改后 token，**主背景没变**；其中 **3 页（`S38_科技`/`S31_灵兽`/`TAB_殿阁`）另有主视区微量元素**（段2/段中），逐页精修时单独复核。" % n_sub)
    L.append("   - **%d 页（量化噪声）**：`>8` 像素 = 0，max 通道差 ≤ 8 ⇒ **视觉无变化**（art 的 md5 口径把这批算作「变」是 PNG 量化噪声所致）。" % n_noise)
    L.append("2. ⇒ 这 21 页 = **「逐页视觉精修」必须接管**的对象（全局 token 修正到达不了它们的**主视觉**）。")
    L.append("3. **建议派单时的第一动作**：逐页回盘核**硬编码 `Color(` 字面量**（确认其主背景是否硬编码、抑或用了本批 26 行以外的 token）。")
    L.append("4. **不判 FAIL**：本批（P0-A）只改 `ui_theme.gd` 常量；页面主背景是否硬编码**不属本批范围**（`spec §4` 不动清单：硬编码 Color 全量 1242 处归 **P0-4**）。本清单=**P0-4 的优先输入**。")
    L.append("")
    L.append("## 明细（含 max 通道差 / 改动占比）")
    L.append("")
    L.append("| 页 id | maxΔ | 改动占比 | 档位 |")
    L.append("|---|---:|---:|---|")
    for r in recs:
        L.append("| `%s` | %s | %s | %s |" % (r[0], r[6], r[7] if len(r) > 7 else "-", r[1]))
    L.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("WROTE", OUT)
    print("sub=%d noise=%d total=%d" % (n_sub, n_noise, len(recs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
