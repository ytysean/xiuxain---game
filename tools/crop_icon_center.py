#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
对顶部资源图标做中心裁剪，去掉外围方形底板，只保留中心主体区域。
从 256x256 原图中心截取 crop_size x crop_size，再缩放到 out_size x out_size。
"""

from PIL import Image
import os

SRC_DIR = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
NAMES = ["res_lingshi", "res_lingqi", "res_lingzhi", "res_shengwang"]

CROP_SIZE = 170  # 中心裁剪区域
OUT_SIZE = 20    # 输出尺寸（顶部栏图标显示大小）


def crop_center(name: str) -> None:
    path = os.path.join(SRC_DIR, f"{name}.png")
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    cx, cy = w // 2, h // 2
    left = cx - CROP_SIZE // 2
    top = cy - CROP_SIZE // 2
    right = left + CROP_SIZE
    bottom = top + CROP_SIZE
    cropped = im.crop((left, top, right, bottom))
    out = cropped.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    out.save(path)
    print(f"{name}: cropped {CROP_SIZE}x{CROP_SIZE} -> {OUT_SIZE}x{OUT_SIZE}")


def main() -> None:
    for name in NAMES:
        crop_center(name)


if __name__ == "__main__":
    main()
