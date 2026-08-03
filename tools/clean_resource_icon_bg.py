#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把资源图标 PNG 的浅色外背景改为透明，只保留内部暗青面板+图案。
第二版：从所有边缘像素同时 flood fill，解决“角落先透明后其他边缘背景没删掉”的残留问题。
"""
from PIL import Image
from collections import deque
import os

BASE = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
NAMES = ["res_lingshi", "res_lingqi", "res_lingzhi", "res_shengwang"]

LIGHT_THRESHOLD = 130
TOL = 50


def brightness(c):
    r, g, b, a = c
    return (r + g + b) / 3.0


def dist(c1, c2):
    return abs(int(c1[0]) - int(c2[0])) + abs(int(c1[1]) - int(c2[1])) + abs(int(c1[2]) - int(c2[2]))


def clean(name: str) -> None:
    src = os.path.join(BASE, f"{name}.png")
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    bg = [[False] * h for _ in range(w)]

    # 把所有边缘上仍是“浅色不透明”的像素作为种子，统一入队。
    q = deque()
    avg = [0.0, 0.0, 0.0]
    count = 0

    def add_seed(x, y):
        nonlocal count
        c = px[x, y]
        if c[3] < 10 or bg[x][y] or brightness(c) < LIGHT_THRESHOLD:
            return
        bg[x][y] = True
        q.append((x, y))
        avg[0] += c[0]
        avg[1] += c[1]
        avg[2] += c[2]
        count += 1

    for x in range(w):
        add_seed(x, 0)
        add_seed(x, h - 1)
    for y in range(1, h - 1):
        add_seed(0, y)
        add_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        c = px[x, y]
        # 用动态平均色更新，允许背景有渐变
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h:
                    continue
                if bg[nx][ny]:
                    continue
                nc = px[nx, ny]
                if nc[3] < 10:
                    continue
                ac = (avg[0] / count, avg[1] / count, avg[2] / count)
                if dist(nc, ac) <= TOL:
                    bg[nx][ny] = True
                    q.append((nx, ny))
                    avg[0] += nc[0]
                    avg[1] += nc[1]
                    avg[2] += nc[2]
                    count += 1

    removed = 0
    for y in range(h):
        for x in range(w):
            if bg[x][y]:
                px[x, y] = (0, 0, 0, 0)
                removed += 1

    im.save(src)
    print(f"{name}: removed {removed} bg pixels, kept {w*h - removed}")


if __name__ == "__main__":
    for n in NAMES:
        clean(n)
