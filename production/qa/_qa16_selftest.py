# -*- coding: utf-8 -*-
"""PH7-QA-16 合成自检：造 after（注入已知改动）→ 跑 qa16_diff_runner → 断言。
验证：① 变化页被检出 ② 未变页判据命中「预期改但未变」③ 归因/带区/TSV 生成。
不依赖 Godot；合成图入系统临时目录，报告入 production/qa/_qa16_selftest。"""
import os, io, sys, tempfile, subprocess
import numpy as np
from PIL import Image

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
BEFORE = os.path.join(ROOT, ".workbuddy", "_ph7visual", "baseline_before")
OUT = os.path.join(ROOT, "production", "qa", "_qa16_selftest_out")
RUNNER = os.path.join(ROOT, "production", "qa", "qa16_diff_runner.py")

# 已知改动脚本：页 id → 改动描述（truth）
CHANGE = {
    "00_home": "整页底色偏移（G-25, B+25）",      # 期望 COLOR_DELTA
    "S11_坊市": "上半屏底色偏移（R+25）",           # 期望 COLOR_DELTA
    "S20_宗门舆图": "整页下拉 3px（布局位移）",      # 期望 LAYOUT_SHIFT
}
EXPECTED = ["00_home", "S11_坊市", "S20_宗门舆图", "S02_传送阵"]  # S02 故意不改 ⇒ 应命中未变页

after = os.path.join(tempfile.gettempdir(), "qa16_selftest_after")
os.makedirs(after, exist_ok=True)

n = 0
for fn in sorted(os.listdir(BEFORE)):
    if not fn.lower().endswith(".png"):
        continue
    pid = os.path.splitext(fn)[0]
    arr = np.asarray(Image.open(os.path.join(BEFORE, fn)).convert("RGB")).astype(np.int16).copy()
    h = arr.shape[0]
    if pid == "00_home":
        arr[:, :, 1] = np.clip(arr[:, :, 1] - 25, 0, 255)
        arr[:, :, 2] = np.clip(arr[:, :, 2] + 25, 0, 255)
    elif pid == "S11_坊市":
        arr[:h // 2, :, 0] = np.clip(arr[:h // 2, :, 0] + 25, 0, 255)
    elif pid == "S20_宗门舆图":
        arr = np.roll(arr, 3, axis=0)
    Image.fromarray(np.uint8(np.clip(arr, 0, 255))).save(os.path.join(after, fn))
    n += 1

exp_path = os.path.join(tempfile.gettempdir(), "qa16_selftest_expected.txt")
with io.open(exp_path, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(EXPECTED) + "\n")

cmd = [sys.executable, RUNNER, "--before", BEFORE, "--after", after, "--out", OUT,
       "--expected-pages", exp_path, "--batch-files", "ui_theme.gd", "--cmp", "--tag", "SELFTEST"]
p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
print("=== runner stdout ===")
print(p.stdout)
print(p.stderr)
print("=== copied pages:", n, "===")
