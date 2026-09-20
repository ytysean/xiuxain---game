# -*- coding: utf-8 -*-
"""PH7-QA-16 只读探针：核 baseline_before/ 有效性 + 找 after/ + ui_theme.gd 佐证。
不启动 Godot、不改任何 .gd/.csv。输出 UTF-8 到同目录 _qa16_baseline_probe.txt。"""
import os, io, hashlib, time, json

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
OUT = os.path.join(ROOT, "production", "qa", "_qa16_baseline_probe.txt")
EXPECT_UI_THEME_MD5 = "21c4ece5ec30fdb09ec8b80354248af2"


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def scan_dir(d):
    if not os.path.isdir(d):
        return None
    pngs = []
    for fn in sorted(os.listdir(d)):
        p = os.path.join(d, fn)
        if os.path.isfile(p) and fn.lower().endswith((".png", ".webp", ".jpg", ".jpeg")):
            pngs.append((fn, os.path.getmtime(p), os.path.getsize(p)))
    return pngs


def fmt(t):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t))


L = []
L.append("== PH7-QA-16 baseline 先验（只读） ==")
L.append("ROOT=%s" % ROOT)

# 1) ui_theme.gd 佐证
ut = os.path.join(ROOT, "ui_theme.gd")
if os.path.isfile(ut):
    L.append("ui_theme.gd md5=%s size=%d mtime=%s" % (
        md5(ut), os.path.getsize(ut), fmt(os.path.getmtime(ut))))
    L.append("expected 改前 md5=%s -> %s" % (
        EXPECT_UI_THEME_MD5,
        "MATCH" if md5(ut) == EXPECT_UI_THEME_MD5 else "MISMATCH"))
    ut_mtime = os.path.getmtime(ut)
else:
    L.append("ui_theme.gd NOT FOUND")
    ut_mtime = None

# 2) 候选截图目录
cands = [
    "ui_baseline_before",
    "ui_baseline_after",
    "baseline_before",
    "baseline_after",
    "accept_shots",
    "accept_shots_full",
    "accept_shots_p0a_after",
    "after",
]
L.append("")
L.append("-- 候选目录 --")
for c in cands:
    d = os.path.join(ROOT, c)
    pngs = scan_dir(d)
    if pngs is None:
        L.append("[ 缺 ] %s" % c)
        continue
    ts = [t for _, t, _ in pngs]
    L.append("[有] %s : %d 张 | mtime %s .. %s" % (
        c, len(pngs), fmt(min(ts)) if ts else "-", fmt(max(ts)) if ts else "-"))
    if ut_mtime is not None and ts:
        n_before = sum(1 for t in ts if t <= ut_mtime + 60)
        L.append("       早于/近 ui_theme.gd mtime 的: %d/%d" % (n_before, len(ts)))

# 3) ui_baseline_before 明细
L.append("")
L.append("-- ui_baseline_before 逐张 --")
d = os.path.join(ROOT, "ui_baseline_before")
pngs = scan_dir(d)
if pngs:
    for fn, t, sz in pngs:
        L.append("  %-28s %s  %d B" % (fn, fmt(t), sz))
    L.append("  共 %d 张" % len(pngs))
else:
    L.append("  (无)")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L) + "\n")
print("WROTE", OUT)
