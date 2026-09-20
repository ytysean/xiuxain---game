#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qa24_text_presence.py —— 「文字存在性」画质判据（判据版本 v1.2 / 2026-09-17）

定案判据（team-lead msg#6 拍板）
------------------------------
在目标物理带 (x0,y0,x1,y1) 内：
  1) D = |A − B|.max(2)  →  M = (D > 120)  →  连通成块（默认 4-邻域）
  2) 一块「有字」须**同时**满足：
       px ≥ 60  且  bbox_w ≥ 8  且  bbox_h ≥ 8  且  块内量化众数色占比 ≥ 0.50
  3) 分级（占比）：
       ≥ 0.65          → PASS
       0.50 – 0.65     → WEAK（需人工确认）
       < 0.50          → FAIL
  4) 30 ≤ px < 60 的块：**一律打印为「疑似未达阈」**，不得静默丢弃（单字标签预计 ~38 px）。

颜色无关：众数取**量化色**（每通道 `v//32`），报告色取该 bin 内实际均值。禁用「单色常量」判据。

禁用清单
--------
  ① md5 当内容代理
  ② `>8` 全屏计数（S38_科技 853607 px 里 850761 只差 ≤2 级，已知假阳性）
  ③ 任何绑定单一颜色常量的判据（白纸黑字）

硬门（非提示）
--------------
  · 合成对照失败 ⇒ 打印 CRITERION BROKEN，`exit 2`
  · batch 的真实阳性对照（`P2_B_noclip @snap_card1`）判 FAIL ⇒ 打印 CRITERION BROKEN，`exit 1`
    （WEAK 视为「已亮」，不触发硬门）

用法
----
  python qa24_text_presence.py selftest
  python qa24_text_presence.py pair  A.png B.png x0,y0,x1,y1 [--quant 32] [--conn 4]
  python qa24_text_presence.py dump  A.png B.png x0,y0,x1,y1 [--conn 4|8] [--min-px 1]
  python qa24_text_presence.py batch <dir> <ref_name>

