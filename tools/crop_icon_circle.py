#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把顶部资源图标从中心裁成圆形区域，外部像素全透明。
这样图标本身变成圆形，放到 UI 统一圆形底上时不会露出方形外框。
"""

from PIL import Image
import os
import math

SRC_DIR = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
NAMES = ["res_lingshi", "res_lingqi", "res_lingzhi", "res_shengwang"]

OUT_SIZE = 20
# 原图中心圆形裁剪半径（相对 256x256）
RADIUS_RATIO = 0.42  # 取中心 84% 直径的圆


def crop_circle(name: str) -> None:
    path = os.path.join(SRC_DIR, f"{name}.png")
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    cx, cy = w / 2, h / 2
    radius = min(cx, cy) * RADIUS_RATIO

    # 创建圆形 mask
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            if d <= radius:
                mp[x, y] = 255
            elif d <= radius + 2:
                # 柔和 2px 过渡
                mp[x, y] = int(255 * (1 - (d - radius) / 2))
            else:
                mp[x, y] = 0

    # 应用 mask
    r, g, b, a = im.split()
    a = Image.composite(a, Image.new("L", (w, h), 0), mask)
    out = Image.merge("RGBA", (r, g, b, a))

    # 缩放到 20x20
    out = out.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    out.save(path)
    print(f"{name}: circular crop -> {OUT_SIZE}x{OUT_SIZE}")


def main() -> None:
    for name in NAMES:
        crop_circle(name)


if __name__ == "__main__":
    main()
