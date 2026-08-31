#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
B2 图标规范化后处理：将三套 UI 图标统一到 96x96 基准 + USM 锐化 + 对比度增强。
目标：消除 bld_/nav_/res_/_gen 组内与组间的尺寸/清晰度差异，对齐商业手游工业化标准。

处理范围（按 glob）：
  art/ui/buttons/bld_*.png      (功能卡图标：7张88 + 8张256 -> 96)
  art/ui/buttons/nav_*.png      (底部Tab：已96，过一遍锐化对齐)
  art/ui/buttons/res_*.png      (资源栏：5张64 -> 96)
  art/ui/buttons/_gen/icon_func_*.png  (洞天/隐藏UI：256 -> 96)

流程：
  1. 备份原图到 art/ui/buttons/_legacy_b2/
  2. 非正方形先补透明边变正方形（避免裁切）
  3. LANCZOS 重采样到 96x96
  4. 仅对 RGB 通道做 USM 锐化 (radius 0.4, percent 120, threshold 1)，保留 alpha 不被污染
  5. 对比度 +5% 增强描边清晰度
  6. 原地覆盖保存
"""
import os
import glob
from PIL import Image, ImageFilter, ImageEnhance

ROOT = "art/ui/buttons"
LEGACY = os.path.join(ROOT, "_legacy_b2")
TARGET = 96

GROUPS = [
    os.path.join(ROOT, "bld_*.png"),
    os.path.join(ROOT, "nav_*.png"),
    os.path.join(ROOT, "res_*.png"),
    os.path.join(ROOT, "_gen", "icon_func_*.png"),
]

os.makedirs(LEGACY, exist_ok=True)


def process(path: str) -> str:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    # 非正方形 -> 补透明边成正方形（绝不裁切）
    if w != h:
        side = max(w, h)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(img, ((side - w) // 2, (side - h) // 2))
        img = sq
    # 重采样到 TARGET
    if img.size[0] != TARGET:
        img = img.resize((TARGET, TARGET), Image.LANCZOS)
    # 仅锐化 RGB 通道，alpha 不变（避免透明边 halo）
    rgb = img.convert("RGB")
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=0.4, percent=120, threshold=1))
    rgb = ImageEnhance.Contrast(rgb).enhance(1.05)
    out = rgb.convert("RGBA")
    out.putalpha(img.split()[3])
    return out


def main():
    count = 0
    for pat in GROUPS:
        for f in sorted(glob.glob(pat)):
            if f.endswith(".import") or "_legacy" in f:
                continue
            rel = os.path.relpath(f, ROOT).replace(os.sep, "_")
            bak = os.path.join(LEGACY, rel)
            if not os.path.exists(bak):
                Image.open(f).convert("RGBA").save(bak)
            out = process(f)
            out.save(f)
            count += 1
            print(f"  {os.path.basename(f):30s} -> {TARGET}x{TARGET}  [bak: {os.path.basename(bak)}]")
    print(f"\nDone. 处理 {count} 张图标，原图备份于 {LEGACY}")


if __name__ == "__main__":
    main()