只读，无 Godot。
"""
import os
import sys
from collections import deque, Counter

import numpy as np
from PIL import Image

DIFF_THR = 120
MIN_BLOCK = 60        # v1.2
MIN_BBOX = 8          # v1.2：块 bbox 高/宽都须 ≥ 8
SUSPECT_MIN = 30      # 30~59 px 打印为「疑似」
WEAK_LO = 0.50
PASS_HI = 0.65
QUANT = 32
CRITERION_VERSION = "v1.2/2026-09-17"

BANDS = {
    "snap_title_wide": (26, 780, 693, 804),
    "snap_card1":      (85, 785, 148, 800),
    "dock_label":      (0, 1090, 719, 1125),   # v1.2 更正后的 dock 标签带
    "dock_label_old":  (0, 1029, 719, 1039),   # 旧（dock 上沿，无字）
    "dock_full":       (0, 1029, 719, 1139),
    "value_ctrl":      (26, 807, 693, 840),
}


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.int16)


def label_components(mask, conn=4):
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    if conn == 8:
        offs = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    else:
        offs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if mask[y0, x0] and not seen[y0, x0]:
                dq = deque([(y0, x0)])
                seen[y0, x0] = True
                cells = []
                while dq:
                    y, x = dq.popleft()
                    cells.append((y, x))
                    for dy, dx in offs:
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            dq.append((ny, nx))
                comps.append(cells)
    return comps


def _block_stats(cells, b, x0, y0):
    size = len(cells)
    ys = np.array([c[0] for c in cells]); xs = np.array([c[1] for c in cells])
    colsb = b[ys, xs]
    q = colsb // QUANT
    cnt = Counter(map(tuple, q.tolist()))
    bin_, bcount = cnt.most_common(1)[0]
    sel = np.all(q == np.array(bin_), axis=1)
    mean = colsb[sel].mean(0)
    bx0, by0, bx1, by1 = int(xs.min()) + x0, int(ys.min()) + y0, int(xs.max()) + x0, int(ys.max()) + y0
    return {
        "size": size,
        "bbox": (bx0, by0, bx1, by1),
        "w": bx1 - bx0 + 1, "h": by1 - by0 + 1,
        "mode_bin": tuple(int(v) * QUANT for v in bin_),
        "mode_color": tuple(int(round(v)) for v in mean),
        "mode_share": round(bcount / size, 3),
    }


def analyze(A, B, band, conn=4):
    x0, y0, x1, y1 = band
    x1 = min(x1, A.shape[1] - 1); y1 = min(y1, A.shape[0] - 1)
    a = A[y0:y1 + 1, x0:x1 + 1]; b = B[y0:y1 + 1, x0:x1 + 1]
    if a.shape != b.shape:
        return {"ok": False}
    d = np.abs(a - b).max(2)
    m = d > DIFF_THR
    n_diff = int(m.sum())
    allblocks = [_block_stats(cells, b, x0, y0) for cells in label_components(m, conn) if len(cells) >= 1]
    allblocks.sort(key=lambda t: -t["size"])

    def qualifies(bl):
        return (bl["size"] >= MIN_BLOCK and bl["w"] >= MIN_BBOX and bl["h"] >= MIN_BBOX
                and bl["mode_share"] >= WEAK_LO)

    qual = [bl for bl in allblocks if qualifies(bl)]
    suspect = [bl for bl in allblocks if SUSPECT_MIN <= bl["size"] < MIN_BLOCK]
    passes = [bl for bl in qual if bl["mode_share"] >= PASS_HI]
    weaks = [bl for bl in qual if bl["mode_share"] < PASS_HI]
    if passes:
        verdict = "PASS"
    elif weaks:
        verdict = "WEAK"
    else:
        verdict = "FAIL"
    return {"ok": True, "n_diff": n_diff, "n_blocks": len(allblocks),
            "largest": allblocks[0] if allblocks else None,
            "best_qual": (max(qual, key=lambda bl: bl["mode_share"]) if qual else None),
            "qualifying": qual[:5], "suspect": suspect[:8],
            "verdict": verdict, "exists": len(qual) > 0}


def self_test():
    A = np.zeros((60, 60, 3), np.int16)
    Bp = A.copy(); Bp[10:24, 10:24] = 255          # 14x14 = 196 px 纯白块
    Bn = A.copy()
    pos = analyze(A, Bp, (0, 0, 59, 59))
    neg = analyze(A, Bn, (0, 0, 59, 59))
    ok = pos["exists"] and not neg["exists"]
    return ok, "pos=%s/%s neg=%s" % (pos["exists"], pos["verdict"], neg["exists"])


def fmt(res):
    if not res.get("ok"):
        return "ERROR"
    lg = res.get("best_qual") or res["largest"]
    ls = ("max px=%d %dx%d bbox=%s color=%s share=%.3f"
          % (lg["size"], lg["w"], lg["h"], lg["bbox"], lg["mode_color"], lg["mode_share"])) if lg else "no blk"
    s = "n_diff=%5d blk=%2d [%s] verdict=%s exists=%s" % (res["n_diff"], res["n_blocks"], ls, res["verdict"], res["exists"])
    if res["suspect"]:
        s += " | 疑似(30-59px)=%d[%s]" % (len(res["suspect"]), ",".join("px%d/%dx%d" % (x["size"], x["w"], x["h"]) for x in res["suspect"][:4]))
    return s


def dump_blocks(A, B, band, conn):
    x0, y0, x1, y1 = band
    x1 = min(x1, A.shape[1] - 1); y1 = min(y1, A.shape[0] - 1)
    a = A[y0:y1 + 1, x0:x1 + 1]; b = B[y0:y1 + 1, x0:x1 + 1]
    d = np.abs(a - b).max(2); m = d > DIFF_THR
    blocks = [_block_stats(cells, b, x0, y0) for cells in label_components(m, conn) if len(cells) >= 1]
    blocks.sort(key=lambda t: -t["size"])
    print("dump band=%s conn=%d  n_diff=%d  连通块=%d" % (band, conn, int(m.sum()), len(blocks)))
    tot = m.sum()
    print("  %-4s %-22s %-9s %-14s %s" % ("px", "bbox(x0,y0,x1,y1)", "w x h", "量化众数色", "占比"))
    for bl in blocks[:40]:
        print("  %-4d %-22s %-9s %-14s %.2f" % (bl["size"], str(bl["bbox"]), "%dx%d" % (bl["w"], bl["h"]), str(bl["mode_color"]), bl["mode_share"]))
    ys, xs = np.where(m)
    if len(ys):
        print("  [全差像素包络] x=%d..%d  y=%d..%d  (w=%d,h=%d)" % (xs.min() + x0, xs.max() + x0, ys.min() + y0, ys.max() + y0, xs.max() - xs.min() + 1, ys.max() - ys.min() + 1))
    return blocks


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); return
    cmd = args[0]
    print("# qa24_text_presence · criterion %s" % CRITERION_VERSION)
    ok, detail = self_test()
    print("# self-test(synthetic): %s  %s" % ("PASS" if ok else "FAIL", detail))
    if not ok:
        print("CRITERION BROKEN")
        sys.exit(2)

    conn = 4
    if "--conn" in args:
        conn = int(args[args.index("--conn") + 1])

    if cmd == "selftest":
        return

    if cmd == "dump":
        A = load(args[1]); B = load(args[2])
        band = tuple(int(v) for v in args[3].split(","))
        dump_blocks(A, B, band, conn)
        return

    if cmd == "pair":
        A = load(args[1]); B = load(args[2])
        band = tuple(int(v) for v in args[3].split(","))
        print("pair %s vs %s band=%s conn=%d" % (os.path.basename(args[1]), os.path.basename(args[2]), band, conn))
        print(fmt(analyze(A, B, band, conn)))
        return

    if cmd == "batch":
        d = args[1]; ref = args[2]
        A = load(os.path.join(d, ref + ".png"))
        frames = sorted(f[:-4] for f in os.listdir(d) if f.endswith(".png"))
        print("batch ref=%s frames=%d conn=%d" % (ref, len(frames), conn))

        # 真实阳性对照（硬门）
        if "P2_B_noclip" in frames:
            Bc = load(os.path.join(d, "P2_B_noclip.png"))
            rc = analyze(A, Bc, BANDS["snap_card1"], conn)
            print("# real-positive-ctrl(P2_B_noclip@snap_card1): %s | %s" % (rc["verdict"], fmt(rc)))
            if rc["verdict"] == "FAIL":
                print("CRITERION BROKEN")
                sys.exit(1)
        # 真实阴性对照
        if "P2B_dock_noclip" in frames:
            Bd = load(os.path.join(d, "P2B_dock_noclip.png"))
            rn = analyze(A, Bd, BANDS["snap_card1"], conn)
            print("# real-negative-ctrl(P2B_dock_noclip@snap_card1): %s（期望 FAIL）| %s" % (rn["verdict"], fmt(rn)))

        for band_name, band in BANDS.items():
            print("\n## band %s %s" % (band_name, band))
            for fn in frames:
                if fn == ref:
                    continue
                B = load(os.path.join(d, fn + ".png"))
                r = analyze(A, B, band, conn)
                print("   %-20s %s" % (fn, fmt(r)))
        return

    print("unknown cmd", cmd)


if __name__ == "__main__":
    main()
