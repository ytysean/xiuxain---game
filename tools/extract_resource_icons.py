#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
去掉顶部资源图标的外框/底板，只保留中心本体。
统一以暗青/深灰底板为背景色，按 RGB 距离 + 各图标颜色特征去除背景，
再保留中心最大连通区域。
"""

from PIL import Image
import os

SRC_DIR = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
NAMES = ["res_lingshi", "res_lingqi", "res_lingzhi", "res_shengwang"]

# 暗青/深灰背景代表色（观察四个原图共性）
BG_COLOR = (70, 75, 73)


def brightness(c):
    return (c[0] + c[1] + c[2]) / 3.0


def saturation(c):
    r, g, b = c[0], c[1], c[2]
    mx = max(r, g, b)
    mn = min(r, g, b)
    if mx == 0:
        return 0
    return (mx - mn) / mx


def rgb_dist(c1, c2):
    return abs(int(c1[0]) - int(c2[0])) + abs(int(c1[1]) - int(c2[1])) + abs(int(c1[2]) - int(c2[2]))


def keep_largest_center(mask, px, w, h, min_area=500):
    visited = [[False] * h for _ in range(w)]
    cx, cy = w // 2, h // 2
    best = []
    best_score = -1

    for y in range(h):
        for x in range(w):
            if visited[x][y] or not mask[x][y]:
                continue
            stack = [(x, y)]
            visited[x][y] = True
            region = []
            min_dist = 1e9
            while stack:
                cx2, cy2 = stack.pop()
                region.append((cx2, cy2))
                d = (cx2 - cx) ** 2 + (cy2 - cy) ** 2
                if d < min_dist:
                    min_dist = d
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx2 + dx, cy2 + dy
                    if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny] and mask[nx][ny]:
                        visited[nx][ny] = True
                        stack.append((nx, ny))

            if len(region) < min_area:
                continue
            score = len(region) * 1000 - min_dist
            if score > best_score:
                best_score = score
                best = region

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()
    for x, y in best:
        out_px[x, y] = px[x, y]
    return out


def process(name: str) -> None:
    path = os.path.join(SRC_DIR, f"{name}.png")
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size

    mask = [[False] * h for _ in range(w)]

    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 128:
                continue

            d = rgb_dist(c[:3], BG_COLOR)
            sat = saturation(c[:3])
            br = brightness(c)

            keep = False
            if name == "res_lingshi":
                # 蓝色宝石 / 金边高光
                keep = d >= 48 or c[2] > c[0] + 15 or br > 130
            elif name == "res_lingqi":
                # 淡青色灵气漩涡
                keep = d >= 55 or (c[1] > c[0] + 5 and c[2] > c[0] + 5 and br > 100)
            elif name == "res_lingzhi":
                # 棕绿色植物
                keep = d >= 50 or (sat > 0.18 and br > 60 and not (c[0] < 50 and c[1] < 60 and c[2] < 55))
            elif name == "res_shengwang":
                # 暖色古铜金
                keep = d >= 45 or (c[0] > 80 and c[0] >= c[1] and c[0] > c[2] and sat > 0.15)

            if keep:
                mask[x][y] = True

    out = keep_largest_center(mask, px, w, h, min_area=800)
    out.save(path)
    print(f"saved {name}.png")


def main():
    for name in NAMES:
        process(name)


if __name__ == "__main__":
    main()
